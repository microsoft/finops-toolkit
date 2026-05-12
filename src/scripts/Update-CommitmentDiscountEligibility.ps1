# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Fetches commitment discount eligibility data from the Azure Retail Prices API.

    .DESCRIPTION
    Queries the Azure Retail Prices API to determine which meters are eligible for
    Reserved Instances and/or Savings Plans. Outputs a CSV file that can be used as
    open data for FinOps Hub ingestion and PowerShell module lookups.

    .PARAMETER OutputPath
    Path to the output CSV file. Defaults to src/open-data/CommitmentDiscountEligibility.csv.

    .EXAMPLE
    ./Update-CommitmentDiscountEligibility.ps1

    .EXAMPLE
    ./Update-CommitmentDiscountEligibility.ps1 -OutputPath ./output/eligibility.csv
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/../open-data/CommitmentDiscountEligibility.csv"
)

$ErrorActionPreference = 'Stop'

$apiBase = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview'

function Get-RetailPricePages
{
    <#
        .SYNOPSIS
        Pages through the Azure Retail Prices API and invokes a callback per item.
    #>
    param(
        [string]$Filter,
        [string]$MeterRegion,
        [string]$OrderBy,
        [string]$ActivityName,
        [int]$EstimatedItems = 0,
        [scriptblock]$OnItem
    )

    $pageSize = 1000
    $overlap = 10
    $url = $apiBase
    if ($Filter) { $url += "&`$filter=$Filter" }
    if ($MeterRegion) { $url += "&meterRegion='$MeterRegion'" }
    if ($OrderBy) { $url += "&`$orderby=$OrderBy" }
    $url += "&`$top=$pageSize"
    Write-Verbose "  API URL: $url"
    $page = 0
    $totalItems = 0
    $driftDetected = 0
    $skip = 0
    $startTime = [DateTime]::UtcNow
    $estimatedPages = if ($EstimatedItems -gt 0) { [Math]::Ceiling($EstimatedItems / $pageSize) } else { 0 }
    if ($estimatedPages -gt 0) { Write-Verbose "  Estimated pages: $estimatedPages (~$EstimatedItems items)" }

    # Track the last $overlap items from each page for drift detection
    $prevTail = @()

    while ($url)
    {
        $page++
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
                $statusCode = [int]$_.Exception.Response.StatusCode
                if ($statusCode -and $statusCode -lt 500 -and $statusCode -ne 429)
                {
                    throw "HTTP $statusCode on page $page`: $_"
                }

                $retries++
                if ($retries -gt $maxRetries)
                {
                    throw "Failed after $maxRetries retries on page $page`: $_"
                }

                $retryAfter = $_.Exception.Response.Headers['Retry-After']
                $wait = if ($retryAfter) { [int]$retryAfter } else { [Math]::Pow(2, $retries) * 10 }
                $reason = if ($statusCode -eq 429) { 'Rate limited' } else { "HTTP $statusCode" }
                Write-Host "  $reason on page $page, retrying in ${wait}s (attempt $retries/$maxRetries)"
                Start-Sleep -Seconds $wait
            }
        }

        $items = $response.Items
        $newItems = $items

        # Drift detection: verify overlap with previous page
        if ($prevTail.Count -gt 0 -and $items.Count -gt 0)
        {
            $overlapCount = [Math]::Min($prevTail.Count, $items.Count)
            $matched = 0
            for ($i = 0; $i -lt $overlapCount; $i++)
            {
                if ($items[$i].meterId -eq $prevTail[$i].meterId -and $items[$i].skuId -eq $prevTail[$i].skuId)
                {
                    $matched++
                }
                else
                {
                    break
                }
            }

            if ($matched -eq $overlapCount)
            {
                Write-Verbose "  Page ${page}: overlap verified ($matched/$overlapCount items matched)"
            }
            else
            {
                $driftDetected++
                Write-Warning "Drift detected on page $page! Expected overlap of $overlapCount items but only $matched matched."
                Write-Warning "  Expected: $($prevTail[0].meterId) ($($prevTail[0].skuId))"
                Write-Warning "  Got:      $($items[0].meterId) ($($items[0].skuId))"
            }

            # Strip the overlap items so we don't process them twice
            $newItems = $items | Select-Object -Skip $matched
        }

        foreach ($item in $newItems)
        {
            & $OnItem $item
        }

        $totalItems += $newItems.Count

        # Save the last $overlap items for next page's verification
        if ($items.Count -ge $overlap)
        {
            $prevTail = $items[($items.Count - $overlap)..($items.Count - 1)]
        }
        else
        {
            $prevTail = $items
        }

        # Build next page URL with overlap: back up by $overlap items.
        # Advance by actual returned count (minus overlap) to stay aligned even
        # if the API returns fewer items than $top requested.
        if ($response.NextPageLink)
        {
            $skip += [Math]::Max(0, $items.Count - $overlap)
            $url = $apiBase
            if ($Filter) { $url += "&`$filter=$Filter" }
            if ($MeterRegion) { $url += "&meterRegion='$MeterRegion'" }
            if ($OrderBy) { $url += "&`$orderby=$OrderBy" }
            $url += "&`$top=$pageSize&`$skip=$skip"
        }
        else
        {
            $url = $null
        }

        $status = if ($estimatedPages -gt 0) { "Page $page of ~$estimatedPages" } else { "Page $page" }
        if ($estimatedPages -gt 0)
        {
            $pct = [Math]::Min(100, [Math]::Floor($page / $estimatedPages * 100))
            $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
            $secsRemaining = if ($page -gt 0) { ($elapsed / $page) * [Math]::Max(0, $estimatedPages - $page) } else { -1 }
            Write-Progress -Activity $ActivityName -Status $status -PercentComplete $pct -SecondsRemaining $secsRemaining
        }
        else
        {
            Write-Progress -Activity $ActivityName -Status $status
        }
    }

    Write-Progress -Activity $ActivityName -Completed
    $elapsed = ([DateTime]::UtcNow - $startTime).TotalSeconds
    Write-Host "  Done: $totalItems items across $page pages"
    if ($driftDetected -gt 0)
    {
        Write-Warning "  Drift detected on $driftDetected pages -- results may be incomplete"
    }
    Write-Verbose "  Elapsed: $([Math]::Round($elapsed, 1))s ($([Math]::Round($totalItems / [Math]::Max(1, $elapsed), 0)) items/s)"
}

