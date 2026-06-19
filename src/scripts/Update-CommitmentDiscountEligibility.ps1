# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Fetches commitment discount eligibility data from the Azure Retail Prices API.

    .DESCRIPTION
    Queries the Azure Retail Prices API to determine which meters are eligible for
    Reserved Instances and/or Savings Plans. Outputs a CSV file that can be used as
    open data for FinOps Hub ingestion and PowerShell module lookups.

    The Azure Retail Prices API does not guarantee a stable total order across paged
    requests, so a single NextPageLink/$skip traversal of a large result set silently
    drops a scattered fraction of rows and is not reproducible run-to-run. To work
    around this, the script:
      1. Discovers the serviceFamily values actually present in the API (one scan per
         price type) and shards by those, so the shard list is self-correcting: a
         newly added family (or a rename) is fetched automatically instead of being
         silently excluded by a hardcoded allowlist. A discovery scan is itself a long
         traversal and so is exposed to the ordering drop; for most families the drop
         can only lose scattered rows (never all of them), but a tiny family with 1-2
         meters could be missed entirely, so the discovered set is unioned with the
         prior run's families (Add-BaselineShard) -- a previously-seen family is always
         queried and can never be silently dropped.
      2. Shards each query by those serviceFamily values so individual traversals stay
         short (short traversals are far less exposed to the ordering instability), and
      3. Repeats each shard, unioning results by meterId, until the collected set
         stops growing (misses are random per pass, so the union converges).
    A completeness guard aborts before writing if the fetched total falls materially
    below the previously published total -- in aggregate and per family, so a family
    that vanishes or under-fetches is caught even if growth elsewhere masks it -- so an
    incomplete run can never overwrite good open-data with missing eligibility.

    Pagination follows the documented NextPageLink verbatim; no undocumented $orderby
    is used (a multi-field $orderby is now rejected by the API with HTTP 400).

    .PARAMETER OutputPath
    Path to the output CSV file. Defaults to src/open-data/CommitmentDiscountEligibility.csv.

    .EXAMPLE
    ./Update-CommitmentDiscountEligibility.ps1

    .EXAMPLE
    ./Update-CommitmentDiscountEligibility.ps1 -OutputPath ./output/eligibility.csv
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/../open-data/CommitmentDiscountEligibility.csv",

    # Completeness guard: abort without writing if this run's meter total falls more
    # than this fraction below the previously published row count. Raise it for a
    # deliberate large change (e.g. an initial migration that sheds retired meters).
    # Constrained to 0..1: a value >1 would make the floor negative and silently
    # disable the guard.
    [ValidateRange(0.0, 1.0)]
    [double]$MaxShrinkFraction = 0.15
)

$ErrorActionPreference = 'Stop'

$apiBase = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview'

# The serviceFamily values to shard by are discovered at runtime per price type (see
# Get-ServiceFamily), not hardcoded: a positive `serviceFamily eq` allowlist would
# silently drop any family it omits (e.g. a newly added or renamed family), and the
# completeness guard's aggregate floor is too coarse to catch a small family. Discovery
# makes the shard set self-correcting; the per-family guard catches any family that
# disappears between runs.

# Repeat each shard until its unioned key set stops growing for $StablePasses
# consecutive passes, or $MaxPassesPerShard is reached (treated as non-convergence).
$MaxPassesPerShard = 4
$StablePasses = 2

