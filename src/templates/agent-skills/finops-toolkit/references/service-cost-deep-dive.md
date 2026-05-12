---
name: service-cost-deep-dive
description: Performs a detailed deep dive into a specific service using FinOps hubs cost, price, and recommendation data.
author: FinOps Toolkit Team
version: 1.1.0
license: Apache-2.0
---

# Service cost deep dive

## Purpose

Use this reference to investigate one service in depth, explain what is driving cost, and identify practical optimization actions in a FinOps Toolkit / FinOps hubs environment.

This deep dive keeps the original intent of service-level analysis, but uses validated FinOps hubs patterns:

- `Costs()` as the primary analytical surface
- `Prices()` when unit-price validation is relevant
- `Recommendations()` when optimization guidance is relevant
- FinOps hubs fields such as `ServiceName`, `ResourceName`, `ResourceType`, `RegionName`, `SubAccountName`, `x_ResourceGroupName`, `x_UsageType`, and `Tags[...]`

## Grounding and prerequisites

Before starting:

1. Review the schema guidance in [finops-hub-database-guide.md](./queries/finops-hub-database-guide.md).
2. Review the query catalog in [INDEX.md](./queries/INDEX.md).
3. Start from [costs-enriched-base.kql](./queries/catalog/costs-enriched-base.kql) for any custom drilldown that needs enriched fields.
4. Use [top-services-by-cost.kql](./queries/catalog/top-services-by-cost.kql) to confirm the exact `ServiceName` values in scope.
5. Use [service-price-benchmarking.kql](./queries/catalog/service-price-benchmarking.kql) when you need price and realized-savings context.

Inspect which populated fields, tags, and columns are available in your hub before assuming business context exists.
Treat `x_CostCenter`, `x_Project`, `Tags["environment"]`, and `Tags['team']` as observed or optional fields, not guaranteed schema requirements.
If available, use those fields for attribution. If populated, use them to explain ownership. When populated, use them carefully and call out blanks honestly.

## When to use

- “Analyze my Azure SQL costs”
- “Deep dive into Virtual Machines spending”
- “Why is Storage getting more expensive?”
- “Break down this service by subscription, region, and resource group”
- “Show the specific resources behind a service spike”
- “Benchmark the service’s price and savings profile”
- “Find optimization opportunities for one service”

## Workflow

### Step 1: Identify the exact service

Use the catalog query first if the service label is uncertain.

```kusto
// Start with the catalog pattern from top-services-by-cost.kql
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by ServiceName
| top 20 by EffectiveCost desc
```

Pick the exact `ServiceName` that matches the user’s request before drilling deeper.

### Step 2: Establish the service baseline

Use `Costs()` as the primary surface for total cost and trend.

```kusto
let targetService = 'Virtual Machines';
let startDate = startofmonth(ago(90d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| where ServiceName == targetService
| summarize TotalEffectiveCost = sum(EffectiveCost),
            TotalBilledCost = sum(BilledCost),
            TotalListCost = sum(ListCost),
            TotalSavings = sum(x_TotalSavings)
```

```kusto
let targetService = 'Virtual Machines';
let startDate = startofmonth(ago(90d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by Day = startofday(ChargePeriodStart)
| order by Day asc
```

Calculate:

- Total service cost
- Daily or monthly trend
- Share of total spend
- Realized savings already present in `x_TotalSavings`

### Step 3: Break down the service by operational dimensions

Start with the enriched base pattern from `costs-enriched-base.kql` when you need more context.

**By subscription/account**

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by SubAccountName
| order by EffectiveCost desc
```

**By region**

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by RegionName
| order by EffectiveCost desc
```

**By resource group**

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by x_ResourceGroupName
| order by EffectiveCost desc
```

**By resource and resource type**

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by ResourceName, ResourceType
| top 50 by EffectiveCost desc
```

**By usage pattern**

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| summarize EffectiveCost = sum(EffectiveCost) by x_UsageType
| order by EffectiveCost desc
```

Use these breakdowns to answer:

- Which `SubAccountName` owns the cost?
- Which `RegionName` is driving spend?
- Which `x_ResourceGroupName` clusters the spend?
- Which `ResourceName` and `ResourceType` are the biggest contributors?
- Which `x_UsageType` explains the charge pattern?

### Step 4: Attribute cost with business context

Business fields are often optional or only partially populated.

Inspect which populated fields or tags are present before choosing your allocation lens.

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| project x_CostCenter, x_Project, Tags
| take 20
```

If populated, use business context like this:

```kusto
let targetService = 'Virtual Machines';
Costs()
| where ServiceName == targetService
| extend Environment = tostring(Tags["environment"]),
         Team = tostring(Tags['team'])
| summarize EffectiveCost = sum(EffectiveCost)
    by Environment, Team, x_CostCenter, x_Project
| order by EffectiveCost desc
```

Call out blank or missing values explicitly. Untagged or unattributed cost is usually a governance finding, not just a reporting inconvenience.

### Step 5: Investigate the service spike or trend change

When the service changed recently, compare periods and isolate the dimensions that moved.

