---
name: Azure VM Rightsizing
description: Workflow for identifying over-provisioned VMs using Azure Advisor recommendations and Azure Monitor metrics, then recommending SKU downsizes validated against retail pricing. Covers CPU, memory, and disk IO utilization analysis with safety checks for burst requirements and Hybrid Benefit status.
---

**Key Features:**
- Azure Advisor right-size VM candidate identification
- Azure Monitor / Log Analytics utilization metric collection
- Utilization thresholds: CPU P95 < 20%, memory avg < 30%
- Target SKU recommendation with retail price validation
- Safety checks: burst requirements, instance size flexibility, Hybrid Benefit

---

## Overview

VM rightsizing is the highest-value single resource optimization in most Azure environments. The workflow:

1. **Identify candidates** — Advisor flags underutilized VMs
2. **Collect metrics** — Azure Monitor confirms utilization patterns
3. **Recommend target SKU** — downsize within the VM family
4. **Validate pricing** — confirm savings with Retail Prices API
5. **Safety check** — burst, flexibility, licensing

---

## Step 1: Identify candidates via Azure Advisor

Azure Advisor recommendation type `e10b1381-5f0a-47ff-8c7b-37bd13d7c974` identifies VMs for rightsizing based on 7-day utilization analysis.

### Azure CLI

```bash
az advisor recommendation list \
    --category Cost \
    --query "[?recommendationTypeId=='e10b1381-5f0a-47ff-8c7b-37bd13d7c974'].{
        Resource: resourceMetadata.resourceId,
        CurrentSku: extendedProperties.currentSku,
        TargetSku: extendedProperties.targetSku,
        Savings: extendedProperties.savingsAmount,
        Region: extendedProperties.regionId
    }" \
    --output table
```

