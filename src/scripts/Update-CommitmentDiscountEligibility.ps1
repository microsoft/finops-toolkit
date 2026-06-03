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
      1. Shards each query by serviceFamily so individual traversals stay short
         (short traversals are far less exposed to the ordering instability), and
      2. Repeats each shard, unioning results by meterId, until the collected set
         stops growing (misses are random per pass, so the union converges).
    A completeness guard aborts before writing if the fetched total falls materially
    below the previously published total, so an incomplete run can never overwrite
    good open-data with missing eligibility.

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
    [double]$MaxShrinkFraction = 0.15
)

$ErrorActionPreference = 'Stop'

$apiBase = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview'

# serviceFamily values to shard by (documented list; "subject to change"). A newly
# added family missing from this list is caught by the completeness guard below.
$ShardList = @(
    'Analytics', 'Azure Arc', 'Azure Communication Services', 'Azure Security',
    'Azure Stack', 'Compute', 'Containers', 'Data', 'Databases', 'Developer Tools',
    'Dynamics', 'Gaming', 'Integration', 'Internet of Things',
    'Management and Governance', 'Microsoft Syntex', 'Mixed Reality', 'Networking',
    'Other', 'Power Platform', 'Quantum Computing', 'Security', 'Storage',
    'Telecommunications', 'Web', 'Windows Virtual Desktop'
)

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
        Returns the number of items walked. Retries 429/5xx with backoff (honoring
        Retry-After) and throws on terminal 4xx. NextPageLink already carries
        api-version, $filter, $skip, and meterRegion, so it is followed verbatim.
    #>
    param(
        [string]$Filter,
        [string]$MeterRegion,
        [scriptblock]$OnItem
    )

    # Do NOT send $top: the API's NextPageLink generator decrements $top by the page
    # size each page (1000 -> 0 -> -1000 -> ...), and a negative $top returns HTTP 400.
    # Omitting it lets the server default to 1000/page and only advance $skip.
    $url = $apiBase
    if ($Filter) { $url += "&`$filter=$Filter" }
    if ($MeterRegion) { $url += "&meterRegion='$MeterRegion'" }

    $totalItems = 0
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

        foreach ($item in $response.Items)
        {
            & $OnItem $item
        }
        $totalItems += $response.Items.Count

        # NextPageLink already carries api-version, $filter, $skip, and meterRegion.
        $url = $response.NextPageLink
    }

    return $totalItems
}

function Invoke-ShardedUnion
{
    <#
        .SYNOPSIS
        Runs a query sharded by serviceFamily, repeating each shard and unioning the
        collected meterId keys until the set stabilizes (or a pass cap is hit).

        .DESCRIPTION
        Returns a hashtable: Keys = @{ meterId -> $true } for all collected meters;
        NonConverged = list of shards that hit the pass cap while still adding keys.
        $CollectKey receives an item and returns the meterId to record, or $null to
        skip it (used to gate Savings Plan eligibility on a non-empty savingsPlan).
    #>
    param(
        [string]$BaseFilter,
        [string[]]$Shards,
        [string]$MeterRegion,
        [scriptblock]$CollectKey,
        [string]$ActivityName
    )

    $union = @{}
    $nonConverged = @()
    $shardNum = 0

    foreach ($shard in $Shards)
    {
        $shardNum++
        $shardFilter = "$BaseFilter and serviceFamily eq '$shard'"
        $shardKeys = @{}
        $stable = 0
        $pass = 0
        $itemsLastPass = 0

        $singlePage = $false
        while ($pass -lt $MaxPassesPerShard -and $stable -lt $StablePasses)
        {
            $pass++
            $before = $shardKeys.Count
            $itemsLastPass = Get-RetailPriceSegment -Filter $shardFilter -MeterRegion $MeterRegion -OnItem {
                param($item)
                $key = & $CollectKey $item
                if ($key) { $shardKeys[$key.ToLowerInvariant()] = $true }
            }

            # A shard that fit in a single page (no pagination) returned its complete,
            # deterministic set -- repeating cannot add anything, so stop. Only
            # paginated shards are exposed to the unstable-order drop and need repeats.
            if ($itemsLastPass -le 1000) { $singlePage = $true; break }

            $added = $shardKeys.Count - $before
            if ($added -eq 0) { $stable++ } else { $stable = 0 }

            $pct = [Math]::Min(100, [Math]::Floor($shardNum / $Shards.Count * 100))
            Write-Progress -Activity $ActivityName -Status "$shard (pass $pass): $($shardKeys.Count) keys" -PercentComplete $pct
        }

        foreach ($k in $shardKeys.Keys) { $union[$k] = $true }

        if (-not $singlePage -and $stable -lt $StablePasses)
        {
            $nonConverged += $shard
            Write-Warning "  Shard '$shard' did not converge within $MaxPassesPerShard passes (still adding keys)."
        }
        Write-Host "  $shard : $($shardKeys.Count) keys ($itemsLastPass items/pass, $pass pass(es))"
    }

    Write-Progress -Activity $ActivityName -Completed
    return @{ Keys = $union; NonConverged = $nonConverged }
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

# -----------------------------------------------------------------------
# Step 2: Reservation-eligible meters (sharded by serviceFamily, union to stable)
# -----------------------------------------------------------------------
Write-Host "Fetching Reservation prices (sharded by serviceFamily)..."
$riResult = Invoke-ShardedUnion -BaseFilter "priceType eq 'Reservation'" -Shards $ShardList -MeterRegion 'primary' -ActivityName 'Fetching Reservation prices' -CollectKey {
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
Write-Host "Fetching Consumption prices (sharded by serviceFamily; checking for Savings Plan eligibility)..."
$spResult = Invoke-ShardedUnion -BaseFilter "priceType eq 'Consumption'" -Shards $ShardList -MeterRegion 'primary' -ActivityName 'Fetching Consumption prices' -CollectKey {
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
    $floor = [Math]::Floor($cachedTotal * (1 - $MaxShrinkFraction))
    if ($seenTotal -lt $floor)
    {
        throw "Aborting before write: fetched $seenTotal meters, below the floor of $floor (cached $cachedTotal, max shrink $([Math]::Round($MaxShrinkFraction * 100))%). Run is likely incomplete; refusing to overwrite published data."
    }
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
