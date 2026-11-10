$ErrorActionPreference = "Stop"

# Collect generic and recommendation-specific variables

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

$workspaceId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceId"
$workspaceSubscriptionId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceSubId"

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RecommendationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer)) {
    $storageAccountSinkContainer = "recommendationsexports"
}

$deploymentDate = Get-AutomationVariable -Name  "AzureOptimization_DeploymentDate" # yyyy-MM-dd format
$deploymentDate = $deploymentDate.Replace('"', "")

$lognamePrefix = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsLogPrefix" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($lognamePrefix))
{
    $lognamePrefix = "AzureOptimization"
}

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}

$assignmentsPercentageThresholdVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationRBACAssignmentsPercentageThreshold" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($assignmentsPercentageThresholdVar) -or $assignmentsPercentageThresholdVar -eq 0)
{
    $assignmentsPercentageThreshold = 80
}
else
{
    $assignmentsPercentageThreshold = [int] $assignmentsPercentageThresholdVar
}

$assignmentsSubscriptionsLimitVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationRBACSubscriptionsAssignmentsLimit" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($assignmentsSubscriptionsLimitVar) -or $assignmentsSubscriptionsLimitVar -eq 0)
{
    $assignmentsSubscriptionsLimit = 4000
}
else
{
    $assignmentsSubscriptionsLimit = [int] $assignmentsSubscriptionsLimitVar
}

$assignmentsMgmtGroupsLimitVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationRBACMgmtGroupsAssignmentsLimit" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($assignmentsMgmtGroupsLimitVar) -or $assignmentsMgmtGroupsLimitVar -eq 0)
{
    $assignmentsMgmtGroupsLimit = 500
}
else
{
    $assignmentsMgmtGroupsLimit = [int] $assignmentsMgmtGroupsLimitVar
}

$rgPercentageThresholdVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationResourceGroupsPerSubPercentageThreshold" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($rgPercentageThresholdVar) -or $rgPercentageThresholdVar -eq 0)
{
    $rgPercentageThreshold = 80
}
else
{
    $rgPercentageThreshold = [int] $rgPercentageThresholdVar
}

$rgLimitVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationResourceGroupsPerSubLimit" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($rgLimitVar) -or $rgLimitVar -eq 0)
{
    $rgLimit = 980
}
else
{
    $rgLimit = [int] $rgLimitVar
}

$SqlTimeout = 120
$LogAnalyticsIngestControlTable = "LogAnalyticsIngestControl"

# Authenticate against Azure

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

$cloudDetails = Get-AzEnvironment -Name $CloudEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)

Write-Output "Finding tables where recommendations will be generated from..."

$tries = 0
$connectionSuccess = $false
do {
    $tries++
    try {
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
        $Conn.AccessToken = $dbToken.Token
        $Conn.Open()
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('RBACAssignments','ARGResourceContainers')"

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $controlRows = New-Object System.Data.DataTable
        $sqlAdapter.Fill($controlRows) | Out-Null
        $connectionSuccess = $true
    }
    catch {
        Write-Output "Failed to contact SQL at try $tries."
        Write-Output $Error[0]
        Start-Sleep -Seconds ($tries * 20)
    }
} while (-not($connectionSuccess) -and $tries -lt 3)

if (-not($connectionSuccess))
{
    throw "Could not establish connection to SQL."
}

$rbacTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'RBACAssignments' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $rbacTableName and $subscriptionsTableName"

$Conn.Close()
$Conn.Dispose()

$recommendationSearchTimeSpan = 30 + $consumptionOffsetDaysStart

# Grab a context reference to the Storage Account where the recommendations file will be stored


$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

if ($workspaceSubscriptionId -ne $storageAccountSinkSubscriptionId)
{
    Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
}

$recommendationsErrors = 0

$assignmentsThreshold = $assignmentsSubscriptionsLimit * ($assignmentsPercentageThreshold / 100)

Write-Output "Looking for subscriptions with more than $assignmentsPercentageThreshold% of the $assignmentsSubscriptionsLimit RBAC assignments limit..."

