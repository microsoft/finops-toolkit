# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Fetches instance size flexibility (ISF) ratios from the Azure Reservations Catalogs API.

    .DESCRIPTION
    Queries the Azure Reservations Catalogs API (Microsoft.Capacity/catalogs) to extract
    instance size flexibility groups and ratios for the supported reserved resource types.
    Outputs a CSV file that can be used as open data for FinOps Hub ingestion, Power BI, and
    the Optimization Engine.

    This replaces the deprecated static ISF CSVs that were hosted on
    ccmstorageprod.blob.core.windows.net (AutofitComboMeterData.csv and isfratioblob.csv),
    which Microsoft is retiring (no updates after 9 May 2026, removed 30 Aug 2026).

    The Catalogs API is authenticated and requires the Microsoft.Capacity/catalogs/read
    permission, so this script must run with an active Azure context (Connect-AzAccount). The
    authentication complexity lives only in this generator -- downstream tools consume the
    resulting public CSV and need no Azure credentials.

    See: https://learn.microsoft.com/azure/cost-management-billing/reservations/instance-size-flexibility#extract-instance-size-flexibility-ratios-using-azure-catalogs-api

    .PARAMETER OutputPath
    Path to the output CSV file. Defaults to src/open-data/InstanceSizeFlexibility.csv.

    .PARAMETER SubscriptionId
    Subscription to use for the Catalogs API call. Defaults to the subscription in the current
    Azure context.

    .PARAMETER Location
    One or more Azure regions to query and union ISF ratios from. Compute ISF group/ratio
    relationships are region-stable, but BlockBlob storage groups are region-specific, so the
    default unions a broad region set to maximize coverage.

    .PARAMETER ReservedResourceType
    One or more reserved resource types to extract ISF ratios for. Default is the four types that
    expose ISF ratios as of 2026-06 (VirtualMachines, BlockBlob, RedisCache, DedicatedHost);
    other reserved types are 1:1 and carry no flexibility groups.

    .PARAMETER ApiVersion
    Catalogs API version. Default = 2022-03-01.

    .PARAMETER Normalize
    Normalize ratios so the smallest SKU in each flexibility group has a ratio of 1. The raw API
    ratios don't always start at 1 (e.g. BS Series starts at 0.25). Default = false, which keeps
    the raw Microsoft ratios for drop-in parity with the deprecated isfratioblob.csv /
    AutofitComboMeterData.csv files that downstream tools (Power BI, Optimization Engine) expect.

    .EXAMPLE
    ./Update-InstanceSizeFlexibility.ps1

    .EXAMPLE
    ./Update-InstanceSizeFlexibility.ps1 -ReservedResourceType VirtualMachines, RedisCache -OutputPath ./output/isf.csv
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/../open-data/InstanceSizeFlexibility.csv",

    [string]$SubscriptionId,

    # ISF group/ratio relationships are region-stable for compute, but BlockBlob storage groups
    # are region-specific, so a broad region set is unioned to maximize coverage.
    [string[]]$Location = @(
        'eastus', 'eastus2', 'westus', 'westus2', 'westus3', 'centralus', 'southcentralus', 'northcentralus',
        'westeurope', 'northeurope', 'uksouth', 'francecentral', 'germanywestcentral', 'swedencentral', 'norwayeast',
        'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'koreacentral', 'centralindia',
        'canadacentral', 'brazilsouth', 'southafricanorth', 'uaenorth'
    ),

    # The reserved resource types that expose ISF ratios (ReservationsAutofitGroup/Ratio). As of
    # 2026-06 only these four do; other reserved types are 1:1 and carry no flexibility groups.
    [string[]]$ReservedResourceType = @('VirtualMachines', 'BlockBlob', 'RedisCache', 'DedicatedHost'),

    [string]$ApiVersion = '2022-03-01',

    [bool]$Normalize = $false
)

$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------
# Step 0: Validate the Azure context (the Catalogs API is authenticated)
# -----------------------------------------------------------------------
$context = Get-AzContext
if (-not $context)
{
    throw "No Azure context found. Run Connect-AzAccount before running this script (the Catalogs API requires Microsoft.Capacity/catalogs/read)."
}

