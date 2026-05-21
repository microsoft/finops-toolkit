---
title: Configure an SRE agent for FinOps hubs
description: Learn how to configure an Azure SRE agent to connect to your FinOps hub for scheduled cost analysis, capacity monitoring, and reporting.
author: msbrett
ms.author: brettwil
ms.date: 04/28/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps hub admin, I want to connect an Azure SRE agent to my hub so that I can receive scheduled cost reports, anomaly detection, and capacity monitoring in Teams.
---

# Configure an SRE agent for FinOps hubs

[Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview) supports agent-based operational workflows. This article shows how to connect Azure SRE Agent to a [FinOps hub](finops-hubs-overview.md), configure scheduled cost analysis and capacity checks from the [SRE agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent), and send results to Teams with the [Teams notification connector](https://learn.microsoft.com/azure/sre-agent/send-notifications).

<br>

## Prerequisites

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub) with Data Explorer.
- [Configured scopes](configure-scopes.md) and ingested data successfully.
- An Azure subscription where you have the **Owner** or **User Access Administrator** role. [Learn more](/azure/role-based-access-control/built-in-roles).
- The `Microsoft.App` resource provider [registered](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) on the subscription.
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) 1.9 or later.
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.60 or later.
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) for [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools).
- `python3` and `bash` available locally for the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts).

<br>

## Review deployed resources

The [SRE agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) deploys a single Azure SRE agent with these resources and configuration objects:

| Component | Count | Description |
|-----------|-------|-------------|
| SRE agent | 1 | [`Microsoft.App/agents`](https://learn.microsoft.com/azure/sre-agent/overview) resource in [autonomous mode](https://learn.microsoft.com/azure/sre-agent/run-modes) |
| Managed identity | 1 | User-assigned managed identity for the agent |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics for monitoring |
| Subscription RBAC | 2 | Reader + Monitoring Contributor role assignments |
| Azure Data Explorer role (optional) | 1 | `AllDatabasesViewer` when Azure Data Explorer parameters are provided |
| Subagents | 5 | `finops-practitioner`, `azure-capacity-manager`, `chief-financial-officer`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Kusto tools | 21 | Predefined KQL queries for cost trends, anomalies, forecasts, savings, and commitments |
| Connector | 1 | Kusto MCP connector to the FinOps hub Azure Data Explorer cluster |
| Scheduled tasks | 9 | Reports at daily, weekly, monthly, and quarterly cadences |
| Knowledge docs | 3 | Onboarding guidance, Teams notification patterns, and known issues |

<br>

## Deploy the SRE agent

The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts) creates the [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) environment, sets required values, and runs `azd up`:

### [Bash](#tab/bash)

```bash
cd src/templates/sre-agent

bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --subscription <subscription-id> \
  --finops-hub-cluster-uri https://<your-cluster>.kusto.windows.net
```

### [PowerShell](#tab/powershell)

```powershell
cd src/templates/sre-agent

pwsh ./scripts/deploy.ps1 `
  -Environment <environment-name> `
  -Subscription <subscription-id> `
  -FinopsHubClusterUri https://<your-cluster>.kusto.windows.net
```

---

Replace `<environment-name>` with a name for your deployment, such as `ftk-sre-prod`; `<subscription-id>` with the Azure subscription that hosts the SRE agent; and `<your-cluster>` with your FinOps hub Azure Data Explorer cluster hostname.

The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts):

1. Creates or selects an `azd` environment.
2. Sets the `az` CLI context to the target subscription. This step is required for [B2B tenant environments](#troubleshoot-b2b-tenant-environments).
3. Runs `azd up`, which deploys Bicep infrastructure and starts the `postprovision` hook from [`azure.yaml`](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/azure.yaml).

The `postprovision` hook installs [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools), then applies 3 skills, 5 subagents, 21 Kusto tools, 9 scheduled tasks, 3 knowledge documents, and the Kusto connector.

### Grant the optional Azure Data Explorer viewer role

To grant the agent's managed identity the `AllDatabasesViewer` role on your Azure Data Explorer cluster, add the optional cluster parameters from the [Azure Data Explorer role module](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/bicep/modules/adx-role.bicep):

```bash
--finops-hub-cluster-name <adx-cluster-name> \
--finops-hub-cluster-resource-group <adx-resource-group>
```

### Replace an existing environment

To delete an existing deployment and redeploy it, use the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts):

```bash
bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --clone-env <existing-environment> \
  --replace
```

### Delete an environment

To delete Azure resources and the local `azd` environment, use the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts):

```bash
bash ./scripts/deploy.sh \
  --environment <environment-name> \
  --destroy