function Get-RetailPriceSegment
{
    <#
        .SYNOPSIS
        Walks a single query to completion by following NextPageLink verbatim,
        invoking a callback per item. No client-side $skip or $orderby.

        .DESCRIPTION
        Returns @{ Items = <count walked>; Pages = <responses fetched> }. Retries
        429/5xx with backoff (honoring Retry-After) and throws on terminal 4xx.
        NextPageLink already carries api-version, $filter, $skip, and meterRegion,
        so it is followed verbatim. Pages lets the caller detect "fit in one page"
        without assuming a fixed server page size.
    #>
    param(
        [string]$Filter,
        [string]$MeterRegion,
        [scriptblock]$OnItem
    )

    # Do NOT send $top: the API's NextPageLink generator decrements $top by the page
    # size each page (1000 -> 0 -> -1000 -> ...), and a negative $top returns HTTP 400.
    # Omitting it lets the server default its page size and only advance $skip.
    $url = $apiBase
    if ($Filter) { $url += "&`$filter=$Filter" }
    if ($MeterRegion) { $url += "&meterRegion='$MeterRegion'" }

    $totalItems = 0
    $pageCount = 0
    while ($url)
    {
        $retries = 0
        $maxRetries = 5

        while ($true)
        {
            try
            {
                $savedProgress = $ProgressPreference
                $savedVerbose = $VerbosePreference
                $ProgressPreference = 'SilentlyContinue'
                $VerbosePreference = 'SilentlyContinue'
                try { $response = Invoke-RestMethod -Uri $url -Method Get }
                finally { $ProgressPreference = $savedProgress; $VerbosePreference = $savedVerbose }
                break
            }
            catch
            {
                # On network/DNS/timeout errors there is no HTTP response, so guard
                # against a null .Response before reading status code / headers --
                # otherwise indexing it throws here and bypasses the retry/backoff.
                $errResponse = $_.Exception.Response
                $statusCode = if ($errResponse) { [int]$errResponse.StatusCode } else { 0 }
                if ($statusCode -and $statusCode -lt 500 -and $statusCode -ne 429)
                {
                    throw "HTTP $statusCode`: $_"
                }

                $retries++
                if ($retries -gt $maxRetries)
                {
                    throw "Failed after $maxRetries retries: $_"
                }

                $retryAfter = if ($errResponse) { $errResponse.Headers['Retry-After'] } else { $null }
                $wait = if ($retryAfter) { [int]$retryAfter } else { [Math]::Pow(2, $retries) * 10 }
                $reason = if ($statusCode -eq 429) { 'Rate limited' } elseif ($statusCode) { "HTTP $statusCode" } else { 'Network error' }
                Write-Host "  $reason, retrying in ${wait}s (attempt $retries/$maxRetries)"
                Start-Sleep -Seconds $wait
            }
        }

        $pageCount++
        foreach ($item in $response.Items)
        {
            & $OnItem $item
        }
        $totalItems += $response.Items.Count

        # NextPageLink already carries api-version, $filter, $skip, and meterRegion.
        $url = $response.NextPageLink
    }

    return @{ Items = $totalItems; Pages = $pageCount }
}

function Get-ServiceFamily
{
    <#
        .SYNOPSIS
        Scans a query to completion and returns the distinct serviceFamily values
        present, used to build the shard list dynamically instead of hardcoding it.

        .DESCRIPTION
        A single full traversal is exposed to the API's unstable paging order. For
        families with many meters the drop can only lose scattered rows, so they are
        always discovered; a tiny family (1-2 meters) could in principle be missed,
        which the caller backstops by unioning with the prior baseline (Add-BaselineShard).
        The per-family data fetch in Invoke-ShardedUnion still repeats and unions to
        recover the dropped rows.
    #>
    param(
        [string]$Filter,
        [string]$MeterRegion,
        [string]$ActivityName
    )

    $families = @{}
    Write-Progress -Activity $ActivityName -Status 'Discovering serviceFamily values...'
    $null = Get-RetailPriceSegment -Filter $Filter -MeterRegion $MeterRegion -OnItem {
        param($item)
        if ($item.serviceFamily) { $families[$item.serviceFamily] = $true }
    }
    Write-Progress -Activity $ActivityName -Completed
    return [string[]]($families.Keys | Sort-Object)
}

