---
name: Azure Orphaned Resources
description: Azure Resource Graph queries to detect unused and orphaned resources generating waste with zero workload value. Covers unattached disks, unused NICs, orphaned public IPs, idle load balancers, empty availability sets, orphaned NSGs, idle NAT gateways, and stale snapshots with safe cleanup patterns.
---

**Key Features:**
- Resource Graph queries for 8 orphaned resource types
- Immediate savings with zero performance risk
- Safe cleanup patterns with `-WhatIf` / `--dry-run`
- Cost estimation guidance per resource type
- Automation via Azure Policy and scheduled queries

---

## Why orphaned resources matter

Orphaned resources are Azure resources that remain provisioned after the workloads they supported are deleted, scaled down, or reconfigured. They generate charges with zero workload value — pure waste. Common causes: VM deletions that leave disks and NICs behind, IP address releases that don't clean up the public IP, and load balancers left after AKS cluster teardown.

These are the lowest-risk cost optimization opportunities because removing them has no impact on running workloads.

---

## Prerequisites

- Azure CLI (`az login`) or Azure PowerShell (`Connect-AzAccount`)
- **Reader** role on target subscriptions
- Azure Resource Graph access (enabled by default for all Microsoft Entra ID users)

---

## Detection queries

### Unattached managed disks

Disks in `Unattached` state are not connected to any VM. Typical monthly cost: $1.54–$122.88/disk depending on tier and size.

```bash
az graph query -q "
resources
| where type == 'microsoft.compute/disks'
| where properties.diskState == 'Unattached'
| project name, resourceGroup, subscriptionId,
    sku = properties.sku.name,
    sizeGb = properties.diskSizeGB,
    location,
    timeCreated = properties.timeCreated
| order by sizeGb desc
" --first 1000
```

### Unused network interfaces

NICs not attached to any VM. Created during VM provisioning and left behind on deletion.

```bash
az graph query -q "
resources
| where type == 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine)
| where isnull(properties.virtualMachineScaleSet)
| where isnull(properties.privateEndpoint)
| project name, resourceGroup, subscriptionId, location,
    privateIp = properties.ipConfigurations[0].properties.privateIPAddress
" --first 1000
```

**Note:** NICs attached to private endpoints (`properties.privateEndpoint != null`) or VMSS instances (`properties.virtualMachineScaleSet != null`) are not orphaned — both are excluded.

### Orphaned public IP addresses

Public IPs not associated with any resource. Standard SKU public IPs cost ~$3.65/month even when idle.

```bash
az graph query -q "
resources
| where type == 'microsoft.network/publicipaddresses'
| where isnull(properties.ipConfiguration)
| where isnull(properties.natGateway)
| project name, resourceGroup, subscriptionId, location,
    sku = sku.name,
    ipAddress = properties.ipAddress,
    allocationMethod = properties.publicIPAllocationMethod
" --first 1000
```

### Idle NAT gateways

NAT gateways with no associated subnets. Charged at ~$32.85/month plus data processing fees.

```bash
az graph query -q "
resources
| where type == 'microsoft.network/natgateways'
| where isnull(properties.subnets) or array_length(properties.subnets) == 0
| project name, resourceGroup, subscriptionId, location
" --first 1000
```

### Orphaned snapshots

Snapshots where the source disk no longer exists. Filter to snapshots older than 30 days to avoid catching in-progress operations.

```bash
az graph query -q "
resources
| where type == 'microsoft.compute/snapshots'
| where todatetime(properties.timeCreated) < ago(30d)
| extend sourceDisk = tostring(properties.creationData.sourceResourceId)
| where not(sourceDisk has '/snapshots/')
| join kind=leftanti (
    resources
    | where type == 'microsoft.compute/disks'
    | project id
) on \$left.sourceDisk == \$right.id
| project name, resourceGroup, subscriptionId, location,
    sizeGb = properties.diskSizeGB,
    created = properties.timeCreated,
    sourceDisk
| order by sizeGb desc
" --first 1000
```

### Idle load balancers

Load balancers with empty backend pools — no VMs or VMSSes behind them.

```bash
az graph query -q "
resources
| where type == 'microsoft.network/loadbalancers'
| where isnull(properties.backendAddressPools)
    or array_length(properties.backendAddressPools) == 0
| project name, resourceGroup, subscriptionId, location,
    sku = sku.name
" --first 1000
```

**Note:** Standard SKU load balancers cost ~$18.25/month when idle. Basic SKU load balancers are free but should still be cleaned up.

### Empty availability sets

Availability sets with no VMs. No direct cost, but they clutter the environment and may prevent resource cleanup.

```bash
az graph query -q "
resources
| where type == 'microsoft.compute/availabilitysets'
| where isnull(properties.virtualMachines) or array_length(properties.virtualMachines) == 0
| project name, resourceGroup, subscriptionId, location
" --first 1000
```

### Orphaned network security groups

NSGs not attached to any NIC or subnet. No direct cost, but they add management overhead and security audit noise.

```bash
az graph query -q "
resources
| where type == 'microsoft.network/networksecuritygroups'
| where isnull(properties.networkInterfaces) or array_length(properties.networkInterfaces) == 0
| where isnull(properties.subnets) or array_length(properties.subnets) == 0
| project name, resourceGroup, subscriptionId, location,
    rulesCount = array_length(properties.securityRules)
" --first 1000
```

