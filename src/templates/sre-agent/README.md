# FinOps toolkit SRE Agent

Deploy and configure an Azure SRE Agent with FinOps Toolkit and Azure capacity-management capabilities using the canonical `microsoft/sre-agent/sreagent-templates` recipe pattern.

## What you get

| Component | Count | Description |
|-----------|-------|-------------|
| SRE Agent | 1 | `Microsoft.App/agents` resource |
| Managed identity | 1 | User-assigned identity plus system-assigned identity |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics |
| Subagents | 5 | FinOps, CFO, capacity, database-query, and hubs specialists |
| Skills | 3 | Azure capacity management, Azure cost management, and FinOps Toolkit |
| Tools | 34 | Kusto and Python tools for FinOps and capacity analysis |
| Scheduled tasks | 19 | Recurring FinOps, capacity, governance, and reporting tasks |
| Connector | 1 | Optional FinOps Hub Kusto connector when `FINOPS_HUB_CLUSTER_URI` is provided |

## Prerequisites

- Azure CLI (`az`) signed in with the intended subscription selected
- `jq`
- `python3` with PyYAML
- `curl`
- Bash 3.2 or newer
- `Microsoft.App` resource provider registered in the selected subscription
- `srectl` (required only when using `--fallback-srectl`)

Run:

```bash
bash bin/check-prerequisites.sh
```

## Deploy

The deployment uses the subscription selected in Azure CLI. Confirm it first:

```bash
az account show --query '{name:name,id:id}' -o table
```

Deploy the packaged FinOps Hub recipe:

```bash
# Deploy:
bash bin/deploy.sh recipes/finops-hub/

# Dry-run assembly only (no ARM deployment):
bash bin/deploy.sh recipes/finops-hub/ --dry-run

# ARM what-if validation:
bash bin/deploy.sh recipes/finops-hub/ --what-if
```

If your tenant blocks ARM extension child-resource writes, deploy in constrained mode:

```bash
bash bin/deploy.sh recipes/finops-hub/ --fallback-srectl
```

Constrained mode keeps core agent provisioning in Bicep, then hydrates tools/subagents/skills/scheduled tasks via `srectl`.

To include the FinOps Hub Kusto connector, set `FINOPS_HUB_CLUSTER_URI` before deployment (or put it in `recipes/finops-hub/connectors.secrets.env`). The value must include the database path (`/hub`):

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-finops-hub-cluster>.<region>.kusto.windows.net/hub"
bash bin/deploy.sh recipes/finops-hub/
```

When a system-identity Kusto connector is present, `deploy.sh` now enables a Bicep-managed ADX role assignment (`AllDatabasesViewer`) for the agent system identity. The script auto-discovers the cluster ARM resource ID from the connector host in the selected subscription. You can override discovery explicitly:

```bash
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
```

Use `--force` to redeploy when no changes are detected.

The flow is:

1. `bicep/assemble-agent.sh` reads `recipes/finops-hub/` and produces deployment parameters plus extras.
2. `az deployment sub create` runs `bicep/main.bicep` at subscription scope. The Bicep file creates the resource group.
3. Bicep declares `Microsoft.App/agents/{subagents,skills,tools,connectors,commonPrompts}` directly.
4. `bicep/apply-extras.sh` applies data-plane extras (for example repos, hooks, knowledge, and auth wiring).

## Canonical pattern

This template follows the production recipe layout from [`microsoft/sre-agent/sreagent-templates`](https://github.com/microsoft/sre-agent/tree/main/sreagent-templates), pinned in `.upstream-pin`.

## Repository structure

```text
bin/                         deployment and verification entry points
bicep/                       subscription-scope Bicep templates
recipes/finops-hub/          FinOps Toolkit recipe
  agent.json
  connectors.json
  expected-config.json
  roles.yaml
  config/subagents/
  config/skills/
  config/tools/
  automations/scheduled-tasks/
  knowledge/
examples/ci-cd/              CI/CD example
```

## Post-deploy verification

```bash
bash bin/verify-agent.sh $(az account show --query id -o tsv) rg-finops-sre-agent finops-sre-agent --expected recipes/finops-hub
```

If a FinOps Hub URI was supplied, verify the `finops-hub-kusto` connector is healthy in `https://sre.azure.com`.
