# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
    .SYNOPSIS
    Deploys and refreshes the FinOps hub instances that demo Power BI reports are built from.

    .DESCRIPTION
    Demo reports in PowerBI-demo.zip are saved with data from a demo hub. That hub has to be on
    the version being released and have data for the current month, or the demo either fails to
    refresh or ships with stale numbers.

    Deploys two kinds of instances:

    - "ftk-demo" is the current demo hub. It holds 12 months of data and is what demo reports are
      built from.
    - "ftk-demo-v{version}" is a versioned instance kept for testing an older release. It holds
      one month of data, and its Data Explorer cluster is stopped after data is ingested so it
      costs almost nothing to keep around.

    Run with -Check before a release to confirm the demo hub is current. It reports the hub
    version and the months of data it holds, and fails when the hub is behind the toolkit version
    or is missing data for the current month.

    .PARAMETER Version
    Optional. Deploys the versioned instance for a release (for example, "v15") instead of the current demo hub.

    .PARAMETER Subscription
    Optional. Name or ID of the subscription to deploy to. Default = "FTK Prod".

    .PARAMETER ResourceGroup
    Optional. Name of the resource group. Default = the instance name.

    .PARAMETER Location
    Optional. Azure region to deploy to. Default = "westus".

    .PARAMETER Scope
    Optional. Resource IDs of the scopes to export cost data for. Default = the subscription being deployed to.

    .PARAMETER Months
    Optional. Number of months of data to backfill. Default = 12 for the current demo hub, 1 for a versioned instance.

    .PARAMETER Check
    Optional. Reports whether the demo hub is ready for a release without changing anything. Default = false.

    .PARAMETER SkipBackfill
    Optional. Deploys the hub without creating or running exports. Default = false.

    .PARAMETER Stop
    Optional. Stops the Data Explorer cluster when the deployment finishes. Default = true for versioned instances.

    .PARAMETER Build
    Optional. Builds the templates before deploying. Default = false.

    .PARAMETER WhatIf
    Optional. Validates the deployment without making changes. Default = false.

    .EXAMPLE
    ./Deploy-Demo -Check

    Reports whether the demo hub is on the current version and has data for this month.

    .EXAMPLE
    ./Deploy-Demo

    Deploys or updates the demo hub and backfills 12 months of data.

    .EXAMPLE
    ./Deploy-Demo -Version v15

    Deploys the versioned instance for v15 with one month of data, then stops its cluster.

    .LINK
    https://github.com/microsoft/finops-toolkit/blob/dev/src/scripts/README.md#-deploy-demo
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]
    $Version,

    [string]
    $Subscription = 'FTK Prod',

    [string]
    $ResourceGroup,

    [string]
    $Location = 'westus',

    [string[]]
    $Scope,

    [int]
    $Months,

    [switch]
    $Check,

    [switch]
    $SkipBackfill,

    [switch]
    $Stop,

    [switch]
    $Build
)

$ErrorActionPreference = 'Stop'

$toolkitVersion = & "$PSScriptRoot/Get-Version.ps1"
$isVersioned = [bool]$Version
$name = if ($isVersioned) { "ftk-demo-$($Version.TrimStart('v') -replace '^', 'v')" } else { 'ftk-demo' }
if (-not $ResourceGroup) { $ResourceGroup = $name }
if (-not $Months) { $Months = if ($isVersioned) { 1 } else { 12 } }
if (-not $PSBoundParameters.ContainsKey('Stop')) { $Stop = $isVersioned }

#region Helpers

<#
    .SYNOPSIS
    Selects the subscription to work in, by name or ID.
#>
function Set-DemoSubscription([string] $NameOrId)
{
    $context = Get-AzContext
    if (-not $context)
    {
        throw 'Not signed in to Azure. Run Connect-AzAccount, then run this command again.'
    }

    if ($context.Subscription.Name -eq $NameOrId -or $context.Subscription.Id -eq $NameOrId)
    {
        return $context
    }

    $subscription = Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $NameOrId -or $_.Id -eq $NameOrId } | Select-Object -First 1
    if (-not $subscription)
    {
        $available = (Get-AzSubscription -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ', '
        throw "Subscription '$NameOrId' not found in tenant $($context.Tenant.Id). Available: $available"
    }

    Write-Host "Using subscription $($subscription.Name) ($($subscription.Id))"
    return Set-AzContext -SubscriptionObject $subscription
}

<#
    .SYNOPSIS
    Reports the hub version and the months of data an instance holds.

    .DESCRIPTION
    The version is read from the config container, which every hub writes when it deploys. The
    months come from the folders in the ingestion container, which are named by month.
