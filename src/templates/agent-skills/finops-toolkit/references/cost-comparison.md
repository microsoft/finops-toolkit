---
name: cost-comparison
description: Compares FinOps hubs cost across time periods, subscriptions, regions, resource groups, billing hierarchy, and optional tags to explain spending differences and benchmark efficiency
author: FinOps Toolkit Team
version: 1.0.0
license: Apache-2.0
---

# Cost comparison

## Purpose
Use FinOps hubs data to compare cost across two or more periods or groups, quantify the size of the difference, and explain which services, subscriptions, regions, resource groups, or billing-hierarchy nodes account for the change.

## When to use
- "Compare costs between period A and period B"
- "Show me month-over-month changes"
- "Which subscription, region, or service is more expensive?"
- "Compare production and non-production costs"
- "Benchmark billing profiles, invoice sections, or resource groups"
- Keywords: compare, comparison, versus, vs, difference, benchmark, relative, month-over-month

## Prerequisites
- Confirm the hub connection, reporting window, and any required filters.
- Use `references/queries/finops-hub-database-guide.md` to verify available FinOps hubs fields and enrichment columns.
- Use `references/queries/INDEX.md` to select the closest starting query.
- Start with `costs-enriched-base.kql` when you need a reusable filtered dataset for several comparison views.

## Recommended comparison dimensions
Choose the first grouping that best matches the question:

- `ServiceName` for side-by-side service comparison across periods or groups
- `SubAccountName` for subscription or sub-account comparison
- `RegionName` for regional comparison
- `x_ResourceGroupName` for resource-group comparison
- `x_BillingProfileName` and `x_InvoiceSectionName` for billing-hierarchy comparison

Tag-based grouping is optional. If your organization uses tags and coverage is good enough, compare `Tags['team']`, `Tags['product']`, `Tags['application']`, or `Tags['environment']`.

