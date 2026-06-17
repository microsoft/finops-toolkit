# Lab 2: Forecasting

## Overview

Forecasting capacity needs is about collecting utilization signals, analyzing patterns, and translating them into infrastructure commitments. This lab walks you through using Azure Cost Management APIs, quota telemetry, and utilization metrics to build a forecast of compute and storage demand across your SaaS platform, aligned with [Well-Architected capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) guidance.

You'll gather baseline quota usage, analyze utilization patterns in Azure Monitor, pull savings plan recommendations, assess storage costs, and map your forecast to deployment scale units. These outputs feed directly into procurement and allocation decisions.

> **Pilot scope boundary:** Forecasting improves planning quality and escalation readiness, but it doesn't guarantee regional or zonal service availability on its own. Region and zone deployment access still depends on subscription-level access approvals and current capacity availability in Azure regions ([Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [Region access request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), [Zonal enablement request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series)).

### Required lab outputs

Produce these outputs before moving to procurement and allocation work:

1. **FY26 forecasting template output** with assumptions, confidence ranges, and quarter-by-quarter demand projections ([Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).
2. **Technical action register** with signal, threshold, evidence, recommended action, and validation timestamp for every identified quota, capacity, or cost action ([Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)).
3. **Escalation-ready evidence pack** with support-ready artifacts for quota, region access, and reservation blockers ([Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request), [Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests)).
4. **Regional PaaS readiness matrix** for non-compute services in each target region, backed by reproducible API output ([Azure REST API reference](https://learn.microsoft.com/en-us/rest/api/azure/), [Azure CLI quota reference](https://learn.microsoft.com/en-us/cli/azure/quota?view=azure-cli-latest)).

### Technical decision evidence model

Capture a decision artifact only when forecast output changes one or more technical control values:

- Target deployment date or milestone date
- Target region or availability zone
- Requested quota, capacity reservation quantity, or commitment amount
- Service scaling boundary (for example, storage sharding, partitioning, or throughput target)

If none of these values change, keep the item as an observation in your evidence workbook, not as a decision artifact ([Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [FinOps planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/)).

> **Policy callout:** All training steps in this lab must be reproducible with publicly documented Azure APIs or documented CLI surfaces. Don't rely on private tools, unpublished endpoints, or portal-only behavior without an API equivalent ([Azure REST API reference](https://learn.microsoft.com/en-us/rest/api/azure/), [Azure CLI overview](https://learn.microsoft.com/en-us/cli/azure/what-is-azure-cli)).

**Prerequisites:**
- Authenticated access to a billing scope and at least one Azure subscription that contains workload resources for analysis ([scripts/rate/README.md](../../scripts/rate/README.md), [Azure subscriptions and management groups](https://learn.microsoft.com/en-us/azure/governance/management-groups/overview))
- A supported command surface for reproducible queries: Azure CLI and, for PowerShell examples in this lab, the Az PowerShell modules used by the scripts ([Azure CLI overview](https://learn.microsoft.com/en-us/cli/azure/what-is-azure-cli), [Install Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell), [scripts/rate/README.md](../../scripts/rate/README.md), [scripts/quota/README.md](../../scripts/quota/README.md))
- Read access on the target billing or subscription scope so you can query cost, quota, and monitoring data ([scripts/rate/README.md](../../scripts/rate/README.md), [Use cost alerts to monitor usage and spending](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending), [How to monitor quotas and generate alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting))

---

## Exercise 1: Gather baseline quota and usage data

**Objective:** Collect current quota limits and actual usage across compute SKUs and regions to understand headroom for growth.

Quota tells you what you're allowed to run, and usage tells you what you're actually running. The gap is your growth buffer for planning and escalation lead time ([Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).

### Step 1.1: Export VM SKU quota usage across subscriptions

Run the multithreaded quota analysis script to scan all subscriptions for compute quota:

```powershell
.\scripts/quota/Get-AzVMQuotaUsage.ps1 `
  -SKUs "Standard_D2s_v3", "Standard_D4s_v3", "Standard_E2s_v3", "Standard_E4s_v3" `
  -Locations "eastus", "westus2", "northeurope" `
  -Threads 4 `
  -UsePhysicalZones
```

This script:
- Queries each subscription in parallel (4 concurrent threads) ([Get-AzVMQuotaUsage script](../../scripts/quota/Get-AzVMQuotaUsage.ps1), [quota scripts README](../../scripts/quota/README.md))
- Returns quota limits, current usage, and utilization % per SKU per location ([Get-AzVMQuotaUsage script](../../scripts/quota/Get-AzVMQuotaUsage.ps1), [quota scripts README](../../scripts/quota/README.md))
- Identifies subscriptions approaching quota limits (the constraint on scaling) ([Get-AzVMQuotaUsage script](../../scripts/quota/Get-AzVMQuotaUsage.ps1), [quota scripts README](../../scripts/quota/README.md))
- Includes physical zone information if -UsePhysicalZones is set ([Get-AzVMQuotaUsage script](../../scripts/quota/Get-AzVMQuotaUsage.ps1), [quota scripts README](../../scripts/quota/README.md))

**Output interpretation:**
- Use your own alert policy thresholds for investigation and escalation. If you use >80% and <20% as internal triage bands, treat them as operator-defined heuristics, not Azure platform defaults ([How to monitor quotas and generate alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning))
- Compare across regions to identify uneven capacity distribution

### Step 1.2: Query quota usage via Azure CLI

For a specific subscription and region, use the CLI to drill down:

```bash
az vm list-usage \
  --location eastus \
  --subscription YOUR_SUBSCRIPTION_ID \
  --query "[?contains(name.value, 'DSv3')].{Family: name.localizedValue, Limit: limit, CurrentUsage: currentValue}" \
  --output table
```

This returns per-family vCPU limits and current usage. Filter by family name substring (e.g., `DSv3`, `ESv3`) — the `name.value` field contains family identifiers like `standardDSv3Family`, not individual SKU names.

Reference the [az vm list-usage documentation](https://learn.microsoft.com/en-us/cli/azure/vm?view=azure-cli-latest#az-vm-list-usage) for output schema details.

**What to look for (operator-defined triage heuristics):**
- Subscriptions or regions where current usage approaches configured alert thresholds for the quota family.
- SKU families with sustained low utilization relative to allocated limits.
- Regional concentration patterns that create uneven headroom across target deployment regions.

References: [How to monitor quotas and generate alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning).

### Step 1.3: Document baseline

Save the output CSVs. You'll use these as a baseline to track growth rate quarter-over-quarter.

Also capture escalation evidence fields in your baseline workbook so the output can move directly into support or capacity escalation when needed:

- Subscription ID, tenant ID, and billing scope
- Region and availability zone (logical and physical mapping, where applicable)
- VM family, current limit, current usage, requested limit, and utilization %
- Blocking deployment timestamp, error code, and failed operation ID
- Forecasted demand window (date range), estimated shortfall, and business impact statement
- Evidence links (CLI output, script export, workbook snapshot), and last validated date

References: [Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request), [Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain).

### Step 1.4: Run explicit multi-subscription analysis and hand off allocation decisions

Run this exercise across all in-scope subscriptions, not a single subscription sample. Forecast quality depends on estate-level variance by subscription and region ([Quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).

At the end of Exercise 1, hand off these outputs to [Lab 3: Allocation](./lab-03-allocation.md) for quota-group allocation decisions:

- Regional and per-family utilization heatmap by subscription
- Candidate subscriptions for quota transfer or rebalance
- Escalation candidates where projected demand exceeds available headroom

### Step 1.5: Run non-compute quota and access checks with public APIs

Run service-specific checks in parallel with compute quota checks. Quota groups cover IaaS compute, not PaaS service limits ([Quota groups](https://learn.microsoft.com/en-us/azure/quotas/quota-groups), [Non-compute quota guide](../operations/non-compute-quotas/README.md)).

**Azure SQL Database usage check (`Microsoft.Sql/locations/usages`):**

```bash
az rest --method GET \
  --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/providers/Microsoft.Sql/locations/eastus/usages?api-version=2023-08-01-preview"
```

Reference: [SQL usage operations](https://learn.microsoft.com/en-us/rest/api/sql/usages/list-by-location).

> **API version hygiene:** This sample uses a preview API version (`2023-08-01-preview`). Before running it in production or automation, verify the current supported `Microsoft.Sql` `usages` API version in the [SQL usage operations reference](https://learn.microsoft.com/en-us/rest/api/sql/usages/list-by-location), and update the command if a newer stable version is available.

**Azure Cosmos DB regional readiness check (regional footprint and account capability):**

```bash
az cosmosdb show \
  --resource-group YOUR_RESOURCE_GROUP \
  --name YOUR_COSMOS_ACCOUNT \
  --query "{writeRegions:writableLocations[].locationName,readRegions:readableLocations[].locationName,capabilities:capabilities[].name}" \
  --output json
```

Reference: [Azure Cosmos DB account management and global distribution](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-manage-database-account), [az cosmosdb reference](https://learn.microsoft.com/en-us/cli/azure/cosmosdb?view=azure-cli-latest).

**Azure Database for PostgreSQL regional capability check (`az postgres flexible-server list-skus`):**

```bash
az postgres flexible-server list-skus \
  --location eastus \
  --output table
```

Reference: [az postgres flexible-server list-skus](https://learn.microsoft.com/en-us/cli/azure/postgres/flexible-server?view=azure-cli-latest#az-postgres-flexible-server-list-skus).

If you need a REST equivalent for automation parity, keep that endpoint mapping as pending validation in this lab revision, and only add it after validating the exact API path and version in Microsoft Learn.

**Azure App Service quota and zonal readiness checks (`Microsoft.Web`):**

```bash
# 1) Subscription-level App Service quota usage surface
az quota usage list \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID \
  --resource-provider Microsoft.Web \
  --output json

# 2) App Service plan zonal readiness surface
az appservice plan show \
  --resource-group YOUR_RESOURCE_GROUP \
  --name YOUR_APP_SERVICE_PLAN \
  --query "{id:id,location:location,sku:sku.name,zoneRedundant:properties.zoneRedundant,maximumNumberOfZones:properties.maximumNumberOfZones,numberOfWorkers:properties.numberOfWorkers,maximumNumberOfWorkers:properties.maximumNumberOfWorkers}" \
  --output json
```

References: [az quota usage list](https://learn.microsoft.com/en-us/cli/azure/quota/usage?view=azure-cli-latest#az-quota-usage-list), [az appservice plan show](https://learn.microsoft.com/en-us/cli/azure/appservice/plan?view=azure-cli-latest#az-appservice-plan-show), [App Service Plans - Get (Microsoft.Web/serverfarms)](https://learn.microsoft.com/en-us/rest/api/appservice/app-service-plans/get?view=rest-appservice-2024-11-01).

**Optional instance-level evidence (physical zone signal from runtime instances):**

```bash
# 3a) List app instances
az rest --method GET \
  --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.Web/sites/YOUR_APP_NAME/instances?api-version=2024-11-01"

# 3b) Get one instance detail
az rest --method GET \
  --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.Web/sites/YOUR_APP_NAME/instances/YOUR_INSTANCE_ID?api-version=2024-11-01"
```

References: [Web Apps - List Instance Identifiers](https://learn.microsoft.com/en-us/rest/api/appservice/web-apps/list-instance-identifiers?view=rest-appservice-2024-11-01), [Web Apps - Get Instance Info](https://learn.microsoft.com/en-us/rest/api/appservice/web-apps/get-instance-info?view=rest-appservice-2024-11-01).

**Interpretation signals and evidence fields:**

- **Quota signal (`Microsoft.Web`):** Track current usage versus limit for App Service quota entries returned by `az quota usage list`; flag an escalation candidate when projected demand exceeds available headroom in the forecast window.
- **Plan zonal readiness signal:** Use `zoneRedundant=true` as the configuration signal that the plan is set for zone balancing; treat `zoneRedundant=false` as non-zonal configuration for that plan. Validate worker headroom with `numberOfWorkers` versus `maximumNumberOfWorkers` from the same plan output.
- **Maximum zones evidence field:** Capture `maximumNumberOfZones` from plan output when present, and record `null` or missing explicitly when the provider response doesn't expose it for the selected SKU, region, or API shape.
- **Runtime placement evidence (optional):** Capture per-instance `properties.physicalZone` from the instance APIs as supporting evidence for where active workers are running.
- **Minimum evidence record:** Subscription ID, resource group, app name, plan name, region, timestamp, command used, raw JSON output link, `zoneRedundant`, `maximumNumberOfZones`, `numberOfWorkers`, `maximumNumberOfWorkers`, and any returned `physicalZone` values.

**Azure SQL Managed Instance placeholder:**

API details for a reproducible regional readiness check are pending validation in this lab revision. Don't add speculative commands. Use documented APIs only once validated and cited.

---

## Exercise 2: Analyze compute utilization with Azure Monitor

**Objective:** Measure actual CPU and memory consumption to forecast peak demand and right-size commitments.

Quota and usage tell you how many VMs you can and are running. Utilization metrics tell you how hard those VMs are working—critical for forecasting when you'll hit scaling limits.

### Step 2.1: Query CPU metrics across VMs

Query aggregate CPU utilization across all VMs using [VM insights](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-overview) data in Log Analytics:

```kusto
InsightsMetrics
| where Origin == "vm.azm.ms"
| where Namespace == "Processor"
| where Name == "UtilizationPercentage"
| where TimeGenerated > ago(30d)
| summarize AvgCPU = avg(Val), MaxCPU = max(Val), P95CPU = percentile(Val, 95) by Computer, bin(TimeGenerated, 1h)
| render timechart
```

Run this in the [Log Analytics workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview) connected to your VMs, or via CLI:

```bash
az monitor log-analytics query \
  --workspace YOUR_WORKSPACE_ID \
  --analytics-query "InsightsMetrics | where Origin == 'vm.azm.ms' | where Namespace == 'Processor' | where Name == 'UtilizationPercentage' | where TimeGenerated > ago(30d) | summarize AvgCPU = avg(Val), MaxCPU = max(Val), P95CPU = percentile(Val, 95) by Computer, bin(TimeGenerated, 1h)" \
  --output table
```

For a single VM's platform metrics (no Log Analytics required):

```bash
az monitor metrics list \
  --resource "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.Compute/virtualMachines/YOUR_VM_NAME" \
  --metrics "Percentage CPU" \
  --interval PT1H \
  --aggregation Average \
  --output table
```

See the [InsightsMetrics table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/insightsmetrics) for the full list of VM insights namespaces and metric names.

Reference the [capacity planning section of the Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning) for guidance on which metrics to track.

### Step 2.2: Identify utilization patterns

Look for:
- **Peak hours:** When does CPU spike? This shows your scaling trigger points.
- **Baseline:** What's the minimum CPU during off-peak? This tells you static vs. variable cost.
- **Trend:** Is utilization growing week-over-week? This informs forecast slope.
- **P95:** 95th percentile tells you the threshold for "normal" workload bursts. Budget capacity for this, not average.

References: [InsightsMetrics table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/insightsmetrics), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning).

### Step 2.3: Establish growth trends

Track week-over-week utilization changes from your monitoring data. The growth trend feeds directly into your quota increase cadence—if utilization is climbing, schedule quota requests before you hit your operator-defined 80% triage threshold from Exercise 1 ([How to monitor quotas and generate alerts](https://learn.microsoft.com/en-us/azure/quotas/how-to-guide-monitoring-alerting), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).

---

## Exercise 3: Pull savings plan recommendations

**Objective:** Use Azure Cost Management's Benefit Recommendations API to forecast commitment levels that match your utilization forecast.

Set commitment targets from your own historical usage and from recommendation surfaces, including [Azure Reservations guidance](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), [savings plan guidance](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview), and [FinOps rate optimization guidance](https://www.finops.org/framework/capabilities/rate-optimization/). This exercise focuses on the savings plan recommendation layer in that decision.

### Step 3.1: Query savings plan recommendations

```powershell
.\scripts/rate/Get-BenefitRecommendations.ps1 `
  -BillingScope "/subscriptions/YOUR_SUBSCRIPTION_ID" `
  -LookBackPeriod "Last30Days" `
  -Term "P3Y"
```

Parameters:
- **BillingScope:** billing account (for EA), subscription, or resource group. Narrower scopes give more targeted recommendations ([scripts/rate/README.md](../../scripts/rate/README.md), [Get-BenefitRecommendations script](../../scripts/rate/Get-BenefitRecommendations.ps1)).
- **LookBackPeriod:** Last7Days / Last30Days / Last60Days. Use 30+ days for reliable trending ([scripts/rate/README.md](../../scripts/rate/README.md), [Get-BenefitRecommendations script](../../scripts/rate/Get-BenefitRecommendations.ps1)).
- **Term:** P1Y (1-year) or P3Y (3-year). 3-year has higher discount but less flexibility ([scripts/rate/README.md](../../scripts/rate/README.md), [Get-BenefitRecommendations script](../../scripts/rate/Get-BenefitRecommendations.ps1), [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations)).

**Output fields:**
- `commitmentAmount`: Recommended commitment amount returned by the API.
- `commitmentGranularity`: Time granularity used for the commitment amount.
- `savingsPercentage`: Estimated savings percentage for the look-back period.
- `coveragePercentage`: Estimated coverage percentage for the look-back period.
- `averageUtilizationPercentage`: Estimated average utilization percentage for the look-back period.
- `overageCost`: Estimated overage cost for usage beyond the commitment.
- `wastageCost`: Estimated unused portion of the benefit cost.

Field names and descriptions above are based on the Cost Management Benefit Recommendations API schema and the script reference used in this repo ([Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations), [scripts/rate/README.md](../../scripts/rate/README.md)).

### Step 3.2: Interpret the recommendation

Example output (illustrative scenario, not a platform default target):
- Hourly commitment: $500
- Coverage: 85%
- Savings: 40%
- Wastage: $12/day

This means:
- Buy $500/hour of compute commitment (1-year or 3-year term)
- This covers 85% of your typical hourly usage
- The remaining 15% runs at pay-as-you-go rates unless covered by another pricing benefit
- You're leaving ~$12/day on the table to underutilized reserved capacity

**Decision point (illustrative):** Do you accept 85% coverage to save 40%, or do you need tighter alignment? If your forecast shows 10% growth over the next quarter, and coverage is already 85%, you might increase commitment targets to limit expected overage risk as utilization climbs.

### Step 3.3: Validate against your forecast

Cross-check the API's recommendation against your capacity forecast from Exercise 2:
- Example: if your forecast growth rate suggests 12% month-over-month increase, and the API recommendation maps to 85% coverage, plan a commitment refresh window before projected overage risk crosses your internal threshold.
- Schedule your next forecast refresh accordingly.

Reference the [FinOps Framework planning and estimating guidance](https://www.finops.org/framework/capabilities/planning-estimating/) and [Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations) for structuring this decision.

---

## Exercise 4: Assess storage and PaaS costs and forecast

**Objective:** Analyze storage, disk, and PaaS service costs across your estate, then forecast growth based on recent trends.

Storage and PaaS services scale differently from compute. Understanding which resources drive cost—and their growth rate—prevents surprise bill spikes and ensures you allocate capacity correctly across regions. Use [Cost Management cost analysis](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/quick-acm-cost-analysis) to query cost data across service categories.

### Step 4.1: Query storage costs with Cost Management

Use the Azure CLI to pull storage costs grouped by subscription and resource for the last billing period:

```bash
az rest --method POST \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/YOUR_BILLING_ACCOUNT_ID/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{
    "type": "ActualCost",
    "timeframe": "TheLastBillingMonth",
    "dataset": {
      "granularity": "None",
      "filter": {
        "dimensions": { "name": "ServiceName", "operator": "In", "values": ["Storage"] }
      },
      "grouping": [
        { "type": "Dimension", "name": "SubscriptionName" },
        { "type": "Dimension", "name": "ResourceId" }
      ],
      "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } }
    }
  }'
```

Reference the [Cost Management Query API](https://learn.microsoft.com/en-us/rest/api/cost-management/query/usage) for request body schema and supported dimensions.

Alternatively, in the Azure portal:
1. Go to **Cost Management** > **Cost analysis**
2. Select **Group by** > **Service name**, then filter to **Storage**
3. Select the **DailyCosts** view to see the trend over the billing period

For recurring analysis, [create a Cost Management export](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-export-acm-data) to automatically deliver cost data to a storage account on a schedule. This gives you a historical dataset for trend analysis without manual queries.

### Step 4.2: Identify growth drivers

For each high-cost storage resource:
- Compare this month's cost to the previous month's cost
- Calculate growth rate: (Current - Previous) / Previous * 100
- If growth > 10% per month, flag for capacity planning

Example: An analytics storage account grew from 500 GB to 600 GB in 30 days = 20% growth. At that rate, it reaches 1 TB in ~4 months. Plan ingestion limits, archival policies, or regional replica targets now.

Storage cost varies by tier (hot, cool, archive), replication (LRS, GRS, RA-GRS), and region. Drill down into high-growth accounts and determine if cost is driven by increasing volume, access pattern shifts, or replication overhead.

### Step 4.3: Forecast Premium SSD v2 disk costs

[Premium SSD v2](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types#premium-ssd-v2) disks bill separately for capacity, throughput, and IOPS—each dimension scales independently. This makes forecasting more granular than standard managed disks.

Query disk costs with:

```bash
az rest --method POST \
  --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{
    "type": "ActualCost",
    "timeframe": "TheLastBillingMonth",
    "dataset": {
      "granularity": "None",
      "filter": {
        "dimensions": { "name": "MeterSubCategory", "operator": "In", "values": ["Premium SSD v2"] }
      },
      "grouping": [{ "type": "Dimension", "name": "ResourceId" }],
      "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } }
    }
  }'
```

When forecasting Premium SSD v2 growth, track three dimensions separately:
- **Capacity (GiB):** Grows with data volume—forecast from ingestion rate
- **Provisioned throughput (MBps):** Grows with workload IO demands—forecast from performance baselines
- **Provisioned IOPS:** Grows with transaction density—forecast from application telemetry

Each dimension has its own per-unit price, so a workload that's IOPS-heavy but storage-light has a different cost profile than one that's capacity-heavy. Model each dimension independently for accurate projections.

### Step 4.4: Forecast Azure Cosmos DB costs

[Azure Cosmos DB](https://learn.microsoft.com/en-us/azure/cosmos-db/cost-management) uses request units (RUs) as its primary capacity metric. Forecasting Cosmos DB costs requires tracking RU consumption patterns alongside storage growth.

Query Cosmos DB costs with:

```bash
az rest --method POST \
  --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{
    "type": "ActualCost",
    "timeframe": "TheLastBillingMonth",
    "dataset": {
      "granularity": "None",
      "filter": {
        "dimensions": { "name": "ServiceName", "operator": "In", "values": ["Azure Cosmos DB"] }
      },
      "grouping": [{ "type": "Dimension", "name": "ResourceId" }],
      "aggregation": { "totalCost": { "name": "Cost", "function": "Sum" } }
    }
  }'
```

Key forecasting dimensions for Cosmos DB:
- **Provisioned throughput (RU/s):** If you use [provisioned throughput](https://learn.microsoft.com/en-us/azure/cosmos-db/set-throughput), forecast from peak RU consumption trends in Azure Monitor. Autoscale accounts bill for the max RU/s reached per hour.
- **Serverless consumption:** If you use [serverless](https://learn.microsoft.com/en-us/azure/cosmos-db/serverless), forecast from total RU consumption per billing period. Costs scale linearly with request volume.
- **Storage:** Cosmos DB bills per GB stored. Forecast from data growth rate—partition splits don't change cost, but multi-region writes multiply storage charges per replica.

For stamp-based deployments, treat this as a workload-specific operator assumption: if your data model assigns throughput and storage boundaries per tenant, Cosmos DB cost can track tenant count more closely than user count. Validate that assumption with your own per-tenant RU telemetry before using it in forecasts ([Set throughput on Azure Cosmos DB containers and databases](https://learn.microsoft.com/en-us/azure/cosmos-db/set-throughput), [Azure Cosmos DB serverless](https://learn.microsoft.com/en-us/azure/cosmos-db/serverless), [Azure Cosmos DB cost management](https://learn.microsoft.com/en-us/azure/cosmos-db/cost-management)).

### Step 4.5: Map forecasts to workload types

Combine your storage, disk, and PaaS cost data into a unified forecast:
- **Azure Storage:** Forecast by tier, replication, and transaction volume
- **Premium SSD v2:** Forecast by capacity, throughput, and IOPS independently
- **Azure Cosmos DB:** Forecast by RU consumption pattern and storage growth

Cross-reference these forecasts with your compute stamp projections from Exercise 5—PaaS costs often scale proportionally with stamp count, but the relationship isn't always linear. A new stamp may need pre-provisioned Cosmos DB throughput before tenants migrate to it.

### Step 4.6: Add storage scaling and partitioning architecture guidance

Document the storage scaling and partitioning design that matches each high-growth workload:

- Storage account sharding or split strategy by workload boundary and region
- Partition-key strategy for high-volume PaaS data paths, including expected hot-partition risk
- Replication pattern (for example, LRS, GRS, or RA-GRS) and the cost-to-recovery tradeoff

Use service documentation to justify the design choices and scaling constraints ([Storage scalability targets](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#scalability-targets-for-standard-storage-accounts), [Azure Cosmos DB partitioning overview](https://learn.microsoft.com/en-us/azure/cosmos-db/partitioning-overview)).

### Step 4.7: Define storage escalation triggers and evidence requirements

Create explicit escalation triggers for storage and PaaS growth:

- Trigger when forecasted growth crosses a documented service limit or support-reviewed operational threshold.
- Trigger when projected cost variance crosses your FinOps guardrail for the planning window.
- Trigger when regional readiness checks show a required service isn't ready in a target region.

For each trigger, capture required evidence: 30-day trend, current usage, forecast method, target region, and requested change ([Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request), [FinOps planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/)).

> **Implementation note:** Don't hardcode unverified numeric limits in lab assets. Pull limits from current Microsoft Learn documentation or live API output each run, then cite the source used ([Azure REST API reference](https://learn.microsoft.com/en-us/rest/api/azure/), [Azure limits and quotas](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits)).

---

## Exercise 5: Map forecasts to scale units

**Objective:** Translate compute and storage forecasts into capacity per deployment stamp or region, identifying when you'll exceed current allocation.

ISVs often deploy multiple independent instances of their platform across regions (the [Deployment Stamps pattern](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern)). Forecasting capacity per stamp—not only the aggregate—ensures you don't overload one region.

### Step 5.1: Define your stamp architecture

Document your deployment unit. Example:
- **Stamp composition:**
  - 3 API frontend VMs (Standard_D2s_v3, autoscale 3–10)
  - 1 data platform VM (Standard_D8s_v3, fixed)
  - 1 cache VM (Standard_E4s_v3, fixed)
  - 1 storage account (500 GB hot, 2 TB cool for backups)
- **Stamp capacity limit:** 10,000 concurrent users
- **Deployment regions:** eastus, westus2, and northeurope

### Step 5.2: Forecast per-stamp demand

Use utilization data from Exercise 2 to estimate:
- Concurrent users / peak demand per week
- Storage growth per region

Example forecast:
- **Week 1:** 15,000 users across 2 stamps deployed (1 eastus, 1 westus2)—each stamp handles up to 10,000 users, so you're at 75% capacity
- **Week 12 (end of quarter):** 22,000 users—2 stamps can't cover the load, so deploy a 3rd stamp in northeurope

### Step 5.3: Calculate quota and commitment needs

From Exercise 1, your quota per region: 50 Standard_D2s_v3, 10 Standard_D8s_v3, 10 Standard_E4s_v3.

With 2 stamps fully deployed:
- In-use: 6 D2s, 2 D8s, 2 E4s
- Headroom: 44 D2s, 8 D8s, 8 E4s

Forecast shows you need 3 stamps by week 12 (9 D2s, 3 D8s, 3 E4s in-use). You're safe. But if westus2 is your high-demand region, you may hit quota limits in that region before others—request regional quota increase now.

From Exercise 3, your savings plan commitment is $500/hour. With 2 stamps:
- Compute cost: ~$300/hour at on-demand
- Your commitment covers: $300 / $500 = 60% (acceptable)

At 3 stamps (week 12):
- Compute cost climbs to ~$450/hour
- Commitment covers: $450 / $500 = 90% (tight but viable)

Decision: Buy additional commitment buffer now for the 3rd stamp, or risk overages in week 12.

### Step 5.4: Schedule capacity milestones

Create a table:

| Milestone | Timestamp | Stamps Deployed | Quota Headroom (D2s) | Commitment Buffer | Action |
|-----------|-----------|-----------------|----------------------|-------------------|--------|
| Current | Week 1 | 2 | 44 | $200/hr | Baseline |
| Q1 End | Week 12 | 3 | 41 | $50/hr | Request +10 D2s quota; buy +$200/hr commitment |
| Q2 End | Week 26 | 4 | 38 | Risk | Plan regional expansion |

Reference the [Deployment Stamps pattern](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern) and [Well-Architected scaling guidance](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling) for stamp-based capacity planning.

### Step 5.5: Branch for target-region-unavailable scenarios

If the target region is unavailable, run this branch before finalizing milestone dates:

1. **Select escape region options** and map each option to required quota, service readiness, and expected latency impact ([Region access request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), [Deployment Stamps pattern](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern)).
2. **Assess surge handling implications** for failover or temporary concentration in remaining regions, including autoscale and quota pressure in those regions ([Well-Architected scaling guidance](https://learn.microsoft.com/en-us/azure/well-architected/reliability/scaling), [Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests)).
3. **Recalculate timeline impact** from supply constraints, including region access approval lead time and datacenter capacity constraints such as power and infrastructure pressure in the target geography ([Region access request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process)).

Update your milestone table with a primary plan and an escape-region plan so procurement and allocation can proceed without reopening forecast assumptions.

---

## Exercise 6: Review the Cost Optimization workbook

**Objective:** Use Azure Advisor's Cost Optimization workbook to surface right-sizing and underutilization recommendations.

Azure Advisor and the Cost Optimization workbook provide cost recommendation signals you can review alongside your own telemetry and forecast model ([Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization), [Advisor VM and VMSS cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations)).

### Step 6.1: Open the workbook

1. In the Azure portal, go to **Azure Advisor**
2. Select **Cost Optimization** tab
3. Open **Cost Optimization workbook** (link in the top toolbar)

Reference the [Cost Optimization workbook documentation](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization) for setup details.

### Step 6.2: Review recommendation categories

The workbook typically surfaces recommendation categories across compute, storage, and commitment optimization, including Advisor recommendation tiles and usage optimization views ([Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization)).

Examples you should evaluate:

**Underutilized VMs:**
- Advisor can recommend VM and VMSS resize or shutdown actions for low-utilization resources based on its documented utilization criteria and lookback configuration ([Advisor VM and VMSS cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations)).
- Decision: Right-size (move to smaller SKU), turn off during off-hours, or delete
- Impact on forecast: Treat underutilized recommendations as an efficiency signal, then validate with your own CPU, memory, and network telemetry before updating per-stamp efficiency assumptions ([Advisor VM and VMSS cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations)).

**Unattached disks:**
- Disks not connected to any VM, still accruing cost
- Decision: Delete if no snapshot backups rely on them
- Impact: Cost reduction without compute capacity impact ([Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization)).

**Oversized database and storage:**
- Databases and storage accounts with excess reserved capacity
- Decision: Right-size tier or replication settings
- Impact: Reduces storage forecasting headroom; ensure measured growth justifies existing allocation ([Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization)).

**Unused reservations:**
- Commitments (RI / Savings Plans) with low utilization
- Decision: Evaluate if workload pattern changed; may need to trim commitment or accelerate utilization
- Impact: Informs the next commitment purchase decision (Exercise 3) ([Cost Optimization workbook](https://learn.microsoft.com/en-us/azure/advisor/advisor-workbook-cost-optimization), [Azure Reservations](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), [Azure savings plan for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)).

### Step 6.3: Cross-check against your forecast

For each recommendation:
1. Does it contradict your utilization forecast from Exercise 2?
   - If Advisor flags underutilization but your metrics show growth, treat that as a validation task before making SKU changes ([Advisor VM and VMSS cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).
2. Does it reveal an allocation misalignment?
   - If one region shows persistent underutilization while demand grows elsewhere, validate stamp placement and regional distribution assumptions before you rebalance ([Deployment Stamps pattern](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/overview#deployment-stamps-pattern), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).
3. Does it confirm your savings plan coverage?
   - If recommendation signals show persistent underutilization of commitments, re-check renewal targets against measured coverage and wastage trends ([Azure Reservations](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), [Azure savings plan for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview), [FinOps planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/)).

### Step 6.4: Feed findings into procurement

Document findings in your capacity planning tracker:
- Right-sizing actions: Record the recommendation, expected savings estimate, and target SKU change, then validate against your effective rates before actioning because Advisor savings are based on retail rates ([Advisor VM and VMSS cost recommendations](https://learn.microsoft.com/en-us/azure/advisor/advisor-cost-recommendations)).
- Headroom recovery: Consolidation frees X quota units per region and can delay the next quota increase window ([Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning)).
- Commitment efficiency: Compare current commitment coverage against measured utilization, then adjust the next purchase target to reduce overage and wastage risk ([Benefit Recommendations API](https://learn.microsoft.com/en-us/rest/api/cost-management/benefit-recommendations), [Azure savings plan for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview), [Azure Reservations](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations)).

### Step 6.5: Add dev and test technical validation checkpoint

Before closing the lab, add one validation row for each forecast action that changes dev or test capacity settings:

- Environment and scope (subscription, region, and service)
- Planned change (quota, SKU, throughput, storage tier, or reservation target)
- Baseline measurement (query output timestamp and value)
- Post-change validation query and expected threshold
- Rollback trigger and evidence link

Use the same evidence depth you apply to production checks so forecast assumptions stay testable across environments ([Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)).

---

## Wrap-up: From forecast to procurement

You've now gathered all the signals needed to make infrastructure commitments with confidence:

1. **Quota and usage (Exercise 1):** Know what you're allowed to run and what you're running
2. **Utilization patterns (Exercise 2):** Know the growth rate and peak load patterns
3. **Savings plan recommendations (Exercise 3):** Know the optimal commitment level and discount
4. **Storage and PaaS trends (Exercise 4):** Know which storage, disk, and PaaS resources drive cost and when they'll require scale action
5. **Stamp-level forecasts (Exercise 5):** Know when to deploy new stamps or request regional quota
6. **Advisor recommendations (Exercise 6):** Know where to recover efficiency and trim waste

**Escalation evidence path:**

When forecast outputs identify blockers, package technical evidence first, then open the correct Azure support path:

- Classify blocker type: quota limit, region access restriction, zonal enablement restriction, or reservation mismatch ([Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Region access request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/region-access-request-process), [Zonal enablement request process](https://learn.microsoft.com/en-us/troubleshoot/azure/general/zonal-enablement-request-for-restricted-vm-series), [Capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview)).
- Attach reproducible evidence: failed deployment timestamp, operation ID, requested versus current limits, region and zone target, and forecasted shortfall window ([Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request)).
- Map blocker-to-request type so each item routes to the matching support request category without rework ([Create an Azure support request](https://learn.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request)).

Reference: [Support escalation guide](../operations/escalation/README.md).

**Next steps:**
- Refresh these analyses monthly. Create a recurring task to run Exercises 1, 2, and 6 each month.
- Use 3-month utilization trends to refresh reservation and savings-plan targets, and update commitment levels when measured coverage and wastage drift from your forecast bounds.
- Align stamps with regions: review Exercise 5 data in your billing API to confirm actual per-region deployment matches your forecast assumptions.
- Archive historical CSVs (quota, utilization, storage) to track forecast accuracy and refine your projections for next quarter.

References: [Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain), [Azure Reservations](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), [Azure savings plan for compute](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview).

**FOCUS exports and reservation sizing:**
If you use FOCUS (FinOps Open Cost and Usage Specification) exports from Cost Management, map commitment discount utilization to your reservation sizing model. See the [FOCUS exports overview](https://learn.microsoft.com/en-us/cloud-computing/finops/focus/overview) for guidance on structuring cost data for forecasting and commitment planning.

**Operationalization cadence:**
Define and run a recurring review cadence for utilization analysis, projection updates, and forecast validation so quota and commitment decisions stay aligned with measured demand and delivery timelines ([Capacity planning](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/capacity-planning), [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)).

**Release gates:**
Before each stamp deployment, validate three gates:
1. Quota headroom ≥ scale unit requirement (from Exercise 5)
2. CRG reserved quantity ≥ deployment target (if applicable)
3. Budget posture allows the spend increase

These gates prevent quota exhaustion, commitment overages, and budget surprises when you enforce them before each release ([Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview), [Use cost alerts to monitor usage and spending](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending), [Workload supply chain](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/workload-supply-chain)).

References: [Per-VM quota requests](https://learn.microsoft.com/en-us/azure/quotas/per-vm-quota-requests), [Capacity reservation overview](https://learn.microsoft.com/en-us/azure/virtual-machines/capacity-reservation-overview), [Use cost alerts to monitor usage and spending](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-alerts-monitor-usage-spending).

The output of forecasting feeds directly into:
- **Allocation decisions:** How much quota and commitment per region?
- **Procurement timing:** When to renew savings plans or request capacity increases?
- **Architecture reviews:** Are stamp capacities sized correctly, or is one region a bottleneck?

For deeper guidance on the FinOps discipline around forecasting, refer to the [FinOps Framework planning and estimating section](https://www.finops.org/framework/capabilities/planning-estimating/).
