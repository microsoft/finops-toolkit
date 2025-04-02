<#
.SYNOPSIS
This script suppresses a recommendation in the Azure Optimization Engine.

.DESCRIPTION
This script suppresses a recommendation in the Azure Optimization Engine. The script will prompt the user for the required information
to suppress the recommendation.

.PARAMETER RecommendationId
The recommendation Id to suppress.

.PARAMETER AzureEnvironment
The Azure environment to connect to. Default is AzureCloud.

.EXAMPLE
.\Suppress-Recommendation.ps1 -RecommendationId "00000000-0000-0000-0000-000000000001"

.LINK
https://aka.ms/AzureOptimizationEngine/suppressrecs
#>
param(
    [Parameter(Mandatory = $true)]
    [String] $RecommendationId,

    [Parameter(Mandatory = $false)]
    [string] $AzureEnvironment = "AzureCloud"
)

$ErrorActionPreference = "Stop"

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ObjectGuid
    )

    # Define verification regex
    [regex]$guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'

    # Check guid against regex
    return $ObjectGuid -match $guidRegex
}

if (-not(Test-IsGuid -ObjectGuid $RecommendationId))
{
    Write-Host "The provided recommendation Id is invalid. Must be a valid GUID." -ForegroundColor Red
    Exit
}

$ctx = Get-AzContext
if (-not($ctx)) {
    Connect-AzAccount -Environment $AzureEnvironment
    $ctx = Get-AzContext
}
else {
    if ($ctx.Environment.Name -ne $AzureEnvironment) {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $AzureEnvironment
        $ctx = Get-AzContext
    }
}

$cloudDetails = Get-AzEnvironment -Name $AzureEnvironment
$azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)

$databaseConnectionSettingsPath = ".\database-connection-settings.json"
$dbConnectionSettings = @{}

if (Test-Path -Path $databaseConnectionSettingsPath)
{
    $dbSettings = Get-Content -Path $databaseConnectionSettingsPath | ConvertFrom-Json
    Write-Host $dbSettings -ForegroundColor Green
    $dbSettingsReuse = Read-Host "Found existing database connection settings. Do you want to reuse them (Y/N)?"
    if ("Y", "y" -contains $dbSettingsReuse)
    {
        foreach ($property in $dbSettings.PSObject.Properties)
        {
            $dbConnectionSettings[$property.Name] = $property.Value
        }
    }
}

if (-not($dbConnectionSettings["DatabaseServer"]))
{
    $databaseServer = Read-Host "Please, enter the AOE Azure SQL server hostname (for example, xpto.database.windows.net)"
    $dbConnectionSettings["DatabaseServer"] = $databaseServer
}
else
{
    $databaseServer = $dbConnectionSettings["DatabaseServer"]
}

if (-not($dbConnectionSettings["DatabaseName"]))
{
    $databaseName = Read-Host "Please, enter the AOE Azure SQL Database name (for example, azureoptimization)"
    $dbConnectionSettings["DatabaseName"] = $databaseName
}
else
{
    $databaseName = $dbConnectionSettings["DatabaseName"]
}

$SqlTimeout = 120
$recommendationsTable = "Recommendations"
$suppressionsTable = "Filters"

Write-Host "Opening connection to the database..." -ForegroundColor Green

$tries = 0
$connectionSuccess = $false
do {
    $tries++
    try {
        $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/" -AsSecureString
        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$databaseServer,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
        $Conn.AccessToken = $dbToken.Token | ConvertFrom-SecureString -AsPlainText
        $Conn.Open()
        $Cmd=new-object system.Data.SqlClient.SqlCommand
        $Cmd.Connection = $Conn
        $Cmd.CommandTimeout = $SqlTimeout
        $Cmd.CommandText = "SELECT * FROM [dbo].[$recommendationsTable] WHERE RecommendationId = '$RecommendationId'"

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $sqlAdapter.SelectCommand = $Cmd
        $controlRows = New-Object System.Data.DataTable
        $sqlAdapter.Fill($controlRows) | Out-Null
        $connectionSuccess = $true
    }
    catch {
        Write-Host "Failed to contact SQL at try $tries." -ForegroundColor Yellow
        Write-Host $Error[0] -ForegroundColor Yellow
        Write-Output "Waiting $($tries * 20) seconds..."
        Start-Sleep -Seconds ($tries * 20)
    }
} while (-not($connectionSuccess) -and $tries -lt 3)

if (-not($connectionSuccess))
{
    throw "Could not establish connection to SQL."
}

$Conn.Close()
$Conn.Dispose()

if (-not($controlRows.RecommendationId))
{
    Write-Host "The provided recommendation Id was not found. Please, try again with a valid GUID." -ForegroundColor Red
    Exit
}

