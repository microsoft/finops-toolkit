# Alert Coverage Audit

## Identity
- **YAML:** sre-config/scheduled-tasks/alert-coverage-audit.yaml
- **Cron:** 0 8 16 * * — monthly on day 16 at 08:00 UTC
- **Owning subagent:** finops-practitioner
- **FinOps Framework capability:** Anomaly Management
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, query

## Latest run summary
The monthly Alert Coverage Audit has completed successfully. Here's the summary: **Scope:** 1 active subscription (Non-Prod-Workloads) **Key Findings (5 total):** exists but unused | **High** | **What was done:** Queried Azure Resource Graph and Cost Management APIs for all alert-related resources Inventoried 8 alert resources: 4 App Insights smart detectors, 3 action groups, 1 activity log alert Confirmed 0 cost anomaly alerts and 0 scheduled query rules exist

## Final Teams card / Outlook output (verbatim)
~~~~text
The monthly Alert Coverage Audit has completed successfully. Here's the
summary:

**Scope:** 1 active subscription (Non-Prod-Workloads)

**Key Findings (5 total):**

| # | Finding | Severity |
|---|---------|----------|
| 1 | No cost anomaly detection alerts configured | **Critical** |
| 2 | Budget & health alerts route to single person (AGOwner) — AGManager
exists but unused | **High** |
| 3 | No KQL-based cost alerts via FinOps Hub | **High** |
| 4 | Subscription missing owner/environment/team tags | Medium |
| 5 | Transactions() data gap persists (0 rows) | Medium |

**What was done:**
- Queried Azure Resource Graph and Cost Management APIs for all
alert-related resources
- Inventoried 8 alert resources: 4 App Insights smart detectors, 3 action
groups, 1 activity log alert
- Confirmed 0 cost anomaly alerts and 0 scheduled query rules exist
- Ran FinOps Hub anomaly detection (90-day window) — 0 true anomalies,
stable ~$1,340–$1,390/day
- Generated 3 visualization charts (coverage matrix, gap analysis,
notification routing)
- Posted full report with tables and charts to Teams
- Saved operational findings to
[alert-coverage-audit-findings.md](/api/files/memories/synthesizedKnowledge/alert-coverage-audit-findings.md)
~~~~

## Finding tables
| # | Finding | Severity |
|---|---------|----------|
| 1 | No cost anomaly detection alerts configured | **Critical** |
| 2 | Budget & health alerts route to single person (AGOwner) — AGManager exists but unused | **High** |
| 3 | No KQL-based cost alerts via FinOps Hub | **High** |
| 4 | Subscription missing owner/environment/team tags | Medium |
| 5 | Transactions() data gap persists (0 rows) | Medium |

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Read knowledge base documents
- 9. Save operational findings to knowledge base
- Reading existing knowledge base and loading the FinOps practitioner skill
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base read complete. The finops-practitioner skill doesn't exist,
- Knowledge base reviewed — I have prior findings on hub architecture, data
- as noted in the knowledge base).
- data, not real anomalies — consistent with prior knowledge base findings).
- 2. Save operational findings to the knowledge base
- knowledge base.
- Read file: memory: advisor-suppression-review-findings.md
- knowledge base. Let me create the knowledge base file with non-financial
- Created file: memory: alert-coverage-audit-findings.md (92 lines)
- [alert-coverage-audit-findings.md](/api/files/memories/synthesizedKnowledge/alert-coverage-audit-findings.md)

## MCAPS asks this task answers
- **#27:** Shows budget and health alerts exist but cost anomaly alerts are absent; highlights guardrail gap.
- **#48:** Confirms 0 cost anomaly alerts and 0 scheduled query rules, exposing native monitoring gaps.
- **#55:** Defines post-deploy alert ownership/routing gaps: AGOwner only, AGManager unused.
- **#70:** Uses Teams charts/reporting to make alert coverage visible to operators.
