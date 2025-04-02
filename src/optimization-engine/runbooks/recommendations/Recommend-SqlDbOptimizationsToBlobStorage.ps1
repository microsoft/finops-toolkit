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
$workspaceName = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceName"
$workspaceRG = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceRG"
$workspaceSubscriptionId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceSubId"
$workspaceTenantId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceTenantId"

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RecommendationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer)) {
    $storageAccountSinkContainer = "recommendationsexports"
}

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

$perfDaysBackwards = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendPerfPeriodInDays" -ErrorAction SilentlyContinue)
if (-not($perfDaysBackwards -gt 0)) {
    $perfDaysBackwards = 7
}

$dtuPercentile = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfPercentileSqlDtu" -ErrorAction SilentlyContinue)
if (-not($dtuPercentile -gt 0)) {
    $dtuPercentile = 99
}
$dtuPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdDtuPercentage" -ErrorAction SilentlyContinue)
if (-not($dtuPercentageThreshold -gt 0)) {
    $dtuPercentageThreshold = 40
}
$dtuDegradedPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdDtuDegradedPercentage" -ErrorAction SilentlyContinue)
if (-not($dtuDegradedPercentageThreshold -gt 0)) {
    $dtuDegradedPercentageThreshold = 75
}

$consumptionOffsetDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_ConsumptionOffsetDays")
$consumptionOffsetDaysStart = $consumptionOffsetDays + 1

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('ARGSqlDb','MonitorMetrics','AzureConsumption','ARGResourceContainers')"

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

$sqlDbsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGSqlDb' }).LogAnalyticsSuffix + "_CL"
$metricsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'MonitorMetrics' }).LogAnalyticsSuffix + "_CL"
$consumptionTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureConsumption' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $sqlDbsTableName, $subscriptionsTableName, $metricsTableName and $consumptionTableName"

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

# Execute the recommendation query against Log Analytics
Write-Output "Looking for underused SQL Databases, with less than $dtuPercentageThreshold % Max. DTU usage..."

$baseQuery = @"
    let DTUPercentageThreshold = $dtuPercentageThreshold;
    let MetricsInterval = $($perfDaysBackwards)d;
    let BillingInterval = 30d;
    let dtuPercentPercentile = $dtuPercentile;
    let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(BillingInterval) | summarize max(todatetime(Date_s))));
    let stime = etime-BillingInterval;
    let CandidateDatabaseIds = $sqlDbsTableName
    | where TimeGenerated > ago(1d) and SkuName_s in ('Standard','Premium')
    | distinct InstanceId_s;
    $metricsTableName
    | where TimeGenerated > ago(MetricsInterval)
    | where ResourceId in (CandidateDatabaseIds) and MetricNames_s == 'dtu_consumption_percent' and AggregationType_s == 'Maximum'
    | summarize P99DTUPercentage = percentile(todouble(MetricValue_s), dtuPercentPercentile) by ResourceId
    | where P99DTUPercentage < DTUPercentageThreshold
    | join (
        $sqlDbsTableName
        | where TimeGenerated > ago(1d)
        | project ResourceId = InstanceId_s, DBName_s, ResourceGroupName_s, SubscriptionGuid_g, TenantGuid_g, SkuName_s, ServiceObjectiveName_s, Tags_s, Cloud_s
    ) on ResourceId
    | join kind=leftouter (
        $consumptionTableName
        | where todatetime(Date_s) between (stime..etime)
        | project ResourceId=tolower(ResourceId), CostInBillingCurrency_s, Date_s
    ) on ResourceId
    | summarize Last30DaysCost=sum(todouble(CostInBillingCurrency_s)) by DBName_s, ResourceId, TenantGuid_g, SubscriptionGuid_g, ResourceGroupName_s, SkuName_s, ServiceObjectiveName_s, Tags_s, Cloud_s, P99DTUPercentage
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionGuid_g
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
    $queryInstanceId = $result.ResourceId
    $queryText = @"
    $metricsTableName
    | where ResourceId == '$queryInstanceId'
    | where MetricNames_s == 'dtu_consumption_percent' and AggregationType_s == 'Maximum'
    | project TimeGenerated, DTUPercentage = toint(MetricValue_s)
    | render timechart
