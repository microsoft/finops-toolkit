$ErrorActionPreference = "Stop"

$cloudEnvironment = Get-AutomationVariable -Name "AzureOptimization_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}

$dceEndpoint = Get-AutomationVariable -Name  "AzureOptimization_DCEIngestionEndpoint"
$LogAnalyticsChunkSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsChunkSize" -ErrorAction SilentlyContinue)
if (-not($LogAnalyticsChunkSize -gt 0))
{
    $LogAnalyticsChunkSize = 6000
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

$authenticationOption = Get-AutomationVariable -Name  "AzureOptimization_AuthenticationOption" -ErrorAction SilentlyContinue # ManagedIdentity|UserAssignedManagedIdentity
if ([string]::IsNullOrEmpty($authenticationOption))
{
    $authenticationOption = "ManagedIdentity"
}
if ($authenticationOption -eq "UserAssignedManagedIdentity")
{
    $uamiClientID = Get-AutomationVariable -Name "AzureOptimization_UAMIClientID"
}

$SqlTimeout = 300
$FiltersTable = "Filters"

#region Functions

# Sends data to a Log Analytics custom table via the DCR-based Logs Ingestion API.
function Send-LogIngestionData($accessToken, $dceEndpoint, $dcrImmutableId, $streamName, $body)
{
    $uri = "$dceEndpoint/dataCollectionRules/$dcrImmutableId/streams/$streamName`?api-version=2023-01-01"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 1000
    return $response.StatusCode
}

#endregion Functions

"Logging in to Azure with $authenticationOption..."

switch ($authenticationOption)
{
    "UserAssignedManagedIdentity"
    {
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment -AccountId $uamiClientID
        break
    }
    default
    {
        #ManagedIdentity
        Connect-AzAccount -Identity -EnvironmentName $cloudEnvironment
        break
    }
}

$cloudDetails = Get-AzEnvironment -Name $CloudEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)

# Determine the Logs Ingestion API audience URL for this cloud
switch ($cloudEnvironment)
{
    "AzureChinaCloud"    { $monitorAudience = "https://monitor.azure.cn/" }
    "AzureUSGovernment"  { $monitorAudience = "https://monitor.azure.us/" }
    default              { $monitorAudience = "https://monitor.azure.com/" }
}

Write-Output "Getting excluded recommendation sub-type IDs..."

$tries = 0
$connectionSuccess = $false
do
{
    $tries++
    try
    {
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
        $Conn.AccessToken = $dbToken.Token
        $Conn.Open()
        $Cmd = New-Object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.CommandText = "SELECT * FROM [dbo].[$FiltersTable] WHERE IsEnabled = 1 AND (FilterEndDate IS NULL OR FilterEndDate > GETDATE())"

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $filters = New-Object System.Data.DataTable
        $sqlAdapter.Fill($filters) | Out-Null
        $connectionSuccess = $true
    }
    catch
    {
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

$datetime = (Get-Date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$filterObjects = @()

$filterObject = New-Object PSObject -Property @{
    Timestamp               = $timestamp
    FilterId                = (New-Guid).Guid
    RecommendationSubTypeId = [System.Guid]::empty.Guid
    FilterType              = "Dummy"
    InstanceId              = [System.Guid]::empty.Guid
    InstanceName            = "Dummy"
    FilterStartDate         = "2019-01-01T00:00:00.000Z"
    FilterEndDate           = "2199-12-31T23:59:59.000Z"
    Author                  = "AOE"
    Notes                   = "This is a dummy suppression required to build the full suppressions schema in Log Analytics"
}
$filterObjects += $filterObject

foreach ($filter in $filters)
{
    $filterEndDate = $null
    if (-not([string]::IsNullOrEmpty($filter.FilterEndDate)))
    {
        Write-Output $filter.FilterEndDate
        $filterEndDate = $filter.FilterEndDate.ToString("yyyy-MM-ddTHH:mm:00.000Z")
    }
    else
    {
        $filterEndDate = "2199-12-31T23:59:59.000Z"
    }

    $filterStartDate = $null
    if (-not([string]::IsNullOrEmpty($filter.FilterStartDate)))
    {
        $filterStartDate = $filter.FilterStartDate.ToString("yyyy-MM-ddTHH:mm:00.000Z")
    }
    else
    {
        $filterStartDate = "2019-01-01T00:00:00.000Z"
    }

    $instanceId = $null
    $instanceName = $null
    $ObjectGuid = [System.Guid]::empty
    if ([System.Guid]::TryParse($filter.InstanceId, [System.Management.Automation.PSReference]$ObjectGuid))
    {
        $instanceId = $filter.InstanceId
    }
    else
    {
        $instanceName = $filter.InstanceId
    }

    $filterObject = New-Object PSObject -Property @{
        Timestamp               = $timestamp
        FilterId                = $filter.FilterId
        RecommendationSubTypeId = $filter.RecommendationSubTypeId
        FilterType              = $filter.FilterType
        InstanceId              = $instanceId
        InstanceName            = $instanceName
        FilterStartDate         = $filterStartDate
        FilterEndDate           = $filterEndDate
        Author                  = $filter.Author
        Notes                   = $filter.Notes
    }
    $filterObjects += $filterObject
}

$filtersJson = $filterObjects | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name 'TimeGenerated' -Value $_.Timestamp -Force -PassThru
} | ConvertTo-Json

$LogAnalyticsSuffix = "SuppressionsV1"
$logname = $lognamePrefix + $LogAnalyticsSuffix
$streamName = "Custom-$lognamePrefix$LogAnalyticsSuffix"

# Retrieve DCR immutable ID from SQL control table
$dcrImmutableId = $null
$tries = 0
$dcrQuerySuccess = $false
do
{
    $tries++
    try
    {
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
        $dcrConn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
        $dcrConn.AccessToken = $dbToken.Token
        $dcrConn.Open()
        $dcrCmd = New-Object system.Data.SqlClient.SqlCommand
        $dcrCmd.Connection = $dcrConn
        $dcrCmd.CommandTimeout = $SqlTimeout
        $dcrCmd.CommandText = "SELECT DCRImmutableId FROM [dbo].[LogAnalyticsIngestControl] WHERE StorageContainerName = 'suppressions'"
        $dcrImmutableId = $dcrCmd.ExecuteScalar()
        $dcrConn.Close()
        $dcrConn.Dispose()
        $dcrQuerySuccess = $true
    }
    catch
    {
        Write-Output "Failed to retrieve DCR immutable ID from SQL at try $tries."
        Write-Output $Error[0]
        Start-Sleep -Seconds ($tries * 20)
    }
} while (-not($dcrQuerySuccess) -and $tries -lt 3)

if ([string]::IsNullOrEmpty($dcrImmutableId))
{
    throw "DCRImmutableId is not set for suppressions. Run Setup-LogAnalyticsTablesAndDCRs.ps1 first."
}

$monitorToken = (Get-AzAccessToken -ResourceUrl $monitorAudience).Token
$res = Send-LogIngestionData -accessToken $monitorToken -dceEndpoint $dceEndpoint `
    -dcrImmutableId $dcrImmutableId -streamName $streamName `
    -body ([System.Text.Encoding]::UTF8.GetBytes($filtersJson))
if ($res -ge 200 -and $res -lt 300)
{
    Write-Output "Successfully uploaded $($filterObjects.Count) $LogAnalyticsSuffix rows to Log Analytics"
}
else
{
    Write-Warning "Failed to upload $($filterObjects.Count) $LogAnalyticsSuffix rows. Error code: $res"
    throw
}
