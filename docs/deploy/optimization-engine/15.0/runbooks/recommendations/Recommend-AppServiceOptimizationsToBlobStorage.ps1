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

$deploymentDate = Get-AutomationVariable -Name  "AzureOptimization_DeploymentDate" # yyyy-MM-dd format
$deploymentDate = $deploymentDate.Replace('"', "")

$perfDaysBackwards = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendPerfPeriodInDays" -ErrorAction SilentlyContinue)
if (-not($perfDaysBackwards -gt 0)) {
    $perfDaysBackwards = 7
}

$perfTimeGrain = Get-AutomationVariable -Name  "AzureOptimization_RecommendPerfTimeGrain" -ErrorAction SilentlyContinue
if (-not($perfTimeGrain)) {
    $perfTimeGrain = "1h"
}

# percentiles variables
$cpuPercentile = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfPercentileCpu" -ErrorAction SilentlyContinue)
if (-not($cpuPercentile -gt 0)) {
    $cpuPercentile = 99
}
$memoryPercentile = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfPercentileMemory" -ErrorAction SilentlyContinue)
if (-not($memoryPercentile -gt 0)) {
    $memoryPercentile = 99
}

# perf thresholds variables
$cpuPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdCpuPercentage" -ErrorAction SilentlyContinue)
if (-not($cpuPercentageThreshold -gt 0)) {
    $cpuPercentageThreshold = 30
}
$memoryPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdMemoryPercentage" -ErrorAction SilentlyContinue)
if (-not($memoryPercentageThreshold -gt 0)) {
    $memoryPercentageThreshold = 50
}
$cpuDegradedMaxPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdCpuDegradedMaxPercentage" -ErrorAction SilentlyContinue)
if (-not($cpuDegradedMaxPercentageThreshold -gt 0)) {
    $cpuDegradedMaxPercentageThreshold = 95
}
$cpuDegradedAvgPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdCpuDegradedAvgPercentage" -ErrorAction SilentlyContinue)
if (-not($cpuDegradedAvgPercentageThreshold -gt 0)) {
    $cpuDegradedAvgPercentageThreshold = 75
}
$memoryDegradedPercentageThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdMemoryDegradedPercentage" -ErrorAction SilentlyContinue)
if (-not($memoryDegradedPercentageThreshold -gt 0)) {
    $memoryDegradedPercentageThreshold = 90
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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('AppServicePlans','MonitorMetrics','AzureConsumption','ARGResourceContainers')"

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

$appServicePlansTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AppServicePlans' }).LogAnalyticsSuffix + "_CL"
$metricsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'MonitorMetrics' }).LogAnalyticsSuffix + "_CL"
$consumptionTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureConsumption' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $appServicePlansTableName, $subscriptionsTableName, $metricsTableName and $consumptionTableName"

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
Write-Output "Looking for underused App Service Plans, with less than $cpuPercentageThreshold% CPU and $memoryPercentageThreshold% RAM usage..."

$baseQuery = @"
    let billingInterval = 30d;
    let perfInterval = $($perfDaysBackwards)d;
    let cpuPercentileValue = $cpuPercentile;
    let memoryPercentileValue = $memoryPercentile;
    let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(30d) | summarize max(todatetime(Date_s))));
    let stime = etime-billingInterval;

    let BilledPlans = $consumptionTableName
    | where todatetime(Date_s) between (stime..etime) and ResourceId has 'microsoft.web/serverfarms'
    | extend ConsumedQuantity = todouble(Quantity_s)
    | extend FinalCost = todouble(EffectivePrice_s) * ConsumedQuantity
    | extend InstanceId_s = tolower(ResourceId)
    | summarize Last30DaysCost = sum(FinalCost), Last30DaysQuantity = sum(ConsumedQuantity) by InstanceId_s;

    let ProcessorPerf = $metricsTableName
    | where TimeGenerated > ago(perfInterval)
    | where ResourceId has 'microsoft.web/serverfarms'
    | where MetricNames_s == "CpuPercentage" and AggregationType_s == 'Maximum'
    | extend InstanceId_s = ResourceId
    | summarize PCPUPercentage = percentile(todouble(MetricValue_s), cpuPercentileValue) by InstanceId_s;

    let MemoryPerf = $metricsTableName
    | where TimeGenerated > ago(perfInterval)
    | where ResourceId has 'microsoft.web/serverfarms'
    | where MetricNames_s == "MemoryPercentage" and AggregationType_s == 'Maximum'
    | extend InstanceId_s = ResourceId
    | summarize PMemoryPercentage = percentile(todouble(MetricValue_s), memoryPercentileValue) by InstanceId_s;

    $appServicePlansTableName
    | where TimeGenerated > ago(1d) and ComputeMode_s == 'Dedicated' and SkuTier_s != 'Free'
    | distinct InstanceId_s, AppServicePlanName_s, ResourceGroupName_s, SubscriptionGuid_g, Cloud_s, TenantGuid_g, SkuSize_s, NumberOfWorkers_s, Tags_s
    | join kind=inner ( BilledPlans ) on InstanceId_s
    | join kind=leftouter ( MemoryPerf ) on InstanceId_s
    | join kind=leftouter ( ProcessorPerf ) on InstanceId_s
    | project InstanceId_s, AppServicePlan = AppServicePlanName_s, ResourceGroup = ResourceGroupName_s, SubscriptionId = SubscriptionGuid_g, Cloud_s, TenantGuid_g, SkuSize_s, NumberOfWorkers_s, PMemoryPercentage, PCPUPercentage, Tags_s, Last30DaysCost, Last30DaysQuantity
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionId = SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionId
    | where isnotempty(PMemoryPercentage) and isnotempty(PCPUPercentage) and PMemoryPercentage < $memoryPercentageThreshold and PCPUPercentage < $cpuPercentageThreshold
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
    $queryInstanceId = $result.InstanceId_s
    $queryText = @"
