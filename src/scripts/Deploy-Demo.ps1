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
      one month of data. Every cluster stops itself when idle, so an instance nobody is using
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

    .PARAMETER Retention
    Optional. Number of months of data the hub keeps. Default = 12 for the current demo hub, 1 for a versioned instance.

    .PARAMETER DataExplorerSku
    Optional. Data Explorer SKU. Use this when a region has no capacity for the default (InsufficientResourcesForSubscription). Default = "Standard_E2ads_v5" for the current demo hub, "Dev(No SLA)_Standard_E2a_v4" for a versioned instance.

    .PARAMETER Backfill
    Optional. Number of months of history to load. Backfilling is a one-time task for a new instance, so nothing is backfilled unless this is specified.

    .PARAMETER Check
    Optional. Reports whether the demo hub is ready for a release without changing anything. Default = false.


    .PARAMETER Build
    Optional. Builds the templates before deploying. Default = false.

    .PARAMETER WhatIf
    Optional. Validates the deployment without making changes. Default = false.

    .EXAMPLE
    ./Deploy-Demo -Check

    Reports whether the demo hub is on the current version and has data for this month.

    .EXAMPLE
    ./Deploy-Demo

    Deploys or updates the demo hub. Exports keep running on their own, so nothing is backfilled.

    .EXAMPLE
    ./Deploy-Demo -Backfill 12

    Deploys the demo hub and loads 12 months of history. Only needed for a new instance.

    .EXAMPLE
    ./Deploy-Demo -Version v15 -Backfill 1

    Deploys the versioned instance for v15 with one month of data.

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
    $Retention,

    [string]
    $DataExplorerSku,

    [int]
    $Backfill,

    [switch]
    $Check,


    [switch]
    $Build
)

$ErrorActionPreference = 'Stop'

$toolkitVersion = & "$PSScriptRoot/Get-Version.ps1"
$isVersioned = [bool]$Version
$name = if ($isVersioned) { "ftk-demo-$($Version.TrimStart('v') -replace '^', 'v')" } else { 'ftk-demo' }
if (-not $ResourceGroup) { $ResourceGroup = $name }
if (-not $Retention) { $Retention = if ($isVersioned) { 1 } else { 12 } }

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
    # Blobs come back 5,000 at a time in name order, so page through all of them: on a hub with a
    # year of data the newest months can sit past the first page.
    $token = $null
    do
    {
        $page = @(Get-AzStorageBlob -Container 'ingestion' -Context $context -MaxCount 5000 -ContinuationToken $token -ErrorAction SilentlyContinue)
        foreach ($blob in $page)
        {
            if ($blob.Name -match '(?<month>20\d{2}[-/]?(0[1-9]|1[0-2]))') { $null = $months.Add(($Matches.month -replace '[-/]', '')) }
        }
        $token = if ($page.Count -gt 0) { $page[-1].ContinuationToken } else { $null }
    }
    while ($null -ne $token)
    $state.Months = @($months | Sort-Object)

    return $state
}

<#
    .SYNOPSIS
    Starts a Data Factory pipeline and waits for it to finish, returning its final status.
#>
function Invoke-DemoPipeline([string] $FactoryId, [string] $Pipeline, [hashtable] $Parameters, [int] $TimeoutSeconds = 600)
{
    $api = 'api-version=2018-06-01'
    $payload = if ($Parameters.Count) { $Parameters | ConvertTo-Json -Compress } else { '{}' }
    $start = Invoke-AzRestMethod -Method POST -Path "$FactoryId/pipelines/$Pipeline/createRun?$api" -Payload $payload
    if ($start.StatusCode -ne 200) { return "not started ($($start.StatusCode))" }

    $runId = ($start.Content | ConvertFrom-Json).runId
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do
    {
        Start-Sleep -Seconds 10
        $status = ((Invoke-AzRestMethod -Method GET -Path "$FactoryId/pipelineruns/${runId}?$api").Content | ConvertFrom-Json).status
    }
    while (($status -in 'Queued', 'InProgress') -and (Get-Date) -lt $deadline)

    return $status
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
    dataExplorerSku                   = if ($DataExplorerSku) { $DataExplorerSku } elseif ($isVersioned) { 'Dev(No SLA)_Standard_E2a_v4' } else { 'Standard_E2ads_v5' }
    enableManagedExports              = $true
    scopesToMonitor                   = $Scope
    ingestionRetentionInMonths        = $Retention
    dataExplorerFinalRetentionInMonths = $Retention
}

Write-Host "Deploying $name keeping $Retention month$(if ($Retention -ne 1) { 's' }) of data for $($Scope -join ', ')..."

if ($PSCmdlet.ShouldProcess($name, "Deploy FinOps hub to $ResourceGroup"))
{
    & "$PSScriptRoot/Deploy-Toolkit.ps1" 'finops-hub' -ResourceGroup $ResourceGroup -Location $Location -Parameters $parameters -Build:$Build -WhatIf:$WhatIfPreference
}

if ($WhatIfPreference) { return }

#endregion Deploy

#region Access

