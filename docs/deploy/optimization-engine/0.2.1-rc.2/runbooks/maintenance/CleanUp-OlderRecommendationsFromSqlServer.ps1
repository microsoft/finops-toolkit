$ErrorActionPreference = "Stop"

$sqlserver = Get-AutomationVariable -Name  "AzureOptimization_SQLServerHostname"
$sqlserverCredential = Get-AutomationPSCredential -Name "AzureOptimization_SQLServerCredential"
$SqlUsername = $sqlserverCredential.UserName 
$SqlPass = $sqlserverCredential.GetNetworkCredential().Password 
$sqldatabase = Get-AutomationVariable -Name  "AzureOptimization_SQLServerDatabase" -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($sqldatabase))
{
    $sqldatabase = "azureoptimization"
}
$RecommendationsMaxAge = [int] (Get-AutomationVariable -Name  "AzureOptimization_RecommendationsMaxAgeInDays" -ErrorAction SilentlyContinue)
if (-not($RecommendationsMaxAge -gt 0))
{
    $RecommendationsMaxAge = 365
}

$recommendationsTable = "Recommendations"

$tries = 0
$connectionSuccess = $false

Write-Output "Cleaning up recommendations older than $RecommendationsMaxAge days..."

do {
    $tries++
    try {
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlserver,1433;Database=$sqldatabase;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=$SqlTimeout;") 
        $Conn.Open() 
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = 0
        $Cmd.CommandText = "DELETE FROM [dbo].[$recommendationsTable] WHERE GeneratedDate < GETDATE()-$RecommendationsMaxAge"
        $DeletedRows = $Cmd.ExecuteNonQuery()            
        $connectionSuccess = $true
    }
    catch {
        Write-Output "Failed to contact SQL at try $tries."
        Write-Output $Error[0]
        Start-Sleep -Seconds ($tries * 20)
    }
    finally {
        $Conn.Close()    
        $Conn.Dispose()            
    }    
} while (-not($connectionSuccess) -and $tries -lt 3)

if (-not($connectionSuccess))
{
    throw "Could not establish connection to SQL."
}

Write-Output "Cleaned up $DeletedRows recommendations."