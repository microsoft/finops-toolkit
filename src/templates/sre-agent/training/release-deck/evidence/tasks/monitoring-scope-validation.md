# Monitoring Scope Validation

## Identity
- **YAML:** sre-config/scheduled-tasks/monitoring-scope-validation.yaml
- **Cron:** 0 9 * * 4 — weekly on Thursday at 09:00 UTC
- **Owning subagent:** ftk-hubs-agent
- **FinOps Framework capability:** Data Ingestion & Normalization
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage, resource-graph-query, query, data-freshness-check

## Latest run summary
The **Monitoring Scope Validation** scheduled task completed successfully. Here's a summary: **Key Findings:** **24 subscriptions** actively monitored by the Hub via cost exports **Data freshness**: Costs() healthy (1.27M rows, May 2026 billing period), Prices() healthy (14.3M rows), Recommendations() present (45 rows) **Transactions() remains empty (0 rows)** — persistent issue requiring investigation of Cost Management transaction exports

## Final Teams card / Outlook output (verbatim)
~~~~text
The **Monitoring Scope Validation** scheduled task completed successfully.
Here's a summary:

**Key Findings:**
- **24 subscriptions** actively monitored by the Hub via cost exports
- **Data freshness**: Costs() healthy (1.27M rows, May 2026 billing
period), Prices() healthy (14.3M rows), Recommendations() present (45 rows)
- **Transactions() remains empty (0 rows)** — persistent issue requiring
investigation of Cost Management transaction exports
- **Agent RBAC scope** is limited to 1 subscription (Hub infrastructure);
full coverage validation requires broader access

**Actions Taken:**
1. Queried Resource Graph for active subscription inventory
2. Validated Hub data freshness via Kusto REST API (Costs, Prices,
Recommendations, Transactions)
3. Cross-referenced subscription coverage between Resource Graph and Hub
Costs() SubAccountId
4. Generated 2 visualization charts (subscription coverage, data freshness)
5. Posted full report to Teams ([message
link](https://teams.microsoft.com/l/message/19%3ABpZihiFQYCvAeVjSALERBqmtDPW7p8_QESgBTG7xz7M1%40thread.tacv2/1777746594615?groupId=8b3d5b2c-2edc-4a9f-a0ff-0ed3856d5af3&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&createdTime=1777746594615&parentMessageId=1777746594615))
6. Updated knowledge base with operational findings

**Open Issues (4):**
| # | Issue | Severity |
|---|-------|----------|
| 1 | Transactions() empty — verify Cost Management transaction exports |
High |
| 2 | 2,332 rows with empty SubAccountId in Costs() | Medium |
| 3 | Agent RBAC limited to 1 subscription for Resource Graph validation |
Medium |
| 4 | Hub version 13.0 — upgrade to 14.0 recommended | Medium |
~~~~

## Finding tables
| # | Issue | Severity |
|---|-------|----------|
| 1 | Transactions() empty — verify Cost Management transaction exports |
High | | 2 | 2,332 rows with empty SubAccountId in Costs() | Medium | | 3 | Agent RBAC limited to 1 subscription for Resource Graph validation | Medium | | 4 | Hub version 13.0 — upgrade to 14.0 recommended | Medium |

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Reading the knowledge base documents
- Reading knowledge base and loading the FinOps Hubs skill in parallel.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the FinOps Hubs skill. Let me
- 2. Save operational findings to knowledge base (task 8)
- execution based on codeRefs. Let me update the knowledge base with the
- knowledge base.
- knowledge base (task 8). Let me complete that task by updating the
- knowledge base file with the monitoring scope validation findings.
- Completing the final task — updating the knowledge base with monitoring
- Edited file: memory: finops-hub-health-check-findings.md
- completing task 8 (saving operational findings to the knowledge base). Let
- Let me complete task 8 by finishing the knowledge base update, and also
- to the knowledge base. I also need to add the new finding about
- Completing the knowledge base update with monitoring scope validation
- 6. Updated knowledge base with operational findings

## MCAPS asks this task answers
- **#34:** Shows multi-subscription scope: 24 subscriptions monitored by Hub costs data.
- **#41:** Validates hub functions and subscription coverage for reporting readiness.
- **#58:** Flags Transactions() empty and 2,332 rows with empty SubAccountId.
- **#61:** Confirms remote/multi-subscription aggregation coverage, with RBAC limitation caveat.
- **#66:** Data freshness and open issue scorecard establish data credibility boundaries.
