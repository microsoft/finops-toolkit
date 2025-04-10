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
$ChunkSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_SQLServerInsertSize" -ErrorAction SilentlyContinue)
if (-not($ChunkSize -gt 0))
{
    $ChunkSize = 900
}
$SqlTimeout = 120

$storageAccountSink = Get-AutomationVariable -Name  "AzureOptimization_StorageSink"


$storageAccountSinkContainer = Get-AutomationVariable -Name  "AzureOptimization_RecommendationsContainer" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($storageAccountSinkContainer)) {
    $storageAccountSinkContainer = "recommendationsexports"
}
$StorageBlobsPageSize = [int] (Get-AutomationVariable -Name  "AzureOptimization_StorageBlobsPageSize" -ErrorAction SilentlyContinue)
if (-not($StorageBlobsPageSize -gt 0))
{
    $StorageBlobsPageSize = 1000
}

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
    $continuationToken = $blobs[$blobs.Count -1].ContinuationToken;
}
While ($null -ne $continuationToken)

$SqlServerIngestControlTable = "SqlServerIngestControl"
$recommendationsTable = "Recommendations"

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
        $Cmd.CommandText = "SELECT * FROM [dbo].[$SqlServerIngestControlTable] WHERE StorageContainerName = '$storageAccountSinkContainer' and SqlTableName = '$recommendationsTable'"
    
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

if ($controlRows.Count -eq 0)
{
    throw "Could not find a control row for $storageAccountSinkContainer container and $recommendationsTable table."
}

$controlRow = $controlRows[0]    
$lastProcessedLine = $controlRow.LastProcessedLine
$lastProcessedDateTime = $controlRow.LastProcessedDateTime.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")

$Conn.Close()    
$Conn.Dispose()            

Write-Output "Processing blobs modified after $lastProcessedDateTime (line $lastProcessedLine) and ingesting them into the Recommendations SQL table..."

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
        for ($i = 0; $i -lt $recCount; $i += $ChunkSize) {
            $jsonObjectSplitted += , @($jsonObject[$i..($i + ($ChunkSize - 1))]);
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
                $sqlStatement = "INSERT INTO [$recommendationsTable]"
                $sqlStatement += " (RecommendationId, GeneratedDate, Cloud, Category, ImpactedArea, Impact, RecommendationType, RecommendationSubType,"
                $sqlStatement += " RecommendationSubTypeId, RecommendationDescription, RecommendationAction, InstanceId, InstanceName, AdditionalInfo,"
                $sqlStatement += " ResourceGroup, SubscriptionGuid, SubscriptionName, TenantGuid, FitScore, Tags, DetailsUrl) VALUES"
                for ($i = 0; $i -lt $jsonObjectSplitted[$j].Count; $i++)
                {
                    $jsonObjectSplitted[$j][$i].RecommendationDescription = $jsonObjectSplitted[$j][$i].RecommendationDescription.Replace("'", "")
                    $jsonObjectSplitted[$j][$i].RecommendationAction = $jsonObjectSplitted[$j][$i].RecommendationAction.Replace("'", "")            
                    if ($null -ne $jsonObjectSplitted[$j][$i].InstanceName)
                    {
                        $jsonObjectSplitted[$j][$i].InstanceName = $jsonObjectSplitted[$j][$i].InstanceName.Replace("'", "")
                    }            
                    $additionalInfoString = $jsonObjectSplitted[$j][$i].AdditionalInfo | ConvertTo-Json -Compress
                    $tagsString = $jsonObjectSplitted[$j][$i].Tags | ConvertTo-Json -Compress
                    $subscriptionGuid = "NULL"
                    if ($jsonObjectSplitted[$j][$i].SubscriptionGuid)
                    {
                        $subscriptionGuid = "'$($jsonObjectSplitted[$j][$i].SubscriptionGuid)'"
                    }
                    $subscriptionName = "NULL"
                    if ($jsonObjectSplitted[$j][$i].SubscriptionName)
                    {
                        $subscriptionName = $jsonObjectSplitted[$j][$i].SubscriptionName.Replace("'", "")
                        $subscriptionName = "'$subscriptionName'"
                    }
                    $resourceGroup = "NULL"
                    if ($jsonObjectSplitted[$j][$i].ResourceGroup)
                    {
                        $resourceGroup = "'$($jsonObjectSplitted[$j][$i].ResourceGroup)'"
                    }
                    $sqlStatement += " (NEWID(), CONVERT(DATETIME, '$($jsonObjectSplitted[$j][$i].Timestamp)'), '$($jsonObjectSplitted[$j][$i].Cloud)'"
                    $sqlStatement += ", '$($jsonObjectSplitted[$j][$i].Category)', '$($jsonObjectSplitted[$j][$i].ImpactedArea)'"
                    $sqlStatement += ", '$($jsonObjectSplitted[$j][$i].Impact)', '$($jsonObjectSplitted[$j][$i].RecommendationType)'"
                    $sqlStatement += ", '$($jsonObjectSplitted[$j][$i].RecommendationSubType)', '$($jsonObjectSplitted[$j][$i].RecommendationSubTypeId)'"
                    $sqlStatement += ", '$($jsonObjectSplitted[$j][$i].RecommendationDescription)', '$($jsonObjectSplitted[$j][$i].RecommendationAction)'"
                    $sqlStatement += ", '$($jsonObjectSplitted[$j][$i].InstanceId)', '$($jsonObjectSplitted[$j][$i].InstanceName)', '$additionalInfoString'"
                    $sqlStatement += ", $resourceGroup, $subscriptionGuid, $subscriptionName, '$($jsonObjectSplitted[$j][$i].TenantGuid)'"
                    $sqlStatement += ", $($jsonObjectSplitted[$j][$i].FitScore), '$tagsString', '$($jsonObjectSplitted[$j][$i].DetailsURL)')"
                    if ($i -ne ($jsonObjectSplitted[$j].Count-1))
                    {
                        $sqlStatement += ","
                    }
                }

                $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/"
                $Conn2 = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;Encrypt=True;Connection Timeout=$SqlTimeout;") 
                $Conn2.AccessToken = $dbToken.Token
                $Conn2.Open() 
        
                $Cmd=new-object system.Data.SqlClient.SqlCommand
                $Cmd.Connection = $Conn2
                $Cmd.CommandText = $sqlStatement
                $Cmd.CommandTimeout = $SqlTimeout
                try
                {
                    $Cmd.ExecuteReader()
                }
                catch
                {
                    Write-Output "Failed statement: $sqlStatement"
                    throw
                }
        
                $Conn2.Close()                
            
                $linesProcessed += $currentObjectLines
                Write-Output "Processed $linesProcessed lines..."
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
                $sqlStatement = "UPDATE [$SqlServerIngestControlTable] SET LastProcessedLine = $updatedLastProcessedLine, LastProcessedDateTime = '$updatedLastProcessedDateTime' WHERE StorageContainerName = '$storageAccountSinkContainer'"
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