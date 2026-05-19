###########################################################################
# GET-ORPHANEDRESOURCES.PS1
# AZURE FINOPS MULTITOOL - Orphaned & Idle Resource Detection
###########################################################################
# Purpose: Use Azure Resource Graph to find resources that are costing
#          money but serving no purpose: orphaned disks, unattached IPs,
#          empty App Service Plans, unattached NICs, and stopped VMs
#          that are still incurring compute charges.
###########################################################################

function Get-OrphanedResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    Write-Host "  Scanning for orphaned and idle resources..." -ForegroundColor Cyan

    $subIds = $Subscriptions | ForEach-Object { $_.Id }
    $allOrphans = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -- 1: Orphaned Managed Disks (no ownerVM) --------------------------
    try {
        $diskQuery = @"
resources
| where type =~ 'microsoft.compute/disks'
| where managedBy == '' or isnull(managedBy)
| where properties.diskState == 'Unattached'
| project name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          sku = sku.name, diskState = properties.diskState,
          type = 'Orphaned Disk'
"@
        $result = Search-AzGraphSafe -Query $diskQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Orphaned Disk'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "$($r.diskSizeGb) GB ($($r.sku))"
                Impact         = 'Medium'
            })
        }
        Write-Host "    Orphaned disks: $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Orphaned disk query failed: $($_.Exception.Message)"
    }

    # -- 2: Unattached Public IPs -----------------------------------------
    try {
        $pipQuery = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where properties.ipConfiguration == '' or isnull(properties.ipConfiguration)
| where properties.natGateway == '' or isnull(properties.natGateway)
| project name, resourceGroup, subscriptionId, location,
          sku = sku.name, ipAddress = properties.ipAddress,
          allocationMethod = properties.publicIPAllocationMethod,
          type = 'Unattached Public IP'
"@
        $result = Search-AzGraphSafe -Query $pipQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Unattached Public IP'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "$($r.sku) - $($r.allocationMethod)"
                Impact         = if ($r.sku -eq 'Standard') { 'Medium' } else { 'Low' }
            })
        }
        Write-Host "    Unattached public IPs: $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Unattached public IP query failed: $($_.Exception.Message)"
    }

    # -- 3: Unattached NICs -----------------------------------------------
    try {
        $nicQuery = @"
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine) or properties.virtualMachine == ''
| where isnull(properties.privateEndpoint) or properties.privateEndpoint == ''
| project name, resourceGroup, subscriptionId, location,
          enableAcceleratedNetworking = properties.enableAcceleratedNetworking,
          type = 'Unattached NIC'
"@
        $result = Search-AzGraphSafe -Query $nicQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Unattached NIC'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "Accelerated: $($r.enableAcceleratedNetworking)"
                Impact         = 'Low'
            })
        }
        Write-Host "    Unattached NICs: $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Unattached NIC query failed: $($_.Exception.Message)"
    }

    # -- 4: Stopped (deallocated) VMs still on disk -----------------------
    try {
        $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.extended.instanceView.powerState.displayStatus == 'VM deallocated'
    or properties.extended.instanceView.powerState.code == 'PowerState/deallocated'
| project name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          powerState = properties.extended.instanceView.powerState.displayStatus,
          type = 'Deallocated VM'
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Deallocated VM'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "$($r.vmSize) - still incurs disk/IP costs"
                Impact         = 'Medium'
            })
        }
        Write-Host "    Deallocated VMs: $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Deallocated VM query failed: $($_.Exception.Message)"
    }

    # -- 5: Empty App Service Plans (0 apps) ------------------------------
    try {
        $aspQuery = @"
resources
| where type =~ 'microsoft.web/serverfarms'
| where properties.numberOfSites == 0
| where sku.tier != 'Free' and sku.tier != 'Shared'
| project name, resourceGroup, subscriptionId, location,
          sku = strcat(sku.tier, ' / ', sku.name),
          workers = properties.numberOfWorkers,
          type = 'Empty App Service Plan'
"@
        $result = Search-AzGraphSafe -Query $aspQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Empty App Service Plan'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "$($r.sku), $($r.workers) worker(s), 0 apps"
                Impact         = 'High'
            })
        }
        Write-Host "    Empty App Service Plans: $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Empty ASP query failed: $($_.Exception.Message)"
    }

    # -- 6: Orphaned Snapshots (older than 30 days) -----------------------
    try {
        $snapshotCutoff = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
        $snapQuery = @"
resources
| where type =~ 'microsoft.compute/snapshots'
| where properties.timeCreated < datetime('$snapshotCutoff')
| project name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          timeCreated = properties.timeCreated,
          type = 'Old Snapshot'
"@
        $result = Search-AzGraphSafe -Query $snapQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                Category       = 'Old Snapshot (30d+)'
                ResourceName   = $r.name
                ResourceGroup  = $r.resourceGroup
                SubscriptionId = $r.subscriptionId
                Location       = $r.location
                Detail         = "$($r.diskSizeGb) GB, created $($r.timeCreated)"
                Impact         = 'Low'
            })
        }
        Write-Host "    Old snapshots (30d+): $($rows.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "  Snapshot query failed: $($_.Exception.Message)"
    }

    # -- Summary by category --
    $summary = $allOrphans | Group-Object Category | ForEach-Object {
        [PSCustomObject]@{
            Category = $_.Name
            Count    = $_.Count
        }
    }

    return [PSCustomObject]@{
        Orphans     = @($allOrphans)
        Summary     = @($summary)
        TotalCount  = $allOrphans.Count
        HasData     = ($allOrphans.Count -gt 0)
    }
}
