# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# PowerShell 7+ only: this script uses ConvertFrom-Json -AsHashtable, Export-Csv
# -UseQuotes, and reads Invoke-RestMethod's error response as an HttpResponseMessage
# (Windows PowerShell 5.1 surfaces an HttpWebResponse instead). Declaring it here fails
# fast with a clear message rather than a confusing downstream error. The workflow runs
# `shell: pwsh`, so this only affects someone running the script by hand.
#Requires -Version 7.0

<#
    .SYNOPSIS
    Fetches commitment discount eligibility data from the Azure Retail Prices API.

    .DESCRIPTION
    Queries the Azure Retail Prices API to determine which meters are eligible for
    Reserved Instances and/or Savings Plans. Outputs a CSV file that can be used as
    open data for FinOps Hub ingestion and PowerShell module lookups.

    Each price type is fetched in a single traversal that follows the documented
    NextPageLink verbatim -- no $top, no $orderby (a multi-field $orderby is rejected
    by the API with HTTP 400), no client-side $skip. The same pass records both the
    eligible meterIds and a per-serviceFamily count, so the completeness guard below
    gets its per-family baseline for free.

    Data integrity rests on the completeness guard, not on re-fetching. Before writing,
    the run is compared against the previously published data in aggregate AND per
    serviceFamily; either check falling more than -MaxShrinkFraction below its baseline
    aborts the run, so an incomplete fetch can never overwrite good open data with
    missing eligibility. The per-family check is what catches a single family that
    silently under-fetches, which an aggregate-only floor would miss when growth
    elsewhere masks it.

    History: this script previously sharded each query by serviceFamily and repeated
    every shard until its meterId set stopped growing, to work around a period when the
    API returned an unstable page order and a single traversal silently dropped a
    scattered fraction of rows. That instability was last observed in early June 2026;
    Microsoft support case 2606030050003725 closed without a root cause on 2026-07-06.
    Seven full traversals on 2026-06-29 were byte-identical, and the workaround's own
    telemetry in CI on 2026-08-12 showed every repeat pass across all 22 shards adding
    exactly zero meters while costing 2-3x the traversal volume -- and the shard list
    required a full discovery traversal per price type, which alone consumed 25 of the
    job's 60 minutes and pushed the run into its timeout. The workaround was therefore
    removed in favour of the guards. If the instability returns, the guards abort the
    run loudly rather than publishing partial data; that is the intended behaviour and
    the signal to reopen the case.

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
        so it is followed verbatim. Pages lets the caller report how much of the
        catalogue a traversal actually covered.
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

                $wait = Get-RetryDelay -Response $errResponse -Attempt $retries
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

function Get-RetryDelay
{
    <#
        .SYNOPSIS
        Returns the seconds to wait before retrying: the response's Retry-After when
        the server supplied a usable one, otherwise an exponential backoff.

        .DESCRIPTION
        Reads the STRONGLY TYPED HttpResponseHeaders.RetryAfter property. Do not reach
        for $Response.Headers['Retry-After'] -- HttpResponseHeaders has no string
        indexer, so that expression silently evaluates to $null (it does not throw) and
        the header is never honored. GetValues() is no better: it throws when the header
        is absent. The typed property parses both legal forms of the header (delta-
        seconds and HTTP-date), and is $null when absent.

        The value is clamped to -MaxSeconds so an outsized server value cannot stall the
        run past the job timeout, and a non-positive value (a stale HTTP-date already in
        the past) falls back to the exponential backoff rather than retrying instantly.
    #>
    param(
        $Response,
        [int]$Attempt,

        # The API documents no ceiling on Retry-After and the job runs under a fixed
        # timeout, so an outsized server value is clamped rather than allowed to stall
        # the run until it is killed mid-fetch.
        [int]$MaxSeconds = 300
    )

    $retryAfter = $null
    $header = if ($Response) { $Response.Headers.RetryAfter } else { $null }
    if ($header.Delta)
    {
        $retryAfter = [int]$header.Delta.TotalSeconds
    }
    elseif ($header.Date)
    {
        $retryAfter = [int]([Math]::Ceiling(($header.Date - [DateTimeOffset]::UtcNow).TotalSeconds))
    }

    if ($retryAfter -gt 0)
    {
        return [Math]::Min($retryAfter, $MaxSeconds)
    }
    return [int][Math]::Pow(2, $Attempt) * 10
}