# -----------------------------------------------------------------------
# Step 1: Load existing CSV as a cache to preserve meters not seen this run
# -----------------------------------------------------------------------
$cachedRi = @{}
$cachedSp = @{}
$cachedTotal = 0

if (Test-Path $OutputPath)
{
    Write-Host "Loading existing CSV as cache..."
    Write-Verbose "  Cache file: $OutputPath"
    $existing = Import-Csv -Path $OutputPath
    foreach ($row in $existing)
    {
        $key = $row.MeterId.ToLowerInvariant()
        if ($row.x_CommitmentDiscountSpendEligibility -eq 'Eligible') { $cachedRi[$key] = $true }
        if ($row.x_CommitmentDiscountUsageEligibility -eq 'Eligible') { $cachedSp[$key] = $true }
    }
    $cachedTotal = $existing.Count
    Write-Host "  Cached meters: $cachedTotal (RI: $($cachedRi.Count), SP: $($cachedSp.Count))"
}

# -----------------------------------------------------------------------
# Step 2: Reservation-eligible meters
# -----------------------------------------------------------------------
Write-Host "Fetching Reservation prices..."
$riMeters = @{}

Get-RetailPricePages -Filter "priceType eq 'Reservation'" -MeterRegion 'primary' -OrderBy 'meterId asc, skuId asc' -ActivityName 'Fetching Reservation prices' -EstimatedItems ($cachedRi.Count * 2) -OnItem {
    param($item)
    $key = $item.meterId.ToLowerInvariant()
    if (-not $riMeters.ContainsKey($key))
    {
        $riMeters[$key] = $true
    }
}