if (-not $SubscriptionId)
{
    $SubscriptionId = $context.Subscription.Id
}
if (-not $SubscriptionId)
{
    throw "No subscription found in the current Azure context. Pass -SubscriptionId or run Set-AzContext."
}
Write-Host "Using subscription $SubscriptionId, $($Location.Count) region(s), types: $($ReservedResourceType -join ', ')"

function Invoke-CatalogsApi
{
    <#
        .SYNOPSIS
        Pages through the Catalogs API for a single reserved resource type and returns all items.
    #>
    param(
        [string]$ResourceType,
        [string]$Region
    )

    $items = [System.Collections.ArrayList]::new()
    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Capacity/catalogs" +
        "?api-version=$ApiVersion&reservedResourceType=$ResourceType&location=$Region"
    $page = 0

    while ($uri)
    {
        $page++
        $retries = 0
        $maxRetries = 5

        # Retry transient failures (network exceptions and 429/5xx) on the SAME page, without
        # advancing the paging loop, so $page counts and the retry cap stay correct.
        $response = $null
        while ($true)
        {
            try
            {
                $response = Invoke-AzRestMethod -Uri $uri -Method GET
            }
            catch
            {
                $retries++
                if ($retries -gt $maxRetries) { throw "Failed after $maxRetries retries on $ResourceType/$Region page $page`: $_" }
                $wait = [Math]::Pow(2, $retries) * 5
                Write-Host "  Error on $ResourceType/$Region page $page, retrying in ${wait}s (attempt $retries/$maxRetries)"
                Start-Sleep -Seconds $wait
                continue
            }

            if ($response.StatusCode -eq 429 -or $response.StatusCode -ge 500)
            {
                $retries++
                if ($retries -gt $maxRetries) { throw "Failed after $maxRetries retries on $ResourceType/$Region page $page (HTTP $($response.StatusCode))" }
                $wait = [Math]::Pow(2, $retries) * 5
                Write-Host "  HTTP $($response.StatusCode) on $ResourceType/$Region page $page, retrying in ${wait}s (attempt $retries/$maxRetries)"
                Start-Sleep -Seconds $wait
                continue
            }
            if ($response.StatusCode -ge 400)
            {
                throw "HTTP $($response.StatusCode) on $ResourceType/$Region page $page`: $($response.Content)"
            }

            break
        }

        $json = $response.Content | ConvertFrom-Json -Depth 100

        # The catalogs API may return a bare array or an object with value/nextLink.
        if ($null -ne $json -and $json.PSObject.Properties.Name -contains 'value')
        {
            $pageItems = $json.value
            $uri = $json.nextLink
        }
        else
        {
            $pageItems = $json
            $uri = $null
        }

        foreach ($item in $pageItems) { $null = $items.Add($item) }
        Write-Verbose "  $ResourceType/$Region page $page`: $($pageItems.Count) items"
    }

    return $items
}

function Get-IsfRecords
{
    <#
        .SYNOPSIS
        Extracts ISF group/ratio records from raw catalog items.
    #>
    param(
        [object[]]$CatalogItems
    )

    $records = [System.Collections.ArrayList]::new()
    foreach ($item in $CatalogItems)
    {
        $flexGroup = $null
        $ratio = $null

        foreach ($property in $item.skuProperties)
        {
            switch ($property.name)
            {
                { $_ -in 'ReservationsAutofitGroup', 'InstanceSizeFlexibilityGroup' } { $flexGroup = $property.value }
                { $_ -in 'ReservationsAutofitRatio', 'InstanceSizeFlexibilityRatio' } { $ratio = $property.value }
            }
        }

        # ArmSkuName is exposed as armSkuName on newer API versions, otherwise the catalog name.
        $armSkuName = if ($item.PSObject.Properties.Name -contains 'armSkuName' -and $item.armSkuName) { $item.armSkuName } else { $item.name }

        # Preview/unreleased SKUs can come back with a placeholder name (e.g.
        # 'arm_sku_name_placeholder'); skip them so they don't leak into the public CSV.
        if ($armSkuName -like '*placeholder*') { continue }

        if ($flexGroup -and $ratio -and $armSkuName)
        {
            $null = $records.Add([PSCustomObject]@{
                    InstanceSizeFlexibilityGroup = [string]$flexGroup
                    ArmSkuName                   = [string]$armSkuName
                    Ratio                        = [double]$ratio
                })
        }
    }

    return $records
}