If tags are missing, blank, or tag coverage is incomplete, fall back to `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `x_BillingProfileName`, or `x_InvoiceSectionName` instead.

Treat blank tag values as incomplete metadata, not as a reliable business grouping.

## Recommended query assets
- `costs-enriched-base.kql` for custom side-by-side comparisons and repeated drill-downs
- `monthly-cost-change-percentage.kql` for month-over-month change analysis
- `cost-by-region-trend.kql` for region-led comparisons and trend context
- `cost-by-financial-hierarchy.kql` for billing profile and invoice section comparisons

## Analysis workflow

### Step 1: Identify the comparison type
Confirm whether the request is:

- period versus period
- month-over-month
- before versus after an optimization or migration
- subscription versus subscription
- region versus region
- resource group versus resource group
- billing profile or invoice section versus peers

Also confirm whether the user wants a technical comparison, a finance or allocation comparison, or both.

### Step 2: Choose the strongest base dimension
Start with one high-signal non-tag dimension before adding more detail:

- `ServiceName` when comparing what changed across equal time windows
- `SubAccountName` when comparing subscriptions or business-owned scopes
- `RegionName` when testing whether geography explains the difference
- `x_ResourceGroupName` when operational ownership matters most
- `x_BillingProfileName` and `x_InvoiceSectionName` when the comparison is for showback or chargeback

### Step 3: Build comparable datasets

**Side-by-side period comparison by service**

This pattern works well for comparing equal windows by `ServiceName`.

```kusto
let currentStart = datetime(2024-02-01);
let currentEnd = datetime(2024-03-01);
let previousStart = datetime(2024-01-01);
let previousEnd = datetime(2024-02-01);
union
(
    Costs()
    | where ChargePeriodStart >= currentStart and ChargePeriodStart < currentEnd
    | summarize EffectiveCost = sum(EffectiveCost) by ServiceName
    | extend ComparisonGroup = 'Current period'
),
(
    Costs()
    | where ChargePeriodStart >= previousStart and ChargePeriodStart < previousEnd
    | summarize EffectiveCost = sum(EffectiveCost) by ServiceName
    | extend ComparisonGroup = 'Previous period'
)
| order by ServiceName asc, ComparisonGroup asc
```

**Month-over-month comparison**

Start with `monthly-cost-change-percentage.kql` to quantify the overall shift, then drill into the main driver dimension.

```kusto
let startDate = startofmonth(ago(90d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by Month = startofmonth(ChargePeriodStart), ServiceName
| order by Month asc, EffectiveCost desc
```

**Region comparison**

Use `cost-by-region-trend.kql` when the question is whether `RegionName` explains cost variance.

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by RegionName, ServiceName
| order by RegionName asc, EffectiveCost desc
```

**Billing-hierarchy comparison**

Use `cost-by-financial-hierarchy.kql` when the baseline needs to follow finance ownership.

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost)
    by x_BillingProfileName, x_InvoiceSectionName, SubAccountName
| order by EffectiveCost desc
```

### Step 4: Calculate comparison metrics
For each comparable row, calculate:

- **Absolute difference:** `Difference = CostA - CostB`
- **Percentage difference:** `% Difference = ((CostA - CostB) / CostB) * 100`
- **Ratio:** `Ratio = CostA / CostB`
- **Share of total:** each row's cost divided by total cost for its group

When period lengths differ, normalize to a daily average before interpreting the result.

### Step 5: Identify the largest differences
Look for:

- services with the largest dollar delta in `ServiceName`
- subscriptions with the largest swing in `SubAccountName`
- region shifts in `RegionName`
- ownership concentration in `x_ResourceGroupName`
- allocation changes in `x_BillingProfileName` and `x_InvoiceSectionName`
- rows present in one group but absent in the other

### Step 6: Drill into the root cause
After the first comparison, add one more dimension to explain the difference:

- `ServiceName` by `SubAccountName`
- `ServiceName` by `RegionName`
- `x_ResourceGroupName` within the most expensive service or subscription
- `x_BillingProfileName` → `x_InvoiceSectionName` → `SubAccountName`

Use `costs-enriched-base.kql` when you need to pivot the same filtered dataset more than once.

### Step 7: Add optional tag overlays only after the base comparison is clear
If tag quality is usable, add `Tags['team']`, `Tags['product']`, `Tags['application']`, or `Tags['environment']` to explain ownership or workload context.

If tags are missing or incomplete, use `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `x_BillingProfileName`, or `x_InvoiceSectionName` instead so the comparison remains reliable.

### Step 8: Explain what changed and what to do next
Summarize:

- what changed
- where the difference is concentrated
- whether the difference is expected or avoidable
- which follow-up analysis or optimization should happen next

## Output format

### 1. Executive summary
- what was compared
- overall cost difference in dollars and percent
- one-sentence explanation of the primary driver
- recommended next action

### 2. High-level comparison

| Group | Total cost | Difference from baseline | % difference |
|------|------------|--------------------------|--------------|
| Group A | $X,XXX | +$X,XXX | +XX% |
| Group B | $X,XXX | baseline | 0% |

### 3. Primary driver breakdown

| Dimension | Group A | Group B | Difference | % difference | Notes |
|-----------|---------|---------|------------|--------------|-------|
| `ServiceName` or other primary field | $X,XXX | $X,XXX | +$XXX | +XX% | Main explanation |

### 4. Root-cause drill-down
Use one of these structures:

- `ServiceName` by `SubAccountName`
- `ServiceName` by `RegionName`
- `x_ResourceGroupName` for the most expensive subscription
- `x_BillingProfileName` and `x_InvoiceSectionName` for allocation conversations

### 5. Unique or shifted costs
- rows only present in one group
- major cost movements between subscriptions, regions, or resource groups
- one-time charges or newly adopted services

### 6. Optional tag view
If tag quality is usable, summarize what `Tags['team']`, `Tags['product']`, `Tags['application']`, or `Tags['environment']` adds to the analysis.

If tags are blank or incomplete, explicitly state that the comparison relied on `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `x_BillingProfileName`, or `x_InvoiceSectionName` instead.

### 7. Recommendations
Recommend:
1. which cost deltas need immediate validation
2. which owners or teams should review the biggest differences
3. which resource groups, subscriptions, or regions need deeper investigation
4. whether metadata cleanup is needed before using tags in future comparisons

## Common comparison scenarios

### Scenario 1: This month versus last month
Goal: understand month-over-month change.

Approach:
1. start with `monthly-cost-change-percentage.kql`
2. compare equal monthly windows
3. break the delta down by `ServiceName`
4. isolate new, removed, or sharply changed services
5. normalize for daily average if month lengths differ

### Scenario 2: Production versus non-production
Goal: verify non-production is scaled appropriately.

Approach:
1. use `ServiceName`, `SubAccountName`, or `x_ResourceGroupName` as the baseline comparison
2. add `Tags['environment']` only if the tag is present and trustworthy
3. compare service mix and total cost
4. identify oversized non-production resources
5. recommend rightsizing or shutdown opportunities

### Scenario 3: Subscription versus subscription
Goal: benchmark business or technical ownership scopes.

Approach:
1. compare totals by `SubAccountName`
2. split major differences by `ServiceName`
3. check whether `RegionName` or `x_ResourceGroupName` explains the variance
4. identify repeatable practices from the lower-cost peer

### Scenario 4: Region versus region
Goal: understand regional cost differences.

Approach:
1. start with `cost-by-region-trend.kql`
2. compare the same services across `RegionName`
3. check whether service mix or data movement explains the variance
4. recommend consolidation or placement review if the premium is avoidable

### Scenario 5: Before versus after an optimization
Goal: measure realized impact.

Approach:
1. compare equal windows before and after the change
2. quantify savings in dollars and percent
3. validate which `ServiceName`, `SubAccountName`, or `x_ResourceGroupName` changed
4. document repeatable lessons for future optimization work

## Best practices
1. Compare equal periods whenever possible.
2. Start with a strong non-tag baseline dimension.
3. Use both dollars and percentages so materiality is obvious.
4. Use `monthly-cost-change-percentage.kql` for month-over-month context, then explain the delta with `ServiceName` or another strong grouping.
5. Use `costs-enriched-base.kql` when you need multiple follow-up pivots from the same filtered scope.
6. Add optional tags only when coverage is good enough to trust.
7. If tags are incomplete, say so and fall back to non-tag fields.

## See also
- `references/queries/INDEX.md`
- `references/queries/finops-hub-database-guide.md`
- `costs-enriched-base.kql`
- `monthly-cost-change-percentage.kql`
- `cost-by-region-trend.kql`
- `cost-by-financial-hierarchy.kql`