let perfInterval = $($perfDaysBackwards)d;
let armId = `'$queryInstanceId`';
let gInt = $perfTimeGrain;
let MemoryPerf = $metricsTableName
| where TimeGenerated > ago(perfInterval)
| extend CollectedDate = todatetime(strcat(format_datetime(TimeGenerated, 'yyyy-MM-dd'),'T',format_datetime(TimeGenerated, 'HH'),':00:00Z'))
| where ResourceId == armId
| where MetricNames_s == 'MemoryPercentage' and AggregationType_s == 'Maximum'
| extend MemoryPercentage = todouble(MetricValue_s)
| summarize percentile(MemoryPercentage, $memoryPercentile) by bin(CollectedDate, gInt);
let ProcessorPerf = $metricsTableName
| where TimeGenerated > ago(perfInterval)
| extend CollectedDate = todatetime(strcat(format_datetime(TimeGenerated, 'yyyy-MM-dd'),'T',format_datetime(TimeGenerated, 'HH'),':00:00Z'))
| where ResourceId == armId
| where MetricNames_s == 'CpuPercentage' and AggregationType_s == 'Maximum'
| extend ProcessorPercentage = todouble(MetricValue_s)
| summarize percentile(ProcessorPercentage, $cpuPercentile) by bin(CollectedDate, gInt);
MemoryPerf
| join kind=inner (ProcessorPerf) on CollectedDate
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

    $additionalInfoDictionary["currentSku"] = "$($result.SkuSize_s)"
    $additionalInfoDictionary["InstanceCount"] = [int] $result.NumberOfWorkers_s
    $additionalInfoDictionary["MetricCPUPercentage"] = "$($result.PCPUPercentage)"
    $additionalInfoDictionary["MetricMemoryPercentage"] = "$($result.PMemoryPercentage)"
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
        ImpactedArea = "Microsoft.Web/serverFarms"
        Impact = "High"
        RecommendationType = "Saving"
        RecommendationSubType = "UnderusedAppServicePlans"
        RecommendationSubTypeId = "042adaca-ebdf-49b4-bc1b-2800b6e40fea"
        RecommendationDescription = "Underused App Service Plans (performance capacity waste)"
        RecommendationAction = "Right-size underused App Service Plans or scale it in"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.AppServicePlan
        AdditionalInfo = $additionalInfoDictionary
        ResourceGroup = $result.ResourceGroup
        SubscriptionGuid = $result.SubscriptionId
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
$jsonExportPath = "appserviceplans-underused-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for performance constrained App Service Plans, with more than $cpuDegradedMaxPercentageThreshold% Max. CPU, $cpuDegradedAvgPercentageThreshold% Avg. CPU and $memoryDegradedPercentageThreshold% RAM usage..."