```kusto
let targetService = 'Virtual Machines';
let recentStart = startofmonth(ago(30d));
let priorStart = startofmonth(ago(60d));
let recent =
    Costs()
    | where ChargePeriodStart >= recentStart and ChargePeriodStart < now()
    | where ServiceName == targetService
    | summarize RecentCost = sum(EffectiveCost) by RegionName, x_ResourceGroupName, ResourceType;
let prior =
    Costs()
    | where ChargePeriodStart >= priorStart and ChargePeriodStart < recentStart
    | where ServiceName == targetService
    | summarize PriorCost = sum(EffectiveCost) by RegionName, x_ResourceGroupName, ResourceType;
recent
| join kind=fullouter prior on RegionName, x_ResourceGroupName, ResourceType
| extend RecentCost = coalesce(RecentCost, 0.0),
         PriorCost = coalesce(PriorCost, 0.0),
         Delta = RecentCost - PriorCost
| order by Delta desc
```

This highlights whether the change is driven by region expansion, new resource groups, or a different `ResourceType` mix.

### Step 6: Validate unit-price and savings posture

Use the service-price-benchmarking pattern first. If you need lower-level unit-price validation, use `Prices()` against the SKU identifiers surfaced from `Costs()`.

```kusto
let targetService = 'Virtual Machines';
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
let targetPrices =
    Costs()
    | where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
    | where ServiceName == targetService
    | summarize by SkuPriceId;
Prices()
| where SkuPriceId in (targetPrices)
| project SkuPriceId,
          ListUnitPrice,
          ContractedUnitPrice,
          x_EffectiveUnitPrice,
          PricingUnit,
          x_SkuMeterName,
          x_SkuRegion,
          x_SkuTerm
```

Use this to explain:

- Whether unit prices look reasonable
- Whether negotiated or commitment discounts are already helping
- Whether price changes or SKU mix shifts are contributing to the increase

### Step 7: Pull optimization recommendations when relevant

Use `Recommendations()` when the service deep dive should end with a concrete action list.

```kusto
let targetService = 'Virtual Machines';
Recommendations()
| where x_SourceProvider == 'Microsoft'
| extend ServiceName = tostring(x_RecommendationDetails.ServiceName),
         RegionName = tostring(x_RecommendationDetails.RegionName),
         ResourceType = tostring(x_RecommendationDetails.ResourceType),
         ResourceName = tostring(x_RecommendationDetails.ResourceName)
| where ServiceName =~ targetService or ResourceType has targetService
| project x_RecommendationDate,
          ServiceName,
          RegionName,
          ResourceType,
          ResourceName,
          x_EffectiveCostBefore,
          x_EffectiveCostAfter,
          x_EffectiveCostSavings
| order by x_EffectiveCostSavings desc
```

Recommendation payload details can be optional. If available, use them to connect the service-level story to a short list of remediations.

## Service-specific interpretation guidance

### Compute services

Focus on:

- `ResourceType` mix
- `x_UsageType` patterns
- rightsizing candidates
- commitment discount coverage
- stop/deallocate opportunities

Useful signals:

- high spend concentrated in a few `ResourceName` values
- one `RegionName` carrying disproportionate cost
- expensive usage concentrated in one `x_ResourceGroupName`

### Storage services

Focus on:

- growth by `ResourceName`
- region duplication
- hot vs. cooler usage patterns when visible in `x_UsageType`
- price posture using `Prices()` for the affected SKUs

### Database services

Focus on:

- steady-state growth
- non-production cost hiding in the wrong `Tags["environment"]`
- expensive editions or resource families by `ResourceType`
- savings opportunities surfaced in `Recommendations()`

### Network and transfer-heavy services

Focus on:

- `RegionName` concentration
- abrupt period-over-period movement
- resource-group concentration via `x_ResourceGroupName`
- whether the cost is spread broadly or driven by a few `ResourceName` entries

## Output format

Use this structure in the final response.

### 1. Executive summary

- Service analyzed: exact `ServiceName`
- Total cost for period
- Trend direction and magnitude
- Biggest cost driver
- Biggest optimization opportunity

### 2. Cost breakdown

- Top `SubAccountName` values
- Top `RegionName` values
- Top `x_ResourceGroupName` values
- Top `ResourceName` / `ResourceType` pairs
- Top `x_UsageType` values if available

### 3. Business attribution

- `x_CostCenter` and `x_Project` if populated
- `Tags["environment"]` and `Tags['team']` if populated
- clear note for unattributed cost

### 4. Pricing and savings

- observed list vs. contracted vs. effective posture
- realized savings from the service-price-benchmarking pattern
- whether unit-price review via `Prices()` changed the interpretation

### 5. Recommendations

- recommendation-backed actions from `Recommendations()` where available
- service-specific quick wins
- governance follow-ups for blank tags or weak attribution

## Best practices

1. Use `Costs()` first; only branch into `Prices()` or `Recommendations()` when the question requires it.
2. Confirm the exact `ServiceName` instead of guessing from a friendly service label.
3. Start broad, then narrow to `RegionName`, `SubAccountName`, `x_ResourceGroupName`, `ResourceType`, and `ResourceName`.
4. Inspect which populated fields and tags are available before promising allocation detail.
5. Treat business context as observed data, not guaranteed schema.
6. Use `costs-enriched-base.kql` when you need a reusable enriched baseline.
7. Use `top-services-by-cost.kql` for service discovery and `service-price-benchmarking.kql` for savings context.

## See also

- [finops-hub-database-guide.md](./queries/finops-hub-database-guide.md)
- [INDEX.md](./queries/INDEX.md)
- [costs-enriched-base.kql](./queries/catalog/costs-enriched-base.kql)
- [top-services-by-cost.kql](./queries/catalog/top-services-by-cost.kql)
- [service-price-benchmarking.kql](./queries/catalog/service-price-benchmarking.kql)
