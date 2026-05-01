# Agent instructions

**⛔ PROHIBITED: Manual Azure resource intervention.** Do not run `az`, `srectl`, ARM REST calls, or any other command against live Azure resources outside of `deploy.sh` or `azd up`. Agents have repeatedly corrupted production deployments by running ad-hoc commands against live SRE Agent resources. All Azure changes go through the release process. No exceptions.

Load the `azure-sre-agent` skill at session start and after every compaction or summarization.

## Template inventory

| Component | Count | Details |
|-----------|-------|---------|
| Subagents | 5 | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 33 | 21 Kusto (KQL against FinOps Hub) + 12 Python (ARM REST API via UAMI) |
| Scheduled tasks | 18 | 9 core (daily/weekly/monthly/quarterly) + 9 capacity/governance |
| Connector | 1 | Kusto MCP → FinOps Hub ADX cluster |

## Connection details

```yaml
default_environment: finops-hub
environments:
  finops-hub:
    cluster-uri: https://<your-cluster>.kusto.windows.net/<database>
    tenant: <tenant-id>
    subscription: <subscription-id>
    resource-group: <resource-group>
```

## Deployment target

- Subscription: `/subscriptions/<subscription-id>`
- Resource group: `/subscriptions/<subscription-id>/resourceGroups/<resource-group>`
- Supported regions: `eastus2`, `swedencentral`, `australiaeast`

See [README.md](README.md) for deployment instructions, architecture, and post-deploy verification.

## Key references

- [CATALOG.md](CATALOG.md) — Full scheduled task catalog with FinOps Framework alignment
- [README.md](README.md) — Deployment guide, architecture, prerequisites
- `sre-config/agents/` — Subagent YAML definitions
- `sre-config/skills/` — Skill directories
- `sre-config/knowledge/` — Knowledge docs uploaded to the agent
- `sre-config/connectors/` — Kusto connector YAML
