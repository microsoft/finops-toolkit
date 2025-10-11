<#
.SYNOPSIS
This script deploys the Azure Optimization Engine.

.DESCRIPTION
This script deploys the Azure Optimization Engine to an Azure subscription. The script will guide you through the deployment process, allowing you to choose the subscription,
resource group, and other deployment settings. The script will also check the availability of the chosen resource names and provide you with the option to reuse an existing
Log Analytics Workspace or create a new one.

.PARAMETER TemplateUri
The URI of the Bicep template to deploy. If not provided, the script will use the default template from the GitHub repository.

.PARAMETER AzureEnvironment
The Azure environment to deploy the resources to. Default is AzureCloud.

.PARAMETER DoPartialUpgrade
A switch to indicate if the script should perform a partial upgrade of the existing resources. Default is false.

.PARAMETER IgnoreNamingAvailabilityErrors
A switch to indicate if the script should ignore SQL Server naming availability errors (when a custom SQL engine is being used). Default is false.

.PARAMETER SilentDeploymentSettingsPath
The path to the silent deployment settings file. If provided, the script will use the settings from the file to deploy the resources without any user interaction.

.PARAMETER ResourceTags
A hashtable of resource tags to apply to the deployed resources. Default is an empty hashtable.

.PARAMETER SqlAdminPrincipalType
The type of the SQL Admin principal. Default is User. Can also be Group or ServicePrincipal.

.PARAMETER SqlAdminPrincipalName
The name of the SQL Admin principal. Required only if the principal type is Group or ServicePrincipal.

.PARAMETER SqlAdminPrincipalObjectId
The object ID of the SQL Admin principal. Required only if the principal type is Group or ServicePrincipal.

.PARAMETER EnableDefaultTelemetry
A boolean to indicate if the default telemetry should be enabled. Default is true.

.EXAMPLE
.\Deploy-AzureOptimizationEngine.ps1

Deploys or upgrades the Azure Optimization Engine using the default template from the GitHub repository.

.EXAMPLE
.\Deploy-AzureOptimizationEngine.ps1 -DoPartialUpgrade

Performs a partial upgrade of the existing resources.

.EXAMPLE
.\Deploy-AzureOptimizationEngine.ps1 -TemplateUri "https://raw.githubusercontent.com/microsoft/finops-toolkit/dev/src/optimization-engine/azuredeploy.bicep" -AzureEnvironment "AzureChinaCloud" -ResourceTags @{"Environment"="Production"; "Owner"="John Doe"}

Deploys or upgrades the Azure Optimization Engine using a custom template from the GitHub repository, in the AzureChinaCloud environment, with custom resource tags.

.LINK
https://aka.ms/AzureOptimizationEngine/deployment
#>
param (
    [Parameter(Mandatory = $false)]
    [string] $TemplateUri,

    [Parameter(Mandatory = $false)]
    [string] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [switch] $DoPartialUpgrade,

    [Parameter(Mandatory = $false)]
    [switch] $IgnoreNamingAvailabilityErrors,

    [Parameter(Mandatory = $false)]
    [string] $SilentDeploymentSettingsPath,

    [Parameter(Mandatory = $false)]
    [hashtable] $ResourceTags = @{},

    [Parameter(Mandatory = $false)]
    [string] $SqlAdminPrincipalType = "User",

    [Parameter(Mandatory = $false)]
    [string] $SqlAdminPrincipalName,

    [Parameter(Mandatory = $false)]
    [string] $SqlAdminPrincipalObjectId,

    [Parameter(Mandatory = $false)]
    [bool] $EnableDefaultTelemetry = $true
)

function ConvertTo-Hashtable
{
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject)
        {
            return $null
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject)
                {
                    ConvertTo-Hashtable -InputObject $object
                }
            )
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        }
        else
        {
            $InputObject
        }
    }
}

$ErrorActionPreference = "Stop"

#region Deployment environment settings

$lastDeploymentStatePath = ".\last-deployment-state.json"
$deploymentOptions = @{}
$silentDeploy = $false

# Check if silent deployment settings file exists
if (-not([string]::IsNullOrEmpty($SilentDeploymentSettingsPath)) -and (Test-Path -Path $SilentDeploymentSettingsPath))
{
    $silentDeploy = $true
    # Get the deployment details from the silent deployment settings file
    $silentDepOptions = Get-Content -Path $SilentDeploymentSettingsPath | ConvertFrom-Json
    Write-Host "Silent deployment options found." -ForegroundColor Green
    $silentDepOptions = ConvertTo-Hashtable -InputObject $silentDepOptions
    $silentDepOptions.Keys | ForEach-Object {
        $deploymentOptions[$_] = $silentDepOptions[$_]
    }

    # Validate the silent deployment settings
    if (-not($deploymentOptions["SubscriptionId"]))
    {
        throw "SubscriptionId is required for silent deployment."
    }
    if (-not($deploymentOptions["NamePrefix"]))
    {
        throw "NamePrefix is required for silent deployment. Set to 'EmptyNamePrefix' to use own naming convention and specify the needed resource names."
    }
    if ($deploymentOptions["NamePrefix"].Length -gt 21)
    {
        throw "Name prefix length is larger than the 21 characters limit ($($deploymentOptions["NamePrefix"]))"
    }
    if ($deploymentOptions["NamePrefix"] -eq "EmptyNamePrefix")
    {
        if (-not($deploymentOptions["ResourceGroupName"]))
        {
            throw "ResourceGroupName is required for silent deployment when NamePrefix is set to 'EmptyNamePrefix'."
        }
        if (-not($deploymentOptions["StorageAccountName"]))
        {
            throw "StorageAccountName is required for silent deployment when NamePrefix is set to 'EmptyNamePrefix'."
        }
        if (-not($deploymentOptions["AutomationAccountName"]))
        {
            throw "AutomationAccountName is required for silent deployment when NamePrefix is set to 'EmptyNamePrefix'."
        }
        if (-not($deploymentOptions["SqlServerName"]))
        {
            throw "SqlServerName is required for silent deployment when NamePrefix is set to 'EmptyNamePrefix'."
        }
        if (-not($deploymentOptions["SqlDatabaseName"]))
        {
            throw "SqlDatabaseName is required for silent deployment when NamePrefix is set to 'EmptyNamePrefix'."
        }
    }
    if (-not($deploymentOptions["WorkspaceReuse"]) -or ($deploymentOptions["WorkspaceReuse"] -ne "y" -and $deploymentOptions["WorkspaceReuse"] -ne "n"))
    {
        throw "WorkspaceReuse set to 'y' or 'n' is required for silent deployment."
    }
    if ($deploymentOptions["WorkspaceReuse"] -eq "y")
    {
        if (-not($deploymentOptions["WorkspaceName"]))
        {
            throw "WorkspaceName is required for silent deployment when WorkspaceReuse is set to 'y'."
        }
        if (-not($deploymentOptions["WorkspaceResourceGroupName"]))
        {
            throw "WorkspaceResourceGroupName is required for silent deployment when WorkspaceReuse is set to 'y'."
        }
    }
    if (-not($deploymentOptions["DeployWorkbooks"]) -or ($deploymentOptions["DeployWorkbooks"] -ne "y" -and $deploymentOptions["DeployWorkbooks"] -ne "n"))
    {
        throw "DeployWorkbooks set to 'y' or 'n' is required for silent deployment."
    }
    if (-not($deploymentOptions["TargetLocation"]))
    {
        throw "TargetLocation is required for silent deployment."
    }
    if (-not($deploymentOptions["DeployBenefitsUsageDependencies"]))
    {
        throw "DeployBenefitsUsageDependencies is required for silent deployment."
    }
    if ($deploymentOptions["DeployBenefitsUsageDependencies"] -eq "y")
    {
        if (-not($deploymentOptions["CustomerType"]))
        {
            throw "CustomerType is required for silent deployment when DeployBenefitsUsageDependencies is set to 'y'."
        }
        if (-not($deploymentOptions["BillingAccountId"]))
        {
            throw "BillingAccountId is required for silent deployment when DeployBenefitsUsageDependencies is set to 'y'."
        }
        if (-not($deploymentOptions["CurrencyCode"]))
        {
            throw "CurrencyCode is required for silent deployment when DeployBenefitsUsageDependencies is set to 'y'."
        }
        if ($deploymentOptions["CustomerType"] -eq "MCA")
        {
            if (-not($deploymentOptions["BillingProfileId"]))
            {
                throw "BillingProfileId is required for silent deployment when CustomerType is set to 'MCA'."
            }
        }
    }
}

