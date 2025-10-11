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
$referenceRegion = Get-AutomationVariable -Name "AzureOptimization_ReferenceRegion" -ErrorAction SilentlyContinue # e.g., westeurope
if ([string]::IsNullOrEmpty($referenceRegion))
{
    $referenceRegion = "westeurope"
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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGVNetContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argvnetexports"
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

$allsubnets = @()

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

$subnetsTotal = @()

$resultsSoFar = 0

Write-Output "Querying for ARM VNet properties"

$argQuery = @"
    resources
    | where type =~ 'microsoft.network/virtualnetworks'
    | mv-expand subnets = properties.subnets limit 400
    | extend peeringsCount = array_length(properties.virtualNetworkPeerings)
    | extend vnetPrefixes = properties.addressSpace.addressPrefixes
    | extend dnsServers = properties.dhcpOptions.dnsServers
    | extend enableDdosProtection = properties.enableDdosProtection
    | project-away properties
    | extend subnetPrefix = tostring(subnets.properties.addressPrefix)
    | extend subnetDelegationsCount = array_length(subnets.properties.delegations)
    | extend subnetUsedIPs = iif(isnotempty(subnets.properties.ipConfigurations), array_length(subnets.properties.ipConfigurations), 0)
    | extend subnetTotalPrefixIPs = pow(2, 32 - toint(split(subnetPrefix,'/')[1])) - 5
    | extend subnetNsgId = tolower(subnets.properties.networkSecurityGroup.id)
    | project id, vnetName = name, resourceGroup, subscriptionId, tenantId, location, vnetPrefixes, dnsServers, subnetName = tolower(tostring(subnets.name)), subnetPrefix, subnetDelegationsCount, subnetTotalPrefixIPs, subnetUsedIPs, subnetNsgId, peeringsCount, enableDdosProtection, tags
    | order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $subnets = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $subnets = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($subnets -and $subnets.GetType().Name -eq "PSResourceGraphResponse")
    {
        $subnets = $subnets.Data
    }
    $resultsCount = $subnets.Count
    $resultsSoFar += $resultsCount
    $subnetsTotal += $subnets

} while ($resultsCount -eq $ARGPageSize)

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($subnetsTotal.Count) ARM VNet subnet entries"

foreach ($subnet in $subnetsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $subnet.tenantId
        SubscriptionGuid = $subnet.subscriptionId
        ResourceGroupName = $subnet.resourceGroup.ToLower()
        Location = $subnet.location
        VNetName = $subnet.vnetName.ToLower()
        InstanceId = $subnet.id.ToLower()
        Model = "ARM"
        VNetPrefixes = $subnet.vnetPrefixes
        DNSServers = $subnet.dnsServers
        PeeringsCount = $subnet.peeringsCount
        EnableDdosProtection = $subnet.enableDdosProtection
        SubnetName = $subnet.subnetName
        SubnetPrefix = $subnet.subnetPrefix
        SubnetDelegationsCount = $subnet.subnetDelegationsCount
        SubnetTotalPrefixIPs = $subnet.subnetTotalPrefixIPs
        SubnetUsedIPs = $subnet.subnetUsedIPs
        SubnetNSGId = $subnet.subnetNsgId
        Tags = $subnet.tags
        StatusDate = $statusDate
    }
    
    $allsubnets += $logentry
}

$subnetsTotal = @()

$resultsSoFar = 0

Write-Output "Querying for Classic VNet properties"

$argQuery = @"
    resources
    | where type =~ 'microsoft.classicnetwork/virtualnetworks'
    | extend vNetId = tolower(id)
    | mv-expand subnets = properties.subnets limit 400
    | extend subnetName = tolower(tostring(subnets.name))
    | join kind=leftouter (
        resources
        | where type =~ 'microsoft.network/virtualnetworks'
        | mvexpand peerings = properties.virtualNetworkPeerings limit 400
        | extend vNetId = tolower(tostring(peerings.properties.remoteVirtualNetwork.id))
        | where vNetId has "microsoft.classicnetwork"
        | summarize vNetPeerings=count() by vNetId
    ) on vNetId
    | extend peeringsCount = iif(isnotempty(vNetPeerings), vNetPeerings, 0)
    | extend vnetPrefixes = properties.addressSpace.addressPrefixes
    | extend dnsServers = properties.dhcpOptions.dnsServers
    | project-away properties
    | extend subnetPrefix = tostring(subnets.addressPrefix)
    | join kind=leftouter (
        resources
        | where type =~ 'microsoft.classiccompute/virtualmachines'
        | extend networkProfile = properties.networkProfile
        | mvexpand subnets = networkProfile.virtualNetwork.subnetNames limit 400
        | extend subnetName = tolower(tostring(subnets))
        | project id, vNetId = tolower(tostring(networkProfile.virtualNetwork.id)), subnetName
        | summarize subnetUsedIPs = count() by vNetId, subnetName
    ) on vNetId and subnetName
    | extend subnetUsedIPs = iif(isnotempty(subnetUsedIPs), subnetUsedIPs, 0)
    | extend subnetTotalPrefixIPs = pow(2, 32 - toint(split(subnetPrefix,'/')[1])) - 5
    | extend enableDdosProtection = 'false'
    | project vNetId, vnetName = name, resourceGroup, subscriptionId, tenantId, location, vnetPrefixes, dnsServers, subnetName, subnetPrefix, subnetTotalPrefixIPs, subnetUsedIPs, peeringsCount, enableDdosProtection
    | order by vNetId asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $subnets = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $subnets = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($subnets -and $subnets.GetType().Name -eq "PSResourceGraphResponse")
    {
        $subnets = $subnets.Data
    }
    $resultsCount = $subnets.Count
    $resultsSoFar += $resultsCount
    $subnetsTotal += $subnets

} while ($resultsCount -eq $ARGPageSize)

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($subnetsTotal.Count) Classic VNet subnet entries"

foreach ($subnet in $subnetsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $subnet.tenantId
        SubscriptionGuid = $subnet.subscriptionId
        ResourceGroupName = $subnet.resourceGroup.ToLower()
        Location = $subnet.location
        VNetName = $subnet.vnetName.ToLower()
        InstanceId = $subnet.vNetId.ToLower()
        Model = "Classic"
        VNetPrefixes = $subnet.vnetPrefixes
        DNSServers = $subnet.dnsServers
        PeeringsCount = $subnet.peeringsCount
        EnableDdosProtection = $subnet.enableDdosProtection
        SubnetName = $subnet.subnetName
        SubnetPrefix = $subnet.subnetPrefix
        SubnetTotalPrefixIPs = $subnet.subnetTotalPrefixIPs
        SubnetUsedIPs = $subnet.subnetUsedIPs
        StatusDate = $statusDate
    }
    
    $allsubnets += $logentry
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-vnetsubnets-$subscriptionSuffix.csv"

$allsubnets | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    