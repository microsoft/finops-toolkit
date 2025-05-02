<#
.SYNOPSIS
Deploys Data Collection Rules (DCRs) to collect performance counters from Windows and Linux virtual machines.

.DESCRIPTION
This script deploys Data Collection Rules (DCRs) to collect performance counters from Windows and Linux virtual machines required by the Azure Optimization Engine
to augment the Azure Advisor virtual machine right-size recommendations with guest OS metrics and accurate fit score.

.PARAMETER AzureEnvironment
The Azure environment to use. Default is AzureCloud.

.PARAMETER DestinationWorkspaceResourceId
The Resource ID of the destination Log Analytics workspace.

.PARAMETER IntervalSeconds
The interval in seconds to collect performance counters. Default is 60 seconds.

.PARAMETER ResourceTags
The tags to apply to the resources created.

.EXAMPLE
.\Deploy-AzureOptimizationEngine.ps1 -DestinationWorkspaceResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.OperationalInsights/workspaces/MyWorkspace"

.LINK
https://aka.ms/AzureOptimizationEngine/customize
#>
param(
    [Parameter(Mandatory = $false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $true)]
    [String] $DestinationWorkspaceResourceId,

    [Parameter(Mandatory = $false)]
    [int] $IntervalSeconds = 60,

    [Parameter(Mandatory = $false)]
    [hashtable] $ResourceTags = @{}
)

$ErrorActionPreference = "Stop"

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

$lastDeploymentStatePath = ".\last-deployment-state.json"
$deploymentOptions = @{}

$perfCounters = Get-Content -Path ".\perfcounters.json" | ConvertFrom-Json

if ((Test-Path -Path $lastDeploymentStatePath))
{
    $depOptions = Get-Content -Path $lastDeploymentStatePath | ConvertFrom-Json
    Write-Host $depOptions -ForegroundColor Green
    $depOptionsReuse = Read-Host "Found last deployment options above. Do you want to create Data Collection Rules (DCRs) reusing the last deployment options (Y/N)?"
    if ("Y", "y" -contains $depOptionsReuse)
    {
        foreach ($property in $depOptions.PSObject.Properties)
        {
            $deploymentOptions[$property.Name] = $property.Value
        }
    }
}

Write-Host "Getting Azure subscriptions..." -ForegroundColor Yellow
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" -and $_.SubscriptionPolicies.QuotaId -notlike "AAD*" }

