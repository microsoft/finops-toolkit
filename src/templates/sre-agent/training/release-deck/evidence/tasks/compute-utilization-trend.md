# Compute Utilization Trend

## Identity
- **YAML:** sre-config/scheduled-tasks/compute-utilization-trend.yaml
- **Cron:** 0 7 * * 1 — weekly on Monday at 07:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Reporting & Analytics (Capacity)
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage, resource-graph-query, query, vm-quota-usage

## Latest run summary
The weekly compute utilization trend task completed successfully. Here's the summary: **Results:** **Subscription:** Non-Prod-Workloads — PaaS-only, no VMs/VMSS/AKS deployed **7 regions scanned:** All at 0% compute quota utilization **No flags:** No families above 80% or 95% thresholds **Baseline established:** First run — future reports will include week-over-week trends **Deliverables:** Report posted to Teams with risk scorecard, headroom chart, and

## Final Teams card / Outlook output (verbatim)
~~~~text
The weekly compute utilization trend task completed successfully. Here's
the summary:

**Results:**
- **Subscription:** Non-Prod-Workloads — PaaS-only, no VMs/VMSS/AKS
deployed
- **7 regions scanned:** All at 0% compute quota utilization
- **No flags:** No families above 80% or 95% thresholds
- **Baseline established:** First run — future reports will include
week-over-week trends

**Deliverables:**
- Report posted to Teams with risk scorecard, headroom chart, and
recommendations
- Baseline findings saved to
[weekly-compute-utilization-trend.md](/api/files/memories/synthesizedKnowledge/weekly-compute-utilization-trend.md)
for future comparisons

**Notable:** westus has an elevated 350 vCPU quota (vs 100 default) with 0%
usage — worth reviewing whether the increase is still needed.
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Phase 0: Read knowledge base documents, load capacity management skill
- Let me start by setting up the todo list and reading the knowledge base.
- Reading knowledge base and loading the capacity management skill in
- Read file: memory: finops-hub-health-check-findings.md
- Knowledge base read complete. Key notes from prior findings:
- Knowledge base and skill loaded. Key context: subscription
- Looking back at the knowledge base, I see there was a same-day API check on
- the knowledge base.
- knowledge base.
- Saving the baseline findings to the knowledge base for future weekly
- Created file: memory: weekly-compute-utilization-trend.md (49 lines)
- - Baseline findings saved to
- [weekly-compute-utilization-trend.md](/api/files/memories/synthesizedKnowledge/weekly-compute-utilization-trend.md)

## MCAPS asks this task answers
- **#8:** Establishes no compute quota pressure despite elevated westus quota.
- **#21:** Creates a baseline for future week-over-week compute utilization trends.
- **#24:** Scans 7 regions for proactive quota thresholds.
- **#71:** Makes capacity visibility explicit: no VMs/VMSS/AKS and all scanned regions at 0%.