function Add-BaselineShard
{
    <#
        .SYNOPSIS
        Unions discovered families with the families seen in the prior run's baseline.

        .DESCRIPTION
        A discovery scan is a single traversal and so is exposed to the ordering drop.
        Most families have many meters (so the drop can't lose all of them), but some
        have only 1-2, where a single miss could drop the family's only row and omit it
        from the shard list. Re-including every family from the prior baseline
        guarantees a previously-seen family is always queried -- it can never be
        silently dropped by a discovery miss -- while discovery still surfaces new
        families. The per-shard guard then catches any known family that genuinely
        shrank. Returns the sorted, de-duplicated union.
    #>
    param(
        [string[]]$Discovered,
        [hashtable]$BaselineSection
    )
    if (-not $BaselineSection) { return [string[]](@($Discovered) | Sort-Object -Unique) }
    return [string[]](@($Discovered) + @($BaselineSection.Keys) | Sort-Object -Unique)
}

function Invoke-ShardedUnion
{
    <#
        .SYNOPSIS
        Runs a query sharded by serviceFamily, repeating each shard and unioning the
        collected meterId keys until the set stabilizes (or a pass cap is hit).

        .DESCRIPTION
        Returns a hashtable: Keys = @{ meterId -> $true } for all collected meters;
        NonConverged = list of shards that hit the pass cap while still adding keys;
        ShardCounts = @{ shard -> collected key count } for the per-shard guard.
        $CollectKey receives an item and returns the meterId to record, or $null to
        skip it (used to gate Savings Plan eligibility on a non-empty savingsPlan).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'CollectKey is invoked inside the nested -OnItem closure passed to Get-RetailPriceSegment, which the analyzer cannot trace. Target must be empty to suppress on PSScriptAnalyzer 1.x.')]
    param(
        [string]$BaseFilter,
        [string[]]$Shards,
        [string]$MeterRegion,
        [scriptblock]$CollectKey,
        [string]$ActivityName
    )

    $union = @{}
    $nonConverged = @()
    $shardCounts = @{}
    $shardNum = 0

    foreach ($shard in $Shards)
    {
        $shardNum++
        # URL-encode the serviceFamily value. In a query string an unescaped '+' is
        # decoded server-side to a space, so a family like 'AI + Machine Learning'
        # would match nothing and be silently dropped (168 meters today). The server
        # decodes the escape back to the literal value before OData parsing.
        $encodedShard = [uri]::EscapeDataString($shard)
        $shardFilter = "$BaseFilter and serviceFamily eq '$encodedShard'"
        $shardKeys = @{}
        $stable = 0
        $pass = 0
        $itemsLastPass = 0

        $singlePage = $false
        while ($pass -lt $MaxPassesPerShard -and $stable -lt $StablePasses)
        {
            $pass++
            $before = $shardKeys.Count
            $segment = Get-RetailPriceSegment -Filter $shardFilter -MeterRegion $MeterRegion -OnItem {
                param($item)
                $key = & $CollectKey $item
                if ($key) { $shardKeys[$key.ToLowerInvariant()] = $true }
            }
            $itemsLastPass = $segment.Items

            # A shard that fit in a single response (the API returned no NextPageLink)
            # delivered its complete, deterministic set -- repeating cannot add anything,
            # so stop. Only paginated shards are exposed to the unstable-order drop and
            # need repeats. Keyed off the page count rather than a hardcoded page size,
            # so a change to the server's default page size cannot mask a real miss.
            if ($segment.Pages -le 1) { $singlePage = $true; break }

            $added = $shardKeys.Count - $before
            if ($added -eq 0) { $stable++ } else { $stable = 0 }

            $pct = [Math]::Min(100, [Math]::Floor($shardNum / $Shards.Count * 100))
            Write-Progress -Activity $ActivityName -Status "$shard (pass $pass): $($shardKeys.Count) keys" -PercentComplete $pct
        }

        foreach ($k in $shardKeys.Keys) { $union[$k] = $true }
        $shardCounts[$shard] = $shardKeys.Count

        if (-not $singlePage -and $stable -lt $StablePasses)
        {
            $nonConverged += $shard
            Write-Warning "  Shard '$shard' did not converge within $MaxPassesPerShard passes (still adding keys)."
        }
        Write-Host "  $shard : $($shardKeys.Count) keys ($itemsLastPass items/pass, $pass pass(es))"
    }

    Write-Progress -Activity $ActivityName -Completed
    return @{ Keys = $union; NonConverged = $nonConverged; ShardCounts = $shardCounts }
}

# Per-shard baseline (sidecar alongside the CSV). The published CSV carries only
# MeterId + the two flags -- no serviceFamily -- so per-shard counts from the last
# good run are persisted here to let the completeness guard catch a single shard
# that systematically under-fetches (which an aggregate-only check could miss when
# growth elsewhere masks it). Committed/pushed beside the CSV so it survives the
# fresh checkout of each scheduled CI run.
$ShardCountPath = [System.IO.Path]::ChangeExtension($OutputPath, 'shardcounts.json')

function Get-ShardShortfall
{
    <#
        .SYNOPSIS
        Returns per-shard guard violations: families whose collected count fell more
        than $MaxShrinkFraction below the baseline. Empty when the baseline is
        absent (first run) or every family is within tolerance.

        .DESCRIPTION
        Iterates the BASELINE families, not the current run's, so a family that
        disappears entirely this run (e.g. discovery missed it, or a rename) is caught
        as a 100% shortfall against its baseline -- iterating the current set would
        skip a vanished family and let the silent drop through. New families (present
        now, absent from the baseline) need no check and are simply not iterated.
    #>
    param(
        [string]$Section,
        [hashtable]$Current,
        [hashtable]$Baseline,
        [double]$MaxShrinkFraction
    )

    $violations = @()
    if (-not $Baseline) { return $violations }
    foreach ($shard in $Baseline.Keys)
    {
        $prev = $Baseline[$shard]
        if (-not $prev) { continue }   # previously-empty shard: nothing to compare
        # Ceiling, not Floor: Floor rounds the bound down, allowing up to ~1 extra row
        # of shrink -- and for a baseline of 1 it floors to 0, so a drop to 0 (the
        # family vanishing) would pass. Ceiling preserves the fractional bound and
        # flags small-baseline regressions.
        $floor = [Math]::Ceiling($prev * (1 - $MaxShrinkFraction))
        $cur = if ($Current.ContainsKey($shard)) { $Current[$shard] } else { 0 }
        if ($cur -lt $floor)
        {
            $violations += "$Section/$shard $cur (baseline $prev, floor $floor)"
        }
    }
    return $violations
}

