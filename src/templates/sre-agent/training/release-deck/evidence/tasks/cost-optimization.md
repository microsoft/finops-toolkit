# Cost Optimization

## Identity
- **YAML:** sre-config/scheduled-tasks/cost-optimization.yaml
- **Cron:** 0 8 * * 1 — weekly on Monday at 08:00 UTC
- **Owning subagent:** finops-practitioner
- **FinOps Framework capability:** Workload Optimization + Rate Optimization
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, non-compute-quotas, benefit-recommendations, Look for cost anomalies and trends that inform optimization priorities.

## Phase 3: Analysis

### 3a: Validate top rightsizing recommendations

For the top 5 Advisor right-size VM recommendations (by savings amount), validate with the Retail Prices API.

Use, to look up current and target SKU prices. Compare Advisor's estimated savings against actual retail price deltas.

### 3b: VM utilization deep dive (if VM Insights available)

For the top rightsizing candidates, check actual utilization metrics if VM Insights is enabled.

Use, for:
- 14-day CPU P95 analysis
- Memory utilization (if VM Insights agent deployed)
- Burst pattern detection (P99 check)

Skip this step if VM Insights is not available — note it as a recommendation for future optimization maturity.

### 3c: Categorize by effort and risk
Before categorizing, use, to identify Storage and Network quota pressure that may affect optimization feasibility.

Organize all findings into four categories:

| Category | Effort | Risk | Examples |
|----------|--------|------|----------|
| **Quick wins** | Low | Zero | Delete orphaned resources, remove unused IPs |
| **Rightsizing** | Medium | Low | Resize underutilized VMs (requires restart) |
| **Commitment optimization** | Medium | Medium | Purchase savings plans or reservations |
| **Architecture changes** | High | Variable | Redesign for cost efficiency, migrate to PaaS |

## Phase 4: Report

Generate a markdown report with the following structure:

### Report template, for deeper analysis
- Do not save task reports or financial data to the git repository — use #remember for key operational findings instead

## Phase 5: Deliver


**Visualizations:** Before posting, generate charts for key findings using matplotlib or seaborn via the code interpreter. Include at minimum one trend chart and one comparison chart where the data supports it. Verify each generated chart non-visually before embedding by checking the output file exists, has non-zero size, opens as an image, and reports expected dimensions and metadata through code interpreter filesystem or image-library checks. Do not use visual inspection as the verification gate; regenerate or omit any chart that fails these checks and state why. Embed the chart images inline in the Teams message alongside the text tables. Charts make the report immediately actionable for stakeholders who scan rather than read.
**Teams (financial results only):** Post the final cost optimization report to our Teams channel. Include the executive summary, total identified savings, quick wins, and prioritized next steps. Do not post intermediate results — only the completed report. Use

## Latest run summary
The weekly cost optimization report has been completed and posted to Teams. Here's a summary of what was done: **Key Findings (April 2026):** **Effective cost:** $40,306 (▼3.8% vs March) **Orphaned resources:** Environment is clean — only 5 orphaned NSGs (no cost impact) **Advisor recommendations:** 29 total, $3,407/mo potential savings (18 RI, 2 shutdown idle VMs, 9 savings plan/other) **Commitment coverage:** Only 3.5% of core hours are covered by

## Final Teams card / Outlook output (verbatim)
~~~~text
The weekly cost optimization report has been completed and posted to Teams.
Here's a summary of what was done:

**Key Findings (April 2026):**
- **Effective cost:** $40,306 (▼3.8% vs March)
- **Orphaned resources:** Environment is clean — only 5 orphaned NSGs (no
cost impact)
- **Advisor recommendations:** 29 total, $3,407/mo potential savings (18
RI, 2 shutdown idle VMs, 9 savings plan/other)
- **Commitment coverage:** Only 3.5% of core hours are covered by
reservations — 96.5% on-demand
- **ESR:** 2.80% — well below the 20%+ FinOps target
- **Top reservation opportunity:** $8,881/mo savings across top 10
recommendations (SQL DB, VMs)
- **No cost anomalies detected** — stable ~$1,340–$1,390/day

**Delivered:**
- Full report with 4 charts posted to
[Teams](https://teams.microsoft.com/l/message/19%3ABpZihiFQYCvAeVjSALERBqmtDPW7p8_QESgBTG7xz7M1%40thread.tacv2/1777746727277?groupId=8b3d5b2c-2edc-4a9f-a0ff-0ed3856d5af3&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&createdTime=1777746727277&parentMessageId=1777746727277)
- Operational learnings saved to knowledge base (Resource Graph
workarounds, Advisor patterns)

**Biggest opportunity:** Commitment discounts — purchasing reservations for
the top SQL DB and VM workloads could save up to $8,881/mo and dramatically
improve the ESR from 2.8% toward the 20%+ target.
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- Biggest opportunity:** Commitment discounts — purchasing reservations for

## Knowledge updates
- 1. Reading knowledge base documents
- Starting Phase 0: Reading knowledge base and reference documents.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I have the knowledge base read. Key learnings from previous runs:
- Knowledge base loaded. Key learnings noted: FinOps Hub is connected
- Good, Phase 0 is mostly done - I've read the knowledge base and all
- Discovery. I know from the knowledge base:
- Discovery confirmed from knowledge base: Subscription
- 2. Save operational learnings to the knowledge base
- operational learnings to the knowledge base.
- knowledge base. Let me first read the existing knowledge base file to see
- Now I'll update the knowledge base with these findings.
- operational learnings to the knowledge base. Let me complete that final
- Let me update the knowledge base with operational learnings from this cost
- Now I'm saving these operational patterns to the knowledge base.
- Edited file: memory: finops-hub-health-check-findings.md
- - Operational learnings saved to knowledge base (Resource Graph

## MCAPS asks this task answers
- **#17:** Finds 96.5% on-demand core hours and RI/SP commitment discount opportunity.
- **#29:** Surfaces optimization levers through Advisor and reservation opportunities.
- **#43:** Uses ESR target comparison to show FinOps rate-optimization maturity gap.
- **#62:** Quantifies reservation opportunity and ESR improvement path.
- **#64:** Uses Advisor, Resource Graph, and Hub trend data to distinguish native and FTK signals.
- **#66:** Reports stable cost and no anomalies to support finance trust.
