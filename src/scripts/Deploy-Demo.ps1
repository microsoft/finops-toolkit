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

    - "ftk-demo" is the current demo hub. It holds 36 months of data and is what demo reports are
      built from. Its Data Explorer cluster is "ftk-demo-hub", because cluster names are unique across
      Azure and "ftk-demo" is taken.
    - "ftk-demo-v{NN}" (for example, ftk-demo-v07 or ftk-demo-v14) is a versioned instance kept for
      opening reports from that release. The resource group, hub, and Data Explorer cluster all use
      the same name. The version being built is deployed from source; older releases use the released
      template through the FinOps toolkit module. Recent releases keep 3 months of data and older ones
      keep 1 month.

    Every instance uses a dev/test Data Explorer SKU and stops itself when idle, so an instance
    nobody is using costs almost nothing to keep around.

    One call does everything an instance needs: it deploys the hub, gives it access to the scopes,
    sets up the exports, loads history for a new instance, turns on auto-stop, and waits until
    current data has been ingested. It is safe to run again, which updates the instance.

    .PARAMETER Version
    Optional. Deploys the versioned instance for a release (for example, "v15", "v07", or "v0.7") instead of the current demo hub.

    .PARAMETER Subscription
    Optional. Name or ID of the subscription to deploy to. Default = "FTK Prod".

    .PARAMETER ResourceGroup
    Optional. Name of the resource group. Default = the instance name.

    .PARAMETER Location
    Optional. Azure region to deploy to. Default = "westus".

    .PARAMETER Scope
    Optional. Resource IDs of the scopes to export cost data for. Default = the subscription being deployed to.

    .PARAMETER Retention
    Optional. Number of months of data the hub keeps. Default = 36 for the current demo hub, 3 for the current and previous 3 releases, 1 for older releases.

    .PARAMETER DataExplorerSku
    Optional. Data Explorer SKU. Use a dev/test SKU, because production SKUs cost too much for demo instances. Default = "Dev(No SLA)_Standard_D11_v2".

    .PARAMETER WaitMinutes
    Optional. Minutes to wait for data to be ingested before finishing. Default = 30. Use 0 to not wait.

    .PARAMETER Backfill
    Optional. Number of months of history to load. Default = the retention, loaded once: it is skipped when the history export already exists. Use 0 to skip.


    .PARAMETER Build
    Optional. Builds the templates before deploying. Default = false.

    .PARAMETER WhatIf
    Optional. Shows the instance name, version, and current state, and what would be deployed, without changing anything. Default = false.

    .EXAMPLE
    ./Deploy-Demo

    Deploys or updates the demo hub, loads history if it is new, and waits until current data is ingested.

    .EXAMPLE
    ./Deploy-Demo -Version v14

    Does the same for the v14 instance, using the released v14 template.

    .EXAMPLE
    ./Deploy-Demo -Version v15 -Backfill 1

    Loads 1 month of history instead of the default for a new instance.
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

    [int]
    $WaitMinutes = 30,

    [switch]
    $Build
)

$ErrorActionPreference = 'Stop'

$toolkitVersion = & "$PSScriptRoot/Get-Version.ps1"
$currentMajor = [int]($toolkitVersion -replace '^(\d+).*', '$1')
$isVersioned = [bool]$Version

# Instances are named ftk-demo-v{NN} (v07, v14, v15) so they sort and read the same way. Releases before
# v12 were 0.x, so v0.7, v07, and v7 are all the same release.
$useLocalBuild = $true
if ($isVersioned)
{
    $number = if ($Version -match '^v?0\.(\d+)$' -or $Version -match '^v?(\d+)$') { [int]$Matches[1] } else { throw "Version '$Version' isn't valid. Use a release like v14, v07, or v0.7." }
    $name = 'ftk-demo-v{0:D2}' -f $number
    $releaseVersion = if ($number -le 11) { "0.$number" } else { "$number" }

    # The version being built is deployed from source. Anything older is a released template.
    $useLocalBuild = $number -ge $currentMajor
}
else { $name = 'ftk-demo' }