# Managed exports create and run Cost Management exports as the hub's Data Factory identity, so it
# needs access to every scope. Without it nothing is exported, whatever the deployment says.
$factory = Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DataFactory/factories' | Select-Object -First 1
if (-not $factory) { throw "Could not find the Data Factory for $name after deploying." }
$principalId = (Get-AzResource -ResourceId $factory.ResourceId).Identity.PrincipalId

# A single scope is saved to settings.json as an object instead of a list, which export setup fails to read
$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup | Select-Object -First 1
$settingsFile = New-TemporaryFile
try
{
    Get-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -Destination $settingsFile -Context $storageAccount.Context -Force | Out-Null
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    if ($settings.scopes -and $settings.scopes -isnot [array] -and $PSCmdlet.ShouldProcess('settings.json', 'Save scopes as a list'))
    {
        $settings.scopes = @($settings.scopes)
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
        Set-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -File $settingsFile -Context $storageAccount.Context -Properties @{ ContentType = 'application/json' } -Force | Out-Null
    }
}
finally { Remove-Item $settingsFile -Force -ErrorAction SilentlyContinue }

$granted = $false
foreach ($target in $Scope)
{
    if ($target -notmatch '^/subscriptions/|^/providers/Microsoft\.Management/managementGroups/')
    {
        Write-Warning "Can't grant access to $target from here. Give $($factory.Name) the Cost Management Contributor role on it, or nothing is exported for that scope."
        continue
    }

    $role = Get-AzRoleAssignment -ObjectId $principalId -Scope $target -RoleDefinitionName 'Cost Management Contributor' -ErrorAction SilentlyContinue
    if ($role) { continue }

    if ($PSCmdlet.ShouldProcess($target, "Grant Cost Management Contributor to $($factory.Name)"))
    {
        New-AzRoleAssignment -ObjectId $principalId -Scope $target -RoleDefinitionName 'Cost Management Contributor' -ObjectType ServicePrincipal | Out-Null
        $granted = $true
    }
}

# The deployment runs its own export setup before the role exists, so run it again now
if ($granted)
{
    Write-Host 'Waiting for the new role to take effect...'
    Start-Sleep -Seconds 60
}

if ($PSCmdlet.ShouldProcess($name, 'Create and run the exports'))
{
    # Create the exports from the hub's scopes, then run them. Each run has to finish before the next starts.
    foreach ($step in @(
            @{ Pipeline = 'config_ConfigureExports'; Body = @{} },
            @{ Pipeline = 'config_StartExportProcess'; Body = @{ Recurrence = 'Daily' } },
            @{ Pipeline = 'config_StartExportProcess'; Body = @{ Recurrence = 'Monthly' } }
        ))
    {
        $status = Invoke-DemoPipeline $factory.ResourceId $step.Pipeline $step.Body
        if ($status -ne 'Succeeded') { Write-Warning "$($step.Pipeline) $($step.Body.Values) ended as '$status'. Check the run in Data Factory before relying on this instance." }
    }
}

#endregion Access

#region AutoStop

# The hub template leaves auto-stop off and resets it on every deployment, so it's turned on here.
# Idle clusters stop on their own, which keeps unused instances from running up cost.
$cluster = Get-AzKustoCluster -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cluster) { Write-Warning "No Data Explorer cluster found in $ResourceGroup, so auto-stop wasn't set." }
elseif ($PSCmdlet.ShouldProcess($cluster.Name, 'Turn on auto-stop'))
{
    $clusterPath = "$($cluster.Id)?api-version=2023-08-15"
    $null = Invoke-AzRestMethod -Method PATCH -Path $clusterPath -Payload '{"properties":{"enableAutoStop":true}}'

    # The change applies in the background, so wait for it before reporting a problem
    $deadline = (Get-Date).AddMinutes(3)
    do
    {
        Start-Sleep -Seconds 10
        $autoStop = ((Invoke-AzRestMethod -Method GET -Path $clusterPath).Content | ConvertFrom-Json).properties.enableAutoStop
    }
    while (-not $autoStop -and (Get-Date) -lt $deadline)
    if (-not $autoStop) { Write-Warning "Could not turn on auto-stop for $($cluster.Name). Turn it on in the portal under Configurations." }
}

#endregion AutoStop

#region Backfill

# Managed exports run on their own once the hub is deployed, so history is only loaded when asked
if (-not $Backfill)
{
    Write-Host 'Exports run on their own. Pass -Backfill to load history, which a new instance needs once.'
}
else
{
    $state = Get-DemoState $name $ResourceGroup
    if (-not $state.Storage) { throw "Could not find the storage account for $name after deploying." }
    $storageId = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $state.Storage).Id

    foreach ($target in $Scope)
    {
        $exportName = "$name-focus"
        Write-Host "Backfilling $Backfill month$(if ($Backfill -ne 1) { 's' }) of FOCUS 1.2 data for $target..."

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
                -Backfill $Backfill `
                -Execute `
                -ErrorAction Stop `
            | Out-Null
        }
    }

    Write-Host 'Exports run. Data takes a while to ingest, so check back before building demo reports:'
    Write-Host "     ./Deploy-Demo$(if ($isVersioned) { " -Version $Version" }) -Check" -ForegroundColor Cyan
}

#endregion Backfill



Write-Host ''
Write-Host "✅ $name deployed" -ForegroundColor Green
