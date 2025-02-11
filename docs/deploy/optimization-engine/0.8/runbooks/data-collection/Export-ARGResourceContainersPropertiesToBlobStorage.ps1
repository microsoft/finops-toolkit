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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGResourceContainersContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argrescontainersexports"
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

$allResourceContainers = @()

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

$rgsTotal = @()
$subsTotal = @()

$resultsSoFar = 0

Write-Output "Querying for resource groups..."

$argQuery = @"
    resourcecontainers
    | where type == "microsoft.resources/subscriptions/resourcegroups"
    | join kind=leftouter (
        resources
        | summarize ResourceCount= count() by subscriptionId, resourceGroup	
    ) on subscriptionId, resourceGroup
    | extend ResourceCount = iif(isempty(ResourceCount), 0, ResourceCount)
    | project id, name, type, tenantId, location, subscriptionId, managedBy, tags, properties, ResourceCount
    | order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $rgs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $rgs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($rgs -and $rgs.GetType().Name -eq "PSResourceGraphResponse")
    {
        $rgs = $rgs.Data
    }
    $resultsCount = $rgs.Count
    $resultsSoFar += $resultsCount
    $rgsTotal += $rgs

} while ($resultsCount -eq $ARGPageSize)

$resultsSoFar = 0

Write-Output "Querying for subscriptions"

$argQuery = @"
    resourcecontainers
    | where type == "microsoft.resources/subscriptions"
    | join kind=leftouter (
        resources
        | summarize ResourceCount= count() by subscriptionId
    ) on subscriptionId
    | extend ResourceCount = iif(isempty(ResourceCount), 0, ResourceCount)
    | project id, name, type, tenantId, subscriptionId, managedBy, tags, properties, ResourceCount
    | order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $subs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $subs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($subs -and $subs.GetType().Name -eq "PSResourceGraphResponse")
    {
        $subs = $subs.Data
    }
    $resultsCount = $subs.Count
    $resultsSoFar += $resultsCount
    $subsTotal += $subs

} while ($resultsCount -eq $ARGPageSize)

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($rgsTotal.Count) RG entries"

foreach ($rg in $rgsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $rg.tenantId
        SubscriptionGuid = $rg.subscriptionId
        Location = $rg.location
        ContainerType = $rg.type
        ContainerName = $rg.name.ToLower()
        InstanceId = $rg.id.ToLower()
        ResourceCount = $rg.ResourceCount
        ManagedBy = $rg.managedBy
        ContainerProperties = $rg.properties | ConvertTo-Json -Compress
        Tags = $rg.tags
        StatusDate = $statusDate
    }
    
    $allResourceContainers += $logentry
}

Write-Output "Building $($subsTotal.Count) subscription entries"

foreach ($sub in $subsTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $sub.tenantId
        SubscriptionGuid = $sub.subscriptionId
        Location = $sub.location
        ContainerType = $sub.type
        ContainerName = $sub.name.ToLower()
        InstanceId = $sub.id.ToLower()
        ResourceCount = $sub.ResourceCount
        ManagedBy = $sub.managedBy
        ContainerProperties = $sub.properties | ConvertTo-Json -Compress
        Tags = $sub.tags
        StatusDate = $statusDate
    }
        
    $allResourceContainers += $logentry
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$jsonExportPath = "$today-rescontainers-$subscriptionSuffix.json"
$csvExportPath = "$today-rescontainers-$subscriptionSuffix.csv"

$allResourceContainers | ConvertTo-Json -Depth 3 -Compress | Out-File $jsonExportPath
Write-Output "Exported to JSON: $($allResourceContainers.Count) lines"
$allResourceContainersJson = Get-Content -Path $jsonExportPath | ConvertFrom-Json
Write-Output "JSON Import: $($allResourceContainersJson.Count) lines"
$allResourceContainersJson | Export-Csv -NoTypeInformation -Path $csvExportPath
Write-Output "Export to $csvExportPath"

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    

Remove-Item -Path $jsonExportPath -Force
    
$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."    