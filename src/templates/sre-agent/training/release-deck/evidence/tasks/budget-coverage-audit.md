# Budget Coverage Audit

## Identity
- **YAML:** sre-config/scheduled-tasks/budget-coverage-audit.yaml
- **Cron:** 0 8 15 * * — monthly on day 15 at 08:00 UTC
- **Owning subagent:** finops-practitioner
- **FinOps Framework capability:** Budgeting
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, query

## Latest run summary
The Budget Coverage Audit has completed successfully. Here's a summary of what was done: **Audit Scope:** 1 active subscription (Non-Prod-Workloads), 20 resource groups **Key Findings:** **Budget exists** — FDPOAzureBudget with 6 alert thresholds (actual + forecast) routing to action groups **No RG-level budgets** — 0/20 resource groups have dedicated budgets **No budget enforcement policy** — 32 policies exist, none enforce budget

## Final Teams card / Outlook output (verbatim)
~~~~text
The Budget Coverage Audit has completed successfully. Here's a summary of
what was done:

**Audit Scope:** 1 active subscription (Non-Prod-Workloads), 20 resource
groups

**Key Findings:**
- **Budget exists** — FDPOAzureBudget with 6 alert thresholds (actual +
forecast) routing to action groups
- **No RG-level budgets** — 0/20 resource groups have dedicated budgets
- **No budget enforcement policy** — 32 policies exist, none enforce budget
creation
- **Critical tag gaps** — 0% Owner coverage, 0% CostCenter coverage, 10%
Environment coverage

**Actions Taken:**
1. Queried subscription inventory, budgets (Consumption API), resource
group tags, and policy assignments
2. Generated 3 charts (budget coverage, tag coverage, alert configuration)
3. Posted full report with embedded charts to Teams ([message
link](https://teams.microsoft.com/l/message/19%3ABpZihiFQYCvAeVjSALERBqmtDPW7p8_QESgBTG7xz7M1%40thread.tacv2/1777746628950?groupId=8b3d5b2c-2edc-4a9f-a0ff-0ed3856d5af3&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&createdTime=1777746628950&parentMessageId=1777746628950))
4. Saved operational findings (no financial data) to
[budget-coverage-audit-findings.md](/api/files/memories/synthesizedKnowledge/budget-coverage-audit-findings.md)

**Maturity: Crawl** — subscription budget exists with good alert structure,
but tag governance and policy enforcement are needed to advance to Walk
stage.
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Read knowledge base documents
- 9. Save operational findings to knowledge base
- Let me start by setting up the todo list and reading the knowledge base.
- Reading knowledge base and loading the FinOps practitioner skill in
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base read complete. The finops-practitioner skill isn't
- Knowledge base read complete. The `finops-practitioner` skill isn't
- Teams post done and saving operational findings to the knowledge base.
- Read file: memory: advisor-suppression-review-findings.md
- Created file: memory: budget-coverage-audit-findings.md (72 lines)
- [budget-coverage-audit-findings.md](/api/files/memories/synthesizedKnowledge/budget-coverage-audit-findings.md)

## MCAPS asks this task answers
- **#27:** Finds FDPOAzureBudget with 6 alert thresholds but no RG-level budgets or enforcement policy.
- **#36:** Shows 0% Owner and CostCenter tag coverage plus only 10% Environment coverage.
- **#41:** Verifies budget inventory and policy assignments as cost-reporting readiness inputs.
- **#43:** Classifies maturity as Crawl due to budget and tag-governance gaps.
