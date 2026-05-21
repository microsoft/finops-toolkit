# Capacity Daily Monitor

## Identity
- **YAML:** sre-config/scheduled-tasks/capacity-daily-monitor.yaml
- **Cron:** 30 6 * * * — daily at 06:30 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Quota Monitoring (Capacity Management)
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage, vm-quota-usage, capacity-reservation-groups, data-freshness-check, non-compute-quotas

## Latest run summary
**Daily Capacity Supply Chain Health Check — 2026-05-02 18:30 UTC** All 10 checks completed successfully. Here's the summary: Overall Status: HEALTHY 0% | rows | **One known issue persists:** Transactions() remains at 0 rows — requires investigation of Cost Management transaction export configuration. **Charts:** **Deliverables:** Teams summary posted (message ID: `1777746631571`) Knowledge base updated with new operational learning (defensive `None`

## Final Teams card / Outlook output (verbatim)
~~~~text
**Daily Capacity Supply Chain Health Check — 2026-05-02 18:30 UTC**

All 10 checks completed successfully. Here's the summary:

## Overall Status: HEALTHY

| Check | Status | Detail |
|-------|--------|--------|
| VM Quota (westus) | HEALTHY | 0/350 regional vCPUs used, all families at
0% |
| Non-Compute Quota | HEALTHY | 62 quotas checked, all below thresholds |
| Capacity Reservations | N/A | No CRGs configured |
| AKS Node Pools | N/A | No AKS clusters in subscription |
| Alerts (24h) | HEALTHY | 0 alerts fired |
| Hub Data Freshness | HEALTHY | Costs 1.27M rows (May 2026), Prices 14.3M
rows |

**One known issue persists:** Transactions() remains at 0 rows — requires
investigation of Cost Management transaction export configuration.

**Charts:**

![capacity-health-overview.png](/api/files/tmp/ThreadFiles/2ab4d2ea-8cbc-436a-b50e-d7a8dbf37ee2/capacity-health-overview.png)

![capacity-quota-utilization.png](/api/files/tmp/ThreadFiles/2ab4d2ea-8cbc-436a-b50e-d7a8dbf37ee2/capacity-quota-utilization.png)

**Deliverables:**
- Teams summary posted (message ID: `1777746631571`)
- Knowledge base updated with new operational learning (defensive `None`
handling for VM quota `utilization_pct` field)
~~~~

## Finding tables
| Check | Status | Detail |
|-------|--------|--------|
| VM Quota (westus) | HEALTHY | 0/350 regional vCPUs used, all families at 0% |
| Non-Compute Quota | HEALTHY | 62 quotas checked, all below thresholds |
| Capacity Reservations | N/A | No CRGs configured |
| AKS Node Pools | N/A | No AKS clusters in subscription |
| Alerts (24h) | HEALTHY | 0 alerts fired |
| Hub Data Freshness | HEALTHY | Costs 1.27M rows (May 2026), Prices 14.3M rows |

## Recommendations
- One known issue persists:** Transactions() remains at 0 rows — requires
- Teams summary posted (message ID: `1777746631571`)
- Knowledge base updated with new operational learning (defensive `None`

## Knowledge updates
- 1. First, read knowledge base documents
- Let me start by setting up a todo list and reading the knowledge base.
- Reading knowledge base and loading the capacity management skill.
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base read and skill loaded. Let me update the todo list and
- Knowledge base loaded. Key prior findings: Network Watchers at 100% are
- - Network Watchers will likely show 1/1 (100%) but per knowledge base
- 1. ✅ Knowledge base read
- 2. Save operational learnings to the knowledge base
- - No new issues discovered beyond what's already in the knowledge base
- The knowledge base already has comprehensive notes. The only new finding is
- knowledge base. Let me review what new insights I discovered during this
- run that aren't already in the knowledge base:
- Let me update the existing knowledge base file with this new finding, then
- the middle of updating the knowledge base file with new findings from this
- Let me append this to the existing knowledge base file and mark the task
- `None` values in VM quota data to the knowledge base.
- Edited file: memory: finops-hub-health-check-findings.md
- - Knowledge base updated with new operational learning (defensive `None`

## MCAPS asks this task answers
- **#8:** Separates quota headroom from capacity reservations: 0/350 westus vCPUs used and no CRGs configured.
- **#21:** Daily check feeds short-horizon capacity trend monitoring.
- **#23:** Provides pre-flight style checks for quota, CRG, AKS, alert, and hub freshness status.
- **#24:** Automates proactive capacity monitoring; all 10 checks completed.
- **#71:** Surfaces quota/capacity visibility directly in the SRE Agent report.
