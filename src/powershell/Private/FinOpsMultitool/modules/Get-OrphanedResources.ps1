# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

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
| project id, name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          sku = sku.name, diskState = properties.diskState,
          type = 'Orphaned Disk'
"@
        $result = Search-AzGraphSafe -Query $diskQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Orphaned Disk'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.diskSizeGb) GB ($($r.sku))"
                    Impact         = 'Medium'
                })
        }
        Write-Host "    Orphaned disks: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Orphaned disk query failed: $($_.Exception.Message)"
    }

    # -- 2: Unattached Public IPs -----------------------------------------
    try {
        $pipQuery = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where properties.ipConfiguration == '' or isnull(properties.ipConfiguration)
| where properties.natGateway == '' or isnull(properties.natGateway)
| project id, name, resourceGroup, subscriptionId, location,
          sku = sku.name, ipAddress = properties.ipAddress,
          allocationMethod = properties.publicIPAllocationMethod,
          type = 'Unattached Public IP'
"@
        $result = Search-AzGraphSafe -Query $pipQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Unattached Public IP'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.sku) - $($r.allocationMethod)"
                    Impact         = if ($r.sku -eq 'Standard') { 'Medium' } else { 'Low' }
                })
        }
        Write-Host "    Unattached public IPs: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Unattached public IP query failed: $($_.Exception.Message)"
    }

    # -- 3: Unattached NICs -----------------------------------------------
    try {
        $nicQuery = @"
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine) or properties.virtualMachine == ''
| where isnull(properties.privateEndpoint) or properties.privateEndpoint == ''
| project id, name, resourceGroup, subscriptionId, location,
          enableAcceleratedNetworking = properties.enableAcceleratedNetworking,
          type = 'Unattached NIC'
