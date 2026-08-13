---
name: cost-trend-analysis
description: Analyzes FinOps hubs cost trends over time to identify direction, month-over-month change, service and subscription drivers, regional patterns, and forecast-ready spending signals
author: FinOps Toolkit Team
version: 1.0.0
license: Apache-2.0
---

# Cost trend analysis

## Purpose
Use this reference to analyze how cost changes over time in a FinOps hub, explain whether spend is rising or falling, and identify which services, subscriptions, regions, or resource groups are driving the change.

## When to use
- “How are my costs trending?”
- “Are we increasing or decreasing month over month?”
- “Which services are driving the trend?”
- “Which subscription or resource group changed the most?”
- “Do regions explain the increase?”
- Budget review, forecast preparation, or executive reporting

## Grounding
Use these canonical assets first:
- `monthly-cost-trend.kql`
- `monthly-cost-change-percentage.kql`
- `cost-by-region-trend.kql`
- `Costs()`

Use the FinOps hub database guide and query catalog as the authoritative source for valid columns and query patterns.

## How this skill works

### Step 1: Define the analysis window
- Default to the last 12 full months for leadership trend analysis.
- Use at least 3 months for short trend checks.
- Use 12 months when you need to describe seasonality, sustained growth, or baseline shifts.

### Step 2: Establish the overall monthly trend
Start with `monthly-cost-trend.kql` to understand the total billed and effective cost trajectory.

Questions to answer:
- Is the overall trend increasing, decreasing, or flat?
- Is the latest month above or below the recent baseline?
- Are billed and effective cost moving together?

### Step 3: Quantify the month-over-month change
Use `monthly-cost-change-percentage.kql` to measure direction and magnitude.

Focus on:
- Latest month-over-month change
- Consecutive positive or negative months
- Whether change is accelerating, decelerating, or reverting toward baseline

### Step 4: Check whether region explains the trend
Use `cost-by-region-trend.kql` when geography may explain the change.

Focus on:
- `RegionName` values with the largest current spend
- Regions with the largest absolute change
- Whether a single region explains most of the overall movement

### Step 5: Decompose the trend with `Costs()`
Use `Costs()` when you need a tailored breakdown by driver.

Common dimensions:
- `ServiceName`
- `SubAccountName`
- `RegionName`
- `x_ResourceGroupName`
- `ResourceName`
- `ResourceType`
- `x_UsageType`

#### Example: service trend
```kusto
let startDate = startofmonth(ago(365d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by Month = startofmonth(ChargePeriodStart), ServiceName
| order by Month asc
```

#### Example: subscription trend
```kusto
let startDate = startofmonth(ago(365d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by Month = startofmonth(ChargePeriodStart), SubAccountName
| order by Month asc
```

#### Example: resource group trend
```kusto
let startDate = startofmonth(ago(365d));
let endDate = startofmonth(now());
Costs()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by Month = startofmonth(ChargePeriodStart), x_ResourceGroupName
| order by Month asc
```

Use the same pattern to compare `ResourceName`, `ResourceType`, or `x_UsageType` when the trend appears to be concentrated in a narrow workload slice.

### Step 6: Classify the pattern
After reviewing the catalog queries and custom `Costs()` breakdowns, classify the trend:
- **Growth:** sustained upward movement over multiple months
- **Decline:** sustained downward movement over multiple months
- **Stable:** narrow range with low month-over-month movement
- **Volatile:** frequent swings with no clear baseline
- **Step change:** a permanent shift beginning in a specific month

### Step 7: Identify the main driver
Name the primary driver explicitly:
- top `ServiceName` contributor
- top `SubAccountName` contributor
- top `RegionName` contributor
- top `x_ResourceGroupName` contributor

State whether the driver explains most of the change or only part of it.

### Step 8: Prepare a forecast-ready conclusion
Trend analysis should support planning, not pretend certainty.

Provide:
- current direction
- latest month-over-month percentage change
- largest driver
- confidence level based on consistency of recent months
- a conservative, expected, and high scenario if forecasting is requested

## Output format

### 1. Executive summary
- Overall trend: increasing, decreasing, stable, or volatile
- Latest monthly effective cost
- Latest month-over-month change from `monthly-cost-change-percentage.kql`
- Primary driver by `ServiceName`, `SubAccountName`, `RegionName`, or `x_ResourceGroupName`
- One-sentence takeaway

### 2. Core metrics
- Trend period analyzed
- Latest billed cost
- Latest effective cost
- Month-over-month billed change
- Month-over-month effective change
- Number of consecutive months in the same direction

### 3. Driver breakdown
Summarize the top contributors behind the trend:

| Dimension | Top value | Why it matters |
| --- | --- | --- |
| ServiceName | [value] | Largest service contribution |
| SubAccountName | [value] | Largest subscription contribution |
| RegionName | [value] | Largest regional contribution |
| x_ResourceGroupName | [value] | Largest workload grouping contribution |

### 4. Pattern interpretation
- What changed first?
- What kept changing afterward?
- Is the pattern broad-based or concentrated?
- Does the trend look durable or temporary?

### 5. Recommended next step
- Continue monitoring if stable and expected
- Investigate the main driver if change is concentrated
- Prepare budget or forecast adjustments if growth is sustained
- Review optimization opportunities if growth is not tied to expected business activity

## Best practices
1. Start with `monthly-cost-trend.kql` before writing a custom query.
2. Use `monthly-cost-change-percentage.kql` to quantify the latest movement instead of describing trend direction qualitatively.
3. Use `cost-by-region-trend.kql` when regional deployment, migration, or failover may explain the shift.
4. Use `Costs()` only after the catalog query establishes baseline context.
5. Decompose the trend with `ServiceName`, `SubAccountName`, `RegionName`, and `x_ResourceGroupName` before jumping to conclusions.
6. Explain whether the trend is broad or concentrated.
7. Keep forecast language bounded by recent trend consistency.

## See also
- `queries/INDEX.md`
- `queries/finops-hub-database-guide.md`
- `monthly-cost-trend.kql`
- `monthly-cost-change-percentage.kql`
- `cost-by-region-trend.kql`