"@
    $encodedQuery = [System.Uri]::EscapeDataString($queryText)
    $detailsQueryStart = $datetime.AddDays(-30).ToString("yyyy-MM-dd")
    $detailsQueryEnd = $datetime.AddDays(8).ToString("yyyy-MM-dd")
    switch ($cloudEnvironment)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }
    $detailsURL = "https://portal.azure.$azureTld#@$workspaceTenantId/blade/Microsoft_Azure_Monitoring_Logs/LogsBlade/resourceId/%2Fsubscriptions%2F$workspaceSubscriptionId%2Fresourcegroups%2F$workspaceRG%2Fproviders%2Fmicrosoft.operationalinsights%2Fworkspaces%2F$workspaceName/source/LogsBlade.AnalyticsShareLinkToQuery/query/$encodedQuery/timespan/$($detailsQueryStart)T00%3A00%3A00.000Z%2F$($detailsQueryEnd)T00%3A00%3A00.000Z"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["currentSku"] = "$($result.SkuName_s) $($result.ServiceObjectiveName_s)"
    $additionalInfoDictionary["DTUPercentage"] = [int] $result.P99DTUPercentage
    $additionalInfoDictionary["CostsAmount"] = [double] $result.Last30DaysCost
    $additionalInfoDictionary["savingsAmount"] = ([double] $result.Last30DaysCost / 2)

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
        Category = "Cost"
        ImpactedArea = "Microsoft.Sql/servers/databases"
        Impact = "High"
        RecommendationType = "Saving"
        RecommendationSubType = "UnderusedSqlDatabases"
        RecommendationSubTypeId = "ff68f4e5-1197-4be9-8e5f-8760d7863cb4"
        RecommendationDescription = "Underused SQL Databases (performance capacity waste)"
        RecommendationAction = "Right-size underused SQL Databases"
        InstanceId = $result.ResourceId
        InstanceName = $result.DBName_s
        AdditionalInfo = $additionalInfoDictionary
        ResourceGroup = $result.ResourceGroupName_s
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
$jsonExportPath = "sqldbs-underused-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for performance constrained SQL Databases, with more than $dtuDegradedPercentageThreshold % Avg. DTU usage..."

$baseQuery = @"
    let DTUPercentageThreshold = $dtuDegradedPercentageThreshold;
    let MetricsInterval = $($perfDaysBackwards)d;
    let CandidateDatabaseIds = $sqlDbsTableName
    | where TimeGenerated > ago(1d) and SkuName_s in ('Basic','Standard','Premium')
    | distinct InstanceId_s;
    $metricsTableName
    | where TimeGenerated > ago(MetricsInterval)
    | where ResourceId in (CandidateDatabaseIds) and MetricNames_s == 'dtu_consumption_percent' and AggregationType_s == 'Average' and AggregationOfType_s == 'Maximum'
    | summarize AvgDTUPercentage = avg(todouble(MetricValue_s)) by ResourceId
    | where AvgDTUPercentage > DTUPercentageThreshold
    | join (
        $sqlDbsTableName
        | where TimeGenerated > ago(1d)
        | project ResourceId = InstanceId_s, DBName_s, ResourceGroupName_s, SubscriptionGuid_g, TenantGuid_g, SkuName_s, ServiceObjectiveName_s, Tags_s, Cloud_s
    ) on ResourceId
    | project DBName_s, ResourceId, TenantGuid_g, SubscriptionGuid_g, ResourceGroupName_s, SkuName_s, ServiceObjectiveName_s, Tags_s, Cloud_s, AvgDTUPercentage
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionGuid_g
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
    $queryInstanceId = $result.ResourceId
    $queryText = @"
    $metricsTableName
    | where ResourceId == '$queryInstanceId'
    | where MetricNames_s == 'dtu_consumption_percent' and AggregationType_s == 'Average'
    | project TimeGenerated, DTUPercentage = toint(MetricValue_s)
    | render timechart
"@
    $encodedQuery = [System.Uri]::EscapeDataString($queryText)
    $detailsQueryStart = $datetime.AddDays(-30).ToString("yyyy-MM-dd")
    $detailsQueryEnd = $datetime.AddDays(8).ToString("yyyy-MM-dd")
    switch ($cloudEnvironment)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }
    $detailsURL = "https://portal.azure.$azureTld#@$workspaceTenantId/blade/Microsoft_Azure_Monitoring_Logs/LogsBlade/resourceId/%2Fsubscriptions%2F$workspaceSubscriptionId%2Fresourcegroups%2F$workspaceRG%2Fproviders%2Fmicrosoft.operationalinsights%2Fworkspaces%2F$workspaceName/source/LogsBlade.AnalyticsShareLinkToQuery/query/$encodedQuery/timespan/$($detailsQueryStart)T00%3A00%3A00.000Z%2F$($detailsQueryEnd)T00%3A00%3A00.000Z"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["currentSku"] = "$($result.SkuName_s) $($result.ServiceObjectiveName_s)"
    $additionalInfoDictionary["DTUPercentage"] = [int] $result.AvgDTUPercentage

    $fitScore = 4

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
        Category = "Performance"
        ImpactedArea = "Microsoft.Sql/servers/databases"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "PerfConstrainedSqlDatabases"
        RecommendationSubTypeId = "724ff2f5-8c83-4105-b00d-029c4560d774"
        RecommendationDescription = "SQL Database performance has been constrained by lack of resources"
        RecommendationAction = "Resize SQL Database to higher SKU or scale it out"
        InstanceId = $result.ResourceId
        InstanceName = $result.DBName_s
        AdditionalInfo = $additionalInfoDictionary
        ResourceGroup = $result.ResourceGroupName_s
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
$jsonExportPath = "sqldbs-perfconstrained-$fileDate.json"
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