---
title: Deploy Azure SRE Agent with the FinOps toolkit
description: Deploy the FinOps toolkit Azure SRE Agent template from the Azure portal or CLI, connect it to a FinOps hub Data Explorer cluster, and validate the deployment.
author: msbrett
ms.author: brettwil
ms.date: 06/17/2026
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to deploy and configure the FinOps toolkit's Azure SRE Agent so that I can receive scheduled cost reports, anomaly detection, and capacity monitoring.
---

<!-- markdownlint-disable heading-increment MD024 -->

# Deploy Azure SRE Agent with the FinOps toolkit

In this tutorial, you learn how to deploy the [FinOps toolkit Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent), connect it to a [FinOps hub](../hubs/finops-hubs-overview.md), and validate the deployment.

The deployment flow is copied from the Microsoft SRE Agent starter lab and updated for the FinOps toolkit. The Azure portal path uses the toolkit's packaged ARM template and an embedded deployment script to apply the SRE Agent recipe. The local CLI path uses Azure CLI + Bicep for infrastructure and the supported SRE Agent ARM and data-plane surfaces for recipe configuration. It doesn't use `azd`.

## What gets deployed

The FinOps hub recipe (`src/templates/sre-agent/recipes/finops-hub/`) deploys:

| Component | Count | Notes |
|-----------|-------|-------|
| SRE Agent | 1 | `Microsoft.App/agents` |
| Model provider | 1 | Azure OpenAI provider-level routing (`MicrosoftFoundry` ARM value, `Automatic` model routing) |
| Managed identities | 1-2 | Agent system-assigned managed identity; portal deployments also create a user-assigned identity for the deployment script |
| Log Analytics workspace | 1 | Linked to the agent for telemetry |
| Application Insights | 1 | Linked to Log Analytics |
| Custom agents | 5 | FinOps practitioner orchestrator plus CFO, capacity, database-query, and hubs specialists |
| Skills | 3 | Capacity, cost management, and FinOps Toolkit |
| Tools | 50 | Kusto, capacity, and Hub infrastructure tools |
| Tool overrides | 9 | Enables SRE Agent Log Query and Visualization tools |
| Scheduled tasks | 19 | FinOps, governance, and reporting automations |
| Kusto connector | 0 or 1 | Included when you pass `--cluster-uri` |
| Knowledge docs | 6 | Five recipe knowledge docs plus the FinOps Toolkit output style |

## Prerequisites

- A deployed FinOps hub with Data Explorer.
- Permissions to create deployed resources, such as **Contributor** on the subscription when the template creates the agent resource group.
- Permissions to assign roles at subscription, target resource group, and agent scopes, such as **Role Based Access Control Administrator**, **User Access Administrator**, or **Owner** on those scopes.
- The `Microsoft.App` resource provider registered in the subscription.
- For local CLI deployments only: [Azure CLI](/cli/azure/install-azure-cli), `curl`, `jq`, `python3` with `PyYAML`, and Bash 3.2 or newer.

Run:

```bash
cd src/templates/sre-agent
bash bin/check-prerequisites.sh --subscription <subscription-id>
```

## Deploy the FinOps hub recipe

Use the Azure portal deployment when you want the same one-click experience as other FinOps toolkit templates. The template creates the Azure resources, grants the deployment script identity SRE Agent Administrator on the agent, downloads the packaged recipe assets, and applies connectors, tools, skills, subagents, knowledge, and scheduled tasks.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Deploy to Azure](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Fsre-agent%2Flatest%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Fsre-agent%2Flatest%2FcreateUiDefinition.json)
<!-- prettier-ignore-end -->

### Deploy from local CLI

Run one script with explicit parameters:

```bash
cd src/templates/sre-agent

bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  [--cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>] \
  [--target-resource-group <target-rg> ...] \
  [--dry-run] \
  [--force]
```

`bin/deploy.sh --help` is the CLI contract:

