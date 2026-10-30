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
$sqlserverCredential = Get-AutomationPSCredential -Name "AzureOptimization_SQLServerCredential"
$SqlUsername = $sqlserverCredential.UserName 
$SqlPass = $sqlserverCredential.GetNetworkCredential().Password 
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

$SqlTimeout = 120
$LogAnalyticsIngestControlTable = "LogAnalyticsIngestControl"

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"
$storageAccountSinkRG = Get-AutomationVariable -Name  "AzureOptimization_StorageSinkRG"
$storageAccountSinkSubscriptionId = Get-AutomationVariable -Name  "AzureOptimization_StorageSinkSubId"
$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RecommendationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer)) {
    $storageAccountSinkContainer = "recommendationsexports"
}
$StorageBlobsPageSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_StorageBlobsPageSize" -ErrorAction SilentlyContinue)
if (-not($StorageBlobsPageSize -gt 0))
{
    $StorageBlobsPageSize = 1000
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

# get reference to storage sink
Write-Output "Getting reference to $storageAccountSink storage account (recommendations exports sink)"
Select-AzSubscription -SubscriptionId $storageAccountSinkSubscriptionId
$saCtx = (Get-AzStorageAccount -ResourceGroupName $storageAccountSinkRG -Name $storageAccountSink).Context

$allblobs = @()

Write-Output "Getting blobs list..."
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
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=$SqlTimeout;") 
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
    Write-Output "About to process $($blob.Name)..."
    Get-AzStorageBlobContent -CloudBlob $blob.ICloudBlob -Context $saCtx -Force
    $jsonObject = Get-Content -Path $blob.Name | ConvertFrom-Json
    Write-Output "Blob contains $($jsonObject.Count) results..."

    if ($null -eq $jsonObject)
    {
        $recCount = 0
    }
    elseif ($null -eq $jsonObject.Count)
    {
        $recCount = 1
    }
    else
    {
        $recCount = $jsonObject.Count    
    }

    $linesProcessed = 0
    $jsonObjectSplitted = @()

    if ($recCount -gt 1)
    {
        for ($i = 0; $i -lt $recCount; $i += $LogAnalyticsChunkSize) {
            $jsonObjectSplitted += , @($jsonObject[$i..($i + ($LogAnalyticsChunkSize - 1))]);
        }
    }
    else
    {
        $jsonObjectArray = @()
        $jsonObjectArray += $jsonObject
        $jsonObjectSplitted += , $jsonObjectArray   
    }
    
    for ($j = 0; $j -lt $jsonObjectSplitted.Count; $j++)
    {
        if ($jsonObjectSplitted[$j])
        {
            $currentObjectLines = $jsonObjectSplitted[$j].Count
            if ($lastProcessedLine -lt $linesProcessed)
            {
                for ($i = 0; $i -lt $jsonObjectSplitted[$j].Count; $i++)
                {
                    $jsonObjectSplitted[$j][$i].RecommendationDescription = $jsonObjectSplitted[$j][$i].RecommendationDescription.Replace("'", "")
                    $jsonObjectSplitted[$j][$i].RecommendationAction = $jsonObjectSplitted[$j][$i].RecommendationAction.Replace("'", "")            
                    $jsonObjectSplitted[$j][$i].AdditionalInfo = $jsonObjectSplitted[$j][$i].AdditionalInfo | ConvertTo-Json -Compress
                    $jsonObjectSplitted[$j][$i].Tags = $jsonObjectSplitted[$j][$i].Tags | ConvertTo-Json -Compress
                }
                    
                $jsonObject = ConvertTo-Json -InputObject $jsonObjectSplitted[$j]                
                $res = Post-OMSData -workspaceId $workspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($jsonObject)) -logType $logname -TimeStampField "Timestamp" -AzureEnvironment $cloudEnvironment
                If ($res -ge 200 -and $res -lt 300) {
                    Write-Output "Successfully uploaded $currentObjectLines $LogAnalyticsSuffix rows to Log Analytics"    
                    $linesProcessed += $currentObjectLines
                    if ($j -eq ($jsonObjectSplitted.Count - 1)) {
                        $lastProcessedLine = -1    
                    }
                    else {
                        $lastProcessedLine = $linesProcessed - 1   
                    }
                    
                    $updatedLastProcessedLine = $lastProcessedLine
                    $updatedLastProcessedDateTime = $lastProcessedDateTime
                    if ($j -eq ($jsonObjectSplitted.Count - 1)) {
                        $updatedLastProcessedDateTime = $newProcessedTime
                    }
                    $lastProcessedDateTime = $updatedLastProcessedDateTime
                    Write-Output "Updating last processed time / line to $($updatedLastProcessedDateTime) / $updatedLastProcessedLine"
                    $sqlStatement = "UPDATE [$LogAnalyticsIngestControlTable] SET LastProcessedLine = $updatedLastProcessedLine, LastProcessedDateTime = '$updatedLastProcessedDateTime' WHERE StorageContainerName = '$storageAccountSinkContainer'"
                    $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=$SqlTimeout;") 
                    $Conn.Open() 
                    $Cmd=new-object system.Data.SqlClient.SqlCommand
                    $Cmd.Connection = $Conn
                    $Cmd.CommandText = $sqlStatement
                    $Cmd.CommandTimeout=120 
                    $Cmd.ExecuteReader()
                    $Conn.Close()    
                    $Conn.Dispose()            
                }
                Else {
                    $linesProcessed += $currentObjectLines
                    Write-Warning "Failed to upload $currentObjectLines $LogAnalyticsSuffix rows. Error code: $res"
                    throw
                }
            }
            else
            {
                $linesProcessed += $currentObjectLines  
            }        
        }
    }

    Remove-Item -Path $blob.Name -Force
}

Write-Output "DONE"