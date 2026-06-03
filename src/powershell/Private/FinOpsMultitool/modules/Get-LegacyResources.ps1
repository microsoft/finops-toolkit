###########################################################################
# GET-LEGACYRESOURCES.PS1
# AZURE FINOPS MULTITOOL - Legacy & Retiring Resource Detection
###########################################################################
# Purpose: Use Azure Resource Graph to surface resources running on legacy
#          or retiring SKUs that should be modernized: first-generation VM
#          families (A/D/F/G v1), HDD (Standard_LRS) managed disks,
#          unmanaged (VHD) disks, and Basic-SKU public IPs / load balancers
#          (retiring Sept 2025). Supports the FinOps modernization KPI.
###########################################################################
# Notes:
# - RBAC: Reader on each subscription (Azure Resource Graph).
# - "Legacy" VM families are v1 sizes with no version suffix (e.g.
#   Standard_D2 vs Standard_D2_v3) plus Basic_A / Standard_A0-A7 and the
#   G/GS series. These typically have a modern, cheaper successor.
###########################################################################

function Get-LegacyResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Subscriptions
    )

    Write-Host "  Scanning for legacy and retiring resources..." -ForegroundColor Cyan

    $subIds = $Subscriptions | ForEach-Object { $_.Id }
    $allLegacy = [System.Collections.Generic.List[PSCustomObject]]::new()

    # -- 1: Legacy (v1) VM families ---------------------------------------
    try {
        $vmQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| where vmSize matches regex @'(?i)^(Basic_A[0-9]+|Standard_A[0-7]|Standard_D[0-9]+|Standard_DS[0-9]+|Standard_F[0-9]+|Standard_G[0-9]+|Standard_GS[0-9]+)$'
| project name, resourceGroup, subscriptionId, location, vmSize
"@
        $result = Search-AzGraphSafe -Query $vmQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allLegacy.Add([PSCustomObject]@{
                    Category       = 'Legacy VM Family'
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.vmSize) (v1 - upgrade to current generation)"
                    Impact         = 'High'
                })
        }
        Write-Host "    Legacy VM families: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Legacy VM query failed: $($_.Exception.Message)"
    }

    # -- 2: Unmanaged (VHD) disks -----------------------------------------
    try {
        $vhdQuery = @"
resources
| where type =~ 'microsoft.compute/virtualmachines'
| where isnotempty(properties.storageProfile.osDisk.vhd.uri)
| project name, resourceGroup, subscriptionId, location,
          vhd = tostring(properties.storageProfile.osDisk.vhd.uri)
"@
        $result = Search-AzGraphSafe -Query $vhdQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allLegacy.Add([PSCustomObject]@{
                    Category       = 'Unmanaged Disk'
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = 'VM uses unmanaged (VHD) OS disk - migrate to managed disks'
                    Impact         = 'High'
                })
        }
        Write-Host "    Unmanaged-disk VMs: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Unmanaged disk query failed: $($_.Exception.Message)"
    }

    # -- 3: HDD (Standard_LRS) managed disks ------------------------------
    try {
        $hddQuery = @"
resources
| where type =~ 'microsoft.compute/disks'
| where tostring(sku.name) =~ 'Standard_LRS'
| where toint(properties.diskSizeGB) >= 128
| project name, resourceGroup, subscriptionId, location,
          diskSizeGb = properties.diskSizeGB, sku = sku.name
"@
        $result = Search-AzGraphSafe -Query $hddQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allLegacy.Add([PSCustomObject]@{
                    Category       = 'HDD Managed Disk'
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = "$($r.diskSizeGb) GB HDD (Standard_LRS) - consider Standard/Premium SSD"
                    Impact         = 'Low'
                })
        }
        Write-Host "    HDD managed disks: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  HDD disk query failed: $($_.Exception.Message)"
    }

    # -- 4: Basic-SKU public IPs (retiring Sept 2025) ---------------------
    try {
        $pipQuery = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where tostring(sku.name) =~ 'Basic'
| project name, resourceGroup, subscriptionId, location, sku = sku.name
"@
        $result = Search-AzGraphSafe -Query $pipQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allLegacy.Add([PSCustomObject]@{
                    Category       = 'Basic Public IP'
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = 'Basic-SKU public IP (retires Sep 2025) - migrate to Standard'
                    Impact         = 'High'
                })
        }
        Write-Host "    Basic public IPs: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Basic public IP query failed: $($_.Exception.Message)"
    }

    # -- 5: Basic-SKU load balancers (retiring Sept 2025) -----------------
    try {
        $lbQuery = @"
resources
| where type =~ 'microsoft.network/loadbalancers'
| where tostring(sku.name) =~ 'Basic'
| project name, resourceGroup, subscriptionId, location, sku = sku.name
"@
        $result = Search-AzGraphSafe -Query $lbQuery -Subscription $subIds -First 1000
        $rows = if ($result) { @($result.Data) } else { @() }
        foreach ($r in $rows) {
            [void]$allLegacy.Add([PSCustomObject]@{
                    Category       = 'Basic Load Balancer'
                    ResourceName   = $r.name
                    ResourceGroup  = $r.resourceGroup
                    SubscriptionId = $r.subscriptionId
                    Location       = $r.location
                    Detail         = 'Basic-SKU load balancer (retires Sep 2025) - migrate to Standard'
                    Impact         = 'High'
                })
        }
        Write-Host "    Basic load balancers: $($rows.Count)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  Basic load balancer query failed: $($_.Exception.Message)"
    }

    $byCategory = @(
        $allLegacy | Group-Object Category | ForEach-Object {
            [PSCustomObject]@{ Category = $_.Name; Count = $_.Count }
        } | Sort-Object Count -Descending
    )

    return [PSCustomObject]@{
        HasData         = ($allLegacy.Count -gt 0)
        TotalCount      = $allLegacy.Count
        LegacyResources = @($allLegacy | Sort-Object @{ Expression = 'Impact'; Descending = $true }, Category)
        ByCategory      = $byCategory
        ScannedSubs     = $Subscriptions.Count
    }
}
