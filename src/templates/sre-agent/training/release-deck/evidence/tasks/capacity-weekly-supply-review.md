# Capacity Weekly Supply Review

## Identity
- **YAML:** sre-config/scheduled-tasks/capacity-weekly-supply-review.yaml
- **Cron:** 0 8 * * 1 — weekly on Monday at 08:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Quota Reporting + Rate Optimization
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, vm-quota-usage, non-compute-quotas, capacity-reservation-groups, benefit-recommendations, reservation-recommendation-breakdown

## Latest run summary
The weekly capacity supply chain review completed successfully. Here's the summary: **Quota Headroom:** All green — zero active VM compute usage across 49 regions (10,599 entries), no at-risk families. Non-compute quotas all under 2% utilization; 7 Network Watcher entries flagged at 100% are cosmetic (Azure auto-provisioned defaults). **CRG Audit:** No capacity reservation groups deployed — $0 waste. **SKU Availability:** 1,100/1,173 compute SKUs available in westus (73

## Final Teams card / Outlook output (verbatim)
~~~~text
The weekly capacity supply chain review completed successfully. Here's the
summary:

**Quota Headroom:** All green — zero active VM compute usage across 49
regions (10,599 entries), no at-risk families. Non-compute quotas all under
2% utilization; 7 Network Watcher entries flagged at 100% are cosmetic
(Azure auto-provisioned defaults).

**CRG Audit:** No capacity reservation groups deployed — $0 waste.

**SKU Availability:** 1,100/1,173 compute SKUs available in westus (73
restricted are legacy/promo). Kusto `Dev(No SLA)_Standard_E2a_v4` confirmed
available — no FinOps Hub blocker.

**Top Benefit Recommendations:** 10 reservation opportunities totaling
~$8,880 in estimated savings, led by SQL DB Business Critical Gen5 in West
US 2 ($2,388/3yr) and DSv2 VMs in East US ($1,083/1yr).

**Deliverables:**
- Teams briefing posted with 3 embedded charts (quota scorecard,
non-compute usage, benefit recommendations)
- Knowledge base updated with operational findings (no financial data
saved)
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. First, read knowledge base documents
- Let me start by setting up my todo list and reading the knowledge base.
- Reading knowledge base and loading the capacity management skill.
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base and skill loaded. I have good context from previous runs.
- Knowledge base and skill loaded. Previous findings noted: Network Watchers
- and proceed to save operational learnings to the knowledge base, then wrap
- Read file: memory: weekly-compute-utilization-trend.md
- Read file: memory: sku-availability-audit-findings.md
- **Reviewing knowledge base content**
- knowledge base. I was in the middle of reading existing knowledge files
- when the conversation continued. Let me now update the knowledge base files
- Completing the final task — updating knowledge base with operational
- Edited file: memory: weekly-compute-utilization-trend.md
- Edited file: memory: sku-availability-audit-findings.md
- - Knowledge base updated with operational findings (no financial data

## MCAPS asks this task answers
- **#8:** Shows zero VM compute usage across 49 regions and separates quota headroom from CRG state.
- **#9:** CRG audit finds no CRGs deployed and $0 waste.
- **#14:** Confirms SKU availability in westus and identifies restricted legacy/promo SKUs.
- **#17:** Ranks top benefit recommendations and RI opportunities.
- **#24:** Weekly review monitors quota headroom, non-compute quotas, CRGs, SKU availability, and benefits.
- **#62:** Quantifies top reservation opportunities at about $8,880 savings.
