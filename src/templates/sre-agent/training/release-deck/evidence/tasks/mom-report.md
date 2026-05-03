# Month-over-Month Report

## Identity
- **YAML:** sre-config/scheduled-tasks/mom-report.yaml
- **Cron:** 15 17 * * * — daily at 17:15 UTC
- **Owning subagent:** finops-practitioner
- **FinOps Framework capability:** Reporting & Analytics
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, data-freshness-check, vm-quota-usage, Costs(), costs-enriched-base, monthly-cost-trend, top-services-by-cost, top-resource-groups-by-cost, cost-anomaly-detection, savings-summary-report, commitment-discount-utilization, cost-forecasting-model, reservation-recommendation-breakdown, cost-by-region-trend, top-resource-types-by-cost, cost-by-financial-hierarchy, Transactions(), monthly-cost-change-percentage

## Latest run summary
The MoM cost analysis scheduled task is complete. All 9 tasks finished successfully: **Execution Summary:** **17 Kusto queries** executed across fiscal trends, services, resource groups, anomalies, savings, commitments, forecast, reservations, regions, resource types, benchmarking, volatility, marketplace, and MoM change **4 charts** generated (cost trend + forecast, top services, regional distribution, savings/commitment dashboard)

## Final Teams card / Outlook output (verbatim)
~~~~text
The MoM cost analysis scheduled task is complete. All 9 tasks finished
successfully:

**Execution Summary:**
- **17 Kusto queries** executed across fiscal trends, services, resource
groups, anomalies, savings, commitments, forecast, reservations, regions,
resource types, benchmarking, volatility, marketplace, and MoM change
- **4 charts** generated (cost trend + forecast, top services, regional
distribution, savings/commitment dashboard)
- **Full report posted to Teams** with executive summary, grade card (C+
overall), 12-month trend, reservation recommendations ($8.9K potential
savings), and 3-phase implementation roadmap
- **Knowledge base updated** with operational learnings (parallel query
reliability, data consistency patterns, Prices() freshness via count query)

**Key Findings (April 2026):**
- Effective cost: **$40,306** (-3.8% MoM, -45% YoY)
- ESR: **2.8%** (critical — target 20%+)
- Commitment coverage: **3.5%** (target 60-70%)
- Tag coverage: **97.1%** (excellent)
- Forecast: **~$41K/month** for next 90 days (stable)
- Top action: Purchase 1-year SQL DB and VM reservations for immediate
$3,220/year savings
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- Top action: Purchase 1-year SQL DB and VM reservations for immediate

## Knowledge updates
- 1. Read the knowledge base documents
- Starting Phase 0: Reading knowledge base and loading skills.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded both skills. Key learnings
- Knowledge base loaded. Key learnings from prior runs noted — Prices() has
- knowledge base update). Let me proceed with posting the complete report to
- knowledge base
- Let me first update the knowledge base with operational learnings from this
- Let me start by updating the knowledge base file, then check the repository
- Completing task 8: saving operational learnings to knowledge base. Then
- 1. Task 8: Review and collect learnings - update the knowledge base with
- Let me first update the knowledge base with new operational learnings from
- Now I'm updating the knowledge base and reviewing the runbook for potential
- Updating the knowledge base with operational learnings from this run, then
- Edited file: memory: finops-hub-health-check-findings.md
- the knowledge base
- Let me continue with task 8 (finish updating the knowledge base), then move
- Now I'll wrap up the knowledge base updates and then examine the repository
- improvements). Let me finish updating the knowledge base and then check the
- in the knowledge base. Marking task 9 as complete.

## MCAPS asks this task answers
- **#32:** Produces executive MoM cost, ESR, coverage, and forecast figures that support finance reconciliation conversations.
- **#41:** Runs 17 Kusto queries across cost, savings, commitments, forecast, reservations, and benchmarking.
- **#43:** Grades overall maturity C+ and highlights ESR/coverage gaps.
- **#62:** Identifies reservation recommendations and commitment coverage gap.
- **#63:** Uses hub cost and pricing data for reconciliation-grade reporting.
- **#66:** Stable forecast and tag coverage evidence support finance data credibility.