$baseQuery = @"
    $rbacTableName
    | where TimeGenerated > ago(1d) and Model_s == 'AzureRM' and Scope_s startswith '/subscriptions/'
    | extend SubscriptionGuid_g = tostring(split(Scope_s, '/')[2])
    | summarize AssignmentsCount=count() by SubscriptionGuid_g, TenantGuid_g, Cloud_s
    | join kind=leftouter (
       $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s, Tags_s, InstanceId_s
    ) on SubscriptionGuid_g
    | where AssignmentsCount >= $assignmentsThreshold
"@

try
{
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days $recommendationSearchTimeSpan) -Wait 600 -IncludeStatistics
    if ($queryResults)
    {
        $results = [System.Linq.Enumerable]::ToArray($queryResults.Results)
    }
}
catch
{
    Write-Warning -Message "Query failed. Debug the following query in the AOE Log Analytics workspace: $baseQuery"
    Write-Warning -Message $error[0]
    $recommendationsErrors++
}

Write-Output "Query finished with $($results.Count) results."

Write-Output "Query statistics: $($queryResults.Statistics.query)"

# Build the recommendations objects

$recommendations = @()
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

foreach ($result in $results)
{
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/users"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["assignmentsCount"] = $result.AssignmentsCount

    $fitScore = 5

    $tags = @{}

    if (-not([string]::IsNullOrEmpty($result.Tags_s)))
    {
        $tagPairs = $result.Tags_s.Substring(2, $result.Tags_s.Length - 3).Split(';')
        foreach ($tagPairString in $tagPairs)
        {
            $tagPair = $tagPairString.Split('=')
            if (-not([string]::IsNullOrEmpty($tagPair[0])) -and -not([string]::IsNullOrEmpty($tagPair[1])))
            {
                $tagName = $tagPair[0].Trim()
                $tagValue = $tagPair[1].Trim()
                $tags[$tagName] = $tagValue
            }
        }
    }

    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $result.Cloud_s
        Category = "OperationalExcellence"
        ImpactedArea = "Microsoft.Resources/subscriptions"
        Impact = "High"
        RecommendationType = "BestPractices"
        RecommendationSubType = "HighRBACAssignmentsSubscriptions"
        RecommendationSubTypeId = "c6a88d8c-3242-44b0-9793-c91897ef68bc"
        RecommendationDescription = "Subscriptions close to the maximum limit of RBAC assignments"
        RecommendationAction = "Remove unneeded RBAC assignments or use group-based (or nested group-based) assignments"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.SubscriptionName
        AdditionalInfo = $additionalInfoDictionary
        SubscriptionGuid = $result.SubscriptionGuid_g
        SubscriptionName = $result.SubscriptionName
        TenantGuid = $result.TenantGuid_g
        FitScore = $fitScore
        Tags = $tags
        DetailsURL = $detailsURL
    }

    $recommendations += $recommendation
}

# Export the recommendations as JSON to blob storage

$fileDate = $datetime.ToString("yyyy-MM-dd")
$jsonExportPath = "subscriptionsrbaclimits-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

$assignmentsThreshold = $assignmentsMgmtGroupsLimit * ($assignmentsPercentageThreshold / 100)

Write-Output "Looking for management groups with more than $assignmentsPercentageThreshold% of the $assignmentsMgmtGroupsLimit RBAC assignments limit..."

$baseQuery = @"
    $rbacTableName
    | where TimeGenerated > ago(1d) and Model_s == 'AzureRM' and Scope_s has 'managementGroups'
    | extend ManagementGroupId = tostring(split(Scope_s, '/')[4])
    | summarize AssignmentsCount=count() by ManagementGroupId, TenantGuid_g, Scope_s, Cloud_s
    | where AssignmentsCount >= $assignmentsThreshold
"@

try
{
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days $recommendationSearchTimeSpan) -Wait 600 -IncludeStatistics
    if ($queryResults)
    {
        $results = [System.Linq.Enumerable]::ToArray($queryResults.Results)
    }
}
catch
{
    Write-Warning -Message "Query failed. Debug the following query in the AOE Log Analytics workspace: $baseQuery"
    Write-Warning -Message $error[0]
    $recommendationsErrors++
}

Write-Output "Query finished with $($results.Count) results."

Write-Output "Query statistics: $($queryResults.Statistics.query)"

# Build the recommendations objects

$recommendations = @()
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

