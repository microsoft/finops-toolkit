param(
    [Parameter(Mandatory = $true)]
    [string] $StorageSinkContainer
)

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

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
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
$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = $StorageSinkContainer
$StorageBlobsPageSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_StorageBlobsPageSize" -ErrorAction SilentlyContinue)
if (-not($StorageBlobsPageSize -gt 0))
{
    $StorageBlobsPageSize = 1000
}

$SqlTimeout = 120
$LogAnalyticsIngestControlTable = "LogAnalyticsIngestControl"

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
        throw "Azure Germany isn't suported for the Log Analytics Data Collector API"
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

$cloudDetails = Get-AzEnvironment -Name $CloudEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)

# get reference to storage sink
Write-Output "Getting blobs list from $storageAccountSink storage account ($storageAccountSinkContainer container)..."

$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

$allblobs = @()

$continuationToken = $null
do
{
    $blobs = Get-AzStorageBlob -Container $storageAccountSinkContainer -MaxCount $StorageBlobsPageSize -ContinuationToken $continuationToken -Context $saCtx | Sort-Object -Property LastModified
    if ($blobs.Count -le 0) { break }
    $allblobs += $blobs
    $continuationToken = $blobs[$blobs.Count -1].ContinuationToken;
}
While ($null -ne $continuationToken)

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE StorageContainerName = '$storageAccountSinkContainer'"

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

$Conn.Close()
$Conn.Dispose()

if ($controlRows.Count -eq 0 -or -not($controlRows[0].LastProcessedDateTime))
{
    throw "Could not find a valid ingestion control row for $storageAccountSinkContainer"
}

$controlRow = $controlRows[0]
$lastProcessedLine = $controlRow.LastProcessedLine
$lastProcessedDateTime = $controlRow.LastProcessedDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
$LogAnalyticsSuffix = $controlRow.LogAnalyticsSuffix
$logname = $lognamePrefix + $LogAnalyticsSuffix

Write-Output "Processing blobs modified after $lastProcessedDateTime (line $lastProcessedLine) and ingesting them into the $($logname)_CL table..."

$newProcessedTime = $null

$unprocessedBlobs = @()

foreach ($blob in $allblobs) {
	$blobLastModified = $blob.LastModified.UtcDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    if ($lastProcessedDateTime -lt $blobLastModified -or `
        ($lastProcessedDateTime -eq $blobLastModified -and $lastProcessedLine -gt 0)) {
		Write-Output "$($blob.Name) found (modified on $blobLastModified)"
        $unprocessedBlobs += $blob
    }
}

$unprocessedBlobs = $unprocessedBlobs | Sort-Object -Property LastModified

Write-Output "Found $($unprocessedBlobs.Count) new blobs to process..."

foreach ($blob in $unprocessedBlobs) {
    $newProcessedTime = $blob.LastModified.UtcDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    Write-Output "About to process $($blob.Name) ($($blob.Length) bytes)..."
    $blobFilePath = "$env:TEMP\$($blob.Name)"
    Get-AzStorageBlobContent -CloudBlob $blob.ICloudBlob -Context $saCtx -Force -Destination $blobFilePath | Out-Null

    $r = [IO.File]::OpenText($blobFilePath)

    $linesProcessed = 0
    $lineCounter = 0
    $chunkLines = @()

    while ($r.Peek() -ge 0)
    {
        $line = $r.ReadLine()
        if ($lineCounter -eq 0)
        {
            $header = $line
            $chunkLines += $line
        }
        else
        {
            $linesProcessed++
        }
        if ($lastProcessedLine -lt $linesProcessed -and $lineCounter -gt 0)
        {
            $chunkLines += $line
        }
        if (($lineCounter -eq $LogAnalyticsChunkSize -or $r.Peek() -lt 0) -and $linesProcessed -gt 0)
        {
            $csvObject = $chunkLines | ConvertFrom-Csv
            $jsonObject = ConvertTo-Json -InputObject $csvObject

            if ($null -ne $jsonObject)
            {
                $res = Post-OMSData -workspaceId $workspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($jsonObject)) -logType $logname -TimeStampField "Timestamp" -AzureEnvironment $cloudEnvironment

                if ($res -ge 200 -and $res -lt 300)
                {
                    Write-Output "Succesfully uploaded $lineCounter $LogAnalyticsSuffix rows to Log Analytics"
                }
                else
                {
                    Write-Warning "Failed to upload $lineCounter $LogAnalyticsSuffix rows. Error code: $res"
                    $r.Dispose()
                    Remove-Item -Path $blobFilePath -Force
                    throw
                }
            }
            else
            {
                Write-Warning "Skipped uploading $lineCounter $LogAnalyticsSuffix rows. Null JSON object."
            }

            if ($r.Peek() -lt 0) {
                $lastProcessedLine = -1
            }
            else {
                $lastProcessedLine = $linesProcessed - 1
            }

            $updatedLastProcessedLine = $lastProcessedLine
            $updatedLastProcessedDateTime = $lastProcessedDateTime
            if ($r.Peek() -lt 0) {
                $updatedLastProcessedDateTime = $newProcessedTime
            }
            $lastProcessedDateTime = $updatedLastProcessedDateTime
            Write-Output "Updating last processed time / line to $($updatedLastProcessedDateTime) / $updatedLastProcessedLine"
            $sqlStatement = "UPDATE [$LogAnalyticsIngestControlTable] SET LastProcessedLine = $updatedLastProcessedLine, LastProcessedDateTime = '$updatedLastProcessedDateTime' WHERE StorageContainerName = '$storageAccountSinkContainer'"
            $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken.Token
            $Conn.Open()
            $Cmd=new-object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandText = $sqlStatement
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.ExecuteReader()
            $Conn.Close()
            $Conn.Dispose()

            $chunkLines = @()
            $chunkLines += $header
            $lineCounter = 1
        }
        else
        {
            $lineCounter++
        }
    }
    $r.Dispose()

    if ($linesProcessed -eq 0)
    {
        Write-Output "No rows found"
        $updatedLastProcessedLine = -1
        $updatedLastProcessedDateTime = $newProcessedTime
        Write-Output "Updating last processed time / line to $($updatedLastProcessedDateTime) / $updatedLastProcessedLine"
        $sqlStatement = "UPDATE [$LogAnalyticsIngestControlTable] SET LastProcessedLine = $updatedLastProcessedLine, LastProcessedDateTime = '$updatedLastProcessedDateTime' WHERE StorageContainerName = '$storageAccountSinkContainer'"
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
        $Conn.AccessToken = $dbToken.Token
        $Conn.Open()
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandText = $sqlStatement
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.ExecuteReader()
        $Conn.Close()
        $Conn.Dispose()
    }
    else
    {
        Write-Output "Processed $linesProcessed row(s) in total."
    }

    Remove-Item -Path $blobFilePath -Force
}

Write-Output "DONE"