### Resource Graph (cross-subscription)

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.recommendationTypeId == "e10b1381-5f0a-47ff-8c7b-37bd13d7c974"
| extend currentSku = tostring(properties.extendedProperties.currentSku)
| extend targetSku = tostring(properties.extendedProperties.targetSku)
| extend savings = todouble(properties.extendedProperties.savingsAmount)
| extend vmId = tostring(properties.resourceMetadata.resourceId)
| extend region = tostring(properties.extendedProperties.regionId)
| project vmId, currentSku, targetSku, savings, region, subscriptionId
| order by savings desc
```

See `references/azure-advisor.md` for full Advisor query patterns and suppression management.

---

## Step 2: Collect utilization metrics

Advisor's built-in analysis uses 7 days of data. For higher confidence, collect 14–30 days of metrics from Azure Monitor.

### CPU utilization (Azure Monitor)

```bash
# Average, P95, and max CPU over 14 days
az monitor metrics list \
    --resource "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vmName}" \
    --metric "Percentage CPU" \
    --start-time $(date -u -d "14 days ago" +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --interval PT1H \
    --aggregation Average Maximum \
    --query "value[0].timeseries[0].data[].{Time: timeStamp, Avg: average, Max: maximum}"
```

### Memory utilization (requires VM Insights)

Memory metrics require the Azure Monitor Agent (AMA) or Log Analytics agent. Query via Log Analytics workspace:

```kusto
// Memory utilization over 14 days
InsightsMetrics
| where TimeGenerated > ago(14d)
| where Origin == "vm.azm.ms"
| where Namespace == "Memory"
| where Name == "AvailableMB"
| extend TotalMB = todouble(Tags["vm.azm.ms/memorySizeMB"])
| extend UsedPercent = (TotalMB - Val) / TotalMB * 100
| summarize
    AvgMemoryPercent = avg(UsedPercent),
    P95MemoryPercent = percentile(UsedPercent, 95),
    MaxMemoryPercent = max(UsedPercent)
    by Computer
```

### Disk IO utilization

```kusto
// Disk IOPS and throughput over 14 days
InsightsMetrics
| where TimeGenerated > ago(14d)
| where Origin == "vm.azm.ms"
| where Namespace == "LogicalDisk"
| where Name in ("ReadsPerSecond", "WritesPerSecond", "ReadBytesPerSecond", "WriteBytesPerSecond")
| summarize
    AvgValue = avg(Val),
    P95Value = percentile(Val, 95),
    MaxValue = max(Val)
    by Computer, Name
| order by Computer, Name
```

### Combined utilization summary

```kusto
// Combined VM utilization summary for rightsizing analysis
let cpu = Perf
| where TimeGenerated > ago(14d)
| where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
| summarize CpuAvg = avg(CounterValue), CpuP95 = percentile(CounterValue, 95), CpuMax = max(CounterValue) by Computer;
let mem = InsightsMetrics
| where TimeGenerated > ago(14d)
| where Origin == "vm.azm.ms" and Namespace == "Memory" and Name == "AvailableMB"
| extend TotalMB = todouble(Tags["vm.azm.ms/memorySizeMB"])
| extend UsedPercent = (TotalMB - Val) / TotalMB * 100
| summarize MemAvg = avg(UsedPercent), MemP95 = percentile(UsedPercent, 95) by Computer;
cpu | join kind=leftouter mem on Computer
| project Computer, CpuAvg, CpuP95, CpuMax, MemAvg, MemP95
| extend RightsizeCandidate = CpuP95 < 20 and (isnull(MemAvg) or MemAvg < 30)
| order by RightsizeCandidate desc, CpuP95 asc
```

---

## Step 3: Determine rightsizing thresholds

| Metric | Threshold | Interpretation |
|--------|-----------|----------------|
| CPU P95 | < 20% | Strong downsize candidate |
| CPU P95 | 20–40% | Moderate candidate, verify burst patterns |
| CPU P95 | > 40% | Likely right-sized, skip |
| Memory avg | < 30% | Strong downsize candidate (if available) |
| Memory avg | 30–50% | Moderate candidate |
| Memory avg | > 50% | Likely right-sized for memory |

**Note:** If memory metrics are unavailable (no VM Insights), rely on CPU only but be more conservative — use CPU P95 < 15% as the threshold to account for unknown memory pressure.

**Agent compatibility note:** The `Perf` table is populated by the legacy Microsoft Monitoring Agent (MMA). Environments using the Azure Monitor Agent (AMA) should query CPU from `InsightsMetrics | where Namespace == 'Processor' and Name == 'UtilizationPercentage'` instead.

---

## Step 4: Recommend target SKU

### Get current VM specs via Resource Graph

```kusto
resources
| where type == "microsoft.compute/virtualmachines"
| where name == "{vmName}"
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| extend location = location
| project name, vmSize, location, resourceGroup, subscriptionId
```

### Compare against target SKU pricing

Use the Retail Prices API (see `references/azure-retail-prices.md`) to validate savings:

```powershell
function Get-VmSkuPrice {
    param([string]$Sku, [string]$Region)
    $response = Invoke-RestMethod "https://prices.azure.com/api/retail/prices?`$filter=armSkuName eq '$Sku' and armRegionName eq '$Region' and priceType eq 'Consumption'"
    return ($response.Items | Where-Object { $_.isPrimaryMeterRegion -and $_.type -eq 'Consumption' -and $_.meterName -notmatch 'Spot|Low Priority' }).retailPrice
}

# Example: D4s_v5 -> D2s_v5 in eastus
$currentPrice = Get-VmSkuPrice -Sku "Standard_D4s_v5" -Region "eastus"
$targetPrice = Get-VmSkuPrice -Sku "Standard_D2s_v5" -Region "eastus"
$monthlySavings = ($currentPrice - $targetPrice) * 730

Write-Host "Current: Standard_D4s_v5 @ `$$currentPrice/hr"
Write-Host "Target:  Standard_D2s_v5 @ `$$targetPrice/hr"
Write-Host "Monthly savings: `$$([math]::Round($monthlySavings, 2))"
Write-Host "Annual savings:  `$$([math]::Round($monthlySavings * 12, 2))"
```

### Common downsize paths

| Current Family | Typical Downsize | Notes |
|---------------|-----------------|-------|
| D-series (general purpose) | Halve vCPU count | D4s_v5 -> D2s_v5 |
| E-series (memory optimized) | Halve vCPU count | E8s_v5 -> E4s_v5 |
| F-series (compute optimized) | Halve vCPU count | F8s_v2 -> F4s_v2 |
| B-series (burstable) | Already burstable — verify CPU credits | Often right-sized |
| Cross-family | D-series -> B-series | For consistently low utilization |

---

## Step 5: Safety checks

### Burst requirements

Check P99 CPU to ensure burst capacity is preserved:

```kusto
Perf
| where TimeGenerated > ago(14d)
| where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
| where Computer == "{vmName}"
| summarize P99 = percentile(CounterValue, 99), Max = max(CounterValue) by Computer
```

If P99 > 80%, the VM has burst patterns that a smaller SKU may not handle. Consider B-series (burstable) instead of downsizing within the same family.

### Instance size flexibility

Azure Reservations support [instance size flexibility](https://learn.microsoft.com/azure/virtual-machines/reserved-vm-instance-size-flexibility) within a VM series. Downsizing within the same series (e.g., D4s_v5 -> D2s_v5) preserves reservation coverage with an adjusted ratio.

Check if the VM is covered by a reservation:

```kusto
advisorresources
| where type == "microsoft.advisor/recommendations"
| where properties.category == "Cost"
| where properties.recommendationTypeId == "e10b1381-5f0a-47ff-8c7b-37bd13d7c974"
| extend vmId = tostring(properties.resourceMetadata.resourceId)
| extend currentSku = tostring(properties.extendedProperties.currentSku)
| extend targetSku = tostring(properties.extendedProperties.targetSku)
| project vmId, currentSku, targetSku
```

If the VM is covered by a reservation and the downsize stays within the same series, the reservation automatically adjusts. Cross-series moves forfeit reservation coverage.

### Azure Hybrid Benefit status

Check if the VM uses Azure Hybrid Benefit (AHUB) for Windows or SQL licensing:

```bash
az vm show --name {vmName} --resource-group {rg} \
    --query "{licenseType: licenseType, osType: storageProfile.osDisk.osType}"
```

| `licenseType` value | Meaning |
|--------------------|---------|
| `Windows_Server` | AHUB for Windows Server |
| `Windows_Client` | AHUB for Windows Client |
| `RHEL_BYOS` | BYOS for Red Hat |
| `SLES_BYOS` | BYOS for SUSE |
| `null` | No AHUB — paying full license cost |

Ensure the target SKU preserves the same `licenseType` setting during resize.

---

## Limitations

| Limitation | Impact | Mitigation |
|-----------|--------|------------|
| Memory metrics require VM Insights | No memory data without agent | Deploy AMA agent, use CPU-only with conservative thresholds |
| Advisor uses 7-day window | May miss weekly patterns | Supplement with 14–30 day Azure Monitor analysis |
| No application-level metrics | CPU/memory don't capture app performance | Coordinate with app owners before resize |
| Resize requires VM restart | Brief downtime | Schedule during maintenance window |
| Cross-series resize loses reservation | Reservation coverage forfeited | Stay within same series when possible |

---

## Permissions

| Action | Required Role |
|--------|---------------|
| Query Advisor recommendations | Reader |
| Query Azure Monitor metrics | Monitoring Reader |
| Query Log Analytics workspace | Log Analytics Reader |
| Resize VM | Virtual Machine Contributor |
| Query Resource Graph | Reader |

---

## References

- [Right-size VMs (Azure Advisor)](https://learn.microsoft.com/azure/advisor/advisor-cost-recommendations#right-size-or-shutdown-underutilized-virtual-machines)
- [VM Insights overview](https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-overview)
- [Instance size flexibility](https://learn.microsoft.com/azure/virtual-machines/reserved-vm-instance-size-flexibility)
- [Azure Monitor metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/data-platform-metrics)
- [Azure Retail Prices API](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices)
- [Workload optimization (FinOps Framework)](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/workloads)