$baseQuery = @"
    let perfInterval = $($perfDaysBackwards)d;

    let MemoryPerf = $metricsTableName
    | where TimeGenerated > ago(perfInterval)
    | where ResourceId has 'microsoft.web/serverfarms'
    | where MetricNames_s == "MemoryPercentage" and AggregationType_s == 'Average' and AggregationOfType_s == 'Maximum'
    | extend InstanceId_s = ResourceId
    | summarize PMemoryPercentage = avg(todouble(MetricValue_s)) by InstanceId_s;

    let ProcessorMaxPerf = $metricsTableName
    | where TimeGenerated > ago(perfInterval)
    | where ResourceId has 'microsoft.web/serverfarms'
    | where MetricNames_s == "CpuPercentage" and AggregationType_s == 'Maximum'
    | extend InstanceId_s = ResourceId
    | summarize PCPUMaxPercentage = avg(todouble(MetricValue_s)) by InstanceId_s;

    let ProcessorAvgPerf = $metricsTableName
    | where TimeGenerated > ago(perfInterval)
    | where ResourceId has 'microsoft.web/serverfarms'
    | where MetricNames_s == "CpuPercentage" and AggregationType_s == 'Average' and AggregationOfType_s == 'Maximum'
    | extend InstanceId_s = ResourceId
    | summarize PCPUAvgPercentage = avg(todouble(MetricValue_s)) by InstanceId_s;

    $appServicePlansTableName
    | where TimeGenerated > ago(1d) and ComputeMode_s == 'Dedicated' and SkuTier_s != 'Free'
    | distinct InstanceId_s, AppServicePlanName_s, ResourceGroupName_s, SubscriptionGuid_g, Cloud_s, TenantGuid_g, SkuSize_s, NumberOfWorkers_s, Tags_s
    | join kind=leftouter ( MemoryPerf ) on InstanceId_s
    | join kind=leftouter ( ProcessorMaxPerf ) on InstanceId_s
    | join kind=leftouter ( ProcessorAvgPerf ) on InstanceId_s
    | project InstanceId_s, AppServicePlan = AppServicePlanName_s, ResourceGroup = ResourceGroupName_s, SubscriptionId = SubscriptionGuid_g, Cloud_s, TenantGuid_g, SkuSize_s, NumberOfWorkers_s, PMemoryPercentage, PCPUMaxPercentage, PCPUAvgPercentage, Tags_s
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionId = SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionId
    | where isnotempty(PMemoryPercentage) and isnotempty(PCPUAvgPercentage) and isnotempty(PCPUMaxPercentage) and (PMemoryPercentage > $memoryDegradedPercentageThreshold or (PCPUMaxPercentage > $cpuDegradedMaxPercentageThreshold and PCPUAvgPercentage > $cpuDegradedAvgPercentageThreshold))
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
    $queryInstanceId = $result.InstanceId_s
    $queryText = @"
let perfInterval = $($perfDaysBackwards)d;
let armId = `'$queryInstanceId`';
let gInt = $perfTimeGrain;
let MemoryPerf = $metricsTableName
| where TimeGenerated > ago(perfInterval)
| extend CollectedDate = todatetime(strcat(format_datetime(TimeGenerated, 'yyyy-MM-dd'),'T',format_datetime(TimeGenerated, 'HH'),':00:00Z'))
| where ResourceId == armId
| where MetricNames_s == 'MemoryPercentage' and AggregationType_s == 'Average' and AggregationOfType_s == 'Maximum'
| extend MemoryPercentage = todouble(MetricValue_s)
| summarize percentile(MemoryPercentage, $memoryPercentile) by bin(CollectedDate, gInt);
let ProcessorMaxPerf = $metricsTableName
| where TimeGenerated > ago(perfInterval)
| extend CollectedDate = todatetime(strcat(format_datetime(TimeGenerated, 'yyyy-MM-dd'),'T',format_datetime(TimeGenerated, 'HH'),':00:00Z'))
| where ResourceId == armId
| where MetricNames_s == 'CpuPercentage' and AggregationType_s == 'Maximum'
| extend ProcessorMaxPercentage = todouble(MetricValue_s)
| summarize percentile(ProcessorMaxPercentage, $cpuPercentile) by bin(CollectedDate, gInt);
let ProcessorAvgPerf = $metricsTableName
| where TimeGenerated > ago(perfInterval)
| extend CollectedDate = todatetime(strcat(format_datetime(TimeGenerated, 'yyyy-MM-dd'),'T',format_datetime(TimeGenerated, 'HH'),':00:00Z'))
| where ResourceId == armId
| where MetricNames_s == 'CpuPercentage' and AggregationType_s == 'Average' and AggregationOfType_s == 'Maximum'
| extend ProcessorAvgPercentage = todouble(MetricValue_s)
| summarize percentile(ProcessorAvgPercentage, $cpuPercentile) by bin(CollectedDate, gInt);
MemoryPerf
| join kind=inner (ProcessorMaxPerf) on CollectedDate
| join kind=inner (ProcessorAvgPerf) on CollectedDate
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

    $additionalInfoDictionary["currentSku"] = "$($result.SkuSize_s)"
    $additionalInfoDictionary["InstanceCount"] = [int] $result.NumberOfWorkers_s
    $additionalInfoDictionary["MetricCPUAvgPercentage"] = "$($result.PCPUAvgPercentage)"
    $additionalInfoDictionary["MetricCPUMaxPercentage"] = "$($result.PCPUMaxPercentage)"
    $additionalInfoDictionary["MetricMemoryPercentage"] = "$($result.PMemoryPercentage)"

    $fitScore = 3 # needs a more complete analysis to improve score

    if ([double] $result.PCPUMaxPercentage -gt [double] $cpuDegradedMaxPercentageThreshold -and [double] $result.PCPUAvgPercentage -gt [double] $cpuDegradedAvgPercentageThreshold)
    {
        $fitScore = 4
    }

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
        ImpactedArea = "Microsoft.Web/serverFarms"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "PerfConstrainedAppServicePlans"
        RecommendationSubTypeId = "351574cb-c105-4538-a778-11dfbe4857bf"
        RecommendationDescription = "App Service Plan performance has been constrained by lack of resources"
        RecommendationAction = "Resize App Service Plan to higher SKU or scale it out"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.AppServicePlan
        AdditionalInfo = $additionalInfoDictionary
        ResourceGroup = $result.ResourceGroup
        SubscriptionGuid = $result.SubscriptionId
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
$jsonExportPath = "appserviceplans-perfconstrained-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for empty App Service Plans..."

