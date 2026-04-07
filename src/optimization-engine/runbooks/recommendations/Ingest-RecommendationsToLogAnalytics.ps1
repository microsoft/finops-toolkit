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

$SqlTimeout = 120
$LogAnalyticsIngestControlTable = "LogAnalyticsIngestControl"

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RecommendationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer))
{
    $storageAccountSinkContainer = "recommendationsexports"
}
$StorageBlobsPageSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_StorageBlobsPageSize" -ErrorAction SilentlyContinue)
if (-not($StorageBlobsPageSize -gt 0))
{
    $StorageBlobsPageSize = 1000
}

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

# get reference to storage sink
Write-Output "Getting reference to $storageAccountSink storage account (recommendations exports sink)"

$saCtx = New-AzStorageContext -StorageAccountName $storageAccountSink -UseConnectedAccount -Environment $cloudEnvironment

$allblobs = @()

Write-Output "Getting blobs list..."
$continuationToken = $null
do
{
    $blobs = Get-AzStorageBlob -Container $storageAccountSinkContainer -MaxCount $StorageBlobsPageSize -ContinuationToken $continuationToken -Context $saCtx | Sort-Object -Property LastModified
    if ($blobs.Count -le 0) { break }
    $allblobs += $blobs
    $continuationToken = $blobs[$blobs.Count - 1].ContinuationToken
}
while ($null -ne $continuationToken)

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$LogAnalyticsIngestControlTable] WHERE StorageContainerName = '$storageAccountSinkContainer'"

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $controlRows = New-Object System.Data.DataTable
        $sqlAdapter.Fill($controlRows) | Out-Null
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

if ($controlRows.Count -eq 0 -or -not($controlRows[0].LastProcessedDateTime))
{
    throw "Could not find a valid ingestion control row for $storageAccountSinkContainer"
}

$controlRow = $controlRows[0]
$lastProcessedLine = $controlRow.LastProcessedLine
$lastProcessedDateTime = $controlRow.LastProcessedDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
$LogAnalyticsSuffix = $controlRow.LogAnalyticsSuffix
$dcrImmutableId = $controlRow.DCRImmutableId
$logname = $lognamePrefix + $LogAnalyticsSuffix
$streamName = "Custom-$lognamePrefix$LogAnalyticsSuffix"

if ([string]::IsNullOrEmpty($dcrImmutableId))
{
    throw "DCRImmutableId is not set for container $storageAccountSinkContainer. Run Setup-LogAnalyticsTablesAndDCRs.ps1 first."
}

# Obtain a bearer token for the Logs Ingestion API
switch ($cloudEnvironment)
{
    "AzureChinaCloud"    { $monitorAudience = "https://monitor.azure.cn/" }
    "AzureUSGovernment"  { $monitorAudience = "https://monitor.azure.us/" }
    default              { $monitorAudience = "https://monitor.azure.com/" }
}
$monitorToken = (Get-AzAccessToken -ResourceUrl $monitorAudience).Token

Write-Output "Processing blobs modified after $lastProcessedDateTime (line $lastProcessedLine) and ingesting them into the $($logname)_CL table (stream $streamName)..."

$newProcessedTime = $null

$unprocessedBlobs = @()

foreach ($blob in $allblobs)
{
    $blobLastModified = $blob.LastModified.UtcDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
    if ($lastProcessedDateTime -lt $blobLastModified -or `
        ($lastProcessedDateTime -eq $blobLastModified -and $lastProcessedLine -gt 0))
    {
        Write-Output "$($blob.Name) found (modified on $blobLastModified)"
        $unprocessedBlobs += $blob
    }
}

$unprocessedBlobs = $unprocessedBlobs | Sort-Object -Property LastModified

Write-Output "Found $($unprocessedBlobs.Count) new blobs to process..."

foreach ($blob in $unprocessedBlobs)
{
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
        for ($i = 0; $i -lt $recCount; $i += $LogAnalyticsChunkSize)
        {
            $jsonObjectSplitted += , @($jsonObject[$i..($i + ($LogAnalyticsChunkSize - 1))])
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
                    # Rename Timestamp to TimeGenerated as required by Log Analytics custom tables
                    $jsonObjectSplitted[$j][$i] | Add-Member -MemberType NoteProperty -Name 'TimeGenerated' -Value $jsonObjectSplitted[$j][$i].Timestamp -Force
                }

                $jsonObject = ConvertTo-Json -InputObject $jsonObjectSplitted[$j]
                # Refresh token before each chunk upload
                $monitorToken = (Get-AzAccessToken -ResourceUrl $monitorAudience).Token
                $res = Send-LogIngestionData -accessToken $monitorToken -dceEndpoint $dceEndpoint `
                    -dcrImmutableId $dcrImmutableId -streamName $streamName `
                    -body ([System.Text.Encoding]::UTF8.GetBytes($jsonObject))
                if ($res -ge 200 -and $res -lt 300)
                {
                    Write-Output "Successfully uploaded $currentObjectLines $LogAnalyticsSuffix rows to Log Analytics"
                    $linesProcessed += $currentObjectLines
                    if ($j -eq ($jsonObjectSplitted.Count - 1))
                    {
                        $lastProcessedLine = -1
                    }
                    else
                    {
                        $lastProcessedLine = $linesProcessed - 1
                    }

                    $updatedLastProcessedLine = $lastProcessedLine
                    $updatedLastProcessedDateTime = $lastProcessedDateTime
                    if ($j -eq ($jsonObjectSplitted.Count - 1))
                    {
                        $updatedLastProcessedDateTime = $newProcessedTime
                    }
                    $lastProcessedDateTime = $updatedLastProcessedDateTime
                    Write-Output "Updating last processed time / line to $($updatedLastProcessedDateTime) / $updatedLastProcessedLine"
                    $sqlStatement = "UPDATE [$LogAnalyticsIngestControlTable] SET LastProcessedLine = $updatedLastProcessedLine, LastProcessedDateTime = '$updatedLastProcessedDateTime' WHERE StorageContainerName = '$storageAccountSinkContainer'"
                    $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
                    $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;")
                    $Conn.AccessToken = $dbToken.Token
                    $Conn.Open()
                    $Cmd = New-Object system.Data.SqlClient.SqlCommand
                    $Cmd.Connection = $Conn
                    $Cmd.CommandText = $sqlStatement
                    $Cmd.CommandTimeout = $SqlTimeout
                    $Cmd.ExecuteReader()
                    $Conn.Close()
                    $Conn.Dispose()
                }
                else
                {
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