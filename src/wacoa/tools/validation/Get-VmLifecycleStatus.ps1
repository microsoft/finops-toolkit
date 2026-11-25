<#
.SYNOPSIS
    Lists virtual machines and scale sets that run on VM size series with an announced retirement.

.DESCRIPTION
    Read-only. Collects virtual machines and virtual machine scale sets from Azure Resource Graph
    (or reads VM sizes from a CSV file) and matches each size against the retirement table in
    vm-series-retirements.csv.

    Use it during a cost optimization assessment to:
    - Tell the customer which workloads need a modernization plan and by when.
    - Spot reservation recommendations for series that are close to retirement before they are
      added to a savings estimate.

    Sizes that are not in the retirement table are reported as "Not listed". This does not mean
    the series is current: the table only contains series with an announced retirement.

.PARAMETER SubscriptionIds
    Subscriptions to query. If omitted, Azure Resource Graph uses the subscriptions of the current context.

.PARAMETER InputPath
    Optional. CSV file with VM sizes to classify instead of querying Azure (for example an export
    of reservation recommendations). Use -SizeColumn to name the column with the size.

.PARAMETER SizeColumn
    Column that holds the VM size in the -InputPath file. Default: vmSize.

.PARAMETER PowerStateColumn
    Optional column with the power state in the -InputPath file, used to count running VMs. Default: powerState.

.PARAMETER LifecycleDataPath
    Retirement table. Default: vm-series-retirements.csv next to this script.

.PARAMETER OutputPath
    Folder for the output files. Default: current folder.

.PARAMETER AsOfDate
    Date used to calculate the days until retirement. Default: today.

.EXAMPLE
    ./Get-VmLifecycleStatus.ps1 -SubscriptionIds '00000000-0000-0000-0000-000000000000'

.EXAMPLE
    ./Get-VmLifecycleStatus.ps1 -InputPath ./reservation-recommendations.csv -SizeColumn sku

.NOTES
    Requires Az.Accounts and Az.ResourceGraph, an active Connect-AzAccount session and Reader access.
    Outputs: vm-lifecycle-inventory.csv (one row per resource) and vm-lifecycle-summary.csv (one row per series).
#>
[CmdletBinding()]
param(
    [string[]]$SubscriptionIds,
    [string]$InputPath,
    [string]$SizeColumn = 'vmSize',
    [string]$PowerStateColumn = 'powerState',
    [string]$LifecycleDataPath = (Join-Path $PSScriptRoot 'vm-series-retirements.csv'),
    [string]$OutputPath = (Get-Location).Path,
    [datetime]$AsOfDate = (Get-Date).Date
)

$ErrorActionPreference = 'Stop'

function Get-VmSeriesLifecycle {
    param([string]$Size, [object[]]$Table)
    foreach ($entry in $Table) {
        if ($Size -match $entry.SizePattern) { return $entry }
    }
    return $null
}

function Invoke-GraphQuery {
    param([string]$Query, [string[]]$Subscriptions)
    $rows = New-Object System.Collections.Generic.List[object]
    $skipToken = $null
    do {
        $params = @{ Query = $Query; First = 1000 }
        if ($Subscriptions) { $params.Subscription = $Subscriptions }
        if ($skipToken) { $params.SkipToken = $skipToken }
        $response = Search-AzGraph @params
        # Newer Az.ResourceGraph versions return a response object with Data and SkipToken.
        $hasData = $null -ne $response -and $response -isnot [array] -and $response.PSObject.Properties['Data']
        $data = if ($hasData) { $response.Data } else { $response }
        foreach ($row in @($data)) { if ($null -ne $row) { $rows.Add($row) } }
        $skipToken = if ($hasData) { $response.SkipToken } else { $null }
    } while ($skipToken)
    return $rows
}

if (-not (Test-Path $LifecycleDataPath)) { throw "Retirement table not found: $LifecycleDataPath" }
$table = @(Import-Csv $LifecycleDataPath)
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null }

