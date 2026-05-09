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
| Connector | 1 | Optional FinOps Hub Kusto connector when a hub URI is supplied |

## Prerequisites

- Azure CLI (`az`) signed in with the intended subscription selected
- `jq`
- `python3` with PyYAML
- `curl`
- Bash 3.2 or newer
- `Microsoft.App` resource provider registered in the selected subscription

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
bash bin/deploy.sh recipes/finops-hub/ \
  --finops-hub-cluster-uri https://<your-finops-hub-cluster>.<region>.kusto.windows.net/hub
```

For agent-only deployment, omit `--finops-hub-cluster-uri`. The FinOps Hub Kusto connector is skipped until a hub URI is supplied.

The flow is:

1. `bicep/assemble-agent.sh` reads `recipes/finops-hub/` and produces deployment parameters plus extras.
2. `az deployment sub create` runs `bicep/main.bicep` at subscription scope. The Bicep file creates the resource group.
3. Bicep declares `Microsoft.App/agents/{subagents,skills,tools,connectors,commonPrompts}` directly.
4. `bicep/apply-extras.sh` applies scheduled tasks, optional incident automation, knowledge uploads, hooks, and FinOps Hub ADX `AllDatabasesViewer` assignments.

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

If a FinOps Hub URI was supplied, confirm the ADX cluster has `AllDatabasesViewer` assignments for the agent identities.