if (-not $ResourceGroup) { $ResourceGroup = $name }

# Data Explorer cluster names are unique across Azure and "ftk-demo" is already taken, so the current hub's
# cluster is ftk-demo-hub. Versioned instances use the instance name.
$clusterName = if ($isVersioned) { $name } else { "$name-hub" }

# The current demo hub keeps three years. Recent releases keep 3 months and older ones 1 month, to limit cost.
if (-not $Retention) { $Retention = if (-not $isVersioned) { 36 } elseif ($number -ge $currentMajor - 3) { 3 } else { 1 } }

# Dev/test SKUs only. Production SKUs cost too much for instances nobody is using.
if (-not $DataExplorerSku) { $DataExplorerSku = 'Dev(No SLA)_Standard_D11_v2' }

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
    return Set-AzContext -SubscriptionObject $subscription -WhatIf:$false
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

    # Only "it isn't there" means not deployed, or a new instance. Any other failure (network, sign-in,
    # throttling) is thrown so the caller can retry: a healthy hub that can't be read must not look new,
    # because a new instance gets its whole history loaded.
    $isMissing = { param($e) $e.Exception.Message -match 'NotFound|does not exist|Can not find|could not be found' }

    try { $accounts = @(Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction Stop) }
    catch { if (& $isMissing $_) { return $state }; throw }

    $storage = $accounts `
    | Where-Object { $_.StorageAccountName -like "$($HubName -replace '[^a-z0-9]', '')*" -or $_.Tags['cm-resource-parent'] } `
    | Select-Object -First 1
    if (-not $storage) { return $state }

    $state.Deployed = $true
    $state.Storage = $storage.StorageAccountName
    $state.Cluster = try { Get-AzKustoCluster -ResourceGroupName $ResourceGroupName -ErrorAction Stop | Select-Object -First 1 } catch { if (& $isMissing $_) { $null } else { throw } }

    $context = $storage.Context
    $settings = try { Get-AzStorageBlob -Container 'config' -Blob 'settings.json' -Context $context -ErrorAction Stop } catch { if (& $isMissing $_) { $null } else { throw } }
    if ($settings)
    {
        $file = New-TemporaryFile -WhatIf:$false
        try
        {
            # Reading state changes nothing, so it still runs under -WhatIf
            Get-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -Destination $file -Context $context -Force -WhatIf:$false | Out-Null
            $state.Version = (Get-Content $file -Raw | ConvertFrom-Json).version
        }
        finally { Remove-Item $file -Force -ErrorAction SilentlyContinue -WhatIf:$false }
    }

    # Ingested data is stored in folders named by month, so the folder names are the months of data
    $months = New-Object System.Collections.Generic.HashSet[string]
    # Blobs come back 5,000 at a time in name order, so page through all of them: on a hub with a
    # year of data the newest months can sit past the first page.
    $token = $null
    do
    {
        $page = @(try { Get-AzStorageBlob -Container 'ingestion' -Context $context -MaxCount 5000 -ContinuationToken $token -ErrorAction Stop } catch { if (& $isMissing $_) { @() } else { throw } })
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
    $start = Invoke-DemoRetry { Invoke-AzRestMethod -Method POST -Path "$FactoryId/pipelines/$Pipeline/createRun?$api" -Payload $payload }
    if ($start.StatusCode -eq 404) { return 'missing' }
    if ($start.StatusCode -ne 200) { return "not started ($($start.StatusCode))" }

    $runId = ($start.Content | ConvertFrom-Json).runId
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do
    {
        Start-Sleep -Seconds 10
        $status = ((Invoke-DemoRetry { Invoke-AzRestMethod -Method GET -Path "$FactoryId/pipelineruns/${runId}?$api" }).Content | ConvertFrom-Json).status
    }
    while (($status -in 'Queued', 'InProgress') -and (Get-Date) -lt $deadline)

    return $status
}