# --- Collect the sizes ---------------------------------------------------------------------
if ($InputPath) {
    $source = @(Import-Csv $InputPath)
    if ($source.Count -gt 0 -and -not $source[0].PSObject.Properties[$SizeColumn]) {
        throw "Column '$SizeColumn' not found in $InputPath. Use -SizeColumn to name the column with the VM size."
    }
    $resources = foreach ($row in $source) {
        $item = [ordered]@{}
        foreach ($p in $row.PSObject.Properties) { $item[$p.Name] = $p.Value }
        $item['vmSize'] = $row.$SizeColumn
        $item['powerState'] = if ($row.PSObject.Properties[$PowerStateColumn]) { $row.$PowerStateColumn } else { '' }
        [pscustomobject]$item
    }
} else {
    if (-not (Get-AzContext)) { throw 'No Azure session. Run Connect-AzAccount first.' }
    if ($SubscriptionIds) {
        # Resource Graph returns a generic BadRequest when a subscription is not in the tenant of the session.
        $tenantId = (Get-AzContext).Tenant.Id
        $visible = @(Get-AzSubscription -TenantId $tenantId -WarningAction SilentlyContinue | ForEach-Object { $_.Id })
        $missing = @($SubscriptionIds | Where-Object { $_ -notin $visible })
        if ($missing.Count -gt 0) {
            throw "Not accessible in tenant $($tenantId): $($missing -join ', '). Run Connect-AzAccount for the tenant of these subscriptions and try again."
        }
    }
    $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| project id, name, resourceGroup, subscriptionId, location, resourceType = 'Virtual machine',
    vmSize = tostring(properties.hardwareProfile.vmSize),
    powerState = tostring(properties.extended.instanceView.powerState.displayStatus),
    instances = 1
"@
    $vmssQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachinescalesets'
| project id, name, resourceGroup, subscriptionId, location, resourceType = 'Scale set',
    vmSize = tostring(sku.name), powerState = '', instances = toint(sku.capacity)
"@
    $resources = @(Invoke-GraphQuery -Query $vmQuery -Subscriptions $SubscriptionIds) +
                 @(Invoke-GraphQuery -Query $vmssQuery -Subscriptions $SubscriptionIds)
}
$resources = @($resources)
Write-Host "Resources to classify: $($resources.Count)"

# --- Classify ------------------------------------------------------------------------------
$inventory = foreach ($r in $resources) {
    $match = Get-VmSeriesLifecycle -Size "$($r.vmSize)".Trim() -Table $table
    $retirement = $null
    if ($match -and $match.RetirementDate) {
        $retirement = [datetime]::ParseExact($match.RetirementDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $r | Select-Object *,
        @{ n = 'series'; e = { if ($match) { $match.Series } else { '' } } },
        @{ n = 'retirementStatus'; e = { if ($match) { $match.Status } else { 'Not listed' } } },
        @{ n = 'retirementDate'; e = { if ($match) { $match.RetirementDate } else { '' } } },
        @{ n = 'daysToRetirement'; e = { if ($retirement) { [int]($retirement - $AsOfDate).TotalDays } else { '' } } },
        @{ n = 'capacityGrowthRestricted'; e = { if ($match) { $match.CapacityGrowthRestricted } else { '' } } }
}
$inventory = @($inventory)

$summary = $inventory | Group-Object series, retirementStatus, retirementDate | ForEach-Object {
    $first = $_.Group[0]
    $running = @($_.Group | Where-Object { "$($_.powerState)" -match 'running' }).Count
    $instances = ($_.Group | ForEach-Object { if ("$($_.instances)" -match '^\d+$') { [int]$_.instances } else { 1 } } | Measure-Object -Sum).Sum
    [pscustomobject]@{
        series           = if ($first.series) { $first.series } else { '(not in the retirement table)' }
        retirementStatus = $first.retirementStatus
        retirementDate   = $first.retirementDate
        resources        = $_.Count
        runningVms       = $running
        instances        = $instances
        sizes            = (($_.Group.vmSize | Sort-Object -Unique) -join '; ')
    }
} | Sort-Object @{ e = { if ($_.retirementDate) { $_.retirementDate } else { '9999' } } }, series

$inventoryFile = Join-Path $OutputPath 'vm-lifecycle-inventory.csv'
$summaryFile = Join-Path $OutputPath 'vm-lifecycle-summary.csv'
$inventory | Export-Csv $inventoryFile -NoTypeInformation -Encoding utf8
$summary | Export-Csv $summaryFile -NoTypeInformation -Encoding utf8

$listed = @($inventory | Where-Object { $_.retirementStatus -ne 'Not listed' }).Count
Write-Host "On a series with an announced retirement: $listed of $($inventory.Count)"
foreach ($s in $summary) {
    $when = if ($s.retirementDate) { "$($s.retirementStatus) $($s.retirementDate)" } else { $s.retirementStatus }
    Write-Host ("  {0,-32} {1,-24} resources: {2,-5} running VMs: {3}" -f $s.series, $when, $s.resources, $s.runningVms)
}
Write-Host "Files: $inventoryFile, $summaryFile"
Write-Host 'Retirement dates change. Confirm them at https://learn.microsoft.com/azure/virtual-machines/migration/sizes/previous-gen-series-capacity-limitations before sharing the results.'
