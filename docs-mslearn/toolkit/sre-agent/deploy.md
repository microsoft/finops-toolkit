---
title: Deploy Azure SRE Agent with the FinOps toolkit
description: Deploy the FinOps toolkit's Azure SRE Agent template, connect it to a FinOps hub Data Explorer cluster, and configure notifications for scheduled cost and capacity reports.
author: msbrett
ms.author: brettwil
ms.date: 05/12/2026
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps hub admin, I want to deploy and configure the FinOps toolkit's Azure SRE Agent so that I can receive scheduled cost reports, anomaly detection, and capacity monitoring.
---

<!-- markdownlint-disable heading-increment MD024 -->

# Deploy Azure SRE Agent with the FinOps toolkit

In this tutorial, you learn how to deploy the [FinOps toolkit's Azure SRE Agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent), connect it to a [FinOps hub](../hubs/finops-hubs-overview.md), and configure notifications for scheduled cost and capacity reports. This article helps you:

<!-- prettier-ignore-start -->
> [!div class="checklist"]
> - Apply the prerequisites. <!-- markdownlint-disable-line MD032 -->
> - Deploy the FinOps hub recipe with `bin/deploy.sh`.
> - Verify the deployment.
> - Configure Microsoft Teams and Outlook notifications.
> - Use dry-run, what-if, and constrained-mode validation.
<!-- prettier-ignore-end -->

<br>

## What gets deployed

The FinOps hub recipe (`src/templates/sre-agent/recipes/finops-hub/`) deploys:

| Component | Count | Notes |
|-----------|-------|-------|
| SRE Agent | 1 | `Microsoft.App/agents`. Default name `finops-sre-agent`, default resource group `rg-finops-sre-agent`, default region `eastus2`, action mode `Autonomous`, access level `High` |
| User-assigned managed identity | 1 | Plus the agent's system-assigned identity |
| Log Analytics workspace | 1 | Linked to the agent for telemetry |
| Application Insights | 1 | Linked to the Log Analytics workspace |
| Subagents | 5 | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 34 | Kusto and Python tools under `recipes/finops-hub/config/tools/` |
| Scheduled tasks | 19 | FinOps, capacity, governance, and reporting automations |
| Kusto connector | 0 or 1 | `finops-hub-kusto` is included only when `FINOPS_HUB_CLUSTER_URI` is set |
| Knowledge documents | varies | Onboarding, notification patterns, known issue context |

<br>

## Prerequisites

- [Deployed a FinOps hub instance](../hubs/finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](../hubs/configure-scopes.md) and ingested data successfully.
- An Azure subscription where you have the **Owner** or **User Access Administrator** role. [Learn more](/azure/role-based-access-control/built-in-roles).
- The `Microsoft.App` resource provider [registered](/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) on the subscription.
- [Azure CLI](/cli/azure/install-azure-cli) signed in with the target subscription selected (`az account set`).
- `jq`, `python3` with `PyYAML`, `curl`, and Bash 3.2 or newer available locally.
- [`srectl`](/azure/sre-agent/tools) (only required when using `--fallback-srectl`).
- For zone mapping: The `AvailabilityZonePeering` feature must be registered on the subscription. Register it at the management group level if the agent manages capacity across multiple subscriptions.

  ```bash
  az feature register --namespace Microsoft.Resources --name AvailabilityZonePeering
  az provider register --namespace Microsoft.Resources
  ```

The deployment uses the subscription currently selected in Azure CLI. Confirm the active subscription before deploying:

```bash
az account show --query '{name:name,id:id}' -o table
```

<br>

## Deploy the FinOps hub recipe

The deployment script lives at `src/templates/sre-agent/bin/deploy.sh`. It accepts the recipe directory as input, calls `bicep/assemble-agent.sh` to produce ARM parameters and an extras file, runs the Bicep deployment at subscription scope, and then applies the data-plane extras automatically.

```bash
cd src/templates/sre-agent

# Deploy the packaged FinOps hub recipe:
bash bin/deploy.sh recipes/finops-hub/
```

The Bicep deployment creates the resource group named in `recipes/finops-hub/agent.json` (default `rg-finops-sre-agent`), the agent (default `finops-sre-agent`), the Log Analytics workspace, Application Insights, the user-assigned managed identity, and the subagents, skills, tools, and connectors arrays. After the ARM deployment succeeds, `bicep/apply-extras.sh` applies hooks, common prompts, scheduled tasks, knowledge documents, and any repo or auth wiring declared in the recipe.

> [!IMPORTANT]
> Don't run Azure control-plane or data-plane commands against live SRE Agent resources outside `bin/deploy.sh` and its owned helper scripts in `bicep/`. Out-of-band changes drift from the recipe and break the deployment workflow.

If no changes are detected (the script runs `bin/diff-agent.sh` against the existing agent), the deployment is skipped. Use `--force` to redeploy anyway:

```bash
bash bin/deploy.sh recipes/finops-hub/ --force
```

<br>

## Connect to a FinOps hub

The recipe's `connectors.json` declares one Kusto connector with `dataSource: ${FINOPS_HUB_CLUSTER_URI}`. Set that environment variable before running `bin/deploy.sh` to include the connector. The value must point to your FinOps hub Data Explorer cluster and end in `/hub`:

```bash
export FINOPS_HUB_CLUSTER_URI="https://<your-cluster>.<region>.kusto.windows.net/hub"
bash bin/deploy.sh recipes/finops-hub/
```

You can also place the variable in `recipes/finops-hub/connectors.secrets.env`. The assemble script auto-loads that file if present.

When a system-identity Kusto connector is present in the assembled parameters, `deploy.sh` enables a Bicep-managed `AllDatabasesViewer` role assignment for the agent's system-assigned identity. The script auto-discovers the cluster ARM resource ID from the connector hostname against the currently selected subscription. Override discovery when the cluster lives in a different subscription or the host name doesn't resolve uniquely:

```bash
export FINOPS_HUB_CLUSTER_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Kusto/clusters/<cluster>"
bash bin/deploy.sh recipes/finops-hub/
```

<br>

## Validate before deploying

The script supports two non-destructive validation modes plus a constrained-write fallback.

### Dry-run

Assembles the deployment parameters and extras, runs change detection, and exits without calling Azure for the deployment itself. Use it to confirm the recipe assembles cleanly and to preview what would deploy:

```bash
bash bin/deploy.sh recipes/finops-hub/ --dry-run
```

### What-if

Runs `az deployment sub what-if` against the assembled template. Use it to preview the exact ARM resources that the deployment creates, modifies, or deletes:

```bash
bash bin/deploy.sh recipes/finops-hub/ --what-if
```

### Constrained mode (`--fallback-srectl`)

If your tenant blocks ARM extension child-resource writes (`Microsoft.App/agents/{tools,subagents,skills,scheduledTasks,connectors}`), use constrained mode. The Bicep deployment provisions only the core agent resources, then `bin/hydrate-extensions.sh` applies tools, subagents, skills, and scheduled tasks via `srectl`:

```bash
bash bin/deploy.sh recipes/finops-hub/ --fallback-srectl
```

Constrained mode requires `srectl` to be installed and reachable on `PATH`.

<br>

## Verify the deployment

`bin/deploy.sh` automatically runs `bin/verify-agent.sh` against the recipe after a successful deployment and after a no-change skip. Re-run it manually any time:

```bash
bash bin/verify-agent.sh \
  $(az account show --query id -o tsv) \
  rg-finops-sre-agent \
  finops-sre-agent \
  --expected recipes/finops-hub
```

The verify script queries the ARM and data-plane APIs, compares observed counts against the expected counts in `recipes/finops-hub/expected-config.json`, and prints a pass/fail table.

Then confirm the agent in the portal:

1. Open [sre.azure.com](https://sre.azure.com), switch to the directory that contains your subscription, and select your agent.
2. Confirm the FinOps subagents, skills, tools, and `finops-hub-kusto` connector appear in **Builder**.
3. Go to **Scheduled tasks** and confirm tasks are listed and active.
4. Ask the agent: `What knowledge documents do you have?`
5. If you supplied a FinOps hub URI, confirm the `finops-hub-kusto` connector is healthy.
6. Confirm the target Data Explorer cluster shows an `AllDatabasesViewer` principal assignment for the agent's system-assigned identity.

> [!TIP]
> If [sre.azure.com](https://sre.azure.com) shows the agent correctly but `srectl` returns `401`, `403`, or `Forbidden: Access denied by PDP`, confirm the active Azure CLI context points to the subscription that owns the SRE Agent resource. Browser success with CLI failure usually means the CLI token was issued for the wrong tenant.

<br>

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

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Configure AI agents for FinOps hubs](../hubs/configure-ai.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)

<br>