"@
        $result = Search-AzGraphSafe -Query $nicQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Unattached NIC'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "Accelerated: $($r.enableAcceleratedNetworking)"
                    Impact         = 'Low'
                })
        }
        Write-Host "    Unattached NICs: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Unattached NIC query failed: $($_.Exception.Message)"
    }

    # -- 4: Stopped (deallocated) VMs still on disk -----------------------
    try {
        $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where properties.extended.instanceView.powerState.displayStatus == 'VM deallocated'
    or properties.extended.instanceView.powerState.code == 'PowerState/deallocated'
| project id, name, resourceGroup, subscriptionId, location,
          vmSize = properties.hardwareProfile.vmSize,
          powerState = properties.extended.instanceView.powerState.displayStatus,
          type = 'Deallocated VM'
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Deallocated VM'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.vmSize) - still incurs disk/IP costs"
                    Impact         = 'Medium'
                })
        }
        Write-Host "    Deallocated VMs: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Deallocated VM query failed: $($_.Exception.Message)"
    }

    # -- 5: Empty App Service Plans (0 apps) ------------------------------
    try {
        $aspQuery = @"
resources
| where type =~ 'microsoft.web/serverfarms'
| where properties.numberOfSites == 0
| where sku.tier != 'Free' and sku.tier != 'Shared'
| project id, name, resourceGroup, subscriptionId, location,
          sku = strcat(sku.tier, ' / ', sku.name),
          workers = properties.numberOfWorkers,
          type = 'Empty App Service Plan'
"@
        $result = Search-AzGraphSafe -Query $aspQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Empty App Service Plan'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.sku), $($r.workers) worker(s), 0 apps"
                    Impact         = 'High'
                })
        }
        Write-Host "    Empty App Service Plans: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Empty ASP query failed: $($_.Exception.Message)"
    }

    # -- 6: Orphaned Snapshots (older than 30 days) -----------------------
    try {
        $snapshotCutoff = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
        $snapQuery = @"
resources
| where type =~ 'microsoft.compute/snapshots'
| where properties.timeCreated < datetime('$snapshotCutoff')
| project id, name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB,
          timeCreated = properties.timeCreated,
          type = 'Old Snapshot'
"@
        $result = Search-AzGraphSafe -Query $snapQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allOrphans.Add([PSCustomObject]@{
                    Category       = 'Old Snapshot (30d+)'
                    ResourceId     = $r.id
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.diskSizeGb) GB, created $($r.timeCreated)"
                    Impact         = 'Low'
                })
        }
        Write-Host "    Old snapshots (30d+): $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Snapshot query failed: $($_.Exception.Message)"
    }

    # -- Observed cost per orphan (best effort) ---------------------------
    # Cost Management is a separate grant from Reader, so a denial here leaves
    # MonthlyCost null instead of failing the scan. The API rejects the
    # TheLastMonth timeframe, so a full previous month needs an explicit Custom
    # range, with month-to-date as the fallback.
    $costMap = @{}
    $costFailures = [System.Collections.Generic.List[string]]::new()
    $costQueried = 0
    $costPeriodLabel = $null
    $firstOfThisMonth = (Get-Date -Day 1).Date
    $lastMonthStart = $firstOfThisMonth.AddMonths(-1)
    $lastMonthEnd = $firstOfThisMonth.AddDays(-1)
    $costAttempts = @(
        @{
            Label = $lastMonthStart.ToString('MMM yyyy')
            Body  = @{
                type       = 'ActualCost'
                timeframe  = 'Custom'
                timePeriod = @{
                    from = $lastMonthStart.ToString('yyyy-MM-ddT00:00:00Z')
                    to   = $lastMonthEnd.ToString('yyyy-MM-ddT23:59:59Z')
                }
                dataset    = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping    = @(@{ type = 'Dimension'; name = 'ResourceId' })
                }
            }
        }
        @{
            Label = 'Month to date'
            Body  = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{ totalCost = @{ name = 'Cost'; function = 'Sum' } }
                    grouping    = @(@{ type = 'Dimension'; name = 'ResourceId' })
                }
            }
        }
    )
    if ($allOrphans.Count -gt 0) {
        foreach ($sub in $Subscriptions) {
            $costResp = $null
            $usedLabel = $null
            $lastCode = 'no response'
            foreach ($attempt in $costAttempts) {
                # A later subscription reuses whatever period already worked.
                if ($costPeriodLabel -and $attempt.Label -ne $costPeriodLabel) { continue }
                try {
                    $body = $attempt.Body | ConvertTo-Json -Depth 10
                    $r = Invoke-AzRestMethodWithRetry -Path "/subscriptions/$($sub.Id)/providers/Microsoft.CostManagement/query?api-version=2023-11-01" -Method POST -Payload $body
                    if ($r -and $r.StatusCode -eq 200) { $costResp = $r; $usedLabel = $attempt.Label; break }
                    $lastCode = if ($r) { [string]$r.StatusCode } else { 'no response' }
                }
                catch {
                    $lastCode = $_.Exception.Message
                }
            }

            if (-not $costResp) {
                $reason = switch ($lastCode) {
                    '429' { 'rate limited by Cost Management' }
                    '401' { 'not authorized for Cost Management' }
                    '403' { 'not authorized for Cost Management' }
                    default { "Cost Management returned $lastCode" }
                }
                [void]$costFailures.Add("$($sub.Name): $reason")
                continue
            }

            try {
                if (-not $costPeriodLabel) { $costPeriodLabel = $usedLabel }
                $costQueried++

                $costResult = ($costResp.Content | ConvertFrom-Json)
                $costCols = @{}
                for ($cIdx = 0; $cIdx -lt $costResult.properties.columns.Count; $cIdx++) {
                    $costCols[$costResult.properties.columns[$cIdx].name] = $cIdx
                }
                foreach ($costRow in $costResult.properties.rows) {
                    $rid = [string]$costRow[$costCols['ResourceId']]
                    # Resource Graph and Cost Management disagree on ID casing.
                    if ($rid) { $costMap[$rid.ToLowerInvariant()] = [math]::Round([double]$costRow[$costCols['Cost']], 2) }
                }
            }
            catch {
                [void]$costFailures.Add("$($sub.Name): $($_.Exception.Message)")
                Write-Verbose "Orphan cost lookup failed for $($sub.Name): $($_.Exception.Message)"
            }
        }
    }

    foreach ($orphan in $allOrphans) {
        $ridKey = if ($orphan.ResourceId) { ([string]$orphan.ResourceId).ToLowerInvariant() } else { $null }
        $orphanCost = if ($ridKey -and $costMap.ContainsKey($ridKey)) { $costMap[$ridKey] } else { $null }
        $orphan | Add-Member -NotePropertyName MonthlyCost -NotePropertyValue $orphanCost -Force
    }

    $costed = @($allOrphans | Where-Object { $null -ne $_.MonthlyCost })
    $totalMonthlyCost = if ($costed.Count -gt 0) { [math]::Round((($costed | Measure-Object -Property MonthlyCost -Sum).Sum), 2) } else { $null }
    $costAvailable = ($costQueried -gt 0)
    $costIssue = if ($costFailures.Count -gt 0) { ($costFailures | Select-Object -Unique) -join '; ' } else { $null }
    if ($costed.Count -gt 0) {
        Write-Host "    Observed cost ($costPeriodLabel) on $($costed.Count) of $($allOrphans.Count) orphans." -ForegroundColor Gray
    }
    if ($costIssue) {
        Write-Host "    Cost lookup incomplete - $costIssue" -ForegroundColor Yellow
    }

    # -- Summary by category --
    $summary = $allOrphans | Group-Object Category | ForEach-Object {
        [PSCustomObject]@{
            Category = $_.Name
            Count    = $_.Count
        }
    }

    return [PSCustomObject]@{
        Orphans       = @($allOrphans)
        Summary       = @($summary)
        TotalCount    = $allOrphans.Count
        HasData       = ($allOrphans.Count -gt 0)
        MonthlyCost   = $totalMonthlyCost
        CostedCount   = $costed.Count
        CostAvailable = $costAvailable
        CostPeriod    = $costPeriodLabel
        CostIssue     = $costIssue
    }
}