function Get-EligibleMeter
{
    <#
        .SYNOPSIS
        Walks one price type in a single traversal, collecting eligible meterIds and
        per-serviceFamily counts in the same pass.

        .DESCRIPTION
        Returns @{ Keys = @{ meterId -> $true }; FamilyCounts = @{ family -> count };
        Items = <items walked>; Pages = <pages fetched> }.

        $CollectKey receives an item and returns the meterId to record, or $null to skip
        it (used to gate Savings Plan eligibility on a non-empty savingsPlan).

        FamilyCounts counts DISTINCT COLLECTED meterIds per family, matching what the
        sharded implementation persisted, so an existing baseline stays comparable. A
        family bucket is created for every family seen even when it collects nothing, so
        a family that legitimately has no eligible meters is recorded as 0 rather than
        vanishing from the baseline.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'CollectKey is invoked inside the nested -OnItem closure passed to Get-RetailPriceSegment, which the analyzer cannot trace. Target must be empty to suppress on PSScriptAnalyzer 1.x.')]
    param(
        [string]$Filter,
        [string]$MeterRegion,
        [scriptblock]$CollectKey,
        [string]$ActivityName
    )

    $keys = @{}
    $familyKeys = @{}
    # A scalar `$n++` inside the callback would bind to a NEW local in the scriptblock's
    # invocation scope (PowerShell copies on write) and never accumulate, so the tick
    # counter lives in a hashtable, whose entries the callback mutates in place. Keyed
    # 'Seen' rather than 'Count' to avoid colliding with Hashtable's own Count property.
    $tick = @{ Seen = 0 }

    $segment = Get-RetailPriceSegment -Filter $Filter -MeterRegion $MeterRegion -OnItem {
        param($item)

        # Bucket every item's family, not just the collected ones, so a family with zero
        # eligible meters is still recorded (as 0) in the persisted baseline.
        $family = if ($item.serviceFamily) { $item.serviceFamily } else { '(none)' }
        if (-not $familyKeys.ContainsKey($family)) { $familyKeys[$family] = @{} }

        $key = & $CollectKey $item
        if ($key)
        {
            $k = $key.ToLowerInvariant()
            $keys[$k] = $true
            $familyKeys[$family][$k] = $true
        }

        # Write-Progress per item is far too chatty for a 500k-item traversal.
        $tick.Seen++
        if ($tick.Seen % 25000 -eq 0)
        {
            Write-Progress -Activity $ActivityName -Status "$($tick.Seen) items, $($keys.Count) eligible meters"
        }
    }

    Write-Progress -Activity $ActivityName -Completed

    $familyCounts = @{}
    foreach ($family in $familyKeys.Keys) { $familyCounts[$family] = $familyKeys[$family].Count }

    return @{
        Keys         = $keys
        FamilyCounts = $familyCounts
        Items        = $segment.Items
        Pages        = $segment.Pages
    }
}

# Per-family baseline (sidecar alongside the CSV). The published CSV carries only
# MeterId + the two flags -- no serviceFamily -- so per-family counts from the last
# good run are persisted here to let the completeness guard catch a single family
# that systematically under-fetches (which an aggregate-only check could miss when
# growth elsewhere masks it). Committed/pushed beside the CSV so it survives the
# fresh checkout of each scheduled CI run. The 'shardcounts' name predates the removal
# of serviceFamily sharding and is retained because the workflow, the open-data CI path
# filter, and the packaging exclusion all key off it.
$ShardCountPath = [System.IO.Path]::ChangeExtension($OutputPath, 'shardcounts.json')

function ConvertTo-SortedMap
{
    <#
        .SYNOPSIS
        Returns an ordered dictionary with the given hashtable's entries sorted by key.

        .DESCRIPTION
        Hashtable key enumeration order is not guaranteed, so serializing one directly
        can reorder the JSON between runs even when every count is identical. The
        workflow treats ANY diff in the baseline sidecar as "data changed" and pushes a
        branch asking for a PR, so an unstable key order would manufacture empty
        update PRs. Sorting makes the file a function of its contents alone.
    #>
    param([hashtable]$Map)

    $sorted = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object)) { $sorted[$key] = $Map[$key] }
    return $sorted
}

function Get-ShardShortfall
{
    <#
        .SYNOPSIS
        Returns per-family guard violations: families whose collected count fell more
        than $MaxShrinkFraction below the baseline. Empty when the baseline is
        absent (first run) or every family is within tolerance.

        .DESCRIPTION
        Iterates the BASELINE families, not the current run's, so a family that
        disappears entirely this run is caught as a 100% shortfall against its baseline
        -- iterating the current set would skip a vanished family and let the silent
        drop through. New families (present now, absent from the baseline) need no check
        and are simply not iterated.
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
        if (-not $prev) { continue }   # previously-empty family: nothing to compare
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
    Write-Verbose "  Loaded per-family baseline from $ShardCountPath"
}

