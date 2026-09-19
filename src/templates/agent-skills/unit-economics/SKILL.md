---
name: unit-economics
description: Use when the user wants to measure cost efficiency rather than raw spend — cost per customer/transaction/unit, Effective Savings Rate (ESR), commitment coverage and utilization rates, waste percentage, or any FinOps "quantify business value" KPI that ties cloud cost to a business or usage metric.
license: MIT
compatibility: Requires cost data (Cost Management scope or a FinOps hub) and a business/usage denominator (customers, transactions, requests, GB, etc.). Pairs with the finops-toolkit KQL skill and the finops-multitool skill.
metadata:
  author: microsoft
  version: "1.0"
---

# Unit economics

Move the conversation from "how much did we spend" to "how efficiently did we spend it." This skill defines and calculates the KPIs in the FinOps Framework's *Quantify business value* domain.

## When to use this skill

Use it when the user asks about cost efficiency, cost per unit, ROI of optimization, savings rate, coverage/utilization, or wants a metric that pairs cost with a business denominator. For the raw cost inputs, pull from the `finops-toolkit` KQL queries or the `finops-multitool` scans, then compute the ratio here.

## Core KPIs

| KPI | Formula | Reads from |
|-----|---------|-----------|
| **Unit cost** | EffectiveCost ÷ business unit (customers, txns, orders, GB) | Cost + a usage/business metric |
| **Effective Savings Rate (ESR)** | (ListCost − EffectiveCost) ÷ ListCost | `savings-summary-report.kql` |
| **Commitment coverage** | Cost covered by RI/SP ÷ total commitment-eligible cost | commitment utilization, `commitment-discount-utilization.kql` |
| **Commitment utilization** | Used commitment ÷ purchased commitment | commitment utilization |
| **Waste %** | Idle/orphaned cost ÷ total cost | orphaned resources, idle vms |
| **Allocation coverage** | Allocated cost ÷ total cost | cost by tag, `cost-allocation` skill |
| **Forecast accuracy** | 1 − |actual − forecast| ÷ actual | `forecasting-budgeting` skill |

## ESR — the headline rate KPI

ESR is the single best measure of rate-optimization maturity. It captures *all* discount levers (reservations, savings plans, negotiated/contracted prices, Hybrid Benefit) in one number.

- Use `EffectiveCost` vs `ListCost` — not `BilledCost`, which already nets commitments.
- Track ESR as a trend, not a point. A rising ESR means discounts are compounding; a falling ESR means coverage is decaying (often an expiring reservation).
- Pair a falling ESR with commitment utilization to find the expiring or under-covered commitment.

## Defining a unit metric

The hard part is the denominator. Guide the user to:
1. Pick a metric finance and product both accept (active customers, paid transactions, processed GB).
2. Decide the cost scope that maps to it (whole product, one service tier, one workload tag).
3. Use allocated cost (from the `cost-allocation` skill) as the numerator so the unit cost reflects true ownership, including shared-cost splits.
4. Trend it monthly. Falling unit cost while volume grows = healthy economies of scale; rising unit cost = investigate before scaling further.

## Presenting

- Always show the trend and the denominator alongside the ratio — a unit cost with no volume context is misleading.
- Tie each KPI to an action: high waste % → workload optimization; low coverage → `rate-optimization-portfolio`; low allocation coverage → tagging/policy work.

## Hand-offs

- Cost inputs → `finops-toolkit` / `finops-multitool`.
- Allocated numerator → `cost-allocation` skill.
- Coverage/utilization detail → `rate-optimization-portfolio` skill.
- Visualize KPIs → `power-bi-finops`; narrate them → `finops-reporting`.