$baseQuery = @"
let interval = 30d;
let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(interval) | summarize max(todatetime(Date_s))));
let stime = etime-interval;
$appServicePlansTableName
| where TimeGenerated > ago(1d) and ComputeMode_s == 'Dedicated' and SkuTier_s != 'Free' and toint(NumberOfSites_s) == 0
| distinct AppServicePlanName_s, InstanceId_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroupName_s, SkuSize_s, NumberOfWorkers_s, Tags_s, Cloud_s
| join kind=leftouter (
    $consumptionTableName
    | where todatetime(Date_s) between (stime..etime)
    | project InstanceId_s=tolower(ResourceId), CostInBillingCurrency_s, Date_s
) on InstanceId_s
| summarize Last30DaysCost=sum(todouble(CostInBillingCurrency_s)) by AppServicePlanName_s, InstanceId_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroupName_s, SkuSize_s, NumberOfWorkers_s, Tags_s, Cloud_s
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
    $queryInstanceId = $result.InstanceId_s
    $queryText = @"
    $appServicePlansTableName
    | where InstanceId_s == '$queryInstanceId'
    | where toint(NumberOfSites_s) == 0
    | distinct InstanceId_s, AppServicePlanName_s, TimeGenerated
    | summarize FirstUnusedDate = min(TimeGenerated) by InstanceId_s, AppServicePlanName_s
    | join kind=leftouter (
        $consumptionTableName
        | project InstanceId_s=tolower(ResourceId), CostInBillingCurrency_s, Date_s
    ) on InstanceId_s
    | summarize CostsSinceUnused = sumif(todouble(CostInBillingCurrency_s), todatetime(Date_s) > FirstUnusedDate) by AppServicePlanName_s, FirstUnusedDate
"@

    $encodedQuery = [System.Uri]::EscapeDataString($queryText)
    $detailsQueryStart = $deploymentDate
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

    $additionalInfoDictionary["currentSku"] = $result.SkuSize_s
    $additionalInfoDictionary["InstanceCount"] = $result.NumberOfWorkers_s
    $additionalInfoDictionary["CostsAmount"] = [double] $result.Last30DaysCost
    $additionalInfoDictionary["savingsAmount"] = [double] $result.Last30DaysCost

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
        ImpactedArea = "Microsoft.Web/serverFarms"
        Impact = "High"
        RecommendationType = "Saving"
        RecommendationSubType = "EmptyAppServicePlans"
        RecommendationSubTypeId = "ef525225-8b91-47a3-81f3-e674e94564b6"
        RecommendationDescription = "App Service Plans without any application incur in unnecessary costs"
        RecommendationAction = "Delete the App Service Plan"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.AppServicePlanName_s
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
$jsonExportPath = "appserviceplans-empty-$fileDate.json"
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