foreach ($result in $results)
{
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/blade/Microsoft_Azure_ManagementGroups/ManagementGroupBrowseBlade/MGBrowse_overview"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["assignmentsCount"] = $result.AssignmentsCount

    $fitScore = 5

    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $result.Cloud_s
        Category = "OperationalExcellence"
        ImpactedArea = "Microsoft.Management/managementGroups"
        Impact = "High"
        RecommendationType = "BestPractices"
        RecommendationSubType = "HighRBACAssignmentsManagementGroups"
        RecommendationSubTypeId = "b36dea3e-ef21-45a9-a704-6f629fab236d"
        RecommendationDescription = "Management Groups close to the maximum limit of RBAC assignments"
        RecommendationAction = "Remove unneeded RBAC assignments or use group-based (or nested group-based) assignments"
        InstanceId = $result.Scope_s
        InstanceName = $result.ManagementGroupId
        AdditionalInfo = $additionalInfoDictionary
        TenantGuid = $result.TenantGuid_g
        FitScore = $fitScore
        Tags = $tags
        DetailsURL = $detailsURL
    }

    $recommendations += $recommendation
}

# Export the recommendations as JSON to blob storage

$fileDate = $datetime.ToString("yyyy-MM-dd")
$jsonExportPath = "mgmtgroupsrbaclimits-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

$rgThreshold = $rgLimit * ($rgPercentageThreshold / 100)

Write-Output "Looking for subscriptions with more than $rgPercentageThreshold% of the $rgLimit Resource Groups limit..."

$baseQuery = @"
    $subscriptionsTableName
    | where TimeGenerated > ago(1d)
    | where ContainerType_s =~ 'microsoft.resources/subscriptions/resourceGroups'
    | summarize RGCount=count() by SubscriptionGuid_g, TenantGuid_g, Cloud_s
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s, Tags_s, InstanceId_s
    ) on SubscriptionGuid_g
    | where RGCount >= $rgThreshold
"@

try
{
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days $recommendationSearchTimeSpan) -Wait 600 -IncludeStatistics
    if ($queryResults)
    {
        $results = [System.Linq.Enumerable]::ToArray($queryResults.Results)
    }
}
catch
{
    Write-Warning -Message "Query failed. Debug the following query in the AOE Log Analytics workspace: $baseQuery"
    Write-Warning -Message $error[0]
    $recommendationsErrors++
}

Write-Output "Query finished with $($results.Count) results."

Write-Output "Query statistics: $($queryResults.Statistics.query)"

# Build the recommendations objects

$recommendations = @()
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

foreach ($result in $results)
{
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/resourceGroups"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["resourceGroupsCount"] = $result.RGCount

    $fitScore = 5

    $tags = @{}

    if (-not([string]::IsNullOrEmpty($result.Tags_s)))
    {
        $tagPairs = $result.Tags_s.Substring(2, $result.Tags_s.Length - 3).Split(';')
        foreach ($tagPairString in $tagPairs)
        {
            $tagPair = $tagPairString.Split('=')
            if (-not([string]::IsNullOrEmpty($tagPair[0])) -and -not([string]::IsNullOrEmpty($tagPair[1])))
            {
                $tagName = $tagPair[0].Trim()
                $tagValue = $tagPair[1].Trim()
                $tags[$tagName] = $tagValue
            }
        }
    }

    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $result.Cloud_s
        Category = "OperationalExcellence"
        ImpactedArea = "Microsoft.Resources/subscriptions"
        Impact = "High"
        RecommendationType = "BestPractices"
        RecommendationSubType = "HighResourceGroupCountSubscriptions"
        RecommendationSubTypeId = "4468da8d-1e72-4998-b6d2-3bc38ddd9330"
        RecommendationDescription = "Subscriptions close to the maximum limit of resource groups"
        RecommendationAction = "Remove unneeded resource groups or split your resource groups across multiple subscriptions"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.SubscriptionName
        AdditionalInfo = $additionalInfoDictionary
        SubscriptionGuid = $result.SubscriptionGuid_g
        SubscriptionName = $result.SubscriptionName
        TenantGuid = $result.TenantGuid_g
        FitScore = $fitScore
        Tags = $tags
        DetailsURL = $detailsURL
    }

    $recommendations += $recommendation
}

# Export the recommendations as JSON to blob storage

$fileDate = $datetime.ToString("yyyy-MM-dd")
$jsonExportPath = "subscriptionsrglimits-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

if ($recommendationsErrors -gt 0)
{
    throw "Some of the recommendations queries failed. Please, review the job logs for additional information."
}