# -----------------------------------------------------------------------
# Step 2: Reservation-eligible meters (single traversal)
# -----------------------------------------------------------------------
Write-Host "Fetching Reservation prices..."
$riResult = Get-EligibleMeter -Filter "priceType eq 'Reservation'" -MeterRegion 'primary' -ActivityName 'Fetching Reservation prices' -CollectKey {
    param($item)
    $item.meterId
}
$riMeters = $riResult.Keys
Write-Host "  Walked $($riResult.Items) items over $($riResult.Pages) pages across $($riResult.FamilyCounts.Count) service families"
Write-Host "  RI-eligible meters: $($riMeters.Count)"

# -----------------------------------------------------------------------
# Step 3: Savings Plan-eligible meters (single traversal)
# The savingsPlan array is embedded in Consumption items, so we page through
# primary Consumption meters and record those with a non-empty savingsPlan.
# -----------------------------------------------------------------------
Write-Host "Fetching Consumption prices (checking for Savings Plan eligibility)..."
$spResult = Get-EligibleMeter -Filter "priceType eq 'Consumption'" -MeterRegion 'primary' -ActivityName 'Fetching Consumption prices' -CollectKey {
    param($item)
    if ($item.savingsPlan -and $item.savingsPlan.Count -gt 0) { $item.meterId } else { $null }
}
$spMeters = $spResult.Keys
Write-Host "  Walked $($spResult.Items) items over $($spResult.Pages) pages across $($spResult.FamilyCounts.Count) service families"
Write-Host "  SP-eligible meters: $($spMeters.Count)"

# -----------------------------------------------------------------------
# Step 3b: Completeness guard. Abort before writing if the meter total dropped
# materially below the published total -- an incomplete run must never overwrite
# good open-data (a missed SP flag would flip Eligible -> Not).
# -----------------------------------------------------------------------
$seenSet = @{}
foreach ($key in $riMeters.Keys) { $seenSet[$key] = $true }
foreach ($key in $spMeters.Keys) { $seenSet[$key] = $true }
$seenTotal = $seenSet.Count

if ($cachedTotal -gt 0)
{
    $floor = [Math]::Ceiling($cachedTotal * (1 - $MaxShrinkFraction))
    if ($seenTotal -lt $floor)
    {
        throw "Aborting before write: fetched $seenTotal meters, below the floor of $floor (cached $cachedTotal, max shrink $([Math]::Round($MaxShrinkFraction * 100))%). Run is likely incomplete; refusing to overwrite published data."
    }
}

# Per-family guard: a single family that systematically under-fetches can be hidden
# from the aggregate check by growth elsewhere, so compare each family against its
# own baseline (when one exists from a prior run). $cachedShardCounts is a hashtable
# (ConvertFrom-Json -AsHashtable), so index its sections by key -- but it is $null
# when no baseline sidecar exists, and PowerShell throws "Cannot index into a null
# array" rather than yielding $null, so the section lookup MUST be guarded. The sidecar
# is committed next to the CSV, so a normal CI run does have one; this path is taken
# when running against a fresh -OutputPath (as a local test run does) or if the sidecar
# is ever removed.
$riBaseline = if ($cachedShardCounts) { $cachedShardCounts['Reservation'] } else { $null }
$spBaseline = if ($cachedShardCounts) { $cachedShardCounts['Consumption'] } else { $null }

$shardShortfall = @()
$shardShortfall += Get-ShardShortfall -Section 'Reservation' -Current $riResult.FamilyCounts -Baseline $riBaseline -MaxShrinkFraction $MaxShrinkFraction
$shardShortfall += Get-ShardShortfall -Section 'Consumption' -Current $spResult.FamilyCounts -Baseline $spBaseline -MaxShrinkFraction $MaxShrinkFraction
if ($shardShortfall.Count -gt 0)
{
    throw "Aborting before write: service family/families fell more than $([Math]::Round($MaxShrinkFraction * 100))% below baseline: $($shardShortfall -join '; '). A family likely under-fetched; refusing to overwrite published data. Raise -MaxShrinkFraction for a deliberate large change."
}
Write-Host "Completeness check passed: $seenTotal meters seen this run (cached $cachedTotal)."

# -----------------------------------------------------------------------
# Step 4: Build the output from this run's sets (write fresh) and summarize the
# change versus the previously published CSV. Meters present only in the old CSV are
# dropped (retired); the guard above already ensured the run is whole.
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

# Persist this run's per-family counts as the baseline for the next run's guard, with
# the families in sorted order (see ConvertTo-SortedMap).
$newShardCounts = [ordered]@{
    Reservation = ConvertTo-SortedMap -Map $riResult.FamilyCounts
    Consumption = ConvertTo-SortedMap -Map $spResult.FamilyCounts
}
$newShardCounts | ConvertTo-Json -Depth 4 | Set-Content -Path $ShardCountPath -Encoding utf8 -NoNewline
Write-Host "Wrote per-family baseline to $ShardCountPath"
