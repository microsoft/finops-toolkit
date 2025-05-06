$ErrorActionPreference = "Stop"

function Find-SkuHourlyPrice {
    param (
        [object[]] $SKUPriceSheet,
        [string] $SKUName
    )

    $skuPriceObject = $null

    if ($SKUPriceSheet)
    {
        $skuNameParts = $SKUName.Split('_')

        if ($skuNameParts.Count -eq 3) # e.g., Standard_D1_v2
        {
            $skuNameFilter = "*" + $skuNameParts[1] + " *"
            $skuVersionFilter = "*" + $skuNameParts[2]
            $skuPrices = $SKUPriceSheet | Where-Object { $_.MeterName_s -like $skuNameFilter `
             -and $_.MeterName_s -notlike '*Low Priority' -and $_.MeterName_s -notlike '*Expired' `
             -and $_.MeterName_s -like $skuVersionFilter -and $_.MeterSubCategory_s -notlike '*Windows' -and $_.UnitPrice_s -ne 0 }

            if (($skuPrices -or $skuPrices.Count -ge 1) -and $skuPrices.Count -le 2)
            {
                $skuPriceObject = $skuPrices[0]
            }
            if ($skuPrices.Count -gt 2) # D1-like scenarios
            {
                $skuFilter = "*" + $skuNameParts[1] + " " + $skuNameParts[2] + "*"
                $skuPrices = $skuPrices | Where-Object { $_.MeterName_s -like $skuFilter }

                if (($skuPrices -or $skuPrices.Count -ge 1) -and $skuPrices.Count -le 2)
                {
                    $skuPriceObject = $skuPrices[0]
                }
            }
        }

        if ($skuNameParts.Count -eq 2) # e.g., Standard_D1
        {
            $skuNameFilter = "*" + $skuNameParts[1] + "*"

            $skuPrices = $SKUPriceSheet | Where-Object { $_.MeterName_s -like $skuNameFilter `
             -and $_.MeterName_s -notlike '*Low Priority' -and $_.MeterName_s -notlike '*Expired' `
             -and $_.MeterName_s -notlike '* v*' -and $_.MeterSubCategory_s -notlike '*Windows' -and $_.UnitPrice_s -ne 0 }

            if (($skuPrices -or $skuPrices.Count -ge 1) -and $skuPrices.Count -le 2)
            {
                $skuPriceObject = $skuPrices[0]
            }
            if ($skuPrices.Count -gt 2) # D1-like scenarios
            {
                $skuFilterLeft = "*" + $skuNameParts[1] + "/*"
                $skuFilterRight = "*/" + $skuNameParts[1] + "*"
                $skuPrices = $skuPrices | Where-Object { $_.MeterName_s -like $skuFilterLeft -or $_.MeterName_s -like $skuFilterRight }

                if (($skuPrices -or $skuPrices.Count -ge 1) -and $skuPrices.Count -le 2)
                {
                    $skuPriceObject = $skuPrices[0]
                }
            }
        }
    }

    $targetHourlyPrice = [double]::MaxValue
    if ($null -ne $skuPriceObject)
    {
        $targetUnitHours = [int] (Select-String -InputObject $skuPriceObject.UnitOfMeasure_s -Pattern "^\d+").Matches[0].Value
        if ($targetUnitHours -gt 0)
        {
            $targetHourlyPrice = [double] ($skuPriceObject.UnitPrice_s / $targetUnitHours)
        }
    }

    return $targetHourlyPrice
}

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

$referenceRegion = Get-AutomationVariable -Name "AzureOptimization_ReferenceRegion"

# must be less than or equal to the advisor exports frequency
$daysBackwards = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendAdvisorPeriodInDays" -ErrorAction SilentlyContinue)
if (-not($daysBackwards -gt 0)) {
    $daysBackwards = 7
}

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
$networkPercentile = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfPercentileNetwork" -ErrorAction SilentlyContinue)
if (-not($networkPercentile -gt 0)) {
    $networkPercentile = 99
}
$diskPercentile = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfPercentileDisk" -ErrorAction SilentlyContinue)
if (-not($diskPercentile -gt 0)) {
    $diskPercentile = 99
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
$networkMpbsThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdNetworkMbps" -ErrorAction SilentlyContinue)
if (-not($networkMpbsThreshold -gt 0)) {
    $networkMpbsThreshold = 750
}

# perf thresholds variables (shutdown)
$cpuPercentageShutdownThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdCpuShutdownPercentage" -ErrorAction SilentlyContinue)
if (-not($cpuPercentageShutdownThreshold -gt 0)) {
    $cpuPercentageShutdownThreshold = 5
}
$memoryPercentageShutdownThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdMemoryShutdownPercentage" -ErrorAction SilentlyContinue)
if (-not($memoryPercentageShutdownThreshold -gt 0)) {
    $memoryPercentageShutdownThreshold = 100
}
$networkMpbsShutdownThreshold = [int] (Get-AutomationVariable -Name  "AzureOptimization_PerfThresholdNetworkShutdownMbps" -ErrorAction SilentlyContinue )
if (-not($networkMpbsShutdownThreshold -gt 0)) {
    $networkMpbsShutdownThreshold = 10
}

$rightSizeRecommendationId = Get-AutomationVariable -Name  "AzureOptimization_RecommendationAdvisorCostRightSizeId" -ErrorAction SilentlyContinue
if (-not($rightSizeRecommendationId)) {
    $rightSizeRecommendationId = 'e10b1381-5f0a-47ff-8c7b-37bd13d7c974'
}

$additionalPerfWorkspaces = Get-AutomationVariable -Name  "AzureOptimization_RightSizeAdditionalPerfWorkspaces" -ErrorAction SilentlyContinue

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}

$consumptionOffsetDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_ConsumptionOffsetDays")
$consumptionOffsetDaysStart = $consumptionOffsetDays + 1

$SqlTimeout = 120
$LogAnalyticsIngestControlTable = "LogAnalyticsIngestControl"
$FiltersTable = "Filters"

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('ARGVirtualMachine','AzureAdvisor','AzureConsumption','ARGResourceContainers','Pricesheet')"

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

$vmsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGVirtualMachine' }).LogAnalyticsSuffix + "_CL"
$advisorTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureAdvisor' }).LogAnalyticsSuffix + "_CL"
$consumptionTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureConsumption' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"
$pricesheetTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'Pricesheet' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $vmsTableName, $subscriptionsTableName, $advisorTableName, $pricesheetTableName and $consumptionTableName"

$Conn.Close()
$Conn.Dispose()

Write-Output "Getting excluded recommendation sub-type IDs..."

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$FiltersTable] WHERE FilterType = 'Exclude' AND IsEnabled = 1 AND (FilterEndDate IS NULL OR FilterEndDate > GETDATE())"

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $filters = New-Object System.Data.DataTable
        $sqlAdapter.Fill($filters) | Out-Null
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

$Conn.Close()
$Conn.Dispose()

$recommendationSearchTimeSpan = 30 + $consumptionOffsetDaysStart

# Grab a context reference to the Storage Account where the recommendations file will be stored


$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

if ($workspaceSubscriptionId -ne $storageAccountSinkSubscriptionId)
{
    Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
}


Write-Output "Getting Virtual Machine SKUs for the $referenceRegion region..."
# Get all the VM SKUs information for the reference Azure region
$skus = Get-AzComputeResourceSku -Location $referenceRegion | Where-Object { $_.ResourceType -eq "virtualMachines" }

Write-Output "Getting the current Pricesheet..."

if ($cloudEnvironment -eq "AzureCloud")
{
    $pricesheetRegion = "EU West"
}

try
{
    $pricesheetEntries = @()

    $baseQuery = @"
    $pricesheetTableName
    | where TimeGenerated > ago(14d)
    | where MeterCategory_s == 'Virtual Machines' and MeterRegion_s == '$pricesheetRegion' and PriceType_s == 'Consumption'
    | distinct MeterName_s, MeterSubCategory_s, MeterCategory_s, MeterRegion_s, UnitPrice_s, UnitOfMeasure_s
"@

    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days 14) -Wait 600 -IncludeStatistics
    $pricesheetEntries = [System.Linq.Enumerable]::ToArray($queryResults.Results)

    Write-Output "Query finished with $($pricesheetEntries.Count) results."
    Write-Output "Query statistics: $($queryResults.Statistics.query)"
}
catch
{
    Write-Warning -Message "Query failed. Debug the following query in the AOE Log Analytics workspace: $baseQuery"
    Write-Warning -Message $error[0]
    Write-Output "Consumption pricesheet not available, will estimate savings based in cores count..."
}