# -----------------------------------------------------------------------
# Step 1: Load the previously published CSV. Used only for the completeness-guard
# baseline and a change summary -- its rows are NOT preserved. Meters not seen this
# run are dropped (so retired meters age out instead of accumulating forever).
# -----------------------------------------------------------------------
$cached = @{}
$cachedTotal = 0

if (Test-Path $OutputPath)
{
    Write-Host "Loading previously published CSV..."
    Write-Verbose "  File: $OutputPath"
    $existing = Import-Csv -Path $OutputPath
    foreach ($row in $existing)
    {
        $cached[$row.MeterId.ToLowerInvariant()] = "$($row.x_CommitmentDiscountSpendEligibility)|$($row.x_CommitmentDiscountUsageEligibility)"
    }
    $cachedTotal = $existing.Count
    Write-Host "  Previous CSV: $cachedTotal meters"
}

$cachedShardCounts = $null
if (Test-Path $ShardCountPath)
{
    $cachedShardCounts = Get-Content -Path $ShardCountPath -Raw | ConvertFrom-Json -AsHashtable
    Write-Verbose "  Loaded per-shard baseline from $ShardCountPath"
}

# -----------------------------------------------------------------------
# Step 2: Reservation-eligible meters (sharded by serviceFamily, union to stable)
# -----------------------------------------------------------------------
Write-Host "Discovering Reservation serviceFamily values..."
$riShards = Get-ServiceFamily -Filter "priceType eq 'Reservation'" -MeterRegion 'primary' -ActivityName 'Discovering Reservation families'
$riShards = Add-BaselineShard -Discovered $riShards -BaselineSection $cachedShardCounts['Reservation']
Write-Host "  Found $($riShards.Count) serviceFamily values: $($riShards -join ', ')"
Write-Host "Fetching Reservation prices (sharded by serviceFamily)..."
$riResult = Invoke-ShardedUnion -BaseFilter "priceType eq 'Reservation'" -Shards $riShards -MeterRegion 'primary' -ActivityName 'Fetching Reservation prices' -CollectKey {
    param($item)
    $item.meterId
}
$riMeters = $riResult.Keys
Write-Host "  RI-eligible meters: $($riMeters.Count)"

# -----------------------------------------------------------------------
# Step 3: Savings Plan-eligible meters (sharded by serviceFamily, union to stable)
# The savingsPlan array is embedded in Consumption items, so we page through
# primary Consumption meters and record those with a non-empty savingsPlan.
# -----------------------------------------------------------------------
Write-Host "Discovering Consumption serviceFamily values..."
$spShards = Get-ServiceFamily -Filter "priceType eq 'Consumption'" -MeterRegion 'primary' -ActivityName 'Discovering Consumption families'
$spShards = Add-BaselineShard -Discovered $spShards -BaselineSection $cachedShardCounts['Consumption']
Write-Host "  Found $($spShards.Count) serviceFamily values: $($spShards -join ', ')"
Write-Host "Fetching Consumption prices (sharded by serviceFamily; checking for Savings Plan eligibility)..."
$spResult = Invoke-ShardedUnion -BaseFilter "priceType eq 'Consumption'" -Shards $spShards -MeterRegion 'primary' -ActivityName 'Fetching Consumption prices' -CollectKey {
    param($item)
    if ($item.savingsPlan -and $item.savingsPlan.Count -gt 0) { $item.meterId } else { $null }
}
$spMeters = $spResult.Keys
Write-Host "  SP-eligible meters: $($spMeters.Count)"

# -----------------------------------------------------------------------
# Step 3b: Completeness guard. Abort before writing if the run did not converge or
# the meter total dropped materially below the published total -- an incomplete run
# must never overwrite good open-data (a missed SP flag would flip Eligible -> Not).
# -----------------------------------------------------------------------
$seenSet = @{}
foreach ($key in $riMeters.Keys) { $seenSet[$key] = $true }
foreach ($key in $spMeters.Keys) { $seenSet[$key] = $true }
$seenTotal = $seenSet.Count

