# Non-Compute Quota Audit

## Identity
- **YAML:** sre-config/scheduled-tasks/non-compute-quota-audit.yaml
- **Cron:** 0 7 * * 2 — weekly on Tuesday at 07:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Quota Monitoring (non-compute)
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage, non-compute-quotas, quotas, quota_name

## Latest run summary
The weekly Non-Compute Quota Audit completed successfully. Here's the summary: **Results:** **Status: GREEN** — 0 actionable at-risk quotas 2,846 quota entries scanned across 6 services (Storage, Network, App Service plans, SQL servers, Service Bus, Key Vault) in 49 regions All 7 flagged entries were Network Watchers (1/1 per region) — auto-provisioned defaults, excluded from risk reporting Peak utilization: 1.2% (Storage Accounts in westus, 3/250)

## Final Teams card / Outlook output (verbatim)
~~~~text
The weekly Non-Compute Quota Audit completed successfully. Here's the
summary:

**Results:**
- **Status: GREEN** — 0 actionable at-risk quotas
- 2,846 quota entries scanned across 6 services (Storage, Network, App
Service plans, SQL servers, Service Bus, Key Vault) in 49 regions
- All 7 flagged entries were Network Watchers (1/1 per region) —
auto-provisioned defaults, excluded from risk reporting
- Peak utilization: 1.2% (Storage Accounts in westus, 3/250)
- 106 API errors from stage/preview/canary regions (expected, consistent
with prior runs)
- 4 estimated limits verified at low utilization

**Actions taken:**
- Full report with 4 embedded charts posted to Teams
- Knowledge base updated with audit findings
- No runbook or code changes needed — execution matched the task prompt
exactly
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Read knowledge base documents
- Let me start by setting up a todo list and reading the knowledge base.
- Reading knowledge base documents and loading the capacity management skill.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the capacity management
- Key findings from knowledge base:
- Knowledge base read and skill loaded. Key prior findings noted: Network
- remaining tasks: save operational findings to knowledge base, review
- knowledge base.
- - Task 8: Save operational findings to knowledge base (in-progress)
- Let me update the knowledge base with the non-compute quota audit findings,
- knowledge base now.
- Edited file: memory: finops-hub-health-check-findings.md
- Continuing with the remaining audit tasks. Knowledge base was updated
- - Prior knowledge base learning about Network Watcher exclusions saved
- Let me commit the knowledge base update.
- **Preparing knowledge base PR**
- I need to commit the knowledge base update and create a PR. Let me check
- Completing the final task — committing the knowledge base update and
- directory is. The knowledge base update I made is in the memories/

## MCAPS asks this task answers
- **#8:** Distinguishes real quota risk from Network Watcher false positives.
- **#14:** Audits Storage, Network, App Service, SQL, Service Bus, and Key Vault quota availability.
- **#24:** Scans 2,846 quota entries weekly and reports zero actionable at-risk quotas.
- **#71:** Provides non-compute quota visibility across 49 regions.