```text
Usage: bash bin/deploy.sh --recipe <dir> [options]

Required:
  --recipe <dir>                      Recipe directory
  --subscription <id>                 Azure subscription
  -g, --resource-group <name>         Resource group for the agent
  -n, --name <name>                   Agent name
  -l, --location <region>             Azure region

Optional:
  --target-resource-group <name>      Repeatable target resource group. Defaults to --resource-group.
  --cluster-uri <uri>                 Kusto connector URI, including database name.
                                      Example: https://<cluster>.<region>.kusto.windows.net/Hub
  --cluster-resource-id <id>          Optional Kusto cluster ARM resource ID. Real deployments resolve this from --cluster-uri when possible; dry-run requires it.
  --no-subscription-reader            Do not assign Reader at subscription scope. Default: no subscription Reader (opt-in with --subscription-reader).
  --deploy-name <name>                Deployment name override. Defaults to a deterministic name.
  --dry-run                           Validate inputs and write parameters without Azure calls.
  --force                             Accepted for compatibility.
  -h, --help                          Show this help.
```

## Validation modes

Dry-run is hermetic and skips live Azure calls:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  -g <your-rg> \
  -n <your-agent-name> \
  -l <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  --cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster> \
  --dry-run
```

When deploying from the portal, the template runs a subscription-scoped ARM deployment and then runs a `Microsoft.Resources/deploymentScripts` resource to configure the Kusto connector and remaining recipe assets through the supported SRE Agent ARM and data-plane surfaces. When deploying locally, `deploy.sh` runs the same subscription-scoped infrastructure deployment and then runs `bin/apply-extras.sh` for the recipe configuration step.

The recipe defaults the parent SRE Agent to Azure OpenAI provider-level routing by setting `defaultModel.provider` to `MicrosoftFoundry` and `defaultModel.name` to `Automatic`. Azure SRE Agent automatically selects the model within the configured provider for each task. The template doesn't pin different models for individual custom agents or scheduled tasks because the documented SRE Agent configuration surface is provider-level.

Resource names are deterministic for the subscription ID, agent resource group ID, and agent name. Use the same values to update an existing deployment. Post-provisioning deletes existing scheduled tasks with the recipe's task names before applying manifests so redeployments don't create duplicate automations. `--deploy-name` only changes the ARM deployment record and local build directory.

The agent defaults to Low (read-only) access level for reporting and analysis without modification risk. Subscription Reader is opt-in (`--subscription-reader`) and only required for subscription-wide ARM-backed reports; otherwise the agent scopes reads via target resource groups. This posture allows the 19 scheduled reports to run autonomously while eliminating write blast radius.

If `--cluster-uri` points to an Azure Data Explorer cluster with `publicNetworkAccess` set to `Disabled`, the script still deploys all resources, assigns the agent identity `AllDatabasesViewer`, and creates the `finops-hub-kusto` connector. It also prints a warning with the SRE Agent known-limitations URL because private endpoint ADX blocks direct KQL queries from the hosted agent. The customer can decide whether to enable public query access for the connector after reviewing <https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations>.

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

Then confirm the agent in [sre.azure.com](https://sre.azure.com). If you passed `--cluster-uri`, verify the `finops-hub-kusto` connector. If the deployment warned that the cluster denies public query access, the connector is expected to remain unhealthy until the customer enables public query access or Microsoft adds private endpoint ADX query support for SRE Agent.

## Configure notifications

Scheduled tasks deliver reports to Microsoft Teams and Outlook through Azure SRE Agent notification connectors. Connectors require interactive OAuth setup in [sre.azure.com](https://sre.azure.com), so the portal template and `bin/deploy.sh` don't create them.

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

The old deploy flow used configuration inputs such as `FINOPS_HUB_CLUSTER_URI`, `FINOPS_HUB_CLUSTER_RESOURCE_ID`, and `connectors.secrets.env`. Those inputs are no longer supported for identity or config.

Before:

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-cluster>.<your-region>.kusto.windows.net/hub"
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
bash bin/deploy.sh recipes/finops-hub
```

After:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  [--cluster-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>]
```

The only supported environment-variable inputs are secrets:

- `GITHUB_PAT`
- `ADO_PAT`
- `ADO_USE_AAD`
- `ADO_USE_MI`
- `ADO_ORG`
