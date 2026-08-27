---
name: anomaly-investigation
description: Use when a cost spike, anomaly alert, or unexpected charge needs root-cause analysis — drilling from a total-cost jump down to the specific service, resource, region, or change that caused it. Picks up after detection (the "what") to deliver the "why" and the fix.
license: MIT
compatibility: Requires cost data (Cost Management or a FinOps hub) at resource granularity and, ideally, Azure Activity Log read access to correlate changes. Pairs with the finops-multitool skill and the finops-toolkit KQL skill.
metadata:
  author: microsoft
  version: "1.0"
allowed-tools: az pwsh
---

# Cost anomaly investigation

Detection tells you a cost moved; this skill tells you *why* and what to do. It's the root-cause triage that runs after an anomaly alert fires or a budget variance appears.

## When to use this skill

Use it when the user reports a spike, an unexpected bill, an anomaly alert, or "why did cost jump." Confirm/quantify the anomaly first (anomaly alerts, cost trend, `cost-anomaly-detection.kql`), then drill here. For *setting up* detection/alerts, use `forecasting-budgeting` or the `azure-cost-management` anomaly-alerts skill instead.

## Root-cause drill-down

Narrow the spike one dimension at a time until a single driver remains:

1. **When** — pinpoint the day the cost stepped up. A sharp step = a discrete change; a ramp = growing usage.
2. **What service** — group the delta by `ServiceName`; find the service contributing most of the increase.
3. **What resource** — within that service, group by `ResourceName` / resource group.
4. **What changed** — for the suspect resource and date, correlate with the **Azure Activity Log** (create/scale/SKU-change events) and with commitment expiries.
5. **Rate vs volume** — did usage rise (volume) or did the unit price rise / a discount drop (rate)? Compare `EffectiveCost` movement to usage quantity.

## Common spike signatures

| Signature | Likely cause |
|-----------|--------------|
| Step up on a specific day, one resource | Scale-up, SKU change, or tier upgrade — check Activity Log |
| Gradual ramp across many resources | Organic growth or a rollout — usually expected |
| Spike with no usage change | A reservation/savings plan expired → rate went to on-demand (check ESR, commitment utilization) |
| New resource type appears | Net-new deployment, possibly untagged/unowned |
| Data-transfer / egress jump | Cross-region traffic, new integration, data exfil pattern — investigate |
| Spike then return to baseline | One-off job, batch run, or test left running |
| Sustained jump in a shared service | Allocation/shared-cost shift — see `cost-allocation` |

## Closing the loop

For each confirmed anomaly deliver: **driver** (the specific resource/change), **$ impact** (one-time vs recurring), **owner**, **action** (rightsize / delete / re-commit / accept-as-expected), and **prevention** (a budget alert, policy, or tag so it's caught earlier next time). An anomaly that's explained but not prevented will recur.

## Hand-offs

- Confirm/quantify the anomaly → `finops-multitool` (anomaly alerts, cost trend).
- Spike caused by expired commitment → `rate-optimization-portfolio`.
- Prevent recurrence → `forecasting-budgeting` (alerts) or `azure-policy-governance` (guardrails).
- Report it → `finops-reporting`.