function Get-NormalizedRecords
{
    <#
        .SYNOPSIS
        Normalizes ratios so the smallest SKU in each flexibility group has a ratio of 1.
    #>
    param(
        [object[]]$Records
    )

    $normalized = [System.Collections.ArrayList]::new()
    foreach ($group in ($Records | Group-Object InstanceSizeFlexibilityGroup))
    {
        $minRatio = ($group.Group | Measure-Object -Property Ratio -Minimum).Minimum
        if (-not $minRatio) { $minRatio = 1 }
        foreach ($item in $group.Group)
        {
            $null = $normalized.Add([PSCustomObject]@{
                    InstanceSizeFlexibilityGroup = $item.InstanceSizeFlexibilityGroup
                    ArmSkuName                   = $item.ArmSkuName
                    Ratio                        = [Math]::Round($item.Ratio / $minRatio, 4)
                })
        }
    }

    return $normalized
}

# -----------------------------------------------------------------------
# Step 1: Load existing CSV as a cache to preserve SKUs not seen this run
# -----------------------------------------------------------------------
$cache = @{}
if (Test-Path $OutputPath)
{
    Write-Host "Loading existing CSV as cache..."
    foreach ($row in (Import-Csv -Path $OutputPath))
    {
        $key = "$($row.InstanceSizeFlexibilityGroup)|$($row.ArmSkuName)"
        $cache[$key] = [PSCustomObject]@{
            InstanceSizeFlexibilityGroup = $row.InstanceSizeFlexibilityGroup
            ArmSkuName                   = $row.ArmSkuName
            Ratio                        = [double]$row.Ratio
        }
    }
    Write-Host "  Cached SKUs: $($cache.Count)"
}

# -----------------------------------------------------------------------
# Step 2: Fetch ISF ratios for each reserved resource type across all regions
# -----------------------------------------------------------------------
$seen = @{}
foreach ($type in $ReservedResourceType)
{
    $typeKeys = @{}
    foreach ($region in $Location)
    {
        try
        {
            $catalogItems = Invoke-CatalogsApi -ResourceType $type -Region $region
        }
        catch
        {
            Write-Warning "  $type/$region failed, skipping: $($_.Exception.Message)"
            continue
        }
        foreach ($record in (Get-IsfRecords -CatalogItems $catalogItems))
        {
            $key = "$($record.InstanceSizeFlexibilityGroup)|$($record.ArmSkuName)"
            $seen[$key] = $record
            $typeKeys[$key] = $true
        }
    }
    Write-Host "  $type`: $($typeKeys.Count) distinct SKUs with ISF ratios across $($Location.Count) region(s)"
}

# -----------------------------------------------------------------------
# Step 3: Merge current run with cache (update seen, preserve unseen)
# -----------------------------------------------------------------------
$added = 0
$modified = 0
$unchanged = 0
$preserved = 0

$merged = @{}
foreach ($key in $cache.Keys) { $merged[$key] = $cache[$key] }
foreach ($key in $seen.Keys)
{
    if (-not $cache.ContainsKey($key))
    {
        $added++
    }
    elseif ([Math]::Round($cache[$key].Ratio, 6) -ne [Math]::Round($seen[$key].Ratio, 6))
    {
        $modified++
    }
    else
    {
        $unchanged++
    }
    $merged[$key] = $seen[$key]
}
$preserved = $merged.Count - $seen.Count

$allRecords = @($merged.Values)

# -----------------------------------------------------------------------
# Step 4: Normalize, sort, and write output
# -----------------------------------------------------------------------
if ($Normalize)
{
    Write-Host "Normalizing ratios (smallest SKU per group = 1)..."
    $allRecords = Get-NormalizedRecords -Records $allRecords
}

$rows = $allRecords | Sort-Object InstanceSizeFlexibilityGroup, ArmSkuName

Write-Host "`nMerge summary:"
Write-Host "  Added:     $added"
Write-Host "  Modified:  $modified"
Write-Host "  Unchanged: $unchanged"
Write-Host "  Preserved: $preserved (not seen this run, kept from cache)"

$rows | Export-Csv -Path $OutputPath -UseQuotes Always -NoTypeInformation -Encoding utf8
Write-Host "Wrote $($rows.Count) SKUs to $OutputPath"
