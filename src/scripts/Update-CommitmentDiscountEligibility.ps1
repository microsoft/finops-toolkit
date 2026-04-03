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
$ProgressPreference = 'SilentlyContinue'  # Speed up Invoke-RestMethod

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
        [scriptblock]$OnItem
    )

    $url = $apiBase
    if ($Filter) { $url += "&`$filter=$Filter" }
    if ($MeterRegion) { $url += "&meterRegion='$MeterRegion'" }

    $page = 0
    $totalItems = 0

    while ($url)
    {
        $page++
        $retries = 0
        $maxRetries = 5

        while ($true)
        {
            try
            {
                $response = Invoke-RestMethod -Uri $url -Method Get
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

        foreach ($item in $response.Items)
        {
            & $OnItem $item
        }

        $totalItems += $response.Items.Count
        $url = $response.NextPageLink

        if ($page % 100 -eq 0)
        {
            Write-Host "  Page $page ($totalItems items so far)"
        }
    }

    Write-Host "  Done: $totalItems items across $page pages"
}

# -----------------------------------------------------------------------
# Step 1: Reservation-eligible meters
# -----------------------------------------------------------------------
Write-Host "Fetching Reservation prices..."
$riMeters = @{}

Get-RetailPricePages -Filter "priceType eq 'Reservation'" -MeterRegion 'primary' -OnItem {
    param($item)
    if (-not $riMeters.ContainsKey($item.meterId))
    {
        $riMeters[$item.meterId] = $true
    }
}

Write-Host "  RI-eligible meters: $($riMeters.Count)"

# -----------------------------------------------------------------------
# Step 2: Savings Plan-eligible meters
# The savingsPlan array is embedded in Consumption items, so we page
# through primary Consumption meters and check for its presence.
# -----------------------------------------------------------------------
Write-Host "Fetching Consumption prices (checking for Savings Plan eligibility)..."
$spMeters = @{}

Get-RetailPricePages -Filter "priceType eq 'Consumption'" -MeterRegion 'primary' -OnItem {
    param($item)
    if ($item.savingsPlan -and $item.savingsPlan.Count -gt 0 -and -not $spMeters.ContainsKey($item.meterId))
    {
        $spMeters[$item.meterId] = $true
    }
}

Write-Host "  SP-eligible meters: $($spMeters.Count)"

# -----------------------------------------------------------------------
# Step 3: Merge and output
# -----------------------------------------------------------------------
$allMeterIds = @($riMeters.Keys) + @($spMeters.Keys) | Select-Object -Unique | Sort-Object

$rows = foreach ($meterId in $allMeterIds)
{
    [PSCustomObject]@{
        MeterId                              = $meterId
        x_CommitmentDiscountSpendEligibility = if ($riMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
        x_CommitmentDiscountUsageEligibility = if ($spMeters.ContainsKey($meterId)) { 'Eligible' } else { 'Not Eligible' }
    }
}

$rows | Export-Csv -Path $OutputPath -UseQuotes Always -NoTypeInformation -Encoding utf8
Write-Host "`nWrote $($rows.Count) meters to $OutputPath"
