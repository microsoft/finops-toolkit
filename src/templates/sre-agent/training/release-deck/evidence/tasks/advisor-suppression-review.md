# Advisor Suppression Review

## Identity
- **YAML:** sre-config/scheduled-tasks/advisor-suppression-review.yaml
- **Cron:** 0 9 1 * * — monthly on day 1 at 09:00 UTC
- **Owning subagent:** finops-practitioner
- **FinOps Framework capability:** Workload Optimization
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, query

## Latest run summary
**Advisor Suppression Review — May 2026 — Complete** All tasks finished successfully. Here's the summary: **Findings:** **1 suppression** found across subscription `cab7feeb-...`: `HardcodedSuppressionName` on VNet `vnet-g5ibkzemujdge` in `rg-compaq-ka` **Orphaned** — both the target resource and the Advisor recommendation have been deleted **Fails all governance checks**: no expiration (TTL=-1), no owner, no justification, no category, creation predates 90-day activity log window

## Final Teams card / Outlook output (verbatim)
~~~~text
**Advisor Suppression Review — May 2026 — Complete**

All tasks finished successfully. Here's the summary:

**Findings:**
- **1 suppression** found across subscription `cab7feeb-...`:
`HardcodedSuppressionName` on VNet `vnet-g5ibkzemujdge` in `rg-compaq-ka`
- **Orphaned** — both the target resource and the Advisor recommendation
have been deleted
- **Fails all governance checks**: no expiration (TTL=-1), no owner, no
justification, no category, creation predates 90-day activity log window
- **185 active Advisor recommendations** exist with zero currently
suppressed (the orphaned suppression isn't hiding anything)

**Actions recommended:**
1. **Remove the orphaned suppression** (immediate)
2. **Establish suppression governance policy** — require expiration, owner,
justification on all future suppressions
3. **Triage 106 High-impact recommendations** (56 Security, 29 Cost, 20 HA,
1 OpEx)
4. **Next automated review**: June 1, 2026 09:00 UTC

**Deliverables:**
- Report with charts posted to Teams (message ID: `1777746591036`)
- Operational findings saved to
[advisor-suppression-review-findings.md](/api/files/memories/synthesizedKnowledge/advisor-suppression-review-findings.md)
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- Actions recommended:
- 1. **Remove the orphaned suppression** (immediate)
- 2. **Establish suppression governance policy** — require expiration, owner,
- 3. **Triage 106 High-impact recommendations** (56 Security, 29 Cost, 20 HA,
- 4. **Next automated review**: June 1, 2026 09:00 UTC
- Report with charts posted to Teams (message ID: `1777746591036`)
- Operational findings saved to
- [advisor-suppression-review-findings.md](/api/files/memories/synthesizedKnowledge/advisor-suppression-review-findings.md)

## Knowledge updates
- 1. Read knowledge base documents
- 7. Save operational findings to knowledge base
- Let me start by reading the existing knowledge base and loading the skill.
- Reading knowledge base and loading the FinOps practitioner skill in
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base read complete. The finops-practitioner skill doesn't exist
- 2. Save operational findings to knowledge base (task 9)
- knowledge base.
- Saving operational findings to the knowledge base (no financial figures).
- Created file: memory: advisor-suppression-review-findings.md (69 lines)
- - Operational findings saved to
- [advisor-suppression-review-findings.md](/api/files/memories/synthesizedKnowledge/advisor-suppression-review-findings.md)

## MCAPS asks this task answers
- **#45:** Operationalizes workload optimization governance by finding one orphaned Advisor suppression and requiring owner/TTL/justification for future suppressions.