Write-Host "You are suppressing the recommendation with the below details" -ForegroundColor Green
Write-Host "Recommendation: $($controlRows.RecommendationDescription)" -ForegroundColor Blue
Write-Host "Recommendation sub-type id: $($controlRows.RecommendationSubTypeId)" -ForegroundColor Blue
Write-Host "Category: $($controlRows.Category)" -ForegroundColor Blue
Write-Host "Instance Name: $($controlRows.InstanceName)" -ForegroundColor Blue
Write-Host "Resource Group: $($controlRows.ResourceGroup)" -ForegroundColor Blue
Write-Host "Subscription Id: $($controlRows.SubscriptionGuid)" -ForegroundColor Blue
Write-Host "Please, choose the suppression type" -ForegroundColor Green
Write-Host "[E]xclude - this recommendation type will be completely excluded from the engine and will no longer be generated for any resource" -ForegroundColor Green
Write-Host "[D]ismiss - this recommendation will be dismissed for the scope to be chosen next (instance, resource group or subscription)" -ForegroundColor Green
Write-Host "[S]nooze - this recommendation will be postponed for the duration (in days) and scope to be chosen next (instance, resource group or subscription)" -ForegroundColor Green
Write-Host "[C]ancel - no action will be taken" -ForegroundColor Green
$suppOption = Read-Host "Enter your choice (E, D, S or C)"

if ("E", "e" -contains $suppOption)
{
    $suppressionType = "Exclude"
}
elseif ("D", "d" -contains $suppOption)
{
    $suppressionType = "Dismiss"
}
elseif ("S", "s" -contains $suppOption)
{
    $suppressionType = "Snooze"
}
else
{
    Write-Host "Cancelling.. No action will be taken." -ForegroundColor Green
    Exit
}

if ($suppressionType -in ("Dismiss", "Snooze"))
{
    Write-Host "Please, choose the scope for the suppression" -ForegroundColor Green
    Write-Host "[S]ubscription ($($controlRows.SubscriptionGuid))" -ForegroundColor Green
    Write-Host "[R]esource Group ($($controlRows.ResourceGroup))" -ForegroundColor Green
    Write-Host "[I]nstance ($($controlRows.InstanceName))" -ForegroundColor Green
    $scopeOption = Read-Host "Enter your choice (S, R, or I)"

    if ("S", "s" -contains $scopeOption)
    {
        $scope = $controlRows.SubscriptionGuid
    }
    elseif ("R", "r" -contains $scopeOption)
    {
        $scope = $controlRows.ResourceGroup
    }
    elseif ("I", "i" -contains $scopeOption)
    {
        $scope = $controlRows.InstanceId
    }
    else
    {
        Write-Host "Wrong input. No action will be taken." -ForegroundColor Red
        Exit
    }
}

$snoozeDays = 0
if ($suppressionType -eq "Snooze")
{
    Write-Host "Please, enter the number of days the recommendation will be snoozed" -ForegroundColor Green
    $snoozeDays = Read-Host "Number of days (min. 14)"
    if (-not($snoozeDays -ge 14))
    {
        Write-Host "Wrong snooze days. No action will be taken." -ForegroundColor Red
        Exit
    }
}

$author = Read-Host "Please enter your name"
$notes = Read-Host "Please enter a reason for this suppression"

Write-Host "You are about to suppress this recommendation" -ForegroundColor Yellow
Write-Host "Recommendation: $($controlRows.RecommendationDescription)" -ForegroundColor Blue
Write-Host "Suppression type: $suppressionType" -ForegroundColor Blue
if ($suppressionType -in ("Dismiss", "Snooze"))
{
    Write-Host "Scope: $scope" -ForegroundColor Blue
}
if ($suppressionType -eq "Snooze")
{
    Write-Host "Snooze days: $snoozeDays" -ForegroundColor Blue
}
Write-Host "Author: $author" -ForegroundColor Blue
Write-Host "Reason: $notes" -ForegroundColor Blue
$continueInput = Read-Host "Do you want to continue (Y/N)?"
if ("Y", "y" -contains $continueInput)
{
    if ($scope)
    {
        $scope = "'$scope'"
    }
    else
    {
        $scope = "NULL"
    }

    if ($snoozeDays -ge 14)
    {
        $now = (Get-Date).ToUniversalTime()
        $endDate = "'$($now.Add($snoozeDays).ToString("yyyy-MM-ddTHH:mm:00Z"))'"
    }
    else {
        $endDate = "NULL"
    }

    $sqlStatement = "INSERT INTO [$suppressionsTable] VALUES (NEWID(), '$($controlRows.RecommendationSubTypeId)', '$suppressionType', $scope, GETDATE(), $endDate, '$author', '$notes', 1)"

    $dbToken = Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/" -AsSecureString
    $Conn2 = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$databaseServer,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
    $Conn2.AccessToken = $dbToken.Token | ConvertFrom-SecureString -AsPlainText
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

    Write-Host "Suppression sucessfully added." -ForegroundColor Green
}
else
{
    Write-Host "No action was taken." -ForegroundColor Green
}

$dbConnectionSettings | ConvertTo-Json | Out-File -FilePath $databaseConnectionSettingsPath -Force