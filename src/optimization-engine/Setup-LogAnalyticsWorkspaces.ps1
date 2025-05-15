<#
.SYNOPSIS
This script sets up Log Analytics workspaces for Azure Optimization Engine to collect the required performance counters with
the legacy Log Analytics agent (to be deprecated on Aug 31, 2024).

.DESCRIPTION
This script sets up Log Analytics workspaces for Azure Optimization Engine to collect the required performance counters with
the legacy Log Analytics agent (to be deprecated on Aug 31, 2024). The script will check if the required performance counters
are already being collected and will (optionally) automatically fix any missing performance counters.

.PARAMETER AzureEnvironment
The Azure environment to use. Default is AzureCloud.

.PARAMETER WorkspaceIds
The workspace IDs to use (use the workspace GUID, not the ARM resource ID). If not specified, all workspaces will be used.

.PARAMETER AutoFix
Automatically fix missing performance counters.

.PARAMETER IntervalSeconds
The interval in seconds to collect performance counters.

.EXAMPLE
.\Setup-LogAnalyticsWorkspaces.ps1 -WorkspaceIds "00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002" -AutoFix

.LINK
https://aka.ms/AzureOptimizationEngine/customize
#>
param(
    [Parameter(Mandatory = $false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [String[]] $WorkspaceIds,

    [Parameter(Mandatory = $false)]
    [switch] $AutoFix,

    [Parameter(Mandatory = $false)]
    [int] $IntervalSeconds = 60
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

$wsIds = foreach ($workspaceId in $WorkspaceIds)
{
    "'$workspaceId'"
}
if ($wsIds)
{
    $wsIds = $wsIds -join ","
    $whereWsIds = " and properties.customerId in ($wsIds)"
}

$perfCounters = Get-Content -Path ".\perfcounters.json" | ConvertFrom-Json

$ARGPageSize = 1000

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}

$argQuery = "resources | where type =~ 'microsoft.operationalinsights/workspaces'$whereWsIds | order by id"

$workspaces = (Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions).data

Write-Output "Found $($workspaces.Count) workspaces."

$laQuery = "Heartbeat | where TimeGenerated > ago(1d) and ComputerEnvironment == 'Azure' | distinct Computer | summarize AzureComputersCount = count()"

foreach ($workspace in $workspaces) {
    $laQueryResults = $null
    $results = $null
    $laQueryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.properties.customerId -Query $laQuery -Timespan (New-TimeSpan -Days 1) -ErrorAction Continue
    if ($laQueryResults)
    {
        $results = [System.Linq.Enumerable]::ToArray($laQueryResults.Results)
        Write-Output "$($workspace.name) ($($workspace.properties.customerId)): $($results.AzureComputersCount) Azure computers connected."
    }
    else
    {
        Write-Output "$($workspace.name) ($($workspace.properties.customerId)): could not validate connected computers."
    }
    if ($results.AzureComputersCount -gt 0)
    {
        if ($ctx.Subscription.SubscriptionId -ne $workspace.subscriptionId)
        {
            $ctx = Set-AzContext -SubscriptionId $workspace.subscriptionId
        }
        $dsWindows = Get-AzOperationalInsightsDataSource -ResourceGroupName $workspace.resourceGroup -WorkspaceName $workspace.name -Kind WindowsPerformanceCounter
        foreach ($perfCounter in ($perfCounters | Where-Object {$_.osType -eq "Windows"})) {
            if (-not($dsWindows | Where-Object { $_.Properties.ObjectName -eq $perfCounter.objectName -and $_.Properties.InstanceName -eq $perfCounter.instance `
                -and $_.Properties.CounterName -eq $perfCounter.counterName}))
            {
                Write-Output "Missing $($perfCounter.objectName)($($perfCounter.instance))\$($perfCounter.counterName)"
                if ($AutoFix)
                {
                    Write-Output "Fixing..."
                    $dsName = "DataSource_WindowsPerformanceCounter_$(New-Guid)"
                    New-AzOperationalInsightsWindowsPerformanceCounterDataSource -ResourceGroupName $workspace.resourceGroup -WorkspaceName $workspace.name `
                        -Name $dsName -ObjectName $perfCounter.objectName -CounterName $perfCounter.counterName -InstanceName $perfCounter.instance `
                        -IntervalSeconds $IntervalSeconds -Force | Out-Null
                }
            }
        }

        $missingLinuxCounters = @()
        $dsLinux = Get-AzOperationalInsightsDataSource -ResourceGroupName $workspace.resourceGroup -WorkspaceName $workspace.name -Kind LinuxPerformanceObject
        foreach ($perfCounter in ($perfCounters | Where-Object {$_.osType -eq "Linux"})) {
            if (-not($dsLinux | Where-Object { $_.Properties.ObjectName -eq $perfCounter.objectName -and $_.Properties.InstanceName -eq $perfCounter.instance `
                -and ($_.Properties.PerformanceCounters | Where-Object { $_.CounterName -eq $perfCounter.counterName }) }))
            {
                Write-Output "Missing $($perfCounter.objectName)($($perfCounter.instance))\$($perfCounter.counterName)"
                if ($AutoFix)
                {
                    $missingLinuxCounters += $perfCounter
                }
            }
        }

        if ($AutoFix)
        {
            $fixedLinuxCounters = @()
            $existingLinuxObjects = ($dsLinux | Select-Object -ExpandProperty Properties | Select-Object -Property ObjectName).ObjectName
            foreach ($linuxObject in $existingLinuxObjects) {
                $missingObjectCounters = $missingLinuxCounters | Where-Object { $_.objectName -eq $linuxObject }
                $originalDataSource = $dsLinux | Where-Object { $_.Properties.ObjectName -eq $linuxObject }
                foreach ($perfCounter in $missingObjectCounters) {
                    $fixedLinuxCounters += $perfCounter
                    $newCounterName = New-Object -TypeName Microsoft.Azure.Commands.OperationalInsights.Models.PerformanceCounterIdentifier -Property @{CounterName = $perfCounter.counterName}
                    $originalDataSource.Properties.PerformanceCounters.Add($newCounterName)
                }
                if ($missingObjectCounters)
                {
                    Write-Output "Fixing $linuxObject object..."
                    Set-AzOperationalInsightsDataSource -DataSource $originalDataSource | Out-Null
                }
            }
            $missingObjects = ($missingLinuxCounters | Select-Object -Property objectName -Unique).objectName
            $fixedObjects = ($fixedLinuxCounters | Select-Object -Property objectName -Unique).objectName
            $missingObjects = $missingObjects | Where-Object { -not($_ -in $fixedObjects) }
            foreach ($linuxObject in $missingObjects) {
                $missingObjectCounters = $missingLinuxCounters | Where-Object { $_.objectName -eq $linuxObject }
                $missingInstance = ($missingObjectCounters | Select-Object -Property instance -Unique -First 1).instance
                $missingCounterNames = ($missingObjectCounters).counterName

                Write-Output "Adding $linuxObject object..."
                New-AzOperationalInsightsLinuxPerformanceObjectDataSource -ResourceGroupName $workspace.resourceGroup -WorkspaceName $workspace.name `
                    -Name "DataSource_LinuxPerformanceObject_$(New-Guid)" -ObjectName $linuxObject -InstanceName $missingInstance -IntervalSeconds $IntervalSeconds `
                    -CounterNames $missingCounterNames -Force | Out-Null
            }
        }
    }
}