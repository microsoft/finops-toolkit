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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGLoadBalancerContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "arglbexports"
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

$allLBs = @()

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

$LBsTotal = @()
$resultsSoFar = 0

Write-Output "Querying for Load Balancer properties"

$argQuery = @"
resources
| where type =~ 'Microsoft.Network/loadBalancers'
| extend lbType = iif(properties.frontendIPConfigurations contains 'publicIPAddress', 'Public', iif(properties.frontendIPConfigurations contains 'privateIPAddress', 'Internal', 'Unknown'))
| extend lbRulesCount = array_length(properties.loadBalancingRules)
| extend frontendIPsCount = array_length(properties.frontendIPConfigurations)
| extend inboundNatRulesCount = array_length(properties.inboundNatRules)
| extend outboundRulesCount = array_length(properties.outboundRules)
| extend inboundNatPoolsCount = array_length(properties.inboundNatPools)
| extend backendPoolsCount = array_length(properties.backendAddressPools)
| extend probesCount = array_length(properties.probes)
| project id, name, resourceGroup, subscriptionId, tenantId, location, skuName = sku.name, skuTier = sku.tier, lbType, lbRulesCount, frontendIPsCount, inboundNatRulesCount, outboundRulesCount, inboundNatPoolsCount, backendPoolsCount, probesCount, tags
| join kind=leftouter (
	resources
	| where type =~ 'Microsoft.Network/loadBalancers'
	| mvexpand backendPools = properties.backendAddressPools
	| extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)
	| extend backendAddressesCount = array_length(backendPools.properties.loadBalancerBackendAddresses)
	| summarize backendIPCount = sum(backendIPCount), backendAddressesCount = sum(backendAddressesCount) by id
) on id
| project-away id1
| order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $LBs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $LBs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($LBs -and $LBs.GetType().Name -eq "PSResourceGraphResponse")
    {
        $LBs = $LBs.Data
    }
    $resultsCount = $LBs.Count
    $resultsSoFar += $resultsCount
    $LBsTotal += $LBs

} while ($resultsCount -eq $ARGPageSize)

Write-Output "Found $($LBsTotal.Count) Load Balancer entries"

<#
    Building CSV entries
#>

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

foreach ($lb in $LBsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $lb.tenantId
        SubscriptionGuid = $lb.subscriptionId
        ResourceGroupName = $lb.resourceGroup.ToLower()
        InstanceName = $lb.name.ToLower()
        InstanceId = $lb.id.ToLower()
        SkuName = $lb.skuName
        SkuTier = $lb.skuTier
        Location = $lb.location
        LbType = $lb.lbType
        LbRulesCount = $lb.lbRulesCount
        InboundNatRulesCount = $lb.inboundNatRulesCount
        OutboundRulesCount = $lb.outboundRulesCount
        FrontendIPsCount = $lb.frontendIPsCount
        BackendIPCount = $lb.backendIPCount
        BackendAddressesCount = $lb.backendAddressesCount
        InboundNatPoolsCount = $lb.inboundNatPoolsCount
        BackendPoolsCount = $lb.backendPoolsCount
        ProbesCount = $lb.probesCount
        StatusDate = $statusDate
        Tags = $lb.tags
    }

    $allLBs += $logentry
}

<#
    Actually exporting CSV to Azure Storage
#>

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-lbs-$subscriptionSuffix.csv"

$allLBs | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."