# Hubs Health Check

## Identity
- **YAML:** sre-config/scheduled-tasks/hubs-health-check.yaml
- **Cron:** 0 6 * * * — daily at 06:00 UTC
- **Owning subagent:** ftk-hubs-agent
- **FinOps Framework capability:** Data Ingestion & Normalization
- **Maturity:** Crawl
- **Tools used:** PostTeamsMessage, data-freshness-check, Costs(), Transactions(), reservationtransactions, Prices(), Recommendations()

## Latest run summary
The scheduled health check is complete. Here's the summary: FinOps Hub Health Check — 2026-05-02 18:28 UTC Version Status The hub is one major version behind. Deploy the latest via [https://aka.ms/finops/hubs/deploy](https://aka.ms/finops/hubs/deploy). Data Freshness Action Items 1. **Upgrade hub to v14.0** — current version (13.0) is behind the latest stable release. 2. **Investigate Transactions()** — persistently empty across all health

## Final Teams card / Outlook output (verbatim)
~~~~text
The scheduled health check is complete. Here's the summary:

## FinOps Hub Health Check — 2026-05-02 18:28 UTC

### Version Status

| Item | Value | Status |
|------|-------|--------|
| Current Hub Version | 13.0 | ⚠️ Upgrade recommended |
| Latest Stable | 14.0 | — |
| Latest Dev | 14.0 | — |

The hub is one major version behind. Deploy the latest via
[https://aka.ms/finops/hubs/deploy](https://aka.ms/finops/hubs/deploy).

### Data Freshness

| Function | Rows | Latest ChargePeriodStart | Staleness | Status |
|----------|------|--------------------------|-----------|--------|
| Costs() | 1,266,578 | 2026-05-01 | 1 day | ✅ Healthy |
| Prices() | 14,343,006 | N/A | N/A | ✅ Healthy |
| Recommendations() | 45 | — | — | ✅ Present |
| Transactions() | 0 | — | — | ℹ️ Empty |

### Action Items
1. **Upgrade hub to v14.0** — current version (13.0) is behind the latest
stable release.
2. **Investigate Transactions()** — persistently empty across all health
checks today. Verify commitment transaction exports in [Cost
Management](https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/exports).

Results posted to Teams and operational learnings saved to knowledge base.
~~~~

## Finding tables
| Item | Value | Status |
|------|-------|--------|
| Current Hub Version | 13.0 | ⚠️ Upgrade recommended |
| Latest Stable | 14.0 | — |
| Latest Dev | 14.0 | — |

| Function | Rows | Latest ChargePeriodStart | Staleness | Status |
|----------|------|--------------------------|-----------|--------|
| Costs() | 1,266,578 | 2026-05-01 | 1 day | ✅ Healthy |
| Prices() | 14,343,006 | N/A | N/A | ✅ Healthy |
| Recommendations() | 45 | — | — | ✅ Present |
| Transactions() | 0 | — | — | ℹ️ Empty |

## Recommendations
- 1. **Upgrade hub to v14.0** — current version (13.0) is behind the latest
- 2. **Investigate Transactions()** — persistently empty across all health

## Knowledge updates
- 1. **Phase 0**: Read knowledge base documents for prior findings
- Let me start by setting up my todo list and reading the knowledge base.
- Reading knowledge base and loading the FinOps hubs skill for this health
- Read file: memory: finops-hub-health-check-findings.md
- Good, I've read the knowledge base and loaded the FinOps toolkit skill. Now
- Knowledge base loaded — prior findings noted (hub was v13.0, stable was
- The ftkver.txt file path has changed. From my knowledge base, I know it
- The file path changed — knowledge base notes it moved to
- check the current hub instance version. From my knowledge base, I know the
- 2. Save operational learnings to the knowledge base
- Let me first update the knowledge base with findings from this run, then
- Looking at the prior knowledge base, the data is mostly consistent with
- The knowledge base already has solid content, so I'll update it with this
- the knowledge base. Let me update the knowledge base file with the latest
- Now I'm updating the knowledge base file with these findings.
- Updating the knowledge base with findings from this health check run.
- update the knowledge base with the latest timestamp and then address the
- Continuing with the scheduled health check — updating the knowledge base
- Edited file: memory: finops-hub-health-check-findings.md
- operational learnings. Let me update the knowledge base with the latest

## MCAPS asks this task answers
- **#41:** Validates Costs(), Prices(), Recommendations(), and Transactions() freshness/readiness.
- **#56:** Flags hub v13.0 behind v14.0 and recommends upgrade.
- **#58:** Identifies persistent Transactions() empty condition and directs export investigation.
- **#63:** Provides hub data freshness evidence used for portal/Kusto reconciliation confidence.
- **#66:** Health status and freshness counts support data credibility.
- **#68:** Shows current hub data-model maturity; Fabric remains outside this task.
- **#69:** Demonstrates agent-readiness through automated health evidence.
