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

$deallocatedIntervalDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendationLongDeallocatedVmsIntervalDays")
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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('ARGManagedDisk','ARGVirtualMachine','AzureConsumption','ARGResourceContainers')"
    
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
$disksTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGManagedDisk' }).LogAnalyticsSuffix + "_CL"
$consumptionTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureConsumption' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $vmsTableName, $disksTableName, $subscriptionsTableName and $consumptionTableName"

$Conn.Close()    
$Conn.Dispose()            

$recommendationSearchTimeSpan = $deallocatedIntervalDays + $consumptionOffsetDaysStart
$offlineInterval = $deallocatedIntervalDays + $consumptionOffsetDays
$billingInterval = 30 + $consumptionOffsetDays

# Grab a context reference to the Storage Account where the recommendations file will be stored


$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

if ($workspaceSubscriptionId -ne $storageAccountSinkSubscriptionId)
{
    Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
}

$recommendationsErrors = 0

Write-Output "Looking for VMs that have been deallocated for more than 30 days..."

# Execute the recommendation query against Log Analytics

$baseQuery = @"
    let offlineInterval = $($offlineInterval)d;
    let billingInterval = $($billingInterval)d;
    let billingWindowIntervalEnd = $($consumptionOffsetDays)d; 
    let billingWindowIntervalStart = $($consumptionOffsetDaysStart)d; 
    let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(billingInterval) | summarize max(todatetime(Date_s)))); 
    let stime = etime-offlineInterval;
    let BilledVMs = $consumptionTableName 
    | where todatetime(Date_s) between (stime..etime)
    | where ResourceId like 'microsoft.compute/virtualmachines/' or ResourceId like 'microsoft.classiccompute/virtualmachines/' 
    | extend InstanceId_s = tolower(ResourceId)
    | distinct InstanceId_s;
    let RunningVMs = $vmsTableName
    | where TimeGenerated > ago(billingWindowIntervalStart) and TimeGenerated < ago(billingWindowIntervalEnd)
    | where PowerState_s has_any ('running','starting','readyrole')
    | distinct InstanceId_s;
    let BilledDisks = $consumptionTableName 
    | where todatetime(Date_s) between (stime..etime)
    | where ResourceId like 'microsoft.compute/disks/'
    | extend BillingInstanceId = tolower(ResourceId)
    | summarize DisksCosts = sum(todouble(CostInBillingCurrency_s)) by BillingInstanceId;
    $vmsTableName
    | where TimeGenerated > ago(billingWindowIntervalStart) and TimeGenerated < ago(billingWindowIntervalEnd)
    | where InstanceId_s !in (RunningVMs)
    | join kind=leftouter (BilledVMs) on InstanceId_s
    | where isempty(InstanceId_s1)
    | project InstanceId_s, VMName_s, ResourceGroupName_s, SubscriptionGuid_g, TenantGuid_g, Cloud_s, Tags_s 
    | join kind=leftouter (
        $disksTableName 
        | where TimeGenerated > ago(1d)
        | project DiskInstanceId = InstanceId_s, SKU_s, OwnerVMId_s
    ) on `$left.InstanceId_s == `$right.OwnerVMId_s
    | join kind=leftouter (
        BilledDisks
    ) on `$left.DiskInstanceId == `$right.BillingInstanceId
    | summarize TotalDisksCosts = sum(DisksCosts) by InstanceId_s, VMName_s, ResourceGroupName_s, SubscriptionGuid_g, TenantGuid_g, Cloud_s, Tags_s
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
        let offlineInterval = $($offlineInterval)d;
        $consumptionTableName
        | extend ResourceId = tolower(ResourceId) 
        | where ResourceId =~ '$queryInstanceId'
        | where todatetime(Date_s) < now()
        | join kind=inner (
            $disksTableName
            | extend DiskInstanceId = InstanceId_s
        )
        on `$left.ResourceId == `$right.OwnerVMId_s
        | summarize DeallocatedSince = max(todatetime(Date_s)) by DiskName_s, DiskSizeGB_s, SKU_s, DiskInstanceId 
        | join kind=inner
        (
            $consumptionTableName
            | where todatetime(Date_s) > ago(offlineInterval)
            | extend DiskInstanceId = tolower(ResourceId)
            | summarize DiskCosts = sum(todouble(CostInBillingCurrency_s)) by DiskInstanceId
        )
        on DiskInstanceId
        | project DeallocatedSince, DiskName_s, DiskSizeGB_s, SKU_s, MonthlyCosts = DiskCosts
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

    $additionalInfoDictionary["LongDeallocatedThreshold"] = $deallocatedIntervalDays
    $additionalInfoDictionary["CostsAmount"] = [double] $result.TotalDisksCosts 
    $additionalInfoDictionary["savingsAmount"] = [double] $result.TotalDisksCosts 

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
        ImpactedArea = "Microsoft.Compute/virtualMachines"
        Impact = "Medium"
        RecommendationType = "Saving"
        RecommendationSubType = "LongDeallocatedVms"
        RecommendationSubTypeId = "c320b790-2e58-452a-aa63-7b62c383ad8a"
        RecommendationDescription = "Virtual Machine has been deallocated for long with disks still incurring costs"
        RecommendationAction = "Delete Virtual Machine or downgrade its disks to Standard HDD SKU"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.VMName_s
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
$jsonExportPath = "longdeallocatedvms-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for VMs that are stopped (not deallocated)..."

# Execute the recommendation query against Log Analytics

$baseQuery = @"
    $vmsTableName
    | where TimeGenerated > ago(1d)
    | where PowerState_s has 'stopped'
    | project InstanceId_s, VMName_s, ResourceGroupName_s, SubscriptionGuid_g, TenantGuid_g, Cloud_s, Tags_s 
    | join kind=leftouter ( 
        $consumptionTableName
        | where TimeGenerated > ago(1d) and MeterCategory_s == 'Virtual Machines'
        | project InstanceId_s=tolower(ResourceId), UnitPrice_s, EffectivePrice_s
        | summarize arg_max(todouble(EffectivePrice_s), *) by InstanceId_s
        | project InstanceId_s, MonthlyCost=24*todouble(iif(todouble(UnitPrice_s) > 0, todouble(UnitPrice_s), todouble(EffectivePrice_s)))*30
    ) on InstanceId_s
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
        let LastNonStopped = toscalar($vmsTableName
        | where InstanceId_s =~ '$queryInstanceId'
        | where TimeGenerated < now()
        | where PowerState_s !has 'stopped'
        | summarize max(todatetime(StatusDate_s)));
        $consumptionTableName
        | where ResourceId =~ '$queryInstanceId'
        | where todatetime(Date_s) >= LastNonStopped
        | where MeterCategory_s == 'Virtual Machines'
        | summarize ComputeCostsSinceStopped = sum(todouble(Quantity_s)*todouble(UnitPrice_s)) by MeterSubCategory_s, StoppedSince=LastNonStopped
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

    $additionalInfoDictionary["CostsAmount"] = [double] $result.MonthlyCost 
    $additionalInfoDictionary["savingsAmount"] = [double] $result.MonthlyCost

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
        ImpactedArea = "Microsoft.Compute/virtualMachines"
        Impact = "High"
        RecommendationType = "Saving"
        RecommendationSubType = "StoppedVms"
        RecommendationSubTypeId = "110fea55-a9c3-480d-8248-116f61e139a8"
        RecommendationDescription = "Virtual Machine is stopped (not deallocated) and still incurring costs"
        RecommendationAction = "Deallocate Virtual Machine"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.VMName_s
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
$jsonExportPath = "stoppedvms-$fileDate.json"
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