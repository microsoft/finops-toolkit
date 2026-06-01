---
name: forecasting-budgeting
description: Use when the user wants to forecast future Azure cost, design or evaluate budgets, run budget-vs-actual variance analysis, set up budget alerts, or model the cost impact of a planned change. Covers planning and the "manage anomalies and budgets" side of FinOps.
license: MIT
compatibility: Requires cost history (Cost Management or a FinOps hub) for forecasting and Cost Management Contributor to create budgets/alerts. Pairs with the finops-toolkit KQL skill and the finops-multitool MCP server.
metadata:
  author: microsoft
  version: "1.0"
allowed-tools: az pwsh
---

# Forecasting and budgeting

Look forward, not just back. This skill projects future spend, designs budgets, and explains variance so teams can plan and stay accountable.

## When to use this skill

Use it when the user asks to forecast, budget, plan spend, explain why they're over/under budget, or set up budget alerts. Pull history from `scan_cost_trend` / `monthly-cost-trend.kql` and current budget state from `scan_budget_status`, then plan here.

## Forecasting

| Method | Use when | Source |
|--------|----------|--------|
| **Trend / run-rate** | Stable spend, short horizon | MTD ÷ days elapsed × days in month |
| **Linear / seasonal model** | Months of history, want a defensible projection | `cost-forecasting-model.kql` |
| **Driver-based** | A known change is coming (migration, new workload, ramp-down) | Build from the change, not history |

Rules:
- Forecast on `EffectiveCost` (amortized) for planning; use `BilledCost` only for invoice/cash projections.
- Always state the horizon and confidence — a forecast without a range invites false precision.
- Early in the month, run-rate forecasts are noisy (tag-dimensioned and some usage data lag a few days). Flag this rather than over-trusting a day-3 projection.
- Re-forecast when a commitment expires or a major workload changes — both break historical trend.

## Budget design

1. **Scope** — subscription, resource group, or tag (CostCenter/App). Tag-scoped budgets need the allocation model from the `cost-allocation` skill.
2. **Amount** — base on forecast + a planned-growth buffer, not last month flat.
3. **Time grain** — monthly for ops, quarterly/annual for finance.
4. **Alert thresholds** — set multiple (e.g. 50/80/100% actual, plus a forecasted-to-exceed alert). Forecasted alerts warn *before* the overrun.
5. **Actions** — wire alerts to an action group (email/Teams/webhook). For automated response, trigger off the budget alert, not a manual check.

## Variance analysis (budget vs actual)

For an over/under, decompose the gap:
- **Volume** — more/less usage of the same things.
- **Rate** — price changed, or a discount/commitment expired (check ESR via `unit-economics`).
- **New/retired** — resources added or removed since the budget was set.
- **Allocation** — a tag changed and moved cost between buckets.

Report each driver with its $ contribution so the variance is explained, not just stated.

## Hand-offs

- History + current budgets → `finops-multitool` (`scan_cost_trend`, `scan_budget_status`) / `finops-toolkit` KQL.
- Rate-driven variance → `rate-optimization-portfolio` and `unit-economics`.
- Sudden unexpected spike → `anomaly-investigation` skill.
- Write up the variance → `finops-reporting`.