<#
    .SYNOPSIS
    Returns why an instance isn't ready to build demo reports from. Empty when it is ready.
#>
function Get-DemoProblem($State, [string] $InstanceName, [string] $ExpectedVersion, [string[]] $RecentMonths)
{
    if (-not $State.Deployed) { return @("$InstanceName is not deployed.") }

    # Releases are listed as 12 but saved as 12.0
    $normalize = { param($v) $v -replace '^(\d+)$', '$1.0' }
    $problems = New-Object System.Collections.Generic.List[string]
    if ((& $normalize $State.Version) -ne (& $normalize $ExpectedVersion))
    {
        $problems.Add("is on $($State.Version ?? 'an unknown version') but should be on $ExpectedVersion.")
    }
    if (-not ($State.Months | Where-Object { $_ -in $RecentMonths }))
    {
        $problems.Add("has no data for $($RecentMonths -join ' or '), so demo reports would ship with an empty current month.")
    }
    return @($problems)
}

<#
    .SYNOPSIS
    Runs a command again after a short wait when it fails, so a brief network outage doesn't end a run that takes a long time.
#>
function Invoke-DemoRetry([scriptblock] $Action, [int] $Attempts = 20, [int] $DelaySeconds = 30)
{
    for ($attempt = 1; ; $attempt++)
    {
        try { return & $Action }
        catch
        {
            $message = $_.Exception.Message -replace '\s+', ' '

            # Waiting won't fix a permission or sign-in problem, so don't make it look like a hang
            if ($attempt -ge $Attempts -or $message -match 'AuthorizationFailed|AuthenticationFailed|Forbidden|does not have authorization') { throw }

            Write-Host "  ⏳ Azure call failed ($message). Trying again in $DelaySeconds seconds (attempt $attempt of $Attempts)..." -ForegroundColor Yellow
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

<#
    .SYNOPSIS
    Waits for every deployment in a resource group to finish, then fails if any of them failed since the given time.

    .DESCRIPTION
    Creating a Data Explorer cluster takes a long time, and the connection that polls the deployment can drop
    while Azure keeps working. This picks the deployment back up instead of leaving it running unattended.
#>
function Wait-DemoDeployment([string] $ResourceGroupName, [datetime] $Since, [int] $TimeoutMinutes = 90)
{
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while (@(Invoke-DemoRetry { Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName | Where-Object { $_.ProvisioningState -in 'Running', 'Accepted' } }).Count -gt 0)
    {
        if ((Get-Date) -ge $deadline) { throw "Deployment to $ResourceGroupName is still running after $TimeoutMinutes minutes." }
        Start-Sleep -Seconds 30
    }

    $failed = @(Invoke-DemoRetry { Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName | Where-Object { $_.ProvisioningState -eq 'Failed' -and $_.Timestamp -ge $Since.ToUniversalTime() } })
    if ($failed.Count -gt 0) { throw "Deployment to $ResourceGroupName failed ($($failed.DeploymentName -join ', ')). See the deployments in the portal for details." }
}
#endregion Helpers

#region State

$context = Set-DemoSubscription $Subscription
Write-Host ''
Write-Host "FinOps hub demo instance $name" -ForegroundColor White
Write-Host "  Subscription  $($context.Subscription.Name)"
Write-Host "  Resource group $ResourceGroup"

$state = Invoke-DemoRetry { Get-DemoState $name $ResourceGroup }
$thisMonth = (Get-Date).ToString('yyyyMM')
$lastMonth = (Get-Date).AddMonths(-1).ToString('yyyyMM')


$expectedVersion = if ($useLocalBuild) { $toolkitVersion } else { $releaseVersion }

if ($state.Deployed)
{
    $hasCurrent = $state.Months -contains $thisMonth -or $state.Months -contains $lastMonth
    $isCurrentVersion = -not (Get-DemoProblem $state $name $expectedVersion @($thisMonth) | Where-Object { $_ -like 'is on*' })
    Write-Host "  $(if ($isCurrentVersion) { '✅' } else { '⏳' }) Version       $($state.Version ?? 'unknown') (expected $expectedVersion)"
    Write-Host "  $(if ($hasCurrent) { '✅' } else { '⏳' }) Data          $($state.Months.Count) month$(if ($state.Months.Count -ne 1) { 's' })$(if ($state.Months) { ": $($state.Months[0]) to $($state.Months[-1])" })"
    if ($state.Cluster) { Write-Host "  ℹ️ Data Explorer $($state.Cluster.Name) ($($state.Cluster.State))" }
}
else
{
    Write-Host '  ⏳ Not deployed'
}
Write-Host ''

#endregion State

#region Deploy

if (-not $Scope) { $Scope = @("/subscriptions/$($context.Subscription.Id)") }

Write-Host "Deploying $name ($(if ($useLocalBuild) { "version $toolkitVersion, built from source" } else { "released version $releaseVersion" })) keeping $Retention month$(if ($Retention -ne 1) { 's' }) of data for $($Scope -join ', ')..."

if ($PSCmdlet.ShouldProcess($name, "Deploy FinOps hub to $ResourceGroup"))
{
    $deployStarted = Get-Date
    try
    {
        if ($useLocalBuild)
        {
            $parameters = @{
                hubName                            = $name
                dataExplorerName                   = $clusterName
                dataExplorerSku                    = $DataExplorerSku
                enableManagedExports               = $true
                scopesToMonitor                    = $Scope
                ingestionRetentionInMonths         = $Retention
                dataExplorerFinalRetentionInMonths = $Retention
            }
            & "$PSScriptRoot/Deploy-Toolkit.ps1" 'finops-hub' -ResourceGroup $ResourceGroup -Location $Location -Parameters $parameters -Build:$Build -WhatIf:$WhatIfPreference
        }
        else
        {
            # Released versions come from the FinOps toolkit module, which downloads the released template
            if (-not (Get-Command Deploy-FinOpsHub -ErrorAction SilentlyContinue)) { Import-Module "$PSScriptRoot/../powershell/FinOpsToolkit.psm1" -Force }
            Deploy-FinOpsHub `
                -Name $name `
                -ResourceGroupName $ResourceGroup `
                -Location $Location `
                -Version $releaseVersion `
                -DataExplorerName $clusterName `
                -DataExplorerSku $DataExplorerSku `
                -ScopesToMonitor $Scope `
                -IngestionRetentionInMonths $Retention `
                -DataExplorerFinalRetentionInMonths $Retention `
                -EnableManagedExports `
                -WhatIf:$WhatIfPreference `
            | Out-Null
        }
    }
    catch
    {
        # The connection can drop while Azure keeps deploying. If it's still running, wait for it rather than stopping.
        $failure = $_
        $active = try { @(Invoke-DemoRetry -Attempts 4 { Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup | Where-Object { $_.ProvisioningState -in 'Running', 'Accepted' } }) } catch { @() }
        if ($active.Count -eq 0 -or $WhatIfPreference) { throw $failure }
        Write-Warning "Lost the connection while deploying ($($failure.Exception.Message -replace '\s+', ' ')). The deployment is still running, so waiting for it to finish."
        Wait-DemoDeployment $ResourceGroup $deployStarted
    }
}

if ($WhatIfPreference) { return }

#endregion Deploy

#region Access

# Managed exports create and run Cost Management exports as the hub's Data Factory identity, so it
# needs access to every scope. Without it nothing is exported, whatever the deployment says.
$factory = Invoke-DemoRetry { Get-AzResource -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DataFactory/factories' | Select-Object -First 1 }
if (-not $factory) { throw "Could not find the Data Factory for $name after deploying." }
$principalId = Invoke-DemoRetry { (Get-AzResource -ResourceId $factory.ResourceId).Identity.PrincipalId }

# A single scope is saved to settings.json as an object instead of a list, which export setup fails to read
$storageName = (Invoke-DemoRetry { Get-DemoState $name $ResourceGroup }).Storage
$storageAccount = Invoke-DemoRetry { Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $storageName }
$settingsFile = New-TemporaryFile -WhatIf:$false
try
{
    Invoke-DemoRetry { Get-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -Destination $settingsFile -Context $storageAccount.Context -Force | Out-Null }
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    if ($settings.scopes -and $settings.scopes -isnot [array] -and $PSCmdlet.ShouldProcess('settings.json', 'Save scopes as a list'))
    {
        $settings.scopes = @($settings.scopes)
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
        Invoke-DemoRetry { Set-AzStorageBlobContent -Container 'config' -Blob 'settings.json' -File $settingsFile -Context $storageAccount.Context -Properties @{ ContentType = 'application/json' } -Force | Out-Null }
    }
}
finally { Remove-Item $settingsFile -Force -ErrorAction SilentlyContinue }

$granted = $false

# Creating an export means granting the export access to the storage account, so the hub's identity needs to be
# able to assign roles there. Released templates don't all grant it (v14 doesn't), so make sure it's in place.
$canAssign = 'Role Based Access Control Administrator', 'User Access Administrator' | ForEach-Object {
    $roleName = $_
    Invoke-DemoRetry { Get-AzRoleAssignment -ObjectId $principalId -Scope $storageAccount.Id -RoleDefinitionName $roleName -ErrorAction Stop } | Where-Object { $storageAccount.Id -eq $_.Scope -or $storageAccount.Id -like "$($_.Scope)/*" }
} | Where-Object { $_ }
if (-not $canAssign -and $PSCmdlet.ShouldProcess($storageAccount.StorageAccountName, "Grant Role Based Access Control Administrator to $($factory.Name)"))
{
    Invoke-DemoRetry { try { New-AzRoleAssignment -ObjectId $principalId -Scope $storageAccount.Id -RoleDefinitionName 'Role Based Access Control Administrator' -ObjectType ServicePrincipal | Out-Null } catch { if ($_.Exception.Message -notmatch 'already exists') { throw } } }
    $granted = $true
}

foreach ($target in $Scope)
{
    if ($target -notmatch '^/subscriptions/|^/providers/Microsoft\.Management/managementGroups/')
    {
        Write-Warning "Can't grant access to $target from here. Give $($factory.Name) the Cost Management Contributor role on it, or nothing is exported for that scope."
        continue
    }

    $role = Invoke-DemoRetry { Get-AzRoleAssignment -ObjectId $principalId -Scope $target -RoleDefinitionName 'Cost Management Contributor' -ErrorAction Stop } | Where-Object { $target -eq $_.Scope -or $target -like "$($_.Scope)/*" }
    if ($role) { continue }

    if ($PSCmdlet.ShouldProcess($target, "Grant Cost Management Contributor to $($factory.Name)"))
    {
        Invoke-DemoRetry { try { New-AzRoleAssignment -ObjectId $principalId -Scope $target -RoleDefinitionName 'Cost Management Contributor' -ObjectType ServicePrincipal | Out-Null } catch { if ($_.Exception.Message -notmatch 'already exists') { throw } } }
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
        if ($status -eq 'missing') { Write-Verbose "$($step.Pipeline) isn't in this version. It creates exports from settings.json on its own." }
        elseif ($status -ne 'Succeeded') { Write-Warning "$($step.Pipeline) $($step.Body.Values) ended as '$status'. Check the run in Data Factory before relying on this instance." }
    }
}

#endregion Access

#region Exports

# Confirm exports exist, since a deployment can succeed without any
if (-not $WhatIfPreference)
{
    $exports = foreach ($target in $Scope)
    {
        ((Invoke-DemoRetry { Invoke-AzRestMethod -Method GET -Path "$target/providers/Microsoft.CostManagement/exports?api-version=2023-07-01-preview" }).Content | ConvertFrom-Json).value
    }
    # The current hub's name is the start of every versioned name (ftk-demo-v07-...), so those are excluded
    $exports = @($exports | Where-Object { $_.name -like "$name-*" -and ($isVersioned -or $_.name -notmatch "^$name-v\d") })
    if ($exports.Count -eq 0) { Write-Warning "No exports were created for $name. Nothing will be ingested until they exist." }
    else { Write-Host "✅ $($exports.Count) export$(if ($exports.Count -ne 1) { 's' }): $(($exports.name | Sort-Object) -join ', ')" -ForegroundColor Green }
}

#endregion Exports

#region AutoStop

# The hub template leaves auto-stop off and resets it on every deployment, so it's turned on here.
# Idle clusters stop on their own, which keeps unused instances from running up cost.
$cluster = Invoke-DemoRetry { Get-AzKustoCluster -ResourceGroupName $ResourceGroup -ErrorAction Stop | Select-Object -First 1 }
if (-not $cluster) { Write-Warning "No Data Explorer cluster found in $ResourceGroup, so auto-stop wasn't set." }
elseif ($PSCmdlet.ShouldProcess($cluster.Name, 'Turn on auto-stop'))
{
    $clusterPath = "$($cluster.Id)?api-version=2023-08-15"
    $null = Invoke-DemoRetry { Invoke-AzRestMethod -Method PATCH -Path $clusterPath -Payload '{"properties":{"enableAutoStop":true}}' }

    # The change applies in the background, so wait for it before reporting a problem
    $deadline = (Get-Date).AddMinutes(3)
    do
    {
        Start-Sleep -Seconds 10
        $autoStop = ((Invoke-DemoRetry { Invoke-AzRestMethod -Method GET -Path $clusterPath }).Content | ConvertFrom-Json).properties.enableAutoStop
    }
    while (-not $autoStop -and (Get-Date) -lt $deadline)
    if (-not $autoStop) { Write-Warning "Could not turn on auto-stop for $($cluster.Name). Turn it on in the portal under Configurations." }
}

#endregion AutoStop

#region Backfill

# Managed exports only cover the current and last month, so an instance needs its history loaded once. The history
# export (<name>-focus) marks that it was requested, so a rerun doesn't ask again, even while the data is still being
# ingested or after an interrupted first run. -Backfill sets the months explicitly, and 0 skips it.
$backfillMonths = if ($PSBoundParameters.ContainsKey('Backfill')) { $Backfill } else { $Retention }
if (-not $backfillMonths)
{
    Write-Host 'Skipping history because -Backfill is 0. Exports keep the current months up to date.'
}
else
{
    # Backfill uses the FinOps toolkit module, which the source build path doesn't otherwise load
    if (-not (Get-Command New-FinOpsCostExport -ErrorAction SilentlyContinue)) { Import-Module "$PSScriptRoot/../powershell/FinOpsToolkit.psm1" -Force }

    $state = Invoke-DemoRetry { Get-DemoState $name $ResourceGroup }
    if (-not $state.Storage) { throw "Could not find the storage account for $name after deploying." }
    $storageId = (Invoke-DemoRetry { Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $state.Storage }).Id

    foreach ($target in $Scope)
    {
        $exportName = "$name-focus"

        # No data yet doesn't always mean nothing was asked for: ingestion can take a while. If the history export
        # already exists, rerunning would queue every month again, so wait for what's already on its way.
        if (-not $PSBoundParameters.ContainsKey('Backfill'))
        {
            $existing = Invoke-DemoRetry { Invoke-AzRestMethod -Method GET -Path "$target/providers/Microsoft.CostManagement/exports/${exportName}?api-version=2023-07-01-preview" }
            if ($existing.StatusCode -eq 200)
            {
                Write-Host "History for $target was already requested, so it isn't requested again. Waiting for it to be ingested."
                continue
            }
        }

        Write-Host "Loading $backfillMonths month$(if ($backfillMonths -ne 1) { 's' }) of history for $target..."

        if ($PSCmdlet.ShouldProcess($target, "Create and run the $exportName export"))
        {
            New-FinOpsCostExport `
                -Name $exportName `
                -Scope $target `
                -Dataset 'FocusCost' `
                -Monthly `
                -StorageAccountId $storageId `
                -StorageContainer 'msexports' `
                -Backfill $backfillMonths `
                -Execute `
                -ErrorAction Stop `
            | Out-Null

            # The backfill runs are queued, so turn the export's schedule off. Left on, it would load last month
            # a second time every month, on top of the hub's own monthly export.
            $exportPath = "$target/providers/Microsoft.CostManagement/exports/${exportName}?api-version=2023-07-01-preview"
            $export = (Invoke-DemoRetry { Invoke-AzRestMethod -Method GET -Path $exportPath }).Content | ConvertFrom-Json
            $export.properties.schedule.status = 'Inactive'
            $update = Invoke-DemoRetry { Invoke-AzRestMethod -Method PUT -Path $exportPath -Payload (@{ eTag = $export.eTag; properties = $export.properties } | ConvertTo-Json -Depth 20) }
            if ($update.StatusCode -ne 200) { Write-Warning "Could not turn off the schedule for $exportName ($($update.StatusCode)). Turn it off in Cost Management, or last month loads twice." }
        }
    }

}

#endregion Backfill

#region Ready

# Everything above queues work in Cost Management and Data Factory. Wait for the data to land, so the
# instance is ready to use when this finishes. -WaitMinutes 0 skips the wait.
if (-not $WhatIfPreference)
{
    $deadline = (Get-Date).AddMinutes($WaitMinutes)
    while ($true)
    {
        $state = Invoke-DemoRetry { Get-DemoState $name $ResourceGroup }
        $problems = @(Get-DemoProblem $state $name $expectedVersion @($thisMonth, $lastMonth))
        if ($problems.Count -eq 0 -or (Get-Date) -ge $deadline) { break }

        Write-Host "  ⏳ Waiting for data to be ingested ($([int]($deadline - (Get-Date)).TotalMinutes) min left)..."
        Start-Sleep -Seconds 60
    }

    Write-Host ''
    if ($problems.Count -eq 0)
    {
        Write-Host "✅ $name is deployed and ready ($($state.Months.Count) month$(if ($state.Months.Count -ne 1) { 's' }) of data: $($state.Months[0]) to $($state.Months[-1]))" -ForegroundColor Green
    }
    else
    {
        Write-Warning "$name is deployed but isn't ready yet. It $($problems -join ' It ') Ingestion can take a while, so run ./Deploy-Demo$(if ($isVersioned) { " -Version $Version" }) again to keep waiting."
    }
}
# Demo reports are saved with the hub's storage URL, so they refresh from the wrong place if the hub is ever recreated
if (-not $isVersioned -and -not $WhatIfPreference -and $state.Storage)
{
    $models = Get-ChildItem "$PSScriptRoot/../power-bi/*/Shared.Dataset/definition/expressions.tmdl" -ErrorAction SilentlyContinue
    $expectedUrl = "https://$($state.Storage).dfs.core.windows.net/ingestion"
    foreach ($model in $models)
    {
        $text = Get-Content $model -Raw
        $relative = Resolve-Path $model -Relative
        if ($text -notmatch [regex]::Escape("expression 'Storage URL' = `"$expectedUrl`""))
        {
            Write-Warning "$relative doesn't use this hub's storage URL. Set 'Storage URL' to $expectedUrl (and 'Cluster URL' to $($state.Cluster.Name).$Location) so demo reports refresh from this hub."
        }

        # The demo data filter only applies to storage accounts in its list. Without the hub in it, the
        # Governance and Usage optimization demo reports would query every subscription the releaser can read.
        if ($text -notmatch ('"' + [regex]::Escape($state.Storage) + '"'))
        {
            Write-Warning "$relative doesn't list $($state.Storage) in the ftk_DemoFilter storage account list. Add it, and the subscriptions the hub monitors, or demo reports include data from other subscriptions."
        }
    }
}

#endregion Ready
