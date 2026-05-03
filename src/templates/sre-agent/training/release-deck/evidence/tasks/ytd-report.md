# Year-to-Date Report

## Identity
- **YAML:** sre-config/scheduled-tasks/ytd-report.yaml
- **Cron:** 0 9 1 * * — monthly on day 1 at 09:00 UTC
- **Owning subagent:** chief-financial-officer
- **FinOps Framework capability:** Reporting & Analytics / Forecasting
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, benefit-recommendations, data-freshness-check, resource-graph-query, Costs(), costs-enriched-base, monthly-cost-trend, top-services-by-cost, quarterly-cost-by-resource-group, cost-anomaly-detection, savings-summary-report, commitment-discount-utilization, cost-by-financial-hierarchy, cost-forecasting-model, reservation-recommendation-breakdown, cost-by-region-trend, top-resource-types-by-cost, monthly-cost-change-percentage, top-commitment-transactions, Transactions()

## Latest run summary
The FY25-26 Year-to-Date Analysis scheduled task completed successfully. Here's the execution summary: **Execution Stats:** 15 Kusto queries across 3 parallel batches — all succeeded on first attempt 4 charts generated (cost trend + forecast, top services, regional breakdown, savings/commitment) Full executive report posted to Teams with embedded visualizations Operational learnings saved to knowledge base (no financial data)

## Final Teams card / Outlook output (verbatim)
~~~~text
The FY25-26 Year-to-Date Analysis scheduled task completed successfully.
Here's the execution summary:

**Execution Stats:**
- 15 Kusto queries across 3 parallel batches — all succeeded on first
attempt
- 4 charts generated (cost trend + forecast, top services, regional
breakdown, savings/commitment)
- Full executive report posted to Teams with embedded visualizations
- Operational learnings saved to knowledge base (no financial data)

**Key Findings Delivered:**
- YTD effective cost: **$423,131** (10 months, Jul 2025 - Apr 2026)
- Projected full FY: **$497K** (expected scenario)
- Overall grade: **C-** — cost control adequate but rate optimization (ESR
3.5% vs 20-30% target) and tag compliance (86.6% untagged) are critical
gaps
- Commitment coverage at only **9%** of compute core-hours — $8,890/yr in
savings available from top 10 reservation recommendations
- 3 prioritized actions recommended before FY end (SQL DB reservation, VM
reservations, tag governance initiative)

Teams report: [View in
Teams](https://teams.microsoft.com/l/message/19%3ABpZihiFQYCvAeVjSALERBqmtDPW7p8_QESgBTG7xz7M1%40thread.tacv2/1777746728486?groupId=8b3d5b2c-2edc-4a9f-a0ff-0ed3856d5af3&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&createdTime=1777746728486&parentMessageId=1777746728486)
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- reservations, tag governance initiative)

## Knowledge updates
- read the knowledge base and load the required skills.
- Now I'm setting up the todo list and pulling in the knowledge base files to
- Reading knowledge base and loading required skills in parallel.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded both skills. Key learnings
- Knowledge base loaded. Key operational learnings applied: Transactions()
- 2. Save operational learnings to the knowledge base (no financial data)
- knowledge base. Let me also read the existing knowledge base file to update
- to the knowledge base.
- knowledge base. I was in the middle of reading the existing knowledge base
- Let me add a new section to the existing knowledge base file with the YTD
- Completing the final task — updating the knowledge base with operational
- Edited file: memory: finops-hub-health-check-findings.md
- 1. ✅ Phase 0: Preparation - Knowledge base read, skills loaded
- 7. ✅ Phase 7: Knowledge base - Operational learnings saved
- - Operational learnings saved to knowledge base (no financial data)

## MCAPS asks this task answers
- **#32:** Provides FY YTD cost and projected full-year spend for CFO-style review.
- **#33:** Offers full-FY forecast and prioritized actions before fiscal year end.
- **#36:** Highlights 86.6% untagged spend as allocation risk.
- **#43:** Grades overall posture C- and identifies rate optimization/tag compliance gaps.
- **#62:** Quantifies commitment coverage and top reservation savings.
- **#66:** Exec report and forecast support finance trust and credibility.
