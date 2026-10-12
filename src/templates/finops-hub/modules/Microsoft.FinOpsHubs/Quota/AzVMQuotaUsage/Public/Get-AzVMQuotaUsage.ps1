# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

<#
.SYNOPSIS
    Concurrent Azure quota analysis that queries resource provider quota usage, compute resource SKU availability,
    availability zone restrictions and mappings, capacity reservation groups, and disks across subscriptions.

.DESCRIPTION
    Analyzes Azure quota usage and VM availability zone restrictions across all subscriptions
    the ARM bearer token can access and all physical Azure regions. It provides detailed information about:
    - Current quota usage vs. limits for all usage entries of Compute, App Service, Cognitive Services,
      HDInsight, Machine Learning, Network, PostgreSQL flexible servers, Purview, SQL, and Storage,
      such as VM families, regional vCPUs, and disks
    - Available and restricted physical availability zones per SKU
    - Region-level restrictions for specific VM SKUs
    - Logical-to-physical availability zone mappings of each subscription location
    - Capacity reservation groups and disks, such as Premium SSD v2 disks, of each subscription

    Quota is written at the family level on usage rows and restrictions at the SKU level on SKU rows.
    Join them on the SKU family, which matches the ResourceName of the family's ComputeUsage row.
    Sends concurrent ARM requests for all subscriptions and regions through one HTTP client.
    Zones are always reported as physical zones for cross-subscription deployment planning.
    Uses Azure Resource Manager REST calls only; does not use or change Azure PowerShell context.

.PARAMETER AccessToken
    ARM bearer token with Reader access to the target subscriptions.

.PARAMETER SKUs
    Array of VM SKU names to write SKU rows for. If not specified, uses all VM SKUs returned for each region.
    The smallest SKU of each family is found from these SKUs only. Does not limit usage rows.
    Example: @('Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_E4s_v5')

.PARAMETER ConcurrentSubscriptions
    Maximum number of subscriptions scanned at a time.

.PARAMETER ConcurrentRequests
    Maximum number of ARM requests in flight within each subscription.
    Higher values speed up execution but may hit API rate limits.

.PARAMETER OutputFile
    Name of the output CSV file containing the analysis results.

.PARAMETER AsCsv
    Streams the CSV header and rows to the caller instead of writing a local file.
    The caller can upload completed files during collection.