Write-Host "  RI-eligible meters: $($riMeters.Count)"

# -----------------------------------------------------------------------
# Step 3: Savings Plan-eligible meters
# The savingsPlan array is embedded in Consumption items, so we page
# through primary Consumption meters and check for its presence.
# -----------------------------------------------------------------------
Write-Host "Fetching Consumption prices (checking for Savings Plan eligibility)..."
$spMeters = @{}

Get-RetailPricePages -Filter "priceType eq 'Consumption'" -MeterRegion 'primary' -OrderBy 'meterId asc, skuId asc' -ActivityName 'Fetching Consumption prices' -EstimatedItems ($cachedTotal * 5) -OnItem {
    param($item)
    if ($item.savingsPlan -and $item.savingsPlan.Count -gt 0)
    {
        $key = $item.meterId.ToLowerInvariant()
        if (-not $spMeters.ContainsKey($key))
        {
            $spMeters[$key] = $true
        }
    }
}

Write-Host "  SP-eligible meters: $($spMeters.Count)"

# -----------------------------------------------------------------------
# Step 4: Merge current run with cache and write output
# -----------------------------------------------------------------------
Write-Host "`nMerging results..."
$mergeStart = [DateTime]::UtcNow
Write-Verbose "  Seen meters: $($riMeters.Count) RI + $($spMeters.Count) SP"

$seenSet = @{}
foreach ($key in $riMeters.Keys) { $seenSet[$key] = $true }
foreach ($key in $spMeters.Keys) { $seenSet[$key] = $true }

$allMeterIds = @{}
foreach ($key in $seenSet.Keys) { $allMeterIds[$key] = $true }
foreach ($key in $cachedRi.Keys) { $allMeterIds[$key] = $true }
foreach ($key in $cachedSp.Keys) { $allMeterIds[$key] = $true }

$sortedIds = [string[]]($allMeterIds.Keys | Sort-Object)

$added = 0
$modified = 0
$preserved = 0
$unchanged = 0

$rows = [System.Collections.ArrayList]::new($sortedIds.Count)
foreach ($meterId in $sortedIds)
{
    $wasCached = $cachedRi.ContainsKey($meterId) -or $cachedSp.ContainsKey($meterId)
    $wasSeen = $seenSet.ContainsKey($meterId)

    if ($wasSeen)
    {
        $ri = if ($riMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
        $sp = if ($spMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }

        if (-not $wasCached) { $added++ }
        elseif (($cachedRi.ContainsKey($meterId)) -ne ($riMeters.ContainsKey($meterId)) -or
            ($cachedSp.ContainsKey($meterId)) -ne ($spMeters.ContainsKey($meterId))) { $modified++ }
        else { $unchanged++ }
    }
    else
    {
        $ri = if ($cachedRi.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
        $sp = if ($cachedSp.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
        $preserved++
    }

    $null = $rows.Add([PSCustomObject]@{
            MeterId                              = $meterId
            x_CommitmentDiscountSpendEligibility = $ri
            x_CommitmentDiscountUsageEligibility = $sp
        })
}

Write-Verbose "  Merge completed in $([Math]::Round(([DateTime]::UtcNow - $mergeStart).TotalSeconds, 1))s"
Write-Host "`nMerge summary:"
Write-Host "  Added:     $added"
Write-Host "  Modified:  $modified"
Write-Host "  Unchanged: $unchanged"
Write-Host "  Preserved: $preserved (not seen this run, kept from cache)"

Write-Verbose "Writing CSV to $OutputPath..."
$writeStart = [DateTime]::UtcNow
$rows | Export-Csv -Path $OutputPath -UseQuotes Always -NoTypeInformation -Encoding utf8
Write-Verbose "  CSV write completed in $([Math]::Round(([DateTime]::UtcNow - $writeStart).TotalSeconds, 1))s"
Write-Host "Wrote $($rows.Count) meters to $OutputPath"
