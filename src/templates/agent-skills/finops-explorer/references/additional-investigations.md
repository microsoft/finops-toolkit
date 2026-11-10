# Unit economics and remaining investigations

Cost per unit of capacity, plus the investigations not covered by the other reference pages.

## Unit economics

Divide amortized cost by provisioned capacity. Four ratios, each answering a different question.

| Metric | Formula | Answers |
| ------ | ------- | ------- |
| Cost per vCPU | compute cost ÷ total provisioned vCPUs | Are we paying a fair rate for compute? |
| Cost per GB RAM | compute cost ÷ total provisioned memory GB | Is the workload memory-skewed? |
| Cost per VM | compute cost ÷ VM count | Rough fleet average, useful for trend |
| Cost per GB stored | storage cost ÷ total GB | Is storage tiered correctly? |

### Getting the numbers right

**Use amortized cost, not actual.** A reservation purchase lands as a lump on the purchase date in actual cost. Divide that by vCPUs and the month of purchase shows an absurd rate. Amortized spreads it across the term, which is what a unit rate should reflect.

**vCPU and memory are not in Resource Graph.** The `resources` table exposes `vmSize` but not its capabilities. Resolve size → vCPU/memory through the Compute SKUs API per region:

```bash
az vm list-skus --location <region> --resource-type virtualMachines \
  --query "[].{name:name, caps:capabilities}" -o json
```

Cache it per region — the response is large and identical for every VM in that region. Falling back to parsing the size name (`Standard_D4s_v5` → 4 vCPU) works often enough to be dangerous: it silently misreads constrained-vCPU sizes and several families. Prefer the API and note when you had to guess.

**Storage GB has two sources.** Provisioned managed-disk size from Resource Graph, plus *used* capacity for storage accounts from the `UsedCapacity` metric — one call per account. Disks are provisioned; blob storage is consumed. Mixing provisioned and used without saying so produces a rate nobody can reconcile.

### Reading the result

A unit rate is only meaningful as a trend or a comparison. "$47 per vCPU per month" alone means nothing. Rising month over month with flat capacity means rate erosion — usually an expiring commitment. Falling with flat cost means capacity was added without cost, which usually means something is provisioned and idle.

Pair a rising cost-per-vCPU with commitment utilization before concluding anything. See `commitments.md`.

## Legacy resources

Retiring SKUs, deprecated API versions, and resources on classic deployment models. These carry migration risk and often a price premium.

```kusto
resources
| extend skuName = tostring(sku.name), vmSize = tostring(properties.hardwareProfile.vmSize)
| where (type =~ 'microsoft.network/publicipaddresses' and skuName =~ 'Basic')
    or (type =~ 'microsoft.network/loadbalancers' and skuName =~ 'Basic')
    or (type =~ 'microsoft.compute/disks' and skuName =~ 'Standard_LRS' and toint(properties.diskSizeGB) >= 128)
    or (type =~ 'microsoft.compute/virtualmachines'
        and (isnotempty(properties.storageProfile.osDisk.vhd.uri)
            or vmSize matches regex @'(?i)^(Basic_A[0-9]+|Standard_A[0-7]|Standard_D[0-9]+|Standard_DS[0-9]+|Standard_F[0-9]+|Standard_G[0-9]+|Standard_GS[0-9]+)$'))
    or type startswith 'microsoft.classic'
| project name, type, resourceGroup, subscriptionId, location, skuName, vmSize
```

This matches the terminal UI's legacy scan: Basic public IPs and Basic load balancers (both retired on September 30, 2025), first-generation VM sizes (`Standard_D2`, not `Standard_D2_v3`; look up each family's retirement date on Microsoft Learn), unmanaged VHD disks, HDD managed disks of 128 GB or more, and classic resources. Don't flag every `Standard_LRS` resource. It's the default for most storage and small disks, so on its own it isn't a retirement signal.

Report the retirement date alongside the finding — "deprecated" without a date doesn't drive action.

## Budget history

Budget status shows the current period. History shows whether the budget was ever realistic.

Pull budgets from `Microsoft.Consumption/budgets`, then query cost per month over the same window and compare. A budget exceeded every month for six months isn't an alerting problem, it's a budget that was set wrong — recommend re-baselining rather than more alerts.

See `forecasting-budgeting` for budget design.

## AI workload spend

Azure OpenAI and Cognitive Services cost, joined to token telemetry.

Cost comes from Cost Management filtered to `MICROSOFT.COGNITIVESERVICES`. Token volume comes from Azure Monitor:

```kusto
AzureMetrics
| where ResourceProvider == 'MICROSOFT.COGNITIVESERVICES'
| where MetricName in ('ProcessedPromptTokens', 'GeneratedTokens')
| summarize tokens = sum(Total) by Resource, MetricName
```

`AzureMetrics` only has data when the account's diagnostic settings send metrics to a Log Analytics workspace, and that export flattens dimensions. It gives totals per account, not per deployment. For a per-deployment split, read the platform metrics directly:

```bash
az monitor metrics list --resource <accountResourceId> \
  --metric ProcessedPromptTokens GeneratedTokens \
  --start-time <30d-ago> --end-time <now> \
  --aggregation Total --interval P1D \
  --filter "ModelDeploymentName eq '*'" --top 100
```

A filtered query returns at most 10 series by default, so raise `--top` to cover every deployment. Sum the daily totals per deployment and metric.

The useful output is **cost per 1K tokens**, per deployment. That's the number that tells you whether a model choice is defensible — and it exposes the case where a small amount of traffic on an expensive model dominates spend.

Prompt and generated tokens price differently. Keep them separate.

## VM cost breakdown

Full cost for one VM: compute, plus attached disks, plus the public IP, plus bandwidth.

Cost Management grouped by `ResourceId` gives the compute line. The attached resources bill separately and are easy to miss — which is exactly why a deallocated VM still costs money.

Resolve the VM's disks and NICs from Resource Graph, then sum their costs alongside. Reporting the compute line alone understates a VM's real cost, often substantially for storage-heavy machines.

## Tenant hierarchy

Management group and subscription structure, used to understand scope before a broad scan.

```bash
az account management-group list --query "[].{name:name, displayName:displayName}" -o table
```

Mostly a prerequisite rather than a finding. Useful when cost is being reported at the wrong scope, or when a subscription sits outside the expected hierarchy and is escaping policy.

## Related

- `unit-economics` skill for KPI definitions and business denominators
- `commitments.md` for the commitment side of a rising unit rate
- `cost-analysis.md` for amortized versus actual cost
- `forecasting-budgeting` for budget design and variance
