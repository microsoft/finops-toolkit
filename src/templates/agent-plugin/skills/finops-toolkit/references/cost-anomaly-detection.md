---
name: cost-anomaly-detection
description: Detects unusual cost changes in FinOps hubs by establishing baseline spend, surfacing anomalies, and identifying the services, subscriptions, regions, resource groups, resources, or usage types driving the deviation
author: FinOps Toolkit Team
version: 1.0.0
license: Apache-2.0
---

# Cost anomaly detection

## Purpose
Use this reference to detect unusual cost behavior in a FinOps hub, determine whether a cost change is a short-lived spike or a sustained baseline shift, and identify the drivers that require investigation.

## When to use
- “Are there any cost anomalies?”
- “What changed unexpectedly in the last few days or weeks?”
- “Did we have an unusual spike or drop?”
- “Which service, subscription, or resource group caused the anomaly?”
- Weekly operational review, budget alert triage, or incident follow-up

## Grounding
Use these canonical assets first:
- `cost-anomaly-detection.kql`
- `monthly-cost-change-percentage.kql`
- `Costs()`

Use the FinOps hub database guide and query catalog as the authoritative source for valid columns and query patterns.

## How this skill works

### Step 1: Define the anomaly window
- Default to the last 30 to 90 days for recent anomaly checks.
- Use a longer lookback if you need to distinguish a one-time event from seasonality or a new normal.
- Keep the investigation window explicit so baseline and anomaly periods are comparable.

### Step 2: Start with the catalog query
Use `cost-anomaly-detection.kql` first to surface unusual movement in total daily cost.

Questions to answer:
- Which dates are flagged as anomalous?
- Are anomalies positive spikes, negative drops, or repeated oscillations?
- Does the pattern look isolated or sustained?

### Step 3: Quantify recent change
Use `monthly-cost-change-percentage.kql` when you need to explain whether the anomaly also appears in month-over-month movement.

This is especially helpful when:
- the anomaly appears near a month boundary
- stakeholders want a simple percentage summary
- you need to distinguish a daily outlier from a broader monthly shift

### Step 4: Decompose the anomaly with `Costs()`
Use `Costs()` to identify which dimensions explain the anomaly.

Common fields to test:
- `ServiceName`
- `SubAccountName`
- `RegionName`
- `x_ResourceGroupName`
- `ResourceName`
- `ResourceType`
- `x_UsageType`

#### Example: daily service anomaly breakdown
```kusto
let startDate = ago(30d);
let endDate = now();
Costs()
| where ChargePeriodStart between (startDate .. endDate)
| summarize EffectiveCost = sum(EffectiveCost) by Day = startofday(ChargePeriodStart), ServiceName
| order by Day asc, EffectiveCost desc
```

#### Example: subscription anomaly breakdown
```kusto
let startDate = ago(30d);
let endDate = now();
Costs()
| where ChargePeriodStart between (startDate .. endDate)
| summarize EffectiveCost = sum(EffectiveCost) by Day = startofday(ChargePeriodStart), SubAccountName
| order by Day asc, EffectiveCost desc
```

#### Example: resource group and resource investigation
```kusto
let startDate = ago(14d);
let endDate = now();
Costs()
| where ChargePeriodStart between (startDate .. endDate)
| summarize EffectiveCost = sum(EffectiveCost) by Day = startofday(ChargePeriodStart), x_ResourceGroupName, ResourceName, ResourceType
| order by Day asc, EffectiveCost desc
```

Use the same pattern to isolate whether the anomaly is concentrated in `RegionName` or `x_UsageType`.

### Step 5: Classify the anomaly pattern
After reviewing `cost-anomaly-detection.kql` and targeted `Costs()` breakdowns, classify the result:
- **Spike:** abrupt increase followed by reversion
- **Drop:** abrupt decrease followed by reversion
- **Step change:** abrupt increase or decrease that persists
- **Drift:** gradual movement away from prior baseline
- **Concentrated anomaly:** mostly explained by one `ServiceName`, `SubAccountName`, or `x_ResourceGroupName`
- **Broad anomaly:** spread across multiple dimensions

### Step 6: Name the primary driver
State the primary driver explicitly:
- top `ServiceName` contributor
- top `SubAccountName` contributor
- top `RegionName` contributor
- top `x_ResourceGroupName` contributor
- top `ResourceName` or `ResourceType` contributor when the anomaly is workload-specific

### Step 7: Determine likely meaning
Interpret the anomaly before recommending action:
- **Expected business event:** planned launch, migration, scale-out, or month-end processing
- **Operational issue:** runaway workload, misconfiguration, or failed cleanup
- **Data-quality concern:** unexpected drop or gap that may indicate ingest delay or incomplete data
- **Optimization opportunity:** sustained increase tied to inefficient resource or usage patterns

## Output format

### 1. Executive summary
- Anomaly detected: yes or no
- Most significant anomaly date or period
- Estimated impact in cost and percentage terms
- Primary driver by `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `ResourceName`, or `ResourceType`
- One-sentence conclusion

### 2. Anomaly details
- Detection window analyzed
- Baseline behavior described in plain language
- Observed anomaly pattern: spike, drop, step change, or drift
- Magnitude of deviation from normal
- Whether the anomaly appears isolated or ongoing

### 3. Driver breakdown

| Dimension | Top value | Why it matters |
| --- | --- | --- |
| ServiceName | [value] | Largest service contributor |
| SubAccountName | [value] | Largest subscription contributor |
| RegionName | [value] | Regional concentration |
| x_ResourceGroupName | [value] | Workload grouping most affected |
| ResourceType | [value] | Resource class driving change |

### 4. Interpretation
- What changed first?
- What dimension explains the largest share of the anomaly?
- Does the anomaly indicate a one-time event or a baseline reset?
- Does the pattern require immediate action, monitoring, or routine follow-up?

### 5. Recommended next step
- Investigate the largest driver when change is concentrated
- Review workload or deployment events around the anomaly date
- Compare against monthly movement if leadership wants trend context
- Continue monitoring if the anomaly is understood and expected

## Best practices
1. Start with `cost-anomaly-detection.kql` before writing custom anomaly logic.
2. Use `Costs()` to explain the anomaly, not just to confirm it exists.
3. Break down anomalies by `ServiceName`, `SubAccountName`, `RegionName`, and `x_ResourceGroupName` before jumping to conclusions.
4. Use `ResourceName`, `ResourceType`, and `x_UsageType` when the anomaly appears concentrated in a narrow workload slice.
5. Use `monthly-cost-change-percentage.kql` when stakeholders need month-over-month context.
6. Distinguish a short spike from a sustained step change.
7. Treat large negative anomalies as possible data or ingestion issues until validated.

## See also
- `queries/INDEX.md`
- `queries/finops-hub-database-guide.md`
- `cost-anomaly-detection.kql`
- `monthly-cost-change-percentage.kql`
