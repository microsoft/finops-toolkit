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

$workspaceId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceId"
$workspaceSubscriptionId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceSubId"

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

# must be less than or equal to the advisor exports frequency
$daysBackwards = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendAdvisorPeriodInDays" -ErrorAction SilentlyContinue)
if (-not($daysBackwards -gt 0)) {
    $daysBackwards = 7
}

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}

$CategoryFilter = Get-AutomationVariable -Name  "AzureOptimization_AdvisorFilter" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($CategoryFilter))
{
    $CategoryFilter = "HighAvailability,Security,Performance,OperationalExcellence" # comma-separated list of categories
}

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('ARGVirtualMachine','AzureAdvisor','ARGResourceContainers')"

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

$advisorTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AzureAdvisor' }).LogAnalyticsSuffix + "_CL"
$subscriptionsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'ARGResourceContainers' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $subscriptionsTableName and $advisorTableName"

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

# Grab a context reference to the Storage Account where the recommendations file will be stored


$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

if ($workspaceSubscriptionId -ne $storageAccountSinkSubscriptionId)
{
    Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
}

# Execute the recommendation query against Log Analytics

$FinalCategoryFilter = ""

if (-not([string]::IsNullOrEmpty($CategoryFilter)))
{
    $categories = $CategoryFilter.Split(',')
    for ($i = 0; $i -lt $categories.Count; $i++)
    {
        $categories[$i] = "'" + $categories[$i] + "'"
    }
    $FinalCategoryFilter = " and Category in (" + ($categories -join ",") + ")"
}

$baseQuery = @"
let advisorInterval = $($daysBackwards)d;
$advisorTableName
| where todatetime(TimeGenerated) > ago(advisorInterval)$FinalCategoryFilter
| extend AdvisorRecIdIndex = indexof(InstanceId_s, '/providers/microsoft.advisor/recommendations')
| extend InstanceName_s = iif(isnotempty(InstanceName_s),InstanceName_s,iif(AdvisorRecIdIndex > 0, split(substring(InstanceId_s, 0, AdvisorRecIdIndex),'/')[-1], split(InstanceId_s,'/')[-1]))
| summarize by InstanceId_s, InstanceName_s, Category, Description_s, SubscriptionGuid_g, TenantGuid_g, ResourceGroup, Cloud_s, AdditionalInfo_s, RecommendationText_s, ImpactedArea_s, Impact_s, RecommendationTypeId_g, Tags_s
| join kind=leftouter (
    $subscriptionsTableName
    | where TimeGenerated > ago(1d)
    | where ContainerType_s =~ 'microsoft.resources/subscriptions'
    | project SubscriptionGuid_g, SubscriptionName = ContainerName_s
) on SubscriptionGuid_g
"@

Write-Output "Getting $CategoryFilter recommendations for $($daysBackwards)d Advisor..."

try
{
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days $daysBackwards) -Wait 600 -IncludeStatistics
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

Write-Output "Generating fit score..."

foreach ($result in $results) {

    if ($filters | Where-Object { $_.RecommendationSubTypeId -eq $result.RecommendationTypeId_g})
    {
        continue
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

    $additionalInfoDictionary = @{}
    if (-not([string]::IsNullOrEmpty($result.AdditionalInfo_s)))
    {
        ($result.AdditionalInfo_s | ConvertFrom-Json).PsObject.Properties | ForEach-Object { $additionalInfoDictionary[$_.Name] = $_.Value }
    }

    $fitScore = 5

    $queryInstanceId = $result.InstanceId_s

    switch ($result.Cloud_s)
    {
        "AzureCloud" { $azureTld = "com" }
        "AzureChinaCloud" { $azureTld = "cn" }
        "AzureUSGovernment" { $azureTld = "us" }
        default { $azureTld = "com" }
    }

    $detailsURL = "https://portal.azure.$azureTld/#@$($result.TenantGuid_g)/resource/$queryInstanceId/overview"

    $recommendationSubType = "Advisor" + $result.Category

    $recommendation = New-Object PSObject -Property @{
        Timestamp                   = $timestamp
        Cloud                       = $result.Cloud_s
        Category                    = $result.Category
        ImpactedArea                = $result.ImpactedArea_s
        Impact                      = $result.Impact_s
        RecommendationType          = "BestPractices"
        RecommendationSubType       = $recommendationSubType
        RecommendationSubTypeId     = $result.RecommendationTypeId_g
        RecommendationDescription   = $result.Description_s.Replace("'","")
        RecommendationAction        = $result.RecommendationText_s.Replace("'","")
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
$jsonExportPath = "advisor-asis-$fileDate.json"
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