if ((Test-Path -Path $lastDeploymentStatePath) -and !$silentDeploy)
{
    $depOptions = Get-Content -Path $lastDeploymentStatePath | ConvertFrom-Json
    Write-Host $depOptions -ForegroundColor Green
    $depOptionsReuse = Read-Host "Found last deployment options above. Do you want to repeat/upgrade last deployment (Y/N)?"
    if ("Y", "y" -contains $depOptionsReuse)
    {
        foreach ($property in $depOptions.PSObject.Properties)
        {
            $deploymentOptions[$property.Name] = $property.Value
        }
    }
}

$GitHubOriginalUri = "https://microsoft.github.io/finops-toolkit/deploy/optimization-engine/latest/azuredeploy.bicep"

if ([string]::IsNullOrEmpty($TemplateUri))
{
    $TemplateUri = $GitHubOriginalUri
}

$isTemplateAvailable = $false

try
{
    Invoke-WebRequest -Uri $TemplateUri | Out-Null
    $isTemplateAvailable = $true
}
catch
{
    Write-Host "The template URL ($TemplateUri) is not available. Please, put it in a publicly accessible HTTPS location." -ForegroundColor Red
}

if (!$isTemplateAvailable)
{
    throw "Terminating due to template unavailability."
}

if (-not((Test-Path -Path "./azuredeploy.bicep") -and (Test-Path -Path "./azuredeploy-nested.bicep")))
{
    throw "Terminating due to template unavailability. Please, change directory to where azuredeploy.bicep and azuredeploy-nested.bicep are located."
}

$ctx = Get-AzContext
if (-not($ctx))
{
    Connect-AzAccount -Environment $AzureEnvironment
    $ctx = Get-AzContext
}
else
{
    if ($ctx.Environment.Name -ne $AzureEnvironment)
    {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $AzureEnvironment
        $ctx = Get-AzContext
    }
}

if (-not([string]::IsNullOrEmpty($SqlAdminPrincipalName)) -and -not([string]::IsNullOrEmpty($SqlAdminPrincipalObjectId)))
{
    $userPrincipalName = $SqlAdminPrincipalName
    $userObjectId = $SqlAdminPrincipalObjectId
}
elseif ($SqlAdminPrincipalType -eq "User")
{
    $user = Get-AzADUser -SignedIn -Select UserType, UserPrincipalName, Id
    if (-not([string]::IsNullOrEmpty($user.UserPrincipalName)) -and -not([string]::IsNullOrEmpty($user.Id)))
    {
        $userPrincipalName = $user.UserPrincipalName
        $userObjectId = $user.Id
    }
    else
    {
        throw "Could not get the signed-in user details."
    }
}
else
{
    throw "You must provide the SQL Admin principal name and object Id for non-User principal types."
}

$cloudDetails = Get-AzEnvironment -Name $AzureEnvironment

#endregion

#region Azure subscription choice

Write-Host "Getting Azure subscriptions..." -ForegroundColor Yellow
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.SubscriptionPolicies.QuotaId -notlike "AAD*" }

if ($subscriptions.Count -gt 1)
{

    $selectedSubscription = -1
    for ($i = 0; $i -lt $subscriptions.Count; $i++)
    {
        if (-not($deploymentOptions["SubscriptionId"]))
        {
            Write-Output "[$i] $($subscriptions[$i].Name)"
        }
        else
        {
            if ($subscriptions[$i].Id -eq $deploymentOptions["SubscriptionId"])
            {
                $selectedSubscription = $i
                break
            }
        }
    }
    if (-not($deploymentOptions["SubscriptionId"]))
    {
        $lastSubscriptionIndex = $subscriptions.Count - 1
        while ($selectedSubscription -lt 0 -or $selectedSubscription -gt $lastSubscriptionIndex)
        {
            Write-Output "---"
            $selectedSubscription = [int] (Read-Host "Please, select the target subscription for this deployment [0..$lastSubscriptionIndex]")
        }
    }
    if ($selectedSubscription -eq -1)
    {
        throw "The selected subscription does not exist. Check if you are logged in with the right Microsoft Entra ID user."
    }
}
else
{
    if ($subscriptions.Count -ne 0)
    {
        $selectedSubscription = 0
    }
    else
    {
        throw "No valid subscriptions found. Only EA, MCA, PAYG or MSDN subscriptions are supported currently."
    }
}

if ($subscriptions.Count -eq 0)
{
    throw "No subscriptions found. Check if you are logged in with the right Microsoft Entra ID account."
}

$subscriptionId = $subscriptions[$selectedSubscription].Id

if (-not($deploymentOptions["SubscriptionId"]))
{
    $deploymentOptions["SubscriptionId"] = $subscriptionId
}

if ($ctx.Subscription.Id -ne $subscriptionId)
{
    $ctx = Select-AzSubscription -SubscriptionId $subscriptionId
}

#endregion

#region Resource naming options
if ($silentDeploy)
{
    $workspaceReuse = $deploymentOptions["WorkspaceReuse"]
}
else
{
    $workspaceReuse = $null
}

$deploymentNameTemplate = "{0}" + (Get-Date).ToString("yyMMddHHmmss")
$resourceGroupNameTemplate = "{0}-rg"
$storageAccountNameTemplate = "{0}sa"
$laWorkspaceNameTemplate = "{0}-la"
$automationAccountNameTemplate = "{0}-auto"
$sqlServerNameTemplate = "{0}-sql"

$nameAvailable = $true
if (-not($deploymentOptions["NamePrefix"]))
{
    do
    {
        $namePrefix = Read-Host "Please, enter a unique name prefix for the deployment (max. 21 chars) or existing prefix if updating deployment. If you want instead to individually name all resources, just press ENTER"
        if (-not($namePrefix))
        {
            $namePrefix = "EmptyNamePrefix"
        }
    }
    while ($namePrefix.Length -gt 21)
    $deploymentOptions["NamePrefix"] = $namePrefix
}
else
{
    if ($deploymentOptions["NamePrefix"] -eq "EmptyNamePrefix")
    {
        $namePrefix = $null
    }
    else
    {
        $namePrefix = $deploymentOptions["NamePrefix"]
    }
}

if (-not($deploymentOptions["WorkspaceReuse"]))
{
    if ($null -eq $workspaceReuse)
    {
        $workspaceReuse = Read-Host "Are you going to reuse an existing Log Analytics workspace (Y/N)?"
    }
    $deploymentOptions["WorkspaceReuse"] = $workspaceReuse
}
else
{
    $workspaceReuse = $deploymentOptions["WorkspaceReuse"]
}

