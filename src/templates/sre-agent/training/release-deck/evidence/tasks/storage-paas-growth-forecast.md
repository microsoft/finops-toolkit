# Storage PaaS Growth Forecast

## Identity
- **YAML:** sre-config/scheduled-tasks/storage-paas-growth-forecast.yaml
- **Cron:** 0 8 1 * * — monthly on day 1 at 08:00 UTC
- **Owning subagent:** azure-capacity-manager
- **FinOps Framework capability:** Forecasting (Capacity)
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, query, non-compute-quotas, quotas, quota_name

## Latest run summary
The scheduled task **StoragePaasGrowthForecast** completed successfully. Here's the summary: **Results:** **Subscription scanned:** cab7feeb-759d-478c-ade6-9326de0651ff (single subscription) **2,846 quota entries** collected across all regions via ARM provider usages API **0 real at-risk items** — all non-compute quotas are below 2% utilization 7 Network Watcher entries at 100% excluded (known auto-provisioned false positives)

## Final Teams card / Outlook output (verbatim)
~~~~text
The scheduled task **StoragePaasGrowthForecast** completed successfully.
Here's the summary:

**Results:**
- **Subscription scanned:** cab7feeb-759d-478c-ade6-9326de0651ff (single
subscription)
- **2,846 quota entries** collected across all regions via ARM provider
usages API
- **0 real at-risk items** — all non-compute quotas are below 2%
utilization
- 7 Network Watcher entries at 100% excluded (known auto-provisioned false
positives)
- 4 estimated limits noted (Key Vault, App Service, SQL, Service Bus — no
API-reported limits available)
- 106 API errors from stage/preview regions — expected and non-actionable

**Key resource counts:** 6 Storage Accounts, 2 Kusto Clusters, 3 Cognitive
Services, 10 NSGs, 3 VNets — all well within limits across westus and
eastus2.

**Deliverables:**
1. Full report with 3 charts posted to Teams (quota utilization, 90-day
forecast, resource distribution)
2. Baseline data saved to
[storage-paas-quota-baseline.md](/api/files/memories/synthesizedKnowledge/storage-paas-quota-baseline.md)
for future month-over-month comparison
3. Next month's run will detect growth trends by comparing against this
baseline
~~~~

## Finding tables
No tabular data was present in the final output.

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
- 1. Reading the knowledge base documents
- Reading knowledge base and loading the capacity management skill.
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the capacity management
- Knowledge base loaded. Key prior findings noted: Network Watchers (1/1 per
- the report, then post everything to Teams and save it to the knowledge base
- 5. Save to knowledge base
- 4. Save findings to knowledge base
- to Teams (step 8) and then save findings to the knowledge base (step 9).
- 2. Save findings to knowledge base (task 9)
- knowledge base.
- knowledge base. Let me create/update the knowledge base file with the
- Created file: memory: storage-paas-quota-baseline.md (87 lines)
- 2. Baseline data saved to
- [storage-paas-quota-baseline.md](/api/files/memories/synthesizedKnowledge/storage-paas-quota-baseline.md)

## MCAPS asks this task answers
- **#14:** Collects non-compute provider usage across Storage, Network, App Service, SQL, Service Bus, and Key Vault.
- **#21:** Creates baseline for future MoM storage/PaaS quota-growth forecasting.
- **#24:** Automates proactive non-compute quota monitoring with false-positive exclusions.
- **#71:** Shows PaaS and storage capacity headroom across regions.
