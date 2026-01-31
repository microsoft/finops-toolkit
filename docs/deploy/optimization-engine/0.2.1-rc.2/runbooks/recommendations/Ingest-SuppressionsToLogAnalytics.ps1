$ErrorActionPreference = "Stop"

$cloudEnvironment = Get-AutomationVariable -Name "AzureOptimization_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}

$workspaceId = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceId"
$sharedKey = Get-AutomationVariable -Name  "AzureOptimization_LogAnalyticsWorkspaceKey"
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
$sqlserverCredential = Get-AutomationPSCredential -Name "AzureOptimization_SQLServerCredential"
$SqlUsername = $sqlserverCredential.UserName 
$SqlPass = $sqlserverCredential.GetNetworkCredential().Password 
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}

$SqlTimeout = 300
$FiltersTable = "Filters"

#region Functions

# Function to create the authorization signature
Function Build-OMSSignature ($workspaceId, $sharedKey, $date, $contentLength, $method, $contentType, $resource) {
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $workspaceId, $encodedHash
    return $authorization
}

# Function to create and post the request
Function Post-OMSData($workspaceId, $sharedKey, $body, $logType, $TimeStampField, $AzureEnvironment) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-OMSSignature `
        -workspaceId $workspaceId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    
    $uri = "https://" + $workspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    if ($AzureEnvironment -eq "AzureChinaCloud")
    {
        $uri = "https://" + $workspaceId + ".ods.opinsights.azure.cn" + $resource + "?api-version=2016-04-01"
    }
    if ($AzureEnvironment -eq "AzureUSGovernment")
    {
        $uri = "https://" + $workspaceId + ".ods.opinsights.azure.us" + $resource + "?api-version=2016-04-01"
    }
    if ($AzureEnvironment -eq "AzureGermanCloud")
    {
        throw "Azure Germany isn't supported for the Log Analytics Data Collector API"
    }

    $OMSheaders = @{
        "Authorization"        = $signature;
        "Log-Type"             = $logType;
        "x-ms-date"            = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    Try {

        $response = Invoke-WebRequest -Uri $uri -Method POST  -ContentType $contentType -Headers $OMSheaders -Body $body -UseBasicParsing -TimeoutSec 1000
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 401) {            
            "REAUTHENTICATING"

            $response = Invoke-WebRequest -Uri $uri -Method POST  -ContentType $contentType -Headers $OMSheaders -Body $body -UseBasicParsing -TimeoutSec 1000
        }
        else
        {
            return $_.Exception.Response.StatusCode.Value__
        }
    }

    return $response.StatusCode    
}
#endregion Functions

Write-Output "Getting excluded recommendation sub-type IDs..."

$tries = 0
$connectionSuccess = $false
do {
    $tries++
    try {
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=$SqlTimeout;") 
        $Conn.Open() 
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.CommandText = "SELECT * FROM [dbo].[$FiltersTable] WHERE IsEnabled = 1 AND (FilterEndDate IS NULL OR FilterEndDate > GETDATE())"
    
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

$datetime = (get-date).ToUniversalTime()
$timestamp = $datetime.ToString("yyyy-MM-ddTHH:mm:00.000Z")

$filterObjects = @()

$filterObject = New-Object PSObject -Property @{
    Timestamp = $timestamp
    FilterId = (New-Guid).Guid
    RecommendationSubTypeId = [System.Guid]::empty.Guid
    FilterType = "Dummy"
    InstanceId = [System.Guid]::empty.Guid
    InstanceName = "Dummy"
    FilterStartDate = "2019-01-01T00:00:00.000Z"
    FilterEndDate = "2199-12-31T23:59:59.000Z"
    Author = "AOE"
    Notes = "This is a dummy suppression required to build the full suppressions schema in Log Analytics"
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
        Timestamp = $timestamp
        FilterId = $filter.FilterId
        RecommendationSubTypeId = $filter.RecommendationSubTypeId
        FilterType = $filter.FilterType
        InstanceId = $instanceId
        InstanceName = $instanceName
        FilterStartDate = $filterStartDate
        FilterEndDate = $filterEndDate
        Author = $filter.Author
        Notes = $filter.Notes
    }
    $filterObjects += $filterObject
}

$filtersJson = $filterObjects | ConvertTo-Json

$LogAnalyticsSuffix = "SuppressionsV1"
$logname = $lognamePrefix + $LogAnalyticsSuffix

$res = Post-OMSData -workspaceId $workspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($filtersJson)) -logType $logname -TimeStampField "Timestamp" -AzureEnvironment $cloudEnvironment
If ($res -ge 200 -and $res -lt 300) {
    Write-Output "Successfully uploaded $($filterObjects.Count) $LogAnalyticsSuffix rows to Log Analytics"    
}
Else {
    Write-Warning "Failed to upload $($filterObjects.Count) $LogAnalyticsSuffix rows. Error code: $res"
    throw
}
