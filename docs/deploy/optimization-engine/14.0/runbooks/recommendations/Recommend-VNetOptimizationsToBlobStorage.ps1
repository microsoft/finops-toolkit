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

$subnetMaxUsedThresholdVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationVNetSubnetMaxUsedPercentageThreshold" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($subnetMaxUsedThresholdVar) -or $subnetMaxUsedThresholdVar -eq 0)
{
    $subnetMaxUsedThreshold = 80
}
else
{
    $subnetMaxUsedThreshold = [int] $subnetMaxUsedThresholdVar
}

$subnetMinUsedThresholdVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationVNetSubnetMinUsedPercentageThreshold" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($subnetMinUsedThresholdVar) -or $subnetMinUsedThresholdVar -eq 0)
{
    $subnetMinUsedThreshold = 5
}
else
{
    $subnetMinUsedThreshold = [int] $subnetMinUsedThresholdVar
}

# must be a comma-separated, single-quote enclosed list of subnet names, e.g., 'gatewaysubnet','azurebastionsubnet'
$subnetFreeExclusions = Get-AutomationVariable -Name  "AzureOptimization_RecommendationVNetSubnetUsedPercentageExclusions" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($subnetFreeExclusions))
{
    $subnetFreeExclusions = "'gatewaysubnet'"
}

