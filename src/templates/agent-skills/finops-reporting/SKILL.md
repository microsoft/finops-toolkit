---
name: finops-reporting
description: Use when the user wants to turn cost data, scan output, or KQL results into an audience-ready narrative — executive summaries, monthly cost reviews, QBR decks, variance write-ups, or savings/optimization status reports. Converts numbers into decisions and recommendations.
license: MIT
compatibility: Works on output from the finops-multitool MCP server, the finops-toolkit KQL skill, or any cost dataset. Pairs with power-bi-finops for visuals and content-humanizer for tone.
metadata:
  author: microsoft
  version: "1.0"
---

# FinOps reporting

Translate cost analytics into the report the audience actually needs. The other skills produce numbers; this one produces narrative, structure, and recommendations.

## When to use this skill

Use it when the user asks for a summary, executive report, monthly/quarterly review, QBR, variance explanation, or "write up" of cost or savings. Gather the data first (`finops-multitool` scans, `finops-toolkit` KQL, or `run_full_scan` for a broad sweep), then shape it here.

## Match the report to the audience

| Audience | Report | Focus | Length |
|----------|--------|-------|--------|
| Executive / finance | Executive summary | Total spend, trend, top movers, savings captured, 3 actions | 1 page |
| Engineering leads | Optimization review | Waste, rightsizing, idle resources, owners, effort vs savings | 2–3 pages |
| FinOps practice | Monthly cost review | Full breakdown, allocation, coverage, anomalies, forecast | Deck / workbook |
| Account / QBR | Business review | Spend vs budget, ESR trend, commitments, roadmap | Deck |

## Executive summary structure

1. **Headline** — total spend, MoM/QoQ change %, one sentence on why.
2. **Trend** — are we accelerating, flat, or declining? (`scan_cost_trend`, `monthly-cost-trend.kql`)
3. **Top movers** — the 3 services/resource groups driving the change.
4. **Savings captured** — ESR and realized savings (`scan_savings_realized`, `savings-summary-report.kql`).
5. **Opportunities** — top 3 unrealized savings, each with $ impact, effort, and owner.
6. **Anomalies / risks** — anything unusual, expiring commitments, budget overruns.
7. **Recommended actions** — numbered, owned, with a target date. This is the part executives read.

## Turning a scan into a recommendation

For every finding, give: **what** (the issue), **how much** ($ / month or %), **effort** (low/med/high), **risk** (low/med/high), **owner**, **action**. A finding without a dollar figure and an owner is noise — quantify it from the scan data or say it's an estimate.

## Writing rules

- Lead with the number and the decision, not the methodology.
- One idea per bullet; no walls of text in exec material.
- Always express savings as $/month *and* annualized — annualized numbers move executives.
- State assumptions explicitly (window, scope, billed vs effective cost) so the report survives scrutiny.
- For the prose itself, apply the `content-humanizer` skill so it reads like a person, not a generator.

## Hand-offs

- Need the data → `finops-multitool` (`run_full_scan` for breadth) or `finops-toolkit` KQL.
- Need charts in the report → `power-bi-finops`.
- Need efficiency KPIs (ESR, unit cost) → `unit-economics`.
- Need budget vs actual variance → `forecasting-budgeting`.
