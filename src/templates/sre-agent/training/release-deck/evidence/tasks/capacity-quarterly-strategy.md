# Capacity Quarterly Strategy

## Identity
- **YAML:** sre-config/scheduled-tasks/capacity-quarterly-strategy.yaml
- **Cron:** 0 9 1 1,4,7,10 * — 0 9 1 1,4,7,10 *
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Rate Optimization / Capacity Planning
- **Maturity:** Walk/Run
- **Tools used:** PostTeamsMessage, benefit-recommendations, resource-graph-query, vm-quota-usage, reservation-recommendation-breakdown, commitment-discount-utilization, savings-summary-report

## Latest run summary
The Q2 2026 Quarterly Capacity Strategy Review is complete. All 11 tasks finished successfully. **Summary of deliverables:** 1. **Teams Strategy Brief** — Posted with 3 embedded charts (cost trend, commitment alignment, maturity radar), financial tables, maturity scorecard, and a Q3 roadmap with 6 prioritized actions. 2. **Key findings:** Effective savings rate is only **2.81%** (target: 15-25%) — 96% of core-hours are on-demand

## Final Teams card / Outlook output (verbatim)
~~~~text
The Q2 2026 Quarterly Capacity Strategy Review is complete. All 11 tasks
finished successfully.

**Summary of deliverables:**

1. **Teams Strategy Brief** — Posted with 3 embedded charts (cost trend,
commitment alignment, maturity radar), financial tables, maturity
scorecard, and a Q3 roadmap with 6 prioritized actions.

2. **Key findings:**
   - Effective savings rate is only **2.81%** (target: 15-25%) — 96% of
core-hours are on-demand
   - **$8,880/quarter** ($35,520/year) addressable through top 10
reservation recommendations
   - SQL DB BC Gen5 in West US 2 is the single largest savings opportunity
($2,388/qtr at 55% discount)
   - No capacity reservation groups deployed; no quota/budget/anomaly
alerts configured
   - Supply chain maturity: Forecast/Procure/Allocate at Crawl, Monitor at
Walk
   - All quotas well within limits (0% compute utilization, 1.2% storage
utilization)

3. **Knowledge base** — Updated
[quarterly-capacity-strategy-findings.md](/api/files/memories/synthesizedKnowledge/quarterly-capacity-strategy-findings.md)
with methodology, scoring framework, tool execution patterns, and known
issues.

4. **No code changes needed** — This analytical task didn't surface
codebase defects. Operational learnings are captured in the knowledge base
for future runs.
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Reading existing knowledge base documents
- Starting Phase 0: Preparation. Reading knowledge base documents and loading
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the skill. Now let me read
- Knowledge base loaded. I have prior findings from health checks on
- Good, I've loaded the knowledge base and skill references. Now let me mark
- 1. Save operational learnings to the knowledge base (task 9)
- knowledge base first.
- Created file: memory: quarterly-capacity-strategy-findings.md (90 lines)
- knowledge base (task 9). I need to:
- - Knowledge base updated with operational learnings
- tables and embedded images, and the knowledge base file creation. However,
- knowledge base updated without issues. I should check if there are any
- changes—the knowledge base already captured those learnings. The
- - Knowledge base updated with methodology and operational learnings
- operational learnings are captured in the knowledge base file, which is the
- 3. **Knowledge base** — Updated
- [quarterly-capacity-strategy-findings.md](/api/files/memories/synthesizedKnowledge/quarterly-capacity-strategy-findings.md)
- codebase defects. Operational learnings are captured in the knowledge base

## MCAPS asks this task answers
- **#9:** Reports no CRGs deployed and therefore no idle CRG waste.
- **#17:** Quantifies RI opportunity and current on-demand exposure for RI/SP positioning.
- **#18:** Combines capacity planning maturity with commitment recommendations and Q3 roadmap.
- **#21:** Quarterly strategy gives 90-day planning horizon and maturity roadmap.
- **#43:** Scores supply-chain maturity: Forecast/Procure/Allocate at Crawl, Monitor at Walk.
- **#62:** Shows $8,880/quarter reservation opportunity and ESR gap.
- **#71:** Combines quota, CRG, and benefit data in one strategy brief.
