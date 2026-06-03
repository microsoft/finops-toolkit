# Agent instructions

**⛔ PROHIBITED: Manual Azure resource intervention.** Do not run Azure control-plane or data-plane commands against live SRE Agent resources outside the canonical entry point `bin/deploy.sh` and its owned helper scripts in `infra/`, `bin/apply-extras.sh`, and the deprecated compatibility wrapper `bin/post-provision.sh`. All Azure changes go through the release process. No exceptions.

Load the `azure-sre-agent` skill at session start and after every compaction or summarization.

## Template inventory

| Component | Count | Details |
|-----------|-------|---------|
| Custom agents | 5 | `finops-practitioner` orchestrator plus four delegated subagents: `azure-capacity-manager`, `chief-financial-officer`, `ftk-database-query`, `ftk-hubs-agent` |
| Tool-bearing delegated subagents | 3 | `azure-capacity-manager`, `ftk-database-query`, `ftk-hubs-agent`; `finops-practitioner` and `chief-financial-officer` have no tools |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 50 | 37 generated Kusto tools from `src/queries/catalog/` plus 13 Python tools under `recipes/finops-hub/config/tools/` |
| Scheduled tasks | 19 | All owned by `finops-practitioner`; specialist agents are delegated by prompt, not scheduled directly |
| Connectors | 1 | Kusto connector to FinOps Hub ADX cluster |
| Knowledge docs | 6 | Five recipe knowledge files plus `ftk-output-style.md` from the Claude plugin output styles |

## Key references

- [README.md](README.md) — Deployment guide and architecture
- [CATALOG.md](CATALOG.md) — Authoritative FinOps Framework alignment, inventory, tool ownership, and scheduled-task catalog
- `bin/deploy.sh` — Canonical deployment entry point copied from the Microsoft starter-lab setup flow and updated for no-azd FinOps deployment
- `infra/` — Copied-and-updated Microsoft starter-lab Bicep baseline
- `recipes/finops-hub/` — Recipe content
- `../claude-plugin/output-styles/ftk-output-style.md` — Uploaded as SRE Agent knowledge and referenced by every scheduled task for report formatting
- `.upstream-pin` — Upstream canonical template pin

## Scheduled task Teams delivery

Scheduled-task entrypoint agents that deliver results must have explicit access to the Teams connector tools: `PostTeamsMessage`, `ReplyToTeamsMessage`, and `GetTeamsMessages`. When a Teams connector/channel is configured, results must be delivered through that configured Teams channel.
