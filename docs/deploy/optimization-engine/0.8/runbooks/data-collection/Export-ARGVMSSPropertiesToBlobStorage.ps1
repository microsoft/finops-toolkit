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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGVMSSContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argvmssexports"
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

Write-Output "Getting VM sizes details for $referenceRegion"
$sizes = Get-AzVMSize -Location $referenceRegion

$cloudSuffix = ""

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential 
    $cloudSuffix = $externalCloudEnvironment.ToLower() + "-"
    $cloudEnvironment = $externalCloudEnvironment   
}

$tenantId = (Get-AzContext).Tenant.Id

$allvmss = @()

if ($TargetSubscription)
{
    $subscriptions = $TargetSubscription
    $subscriptionSuffix = "-" + $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}
    $subscriptionSuffix = $cloudSuffix + "all-" + $tenantId
}

$armVmssTotal = @()

$resultsSoFar = 0

$argQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| project id, tenantId, name, location, resourceGroup, subscriptionId, skUName = tostring(sku.name),
    computerNamePrefix = tostring(properties.virtualMachineProfile.osProfile.computerNamePrefix),
    usesManagedDisks = iif(isnull(properties.virtualMachineProfile.storageProfile.osDisk.managedDisk), 'false', 'true'),
	capacity = tostring(sku.capacity), priority = tostring(properties.virtualMachineProfile.priority), tags, zones,
	osType = iif(isnotnull(properties.virtualMachineProfile.osProfile.linuxConfiguration), "Linux", "Windows"),
	osDiskSize = tostring(properties.virtualMachineProfile.storageProfile.osDisk.diskSizeGB),
	osDiskCaching = tostring(properties.virtualMachineProfile.storageProfile.osDisk.caching),
	osDiskSKU = tostring(properties.virtualMachineProfile.storageProfile.osDisk.managedDisk.storageAccountType),
	dataDiskCount = iif(isnotnull(properties.virtualMachineProfile.storageProfile.dataDisks), array_length(properties.virtualMachineProfile.storageProfile.dataDisks), 0),
	nicCount = array_length(properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations),
    imagePublisher = iif(isnotempty(properties.virtualMachineProfile.storageProfile.imageReference.publisher),tostring(properties.virtualMachineProfile.storageProfile.imageReference.publisher),'Custom'),
    imageOffer = iif(isnotempty(properties.virtualMachineProfile.storageProfile.imageReference.offer),tostring(properties.virtualMachineProfile.storageProfile.imageReference.offer),tostring(properties.virtualMachineProfile.storageProfile.imageReference.id)),
    imageSku = tostring(properties.virtualMachineProfile.storageProfile.imageReference.sku),
    imageVersion = tostring(properties.virtualMachineProfile.storageProfile.imageReference.version),
    imageExactVersion = tostring(properties.virtualMachineProfile.storageProfile.imageReference.exactVersion),
	singlePlacementGroup = tostring(properties.singlePlacementGroup),
	upgradePolicy = tostring(properties.upgradePolicy.mode),
	overProvision = tostring(properties.overprovision),
	platformFaultDomainCount = tostring(properties.platformFaultDomainCount),
    zoneBalance = tostring(properties.zoneBalance)		
| order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $armVmss = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $armVmss = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions 
    }

    if ($armVmss -and $armVmss.GetType().Name -eq "PSResourceGraphResponse")
    {
        $armVmss = $armVmss.Data
    }
    $resultsCount = $armVmss.Count
    $resultsSoFar += $resultsCount
    $armVmssTotal += $armVmss

} while ($resultsCount -eq $ARGPageSize)

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($armVmssTotal.Count) VMSS entries"

foreach ($vmss in $armVmssTotal)
{
    $vmSize = $sizes | Where-Object {$_.name -eq $vmss.skUName}

    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $vmss.tenantId
        SubscriptionGuid = $vmss.subscriptionId
        ResourceGroupName = $vmss.resourceGroup.ToLower()
        Zones = $vmss.zones
        Location = $vmss.location
        VMSSName = $vmss.name.ToLower()
        ComputerNamePrefix = $vmss.computerNamePrefix.ToLower()
        InstanceId = $vmss.id.ToLower()
        VMSSSize = $vmSize.name.ToLower()
        CoresCount = $vmSize.NumberOfCores
        MemoryMB = $vmSize.MemoryInMB
        OSType = $vmss.osType
        DataDiskCount = $vmss.dataDiskCount
        NicCount = $vmss.nicCount
        StatusDate = $statusDate
        Tags = $vmss.tags
        Capacity = $vmss.capacity
        Priority = $vmss.priority
        OSDiskSize = $vmss.osDiskSize
        OSDiskCaching = $vmss.osDiskCaching
        OSDiskSKU = $vmss.osDiskSKU
        SinglePlacementGroup = $vmss.singlePlacementGroup
        UpgradePolicy = $vmss.upgradePolicy
        OverProvision = $vmss.overProvision
        PlatformFaultDomainCount = $vmss.platformFaultDomainCount
        ZoneBalance = $vmss.zoneBalance
        UsesManagedDisks = $vmss.usesManagedDisks
        ImagePublisher = $vmss.imagePublisher
        ImageOffer = $vmss.imageOffer
        ImageSku = $vmss.imageSku
        ImageVersion = $vmss.imageVersion
        ImageExactVersion = $vmss.imageExactVersion
    }
    
    $allvmss += $logentry
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-vmss-$subscriptionSuffix.csv"

$allvmss | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    