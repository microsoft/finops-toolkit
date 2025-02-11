param(
    [Parameter(Mandatory = $false)]
    [string] $TargetSubscription,

    [Parameter(Mandatory = $false)]
    [string] $externalCloudEnvironment,

    [Parameter(Mandatory = $false)]
    [string] $externalTenantId,

    [Parameter(Mandatory = $false)]
    [string] $externalCredentialName
)

$ErrorActionPreference = "Stop"

$cloudEnvironment = Get-AutomationVariable -Name "AzureOptimization_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}
$authenticationOption = Get-AutomationVariable -Name  "AzureOptimization_AuthenticationOption" -ErrorAction SilentlyContinue # ManagedIdentity|UserAssignedManagedIdentity
if ([string]::IsNullOrEmpty($authenticationOption))
{
    $authenticationOption = "ManagedIdentity"
}
if ($authenticationOption -eq "UserAssignedManagedIdentity")
{
    $uamiClientID = Get-AutomationVariable -Name "AzureOptimization_UAMIClientID"
}

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkEnv = Get-AutomationVariable -Name "AzureOptimization_StorageSinkEnvironment" -ErrorAction SilentlyContinue
if (-not($storageAccountSinkEnv))
{
    $storageAccountSinkEnv = $cloudEnvironment    
}
$storageAccountSinkKeyCred = Get-AutomationPSCredential -Name "AzureOptimization_StorageSinkKey" -ErrorAction SilentlyContinue
$storageAccountSinkKey = $null
if ($storageAccountSinkKeyCred)
{
    $storageAccountSink = $storageAccountSinkKeyCred.UserName
    $storageAccountSinkKey = $storageAccountSinkKeyCred.GetNetworkCredential().Password
}

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGAppGatewayContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argappgwexports"
}

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

$ARGPageSize = 1000

"Logging in to Azure with $authenticationOption..."

switch ($authenticationOption) {
    "UserAssignedManagedIdentity" { 
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment -AccountId $uamiClientID
        break
    }
    Default { #ManagedIdentity
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment 
        break
    }
}

if (-not($storageAccountSinkKey))
{
    Write-Output "Getting Storage Account context with login"
    
    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment
}
else
{
    Write-Output "Getting Storage Account context with key"
    $saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -StorageAccountKey $storageAccountSinkKey -Environment $storageAccountSinkEnv
}

$cloudSuffix = ""

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential 
    $cloudSuffix = $externalCloudEnvironment.ToLower() + "-"
    $cloudEnvironment = $externalCloudEnvironment   
}

$tenantId = (Get-AzContext).Tenant.Id

$allAppGWs = @()

Write-Output "Getting subscriptions target $TargetSubscription"
if (-not([string]::IsNullOrEmpty($TargetSubscription)))
{
    $subscriptions = $TargetSubscription
    $subscriptionSuffix = $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}
    $subscriptionSuffix = $cloudSuffix + "all-" + $tenantId
}

$appGWsTotal = @()
$resultsSoFar = 0

Write-Output "Querying for Application Gateways properties"

$argQuery = @"
resources
| where type =~ 'Microsoft.Network/applicationGateways'
| extend gatewayIPsCount = array_length(properties.gatewayIPConfigurations)
| extend frontendIPsCount = array_length(properties.frontendIPConfigurations)
| extend frontendPortsCount = array_length(properties.frontendPorts)
| extend backendPoolsCount = array_length(properties.backendAddressPools)
| extend httpSettingsCount = array_length(properties.backendHttpSettingsCollection)
| extend httpListenersCount = array_length(properties.httpListeners)
| extend urlPathMapsCount = array_length(properties.urlPathMaps)
| extend requestRoutingRulesCount = array_length(properties.requestRoutingRules)
| extend probesCount = array_length(properties.probes)
| extend rewriteRulesCount = array_length(properties.rewriteRuleSets)
| extend redirectConfsCount = array_length(properties.redirectConfigurations)
| project id, name, resourceGroup, subscriptionId, tenantId, location, zones, skuName = properties.sku.name, skuTier = properties.sku.tier, skuCapacity = properties.sku.capacity, enableHttp2 = properties.enableHttp2, gatewayIPsCount, frontendIPsCount, frontendPortsCount, httpSettingsCount, httpListenersCount, backendPoolsCount, urlPathMapsCount, requestRoutingRulesCount, probesCount, rewriteRulesCount, redirectConfsCount, tags
| join kind=leftouter (
	resources
	| where type =~ 'Microsoft.Network/applicationGateways'
	| mvexpand backendPools = properties.backendAddressPools
	| extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)
    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)
	| summarize backendIPCount = sum(backendIPCount), backendAddressesCount = sum(backendAddressesCount) by id
) on id
| project-away id1
| order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $appGWs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $appGWs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($appGWs -and $appGWs.GetType().Name -eq "PSResourceGraphResponse")
    {
        $appGWs = $appGWs.Data
    }
    $resultsCount = $appGWs.Count
    $resultsSoFar += $resultsCount
    $appGWsTotal += $appGWs

} while ($resultsCount -eq $ARGPageSize)

Write-Output "Found $($appGWsTotal.Count) Application Gateway entries"

<#
    Building CSV entries 
#>

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

foreach ($appGW in $appGWsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $appGW.tenantId
        SubscriptionGuid = $appGW.subscriptionId
        ResourceGroupName = $appGW.resourceGroup.ToLower()
        InstanceName = $appGW.name.ToLower()
        InstanceId = $appGW.id.ToLower()
        SkuName = $appGW.skuName
        SkuTier = $appGW.skuTier
        SkuCapacity = $appGW.skuCapacity
        Location = $appGW.location
        Zones = $appGW.zones
        EnableHttp2 = $appGW.enableHttp2
        GatewayIPsCount = $appGW.gatewayIPsCount
        FrontendIPsCount = $appGW.frontendIPsCount
        FrontendPortsCount = $appGW.frontendPortsCount
        BackendIPCount = $appGW.backendIPCount
        BackendAddressesCount = $appGW.backendAddressesCount
        HttpSettingsCount = $appGW.httpSettingsCount
        HttpListenersCount = $appGW.httpListenersCount
        BackendPoolsCount = $appGW.backendPoolsCount
        ProbesCount = $appGW.probesCount
        UrlPathMapsCount = $appGW.urlPathMapsCount
        RequestRoutingRulesCount = $appGW.requestRoutingRulesCount
        RewriteRulesCount = $appGW.rewriteRulesCount
        RedirectConfsCount = $appGW.redirectConfsCount
        StatusDate = $statusDate
        Tags = $appGW.tags
    }
    
    $allAppGWs += $logentry
}

<#
    Actually exporting CSV to Azure Storage
#>

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-appgws-$subscriptionSuffix.csv"

$allAppGWs | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    