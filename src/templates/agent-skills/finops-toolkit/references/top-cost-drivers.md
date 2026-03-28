---
name: top-cost-drivers
description: Identifies and ranks the biggest contributors to FinOps hubs cost across services, subscriptions, regions, resource groups, billing hierarchy, and optional tags to help prioritize optimization work
author: FinOps Toolkit Team
version: 1.0.0
license: Apache-2.0
---

# Top cost drivers

## Purpose
Use FinOps hubs data to identify the largest contributors to cost, measure how concentrated spend is, and prioritize the next optimization or allocation investigation.

## When to use
- "What are my biggest costs?"
- "Where is most of my spend going?"
- "What should I optimize first?"
- "Show me top spending by service, subscription, region, or resource group"
- Monthly business reviews, budget planning, and allocation reviews
- Keywords: top, biggest, largest, highest, cost drivers, most expensive, concentration, ranking

## Prerequisites
- Confirm the hub connection and reporting window before starting.
- Use `references/queries/finops-hub-database-guide.md` to verify available FinOps hubs fields and enrichment columns.
- Start with `costs-enriched-base.kql` if you need a custom ranking or want one reusable base for several drill-downs.

## Recommended ranking dimensions
Choose the first grouping that best matches the question:

- `ServiceName` for top Azure service cost drivers
- `SubAccountName` for top subscriptions or sub-accounts
- `RegionName` for regional rollups
- `x_ResourceGroupName` for resource-group ranking
- `x_BillingProfileName` and `x_InvoiceSectionName` for billing hierarchy and allocation views

## Analysis workflow

### Step 1: Scope the request
Confirm:
- analysis period
- filters already in scope
- whether the user wants technical drivers, billing hierarchy drivers, or both
- whether optional business tags are trustworthy enough to use

### Step 2: Start with the highest-signal primary dimension

**Top services**
- Use `top-services-by-cost.kql` when the question is service-led.
- This is the fastest way to rank cost by `ServiceName`.

```kusto
let N = 10;
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by ServiceName
| top N by EffectiveCost desc
```

**Top regions**
- Use `cost-by-region-trend.kql` for regional rollup and trend context.
- This groups cost by `RegionName` and helps surface regional concentration.

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by RegionName
| order by EffectiveCost desc
```

**Top resource groups**
- Use `costs-enriched-base.kql` as the foundation for custom ranking by `x_ResourceGroupName`.
- This is the preferred fallback when the catalog query you need is close but not exact.

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by x_ResourceGroupName
| top 20 by EffectiveCost desc
```

**Top billing hierarchy nodes**
- Use `cost-by-financial-hierarchy.kql` when you need allocation or showback context.
- Focus on `x_BillingProfileName`, `x_InvoiceSectionName`, and `SubAccountName` before adding any lower-level dimensions.

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost)
    by x_BillingProfileName, x_InvoiceSectionName, SubAccountName
| top 20 by EffectiveCost desc
```

### Step 3: Add a multidimensional breakdown
After the primary ranking, add one more dimension to explain the driver:

- `ServiceName` by `SubAccountName`
- `ServiceName` by `RegionName`
- `x_ResourceGroupName` within a top `ServiceName`
- `x_BillingProfileName` → `x_InvoiceSectionName` → `SubAccountName`

Use `costs-enriched-base.kql` when you need to pivot the same filtered dataset multiple ways.

### Step 4: Add optional tag-based grouping only when it helps
Tag-based grouping is optional. If your organization uses tags and coverage is good enough, add `Tags['team']`, `Tags['product']`, `Tags['application']`, or `Tags['environment']` as an overlay after the non-tag ranking is understood.

If tags are missing, blank, or tag coverage is incomplete, fall back to `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `x_BillingProfileName`, or `x_InvoiceSectionName` instead.

Treat blank tag values as incomplete metadata, not as a reliable business grouping.

### Step 5: Quantify concentration
For every ranked output:
1. calculate total spend for the filtered scope
2. calculate each row's percentage of total
3. calculate cumulative percentage
4. identify the smallest set of rows that explains roughly 80 percent of spend

### Step 6: Add trend context when needed
- Re-run the top driver view over daily or monthly grain when the user asks what changed.
- `cost-by-region-trend.kql` is useful when regional growth or migration is part of the story.
- For custom trend work, start from `costs-enriched-base.kql` and keep the same driver dimensions so comparisons stay consistent.

## Output format

### 1. Executive summary
- total spend for the period
- scope analyzed
- top 3 drivers in one sentence
- immediate optimization or allocation takeaway

### 2. Ranked cost drivers

| Rank | Dimension | Cost | % of total | Cumulative % |
|------|-----------|------|------------|--------------|
| 1 | Value 1 | $X,XXX | XX% | XX% |
| 2 | Value 2 | $X,XXX | XX% | XX% |
| 3 | Value 3 | $X,XXX | XX% | XX% |

### 3. Drill-down explanation
For each top driver, explain the most useful secondary split, such as:
- `ServiceName` by `SubAccountName`
- `ServiceName` by `RegionName`
- `x_ResourceGroupName` for the most expensive subscription
- `x_BillingProfileName` and `x_InvoiceSectionName` for chargeback conversations

### 4. Concentration summary
- Top N rows represent X percent of spend
- Remaining long tail represents Y percent
- Recommendation on where to focus first

### 5. Optional tag view
If tag quality is usable, summarize what `Tags['team']`, `Tags['product']`, `Tags['application']`, or `Tags['environment']` adds to the analysis.

If tags are missing or incomplete, explicitly say the fallback ranking used `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `x_BillingProfileName`, or `x_InvoiceSectionName` instead.

### 6. Optimization priorities
Recommend:
1. highest-cost services or regions for immediate review
2. subscriptions or resource groups that need deeper investigation
3. billing hierarchy areas that need ownership clarification
4. metadata cleanup when optional tags are incomplete

## Best practices
1. Start with one strong non-tag dimension before adding more detail.
2. Prefer `ServiceName`, `RegionName`, `SubAccountName`, and `x_ResourceGroupName` when tags are unreliable.
3. Use `x_BillingProfileName` and `x_InvoiceSectionName` for finance-facing allocation views.
4. Keep the ranking dimension stable when adding trend context.
5. Always report both dollars and percentages so concentration is obvious.

## See also
- `references/queries/INDEX.md`
- `references/queries/finops-hub-database-guide.md`
- `costs-enriched-base.kql`
- `top-services-by-cost.kql`
- `cost-by-region-trend.kql`
- `cost-by-financial-hierarchy.kql`
