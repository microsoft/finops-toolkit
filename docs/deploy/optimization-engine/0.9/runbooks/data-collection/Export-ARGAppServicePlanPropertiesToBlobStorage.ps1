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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_ARGAppServicePlanContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "argappserviceplanexports"
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

$allasp = @()

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

$aspTotal = @()

$resultsSoFar = 0

Write-Output "Querying for App Service Plan properties"

$argQuery = @"
    resources
    | where type =~ 'microsoft.web/serverfarms'
    | extend skuName = sku.name, skuTier = sku.tier, skuCapacity = sku.capacity, skuFamily = sku.family, skuSize = sku.size
    | extend computeMode = properties.computeMode, zoneRedundant = properties.zoneRedundant
    | extend numberOfWorkers = properties.numberOfWorkers, currentNumberOfWorkers = properties.currentNumberOfWorkers, maximumNumberOfWorkers = properties.maximumNumberOfWorkers
    | extend numberOfSites = properties.numberOfSites, planName = properties.planName
    | order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $asp = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $asp = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($asp -and $asp.GetType().Name -eq "PSResourceGraphResponse")
    {
        $asp = $asp.Data
    }
    $resultsCount = $asp.Count
    $resultsSoFar += $resultsCount
    $aspTotal += $asp

} while ($resultsCount -eq $ARGPageSize)

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")
$statusDate = $datetime.ToString("yyyy-MM-dd")

Write-Output "Building $($aspTotal.Count) App Service Plan entries"

foreach ($asplan in $aspTotal)
{
    $logentry = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        TenantGuid = $asplan.tenantId
        SubscriptionGuid = $asplan.subscriptionId
        ResourceGroupName = $asplan.resourceGroup.ToLower()
        ZoneRedundant = $asplan.zoneRedundant
        Location = $asplan.location
        AppServicePlanName = $asplan.name.ToLower()
        InstanceId = $asplan.id.ToLower()
        Kind = $asplan.kind
        SkuName = $asplan.skuName
        SkuTier = $asplan.skuTier
        SkuCapacity = $asplan.skuCapacity
        SkuFamily = $asplan.skuFamily
        SkuSize = $asplan.skuSize
        ComputeMode = $asplan.computeMode
        NumberOfWorkers = $asplan.numberOfWorkers
        CurrentNumberOfWorkers = $asplan.currentNumberOfWorkers
        MaximumNumberOfWorkers = $asplan.maximumNumberOfWorkers
        NumberOfSites = $asplan.numberOfSites
        PlanName = $asplan.planName
        Tags = $asplan.tags
        StatusDate = $statusDate
    }

    $allasp += $logentry
}

Write-Output "Uploading CSV to Storage"

$today = $datetime.ToString("yyyyMMdd")
$csvExportPath = "$today-asp-$subscriptionSuffix.csv"

$allasp | Export-Csv -Path $csvExportPath -NoTypeInformation

$csvBlobName = $csvExportPath

$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."