if ($subscriptions.Count -gt 1) {

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
        while ($selectedSubscription -lt 0 -or $selectedSubscription -gt $lastSubscriptionIndex) {
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

if ($subscriptions.Count -eq 0) {
    throw "No subscriptions found. Check if you are logged in with the right Microsoft Entra ID account."
}

$subscriptionId = $subscriptions[$selectedSubscription].Id

if ($ctx.Subscription.SubscriptionId -ne $DestinationWorkspaceResourceId.Split('/')[2])
{
    $ctx = Set-AzContext -SubscriptionId $DestinationWorkspaceResourceId.Split('/')[2]
}

$la = Get-AzOperationalInsightsWorkspace -ResourceGroupName $DestinationWorkspaceResourceId.Split('/')[4] -Name $DestinationWorkspaceResourceId.Split('/')[8] -ErrorAction SilentlyContinue

if (-not($la))
{
    throw "The destination workspace ($DestinationWorkspaceResourceId) does not exist. Check if you are logged in with the right Microsoft Entra ID user."
}

if (-not($deploymentOptions["NamePrefix"]))
{
    do
    {
        $namePrefix = Read-Host "Please, enter a unique name prefix for the DCRs or existing prefix if updating deployment. If you want instead to individually name all DCRs, just press ENTER"
        if (-not($namePrefix))
        {
            $namePrefix = "EmptyNamePrefix"
        }
    }
    while ($namePrefix.Length -gt 21)
}
else {
    if ($deploymentOptions["NamePrefix"] -eq "EmptyNamePrefix")
    {
        $namePrefix = $null
    }
    else
    {
        $namePrefix = $deploymentOptions["NamePrefix"]
    }
}

$windowsDcrNameTemplate = "{0}-windows-dcr"
$linuxDcrNameTemplate = "{0}-linux-dcr"

if (-not($deploymentOptions["ResourceGroupName"]))
{

    $resourceGroupName = Read-Host "Please, enter the new or existing Resource Group for this deployment"
}
else
{
    $resourceGroupName = $deploymentOptions["ResourceGroupName"]
}

if ($ctx.Subscription.SubscriptionId -ne $subscriptionId)
{
    $ctx = Set-AzContext -SubscriptionId $subscriptionId
}

$rg = Get-AzResourceGroup -Name $resourceGroupName

if ([string]::IsNullOrEmpty($namePrefix) -or $namePrefix -eq "EmptyNamePrefix") {
    $windowsDcrName = Read-Host "Enter the Windows DCR name"
    $linuxDcrName = Read-Host "Enter the Linux DCR name"
}
else {
    $windowsDcrName = $windowsDcrNameTemplate -f $namePrefix
    $linuxDcrName = $linuxDcrNameTemplate -f $namePrefix
}

if (-not($deploymentOptions["TargetLocation"]))
{
    if (-not($rg.Location)) {
        Write-Host "Getting Azure locations..." -ForegroundColor Green
        $locations = Get-AzLocation | Where-Object { $_.Providers -contains "Microsoft.Insights" } | Sort-Object -Property Location

        for ($i = 0; $i -lt $locations.Count; $i++) {
            Write-Output "[$i] $($locations[$i].location)"
        }
        $selectedLocation = -1
        $lastLocationIndex = $locations.Count - 1
        while ($selectedLocation -lt 0 -or $selectedLocation -gt $lastLocationIndex) {
            Write-Output "---"
            $selectedLocation = [int] (Read-Host "Please, select the target location for this deployment [0..$lastLocationIndex]")
        }

        $targetLocation = $locations[$selectedLocation].location
    }
    else {
        $targetLocation = $rg.Location
    }
}
else
{
    $targetLocation = $deploymentOptions["TargetLocation"]
}

$windowsPerfCounters = @()
foreach ($perfCounter in ($perfCounters | Where-Object {$_.osType -eq "Windows"})) {
    $windowsPerfCounters += $ExecutionContext.InvokeCommand.ExpandString('"\\$($perfCounter.objectName)($($perfCounter.instance))\\$($perfCounter.counterName)"')
}

$linuxPerfCounters = @()
foreach ($perfCounter in ($perfCounters | Where-Object {$_.osType -eq "Linux"})) {
    $linuxPerfCounters += $ExecutionContext.InvokeCommand.ExpandString('"\\$($perfCounter.objectName)($($perfCounter.instance))\\$($perfCounter.counterName)"')
}

$windowsDcrBody = @'
{
    "dataSources": {
        "performanceCounters": [
            {
                "streams": [
                    "Microsoft-Perf"
                ],
                "samplingFrequencyInSeconds": $IntervalSeconds,
                "counterSpecifiers": [
                    $($windowsPerfCounters -join ",")
                ],
                "name": "perfCounterDataSource$IntervalSeconds"
            }
        ]
    },
    "destinations": {
        "logAnalytics": [
            {
                "workspaceResourceId": "$destinationWorkspaceResourceId",
                "workspaceId": "$($la.Properties.CustomerId)",
                "name": "la--1138206996"
            }
        ]
    },
    "dataFlows": [
        {
            "streams": [
                "Microsoft-Perf"
            ],
            "destinations": [
                "la--1138206996"
            ]
        }
    ]
}
'@

Write-Output "Creating Windows DCR..."
$windowsDcrBody = $ExecutionContext.InvokeCommand.ExpandString($windowsDcrBody) | ConvertFrom-Json
New-AzResource -ResourceType "Microsoft.Insights/dataCollectionRules" -ResourceGroupName $resourceGroupName -Location $targetLocation -Name $windowsDcrName -PropertyObject $windowsDcrBody -ApiVersion "2021-04-01" -Tag $ResourceTags -Kind "Windows" -Force | Out-Null

$linuxDcrBody = @'
{
    "dataSources": {
        "performanceCounters": [
            {
                "streams": [
                    "Microsoft-Perf"
                ],
                "samplingFrequencyInSeconds": $IntervalSeconds,
                "counterSpecifiers": [
                    $($linuxPerfCounters -join ",")
                ],
                "name": "perfCounterDataSource$IntervalSeconds"
            }
        ]
    },
    "destinations": {
        "logAnalytics": [
            {
                "workspaceResourceId": "$destinationWorkspaceResourceId",
                "workspaceId": "$($la.Properties.CustomerId)",
                "name": "la--1138206996"
            }
        ]
    },
    "dataFlows": [
        {
            "streams": [
                "Microsoft-Perf"
            ],
            "destinations": [
                "la--1138206996"
            ]
        }
    ]
}
'@

Write-Output "Creating Linux DCR..."
$linuxDcrBody = $ExecutionContext.InvokeCommand.ExpandString($linuxDcrBody) | ConvertFrom-Json
New-AzResource -ResourceType "Microsoft.Insights/dataCollectionRules" -ResourceGroupName $resourceGroupName -Location $targetLocation -Name $linuxDcrName -PropertyObject $linuxDcrBody -ApiVersion "2021-04-01" -Tag $ResourceTags -Kind "Linux" -Force | Out-Null

Write-Host -ForegroundColor Green "Deployment completed successfully"