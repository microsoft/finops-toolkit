---
title: Deploy Azure SRE Agent with the FinOps toolkit
description: Deploy the FinOps toolkit Azure SRE Agent template with explicit CLI parameters, connect it to a FinOps hub Data Explorer cluster, and validate the deployment.
author: msbrett
ms.author: brettwil
ms.date: 05/19/2026
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to deploy and configure the FinOps toolkit's Azure SRE Agent so that I can receive scheduled cost reports, anomaly detection, and capacity monitoring.
---

<!-- markdownlint-disable heading-increment MD024 -->

# Deploy Azure SRE Agent with the FinOps toolkit

In this tutorial, you learn how to deploy the [FinOps toolkit Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent), connect it to a [FinOps hub](../hubs/finops-hubs-overview.md), and validate the deployment.

## What gets deployed

The FinOps hub recipe (`src/templates/sre-agent/recipes/finops-hub/`) deploys:

| Component | Count | Notes |
|-----------|-------|-------|
| SRE Agent | 1 | `Microsoft.App/agents` |
| User-assigned managed identity | 1 | Plus the agent system-assigned identity |
| Log Analytics workspace | 1 | Linked to the agent for telemetry |
| Application Insights | 1 | Linked to Log Analytics |
| Subagents | 5 | FinOps and Azure capacity specialists |
| Skills | 3 | Capacity, cost management, and FinOps Toolkit |
| Tools | 34 | Kusto and Python tools |
| Scheduled tasks | 19 | FinOps, governance, and reporting automations |
| Kusto connector | 0 or 1 | Included when you pass `--cluster-uri` |

## Prerequisites

- A deployed FinOps hub with Data Explorer.
- A subscription where you have the **Owner** or **User Access Administrator** role.
- The `Microsoft.App` resource provider registered in the subscription.
- [Azure CLI](/cli/azure/install-azure-cli).
- `jq`, `python3` with `PyYAML`, `curl`, and Bash 3.2 or newer.
- [`srectl`](/azure/sre-agent/tools) only when you use `--fallback-srectl`.

Run:

```bash
cd src/templates/sre-agent
bash bin/check-prerequisites.sh --subscription <subscription-id>
```

## Deploy the FinOps hub recipe

Run one script with explicit parameters:

```bash
cd src/templates/sre-agent

bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  [--subscription <subscription-id>] \
  [--target-resource-group <target-rg> ...] \
  [--cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>] \
  [--dry-run | --what-if] \
  [--force] \
  [--fallback-srectl] \
  [--no-telemetry]
```

`bin/deploy.sh --help` is the CLI contract:

```text
Usage: bash bin/deploy.sh --recipe <dir> [options]
       bash bin/deploy.sh <legacy.parameters.json> [options]

Required for recipe directories:
  --recipe <dir>                        Recipe directory to assemble
  -g, --resource-group <name>          Resource group (portal field: "Resource group")
  -n, --name <name>                    Agent name (portal field: "Agent name")
  -l, --location <region>              Region (portal field: "Region"; currently documented: swedencentral, eastus2, australiaeast)
      --cluster-uri <uri>              Kusto connector URI when the recipe declares one

Optional:
      --subscription <id>              Subscription (portal field: "Subscription")
      --target-resource-group <name>   Repeatable target resource group
      --cluster-resource-id <id>       Kusto cluster ARM resource ID
      --deploy-name <name>             Deployment name override
      --dry-run                        Assemble and validate inputs without Azure calls
      --what-if                        Run live ARM what-if validation
      --force                          Continue when diff/discovery would otherwise stop
      --fallback-srectl                Deploy ARM core, then hydrate extensions with srectl
      --no-telemetry                   Disable anonymous telemetry for this run
  -h, --help                           Show this help

Legacy input:
  A pre-assembled .parameters.json file is accepted only as a positional argument.
  When using a legacy parameters file, identity and cluster flags are ignored.
```

## Validation modes

Dry-run is hermetic and skips live Azure calls:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --dry-run
```

What-if is a live ARM validation:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --what-if
```

If your tenant blocks ARM extension child-resource writes, use constrained mode:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --fallback-srectl
```

## Recipe identity defaults

- Shipped recipes in this repo omit the `identity` block.
- Customer-authored recipes can keep identity defaults in `agent.json`.
- CLI flags always override recipe defaults.

If you omit `--target-resource-group`, the deploy flow uses the recipe default when present; otherwise it falls back to the agent resource group.

## Verify the deployment

```bash
bash bin/verify-agent.sh \
  $(az account show --query id -o tsv) \
  <your-rg> \
  <your-agent-name> \
  --expected recipes/finops-hub
```

Then confirm the agent in [sre.azure.com](https://sre.azure.com). If you passed `--cluster-uri`, verify that the `finops-hub-kusto` connector is healthy.

## Configure notifications

Scheduled tasks deliver reports to Microsoft Teams and Outlook through Azure SRE Agent notification connectors. Connectors require interactive OAuth setup in [sre.azure.com](https://sre.azure.com), so `bin/deploy.sh` doesn't create them.

### Configure Teams

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Send notification (Microsoft Teams)**.
3. Sign in with your Microsoft 365 account.
4. Paste the channel URL from **Get link to channel** in Teams.
5. Select the agent's managed identity and save.
6. Test from chat: `Post a test message to our Teams channel saying "Azure SRE Agent connected via the FinOps toolkit."`

Use the built-in `PostTeamsMessage` tool from the [Teams notification guidance](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/recipes/finops-hub/knowledge/teams-notification-guide.md). Don't call the Microsoft Graph API or the connection's `dynamicInvoke` endpoint directly because that path returns a 403 error for this connector configuration.

### Configure Outlook

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Outlook Tools (Office 365 Outlook)**.
3. Sign in with a Microsoft 365 account that has mailbox access.
4. Select the agent's managed identity and save.
5. Test from chat: `Send an email to <recipient> with subject "SRE Agent test" and body "Outlook connector is working."`

For more information, see [Send notifications in Azure SRE Agent](/azure/sre-agent/send-notifications).

## GitHub Actions example

The included GitHub Actions example passes the cluster URI as a deploy flag while leaving secret-only inputs such as `GITHUB_PAT` and `ADO_PAT` in the environment.

## Migrating from env-var-driven deploys

The old deploy flow used configuration inputs such as `FINOPS_HUB_CLUSTER_URI`, `FINOPS_HUB_CLUSTER_RESOURCE_ID`, `SRE_AGENT_NO_TELEMETRY`, and `connectors.secrets.env`. Those inputs are no longer supported for identity or config.

Before:

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-cluster>.<your-region>.kusto.windows.net/hub"
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
export SRE_AGENT_NO_TELEMETRY=1
bash bin/deploy.sh recipes/finops-hub
```

After:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/hub \
  --cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster> \
  --no-telemetry
```

The only supported environment-variable inputs are secrets:

- `GITHUB_PAT`
- `ADO_PAT`
- `ADO_USE_AAD`
- `ADO_USE_MI`
- `ADO_ORG`
