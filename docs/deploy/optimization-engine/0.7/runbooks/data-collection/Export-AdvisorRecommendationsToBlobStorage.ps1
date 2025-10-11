param(
    [Parameter(Mandatory = $false)]
    [string] $targetSubscription,

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

$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_AdvisorContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "advisorexports"
}

$CategoryFilter = Get-AutomationVariable -Name  "AzureOptimization_AdvisorFilter" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($CategoryFilter))
{
    $CategoryFilter = "HighAvailability,Security,Performance,OperationalExcellence" # comma-separated list of categories
}
$CategoryFilter += ",Cost"

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    $externalCredential = Get-AutomationPSCredential -Name $externalCredentialName
}

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

if (-not([string]::IsNullOrEmpty($externalCredentialName)))
{
    "Logging in to Azure with $externalCredentialName external credential..."
    Connect-AzAccount -ServicePrincipal -EnvironmentName $externalCloudEnvironment -Tenant $externalTenantId -Credential $externalCredential 
    $cloudEnvironment = $externalCloudEnvironment   
}

Write-Output "Getting subscriptions target $TargetSubscription"

$tenantId = (Get-AzContext).Tenant.Id

$ARGPageSize = 1000

if (-not([string]::IsNullOrEmpty($TargetSubscription)))
{
    $subscriptions = $TargetSubscription
    $scope = $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.SubscriptionPolicies.QuotaId -notlike "AAD*" } | ForEach-Object { "$($_.Id)"}
    $scope = $tenantId
}


<#
   Getting Advisor recommendations for each subscription and building CSV entries
#>

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$recommendationsARG = @()

$resultsSoFar = 0

$FinalCategoryFilter = ""

if (-not([string]::IsNullOrEmpty($CategoryFilter)))
{
    $categories = $CategoryFilter.Split(',')
    for ($i = 0; $i -lt $categories.Count; $i++)
    {
        $categories[$i] = "'" + $categories[$i] + "'"
    }    
    $FinalCategoryFilter = " and properties.category in (" + ($categories -join ",") + ")"
}

$argQuery = @"
advisorresources
| where type == 'microsoft.advisor/recommendations'
| where isnull(properties.suppressionIds)$FinalCategoryFilter
| extend resourceId = tostring(split(tolower(id),'/providers/microsoft.advisor')[0])
| join kind=leftouter (resources | project resourceId=tolower(id), resourceTags=tags) on resourceId
| project id, category = properties.category, impact = properties.impact, impactedArea = properties.impactedField,
    description = properties.shortDescription.problem, recommendationText = properties.shortDescription.solution,
    recommendationTypeId = properties.recommendationTypeId, instanceName = properties.impactedValue,
    additionalInfo = properties.extendedProperties, tags=resourceTags
| order by id asc
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $recs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $recs = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($recs -and $recs.GetType().Name -eq "PSResourceGraphResponse")
    {
        $recs = $recs.Data
    }
    $resultsCount = $recs.Count
    $resultsSoFar += $resultsCount
    $recommendationsARG += $recs

} while ($resultsCount -eq $ARGPageSize)

Write-Output "Building $($recommendationsARG.Count) recommendations entries"

$recommendations = @()

foreach ($advisorRecommendation in $recommendationsARG)
{
    $resourceIdParts = $advisorRecommendation.id.Split('/')
    if ($resourceIdParts.Count -ge 9)
    {
        # if the Resource ID is made of 9 parts, then the recommendation is relative to a specific Azure resource
        $realResourceIdParts = $resourceIdParts[0..8]
        $instanceId = ($realResourceIdParts -join "/").ToLower()
        $resourceGroup = $realResourceIdParts[4].ToLower()
        $subscriptionId = $realResourceIdParts[2]
    }
    else
    {
        # otherwise it is not a resource-specific recommendation (e.g., reservations)
        $resourceGroup = "notavailable"
        $instanceId = $advisorRecommendation.id.ToLower()
        $subscriptionId = $resourceIdParts[2]
    }

    if (-not([string]::IsNullOrEmpty($advisorRecommendation.additionalInfo)))
    {
        $additionalInfo = $advisorRecommendation.additionalInfo | ConvertTo-Json -Compress
    }
    else
    {
        $additionalInfo = $null
    }
    
    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $cloudEnvironment
        Category = $advisorRecommendation.category
        Impact = $advisorRecommendation.impact
        ImpactedArea = $advisorRecommendation.impactedArea
        Description = $advisorRecommendation.description
        RecommendationText = $advisorRecommendation.recommendationText
        RecommendationTypeId = $advisorRecommendation.recommendationTypeId
        InstanceId = $instanceId
        InstanceName = $advisorRecommendation.instanceName
        Tags = $advisorRecommendation.tags
        AdditionalInfo = $additionalInfo
        ResourceGroup = $resourceGroup
        SubscriptionGuid = $subscriptionId
        TenantGuid = $tenantId
    }

    $recommendations += $recommendation    
}

Write-Output "Found $($recommendations.Count) ($CategoryFilter) recommendations..."

$fileDate = $datetime.ToString("yyyyMMdd")
$advisorFilter = $CategoryFilter.Replace(',','').ToLower()
$csvExportPath = "$fileDate-$advisorFilter-$scope.csv"

$recommendations | Export-Csv -NoTypeInformation -Path $csvExportPath
Write-Output "Export to $csvExportPath"

$csvBlobName = $csvExportPath
$csvProperties = @{"ContentType" = "text/csv"};

Set-AzStorageBlobContent -File $csvExportPath -Container $storageAccountSinkContainer -Properties $csvProperties -Blob $csvBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $csvBlobName to Blob Storage..."

Remove-Item -Path $csvExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $csvExportPath from local disk..."    

Write-Output "DONE!"