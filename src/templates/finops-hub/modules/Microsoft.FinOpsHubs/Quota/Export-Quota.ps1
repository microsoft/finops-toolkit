# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#Requires -Version 7.2
<#
.SYNOPSIS
    Collects Azure quota data and writes local CSV files and ingestion manifests.
.DESCRIPTION
    Uses a caller-provided ARM token without changing Azure context. Discovers enabled
    subscriptions and registered providers, follows pagination, and selects the smallest
    VM SKU per subscription, region, and family by vCPU count, then memory.
    Joins the selected SKU with its matching family quota in one row.
    Does not upload files or create ingestion mappings. Source failures produce warnings
    and appear in the returned Sources collection; Complete is false for an incomplete run.
.PARAMETER AccessToken
    ARM bearer token for TenantId, supplied as a SecureString.
.PARAMETER TenantId
    Resource tenant. Must match the token's tid claim.
.PARAMETER OutputDirectory
    Local directory for the generated export folders.
.PARAMETER Location
    Optional region names. Omit to collect all supported regions.
.PARAMETER BillingScope
    Configured billing account or billing profile resource IDs for savings-plan recommendations.
    Omitted scopes are reported as incomplete, not as an empty recommendation response.
.PARAMETER SettingsHash
    SHA256 of the settings file from which the caller read BillingScope.
.PARAMETER SettingsETag
    ETag of that settings file.
.PARAMETER ThrottleLimit
    Maximum concurrent ARM GET requests.
