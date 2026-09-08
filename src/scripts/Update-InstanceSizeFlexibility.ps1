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

    The file is merged into, not replaced. The Catalogs API only returns SKUs that are still
    purchasable, so retired series (Av2, D/DS v1, Dv2, F, G, H, NC, NV, ...) are absent from it
    even though customers still hold active reservations covering them. The published file is
    therefore the floor that keeps those groups in the dataset, and the run fails rather than
    publishing a smaller one.

    .PARAMETER SubscriptionId
    Subscription to use for the Catalogs API call. Defaults to the subscription in the current
    Azure context.

    .PARAMETER Location
    One or more Azure regions to query and union ISF ratios from. ISF group/ratio relationships
    are region-stable, but not every SKU is available in every region, so the results are unioned
    across regions to maximize SKU coverage.

    Defaults to every physical region the subscription's cloud exposes, enumerated from the ARM
    locations API. A hardcoded list has to be hand-maintained as Azure adds regions, and new GPU
    and specialty SKUs routinely launch in a handful of regions first, so any SKU that lands
    outside the list is missing from the dataset until someone notices. That is no longer
    recoverable now that the retired blob can't backfill it. Pass an explicit list to narrow the
    sweep (tests do).

    .PARAMETER ReservedResourceType
    One or more reserved resource types to extract ISF ratios for. Default is VirtualMachines,
    RedisCache, and DedicatedHost. BlockBlob is intentionally excluded: its catalog entries carry
    no real ARM SKU names (only meter-style catalog names), every ratio is 1, and its groups are
    region-specific, which would break the guarantee that ArmSkuName is unique across the output.
    Pass it explicitly if you need it. Other reserved types are 1:1 and carry no flexibility
    groups.

    .PARAMETER ApiVersion
    Catalogs API version. Default = 2022-03-01.

    .PARAMETER LocationApiVersion
    ARM locations API version, used only when -Location is not supplied. Default = 2022-12-01.

    .PARAMETER Normalize
    Normalize ratios so the smallest SKU in each flexibility group has a ratio of 1. The raw API
    ratios don't always start at 1 (e.g. BS Series starts at 0.25). When omitted, the raw Microsoft
    ratios are kept.

    Note that raw API ratios are NOT on the same scale as the retired isfratioblob.csv: the blob
    normalized each group to smallest-SKU-=-1, the API returns unnormalized values, and the two
    differ by a per-group constant (usually 2x -- e.g. Standard_DS11_v2 is 1 in the blob and 2 in
    the API). The published dataset was migrated onto the API scale once, so ratios are the API's
    verbatim wherever it has an opinion. Ratios are only ever compared within a flexibility group.

    The groups the API doesn't cover at all -- the fully retired series, roughly a third of the
    dataset -- necessarily keep the blob's normalized scale, because there is no API value to
    reconcile them against. That is harmless as long as ratios stay within their group.

    .EXAMPLE
    ./Update-InstanceSizeFlexibility.ps1

    .EXAMPLE
    ./Update-InstanceSizeFlexibility.ps1 -ReservedResourceType VirtualMachines, RedisCache -OutputPath ./output/isf.csv
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/../open-data/InstanceSizeFlexibility.csv",

    [string]$SubscriptionId,

    # Defaults to every physical region the subscription's cloud exposes -- see the parameter help.
    [string[]]$Location,

    # The reserved resource types that expose usable ISF ratios (ReservationsAutofitGroup/Ratio).
    # BlockBlob is excluded by default -- see the parameter help above.
    [string[]]$ReservedResourceType = @('VirtualMachines', 'RedisCache', 'DedicatedHost'),

    [string]$ApiVersion = '2022-03-01',

    [string]$LocationApiVersion = '2022-12-01',

    [switch]$Normalize
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
if (-not $Location)
{
    # Physical regions only: the response also carries logical groupings ('global', 'unitedstates',
    # 'europe', 'asiapacific'), which are not valid catalog scopes -- 46 of the 109 entries at the
    # time of writing. Note regionType is nested under metadata, not at the top level.
    # Az.Accounts is the only module the workflow installs, so this uses the REST API rather than
    # Get-AzLocation, which lives in Az.Resources.
    $locationsUri = "https://management.azure.com/subscriptions/$SubscriptionId/locations?api-version=$LocationApiVersion"
    $locationsResponse = Invoke-AzRestMethod -Uri $locationsUri -Method GET
    if ($locationsResponse.StatusCode -ge 400)
    {
        throw "HTTP $($locationsResponse.StatusCode) enumerating regions: $($locationsResponse.Content)"
    }

    $Location = @(
        ($locationsResponse.Content | ConvertFrom-Json -Depth 20).value |
            Where-Object { $_.metadata.regionType -eq 'Physical' } |
            Select-Object -ExpandProperty name
    )

    # Sweeping fewer regions than intended silently drops SKUs, so treat an empty result as fatal
    # rather than falling back to a partial sweep.
    if (-not $Location)
    {
        throw "Region enumeration returned no physical regions for subscription $SubscriptionId. Pass -Location explicitly to override."
    }
    Write-Host "Enumerated $($Location.Count) physical region(s) from the ARM locations API"
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

        # A ratio of 0 carries no flexibility information and consumers divide by it -- the
        # Optimization Engine's benefits simulation does exactly that -- so drop it rather than
        # publish a division by zero. The API returns one today (Azure Redis Cache Isolated).
        $parsedRatio = 0.0
        if ($flexGroup -and $armSkuName -and [double]::TryParse($ratio, [ref]$parsedRatio) -and $parsedRatio -gt 0)
        {
            $null = $records.Add([PSCustomObject]@{
                    InstanceSizeFlexibilityGroup = [string]$flexGroup
                    ArmSkuName                   = [string]$armSkuName
                    Ratio                        = $parsedRatio
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

function Import-IsfCsv
{
    <#
        .SYNOPSIS
        Reads an ISF CSV into records, dropping rows that cannot serve as usable open data.

        .DESCRIPTION
        Drops rows with a blank, non-numeric or non-positive ratio, and drops every row for an
        ArmSkuName that the file maps to more than one flexibility group, which would break the
        ArmSkuName join key that Power BI's model relationship and the Optimization Engine's
        externaldata() joins both depend on.
    #>
    param(
        [string]$Path
    )

    $records = [System.Collections.ArrayList]::new()
    if (-not $Path -or -not (Test-Path $Path)) { return $records }

    $rows = Import-Csv -Path $Path
    $groupsPerSku = @{}
    foreach ($row in $rows)
    {
        $ratio = 0.0
        if (-not [double]::TryParse($row.Ratio, [ref]$ratio)) { continue }
        if ($ratio -le 0) { continue }
        if (-not $groupsPerSku.ContainsKey($row.ArmSkuName)) { $groupsPerSku[$row.ArmSkuName] = @{} }
        $groupsPerSku[$row.ArmSkuName][$row.InstanceSizeFlexibilityGroup] = $true
    }

    foreach ($row in $rows)
    {
        $ratio = 0.0
        if (-not [double]::TryParse($row.Ratio, [ref]$ratio)) { continue }
        if ($ratio -le 0) { continue }
        if ($groupsPerSku[$row.ArmSkuName].Count -gt 1) { continue }
        # Same placeholder filter the API path applies, so a retired file's placeholder rows
        # can't linger in the published dataset.
        if ($row.ArmSkuName -like '*placeholder*') { continue }
        $null = $records.Add([PSCustomObject]@{
                InstanceSizeFlexibilityGroup = [string]$row.InstanceSizeFlexibilityGroup
                ArmSkuName                   = [string]$row.ArmSkuName
                Ratio                        = $ratio
            })
    }

    return $records
}

# -----------------------------------------------------------------------
# Step 1: Fetch ISF ratios for each reserved resource type across all regions
# -----------------------------------------------------------------------
# The dataset is additive: the API result is merged over the previously published file. The API
# only returns SKUs that are still purchasable, so a destructive write drops retired series that
# customers still hold reservations against (issue #2300). Any scope that still fails after
# retries aborts the whole run without touching the output file; the weekly workflow then fails
# and the last published dataset stays as-is.
$seen = @{}
foreach ($type in $ReservedResourceType)
{
    $typeKeys = @{}
    foreach ($region in $Location)
    {
        $catalogItems = Invoke-CatalogsApi -ResourceType $type -Region $region
        foreach ($record in (Get-IsfRecords -CatalogItems $catalogItems))
        {
            $key = "$($record.InstanceSizeFlexibilityGroup)|$($record.ArmSkuName)"
            $seen[$key] = $record
            $typeKeys[$key] = $true
        }
    }
    Write-Host "  $type`: $($typeKeys.Count) distinct SKUs with ISF ratios across $($Location.Count) region(s)"
}

$apiRecords = @($seen.Values)

# ArmSkuName is documented as a safe standalone join key, so fail hard if the API ever returns
# the same SKU in multiple flexibility groups instead of silently publishing ambiguous data.
$duplicateSkus = $apiRecords | Group-Object ArmSkuName | Where-Object Count -gt 1
if ($duplicateSkus)
{
    throw "Duplicate ArmSkuName values across flexibility groups: $($duplicateSkus.Name -join ', '). ArmSkuName must stay unique; investigate before publishing."
}

function Assert-IsfScale
{
    <#
        .SYNOPSIS
        Fails the run if a carried-forward group sits on a different ratio scale than the API.

        .DESCRIPTION
        The Catalogs API returns unnormalized ratios, while the ratio files it replaced
        normalized each group so its smallest SKU was 1. Both encode the same proportions in
        different units, differing by a per-group constant. Those units were reconciled once, in a
        one-time migration, so every published record now sits on the API scale.

        Azure retires individual sizes rather than whole families, so the API commonly returns only
        part of a group. If a carried-forward record were ever on the other scale, the group would
        silently mix units -- Ev3 Series ending up with Standard_E2_v3 at 2 from the API next to
        Standard_E4_v3 at 2 from the older file, which is not just wrong but non-monotonic.

        Scale mismatches are large (the observed factors run from 2x to 80x) while a genuine ratio
        correction from Microsoft is small and should simply be taken, so this compares the median
        factor across the SKUs a group shares with the API and only fails on a scale-sized gap.
    #>
    param(
        [object[]]$Published,
        [object[]]$Api,

        # Well above any plausible ratio correction, well below the smallest observed unit change.
        [double]$MaxFactor = 1.5
    )

    $apiByGroup = @{}
    foreach ($record in $Api)
    {
        if (-not $apiByGroup.ContainsKey($record.InstanceSizeFlexibilityGroup))
        {
            $apiByGroup[$record.InstanceSizeFlexibilityGroup] = @{}
        }
        $apiByGroup[$record.InstanceSizeFlexibilityGroup][$record.ArmSkuName] = $record.Ratio
    }

    $conflicts = [System.Collections.ArrayList]::new()
    foreach ($group in ($Published | Group-Object InstanceSizeFlexibilityGroup))
    {
        if (-not $apiByGroup.ContainsKey($group.Name)) { continue }

        $apiRatios = $apiByGroup[$group.Name]
        $observed = @(
            $group.Group |
                Where-Object { $_.Ratio -and $apiRatios.ContainsKey($_.ArmSkuName) } |
                ForEach-Object { $apiRatios[$_.ArmSkuName] / $_.Ratio }
        )
        if ($observed.Count -eq 0) { continue }

        $sorted = @($observed | Sort-Object)
        $factor = $sorted[[Math]::Floor($sorted.Count / 2)]
        if ($factor -gt $MaxFactor -or $factor -lt (1 / $MaxFactor))
        {
            $null = $conflicts.Add("$($group.Name) (published ratios are $([Math]::Round($factor, 3))x off the API)")
        }
    }

    if ($conflicts.Count -gt 0)
    {
        throw "These flexibility groups are on a different ratio scale than the Catalogs API, so merging them would publish one group in two units: $($conflicts -join '; '). The published dataset was migrated onto the API scale once; re-migrate these groups instead of publishing."
    }
}

# -----------------------------------------------------------------------
# Step 2: Merge over the previously published file
# -----------------------------------------------------------------------
# Keyed on ArmSkuName, lowest precedence first, so the live API wins wherever it has an opinion
# and rows it no longer returns are carried forward instead of dropped. Carried-forward records
# were migrated onto the API's scale once, and the check below keeps them there.
$publishedRecords = @(Import-IsfCsv -Path $OutputPath)
Assert-IsfScale -Published $publishedRecords -Api $apiRecords

$merged = [ordered]@{}
$sources = @(
    @{ Name = 'published'; Records = $publishedRecords }
    @{ Name = 'API'; Records = $apiRecords }
)
foreach ($source in $sources)
{
    $added = 0
    $updated = 0
    foreach ($record in $source.Records)
    {
        if ($merged.Contains($record.ArmSkuName)) { $updated++ } else { $added++ }
        $merged[$record.ArmSkuName] = $record
    }
    Write-Host "  $($source.Name): $($source.Records.Count) records ($added new, $updated superseding an earlier source)"
}

$allRecords = @($merged.Values)
Write-Host "Merged to $($allRecords.Count) SKUs across $(($allRecords | Group-Object InstanceSizeFlexibilityGroup).Count) flexibility groups"

# The merge is keyed on ArmSkuName and every source is filtered to one group per SKU, so this can
# only fire if that changes. Keep the invariant checked rather than assumed.
$duplicateSkus = $allRecords | Group-Object ArmSkuName | Where-Object Count -gt 1
if ($duplicateSkus)
{
    throw "Duplicate ArmSkuName values after merge: $($duplicateSkus.Name -join ', '). ArmSkuName must stay unique; investigate before publishing."
}

# The published dataset must never shrink: downstream consumers join on SKUs that may no longer be
# purchasable but are still covered by active reservations.
$previousCount = (Import-IsfCsv -Path $OutputPath).Count
if ($allRecords.Count -lt $previousCount)
{
    throw "Merged output has $($allRecords.Count) SKUs but the published file has $previousCount. The dataset must not shrink; investigate before publishing."
}

# -----------------------------------------------------------------------
# Step 3: Normalize, sort, and write output
# -----------------------------------------------------------------------
if ($Normalize)
{
    Write-Host "Normalizing ratios (smallest SKU per group = 1)..."
    $allRecords = Get-NormalizedRecords -Records $allRecords
}

$rows = $allRecords | Sort-Object InstanceSizeFlexibilityGroup, ArmSkuName

$rows | Export-Csv -Path $OutputPath -UseQuotes Always -NoTypeInformation -Encoding utf8
Write-Host "Wrote $($rows.Count) SKUs to $OutputPath"