---

## Cost estimation by resource type

| Resource Type | Typical Monthly Cost | Detection Confidence |
|--------------|---------------------|---------------------|
| Managed disks (unattached) | $1.54–$122.88/disk (varies by SKU tier) | High — `Unattached` is definitive; `Reserved` state disks (temporarily held during VM provisioning) are excluded |
| Public IPs (Standard SKU) | ~$3.65/IP | High — no `ipConfiguration` is definitive |
| NAT gateways (idle) | ~$32.85 + data fees | High — no subnets is definitive |
| Load balancers (Standard, empty) | ~$18.25/LB | High — empty backend pools |
| Snapshots (orphaned) | $0.05/GB/month | Medium — source disk deleted but snapshot may be intentional backup; snapshot-to-snapshot chains are excluded |
| NICs (unused) | Free (but blocks cleanup) | Medium — check for pending VM deployments |
| Availability sets (empty) | Free (clutter) | High — no VMs attached |
| NSGs (orphaned) | Free (audit noise) | Medium — may be pre-provisioned for deployment templates |

---

## Safe cleanup patterns

### PowerShell with -WhatIf

```powershell
# Preview disk cleanup (dry run)
$disks = Search-AzGraph -Query "
resources
| where type == 'microsoft.compute/disks'
| where properties.diskState == 'Unattached'
| project name, resourceGroup, subscriptionId
"

foreach ($disk in $disks) {
    Remove-AzDisk -ResourceGroupName $disk.resourceGroup `
        -DiskName $disk.name -WhatIf
}

# Execute cleanup (remove -WhatIf)
foreach ($disk in $disks) {
    Remove-AzDisk -ResourceGroupName $disk.resourceGroup `
        -DiskName $disk.name -Force
}
```

### Azure CLI with --dry-run

Azure CLI `delete` commands do not have a `--dry-run` flag. Instead, list first and review before deleting:

```bash
# List orphaned public IPs (review step)
az graph query -q "
resources
| where type == 'microsoft.network/publicipaddresses'
| where isnull(properties.ipConfiguration)
| where isnull(properties.natGateway)
| project name, resourceGroup, subscriptionId
" --first 1000 -o table

# Delete after review (per resource)
az network public-ip delete --name <name> --resource-group <rg>
```

### Bulk cleanup script

```powershell
# Bulk delete unattached disks across subscriptions
$disks = Search-AzGraph -Query "
resources
| where type == 'microsoft.compute/disks'
| where properties.diskState == 'Unattached'
| project name, resourceGroup, subscriptionId
" -First 1000

$totalRemoved = 0
foreach ($disk in $disks) {
    try {
        Set-AzContext -Subscription $disk.subscriptionId -ErrorAction Stop | Out-Null
        Remove-AzDisk -ResourceGroupName $disk.resourceGroup `
            -DiskName $disk.name -Force -ErrorAction Stop
        $totalRemoved++
    } catch {
        Write-Warning "Skipping $($disk.name) in $($disk.subscriptionId): $_"
    }
}
Write-Host "Removed $totalRemoved of $($disks.Count) unattached disks"
```

---

## Automation

### Azure Policy (audit mode)

Use built-in Azure Policy definitions to audit orphaned resources:

| Policy | Description |
|--------|-------------|
| `Audit unattached managed disks` | Flags disks with `diskState == Unattached` |
| `Audit unused public IP addresses` | Flags public IPs with no association |

Deploy at management group scope for enterprise-wide coverage.

### Scheduled Resource Graph queries

Use Azure Automation or Logic Apps to run detection queries on a weekly schedule and send results via email or Teams webhook:

```powershell
# Azure Automation runbook pattern
param (
    [Parameter(Mandatory = $true)]
    [string]$TeamsWebhookUrl
)

$orphanedDisks = Search-AzGraph -Query "
resources
| where type == 'microsoft.compute/disks'
| where properties.diskState == 'Unattached'
| summarize Count = count()
"

if ($orphanedDisks.Count -gt 0) {
    # NOTE: Actual cost depends on disk SKU tier (Standard HDD ~$0.045/GB, Premium SSD ~$0.17-$0.38/GB).
    # Use references/azure-retail-prices.md for per-SKU pricing validation.
    $body = @{
        title = "Orphaned Resource Alert"
        text  = "$($orphanedDisks.Count) unattached disks found. Review and clean up to reduce waste."
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $TeamsWebhookUrl -Method Post -Body $body -ContentType 'application/json'
}
```

---

## Permissions

| Action | Required Role |
|--------|---------------|
| Run Resource Graph queries | Reader |
| Delete resources | Contributor on resource group |
| Deploy Azure Policy | Resource Policy Contributor |
| Azure Automation runbooks | Automation Contributor |

---

## References

- [Azure Resource Graph overview](https://learn.microsoft.com/azure/governance/resource-graph/overview)
- [Azure Resource Graph query samples](https://learn.microsoft.com/azure/governance/resource-graph/samples/starter)
- [Azure Policy built-in definitions](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies)
- [Manage unattached disks](https://learn.microsoft.com/azure/virtual-machines/windows/find-unattached-disks)
- [Workload optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/workloads)