.EXAMPLE
    Import-Module ./AzVMQuotaUsage/AzVMQuotaUsage.psm1
    $token = ConvertTo-SecureString (az account get-access-token --resource https://management.azure.com --query accessToken -o tsv) -AsPlainText -Force
    Get-AzVMQuotaUsage -AccessToken $token -SKUs @('Standard_D2s_v5','Standard_E4s_v5')
    
    Analyzes specific VM SKUs in all physical regions across all accessible subscriptions.

.EXAMPLE
    Get-AzVMQuotaUsage -AccessToken $token -ConcurrentRequests 16 -OutputFile "MyQuotaAnalysis.csv"
    
    Runs full analysis with up to 16 ARM requests in flight within each subscription.

.NOTES
    Requires an ARM bearer token with Reader access to target subscriptions.
    Output CSV contains the Quota columns: ProviderName, ResourceId, ResourceName, ResourceType, SubAccountId,
    displayName, location, currentValue, limit, unit, x_QuotaDetails, x_SourceName, x_SourceProvider,
    x_SourceType, x_SourceVersion.     ComputeResourceSku rows (one for the smallest VM SKU of each family, and one
        for each other SKU of the family with different zones or restrictions) hold Family, Tier, Size,
        RegionRestricted, RegionRestrictedReasonCode, ZonesPresent, ZonesRestricted, and ZonesRestrictedReasonCode
        as JSON in x_QuotaDetails, with empty currentValue, limit, and unit. Usage rows (one per usage
        entry of each provider) hold the quota and unit, and every other API field that has no column (such as Id, Type,
        and IsAdjustable) in x_QuotaDetails.
    Their x_SourceType is ComputeUsage, AppServiceUsage, CognitiveServicesUsage, HDInsightUsage, MachineLearningUsage,
    NetworkUsage, PostgreSqlUsage, PurviewUsage, SqlSubscriptionUsage, or StorageUsage.
    Resource rows (one per subscription location, capacity reservation group, and disk) hold the ARM resource ID, name,
    and type, and every other API field (such as AvailabilityZoneMappings, Sku, and
    Properties) in x_QuotaDetails. Their x_SourceType is AvailabilityZoneMapping, CapacityReservation, or
    PremiumSSDv2Disk. Disk rows hold the disk SKU in displayName and the disk size in GiB in currentValue.
    Every row has a unique ResourceId.
#>
function Get-AzVMQuotaUsage {
    [CmdletBinding(DefaultParameterSetName = 'File')]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "ARM bearer token")]
        [securestring]$AccessToken,

        [Parameter(Mandatory = $false, HelpMessage = "e.g. @('Standard_D2s_v3', 'Standard_D4s_v3')")]
        [string[]]$SKUs = @(),

        [Parameter(Mandatory = $false, HelpMessage = "Maximum subscriptions scanned at a time")]
        [ValidateRange(1, 2147483647)]
        [int]$ConcurrentSubscriptions = 64,

        [Parameter(Mandatory = $false, HelpMessage = "Maximum ARM requests in flight within each subscription")]
        [ValidateRange(1, 32)]
        [int]$ConcurrentRequests = 16,

        [Parameter(ParameterSetName = 'File', HelpMessage = "Output file name")]
        [string]$OutputFile = "QuotaQuery.csv",

        [Parameter(Mandatory, ParameterSetName = 'Rows')]
        [switch]$AsCsv
    )

    # Set error handling and output preferences
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'SilentlyContinue'
    $begin = Get-Date

    # Define CSV header structure for output file
    $csvHeaderString = "ProviderName,ResourceId,ResourceName,ResourceType,SubAccountId,displayName,location,currentValue,limit,unit,x_QuotaDetails,x_SourceName,x_SourceProvider,x_SourceType,x_SourceVersion"

    # List all accessible subscriptions and physical locations
    $subscriptions = @(Get-Subscriptions -AccessToken $AccessToken)
    if (-not $subscriptions.Count) { throw 'No accessible subscriptions were returned by ARM.' }
    $Locations = Get-Locations -SubscriptionId $subscriptions[0].subscriptionId -AccessToken $AccessToken | Sort-Object

    $skuScope = if ($SKUs.Count -eq 0) { 'all VM SKUs' } else { "$($SKUs.Count) SKUs" }
    Write-Host "Querying $($subscriptions.Count) subscriptions with $skuScope in $($Locations.Count) locations with up to $ConcurrentSubscriptions subscriptions at a time and $ConcurrentRequests requests in flight each"

    # Use one HTTP client for all concurrent ARM requests
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::All
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(120)
    $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
        'Bearer', [System.Net.NetworkCredential]::new('', $AccessToken).Password)
    $writer = $null
    $collectionFailure = $null
    try {
        if ($AsCsv) { $csvHeaderString }
        else {
            $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
            $writer = [IO.StreamWriter]::new($outputPath, $false, [Text.UTF8Encoding]::new($false))
            $writer.WriteLine($csvHeaderString)
        }

        $usageSources = @(
            @{ Provider = 'Microsoft.Compute'; ApiVersion = '2024-07-01'; SourceType = 'ComputeUsage' }
            @{ Provider = 'Microsoft.Web'; ApiVersion = '2024-11-01'; SourceType = 'AppServiceUsage' }
            @{ Provider = 'Microsoft.CognitiveServices'; ApiVersion = '2023-05-01'; SourceType = 'CognitiveServicesUsage' }
            @{ Provider = 'Microsoft.HDInsight'; ApiVersion = '2021-06-01'; SourceType = 'HDInsightUsage' }
            @{ Provider = 'Microsoft.MachineLearningServices'; ApiVersion = '2025-04-01'; SourceType = 'MachineLearningUsage' }
            @{ Provider = 'Microsoft.Network'; ApiVersion = '2025-07-01'; SourceType = 'NetworkUsage' }
            @{ Provider = 'Microsoft.Purview'; ApiVersion = '2021-12-01'; SourceType = 'PurviewUsage' }
            @{ Provider = 'Microsoft.Sql'; ApiVersion = '2023-08-01'; SourceType = 'SqlSubscriptionUsage' }
            @{ Provider = 'Microsoft.Storage'; ApiVersion = '2025-06-01'; SourceType = 'StorageUsage' }
            @{ Provider = 'Microsoft.DBforPostgreSQL'; ApiVersion = '2026-04-01-preview'; SourceType = 'PostgreSqlUsage'; UsagePath = 'resourceType/flexibleServers/usages'; ResourceType = 'Microsoft.DBforPostgreSQL/locations/resourceType/usages' }
        )

        # Each invocation owns only this batch's queues, responses, and zone mappings.
        for ($offset = 0; $offset -lt $subscriptions.Count; $offset += $ConcurrentSubscriptions) {
            & {
                param([object[]]$batch)

                $zoneRequests = [System.Collections.Generic.List[object]]::new()
                foreach ($subscription in $batch) {
                    $zoneRequests.Add(@{ Subscription = $subscription; Path = "/subscriptions/$($subscription.subscriptionId)/locations?api-version=2022-12-01" })
                }
                $zoneMappings = @{}
                Get-ArmResponses $zoneRequests $client $ConcurrentSubscriptions $ConcurrentRequests | ForEach-Object {
                    $subscriptionId = $PSItem.Request.Subscription.subscriptionId
                    if ($PSItem.Error -or $PSItem.Data.Count -eq 0) {
                        Write-Host "No Zone Peering Information found for subscription $subscriptionId $($PSItem.Error)" -ForegroundColor Yellow
                    }
                    foreach ($region in $PSItem.Data | Where-Object { $_.type -eq 'Region' }) {
                        $zoneMappings["$subscriptionId|$($region.name)"] = $region.availabilityZoneMappings
                    }
                    Get-ResourceDetails -Subscription $PSItem.Request.Subscription -Resources $PSItem.Data -SourceType 'AvailabilityZoneMapping' |
                        ForEach-Object { if ($writer) { $writer.WriteLine($PSItem) } else { $PSItem } }
                }

                $requests = [System.Collections.Generic.List[object]]::new()
                foreach ($subscription in $batch) {
                    $scope = "/subscriptions/$($subscription.subscriptionId)"
                    $requests.Add(@{ SourceType = 'CapacityReservation'; IsResourceList = $true; Subscription = $subscription; Path = "$scope/providers/Microsoft.Compute/capacityReservationGroups?api-version=2026-04-01" })
                    $requests.Add(@{ SourceType = 'PremiumSSDv2Disk'; IsResourceList = $true; Subscription = $subscription; Path = "$scope/providers/Microsoft.Compute/disks?api-version=2026-03-02" })
                    foreach ($location in $Locations) {
                        $skuFilter = [uri]::EscapeDataString("location eq '$location'")
                        $requests.Add(@{ SourceType = 'ComputeResourceSku'; Subscription = $subscription; Location = $location; Path = "$scope/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=$skuFilter" })
                        foreach ($source in $usageSources) {
                            $usagePath = $source.UsagePath ?? 'usages'
                            $requests.Add(@{
                                    SourceType = $source.SourceType; ResourceType = $source.ResourceType ?? "$($source.Provider)/locations/usages"; UsagePath = $usagePath
                                    Subscription = $subscription; Location = $location
                                    Path = "$scope/providers/$($source.Provider)/locations/$location/$($usagePath)?api-version=$($source.ApiVersion)"
                                })
                        }
                    }
                }
                Get-ArmResponses $requests $client $ConcurrentSubscriptions $ConcurrentRequests | ForEach-Object {
                    $request = $PSItem.Request
                    if ($PSItem.Error) {
                        Write-Warning "Failed Querying: $($request.Subscription.subscriptionId) - $($request.Location) - $($request.SourceType) - $($PSItem.Error)"
                        return
                    }
                    if ($request.IsResourceList) {
                        Get-ResourceDetails -Subscription $request.Subscription -Resources $PSItem.Data -SourceType $request.SourceType |
                            ForEach-Object { if ($writer) { $writer.WriteLine($PSItem) } else { $PSItem } }
                        return
                    }
                    $isSkus = $request.SourceType -eq 'ComputeResourceSku'
                    $quotaParams = @{
                        Subscription             = $request.Subscription
                        Location                 = $request.Location
                        ComputeSkus              = if ($isSkus) { $PSItem.Data } else { @() }
                        Usage                    = if ($isSkus) { @() } else { $PSItem.Data }
                        UsageResourceType        = $request.ResourceType
                        UsageSourceType          = $request.SourceType
                        UsagePath                = $request.UsagePath
                        AvailabilityZoneMappings = $zoneMappings["$($request.Subscription.subscriptionId)|$($request.Location)"]
                        SKUs                     = $SKUs
                    }
                    Get-QuotaDetails @quotaParams | ForEach-Object { if ($writer) { $writer.WriteLine($PSItem) } else { $PSItem } }
                }
            } $subscriptions[$offset..([math]::Min($offset + $ConcurrentSubscriptions, $subscriptions.Count) - 1)]
        }
    }
    catch {
        $collectionFailure = $PSItem
        throw
    }
    finally {
        try {
            if ($writer) {
                try { $writer.Dispose() }
                catch {
                    if (-not $collectionFailure) { throw }
                    Write-Warning "Quota CSV cleanup failed: $($PSItem.Exception.Message)"
                }
            }
        }
        finally { $client.Dispose() }
    }

    # Display completion summary
    if (-not $AsCsv) { Write-Host "Output written to $OutputFile" }
    $end = Get-Date
    Write-Host "Processed $($subscriptions.Count) subscriptions in $([math]::Round((New-TimeSpan -Start $begin -End $end).TotalSeconds, 2)) seconds"
}
