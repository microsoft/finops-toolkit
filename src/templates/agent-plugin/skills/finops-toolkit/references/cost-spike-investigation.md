---
name: cost-spike-investigation
description: Investigates sudden cost increases in FinOps hubs by comparing spike periods to baseline periods and isolating the services, subscriptions, regions, resource groups, resources, resource types, or usage types responsible for the change
author: FinOps Toolkit Team
version: 1.0.0
license: Apache-2.0
---

# Cost spike investigation

## Purpose
Use this reference to explain why cost increased suddenly in a FinOps hub, determine whether the change is a short-lived spike or the start of a new baseline, and identify the drivers that need follow-up.

## When to use
- “Why did cost jump?”
- “What caused the spike this week or this month?”
- “Which service or subscription explains the increase?”
- “Is this a one-time event or a sustained change?”
- Budget alert, anomaly triage, or executive escalation

## Grounding
Use these canonical assets first:
- `cost-anomaly-detection.kql`
- `monthly-cost-change-percentage.kql`
- `top-services-by-cost.kql`
- `Costs()`

Use the FinOps hub database guide and query catalog as the authoritative source for valid columns and query patterns.

## How this skill works

### Step 1: Define the spike and baseline periods
- Clarify the exact period where the spike appeared.
- Choose a comparable baseline period of equal length.
- Default to the last 7 days versus the previous 7 days when the user does not specify a window.
- Keep the comparison explicit so absolute and percentage change are easy to explain.

### Step 2: Confirm the spike exists
Start with `cost-anomaly-detection.kql` to identify unusual daily movement and confirm when the spike started.

Questions to answer:
- Which dates show the most unusual movement?
- Does the spike revert quickly or persist for multiple days?
- Is the spike isolated or part of a broader pattern?

### Step 3: Quantify the magnitude
Use `monthly-cost-change-percentage.kql` when you need a simple percentage summary for stakeholders.

Focus on:
- absolute increase
- percentage increase
- whether the latest monthly movement supports the same story as the daily spike

### Step 4: Identify the first major driver
Use `top-services-by-cost.kql` to quickly identify whether one or two services explain most of the increase.

Focus on:
- `ServiceName` values with the largest current spend
- services with the largest increase from baseline
- whether the spike is concentrated or broad-based

### Step 5: Decompose the spike with `Costs()`
Use `Costs()` to isolate the dimensions responsible for the spike.

Common fields to test:
- `ServiceName`
- `SubAccountName`
- `RegionName`
- `x_ResourceGroupName`
- `ResourceName`
- `ResourceType`
- `x_UsageType`

#### Example: compare service cost across spike and baseline periods
```kusto
let spikeStart = ago(7d);
let spikeEnd = now();
let baselineStart = ago(14d);
let baselineEnd = ago(7d);
let spike =
    Costs()
    | where ChargePeriodStart between (spikeStart .. spikeEnd)
    | summarize SpikeCost = sum(EffectiveCost) by ServiceName;
let baseline =
    Costs()
    | where ChargePeriodStart between (baselineStart .. baselineEnd)
    | summarize BaselineCost = sum(EffectiveCost) by ServiceName;
spike
| join kind=fullouter baseline on ServiceName
| extend SpikeCost = coalesce(SpikeCost, 0.0), BaselineCost = coalesce(BaselineCost, 0.0)
| extend CostIncrease = SpikeCost - BaselineCost
| order by CostIncrease desc
```

#### Example: isolate subscription and region drivers
```kusto
let spikeStart = ago(7d);
let spikeEnd = now();
Costs()
| where ChargePeriodStart between (spikeStart .. spikeEnd)
| summarize EffectiveCost = sum(EffectiveCost) by SubAccountName, RegionName
| order by EffectiveCost desc
```

#### Example: isolate workload-specific resources
```kusto
let spikeStart = ago(7d);
let spikeEnd = now();
Costs()
| where ChargePeriodStart between (spikeStart .. spikeEnd)
| summarize EffectiveCost = sum(EffectiveCost) by x_ResourceGroupName, ResourceName, ResourceType, x_UsageType
| order by EffectiveCost desc
```

### Step 6: Determine the spike shape
After reviewing the catalog queries and targeted `Costs()` breakdowns, classify the spike:
- **Transient spike:** abrupt increase followed by reversion
- **Sustained spike:** abrupt increase that remains elevated
- **Concentrated spike:** mostly explained by one `ServiceName`, `SubAccountName`, or `x_ResourceGroupName`
- **Broad spike:** spread across several dimensions
- **Usage-driven spike:** concentrated in one `x_UsageType` or `ResourceType`

### Step 7: Name the primary cause
State the most important driver explicitly:
- top `ServiceName` contributor
- top `SubAccountName` contributor
- top `RegionName` contributor
- top `x_ResourceGroupName` contributor
- top `ResourceName` or `ResourceType` contributor when the issue is workload-specific

Then state whether the driver explains most of the increase or only part of it.

### Step 8: Recommend the next action
Interpret the spike before recommending action:
- expected event such as scale-out, launch, migration, or planned testing
- operational issue such as runaway workload or failed cleanup
- optimization opportunity tied to inefficient `ResourceType` or `x_UsageType`
- data-quality concern if the pattern conflicts with other trend evidence

## Output format

### 1. Executive summary
- Spike detected: yes or no
- Spike period analyzed
- Total increase in cost and percentage terms
- Primary driver by `ServiceName`, `SubAccountName`, `RegionName`, `x_ResourceGroupName`, `ResourceName`, or `ResourceType`
- One-sentence conclusion

### 2. Spike metrics
- Baseline period cost
- Spike period cost
- Absolute increase
- Percentage increase
- Whether the spike is still ongoing

### 3. Driver breakdown

| Dimension | Top value | Why it matters |
| --- | --- | --- |
| ServiceName | [value] | Largest service contribution |
| SubAccountName | [value] | Largest subscription contribution |
| RegionName | [value] | Regional concentration |
| x_ResourceGroupName | [value] | Workload grouping with the largest increase |
| ResourceType | [value] | Resource class driving the spike |

### 4. Interpretation
- When did the spike begin?
- Which dimension explains the largest share of the increase?
- Is the spike transient or sustained?
- Is the increase expected, wasteful, or still unverified?

### 5. Recommended next step
- Investigate the primary driver if change is concentrated
- Review recent deployment or scaling events around the spike window
- Monitor closely if the spike is understood and expected
- Pursue optimization if the increase is sustained without business justification

## Best practices
1. Start with `cost-anomaly-detection.kql` before writing custom spike logic.
2. Use `monthly-cost-change-percentage.kql` when stakeholders need a simple summary of magnitude.
3. Use `top-services-by-cost.kql` to identify the fastest path to likely drivers.
4. Use `Costs()` to explain the spike with `ServiceName`, `SubAccountName`, `RegionName`, and `x_ResourceGroupName`.
5. Use `ResourceName`, `ResourceType`, and `x_UsageType` when the spike appears workload-specific.
6. Compare equal-length periods so the increase is defensible.
7. Distinguish a short spike from a sustained baseline reset.

## See also
- `queries/INDEX.md`
- `queries/finops-hub-database-guide.md`
- `cost-anomaly-detection.kql`
- `monthly-cost-change-percentage.kql`
- `top-services-by-cost.kql`
