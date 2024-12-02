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

$expiringCredsDays = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendationAADMinCredValidityDays")
$notExpiringCredsDays = ([int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendationAADMaxCredValidityYears")) * 365

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE CollectedType IN ('AADObjects')"
    
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

$aadObjectsTableName = $lognamePrefix + ($controlRows | Where-Object { $_.CollectedType -eq 'AADObjects' }).LogAnalyticsSuffix + "_CL"

Write-Output "Will run query against tables $aadObjectsTableName"

$Conn.Close()    
$Conn.Dispose()            

$recommendationSearchTimeSpan = 1

# Grab a context reference to the Storage Account where the recommendations file will be stored


$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

if ($workspaceSubscriptionId -ne $storageAccountSinkSubscriptionId)
{
    Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
}

$recommendationsErrors = 0

# Execute the expiring creds recommendation query against Log Analytics

$baseQuery = @" 
    let expiryInterval = $($expiringCredsDays)d;
    let AppsAndKeys = materialize ($aadObjectsTableName
    | where TimeGenerated > ago(1d)
    | where ObjectType_s in ('Application','ServicePrincipal')
    | where ObjectSubType_s != 'ManagedIdentity'
    | where Keys_s startswith '['
    | extend Keys = parse_json(Keys_s)
    | project-away Keys_s
    | mv-expand Keys
    | evaluate bag_unpack(Keys)
    | union ( 
        $aadObjectsTableName
        | where TimeGenerated > ago(1d)
        | where ObjectType_s in ('Application','ServicePrincipal')
        | where ObjectSubType_s != 'ManagedIdentity'
        | where isnotempty(Keys_s) and Keys_s !startswith '['
        | extend Keys = parse_json(Keys_s)
        | project-away Keys_s
        | evaluate bag_unpack(Keys)
    )
    );
    let ExpirationInRisk = AppsAndKeys
    | where EndDate < now()+expiryInterval
    | project ApplicationId_g, KeyId, RiskDate = EndDate;
    let NotInRisk = AppsAndKeys
    | where EndDate > now()+expiryInterval
    | project ApplicationId_g, KeyId, ComfortDate = EndDate;
    let ApplicationsInRisk = ExpirationInRisk
    | join kind=leftouter ( NotInRisk ) on ApplicationId_g
    | where isempty(ComfortDate)
    | summarize ExpiresOn = max(RiskDate) by ApplicationId_g;
    AppsAndKeys
    | join kind=inner (ApplicationsInRisk) on ApplicationId_g
    | summarize ExpiresOn = max(EndDate) by ApplicationId_g, ObjectType_s, DisplayName_s, Cloud_s, KeyType, TenantGuid_g
    | order by ExpiresOn desc
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

    $queryInstanceId = $result.ApplicationId_g
    $detailsURL = "https://portal.azure.$azureTld/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/$queryInstanceId"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["ObjectType"] = $result.ObjectType_s
    $additionalInfoDictionary["KeyType"] = $result.KeyType
    $additionalInfoDictionary["ExpiresOn"] = $result.ExpiresOn

    $fitScore = 5

    $tags = @{}

    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $result.Cloud_s
        Category = "OperationalExcellence"
        ImpactedArea = "Microsoft.AzureActiveDirectory/objects"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "AADExpiringCredentials"
        RecommendationSubTypeId = "3292c489-2782-498b-aad0-a4cef50f6ca2"
        RecommendationDescription = "Microsoft Entra application with credentials expired or about to expire"
        RecommendationAction = "Update the Microsoft Entra application credential before the expiration date"
        InstanceId = $result.ApplicationId_g
        InstanceName = $result.DisplayName_s
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
$jsonExportPath = "aadexpiringcerts-$fileDate.json"
$recommendations | ConvertTo-Json | Out-File $jsonExportPath

$jsonBlobName = $jsonExportPath
$jsonProperties = @{"ContentType" = "application/json"};
Set-AzStorageBlobContent -File $jsonExportPath -Container $storageAccountSinkContainer -Properties $jsonProperties -Blob $jsonBlobName -Context $saCtx -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Uploaded $jsonBlobName to Blob Storage..."

Remove-Item -Path $jsonExportPath -Force

$now = (Get-Date).ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
Write-Output "[$now] Removed $jsonExportPath from local disk..."

# Execute the not expiring in less than X years creds recommendation query against Log Analytics

$baseQuery = @" 
    let expiryInterval = $($notExpiringCredsDays)d;
    let AppsAndKeys = materialize ($aadObjectsTableName
    | where TimeGenerated > ago(1d)
    | where ObjectSubType_s != 'ManagedIdentity'
    | where Keys_s startswith '['
    | extend Keys = parse_json(Keys_s)
    | project-away Keys_s
    | mv-expand Keys
    | evaluate bag_unpack(Keys)
    | union ( 
        $aadObjectsTableName
        | where TimeGenerated > ago(1d)
        | where ObjectSubType_s != 'ManagedIdentity'
        | where isnotempty(Keys_s) and Keys_s !startswith '['
        | extend Keys = parse_json(Keys_s)
        | project-away Keys_s
        | evaluate bag_unpack(Keys)
    )
    );
    AppsAndKeys
    | where EndDate > now()+expiryInterval
    | project ApplicationId_g, ObjectType_s, DisplayName_s, Cloud_s, KeyType, TenantGuid_g, EndDate
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

    $queryInstanceId = $result.ApplicationId_g
    $detailsURL = "https://portal.azure.$azureTld/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/$queryInstanceId"

    $additionalInfoDictionary = @{}

    $additionalInfoDictionary["ObjectType"] = $result.ObjectType_s
    $additionalInfoDictionary["KeyType"] = $result.KeyType
    $additionalInfoDictionary["ExpiresOn"] = $result.EndDate

    $fitScore = 5

    $tags = @{}

    $recommendation = New-Object PSObject -Property @{
        Timestamp = $timestamp
        Cloud = $result.Cloud_s
        Category = "Security"
        ImpactedArea = "Microsoft.AzureActiveDirectory/objects"
        Impact = "Medium"
        RecommendationType = "BestPractices"
        RecommendationSubType = "AADNotExpiringCredentials"
        RecommendationSubTypeId = "ecd969c8-3f16-481a-9577-5ed32e5e1a1d"
        RecommendationDescription = "Microsoft Entra application with credentials expiration not set or too far in time"
        RecommendationAction = "Update the Microsoft Entra application credential with a shorter expiration date"
        InstanceId = $result.ApplicationId_g
        InstanceName = $result.DisplayName_s
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
$jsonExportPath = "aadnotexpiringcerts-$fileDate.json"
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