if (-not($deploymentOptions["ResourceGroupName"]))
{
    if ([string]::IsNullOrEmpty($namePrefix) -or $namePrefix -eq "EmptyNamePrefix")
    {
        $resourceGroupName = Read-Host "Please, enter the new or existing Resource Group for this deployment"
        $deploymentName = $deploymentNameTemplate -f $resourceGroupName
        $storageAccountName = Read-Host "Enter the Storage Account name"
        $automationAccountName = Read-Host "Automation Account name"
        $sqlServerName = Read-Host "Azure SQL Server name"
        $sqlDatabaseName = Read-Host "Azure SQL Database name"
        if ("N", "n" -contains $workspaceReuse)
        {
            $laWorkspaceName = Read-Host "Log Analytics Workspace"
        }
    }
    else
    {
        $deploymentName = $deploymentNameTemplate -f $namePrefix
        $resourceGroupName = $resourceGroupNameTemplate -f $namePrefix
        $storageAccountName = $storageAccountNameTemplate -f $namePrefix
        $automationAccountName = $automationAccountNameTemplate -f $namePrefix
        $sqlServerName = $sqlServerNameTemplate -f $namePrefix
        if ("Y", "y" -contains $workspaceReuse -and $silentDeploy)
        {
            $laWorkspaceName = $deploymentOptions["WorkspaceName"]
        }
        else
        {
            $laWorkspaceName = $laWorkspaceNameTemplate -f $namePrefix
        }
        $sqlDatabaseName = "azureoptimization"
    }

    $deploymentOptions["ResourceGroupName"] = $resourceGroupName
    $deploymentOptions["StorageAccountName"] = $storageAccountName
    $deploymentOptions["AutomationAccountName"] = $automationAccountName
    $deploymentOptions["SqlServerName"] = $sqlServerName
    $deploymentOptions["SqlDatabaseName"] = $sqlDatabaseName
    $deploymentOptions["WorkspaceName"] = $laWorkspaceName
}
else
{
    # With a silent deploy, overrule any custom resource naming if a NamePrefix is provided
    if ($silentDeploy -and ![string]::IsNullOrEmpty($namePrefix) -and $namePrefix -ne "EmptyNamePrefix")
    {
        $deploymentName = $deploymentNameTemplate -f $namePrefix
        $resourceGroupName = $resourceGroupNameTemplate -f $namePrefix
        $storageAccountName = $storageAccountNameTemplate -f $namePrefix
        $automationAccountName = $automationAccountNameTemplate -f $namePrefix
        $sqlServerName = $sqlServerNameTemplate -f $namePrefix
        if ("Y", "y" -contains $workspaceReuse)
        {
            $laWorkspaceName = $deploymentOptions["WorkspaceName"]
        }
        else
        {
            $laWorkspaceName = $laWorkspaceNameTemplate -f $namePrefix
        }
        $sqlDatabaseName = "azureoptimization"
    }
    else
    {
        $resourceGroupName = $deploymentOptions["ResourceGroupName"]
        $storageAccountName = $deploymentOptions["StorageAccountName"]
        $automationAccountName = $deploymentOptions["AutomationAccountName"]
        $sqlServerName = $deploymentOptions["SqlServerName"]
        $sqlDatabaseName = $deploymentOptions["SqlDatabaseName"]
        $laWorkspaceName = $deploymentOptions["WorkspaceName"]
        $deploymentName = $deploymentNameTemplate -f $resourceGroupName
    }
}
#endregion

#region Resource naming availability checks
Write-Host "Checking name prefix availability..." -ForegroundColor Green

Write-Host "...for the Storage Account..." -ForegroundColor Green
$sa = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue
if ($null -eq $sa)
{
    $saNameResult = Get-AzStorageAccountNameAvailability -Name $storageAccountName
    if (-not($saNameResult.NameAvailable))
    {
        $nameAvailable = $false
        Write-Host "$($saNameResult.Message)" -ForegroundColor Red
    }
}
else
{
    Write-Host "(The Storage Account was already deployed)" -ForegroundColor Green
}

if ("N", "n" -contains $workspaceReuse)
{
    Write-Host "...for the Log Analytics workspace..." -ForegroundColor Green

    $logAnalyticsReuse = $false
    $laWorkspaceResourceGroup = $resourceGroupName

    $la = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $laWorkspaceName -ErrorAction SilentlyContinue
    if ($null -ne $la) {
        Write-Host "(The Log Analytics Workspace was already deployed)" -ForegroundColor Green
    }
}
else
{
    $logAnalyticsReuse = $true
}

Write-Host "...for the Azure SQL Server..." -ForegroundColor Green
$sqlServerAlreadyExists = $false
$sql = Get-AzSqlServer -ResourceGroupName $resourceGroupName -Name $sqlServerName -ErrorAction SilentlyContinue
if ($null -eq $sql -and -not($sqlServerName -like "*.database.*") -and -not($IgnoreNamingAvailabilityErrors))
{

    $SqlServerNameAvailabilityUriPath = "/subscriptions/$subscriptionId/providers/Microsoft.Sql/checkNameAvailability?api-version=2021-11-01"
    $body = "{`"name`": `"$sqlServerName`", `"type`": `"Microsoft.Sql/servers`"}"
    # TODO: Switch to custom Invoke-Rest command to leverage telemetry tracking
    $sqlNameResult = (Invoke-AzRestMethod -Path $SqlServerNameAvailabilityUriPath -Method POST -Payload $body).Content | ConvertFrom-Json

    if (-not($sqlNameResult.available))
    {
        $nameAvailable = $false
        Write-Host "$($sqlNameResult.message) ($sqlServerName)" -ForegroundColor Red
    }
}
else
{
    $sqlServerAlreadyExists = $true
    Write-Host "(The SQL Server was already deployed)" -ForegroundColor Green
}

if (-not($nameAvailable) -and -not($IgnoreNamingAvailabilityErrors))
{
    throw "Please, fix naming issues. Terminating execution."
}

Write-Host "Chosen resource names are available for all services" -ForegroundColor Green
#endregion

#region Additional resource options (LA reused, region, SQL user)
if (-not($deploymentOptions["WorkspaceResourceGroupName"]))
{
    if ("Y", "y" -contains $workspaceReuse)
    {
        $laWorkspaceName = Read-Host "Please, enter the name of the Log Analytics workspace to be reused"
        $laWorkspaceResourceGroup = Read-Host "Please, enter the name of the resource group containing Log Analytics $laWorkspaceName"
        $la = Get-AzOperationalInsightsWorkspace -ResourceGroupName $laWorkspaceResourceGroup -Name $laWorkspaceName -ErrorAction SilentlyContinue
        if (-not($la))
        {
            throw "Could not find $laWorkspaceName in resource group $laWorkspaceResourceGroup for the chosen subscription. Aborting."
        }
        $deploymentOptions["WorkspaceName"] = $laWorkspaceName
        $deploymentOptions["WorkspaceResourceGroupName"] = $laWorkspaceResourceGroup
    }
}
else
{
    $laWorkspaceResourceGroup = $deploymentOptions["WorkspaceResourceGroupName"]
}

$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if (-not($deploymentOptions["TargetLocation"]))
{
    if (-not($rg.Location))
    {
        Write-Host "Getting Azure locations..." -ForegroundColor Green
        $locations = Get-AzLocation | Where-Object { $_.Providers -contains "Microsoft.Automation" -and $_.Providers -contains "Microsoft.Sql" `
                -and $_.Providers -contains "Microsoft.OperationalInsights" `
                -and $_.Providers -contains "Microsoft.Storage" } | Sort-Object -Property Location

        for ($i = 0; $i -lt $locations.Count; $i++)
        {
            Write-Output "[$i] $($locations[$i].location)"
        }
        $selectedLocation = -1
        $lastLocationIndex = $locations.Count - 1
        while ($selectedLocation -lt 0 -or $selectedLocation -gt $lastLocationIndex)
        {
            Write-Output "---"
            $selectedLocation = [int] (Read-Host "Please, select the target location for this deployment [0..$lastLocationIndex]")
        }

        $targetLocation = $locations[$selectedLocation].location
    }
    else
    {
        $targetLocation = $rg.Location
    }

    $deploymentOptions["TargetLocation"] = $targetLocation
}
else
{
    $targetLocation = $deploymentOptions["TargetLocation"]
}
#endregion

#region Partial upgrade dependent resource checks
if (-not($DoPartialUpgrade))
{
    $upgrading = $false
}
else
{
    $upgrading = $true

    if ($null -ne $rg)
    {
        if ($upgrading -and $null -ne $sa)
        {
            $containers = Get-AzStorageContainer -Context $sa.Context
        }
        else
        {
            $upgrading = $false
            Write-Host "Did not find the $storageAccountName Storage Account." -ForegroundColor Yellow
        }

        if ($upgrading -and $null -ne $sql)
        {
            $databases = Get-AzSqlDatabase -ServerName $sql.ServerName -ResourceGroupName $resourceGroupName
            if (-not($databases | Where-Object { $_.DatabaseName -eq $sqlDatabaseName }))
            {
                $upgrading = $false
                Write-Host "Did not find the $sqlDatabaseName database." -ForegroundColor Yellow
            }
        }
        else
        {
            if (-not($IgnoreNamingAvailabilityErrors))
            {
                $upgrading = $false
                Write-Host "Did not find the $sqlServerName SQL Server." -ForegroundColor Yellow
            }
        }

        $auto = Get-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName -ErrorAction SilentlyContinue
        if ($null -ne $auto)
        {
            $runbooks = Get-AzAutomationRunbook -ResourceGroupName $resourceGroupName `
                -AutomationAccountName $auto.AutomationAccountName | Where-Object { $_.Name.StartsWith('Export') }
            if ($runbooks.Count -lt 3)
            {
                $upgrading = $false
                Write-Host "Did not find existing runbooks in the $automationAccountName Automation Account." -ForegroundColor Yellow
            }
        }
        else
        {
            $upgrading = $false
            Write-Host "Did not find the $automationAccountName Automation Account." -ForegroundColor Yellow
        }
    }
    else
    {
        $upgrading = $false
    }
}
#endregion