$subnetMinAgeVar = Get-AutomationVariable -Name  "AzureOptimization_RecommendationVNetSubnetEmptyMinAgeInDays" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($subnetMinAgeVar) -or $subnetMinAgeVar -eq 0)
{
    $subnetMinAge = 30
}
else
{
    $subnetMinAge = [int] $subnetMinAgeVar
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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('ARGNetworkInterface','ARGVirtualNetwork','ARGResourceContainers', 'ARGNSGRule', 'ARGPublicIP','AzureConsumption')"

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

$nicsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGNetworkInterface' }).LogAnalyticsSuffix + "_CL"
$vNetsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGVirtualNetwork' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"
$nsgRulesTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGNSGRule' }).LogAnalyticsSuffix + "_CL"
$publicIpsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGPublicIP' }).LogAnalyticsSuffix + "_CL"
$consumptionTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureConsumption' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $nicsTableName, $nsgRulesTableName, $publicIpsTableName, $subscriptionsTableName, $consumptionTableName and $vNetsTableName"

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

Write-Output "Looking for subnets with free IP space less than $subnetMaxUsedThreshold%, excluding $subnetFreeExclusions..."

$baseQuery = @"
    $vNetsTableName
    | where TimeGenerated > ago(1d)
    | where SubnetName_s !in ($subnetFreeExclusions)
    | extend FreeIPs = toint(SubnetTotalPrefixIPs_s) - toint(SubnetUsedIPs_s)
    | extend UsedIPPercentage = (todouble(SubnetUsedIPs_s) / todouble(SubnetTotalPrefixIPs_s)) * 100
    | where UsedIPPercentage >= $subnetMaxUsedThreshold
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
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/subnets"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["subnetName"] = $result.SubnetName_s
    $additionalInfoDictionary["subnetPrefix"] = $result.SubnetPrefix_s
    $additionalInfoDictionary["subnetTotalIPs"] = $result.SubnetTotalPrefixIPs_s
    $additionalInfoDictionary["subnetFreeIPs"] = $result.FreeIPs
    $additionalInfoDictionary["subnetUsedIPPercentage"] = $result.UsedIPPercentage

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
        ImpactedArea = "Microsoft.Network/virtualNetworks"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "HighSubnetIPSpaceUsage"
        RecommendationSubTypeId = "5292525b-5095-4e52-803e-e17192f1d099"
        RecommendationDescription = "Subnets with a high IP space usage may constrain operations"
        RecommendationAction = "Move network devices to a subnet with a larger address space"
        InstanceId = $result.InstanceId_s
        InstanceName = "$($result.VNetName_s)/$($result.SubnetName_s)"
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
$jsonExportPath = "subnetshighspaceusage-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for subnets with used IP space less than $subnetMinUsedThreshold%..."

$baseQuery = @"
    $vNetsTableName
    | where TimeGenerated > ago(1d)
    | where SubnetName_s !in ($subnetFreeExclusions)
    | extend FreeIPs = toint(SubnetTotalPrefixIPs_s) - toint(SubnetUsedIPs_s)
    | extend UsedIPPercentage = (todouble(SubnetUsedIPs_s) / todouble(SubnetTotalPrefixIPs_s)) * 100
    | where UsedIPPercentage > 0 and UsedIPPercentage <= $subnetMinUsedThreshold
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
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/subnets"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["subnetName"] = $result.SubnetName_s
    $additionalInfoDictionary["subnetPrefix"] = $result.SubnetPrefix_s
    $additionalInfoDictionary["subnetTotalIPs"] = $result.SubnetTotalPrefixIPs_s
    $additionalInfoDictionary["subnetUsedIPs_s"] = $result.SubnetUsedIPs_s
    $additionalInfoDictionary["subnetUsedIPPercentage"] = $result.UsedIPPercentage

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
        ImpactedArea = "Microsoft.Network/virtualNetworks"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "LowSubnetIPSpaceUsage"
        RecommendationSubTypeId = "0f27b41c-869a-4563-86e9-d1c94232ba81"
        RecommendationDescription = "Subnets with a low IP space usage are a waste of virtual network address space"
        RecommendationAction = "Move network devices to a subnet with a smaller address space"
        InstanceId = $result.InstanceId_s
        InstanceName = "$($result.VNetName_s)/$($result.SubnetName_s)"
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
$jsonExportPath = "subnetslowspaceusage-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for subnets without any device..."

$baseQuery = @"
    $vNetsTableName
    | where TimeGenerated > ago(1d)
    | where toint(SubnetUsedIPs_s) == 0 and toint(SubnetDelegationsCount_s) == 0
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
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/subnets"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["subnetName"] = $result.SubnetName_s
    $additionalInfoDictionary["subnetPrefix"] = $result.SubnetPrefix_s
    $additionalInfoDictionary["subnetTotalIPs"] = $result.SubnetTotalPrefixIPs_s
    $additionalInfoDictionary["subnetUsedIPs_s"] = $result.SubnetUsedIPs_s

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
        ImpactedArea = "Microsoft.Network/virtualNetworks"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "NoSubnetIPSpaceUsage"
        RecommendationSubTypeId = "343bbfb7-5bec-4711-8353-398454d42b7b"
        RecommendationDescription = "Subnets without any IP usage are a waste of virtual network address space"
        RecommendationAction = "Delete the subnet to reclaim address space"
        InstanceId = $result.InstanceId_s
        InstanceName = "$($result.VNetName_s)/$($result.SubnetName_s)"
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
$jsonExportPath = "subnetsnospaceusage-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for orphaned NICs..."

$baseQuery = @"
    $nicsTableName
    | where TimeGenerated > ago(1d)
    | where isempty(OwnerVMId_s) and isempty(OwnerPEId_s)
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
    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $queryInstanceId = $result.InstanceId_s
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["privateIpAddress"] = $result.PrivateIPAddress_s

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
        ImpactedArea = "Microsoft.Network/networkInterfaces"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "OrphanedNIC"
        RecommendationSubTypeId = "4c5c2d0c-b6a4-4c59-bc18-6fff6c1f5b23"
        RecommendationDescription = "Orphaned Network Interfaces (without owner VM or PE) unnecessarily consume IP address space"
        RecommendationAction = "Delete the NIC to reclaim address space"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.Name_s
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
$jsonExportPath = "orphanednics-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for NSG rules referring empty or removed subnets..."

$baseQuery = @"
    let MinimumSubnetAge = $($subnetMinAge)d;
    let SubnetsToday = materialize( $vNetsTableName
    | where TimeGenerated > ago(1d)
    | extend SubnetId = tolower(strcat(InstanceId_s, '/subnets/', SubnetName_s))
    | distinct SubnetId, SubnetPrefix_s, SubnetUsedIPs_s, SubnetDelegationsCount_s );
    let SubnetsBefore = materialize( $vNetsTableName
    | where TimeGenerated < ago(1d)
    | extend SubnetId = tolower(strcat(InstanceId_s, '/subnets/', SubnetName_s))
    | summarize ExistsSince = min(todatetime(StatusDate_s)) by SubnetId, SubnetPrefix_s );
    let SubnetsExistingLongEnoughIds = SubnetsBefore | where ExistsSince < ago(MinimumSubnetAge) | distinct SubnetId;
    let EmptySubnets = SubnetsToday | where SubnetId in (SubnetsExistingLongEnoughIds) and toint(SubnetUsedIPs_s) == 0 and toint(SubnetDelegationsCount_s) == 0;
    let SubnetsTodayIds = SubnetsToday | distinct SubnetId;
    let SubnetsTodayPrefixes = SubnetsToday | distinct SubnetPrefix_s;
    let RemovedSubnets = SubnetsBefore | where SubnetId !in (SubnetsTodayIds) and SubnetPrefix_s !in (SubnetsTodayPrefixes);
    let NSGRules = materialize($nsgRulesTableName
    | where TimeGenerated > ago(1d)
    | extend SourceAddresses = split(RuleSourceAddresses_s,',')
    | mvexpand SourceAddresses
    | extend SourceAddress = tostring(SourceAddresses)
    | extend DestinationAddresses = split(RuleDestinationAddresses_s,',')
    | mvexpand DestinationAddresses
    | extend DestinationAddress = tostring(DestinationAddresses)
    | project NSGId = InstanceId_s, RuleName_s, DestinationAddress, SourceAddress, SubscriptionGuid_g, Cloud_s, TenantGuid_g, ResourceGroupName_s, NSGName = NSGName_s, Tags_s);
    let EmptySubnetsAsSource = EmptySubnets
    | join kind=inner ( NSGRules ) on `$left.SubnetPrefix_s == `$right.SourceAddress
    | extend SubnetState = 'empty';
    let EmptySubnetsAsDestination = EmptySubnets
    | join kind=inner ( NSGRules ) on `$left.SubnetPrefix_s == `$right.DestinationAddress
    | extend SubnetState = 'empty';
    let RemovedSubnetsAsSource = RemovedSubnets
    | join kind=inner ( NSGRules ) on `$left.SubnetPrefix_s == `$right.SourceAddress
    | extend SubnetState = 'unexisting';
    let RemovedSubnetsAsDestination = RemovedSubnets
    | join kind=inner ( NSGRules ) on `$left.SubnetPrefix_s == `$right.DestinationAddress
    | extend SubnetState = 'unexisting';
    EmptySubnetsAsSource
    | union EmptySubnetsAsDestination
    | union RemovedSubnetsAsSource
    | union RemovedSubnetsAsDestination
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionGuid_g
    | where isnotempty(SubnetPrefix_s)
    | distinct NSGId, NSGName, RuleName_s, SubscriptionGuid_g, SubscriptionName, ResourceGroupName_s, TenantGuid_g, Cloud_s, SubnetId, SubnetPrefix_s, SubnetState, Tags_s
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

    $queryInstanceId = $result.NSGId
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["subnetId"] = $result.SubnetId
    $additionalInfoDictionary["subnetPrefix"] = $result.SubnetPrefix_s
    $additionalInfoDictionary["subnetState"] = $result.SubnetState

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
        Category = "Security"
        ImpactedArea = "Microsoft.Network/networkSecurityGroups"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "NSGRuleForEmptyOrUnexistingSubnet"
        RecommendationSubTypeId = "b5491cde-f76c-4423-8c4c-89e3558ff2f2"
        RecommendationDescription = "NSG rules referring to empty or unexisting subnets"
        RecommendationAction = "Update or remove the NSG rule to improve your network security posture"
        InstanceId = $result.NSGId
        InstanceName = "$($result.NSGName)/$($result.RuleName_s)"
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
$jsonExportPath = "nsgrules-emptyunexistingsubnets-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for NSG rules referring orphan or removed NICs..."

$baseQuery = @"
    let NICsToday = materialize( $nicsTableName
    | where TimeGenerated > ago(1d)
    | extend NICId = tolower(InstanceId_s)
    | distinct NICId, PrivateIPAddress_s, PublicIPId_s, OwnerVMId_s, OwnerPEId_s );
    let NICsBefore = $nicsTableName
    | where TimeGenerated < ago(1d)
    | extend NICId = tolower(InstanceId_s)
    | distinct NICId, PrivateIPAddress_s, PublicIPId_s;
    let OrphanNICs = NICsToday
    | where isempty(OwnerVMId_s) and isempty(OwnerPEId_s)
    | extend PublicIPId_s = tolower(PublicIPId_s)
    | join kind=leftouter (
        $publicIpsTableName
        | where TimeGenerated > ago(1d)
        | project PublicIPId_s = tolower(InstanceId_s), PublicIPAddress = IPAddress
    ) on PublicIPId_s;
    let NICsTodayIds = NICsToday | distinct NICId;
    let NICsTodayIPs = NICsToday | distinct PrivateIPAddress_s;
    let RemovedNICs = NICsBefore
    | where NICId  !in (NICsTodayIds) and PrivateIPAddress_s  !in (NICsTodayIPs)
    | extend PublicIPId_s = tolower(PublicIPId_s)
    | join kind=leftouter (
        $publicIpsTableName
        | where TimeGenerated < ago(1d)
        | project PublicIPId_s = tolower(InstanceId_s), PublicIPAddress = IPAddress
    ) on PublicIPId_s;
    let NSGRules = materialize($nsgRulesTableName
    | where TimeGenerated > ago(1d)
    | extend SourceAddresses = split(RuleSourceAddresses_s,',')
    | mvexpand SourceAddresses
    | extend SourceAddress = replace('/32','',tostring(SourceAddresses))
    | extend DestinationAddresses = split(RuleDestinationAddresses_s,',')
    | mvexpand DestinationAddresses
    | extend DestinationAddress = replace('/32','',tostring(DestinationAddresses))
    | project NSGId = InstanceId_s, RuleName_s, DestinationAddress, SourceAddress, SubscriptionGuid_g, Cloud_s, TenantGuid_g, ResourceGroupName_s, NSGName = NSGName_s, Tags_s);
    let OrphanNICsAsPrivateSource = OrphanNICs
    | join kind=inner ( NSGRules ) on `$left.PrivateIPAddress_s == `$right.SourceAddress
    | extend NICState = 'orphan', IPAddress = PrivateIPAddress_s;
    let OrphanNICsAsPublicSource = OrphanNICs
    | join kind=inner ( NSGRules ) on `$left.PublicIPAddress == `$right.SourceAddress
    | extend NICState = 'orphan', IPAddress = PublicIPAddress;
    let OrphanNICsAsPrivateDestination = OrphanNICs
    | join kind=inner ( NSGRules ) on `$left.PrivateIPAddress_s == `$right.DestinationAddress
    | extend NICState = 'orphan', IPAddress = PrivateIPAddress_s;
    let OrphanNICsAsPublicDestination = OrphanNICs
    | join kind=inner ( NSGRules ) on `$left.PublicIPAddress == `$right.DestinationAddress
    | extend NICState = 'orphan', IPAddress = PublicIPAddress;
    let RemovedNICsAsPrivateSource = RemovedNICs
    | join kind=inner ( NSGRules ) on `$left.PrivateIPAddress_s == `$right.SourceAddress
    | extend NICState = 'unexisting', IPAddress = PrivateIPAddress_s;
    let RemovedNICsAsPublicSource = RemovedNICs
    | join kind=inner ( NSGRules ) on `$left.PublicIPAddress == `$right.SourceAddress
    | extend NICState = 'unexisting', IPAddress = PublicIPAddress;
    let RemovedNICsAsPrivateDestination = RemovedNICs
    | join kind=inner ( NSGRules ) on `$left.PrivateIPAddress_s == `$right.DestinationAddress
    | extend NICState = 'unexisting', IPAddress = PrivateIPAddress_s;
    let RemovedNICsAsPublicDestination = RemovedNICs
    | join kind=inner ( NSGRules ) on `$left.PublicIPAddress == `$right.DestinationAddress
    | extend NICState = 'unexisting', IPAddress = PublicIPAddress;
    OrphanNICsAsPrivateSource
    | union OrphanNICsAsPublicSource
    | union OrphanNICsAsPrivateDestination
    | union OrphanNICsAsPublicDestination
    | union RemovedNICsAsPrivateSource
    | union RemovedNICsAsPublicSource
    | union RemovedNICsAsPrivateDestination
    | union RemovedNICsAsPublicDestination
    | where isnotempty(IPAddress)
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionGuid_g
    | distinct NSGId, NSGName, RuleName_s, SubscriptionGuid_g, SubscriptionName, ResourceGroupName_s, TenantGuid_g, Cloud_s, NICId, IPAddress, NICState, Tags_s
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

    $queryInstanceId = $result.NSGId
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["nicId"] = $result.NICId
    $additionalInfoDictionary["ipAddress"] = $result.IPAddress
    $additionalInfoDictionary["nicState"] = $result.NICState

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
        Category = "Security"
        ImpactedArea = "Microsoft.Network/networkSecurityGroups"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "NSGRuleForOrphanOrUnexistingNIC"
        RecommendationSubTypeId = "3dc1d1f8-19ef-4572-9c9d-78d62831f55a"
        RecommendationDescription = "NSG rules referring to orphan or unexisting NICs"
        RecommendationAction = "Update or remove the NSG rule to improve your network security posture"
        InstanceId = $result.NSGId
        InstanceName = "$($result.NSGName)/$($result.RuleName_s)"
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
$jsonExportPath = "nsgrules-orphanunexistingnics-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for NSG rules referring orphan or removed Public IPs..."

$baseQuery = @"
    let PIPsToday = materialize( $publicIpsTableName
    | where TimeGenerated > ago(1d)
    | extend PublicIPId = tolower(InstanceId_s)
    | distinct PublicIPId, AssociatedResourceId_s, AllocationMethod_s, IPAddress );
    let PIPsBefore = materialize( $publicIpsTableName
    | where TimeGenerated < ago(1d)
    | extend PublicIPId = tolower(InstanceId_s)
    | distinct PublicIPId, IPAddress );
    let OrphanStaticPIPs = PIPsToday
    | where isempty(AssociatedResourceId_s) and AllocationMethod_s == 'static';
    let OrphanDynamicPIPIDs = PIPsToday
    | where isempty(AssociatedResourceId_s) and AllocationMethod_s == 'dynamic'
    | distinct PublicIPId;
    let PIPsTodayIds = PIPsToday | distinct PublicIPId;
    let PIPsTodayIPs = PIPsToday | distinct IPAddress;
    let OrphanDynamicPIPs = PIPsBefore
    | where PublicIPId in (OrphanDynamicPIPIDs) and isnotempty(IPAddress) and IPAddress !in (PIPsTodayIPs);
    let RemovedPIPs = PIPsBefore
    | where PublicIPId !in (PIPsTodayIds) and isnotempty(IPAddress) and IPAddress !in (PIPsTodayIPs);
    let NSGRules = materialize( $nsgRulesTableName
    | where TimeGenerated > ago(1d)
    | extend SourceAddresses = split(RuleSourceAddresses_s,',')
    | mvexpand SourceAddresses
    | extend SourceAddress = replace('/32','',tostring(SourceAddresses))
    | extend DestinationAddresses = split(RuleDestinationAddresses_s,',')
    | mvexpand DestinationAddresses
    | extend DestinationAddress = replace('/32','',tostring(DestinationAddresses))
    | project NSGId = InstanceId_s, RuleName_s, DestinationAddress, SourceAddress, SubscriptionGuid_g, Cloud_s, TenantGuid_g, ResourceGroupName_s, NSGName = NSGName_s, Tags_s);
    let OrphanStaticPIPsAsSource = OrphanStaticPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.SourceAddress
    | extend PIPState = 'orphan';
    let OrphanStaticPIPsAsDestination = OrphanStaticPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.DestinationAddress
    | extend PIPState = 'orphan';
    let OrphanDynamicPIPsAsSource = OrphanDynamicPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.SourceAddress
    | extend PIPState = 'orphan';
    let OrphanDynamicPIPsAsDestination = OrphanDynamicPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.DestinationAddress
    | extend PIPState = 'orphan';
    let RemovedPIPsAsSource = RemovedPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.SourceAddress
    | extend PIPState = 'unexisting';
    let RemovedPIPsAsDestination = RemovedPIPs
    | join kind=inner ( NSGRules ) on `$left.IPAddress == `$right.DestinationAddress
    | extend PIPState = 'unexisting';
    OrphanStaticPIPsAsSource
    | union OrphanDynamicPIPsAsSource
    | union OrphanStaticPIPsAsDestination
    | union OrphanDynamicPIPsAsDestination
    | union RemovedPIPsAsSource
    | union RemovedPIPsAsDestination
    | join kind=leftouter (
        $subscriptionsTableName
        | where TimeGenerated > ago(1d)
        | where ContainerType_s =~ 'microsoft.resources/subscriptions'
        | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
    ) on SubscriptionGuid_g
    | distinct NSGId, NSGName, RuleName_s, SubscriptionGuid_g, SubscriptionName, ResourceGroupName_s, TenantGuid_g, Cloud_s, PublicIPId, IPAddress, PIPState, AllocationMethod_s, Tags_s
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

    $queryInstanceId = $result.NSGId
    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["publicIPId"] = $result.PublicIPId
    $additionalInfoDictionary["ipAddress"] = $result.IPAddress
    $additionalInfoDictionary["publicIPState"] = $result.PIPState
    $additionalInfoDictionary["allocationMethod"] = $result.AllocationMethod_s

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
        Category = "Security"
        ImpactedArea = "Microsoft.Network/networkSecurityGroups"
        Impact = "High"
        RecommendationType = "BestPractices"
        RecommendationSubType = "NSGRuleForOrphanOrUnexistingPublicIP"
        RecommendationSubTypeId = "fe40cbe7-bdee-4cce-b072-cf25e1247b7a"
        RecommendationDescription = "NSG rules referring to orphan or unexisting Public IPs"
        RecommendationAction = "Update or remove the NSG rule to improve your network security posture"
        InstanceId = $result.NSGId
        InstanceName = "$($result.NSGName)/$($result.RuleName_s)"
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
$jsonExportPath = "nsgrules-orphanunexistingpublicips-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

Write-Output "Looking for orphaned Public IPs..."

$baseQuery = @"
    let interval = 30d;
    let etime = todatetime(toscalar($consumptionTableName | where todatetime(Date_s) < now() and todatetime(Date_s) > ago(30d) | summarize max(todatetime(Date_s))));
    let stime = etime-interval;
    $publicIpsTableName
    | where TimeGenerated > ago(1d) and isempty(AssociatedResourceId_s)
    | distinct Name_s, InstanceId_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroupName_s, SkuName_s, AllocationMethod_s, Tags_s, Cloud_s
    | join kind=leftouter (
        $consumptionTableName
        | where todatetime(Date_s) between (stime..etime)
        | project InstanceId_s=tolower(ResourceId), CostInBillingCurrency_s, Date_s
    ) on InstanceId_s
    | summarize Last30DaysCost=sum(todouble(CostInBillingCurrency_s)) by Name_s, InstanceId_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroupName_s, SkuName_s, AllocationMethod_s, Tags_s, Cloud_s
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
    $publicIpsTableName
    | where InstanceId_s == '$queryInstanceId' and isempty(AssociatedResourceId_s)
    | distinct InstanceId_s, Name_s, AllocationMethod_s, SkuName_s, TimeGenerated
    | summarize LastAttachedDate = min(TimeGenerated) by InstanceId_s, Name_s, AllocationMethod_s, SkuName_s
    | join kind=leftouter (
        $consumptionTableName
        | project InstanceId_s=tolower(ResourceId), CostInBillingCurrency_s, Date_s
    ) on InstanceId_s
    | summarize CostsSinceDetached = sumif(todouble(CostInBillingCurrency_s), todatetime(Date_s) > LastAttachedDate) by Name_s, LastAttachedDate, AllocationMethod_s, SkuName_s
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

    $additionalInfoDictionary["currentSku"] = $result.SkuName_s
    $additionalInfoDictionary["allocationMethod"] = $result.AllocationMethod_s
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
        ImpactedArea = "Microsoft.Network/publicIPAddresses"
        Impact = "Low"
        RecommendationType = "Saving"
        RecommendationSubType = "OrphanedPublicIP"
        RecommendationSubTypeId = "3125883f-8b9f-4bde-a0ff-6c739858c6e1"
        RecommendationDescription = "Orphaned Public IP (without owner resource) incur in unnecessary costs"
        RecommendationAction = "Delete the Public IP or change its configuration to dynamic allocation"
        InstanceId = $result.InstanceId_s
        InstanceName = $result.Name_s
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
$jsonExportPath = "orphanedpublicips-$fileDate.json"
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