$linuxMemoryPerfAdditionalWorkspaces = ""
$windowsMemoryPerfAdditionalWorkspaces = ""
$processorPerfAdditionalWorkspaces = ""
$windowsNetworkPerfAdditionalWorkspaces = ""
$diskPerfAdditionalWorkspaces = ""
if ($additionalPerfWorkspaces)
{
    $additionalWorkspaces = $additionalPerfWorkspaces.Split(",")
    foreach ($additionalWorkspace in $additionalWorkspaces) {
        $additionalWorkspace = $additionalWorkspace.Trim()
        $linuxMemoryPerfAdditionalWorkspaces += @"
        | union ( workspace('$additionalWorkspace').Perf
        | where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
        | where CounterName == '% Used Memory'
        | extend WorkspaceId = TenantId
        | summarize hint.strategy=shuffle PMemoryPercentage = percentile(CounterValue, memoryPercentileValue) by _ResourceId, WorkspaceId)
"@
        $windowsMemoryPerfAdditionalWorkspaces += @"
        | union ( workspace('$additionalWorkspace').Perf
        | where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
        | where CounterName == 'Available MBytes'
        | extend WorkspaceId = TenantId
        | project TimeGenerated, MemoryAvailableMBs = CounterValue, _ResourceId, WorkspaceId)
"@
        $processorPerfAdditionalWorkspaces += @"
        | union ( workspace('$additionalWorkspace').Perf
        | where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
        | where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total'
        | extend WorkspaceId = TenantId
        | summarize hint.strategy=shuffle PCPUPercentage = percentile(CounterValue, cpuPercentileValue) by _ResourceId, WorkspaceId)
"@
        $windowsNetworkPerfAdditionalWorkspaces += @"
        | union ( workspace('$additionalWorkspace').Perf
        | where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
        | where CounterName == 'Bytes Total/sec'
        | extend WorkspaceId = TenantId
        | summarize hint.strategy=shuffle PCounter = percentile(CounterValue, networkPercentileValue) by InstanceName, _ResourceId, WorkspaceId
        | summarize PNetwork = sum(PCounter) by _ResourceId, WorkspaceId)
"@
        $diskPerfAdditionalWorkspaces += @"
        | union ( workspace('$additionalWorkspace').Perf
        | where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
        | where CounterName in ('Disk Reads/sec', 'Disk Writes/sec', 'Disk Read Bytes/sec', 'Disk Write Bytes/sec') and InstanceName !in ('_Total', 'D:', '/mnt/resource', '/mnt')
        | extend WorkspaceId = TenantId
        | summarize hint.strategy=shuffle PCounter = percentile(CounterValue, diskPercentileValue) by bin(TimeGenerated, perfTimeGrain), CounterName, InstanceName, _ResourceId, WorkspaceId
        | summarize SumPCounter = sum(PCounter) by CounterName, TimeGenerated, _ResourceId, WorkspaceId
        | summarize MaxPReadIOPS = maxif(SumPCounter, CounterName == 'Disk Reads/sec'),
                    MaxPWriteIOPS = maxif(SumPCounter, CounterName == 'Disk Writes/sec'),
                    MaxPReadMiBps = (maxif(SumPCounter, CounterName == 'Disk Read Bytes/sec') / 1024 / 1024),
                    MaxPWriteMiBps = (maxif(SumPCounter, CounterName == 'Disk Write Bytes/sec') / 1024 / 1024) by _ResourceId, WorkspaceId)
"@
    }
}

# Execute the recommendation query against Log Analytics