#>
function Get-DemoState([string] $HubName, [string] $ResourceGroupName)
{
    $state = [PSCustomObject]@{
        Deployed = $false
        Version  = $null
        Months   = @()
        Storage  = $null
        Cluster  = $null
    }

    $storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue `
    | Where-Object { $_.StorageAccountName -like "$($HubName -replace '[^a-z0-9]', '')*" -or $_.Tags['cm-resource-parent'] } `
    | Select-Object -First 1
    if (-not $storage) { return $state }

    $state.Deployed = $true
    $state.Storage = $storage.StorageAccountName
    $state.Cluster = (Get-AzKustoCluster -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1)

    $context = $storage.Context
    $settings = Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $context -ErrorAction SilentlyContinue
    if ($settings)
    {
        $file = New-TemporaryFile
        try
        {
            Get-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -Destination $file -Context $context -Force | Out-Null
            $state.Version = (Get-Content $file -Raw | ConvertFrom-Json).version
        }
        finally { Remove-Item $file -Force -ErrorAction SilentlyContinue }
    }

    # Ingested data is stored in folders named by month, so the folder names are the months of data
    $months = New-Object System.Collections.Generic.HashSet[string]
    Get-AzStorageBlob -Container 'ingestion' -Context $context -MaxCount 5000 -ErrorAction SilentlyContinue `
    | ForEach-Object {
        if ($_.Name -match '(?<month>20\d{2}[-/]?(0[1-9]|1[0-2]))') { $null = $months.Add(($Matches.month -replace '[-/]', '')) }
    }
    $state.Months = @($months | Sort-Object)

    return $state
}

#endregion Helpers

#region Check

$context = Set-DemoSubscription $Subscription
Write-Host ''
Write-Host "FinOps hub demo instance $name" -ForegroundColor White
Write-Host "  Subscription  $($context.Subscription.Name)"
Write-Host "  Resource group $ResourceGroup"

$state = Get-DemoState $name $ResourceGroup
$thisMonth = (Get-Date).ToString('yyyyMM')
$lastMonth = (Get-Date).AddMonths(-1).ToString('yyyyMM')

if ($state.Deployed)
{
    $hasCurrent = $state.Months -contains $thisMonth -or $state.Months -contains $lastMonth
    $isCurrentVersion = $state.Version -eq $toolkitVersion
    Write-Host "  $(if ($isCurrentVersion) { '✅' } else { '⏳' }) Version       $($state.Version ?? 'unknown') (toolkit is $toolkitVersion)"
    Write-Host "  $(if ($hasCurrent) { '✅' } else { '⏳' }) Data          $($state.Months.Count) month$(if ($state.Months.Count -ne 1) { 's' })$(if ($state.Months) { ": $($state.Months[0]) to $($state.Months[-1])" })"
    if ($state.Cluster) { Write-Host "  ℹ️ Data Explorer $($state.Cluster.Name) ($($state.Cluster.State))" }
}
else
{
    Write-Host '  ⏳ Not deployed'
}
Write-Host ''

if ($Check)
{
    if (-not $state.Deployed) { throw "$name is not deployed. Run ./Deploy-Demo to create it." }

    $problems = New-Object System.Collections.Generic.List[string]
    if ($state.Version -ne $toolkitVersion) { $problems.Add("is on $($state.Version ?? 'an unknown version') but the toolkit is $toolkitVersion. Demo reports built from it would use an older hub.") }
    if (-not ($state.Months -contains $thisMonth -or $state.Months -contains $lastMonth)) { $problems.Add("has no data for $thisMonth or $lastMonth, so demo reports would ship with an empty current month.") }

    if ($problems.Count -gt 0)
    {
        throw "$name isn't ready for a release. It $($problems -join ' It ')`nRun ./Deploy-Demo to update it."
    }

    Write-Host "✅ $name is ready to build demo reports from." -ForegroundColor Green
    return
}

#endregion Check

#region Deploy

if (-not $Scope) { $Scope = @("/subscriptions/$($context.Subscription.Id)") }

$parameters = @{
    hubName                           = $name
    dataExplorerName                  = $name
    dataExplorerSku                   = if ($isVersioned) { 'Dev(No SLA)_Standard_E2a_v4' } else { 'Standard_E2ads_v5' }
    enableManagedExports              = $true
    scopesToMonitor                   = $Scope
    ingestionRetentionInMonths        = $Months
    dataExplorerFinalRetentionInMonths = $Months
}

Write-Host "Deploying $name with $Months month$(if ($Months -ne 1) { 's' }) of data for $($Scope -join ', ')..."

if ($PSCmdlet.ShouldProcess($name, "Deploy FinOps hub to $ResourceGroup"))
{
    & "$PSScriptRoot/Deploy-Toolkit.ps1" 'finops-hub' -ResourceGroup $ResourceGroup -Location $Location -Parameters $parameters -Build:$Build -WhatIf:$WhatIfPreference
}

if ($WhatIfPreference) { return }

#endregion Deploy

#region Backfill

if ($SkipBackfill)
{
    Write-Host 'Skipping exports.'
}
else
{
    $state = Get-DemoState $name $ResourceGroup
    if (-not $state.Storage) { throw "Could not find the storage account for $name after deploying." }
    $storageId = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $state.Storage).Id

    foreach ($target in $Scope)
    {
        $exportName = "$name-focus"
        Write-Host "Backfilling $Months month$(if ($Months -ne 1) { 's' }) of FOCUS 1.2 data for $target..."

        if ($PSCmdlet.ShouldProcess($target, "Create and run the $exportName export"))
        {
            New-FinOpsCostExport `
                -Name $exportName `
                -Scope $target `
                -Dataset 'FocusCost' `
                -DatasetVersion '1.2' `
                -Monthly `
                -StorageAccountId $storageId `
                -StorageContainer 'msexports' `
                -Backfill $Months `
                -Execute `
                -ErrorAction Stop `
            | Out-Null
        }
    }

    Write-Host 'Exports run. Data takes a while to ingest, so check back before building demo reports:'
    Write-Host "     ./Deploy-Demo$(if ($isVersioned) { " -Version $Version" }) -Check" -ForegroundColor Cyan
}

#endregion Backfill

#region Stop

# A versioned instance is only there to open old reports, so its cluster doesn't need to keep
# running. It can't be stopped here because data is still ingesting when this command finishes.
if ($Stop -and $state.Cluster)
{
    Write-Host ''
    Write-Host "  Stop $($state.Cluster.Name) once ingestion finishes so this instance costs almost nothing to keep:" -ForegroundColor Yellow
    Write-Host "     Stop-AzKustoCluster -ResourceGroupName $ResourceGroup -Name $($state.Cluster.Name)" -ForegroundColor Cyan
}

#endregion Stop

Write-Host ''
Write-Host "✅ $name deployed" -ForegroundColor Green
