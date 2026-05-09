# Agent instructions

**⛔ PROHIBITED: Manual Azure resource intervention.** Do not run Azure control-plane or data-plane commands against live SRE Agent resources outside the canonical entry point `bin/deploy.sh` and its owned helper scripts in `bicep/`. All Azure changes go through the release process. No exceptions.

Load the `azure-sre-agent` skill at session start and after every compaction or summarization.

## Template inventory

| Component | Count | Details |
|-----------|-------|---------|
| Subagents | 5 | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 34 | Kusto and Python tools under `recipes/finops-hub/config/tools/` |
| Scheduled tasks | 19 | FinOps, capacity, governance, and reporting automations |
| Connector | 1 | Kusto connector to FinOps Hub ADX cluster |

## Key references

- [README.md](README.md) — Deployment guide and architecture
- [CATALOG.md](CATALOG.md) — Full scheduled-task catalog
- `bin/deploy.sh` — Canonical deployment entry point
- `recipes/finops-hub/` — Recipe content
- `.upstream-pin` — Upstream canonical template pin

## Scheduled task Teams delivery

Scheduled-task entrypoint agents that deliver results must have explicit access to the Teams connector tools: `PostTeamsMessage`, `ReplyToTeamsMessage`, and `GetTeamsMessages`. When a Teams connector/channel is configured, results must be delivered through that configured Teams channel.