$baseQuery = @"
let advisorInterval = $($daysBackwards)d;
let perfInterval = $($perfDaysBackwards)d;
let perfTimeGrain = $perfTimeGrain;
let cpuPercentileValue = $cpuPercentile;
let memoryPercentileValue = $memoryPercentile;
let networkPercentileValue = $networkPercentile;
let diskPercentileValue = $diskPercentile;
let rightSizeRecommendationId = '$rightSizeRecommendationId';
let billingInterval = 30d;
let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(30d) | summarize max(todatetime(Date_s))));
let stime = etime-billingInterval;
let RightSizeInstanceIds = materialize($advisorTableName
| where todatetime(TimeGenerated) > ago(advisorInterval) and Category == 'Cost' and RecommendationTypeId_g == rightSizeRecommendationId
| distinct InstanceId_s);
let LinuxMemoryPerf = Perf
| where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
| where CounterName == '% Used Memory'
| extend WorkspaceId = TenantId
| summarize hint.strategy=shuffle PMemoryPercentage = percentile(CounterValue, memoryPercentileValue) by _ResourceId, WorkspaceId$linuxMemoryPerfAdditionalWorkspaces;
let WindowsMemoryPerf = Perf
| where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
| where CounterName == 'Available MBytes'
| extend WorkspaceId = TenantId
| project TimeGenerated, MemoryAvailableMBs = CounterValue, _ResourceId, WorkspaceId$windowsMemoryPerfAdditionalWorkspaces;
let MemoryPerf = $vmsTableName
| where TimeGenerated > ago(1d)
| distinct InstanceId_s, MemoryMB_s
| join kind=inner hint.strategy=broadcast (
	WindowsMemoryPerf
) on `$left.InstanceId_s == `$right._ResourceId
| extend MemoryPercentage = todouble(toint(MemoryMB_s) - toint(MemoryAvailableMBs)) / todouble(MemoryMB_s) * 100
| summarize hint.strategy=shuffle PMemoryPercentage = percentile(MemoryPercentage, memoryPercentileValue) by _ResourceId, WorkspaceId
| union LinuxMemoryPerf;
let ProcessorPerf = Perf
| where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
| where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total'
| extend WorkspaceId = TenantId
| summarize hint.strategy=shuffle PCPUPercentage = percentile(CounterValue, cpuPercentileValue) by _ResourceId, WorkspaceId$processorPerfAdditionalWorkspaces;
let WindowsNetworkPerf = Perf
| where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
| where CounterName == 'Bytes Total/sec'
| extend WorkspaceId = TenantId
| summarize hint.strategy=shuffle PCounter = percentile(CounterValue, networkPercentileValue) by InstanceName, _ResourceId, WorkspaceId
| summarize PNetwork = sum(PCounter) by _ResourceId, WorkspaceId$windowsNetworkPerfAdditionalWorkspaces;
let DiskPerf = Perf
| where TimeGenerated > ago(perfInterval) and _ResourceId in (RightSizeInstanceIds)
| where CounterName in ('Disk Reads/sec', 'Disk Writes/sec', 'Disk Read Bytes/sec', 'Disk Write Bytes/sec') and InstanceName !in ('_Total', 'D:', '/mnt/resource', '/mnt')
| extend WorkspaceId = TenantId
| summarize hint.strategy=shuffle PCounter = percentile(CounterValue, diskPercentileValue) by bin(TimeGenerated, perfTimeGrain), CounterName, InstanceName, _ResourceId, WorkspaceId
| summarize SumPCounter = sum(PCounter) by CounterName, TimeGenerated, _ResourceId, WorkspaceId
| summarize MaxPReadIOPS = maxif(SumPCounter, CounterName == 'Disk Reads/sec'),
            MaxPWriteIOPS = maxif(SumPCounter, CounterName == 'Disk Writes/sec'),
            MaxPReadMiBps = (maxif(SumPCounter, CounterName == 'Disk Read Bytes/sec') / 1024 / 1024),
            MaxPWriteMiBps = (maxif(SumPCounter, CounterName == 'Disk Write Bytes/sec') / 1024 / 1024) by _ResourceId, WorkspaceId$diskPerfAdditionalWorkspaces;
$advisorTableName
| where todatetime(TimeGenerated) > ago(advisorInterval) and Category == 'Cost'
| extend AdvisorRecIdIndex = indexof(InstanceId_s, '/providers/microsoft.advisor/recommendations')
| extend InstanceName_s = iif(isnotempty(InstanceName_s),InstanceName_s,iif(AdvisorRecIdIndex > 0, split(substring(InstanceId_s, 0, AdvisorRecIdIndex),'/')[-1], split(InstanceId_s,'/')[-1]))
| distinct InstanceId_s, InstanceName_s, Description_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroup, Cloud_s, AdditionalInfo_s, RecommendationText_s, ImpactedArea_s, Impact_s, RecommendationTypeId_g, Tags_s
| join kind=leftouter (
    $consumptionTableName
    | where todatetime(Date_s) between (stime..etime)
    | extend VMConsumedQuantity = iif(ResourceId contains 'virtualmachines' and MeterCategory_s == 'Virtual Machines', todouble(Quantity_s), 0.0)
    | extend VMPrice = iif(ResourceId contains 'virtualmachines' and MeterCategory_s == 'Virtual Machines', todouble(EffectivePrice_s), 0.0)
    | extend FinalCost = iif(ResourceId contains 'virtualmachines', VMPrice * VMConsumedQuantity, todouble(CostInBillingCurrency_s))
    | extend InstanceId_s = tolower(ResourceId)
    | summarize Last30DaysCost = sum(FinalCost), Last30DaysQuantity = sum(VMConsumedQuantity) by InstanceId_s
) on InstanceId_s
| join kind=leftouter (
    $vmsTableName
    | where TimeGenerated > ago(1d)
    | distinct InstanceId_s, NicCount_s, DataDiskCount_s
) on InstanceId_s
| where RecommendationTypeId_g != rightSizeRecommendationId or (RecommendationTypeId_g == rightSizeRecommendationId and toint(NicCount_s) >= 0 and toint(DataDiskCount_s) >= 0)
| join kind=leftouter hint.strategy=broadcast ( MemoryPerf ) on `$left.InstanceId_s == `$right._ResourceId
| join kind=leftouter hint.strategy=broadcast ( ProcessorPerf ) on `$left.InstanceId_s == `$right._ResourceId
| join kind=leftouter hint.strategy=broadcast ( WindowsNetworkPerf ) on `$left.InstanceId_s == `$right._ResourceId
| join kind=leftouter hint.strategy=broadcast ( DiskPerf ) on `$left.InstanceId_s == `$right._ResourceId
| extend MaxPIOPS = MaxPReadIOPS + MaxPWriteIOPS, MaxPMiBps = MaxPReadMiBps + MaxPWriteMiBps
| extend PNetworkMbps = PNetwork * 8 / 1000 / 1000
| distinct Last30DaysCost, Last30DaysQuantity, InstanceId_s, InstanceName_s, Description_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroup, Cloud_s, AdditionalInfo_s, RecommendationText_s, ImpactedArea_s, Impact_s, RecommendationTypeId_g, NicCount_s, DataDiskCount_s, PMemoryPercentage, PCPUPercentage, PNetworkMbps, MaxPIOPS, MaxPMiBps, Tags_s, WorkspaceId
| join kind=leftouter (
    $subscriptionsTableName
    | where TimeGenerated > ago(1d)
    | where ContainerType_s =~ 'microsoft.resources/subscriptions'
    | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
) on SubscriptionGuid_g
"@