$deploymentMessage = "Deploying Azure Optimization Engine to subscription"
if ($upgrading)
{
    Write-Host "Looks like this deployment was already done in the past. We will only upgrade runbooks, modules, schedules, variables, storage and the database." -ForegroundColor Yellow
    $deploymentMessage = "Upgrading Azure Optimization Engine in subscription"
}

if ($silentDeploy)
{
    $continueInput = "Y"
}
else
{
    $continueInput = Read-Host "$deploymentMessage $($subscriptions[$selectedSubscription].Name). Continue (Y/N)?"
}
if ("Y", "y" -contains $continueInput)
{

    $deploymentOptions | ConvertTo-Json | Out-File -FilePath $lastDeploymentStatePath -Force
    #region Computing schedules base time
    $baseTime = (Get-Date).ToUniversalTime().ToString("u")
    $upgradingSchedules = $false
    $schedules = Get-AzAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
    if ($schedules.Count -gt 0)
    {
        $upgradingSchedules = $true
        $originalBaseTime = ($schedules | Where-Object { $_.Name.EndsWith("Weekly") } | Sort-Object -Property StartTime | Select-Object -First 1).StartTime.AddHours(-1.25).DateTime
        $now = (Get-Date).ToUniversalTime()
        $diff = $now.AddHours(-1.25) - $originalBaseTime
        $nextWeekDays = [Math]::Ceiling($diff.TotalDays / 7) * 7
        $baseTime = $now.AddHours(-1.25).AddDays($nextWeekDays - $diff.TotalDays).ToString("u")
        Write-Host "Existing schedules found. Keeping original base time: $baseTime." -ForegroundColor Green
    }
    else
    {
        Write-Host "Automation schedules base time automatically set to $baseTime." -ForegroundColor Green
    }
    #endregion

    if (-not($upgrading))
    {
        #region Template-based deployment
        $jobSchedules = Get-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
        if ($jobSchedules.Count -gt 0)
        {
            Write-Host "Unregistering previous runbook schedules associations from $automationAccountName..." -ForegroundColor Green
            foreach ($jobSchedule in $jobSchedules)
            {
                if ($jobSchedule.ScheduleName.StartsWith("AzureOptimization"))
                {
                    Unregister-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                        -JobScheduleId $jobSchedule.JobScheduleId -Force
                }
            }
        }

        Write-Host "Deploying Azure Optimization Engine resources..." -ForegroundColor Green
        $deploymentTries = 0
        $maxDeploymentTries = 2
        $deploymentSucceeded = $false
        do
        {
            $deploymentTries++
            try
            {
                $deployment = New-AzDeployment -TemplateFile ".\azuredeploy.bicep" -templateLocation $TemplateUri.Replace("azuredeploy.bicep", "") -Location $targetLocation -rgName $resourceGroupName -Name $deploymentName `
                    -projectLocation $targetlocation -logAnalyticsReuse $logAnalyticsReuse -baseTime $baseTime `
                    -logAnalyticsWorkspaceName $laWorkspaceName -logAnalyticsWorkspaceRG $laWorkspaceResourceGroup `
                    -storageAccountName $storageAccountName -automationAccountName $automationAccountName -sqlServerAlreadyExists $sqlServerAlreadyExists `
                    -sqlServerName $sqlServerName -sqlDatabaseName $sqlDatabaseName -cloudEnvironment $AzureEnvironment `
                    -userPrincipalName $userPrincipalName -userObjectId $userObjectId -sqlAdminPrincipalType $SqlAdminPrincipalType `
                    -resourceTags $ResourceTags -enableDefaultTelemetry $EnableDefaultTelemetry -WarningAction SilentlyContinue
                $deploymentSucceeded = $true
            }
            catch
            {
                if ($deploymentTries -ge $maxDeploymentTries)
                {
                    Write-Host "Failed deployment. Stop trying." -ForegroundColor Yellow
                    throw $_
                }
                Write-Host "Failed deployment. Trying once more..." -ForegroundColor Yellow
            }
        } while (-not($deploymentSucceeded) -and $deploymentTries -lt $maxDeploymentTries)

        if ($deployment.ProvisioningState -eq "Failed" -or $null -eq $deployment.Outputs)
        {
            throw "Deployment failed. Check the Azure subscription Activity Logs for more details."
        }

        $spnId = $deployment.Outputs['automationPrincipalId'].Value
        #endregion
    }
    else
    {
        #region Partial upgrade deployment
        $upgradeManifest = Get-Content -Path "./upgrade-manifest.json" | ConvertFrom-Json
        Write-Host "Creating missing storage account containers..." -ForegroundColor Green
        $upgradeContainers = $upgradeManifest.dataCollection.container
        foreach ($container in $upgradeContainers)
        {
            if (-not($container -in $containers.Name))
            {
                New-AzStorageContainer -Name $container -Context $sa.Context -Permission Off | Out-Null
                Write-Host "$container container created."
            }
        }

        Write-Host "Importing runbooks..." -ForegroundColor Green
        $allRunbooks = $upgradeManifest.baseIngest.runbook + $upgradeManifest.dataCollection.runbook + $upgradeManifest.recommendations.runbook + $upgradeManifest.remediations.runbook
        $runbookBaseUri = $TemplateUri.Replace("azuredeploy.bicep", "")
        $topTemplateJson = "{ `"`$schema`": `"https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#`", " + `
            "`"contentVersion`": `"1.0.0.0`", `"resources`": ["
        $bottomTemplateJson = "] }"
        $runbookDeploymentTemplateJson = $topTemplateJson
        for ($i = 0; $i -lt $allRunbooks.Count; $i++)
        {
            try
            {
                Invoke-WebRequest -Uri ($runbookBaseUri + $allRunbooks[$i].name) | Out-Null
                $runbookName = [System.IO.Path]::GetFilenameWithoutExtension($allRunbooks[$i].name)
                $runbookJson = "{ `"name`": `"$automationAccountName/$runbookName`", `"type`": `"Microsoft.Automation/automationAccounts/runbooks`", " + `
                    "`"apiVersion`": `"2018-06-30`", `"location`": `"$targetLocation`", `"tags`": $($ResourceTags | ConvertTo-Json), `"properties`": { " + `
                    "`"runbookType`": `"PowerShell`", `"logProgress`": false, `"logVerbose`": false, " + `
                    "`"publishContentLink`": { `"uri`": `"$runbookBaseUri$($allRunbooks[$i].name)`", `"version`": `"$($allRunbooks[$i].version)`" } } }"
                $runbookDeploymentTemplateJson += $runbookJson
                if ($i -lt $allRunbooks.Count - 1)
                {
                    $runbookDeploymentTemplateJson += ", "
                }
                Write-Host "$($allRunbooks[$i].name) imported."
            }
            catch
            {
                Write-Host "$($allRunbooks[$i].name) not imported (not found)." -ForegroundColor Yellow
            }
        }
        $runbookDeploymentTemplateJson += $bottomTemplateJson
        $runbooksTemplatePath = "./aoe-runbooks-deployment.json"
        $runbookDeploymentTemplateJson | Out-File -FilePath $runbooksTemplatePath -Force
        Write-Host "Executing runbooks deployment..." -ForegroundColor Green
        New-AzResourceGroupDeployment -TemplateFile $runbooksTemplatePath -ResourceGroupName $resourceGroupName -Name ($deploymentNameTemplate -f "runbooks") | Out-Null
        Remove-Item -Path $runbooksTemplatePath -Force
        Write-Host "Runbooks update deployed."

        Write-Host "Importing modules..." -ForegroundColor Green
        $allModules = $upgradeManifest.modules
        $modulesDeploymentTemplateJson = $topTemplateJson
        for ($i = 0; $i -lt $allModules.Count; $i++)
        {
            $moduleJson = "{ `"name`": `"$automationAccountName/$($allModules[$i].name)`", `"type`": `"Microsoft.Automation/automationAccounts/modules`", " + `
                "`"apiVersion`": `"2018-06-30`", `"location`": `"$targetLocation`", `"tags`": $($ResourceTags | ConvertTo-Json), `"properties`": { " + `
                "`"contentLink`": { `"uri`": `"$($allModules[$i].url)`" } } "
            if ($allModules[$i].name -ne "Az.Accounts" -and $allModules[$i].name -ne "Microsoft.Graph.Authentication")
            {
                $moduleJson += ", `"dependsOn`": [ `"Az.Accounts`", `"Microsoft.Graph.Authentication`" ]"
            }
            $moduleJson += "}"
            $modulesDeploymentTemplateJson += $moduleJson
            if ($i -lt $allModules.Count - 1)
            {
                $modulesDeploymentTemplateJson += ", "
            }
            Write-Host "$($allModules[$i].name) imported."
        }
        $modulesDeploymentTemplateJson += $bottomTemplateJson
        $modulesTemplatePath = "./aoe-modules-deployment.json"
        $modulesDeploymentTemplateJson | Out-File -FilePath $modulesTemplatePath -Force
        Write-Host "Executing modules deployment..." -ForegroundColor Green
        New-AzResourceGroupDeployment -TemplateFile $modulesTemplatePath -ResourceGroupName $resourceGroupName -Name ($deploymentNameTemplate -f "modules") | Out-Null
        Remove-Item -Path $modulesTemplatePath -Force
        Write-Host "Modules update deployed."

        Write-Host "Updating schedules..." -ForegroundColor Green
        $allSchedules = $upgradeManifest.schedules

        $allScheduledRunbooks = Get-AzAutomationScheduledRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName
        $exportHybridWorkerOption = ($allScheduledRunbooks | Where-Object { $_.RunbookName.StartsWith("Export") })[0].HybridWorker
        $ingestHybridWorkerOption = ($allScheduledRunbooks | Where-Object { $_.RunbookName.StartsWith("Ingest") })[0].HybridWorker
        $recommendHybridWorkerOption = ($allScheduledRunbooks | Where-Object { $_.RunbookName.StartsWith("Recommend") })[0].HybridWorker
        if ($allScheduledRunbooks | Where-Object { $_.RunbookName.StartsWith("Remediate") })
        {
            $remediateHybridWorkerOption = ($allScheduledRunbooks | Where-Object { $_.RunbookName.StartsWith("Remediate") })[0].HybridWorker
        }

        $hybridWorkerOption = "None"
        if ($exportHybridWorkerOption -or $ingestHybridWorkerOption -or $recommendHybridWorkerOption -or $remediateHybridWorkerOption)
        {
            $hybridWorkerOption = "Export: $exportHybridWorkerOption; Ingest: $ingestHybridWorkerOption; Recommend: $recommendHybridWorkerOption; Remediate: $remediateHybridWorkerOption"
        }
        Write-Host "Current Hybrid Worker option: $hybridWorkerOption" -ForegroundColor Green

        $dataIngestRunbookName = [System.IO.Path]::GetFileNameWithoutExtension(($upgradeManifest.baseIngest | Where-Object { $_.source -eq "dataCollection" }).runbook.name)
        $dataExportsToMultiSchedule = $upgradeManifest.dataCollection | Where-Object { $_.exportSchedules.Count -gt 0 }
        $recommendationsProcessingRunbooks = $upgradeManifest.baseIngest | Where-Object { $_.source -eq "recommendations" -or $_.source -eq "maintenance" }

        foreach ($schedule in $allSchedules)
        {
            if (-not($schedules | Where-Object { $_.Name -eq $schedule.name }))
            {
                $scheduleStartTime = (Get-Date $baseTime).Add([System.Xml.XmlConvert]::ToTimeSpan($schedule.offset))
                $scheduleNow = (Get-Date).ToUniversalTime()

                if ($schedule.frequency -eq "Hour")
                {
                    if ($scheduleNow.AddMinutes(5) -gt $scheduleStartTime)
                    {
                        $hoursDiff = ($scheduleNow - $scheduleStartTime).Hours + 1
                        $scheduleStartTime = $scheduleStartTime.AddHours($hoursDiff)
                    }

                    New-AzAutomationSchedule -Name $schedule.name -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                        -StartTime $scheduleStartTime -HourInterval 1 | Out-Null
                }
                if ($schedule.frequency -eq "Day")
                {
                    if ($scheduleNow.AddMinutes(5) -gt $scheduleStartTime)
                    {
                        $scheduleStartTime = $scheduleStartTime.AddDays(1)
                    }

                    New-AzAutomationSchedule -Name $schedule.name -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                        -StartTime $scheduleStartTime -DayInterval 1 | Out-Null
                }
                if ($schedule.frequency -eq "Week")
                {
                    if ($scheduleNow.AddMinutes(5) -gt $scheduleStartTime)
                    {
                        $scheduleStartTime = $scheduleStartTime.AddDays(7)
                    }

                    New-AzAutomationSchedule -Name $schedule.name -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                        -StartTime $scheduleStartTime -WeekInterval 1 | Out-Null
                }
                Write-Host "$($schedule.name) schedule created."
            }

            $scheduledRunbooks = Get-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                -ScheduleName $schedule.name

            $dataExportsToSchedule = ($upgradeManifest.dataCollection + $upgradeManifest.recommendations) | Where-Object { $_.exportSchedule -eq $schedule.name }
            foreach ($dataExport in $dataExportsToSchedule)
            {
                $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($dataExport.runbook.name)
                $runbookType = $runbookName.Split("-")[0]
                switch ($runbookType)
                {
                    "Export"
                    {
                        $hybridWorkerName = $exportHybridWorkerOption
                    }
                    "Recommend"
                    {
                        $hybridWorkerName = $recommendHybridWorkerOption
                    }
                    "Ingest"
                    {
                        $hybridWorkerName = $ingestHybridWorkerOption
                    }
                    "Remediate"
                    {
                        $hybridWorkerName = $remediateHybridWorkerOption
                    }
                    default
                    {
                        $hybridWorkerName = $null
                    }
                }

                if (-not($scheduledRunbooks | Where-Object { $_.RunbookName -eq $runbookName }))
                {
                    if ($hybridWorkerName)
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $runbookName -ScheduleName $schedule.name -RunOn $hybridWorkerName | Out-Null
                    }
                    else
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $runbookName -ScheduleName $schedule.name | Out-Null
                    }
                    Write-Host "Added $($schedule.name) schedule to $hybridWorkerName $runbookName runbook"
                }
            }

            foreach ($dataExport in $dataExportsToMultiSchedule)
            {
                $exportSchedule = $dataExport.exportSchedules | Where-Object { $_.schedule -eq $schedule.name }
                if ($exportSchedule)
                {
                    $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($dataExport.runbook.name)
                    $runbookType = $runbookName.Split("-")[0]
                    switch ($runbookType)
                    {
                        "Export"
                        {
                            $hybridWorkerName = $exportHybridWorkerOption
                        }
                        "Recommend"
                        {
                            $hybridWorkerName = $recommendHybridWorkerOption
                        }
                        "Ingest"
                        {
                            $hybridWorkerName = $ingestHybridWorkerOption
                        }
                        "Remediate"
                        {
                            $hybridWorkerName = $remediateHybridWorkerOption
                        }
                        default
                        {
                            $hybridWorkerName = $null
                        }
                    }

                    if (-not($scheduledRunbooks | Where-Object { $_.RunbookName -eq $runbookName -and $_.ScheduleName -eq $schedule.name }))
                    {
                        $params = @{}
                        $exportSchedule.parameters.PSObject.Properties | ForEach-Object {
                            $params[$_.Name] = $_.Value
                        }

                        if ($hybridWorkerName)
                        {
                            Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                -RunbookName $runbookName -ScheduleName $schedule.name -RunOn $hybridWorkerName -Parameters $params | Out-Null
                        }
                        else
                        {
                            Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                -RunbookName $runbookName -ScheduleName $schedule.name -Parameters $params | Out-Null
                        }
                        Write-Host "Added $($schedule.name) schedule to $hybridWorkerName $runbookName runbook."
                    }
                }
            }

            $dataIngestToSchedule = $upgradeManifest.dataCollection | Where-Object { $_.ingestSchedule -eq $schedule.name }
            foreach ($dataIngest in $dataIngestToSchedule)
            {
                $hybridWorkerName = $ingestHybridWorkerOption

                if (-not($scheduledRunbooks | Where-Object { $_.RunbookName -eq $dataIngestRunbookName }))
                {
                    $params = @{"StorageSinkContainer" = $dataIngest.container }

                    if ($hybridWorkerName)
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $dataIngestRunbookName -ScheduleName $schedule.name -RunOn $hybridWorkerName -Parameters $params | Out-Null
                    }
                    else
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $dataIngestRunbookName -ScheduleName $schedule.name -Parameters $params | Out-Null
                    }
                    Write-Host "Added $($schedule.name) schedule to $hybridWorkerName $dataIngestRunbookName runbook."
                }
            }

            foreach ($recommendationsProcessingRunbook in $recommendationsProcessingRunbooks)
            {
                $runbookName = [System.IO.Path]::GetFileNameWithoutExtension($recommendationsProcessingRunbook.runbook.name)
                $hybridWorkerName = $ingestHybridWorkerOption

                if ($recommendationsProcessingRunbook.schedule -eq $schedule.name -and -not($scheduledRunbooks | Where-Object { $_.RunbookName -eq $runbookName }))
                {
                    if ($hybridWorkerName)
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $runbookName -ScheduleName $schedule.name -RunOn $hybridWorkerName | Out-Null
                    }
                    else
                    {
                        Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                            -RunbookName $runbookName -ScheduleName $schedule.name | Out-Null
                    }
                    Write-Host "Added $($schedule.name) schedule to $hybridWorkerName $runbookName runbook."
                }
            }
        }

        Write-Host "Updating variables..." -ForegroundColor Green
        $allVariables = $upgradeManifest.dataCollection.requiredVariables + $upgradeManifest.recommendations.requiredVariables + $upgradeManifest.remediations.requiredVariables
        foreach ($variable in $allVariables)
        {
            $existingVariables = Get-AzAutomationVariable -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
            if (-not($existingVariables | Where-Object { $_.Name -eq $variable.name }))
            {
                New-AzAutomationVariable -Name $variable.name -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                    -Value $variable.defaultValue -Encrypted $false | Out-Null
                Write-Host "$($variable.name) variable created."
            }
        }

        Write-Host "Force-updating variables..." -ForegroundColor Green
        $forceUpdateVariables = $upgradeManifest.overwriteVariables
        foreach ($variable in $forceUpdateVariables)
        {
            Set-AzAutomationVariable -Name $variable.name -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                -Value $variable.value -Encrypted $false | Out-Null
            Write-Host "$($variable.name) variable updated."
        }

        Write-Host "Removing deprecated runbooks..." -ForegroundColor Green
        $deprecatedRunbooks = $upgradeManifest.deprecatedRunbooks
        foreach ($deprecatedRunbook in $deprecatedRunbooks)
        {
            Remove-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name $deprecatedRunbook -ResourceGroupName $resourceGroupName -Force -ErrorAction SilentlyContinue
        }
        #endregion
    }

    #region Schedules reset
    if ($upgradingSchedules)
    {
        $schedules = Get-AzAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
        $dailySchedules = $schedules | Where-Object { $_.Frequency -eq "Day" -or $_.Frequency -eq "Hour" }
        Write-Host "Fixing daily schedules after upgrade..." -ForegroundColor Green
        foreach ($schedule in $dailySchedules)
        {
            $now = (Get-Date).ToUniversalTime()
            $newStartTime = [System.DateTimeOffset]::Parse($now.ToString("yyyy-MM-ddT00:00:00Z"))
            $newStartTime = $newStartTime.AddHours($schedule.StartTime.Hour).AddMinutes($schedule.StartTime.Minute)
            if ($newStartTime.AddMinutes(-5) -lt $now)
            {
                $newStartTime = $newStartTime.AddDays(1)
            }
            $expiryTime = $schedule.ExpiryTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $startTime = $newStartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $automationPath = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/schedules/$($schedule.Name)?api-version=2015-10-31"
            $body = "{
                `"name`": `"$($schedule.Name)`",
                `"properties`": {
                  `"description`": `"$($schedule.Description)`",
                  `"startTime`": `"$startTime`",
                  `"expiryTime`": `"$expiryTime`",
                  `"interval`": 1,
                  `"frequency`": `"$($schedule.Frequency.ToString())`",
                  `"advancedSchedule`": {}
                }
              }"
            Invoke-AzRestMethod -Path $automationPath -Method PUT -Payload $body | Out-Null
        }
    }
    #endregion

    #region Deployment date Automation variable
    Write-Host "Checking Azure Automation variable referring to the initial Azure Optimization Engine deployment date..." -ForegroundColor Green
    $deploymentDateVariableName = "AzureOptimization_DeploymentDate"
    $deploymentDateVariable = Get-AzAutomationVariable -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $deploymentDateVariableName -ErrorAction SilentlyContinue

    if ($null -eq $deploymentDateVariable)
    {
        $deploymentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
        Write-Host "Setting initial deployment date ($deploymentDate)..." -ForegroundColor Green
        New-AzAutomationVariable -Name $deploymentDateVariableName -Description "The date of the initial engine deployment" `
            -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Value $deploymentDate -Encrypted $false
    }
    #endregion

    # Ensuring SQL Server allows only Entra ID authentication
    if (-not((Get-AzSqlServerActiveDirectoryOnlyAuthentication -ServerName $sqlServerName -ResourceGroupName $resourceGroupName).AzureADOnlyAuthentication))
    {
        Write-Host "Setting $userPrincipalName as Microsoft Entra admin in SQL Database..." -ForegroundColor Green
        Set-AzSqlServerActiveDirectoryAdministrator -ObjectId $userObjectId `
            -ServerName $sqlServerName -ResourceGroupName $resourceGroupName -DisplayName $userPrincipalName | Out-Null
        Write-Host "Enabling Entra ID-only authentication in SQL Database..." -ForegroundColor Green
        Enable-AzSqlServerActiveDirectoryOnlyAuthentication -ServerName $sqlServerName -ResourceGroupName $resourceGroupName | Out-Null
    }

    # Ensuring the Automation Account identity has the necessary permissions to access the Storage Account (needed for partial upgrades)
    $sa = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $auto = Get-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $resourceGroupName
    $spnId = $auto.Identity.PrincipalId
    $storageBlobContributorRoleId = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Blob Data Contributor role
    $roleAssignment = Get-AzRoleAssignment -ObjectId $spnId -Scope $sa.Id -ErrorAction SilentlyContinue
    if (-not($roleAssignment) -or -not($roleAssignment.RoleDefinitionId -contains $storageBlobContributorRoleId))
    {
        Write-Host "Granting Storage Blob Data Contributor role to the Automation Account identity..." -ForegroundColor Green
        New-AzRoleAssignment -ObjectId $spnId -RoleDefinitionId $storageBlobContributorRoleId -Scope $sa.Id | Out-Null
    }

    #region Open SQL Server firewall rule
    if (-not($sqlServerName -like "*.database.*"))
    {
        $myPublicIp = (Invoke-WebRequest -Uri "https://ifconfig.me/ip").Content.Trim()
        if (-not($myPublicIp -like "*.*.*.*"))
        {
            $myPublicIp = (Invoke-WebRequest -Uri "https://ipv4.icanhazip.com").Content.Trim()
            if (-not($myPublicIp -like "*.*.*.*"))
            {
                $myPublicIp = (Invoke-WebRequest -Uri "https://ipinfo.io/ip").Content.Trim()
            }
        }

        Write-Host "Opening SQL Server firewall temporarily to your public IP ($myPublicIp)..." -ForegroundColor Green
        $tempFirewallRuleName = "InitialDeployment"
        New-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -FirewallRuleName $tempFirewallRuleName -StartIpAddress $myPublicIp -EndIpAddress $myPublicIp -ErrorAction Continue | Out-Null
    }
    #endregion

    #region SQL Database model deployment
    Write-Host "Deploying SQL Database model..." -ForegroundColor Green

    if (-not($sqlServerName -like "*.database.*"))
    {
        $sqlServerEndpoint = "$sqlServerName$($cloudDetails.SqlDatabaseDnsSuffix)"
    }
    else
    {
        $sqlServerEndpoint = $sqlServerName
    }
    $databaseName = $sqlDatabaseName
    $SqlTimeout = 60
    $tries = 0
    $connectionSuccess = $false
    do
    {
        $tries++
        try
        {

            $azureSqlDomain = $cloudDetails.SqlDatabaseDnsSuffix.Substring(1)
            $dbToken = (Get-AzAccessToken -ResourceUrl "https://$azureSqlDomain/" -AsSecureString).Token | ConvertFrom-SecureString -AsPlainText

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createTableQuery = Get-Content -Path "./model/loganalyticsingestcontrol-table.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $initTableQuery = Get-Content -Path "./model/loganalyticsingestcontrol-initialize.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $initTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $upgradeTableQuery = Get-Content -Path "./model/loganalyticsingestcontrol-upgrade.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $upgradeTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createTableQuery = Get-Content -Path "./model/sqlserveringestcontrol-table.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $initTableQuery = Get-Content -Path "./model/sqlserveringestcontrol-initialize.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $initTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createTableQuery = Get-Content -Path "./model/recommendations-table.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createTableQuery = Get-Content -Path "./model/recommendations-sp.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createTableQuery = Get-Content -Path "./model/filters-table.sql"
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createTableQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$sqlServerEndpoint,1433;Database=$databaseName;Encrypt=True;Connection Timeout=$SqlTimeout;")
            $Conn.AccessToken = $dbToken
            $Conn.Open()

            $createUserQuery = (Get-Content -Path "./model/automation-user.sql").Replace("<automation-account-name>", $automationAccountName)
            $Cmd = New-Object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandTimeout = $SqlTimeout
            $Cmd.CommandText = $createUserQuery
            $Cmd.ExecuteReader()
            $Conn.Close()

            $connectionSuccess = $true
        }
        catch
        {
            Write-Host "Failed to contact SQL at try $tries." -ForegroundColor Yellow
            Write-Host $Error[0] -ForegroundColor Yellow
            Start-Sleep -Seconds ($tries * 20)
        }
    } while (-not($connectionSuccess) -and $tries -lt 3)

    if (-not($connectionSuccess))
    {
        if (-not($sqlServerName -like "*.database.*"))
        {
            Write-Host "Deleting temporary SQL Server firewall rule..." -ForegroundColor Green
            Remove-AzSqlServerFirewallRule -FirewallRuleName $tempFirewallRuleName -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -ErrorAction Continue | Out-Null
        }
        throw "Could not establish connection to SQL."
    }
    #endregion

    #region Close SQL Server firewall rule
    if (-not($sqlServerName -like "*.database.*"))
    {
        Write-Host "Deleting temporary SQL Server firewall rule..." -ForegroundColor Green
        Remove-AzSqlServerFirewallRule -FirewallRuleName $tempFirewallRuleName -ResourceGroupName $resourceGroupName -ServerName $sqlServerName -ErrorAction Continue | Out-Null
    }
    #endregion

    #region Workbooks deployment
    if (-not($deploymentOptions["DeployWorkbooks"]))
    {
        $deployWorkbooks = Read-Host "Do you want to deploy the workbooks with additional insights (recommended)? (Y/N)"
    }
    else
    {
        $deployWorkbooks = $deploymentOptions["DeployWorkbooks"]
    }
    if ("Y", "y" -contains $deployWorkbooks)
    {
        $deploymentOptions["DeployWorkbooks"] = "Y"
        $deploymentOptions | ConvertTo-Json | Out-File -FilePath $lastDeploymentStatePath -Force
        Write-Host "Publishing workbooks..." -ForegroundColor Green
        $workbooks = Get-ChildItem -Path "./views/workbooks/" | Where-Object { $_.Name.EndsWith(".bicep") }
        $la = Get-AzOperationalInsightsWorkspace -ResourceGroupName $laWorkspaceResourceGroup -Name $laWorkspaceName
        foreach ($workbook in $workbooks)
        {
            $workbookFileName = [System.IO.Path]::GetFileNameWithoutExtension($workbook.Name)
            Write-Host "Deploying $workbookFileName workbook..."
            try
            {
                New-AzResourceGroupDeployment -TemplateFile $workbook.FullName -ResourceGroupName $resourceGroupName -Name ($deploymentNameTemplate -f $workbookFileName) `
                    -workbookSourceId $la.ResourceId -resourceTags $ResourceTags -WarningAction SilentlyContinue | Out-Null
            }
            catch
            {
                Write-Host "Failed to deploy the workbook. If you are upgrading AOE, please remove first the $workbookFileName workbook from the $laWorkspaceName Log Analytics workspace and then re-deploy." -ForegroundColor Yellow
            }
        }
    }
    #endregion

    if (!$silentDeploy)
    {
        #region Grant Microsoft Entra ID role to AOE principal
        if ($null -eq $spnId)
        {
            $auto = Get-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $resourceGroupName
            $spnId = $auto.Identity.PrincipalId
            if ($null -eq $spnId)
            {
                $runAsConnection = Get-AzAutomationConnection -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name AzureRunAsConnection -ErrorAction SilentlyContinue
                $runAsAppId = $runAsConnection.FieldDefinitionValues.ApplicationId
                if ($runAsAppId)
                {
                    $runAsServicePrincipal = Get-AzADServicePrincipal -ApplicationId $runAsAppId
                    $spnId = $runAsServicePrincipal.Id
                }
            }
        }

        try
        {
            Import-Module Microsoft.Graph.Authentication
            Import-Module Microsoft.Graph.Identity.DirectoryManagement

            Write-Host "Granting Microsoft Entra ID Global Reader role to the Automation Account (requires administrative permissions in Microsoft Entra and MS Graph PowerShell SDK >= 2.4.0)..." -ForegroundColor Green

            #workaround for https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/888
            $localPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            if (-not(Get-Item "$localPath\.graph\" -ErrorAction SilentlyContinue))
            {
                New-Item -Type Directory "$localPath\.graph"
            }

            switch ($cloudEnvironment)
            {
                "AzureUSGovernment"
                {
                    $graphEnvironment = "USGov"
                    break
                }
                "AzureChinaCloud"
                {
                    $graphEnvironment = "China"
                    break
                }
                "AzureGermanCloud"
                {
                    $graphEnvironment = "Germany"
                    break
                }
                default
                {
                    $graphEnvironment = "Global"
                }
            }

            Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.Read.All" -UseDeviceAuthentication -Environment $graphEnvironment -NoWelcome

            $globalReaderRole = Get-MgDirectoryRole -ExpandProperty Members -Property Id, Members, DisplayName, RoleTemplateId `
            | Where-Object { $_.RoleTemplateId -eq "f2ef992c-3afb-46b9-b7cf-a126ee74c451" }
            $globalReaders = $globalReaderRole.Members.Id
            if (-not($globalReaders -contains $spnId))
            {
                New-MgDirectoryRoleMemberByRef -DirectoryRoleId $globalReaderRole.Id -BodyParameter @{"@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$spnId" }
                Start-Sleep -Seconds 5
                $globalReaderRole = Get-MgDirectoryRole -ExpandProperty Members -Property Id, Members, DisplayName, RoleTemplateId `
                | Where-Object { $_.RoleTemplateId -eq "f2ef992c-3afb-46b9-b7cf-a126ee74c451" }
                $globalReaders = $globalReaderRole.Members.Id
                if ($globalReaders -contains $spnId)
                {
                    Write-Host "Role granted." -ForegroundColor Green
                }
                else
                {
                    throw "Error when trying to grant Global Reader role"
                }
            }
            else
            {
                Write-Host "Role was already granted before." -ForegroundColor Green
            }
        }
        catch
        {
            Write-Host $Error[0] -ForegroundColor Yellow
            Write-Host "Could not grant role. If you want Microsoft Entra-based recommendations, please grant the Global Reader role manually to the $automationAccountName managed identity or, for previous versions of AOE, to the Run As Account principal." -ForegroundColor Red
        }
        #endregion
    }
    else
    {
        Write-Host "Could not grant role. If you want Microsoft Entra-based recommendations, please grant the Global Reader role manually to the $automationAccountName managed identity or, for previous versions of AOE, to the Run As Account principal." -ForegroundColor Red
    }
    Write-Host "Azure Optimization Engine deployment completed! We're almost there..." -ForegroundColor Green

    #region Benefits Usage dependencies
    if (-not($deploymentOptions["DeployBenefitsUsageDependencies"]))
    {
        $benefitsUsageDependenciesOption = Read-Host "Do you also want to deploy the dependencies for the Azure Benefits usage workbooks (EA/MCA customers only + agreement administrator role required)? (Y/N)"
    }
    else
    {
        $benefitsUsageDependenciesOption = $deploymentOptions["DeployBenefitsUsageDependencies"]
    }
    if ("Y", "y" -contains $benefitsUsageDependenciesOption)
    {
        $deploymentOptions["DeployBenefitsUsageDependencies"] = $benefitsUsageDependenciesOption
        $automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName
        $principalId = $automationAccount.Identity.PrincipalId
        $tenantId = $automationAccount.Identity.TenantId

        $mcaBillingAccountIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+):([A-Za-z0-9]+(-[A-Za-z0-9]+)+)_[0-9]{4}-[0-9]{2}-[0-9]{2}"
        $mcaBillingProfileIdRegex = "([A-Za-z0-9]+(-[A-Za-z0-9]+)+)"

        if (-not($deploymentOptions["CustomerType"]))
        {
            $customerType = Read-Host "Are you an Enterprise Agreement (EA) or Microsoft Customer Agreement (MCA) customer? Please, type EA or MCA"
            $deploymentOptions["CustomerType"] = $customerType
        }
        else
        {
            $customerType = $deploymentOptions["CustomerType"]
        }

        switch ($customerType)
        {
            "EA"
            {
                if (-not($deploymentOptions["BillingAccountId"]))
                {
                    $billingAccountId = Read-Host "Please, enter your Enterprise Agreement Billing Account ID (e.g. 12345678)"
                    $deploymentOptions["BillingAccountId"] = $billingAccountId
                }
                else
                {
                    $billingAccountId = $deploymentOptions["BillingAccountId"]
                }
                try
                {
                    [int32]::Parse($billingAccountId) | Out-Null
                }
                catch
                {
                    throw "The Enterprise Agreement Billing Account ID must be a number (e.g. 12345678)."
                }
                Write-Host "Granting the Enterprise Enrollment Reader role to the AOE Managed Identity..." -ForegroundColor Green
                $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleAssignments?api-version=2019-10-01-preview"
                $roleAssignmentResponse = Invoke-AzRestMethod -Method GET -Uri $uri
                if (-not($roleAssignmentResponse.StatusCode -eq 200))
                {
                    throw "The Enterprise Enrollment Reader role could not be verified. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
                }
                $roleAssignments = ($roleAssignmentResponse.Content | ConvertFrom-Json).value
                if (-not($roleAssignments | Where-Object { $_.properties.principalId -eq $principalId -and $_.properties.roleDefinitionId -eq "/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" }))
                {
                    $billingRoleAssignmentName = ([System.Guid]::NewGuid()).Guid
                    $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleAssignments/$($billingRoleAssignmentName)?api-version=2019-10-01-preview"
                    $body = "{`"properties`": {`"principalId`":`"$principalId`",`"principalTenantId`":`"$tenantId`",`"roleDefinitionId`":`"/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e`"}}"
                    $roleAssignmentResponse = Invoke-AzRestMethod -Method PUT -Uri $uri -Payload $body
                    if (-not($roleAssignmentResponse.StatusCode -in (200, 201, 202)))
                    {
                        throw "The Enterprise Enrollment Reader role could not be granted. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
                    }
                }
                else
                {
                    Write-Host "Role was already granted before." -ForegroundColor Green
                }
                break
            }
            "MCA"
            {
                if (-not($deploymentOptions["BillingAccountId"]))
                {
                    $billingAccountId = Read-Host "Please, enter your Microsoft Customer Agreement Billing Account ID (e.g. <guid>:<guid>_YYYY-MM-DD)"
                    $deploymentOptions["BillingAccountId"] = $billingAccountId
                }
                else
                {
                    $billingAccountId = $deploymentOptions["BillingAccountId"]
                }
                if (-not($billingAccountId -match $mcaBillingAccountIdRegex))
                {
                    throw "The Microsoft Customer Agreement Billing Account ID must be in the format <guid>:<guid>_YYYY-MM-DD."
                }
                if (-not($deploymentOptions["BillingProfileId"]))
                {
                    $billingProfileId = Read-Host "Please, enter your Billing Profile ID (e.g. ABCD-DEF-GHI-JKL)"
                    $deploymentOptions["BillingProfileId"] = $billingProfileId
                }
                else
                {
                    $billingProfileId = $deploymentOptions["BillingProfileId"]
                }
                if (-not($billingProfileId -match $mcaBillingProfileIdRegex))
                {
                    throw "The Microsoft Customer Agreement Billing Profile ID must be in the format ABCD-DEF-GHI-JKL."
                }
                Write-Host "Granting the Billing Profile Reader role to the AOE Managed Identity..." -ForegroundColor Green
                $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleAssignments?api-version=2019-10-01-preview"
                $roleAssignmentResponse = Invoke-AzRestMethod -Method GET -Uri $uri
                if (-not($roleAssignmentResponse.StatusCode -eq 200))
                {
                    throw "The Billing Profile Reader role could not be verified. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
                }
                $roleAssignments = ($roleAssignmentResponse.Content | ConvertFrom-Json).value
                if (-not($roleAssignments | Where-Object { $_.properties.principalId -eq $principalId -and $_.properties.roleDefinitionId -eq "/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleDefinitions/40000000-aaaa-bbbb-cccc-100000000002" }))
                {
                    $uri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/createBillingRoleAssignment?api-version=2020-12-15-privatepreview"
                    $body = "{`"principalId`":`"$principalId`",`"principalTenantId`":`"$tenantId`",`"roleDefinitionId`":`"/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/billingRoleDefinitions/40000000-aaaa-bbbb-cccc-100000000002`"}"
                    $roleAssignmentResponse = Invoke-AzRestMethod -Method POST -Uri $uri -Payload $body
                    if (-not($roleAssignmentResponse.StatusCode -in (200, 201, 202)))
                    {
                        throw "The Billing Profile Reader role could not be granted. Status Code: $($roleAssignmentResponse.StatusCode); Response: $($roleAssignmentResponse.Content)"
                    }
                }
                else
                {
                    Write-Host "Role was already granted before." -ForegroundColor Green
                }
                break
            }
            default
            {
                throw "Only EA and MCA customers are supported at this time."
            }
        }

        Write-Output "Setting up the Billing Account ID variable..."
        $billingAccountIdVarName = "AzureOptimization_BillingAccountID"
        $billingAccountIdVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -ErrorAction SilentlyContinue
        if (-not($billingAccountIdVar))
        {
            New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -Value $billingAccountId -Encrypted $false | Out-Null
        }
        else
        {
            Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingAccountIdVarName -Value $billingAccountId -Encrypted $false | Out-Null
        }

        if ($billingProfileId)
        {
            Write-Output "Setting up the Billing Profile ID variable..."
            $billingProfileIdVarName = "AzureOptimization_BillingProfileID"
            $billingProfileIdVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -ErrorAction SilentlyContinue
            if (-not($billingProfileIdVar))
            {
                New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -Value $billingProfileId -Encrypted $false | Out-Null
            }
            else
            {
                Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $billingProfileIdVarName -Value $billingProfileId -Encrypted $false | Out-Null
            }
        }

        if (-not $deploymentOptions["CurrencyCode"])
        {
            $currencyCode = Read-Host "Please, enter your consumption currency code (e.g. EUR, USD, etc.)"
            $deploymentOptions["CurrencyCode"] = $currencyCode
        }
        else
        {
            $currencyCode = $deploymentOptions["CurrencyCode"]
        }

        $deploymentOptions | ConvertTo-Json | Out-File -FilePath $lastDeploymentStatePath -Force

        Write-Output "Setting up the consumption currency code variable..."
        $currencyCodeVarName = "AzureOptimization_RetailPricesCurrencyCode"
        $currencyCodeVar = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -ErrorAction SilentlyContinue
        if (-not($currencyCodeVar))
        {
            New-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -Value $currencyCode -Encrypted $false | Out-Null
        }
        else
        {
            Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $currencyCodeVarName -Value $currencyCode -Encrypted $false | Out-Null
        }
    }
    #endregion

    Write-Host "Deployment fully completed!" -ForegroundColor Green
}
else
{
    Write-Host "Deployment cancelled." -ForegroundColor Red
}