```

<br>

## Verify the deployment

After `azd up` completes, use the template's [post-deployment verification guidance](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent#post-deploy-verification):

1. Confirm the `postprovision` hook completed without errors.
2. Open [sre.azure.com](https://sre.azure.com), switch to the directory that contains your subscription, and select your agent.
3. Confirm 5 subagents, 3 skills, and 21 tools appear in **Builder**.
4. Go to **Scheduled tasks** and confirm 9 tasks are listed and active.
5. Ask the agent: `What knowledge documents do you have?`—confirm it lists 3 documents.

<br>

## Configure Teams notifications

Scheduled tasks can send reports to a Teams channel through the [Teams notification connector](https://learn.microsoft.com/azure/sre-agent/send-notifications). The connector requires interactive OAuth setup in the portal.

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Send notification (Microsoft Teams)**.
3. Sign in with your Microsoft 365 account and paste the channel URL from **Get link to channel** in Teams.
4. Select the agent's managed identity and save.
5. Test from chat: `Post a test message to our Teams channel saying "FinOps SRE agent connected."`

Use the built-in `PostTeamsMessage` tool from the [Teams notification guidance](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/sre-config/knowledge/teams-notification-guide.md). Don't call the Microsoft Graph API or the connection's `dynamicInvoke` endpoint directly because that path returns a 403 error for this connector configuration.

For Outlook notifications, follow the same pattern with the **Outlook Tools (Office 365 Outlook)** connector. See [Send notifications](https://learn.microsoft.com/azure/sre-agent/send-notifications) for details.

<br>

## Review scheduled tasks

The template deploys 9 scheduled tasks from the [`sre-config/scheduled-tasks`](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/sre-config/scheduled-tasks) folder. When the Teams connector is configured, each task posts its final report to the connected channel:

| Task | Agent | Schedule | What it reports |
|------|-------|----------|-----------------|
| HubsHealthCheck | ftk-hubs-agent | Daily 6:00 AM | Hub version, data freshness, and pipeline status |
| CapacityDailyMonitor | azure-capacity-manager | Daily 6:30 AM | Quota usage, CRG utilization, and alert status |
| MOM | finops-practitioner | Daily 5:15 PM | Month-over-month cost analysis with 17 Kusto queries |
| CostOptimization | finops-practitioner | Weekly Monday 8:00 AM | Orphaned resources, rightsizing, and commitment opportunities |
| CapacityWeeklySupplyReview | azure-capacity-manager | Weekly Monday 8:00 AM | Quota headroom, CRG cost-waste audit, and benefit recommendations |
| CapacityMonthlyPlanning | azure-capacity-manager | Monthly 1st 9:00 AM | Demand forecast, procurement pipeline, and governance review |
| YTD | chief-financial-officer | Monthly 1st 9:00 AM | Fiscal year-to-date analysis with forecast |
| AIWorkloadCostAnalysis | chief-financial-officer | Monthly 1st 10:00 AM | AI token economics, model efficiency, and cost allocation |
| CapacityQuarterlyStrategy | azure-capacity-manager | Quarterly 9:00 AM | Supply chain maturity, commitment alignment, and architecture review |

Each scheduled task reads the uploaded knowledge documents before it starts. Send financial results to Teams through the configured [notification connector](https://learn.microsoft.com/azure/sre-agent/send-notifications). Save only operational notes, such as tool errors, workarounds, and patterns, to agent [memory](https://learn.microsoft.com/azure/sre-agent/memory) with `#remember`; don't save financial data.

<br>

## Troubleshoot B2B tenant environments

In B2B environments, the Azure subscription and Azure SRE Agent resource can live in a different Microsoft Entra tenant than your Microsoft 365 home tenant. The deployment script sets the active subscription before `azd up` to align the CLI context with the resource tenant.

If [sre.azure.com](https://sre.azure.com) shows the agent correctly but [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools) returns `401`, `403`, or `Forbidden: Access denied by PDP`, use the [B2B tenant troubleshooting steps](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent#b2b-tenant-note-for-srectl):

1. Confirm the active Azure CLI context points at the subscription that owns the SRE agent resource.
2. Re-authenticate against the tenant that owns the subscription.
3. Re-run `srectl init --resource-url <endpoint>`, then retry `srectl status`.

Browser success with CLI failure indicates that the CLI token was issued for the wrong tenant. The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/scripts) runs `az account set --subscription` before `azd up` to set the target subscription context.

<br>

## Review built-in capabilities

Azure SRE Agent includes platform capabilities that are on by default in this template:

- **Code interpreter**: Azure SRE Agent can run Python and shell commands in a sandboxed environment for data analysis, chart generation, and report formatting. The [Bicep template](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/bicep/modules/sre-agent.bicep) sets `experimentalSettings.EnableWorkspaceTools`. See [Use code interpreter](https://learn.microsoft.com/azure/sre-agent/use-code-interpreter).
- **DocsGuide**: DocsGuide provides Azure documentation grounding for agent responses. See [Use DocsGuide](https://learn.microsoft.com/azure/sre-agent/use-docsguide).
- **Visualization**: Built-in chart and table rendering for investigation results. See [Tools](https://learn.microsoft.com/azure/sre-agent/tools).
- **Memory**: Memory stores operational knowledge across sessions. See [Memory and knowledge](https://learn.microsoft.com/azure/sre-agent/memory).

The analytical subagents (`finops-practitioner`, `chief-financial-officer`, `azure-capacity-manager`, and `ftk-database-query`) include `execute_python` in the [agent configuration](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/sre-config/agents) so they can produce charts, tables, and downloadable artifacts from FinOps data.

<br>

## Review supported regions

The Azure SRE Agent deployment supports `swedencentral`, `eastus2`, and `australiaeast`. The [Bicep template](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/bicep/main.bicep) restricts the `location` parameter with `@allowed`.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/ConfigureSRE)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)

Related solutions:

- [Configure AI agents for FinOps hubs](configure-ai.md)
- [FinOps hubs](finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)

<br>