Write-Output "Will run the following query (use this query against the LA workspace for troubleshooting): $baseQuery"

Write-Output "Getting cost recommendations for $($daysBackwards)d Advisor and $($perfDaysBackwards)d Perf history and a $perfTimeGrain time grain..."

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
    throw "Execution aborted"
}

Write-Output "Query finished with $($results.Count) results."

Write-Output "Query statistics: $($queryResults.Statistics.query)"

# Build the recommendations objects

$recommendations = @()
$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$skuPricesFound = @{}

Write-Output "Generating fit score..."

foreach ($result in $results) {

    if ($filters | Where-Object { $_.RecommendationSubTypeId -eq $result.RecommendationTypeId_g})
    {
        continue
    }

    $queryInstanceId = $result.InstanceId_s

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

    $additionalInfoDictionary = @{}
    if (-not([string]::IsNullOrEmpty($result.AdditionalInfo_s)))
    {
        ($result.AdditionalInfo_s | ConvertFrom-Json).PsObject.Properties | ForEach-Object { $additionalInfoDictionary[$_.Name] = $_.Value }
    }

    # Fixing reservation model inconsistencies
    if (-not([string]::IsNullOrEmpty($additionalInfoDictionary["location"])))
    {
        $additionalInfoDictionary["region"] = $additionalInfoDictionary["location"]
    }
    if (-not([string]::IsNullOrEmpty($additionalInfoDictionary["targetResourceCount"])))
    {
        $additionalInfoDictionary["qty"] = $additionalInfoDictionary["targetResourceCount"]
    }
    if (-not([string]::IsNullOrEmpty($additionalInfoDictionary["vmSize"])))
    {
        $additionalInfoDictionary["displaySKU"] = $additionalInfoDictionary["vmSize"]
    }

    $additionalInfoDictionary["CostsAmount"] = [double] $result.Last30DaysCost

    $fitScore = 5
    $hasCpuRamPerfMetrics = $false

    if ($additionalInfoDictionary.targetSku -and $result.RecommendationTypeId_g -eq $rightSizeRecommendationId) {
        $additionalInfoDictionary["SupportsDataDisksCount"] = "true"
        $additionalInfoDictionary["DataDiskCount"] = "$($result.DataDiskCount_s)"
        $additionalInfoDictionary["SupportsNICCount"] = "true"
        $additionalInfoDictionary["NicCount"] = "$($result.NicCount_s)"
        $additionalInfoDictionary["SupportsIOPS"] = "true"
        $additionalInfoDictionary["MetricIOPS"] = "$($result.MaxPIOPS)"
        $additionalInfoDictionary["SupportsMiBps"] = "true"
        $additionalInfoDictionary["MetricMiBps"] = "$($result.MaxPMiBps)"
        $additionalInfoDictionary["BelowCPUThreshold"] = "true"
        $additionalInfoDictionary["MetricCPUPercentage"] = "$($result.PCPUPercentage)"
        $additionalInfoDictionary["BelowMemoryThreshold"] = "true"
        $additionalInfoDictionary["MetricMemoryPercentage"] = "$($result.PMemoryPercentage)"
        $additionalInfoDictionary["BelowNetworkThreshold"] = "true"
        $additionalInfoDictionary["MetricNetworkMbps"] = "$($result.PNetworkMbps)"

        $targetSku = $null
        if ($additionalInfoDictionary.targetSku -ne "Shutdown") {
            $currentSku = $skus | Where-Object { $_.Name -eq $additionalInfoDictionary.currentSku }
            $currentSkuvCPUs = [int]($currentSku.Capabilities | Where-Object { $_.Name -eq 'vCPUsAvailable' }).Value
            $targetSku = $skus | Where-Object { $_.Name -eq $additionalInfoDictionary.targetSku }
            $targetSkuvCPUs = [int]($targetSku.Capabilities | Where-Object { $_.Name -eq 'vCPUsAvailable' }).Value
            $targetMaxDataDiskCount = [int]($targetSku.Capabilities | Where-Object { $_.Name -eq 'MaxDataDiskCount' }).Value
            if ($targetMaxDataDiskCount -gt 0) {
                if (-not([string]::isNullOrEmpty($result.DataDiskCount_s))) {
                    if ([int]$result.DataDiskCount_s -gt $targetMaxDataDiskCount) {
                        $fitScore = 1
                        $additionalInfoDictionary["SupportsDataDisksCount"] = "false:needs$($result.DataDiskCount_s)-max$targetMaxDataDiskCount"
                    }
                }
                else {
                    $fitScore -= 1
                    $additionalInfoDictionary["SupportsDataDisksCount"] = "unknown:max$targetMaxDataDiskCount"
                }
            }
            else {
                $fitScore -= 1
                $additionalInfoDictionary["SupportsDataDisksCount"] = "unknown:needs$($result.DataDiskCount_s)"
            }
            $targetMaxNICCount = [int]($targetSku.Capabilities | Where-Object { $_.Name -eq 'MaxNetworkInterfaces' }).Value
            if ($targetMaxNICCount -gt 0) {
                if (-not([string]::isNullOrEmpty($result.NicCount_s))) {
                    if ([int]$result.NicCount_s -gt $targetMaxNICCount) {
                        $fitScore = 1
                        $additionalInfoDictionary["SupportsNICCount"] = "false:needs$($result.NicCount_s)-max$targetMaxNICCount"
                    }
                }
                else {
                    $fitScore -= 1
                    $additionalInfoDictionary["SupportsNICCount"] = "unknown:max$targetMaxNICCount"
                }
            }
            else {
                $fitScore -= 1
                $additionalInfoDictionary["SupportsNICCount"] = "unknown:needs$($result.NicCount_s)"
            }
            $targetUncachedDiskIOPS = [int]($targetSku.Capabilities | Where-Object { $_.Name -eq 'UncachedDiskIOPS' }).Value
            if ($targetUncachedDiskIOPS -gt 0) {
                if (-not([string]::isNullOrEmpty($result.MaxPIOPS))) {
                    if ([double]$result.MaxPIOPS -ge [double]$targetUncachedDiskIOPS) {
                        $fitScore -= 1
                        $additionalInfoDictionary["SupportsIOPS"] = "false:needs$($result.MaxPIOPS)-max$targetUncachedDiskIOPS"
                    }
                }
                else {
                    $fitScore -= 0.5
                    $additionalInfoDictionary["SupportsIOPS"] = "unknown:max$targetUncachedDiskIOPS"
                }
            }
            else {
                $fitScore -= 1
                $additionalInfoDictionary["SupportsIOPS"] = "unknown:needs$($result.MaxPIOPS)"
            }
            $targetUncachedDiskMiBps = [double]([long]($targetSku.Capabilities | Where-Object { $_.Name -eq 'UncachedDiskBytesPerSecond' }).Value) / 1024 / 1024
            if ($targetUncachedDiskMiBps -gt 0) { 
                if (-not([string]::isNullOrEmpty($result.MaxPMiBps))) {
                    if ([double]$result.MaxPMiBps -ge $targetUncachedDiskMiBps) {
                        $fitScore -= 1
                        $additionalInfoDictionary["SupportsMiBps"] = "false:needs$($result.MaxPMiBps)-max$targetUncachedDiskMiBps"
                    }
                }
                else {
                    $fitScore -= 0.5
                    $additionalInfoDictionary["SupportsMiBps"] = "unknown:max$targetUncachedDiskMiBps"
                }
            }
            else {
                $additionalInfoDictionary["SupportsMiBps"] = "unknown:needs$($result.MaxPMiBps)"
            }

            $savingCoefficient = [double] $currentSkuvCPUs / $targetSkuvCPUs

            if ($savingCoefficient -gt 1)
            {
                $targetSkuSavingsMonthly = [double]$result.Last30DaysCost - ([double]$result.Last30DaysCost / $savingCoefficient)
            }
            else
            {
                $targetSkuSavingsMonthly = [double]$result.Last30DaysCost / 2
            }

            if ($targetSku -and $null -eq $skuPricesFound[$targetSku.Name])
            {
                $skuPricesFound[$targetSku.Name] = Find-SkuHourlyPrice -SKUName $targetSku.Name -SKUPriceSheet $pricesheetEntries
            }

            $tentativeTargetSkuSavingsMonthly = -1

            if ($targetSku -and $skuPricesFound[$targetSku.Name] -gt 0 -and $skuPricesFound[$targetSku.Name] -lt [double]::MaxValue)
            {
                $targetSkuPrice = $skuPricesFound[$targetSku.Name]

                if ($null -eq $skuPricesFound[$currentSku.Name])
                {
                    $skuPricesFound[$currentSku.Name] = Find-SkuHourlyPrice -SKUName $currentSku.Name -SKUPriceSheet $pricesheetEntries
                }

                if ($skuPricesFound[$currentSku.Name] -gt 0)
                {
                    $currentSkuPrice = $skuPricesFound[$currentSku.Name]
                    $tentativeTargetSkuSavingsMonthly = ($currentSkuPrice * [double] $result.Last30DaysQuantity) - ($targetSkuPrice * [double] $result.Last30DaysQuantity)
                }
                else
                {
                    $tentativeTargetSkuSavingsMonthly = [double]$result.Last30DaysCost - ($targetSkuPrice * [double] $result.Last30DaysQuantity)
                }
            }

            if ($tentativeTargetSkuSavingsMonthly -ge 0)
            {
                $targetSkuSavingsMonthly = $tentativeTargetSkuSavingsMonthly
            }

            if ($targetSkuSavingsMonthly -eq [double]::PositiveInfinity)
            {
                $targetSkuSavingsMonthly = [double] $result.Last30DaysCost / 2
            }

            $savingsMonthly = $targetSkuSavingsMonthly

        }
        else
        {
            $savingsMonthly = [double]$result.Last30DaysCost
        }

        $cpuThreshold = $cpuPercentageThreshold
        $memoryThreshold = $memoryPercentageThreshold
        $networkThreshold = $networkMpbsThreshold
        if ($additionalInfoDictionary.targetSku -eq "Shutdown") {
            $cpuThreshold = $cpuPercentageShutdownThreshold
            $memoryThreshold = $memoryPercentageShutdownThreshold
            $networkThreshold = $networkMpbsShutdownThreshold
        }

        if (-not([string]::isNullOrEmpty($result.PCPUPercentage))) {
            if ([double]$result.PCPUPercentage -ge [double]$cpuThreshold) {
                $fitScore -= 0.5
                $additionalInfoDictionary["BelowCPUThreshold"] = "false:needs$($result.PCPUPercentage)-max$cpuThreshold"
            }
            $hasCpuRamPerfMetrics = $true
        }
        else {
            $fitScore -= 0.5
            $additionalInfoDictionary["BelowCPUThreshold"] = "unknown:max$cpuThreshold"
        }
        if (-not([string]::isNullOrEmpty($result.PMemoryPercentage))) {
            if ([double]$result.PMemoryPercentage -ge [double]$memoryThreshold) {
                $fitScore -= 0.5
                $additionalInfoDictionary["BelowMemoryThreshold"] = "false:needs$($result.PMemoryPercentage)-max$memoryThreshold"
            }
            $hasCpuRamPerfMetrics = $true
        }
        else {
            $fitScore -= 0.5
            $additionalInfoDictionary["BelowMemoryThreshold"] = "unknown:max$memoryThreshold"
        }
        if (-not([string]::isNullOrEmpty($result.PNetworkMbps))) {
            if ([double]$result.PNetworkMbps -ge [double]$networkThreshold) {
                $fitScore -= 0.1
                $additionalInfoDictionary["BelowNetworkThreshold"] = "false:needs$($result.PNetworkMbps)-max$networkThreshold"
            }
        }
        else {
            $fitScore -= 0.1
            $additionalInfoDictionary["BelowNetworkThreshold"] = "unknown:max$networkThreshold"
        }

        $fitScore = [Math]::max(0.0, $fitScore)
    }
    else
    {
        if (-not([string]::IsNullOrEmpty($additionalInfoDictionary["annualSavingsAmount"])))
        {
            $savingsMonthly = [double] $additionalInfoDictionary["annualSavingsAmount"] / 12
        }
        else
        {
            if ($result.RecommendationTypeId_g -eq $rightSizeRecommendationId)
            {
                $savingsMonthly = [double] $result.Last30DaysCost
            }
            else
            {
                $savingsMonthly = 0.0 # unknown
            }
        }
    }

    $additionalInfoDictionary["savingsAmount"] = [double] $savingsMonthly

    $queryInstanceId = $result.InstanceId_s
    if (-not($hasCpuRamPerfMetrics))
    {
        switch ($result.Cloud_s)
        {
            "AzureCloud" { $azureTld = "com" }
            "AzureChinaCloud" { $azureTld = "cn" }
            "AzureUSGovernment" { $azureTld = "us" }
            default { $azureTld = "com" }
        }

        $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"
    }
    else
    {
        $queryWorkspace = ""
        if (-not([string]::IsNullOrEmpty($result.WorkspaceId)) -and $result.WorkspaceId -ne $workspaceId)
        {
            $queryWorkspace = "workspace('$($result.WorkspaceId)')."
        }

        $queryText = @"
        let perfInterval = $($perfDaysBackwards)d;
        let armId = tolower(`'$queryInstanceId`');
        let gInt = $perfTimeGrain;
        let LinuxMemoryPerf = $($queryWorkspace)Perf
        | where TimeGenerated > ago(perfInterval)
        | where CounterName == '% Used Memory' and _ResourceId =~ armId
        | project TimeGenerated, MemoryPercentage = CounterValue;
        let WindowsMemoryPerf = $($queryWorkspace)Perf
        | where TimeGenerated > ago(perfInterval)
        | where CounterName == 'Available MBytes' and _ResourceId =~ armId
        | extend MemoryAvailableMBs = CounterValue, InstanceId = tolower(_ResourceId)
        | project TimeGenerated, MemoryAvailableMBs, InstanceId;
        let MemoryPerf = WindowsMemoryPerf
        | join kind=inner (
            $vmsTableName
            | where TimeGenerated > ago(1d)
            | extend InstanceId = tolower(InstanceId_s)
            | distinct InstanceId, MemoryMB_s
        ) on InstanceId
        | extend MemoryPercentage = todouble(toint(MemoryMB_s) - toint(MemoryAvailableMBs)) / todouble(MemoryMB_s) * 100
        | project TimeGenerated, MemoryPercentage
        | union LinuxMemoryPerf
        | summarize P$($memoryPercentile)MemoryPercentage = percentile(MemoryPercentage, $memoryPercentile) by bin(TimeGenerated, gInt);
        let ProcessorPerf = $($queryWorkspace)Perf
        | where TimeGenerated > ago(perfInterval)
        | where CounterName == '% Processor Time' and InstanceName == '_Total' and _ResourceId =~ armId
        | summarize P$($cpuPercentile)CPUPercentage = percentile(CounterValue, $cpuPercentile) by bin(TimeGenerated, gInt);
        MemoryPerf
        | join kind=inner (ProcessorPerf) on TimeGenerated
        | render timechart
"@

        switch ($cloudEnvironment)
        {
            "AzureCloud" { $azureTld = "com" }
            "AzureChinaCloud" { $azureTld = "cn" }
            "AzureUSGovernment" { $azureTld = "us" }
            default { $azureTld = "com" }
        }

        $encodedQuery = [System.Uri]::EscapeDataString($queryText)
        $detailsQueryStart = $datetime.AddDays(-30).ToString("yyyy-MM-dd")
        $detailsQueryEnd = $datetime.AddDays(8).ToString("yyyy-MM-dd")
        $detailsURL = "https://portal.azure.$azureTld#@$workspaceTenantId/blade/Microsoft_Azure_Monitoring_Logs/LogsBlade/resourceId/%2Fsubscriptions%2F$workspaceSubscriptionId%2Fresourcegroups%2F$workspaceRG%2Fproviders%2Fmicrosoft.operationalinsights%2Fworkspaces%2F$workspaceName/source/LogsBlade.AnalyticsShareLinkToQuery/query/$encodedQuery/timespan/$($detailsQueryStart)T00%3A00%3A00.000Z%2F$($detailsQueryEnd)T00%3A00%3A00.000Z"
    }

    $recommendation = New-Object PSObject -Property @{
        Timestamp                   = $timestamp
        Cloud                       = $result.Cloud_s
        Category                    = "Cost"
        ImpactedArea                = $result.ImpactedArea_s
        Impact                      = $result.Impact_s
        RecommendationType          = "Saving"
        RecommendationSubType       = "AdvisorCost"
        RecommendationSubTypeId     = $result.RecommendationTypeId_g
        RecommendationDescription   = $result.Description_s
        RecommendationAction        = $result.RecommendationText_s
        InstanceId                  = $result.InstanceId_s
        InstanceName                = $result.InstanceName_s
        AdditionalInfo              = $additionalInfoDictionary
        ResourceGroup               = $result.ResourceGroup
        SubscriptionGuid            = $result.SubscriptionGuid_g
        SubscriptionName            = $result.SubscriptionName
        TenantGuid                  = $result.TenantGuid_g
        FitScore                    = $fitScore
        Tags                        = $tags
        DetailsURL                  = $detailsURL
    }

    $recommendations += $recommendation
}

# Export the recommendations as JSON to blob storage

Write-Output "Exporting final $($recommendations.Count) results as a JSON file..."

$fileDate = $datetime.ToString("yyyyMMdd")
$jsonExportPath = "advisor-cost-augmented-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

Write-Output "Uploading $jsonExportPath to blob storage..."

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json" };
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."