$nonConverged = @($riResult.NonConverged + $spResult.NonConverged | Sort-Object -Unique)
if ($nonConverged.Count -gt 0)
{
    throw "Aborting before write: shard(s) did not converge within $MaxPassesPerShard passes: $($nonConverged -join ', '). Increase `$MaxPassesPerShard or sub-shard these families by serviceName."
}

if ($cachedTotal -gt 0)
{
    $floor = [Math]::Ceiling($cachedTotal * (1 - $MaxShrinkFraction))
    if ($seenTotal -lt $floor)
    {
        throw "Aborting before write: fetched $seenTotal meters, below the floor of $floor (cached $cachedTotal, max shrink $([Math]::Round($MaxShrinkFraction * 100))%). Run is likely incomplete; refusing to overwrite published data."
    }
}

# Per-shard guard: a single family that systematically under-fetches can be hidden
# from the aggregate check by growth elsewhere, so compare each shard against its
# own baseline (when one exists from a prior run). $cachedShardCounts is a hashtable
# (ConvertFrom-Json -AsHashtable), so index its sections by key; null-safe when no
# baseline file exists.
$shardShortfall = @()
$shardShortfall += Get-ShardShortfall -Section 'Reservation' -Current $riResult.ShardCounts -Baseline $cachedShardCounts['Reservation'] -MaxShrinkFraction $MaxShrinkFraction
$shardShortfall += Get-ShardShortfall -Section 'Consumption' -Current $spResult.ShardCounts -Baseline $cachedShardCounts['Consumption'] -MaxShrinkFraction $MaxShrinkFraction
if ($shardShortfall.Count -gt 0)
{
    throw "Aborting before write: shard(s) fell more than $([Math]::Round($MaxShrinkFraction * 100))% below baseline: $($shardShortfall -join '; '). A family likely under-fetched; refusing to overwrite published data. Raise -MaxShrinkFraction for a deliberate large change."
}
Write-Host "Completeness check passed: $seenTotal meters seen this run (cached $cachedTotal)."

# -----------------------------------------------------------------------
# Step 4: Build the output from this run's converged sets (write fresh) and
# summarize the change versus the previously published CSV. Meters present only in
# the old CSV are dropped (retired); the guard above already ensured the run is whole.
# -----------------------------------------------------------------------
Write-Host "`nBuilding output..."
$sortedIds = [string[]]($seenSet.Keys | Sort-Object)

$added = 0
$changed = 0
$unchanged = 0

$rows = [System.Collections.ArrayList]::new($sortedIds.Count)
foreach ($meterId in $sortedIds)
{
    $ri = if ($riMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
    $sp = if ($spMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
    $val = "$ri|$sp"

    if (-not $cached.ContainsKey($meterId)) { $added++ }
    elseif ($cached[$meterId] -ne $val) { $changed++ }
    else { $unchanged++ }

    $null = $rows.Add([PSCustomObject]@{
            MeterId                              = $meterId
            x_CommitmentDiscountSpendEligibility = $ri
            x_CommitmentDiscountUsageEligibility = $sp
        })
}

$removed = 0
foreach ($key in $cached.Keys) { if (-not $seenSet.ContainsKey($key)) { $removed++ } }

Write-Host "`nChange summary (vs previous CSV):"
Write-Host "  Added:     $added"
Write-Host "  Changed:   $changed"
Write-Host "  Unchanged: $unchanged"
Write-Host "  Removed:   $removed (retired meters no longer returned by the API)"

Write-Verbose "Writing CSV to $OutputPath..."
$writeStart = [DateTime]::UtcNow
$rows | Export-Csv -Path $OutputPath -UseQuotes Always -NoTypeInformation -Encoding utf8
Write-Verbose "  CSV write completed in $([Math]::Round(([DateTime]::UtcNow - $writeStart).TotalSeconds, 1))s"
Write-Host "Wrote $($rows.Count) meters to $OutputPath"

# Persist this run's per-shard counts as the baseline for the next run's guard.
$newShardCounts = [ordered]@{
    Reservation = $riResult.ShardCounts
    Consumption = $spResult.ShardCounts
}
$newShardCounts | ConvertTo-Json -Depth 4 | Set-Content -Path $ShardCountPath -Encoding utf8 -NoNewline
Write-Host "Wrote per-shard baseline to $ShardCountPath"