.EXAMPLE
    ./Export-Quota.ps1 -AccessToken $token -TenantId $tenantId `
        -Location eastus -OutputDirectory ./exports
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [securestring] $AccessToken,
    [Parameter(Mandatory)]
    [guid] $TenantId,
    [Parameter(Mandatory)]
    [string] $OutputDirectory,
    [string[]] $Location,
    [ValidatePattern('^/providers/Microsoft\.Billing/billingAccounts/[^/]+(/billingProfiles/[^/]+)?$')]
    [string[]] $BillingScope,
    [string] $SettingsHash,
    [string] $SettingsETag,
    [ValidateRange(1, 32)]
    [int] $ThrottleLimit = 32
)

$ErrorActionPreference = 'Stop'
$started = [datetime]::UtcNow
$totalWatch = [Diagnostics.Stopwatch]::StartNew()
$stageWatch = [Diagnostics.Stopwatch]::StartNew()
$runId = $started.ToString('yyyyMMddTHHmmssZ')
$arm = 'https://management.azure.com'
$payload = ([System.Net.NetworkCredential]::new('', $AccessToken).Password.Split('.'))[1]
$payload = $payload.Replace('-', '+').Replace('_', '/')
$claims = [System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '='))) | ConvertFrom-Json
if ($claims.tid -ne $TenantId.ToString() -or $claims.exp -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
{
    throw 'The ARM token is expired or belongs to a different tenant.'
}
if ($BillingScope -and (-not $SettingsHash -or -not $SettingsETag))
{
    throw 'Supply SettingsHash and SettingsETag from the settings file that defines BillingScope.'
}

function Get-ArmCollection
{
    param ([string] $Uri, [securestring] $Token)

    $items = [System.Collections.Generic.List[object]]::new()
    do
    {
        if (([uri] $Uri).Scheme -ne 'https' -or ([uri] $Uri).Authority -ne 'management.azure.com')
        {
            throw "Unexpected ARM pagination endpoint: $Uri"
        }
        $response = Invoke-RestMethod -Uri $Uri -Authentication Bearer -Token $Token -TimeoutSec 120 -ErrorAction Stop
        if ($response.PSObject.Properties.Name -contains 'value')
        {
            foreach ($item in $response.value) { $items.Add($item) }
        }
        else { $items.Add($response) }
        $Uri = $response.nextLink
    } while ($Uri)
    return $items.ToArray()
}

function Get-ArmResponses
{
    param ([System.Collections.Generic.List[object]] $Requests, [System.Net.Http.HttpClient] $Client, [int] $Limit)

    $active = @{}
    $next = 0
    while ($next -lt $Requests.Count -or $active.Count)
    {
        while ($active.Count -lt $Limit -and $next -lt $Requests.Count)
        {
            $request = $Requests[$next++]
            $active[$Client.GetStringAsync($request.Uri)] = @{
                Request = $request; Uri = $request.Uri; Items = [System.Collections.Generic.List[object]]::new()
            }
        }
        $task = [System.Threading.Tasks.Task]::WhenAny([System.Threading.Tasks.Task[]] @($active.Keys)).GetAwaiter().GetResult()
        $current = $active[$task]
        $active.Remove($task)
        $errorMessage = $null
        try
        {
            $json = $task.GetAwaiter().GetResult()
            $task = $null
            $page = ConvertFrom-Json -InputObject $json -ErrorAction Stop
            $json = $null
            if ($page.PSObject.Properties.Name -contains 'value')
            {
                foreach ($item in $page.value) { $current.Items.Add($item) }
            }
            else { $current.Items.Add($page) }
            if ($page.nextLink)
            {
                $uri = [uri] $page.nextLink
                if ($uri.Scheme -ne 'https' -or $uri.Authority -ne 'management.azure.com')
                {
                    throw "Unexpected ARM pagination endpoint: $uri"
                }
                $current.Uri = $page.nextLink
                $active[$Client.GetStringAsync($current.Uri)] = $current
                $page = $null
                continue
            }
        }
        catch
        {
            $errorMessage = "$($current.Uri): $($_.Exception.Message) $($_.ErrorDetails.Message)"
        }
        $page = $null
        $json = $null
        $task = $null
        $data = @()
        if (-not $errorMessage) { $data = $current.Items.ToArray() }
        @{
            SourceType = $current.Request.SourceType; Scope = $current.Request.Scope
            Location = $current.Request.Location; Provider = $current.Request.Provider
            Uri = $current.Uri; Data = $data; Error = $errorMessage
        }
        $current = $null
    }
}

function Export-QuotaDataset
{
    param (
        [string] $CsvPath, [int] $RowCount, [string] $Scope,
        [string] $Type = 'Quota', [string] $Version = '1.0',
        [string] $ExportName = 'Quota', [string] $BlobName = "quota/$runId/Quota.csv"
    )

    if (-not (Test-Path -LiteralPath $CsvPath)) { throw "Missing CSV for $BlobName." }
    $directory = Split-Path $CsvPath
    $bytes = (Get-Item -LiteralPath $CsvPath).Length
    $manifest = [ordered] @{
        manifestVersion = '2024-04-01'
        byteCount       = $bytes
        blobCount       = 1
        dataRowCount    = $RowCount
        blobs           = @(@{
                blobName = $BlobName; byteCount = $bytes; rowCount = $RowCount
                sha256 = (Get-FileHash -LiteralPath $CsvPath -Algorithm SHA256).Hash.ToLowerInvariant()
            })
        exportConfig    = @{
            exportName  = $ExportName
            resourceId  = "$Scope/providers/Microsoft.CostManagement/exports/$ExportName"
            dataVersion = $Version
            type        = $Type
        }
        runInfo         = @{
            runId     = $runId
            startDate = $started.ToString('o')
            endDate   = [datetime]::UtcNow.ToString('o')
        }
    }
    $manifestPath = Join-Path $directory 'manifest.json'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    [pscustomobject] @{ CsvPath = $CsvPath; ManifestPath = $manifestPath; BlobName = $BlobName; Rows = $RowCount; Bytes = $bytes }
}

function Get-SnapshotHash
{
    param ([string] $Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$columns = @(
    'ProviderName', 'ResourceId', 'ResourceName', 'ResourceType', 'SubAccountId',
    'displayName', 'location', 'currentValue', 'limit', 'unit', 'x_QuotaDetails',
    'x_SourceName', 'x_SourceProvider', 'x_SourceType', 'x_SourceVersion',
    'x_AvailabilityZoneMappings', 'x_Capabilities', 'x_Family', 'x_Kind',
    'x_LocationInfo', 'x_LocationMetadata', 'x_Locations', 'x_RegionalDisplayName',
    'x_Restrictions', 'x_Size', 'x_Tier'
)
$sources = @(
    @('Microsoft.Web', '2024-11-01', 'AppServiceUsage'),
    @('Microsoft.CognitiveServices', '2023-05-01', 'CognitiveServicesUsage'),
    @('Microsoft.Compute', '2024-07-01', 'ComputeUsage'),
    @('Microsoft.HDInsight', '2021-06-01', 'HDInsightUsage'),
    @('Microsoft.MachineLearningServices', '2025-04-01', 'MachineLearningUsage'),
    @('Microsoft.Network', '2025-07-01', 'NetworkUsage'),
    @('Microsoft.Purview', '2021-12-01', 'PurviewUsage'),
    @('Microsoft.Sql', '2023-08-01', 'SqlSubscriptionUsage'),
    @('Microsoft.Storage', '2025-06-01', 'StorageUsage')
)
$recommendationColumns = @(
    'ProviderName', 'ResourceId', 'ResourceName', 'ResourceType', 'SubAccountId', 'SubAccountName',
    'x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings',
    'x_RecommendationId', 'x_RecommendationCategory', 'x_RecommendationDate', 'x_RecommendationDetails',
    'x_SourceName', 'x_SourceProvider', 'x_SourceType', 'x_SourceVersion'
)
$subscriptions = Get-ArmCollection "$arm/subscriptions?api-version=2022-12-01" $AccessToken
$subscriptions = @($subscriptions | Where-Object state -EQ 'Enabled')
if (-not $subscriptions.Count) { throw 'No enabled subscriptions are accessible in the requested scope.' }
Write-Verbose ("Quota timing: subscription discovery {0:N1}s ({1} subscriptions)" -f $stageWatch.Elapsed.TotalSeconds, $subscriptions.Count)
$stageWatch.Restart()

$requests = [System.Collections.Generic.List[object]]::new()
$skuRequests = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$responses = [System.Collections.Generic.List[object]]::new()
$discoveryRequests = [System.Collections.Generic.List[object]]::new()
$pendingDiscovery = @{}
$quotaWriter = $null
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AutomaticDecompression = [System.Net.DecompressionMethods]::All
$httpClient = [System.Net.Http.HttpClient]::new($handler)
$httpClient.Timeout = [TimeSpan]::FromSeconds(120)
$httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
    'Bearer', [System.Net.NetworkCredential]::new('', $AccessToken).Password)
try
{
    foreach ($sub in $subscriptions)
    {
        if ($sub.tenantId -ne $TenantId.ToString()) { throw "Subscription $($sub.subscriptionId) belongs to a different tenant." }
        $scope = "/subscriptions/$($sub.subscriptionId)"
        $discoveryRequests.Add(@{
                SourceType = 'AvailabilityZoneMapping'; Scope = $scope; Location = ''; Provider = 'Microsoft.Resources'
                Uri = "$arm$scope/locations?api-version=2022-12-01"
            })
        $discoveryRequests.Add(@{
                SourceType = 'ProviderMetadata'; Scope = $scope; Location = ''; Provider = 'Microsoft.Resources'
                Uri = "$arm$scope/providers?api-version=2021-04-01"
            })
    }
    Get-ArmResponses $discoveryRequests $httpClient $ThrottleLimit | ForEach-Object {
        $response = $_
        if ($response.Error) { throw $response.Error }
        $scope = $response.Scope
        if (-not $pendingDiscovery.ContainsKey($scope))
        {
            $pendingDiscovery[$scope] = $response
            return
        }
        $pair = $pendingDiscovery[$scope]
        $pendingDiscovery.Remove($scope)
        if ($response.SourceType -eq 'AvailabilityZoneMapping')
        {
            $locations = @($response.Data)
            $providers = @($pair.Data)
        }
        else
        {
            $locations = @($pair.Data)
            $providers = @($response.Data)
        }
        foreach ($requestedLocation in $Location)
        {
            if ($requestedLocation -notin $locations.name) { throw "Location '$requestedLocation' is not listed for $scope." }
        }
        $selectedLocations = @($locations | Where-Object { -not $Location -or $_.name -in $Location })
        $responses.Add(@{
                SourceType = 'AvailabilityZoneMapping'; Scope = $scope; Location = ''
                Provider = 'Microsoft.Resources'; Data = $selectedLocations; Error = $null
            })
        foreach ($source in $sources)
        {
            $provider = $providers | Where-Object namespace -EQ $source[0]
            $supported = @(($provider.resourceTypes | Where-Object resourceType -EQ 'locations/usages').locations)
            $regions = @($selectedLocations | Where-Object {
                    $_.metadata.regionType -eq 'Physical' -and $_.displayName -in $supported
                })
            if ($provider.registrationState -ne 'Registered' -or -not $regions.Count)
            {
                $reason = "Provider $($source[0]) is not registered or has no supported physical regions in the requested scope."
                Write-Warning "$scope/$($source[2]): $reason"
                $results.Add([pscustomobject] @{ SourceType = $source[2]; Scope = $scope; Location = ''; Rows = 0; Error = $reason })
                continue
            }
            foreach ($region in $regions)
            {
                $requests.Add(@{
                        SourceType = $source[2]; Scope = $scope; Location = $region.name; Provider = $source[0]
                        Uri = "$arm$scope/providers/$($source[0])/locations/$($region.name)/usages?api-version=$($source[1])"
                    })
            }
        }
        foreach ($region in $selectedLocations | Where-Object { $_.metadata.regionType -eq 'Physical' })
        {
            $filter = [uri]::EscapeDataString("location eq '$($region.name)'")
            $skuRequests.Add(@{
                    SourceType = 'ComputeResourceSku'; Scope = $scope; Location = $region.name
                    Provider = 'Microsoft.Compute'
                    Uri = "$arm$scope/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=$filter"
                })
        }
    }
    if (-not $skuRequests.Count) { throw 'No physical regions were selected for VM SKU collection.' }
    Write-Verbose ("Quota timing: location/provider discovery {0:N1}s ({1} source requests, {2} SKU requests)" -f $stageWatch.Elapsed.TotalSeconds, $requests.Count, $skuRequests.Count)
    $stageWatch.Restart()
    foreach ($term in 'P1Y', 'P3Y')
    {
        if (-not $BillingScope)
        {
            $reason = 'No billing account or billing profile scope was supplied.'
            Write-Warning "Microsoft-SavingsPlan-${term}: $reason"
            $results.Add([pscustomobject] @{ SourceType = "Microsoft-SavingsPlan-$term"; Scope = ''; Location = ''; Rows = 0; Error = $reason })
        }
        foreach ($scope in $BillingScope | Select-Object -Unique)
        {
            $filter = [uri]::EscapeDataString("properties/lookBackPeriod eq 'Last60Days' and properties/term eq '$term'")
            $requests.Add(@{
                    SourceType = "Microsoft-SavingsPlan-$term"; Scope = $scope; Location = ''
                    Uri = "$arm$scope/providers/Microsoft.CostManagement/benefitRecommendations?api-version=2026-06-01&`$filter=$filter&`$expand=properties/usage,properties/allRecommendationDetails"
                })
        }
    }

    $computeUsage = @{}
    $files = [System.Collections.Generic.List[object]]::new()
    $quotaBlobName = "quota/$runId/Quota.csv"
    $quotaCsvPath = Join-Path $OutputDirectory $quotaBlobName
    $quotaStringColumns = @($columns | Where-Object {
            $_ -notin @('currentValue', 'limit', 'x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings')
        })
    $quotaRowCount = 0
    $null = New-Item -ItemType Directory -Path (Split-Path $quotaCsvPath) -Force
    $quotaWriter = [IO.StreamWriter]::new($quotaCsvPath, $false, [Text.UTF8Encoding]::new($false))
    & {
    $responses
    Get-ArmResponses $requests $httpClient $ThrottleLimit | ForEach-Object {
        if ($_.SourceType -like 'Microsoft-SavingsPlan-*') { $responses.Add($_) }
        else { $_ }
    }
    Write-Verbose ("Quota timing: source fetch and processing {0:N1}s" -f $stageWatch.Elapsed.TotalSeconds)
    $stageWatch.Restart()
    Get-ArmResponses $skuRequests $httpClient $ThrottleLimit
    } | ForEach-Object {
    $response = $_
    if ($response.Error) { Write-Warning $response.Error }
    $records = @($response.Data)
    if ($response.SourceType -eq 'ComputeUsage')
    {
        foreach ($usage in $records)
        {
            $computeUsage["$($response.Scope)|$($response.Location)|$($usage.name.value)"] = $usage
        }
        $records = @()
    }
    elseif ($response.SourceType -eq 'ComputeResourceSku')
    {
        $candidates = foreach ($sku in $records | Where-Object {
                $_.resourceType -eq 'virtualMachines' -and $_.family
            })
        {
            $vcpus = ($sku.capabilities | Where-Object name -EQ 'vCPUs').value
            $memory = ($sku.capabilities | Where-Object name -EQ 'MemoryGB').value
            if ($null -eq $vcpus -or $null -eq $memory) { throw "SKU $($sku.name) has no vCPUs or MemoryGB capability." }
            foreach ($region in $sku.locations | Where-Object { $_ -eq $response.Location })
            {
                $usage = $computeUsage["$($response.Scope)|$region|$($sku.family)"]
                if ($null -eq $usage) { continue }
                [pscustomobject] @{
                    Region = $region; Family = $sku.family; Sku = $sku; Usage = $usage
                    Vcpus = [double]::Parse($vcpus, [cultureinfo]::InvariantCulture)
                    Memory = [double]::Parse($memory, [cultureinfo]::InvariantCulture)
                }
            }
        }
        $records = @($candidates | Group-Object Region, Family | ForEach-Object {
                $_.Group | Sort-Object Vcpus, Memory, { $_.Sku.name } | Select-Object -First 1
            })
    }
    $responseRowCount = 0
    $firstCsvLine = $true
    & {
    foreach ($record in $records)
    {
        $raw = if ($response.SourceType -eq 'ComputeResourceSku') { $record.Sku } else { $record }
        $row = [ordered] @{}
        foreach ($column in $columns) { $row[$column] = $null }
        $row.ProviderName = 'Microsoft'
        $row.SubAccountId = $response.Scope
        $row.ResourceId = $raw.id
        $row.ResourceType = $raw.type
        $row.location = $response.Location
        $row.x_SourceName = 'Azure Resource Manager'
        $row.x_SourceProvider = 'Microsoft'
        $row.x_SourceType = $response.SourceType
        $row.x_SourceVersion = '1.0'
        $row.x_QuotaDetails = ConvertTo-Json -Depth 100 -Compress -InputObject @{
            SchemaVersion = '1.0'; SourceType = $response.SourceType; RunId = $runId; Raw = $raw
        }
        switch ($response.SourceType)
        {
            'AvailabilityZoneMapping'
            {
                $row.ResourceName = $raw.name
                $row.displayName = $raw.displayName
                $row.location = $raw.name
                $row.x_AvailabilityZoneMappings = ConvertTo-Json -InputObject $raw.availabilityZoneMappings -Depth 100 -Compress
                $row.x_LocationMetadata = ConvertTo-Json -InputObject $raw.metadata -Depth 100 -Compress
                $row.x_RegionalDisplayName = $raw.regionalDisplayName
            }
            'ComputeResourceSku'
            {
                $row.ResourceName = $raw.name
                $row.ResourceType = $raw.resourceType
                $row.displayName = $raw.name
                $row.location = $record.Region
                if (-not $row.ResourceId) { $row.ResourceId = "$($response.Scope)/providers/Microsoft.Compute/locations/$($record.Region)/skus/$($raw.name)" }
                $row.currentValue = $record.Usage.currentValue
                $row.limit = $record.Usage.limit
                $row.unit = $record.Usage.unit
                $row.x_Family = $raw.family
                $row.x_Kind = $raw.kind
                $row.x_Size = $raw.size
                $row.x_Tier = $raw.tier
                $row.x_Capabilities = ConvertTo-Json -InputObject $raw.capabilities -Depth 100 -Compress
                $row.x_Locations = ConvertTo-Json -InputObject @($record.Region) -Compress
                $row.x_LocationInfo = ConvertTo-Json -InputObject @($raw.locationInfo | Where-Object location -EQ $record.Region) -Depth 100 -Compress
                $row.x_Restrictions = ConvertTo-Json -InputObject @($raw.restrictions | Where-Object {
                        $record.Region -in $_.values -or $record.Region -in $_.restrictionInfo.locations
                    }) -Depth 100 -Compress
            }
            default
            {
                $isSql = $response.SourceType -eq 'SqlSubscriptionUsage'
                $usage = if ($isSql) { $raw.properties } else { $raw }
                $row.ResourceName = if ($isSql) { $raw.name } else { $raw.name.value }
                $row.displayName = if ($isSql) { $usage.displayName } else { $raw.name.localizedValue }
                $row.currentValue = $usage.currentValue
                $row.limit = $usage.limit
                $row.unit = $usage.unit
                if (-not $row.ResourceType) { $row.ResourceType = "$($response.Provider)/locations/usages" }
                if (-not $row.ResourceId) { $row.ResourceId = "$($response.Scope)/providers/$($response.Provider)/locations/$($response.Location)/usages/$($row.ResourceName)" }
            }
        }
        [pscustomobject] $row
    }
    } | Select-Object $columns | ConvertTo-Csv -NoTypeInformation -QuoteFields $quotaStringColumns |
        ForEach-Object {
            if ($firstCsvLine)
            {
                $firstCsvLine = $false
                if ($quotaRowCount -eq 0) { $quotaWriter.WriteLine($_) }
            }
            else
            {
                $quotaWriter.WriteLine($_)
                $quotaRowCount++
                $responseRowCount++
            }
        }
    $results.Add([pscustomobject] @{
            SourceType = $response.SourceType; Scope = $response.Scope; Location = $response.Location
            Rows = $responseRowCount; Error = $response.Error
        })
}
}
finally
{
    if ($quotaWriter) { $quotaWriter.Dispose() }
    $httpClient.Dispose()
}
Write-Verbose ("Quota timing: regional SKU fetch and processing {0:N1}s ({1} Quota rows)" -f $stageWatch.Elapsed.TotalSeconds, $quotaRowCount)
$stageWatch.Restart()

if ($quotaRowCount)
{
    $scope = if ($subscriptions.Count -eq 1) { "/subscriptions/$($subscriptions[0].subscriptionId)" } else { '' }
    $files.Add((Export-QuotaDataset -CsvPath $quotaCsvPath -RowCount $quotaRowCount -Scope $scope))
}
Write-Verbose ("Quota timing: Quota manifest {0:N1}s" -f $stageWatch.Elapsed.TotalSeconds)
$stageWatch.Restart()
foreach ($response in $responses | Where-Object { $_.SourceType -like 'Microsoft-SavingsPlan-*' })
{
    if ($response.Error) { Write-Warning $response.Error }
    foreach ($group in $response.Data | Group-Object { $_.properties.scope })
    {
        if (-not $group.Name) { throw "Savings-plan response has no scope: $($response.Uri)" }
        $term = $response.SourceType.Split('-')[-1].ToLowerInvariant()
        $partition = (Get-SnapshotHash $response.Scope.ToLowerInvariant()) + "-$($group.Name.ToLowerInvariant())-60d-$term"
        $idHashes = @($group.Group | ForEach-Object { Get-SnapshotHash $_.id.ToLowerInvariant() } | Sort-Object)
        $snapshotHash = Get-SnapshotHash ($idHashes -join "`n")
        $recommendations = @(foreach ($raw in $group.Group)
            {
                $properties = $raw.properties
                $subAccountId = ''
                if ($properties.scope -eq 'Single')
                {
                    if (-not $properties.subscriptionId) { throw "Single-scope recommendation $($raw.id) has no subscription ID." }
                    $subAccountId = "/subscriptions/$($properties.subscriptionId)"
                }
                $details = [ordered] @{
                    x_ArmSkuName               = $properties.armSkuName
                    x_Term                     = $properties.term
                    x_Scope                    = $properties.scope
                    x_LookBackPeriod           = $properties.lookBackPeriod
                    x_CurrencyCode             = $properties.currencyCode
                    x_CommitmentGranularity    = $properties.commitmentGranularity
                    x_FirstConsumptionDate     = $properties.firstConsumptionDate
                    x_LastConsumptionDate      = $properties.lastConsumptionDate
                    x_TotalHours               = $properties.totalHours
                    x_RecommendationDetails    = $properties.recommendationDetails
                    x_AllRecommendationDetails = $properties.allRecommendationDetails.value
                    x_Usage                    = $properties.usage
                    x_Raw                      = $raw
                    x_CollectionScope          = $response.Scope
                    x_SettingsHash             = $SettingsHash
                    x_SettingsETag             = $SettingsETag
                    x_TenantId                 = $TenantId.ToString()
                    x_RunId                    = $runId
                    x_Partition                = $partition
                    x_SnapshotRowCount         = $group.Count
                    x_SnapshotIdHash           = $snapshotHash
                }
                [pscustomobject] @{
                    ProviderName = 'Microsoft'
                    ResourceId = if ($subAccountId) { $subAccountId } else { $response.Scope }
                    ResourceName = ''; ResourceType = ''; SubAccountId = $subAccountId; SubAccountName = ''
                    x_EffectiveCostBefore = $properties.costWithoutBenefit
                    x_EffectiveCostAfter = $properties.recommendationDetails.totalCost
                    x_EffectiveCostSavings = $properties.recommendationDetails.savingsAmount
                    x_RecommendationId = $raw.id; x_RecommendationCategory = 'Cost'
                    x_RecommendationDate = $started.ToString('o')
                    x_RecommendationDetails = ConvertTo-Json -InputObject $details -Depth 100 -Compress
                    x_SourceName = 'Cost Management'; x_SourceProvider = 'Microsoft'
                    x_SourceType = 'SavingsPlan'; x_SourceVersion = '2026-06-01'
                }
            })
        $blobName = "savings-plan/$runId/$partition/SavingsPlan.csv"
        $csvPath = Join-Path $OutputDirectory $blobName
        $null = New-Item -ItemType Directory -Path (Split-Path $csvPath) -Force
        $stringColumns = @($recommendationColumns | Where-Object {
                $_ -notin @('x_EffectiveCostBefore', 'x_EffectiveCostAfter', 'x_EffectiveCostSavings')
            })
        $recommendations | Select-Object $recommendationColumns | ConvertTo-Csv -NoTypeInformation -QuoteFields $stringColumns |
            Set-Content -LiteralPath $csvPath -Encoding utf8NoBOM
        $files.Add((Export-QuotaDataset -CsvPath $csvPath -RowCount $recommendations.Count `
                    -Scope $response.Scope -Type Recommendations -Version '1.0-savingsplan' `
                    -ExportName "SavingsPlan-$partition" -BlobName $blobName))
    }
    $results.Add([pscustomobject] @{
            SourceType = $response.SourceType; Scope = $response.Scope; Location = ''
            Rows = $response.Data.Count; Error = $response.Error
        })
}
Write-Verbose ("Quota timing: savings-plan output {0:N1}s; total {1:N1}s" -f $stageWatch.Elapsed.TotalSeconds, $totalWatch.Elapsed.TotalSeconds)
[pscustomobject] @{
    RunId = $runId
    TenantId = $TenantId.ToString()
    Complete = @($results | Where-Object Error).Count -eq 0
    Sources = $results.ToArray()
    Files = $files.ToArray()
}
