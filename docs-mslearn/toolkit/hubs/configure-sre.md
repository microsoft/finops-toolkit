---
title: Configure an SRE agent for FinOps hubs
description: Learn how to configure an Azure SRE agent to connect to your FinOps hub for scheduled cost analysis, capacity monitoring, and reporting.
author: msbrett
ms.author: brettwil
ms.date: 05/25/2026
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
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.60 or later.
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) for [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools).
- `curl`, `jq`, `python3`, and `bash` available locally for the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent).

<br>

## Review deployed resources

The [SRE agent template](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) deploys a single Azure SRE agent with these resources and configuration objects:

| Component | Count | Description |
|-----------|-------|-------------|
| SRE agent | 1 | [`Microsoft.App/agents`](https://learn.microsoft.com/azure/sre-agent/overview) resource in [autonomous mode](https://learn.microsoft.com/azure/sre-agent/run-modes) |
| Managed identity | 1 | User-assigned managed identity for the agent |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics for monitoring |
| Target resource group RBAC | 3-4 per target group | Reader, Monitoring Reader, Log Analytics Reader, and Contributor when `accessLevel` is `High` |
| Azure Data Explorer role (optional) | 1 | `AllDatabasesViewer` when Azure Data Explorer parameters are provided |
| Subagents | 5 | `finops-practitioner`, `azure-capacity-manager`, `chief-financial-officer`, `ftk-database-query`, `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, `finops-toolkit` |
| Tools | 34 | Kusto and Python tools for cost, capacity, governance, and reporting workflows |
| Connector | 1 | Kusto MCP connector to the FinOps hub Azure Data Explorer cluster |
| Scheduled tasks | 19 | Reports at daily, weekly, monthly, semiannual, and quarterly cadences |
| Knowledge docs | 6 | Onboarding, artifact verification, Teams notification patterns, known issues, document index guidance, and the FinOps Toolkit output style |

<br>

## Deploy the SRE agent

The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) is copied from the Microsoft SRE Agent starter lab and updated for the FinOps toolkit. It uses Azure CLI + Bicep directly and doesn't use `azd`:

### [Bash](#tab/bash)

```bash
cd src/templates/sre-agent

bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  --cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>
```

### [PowerShell](#tab/powershell)

```powershell
cd src/templates/sre-agent

pwsh -Command './src/scripts/Deploy-Toolkit sre-agent'
```

---

PowerShell deployment support is planned through the toolkit wrapper. The customer-facing template entry point today is `bin/deploy.sh`.

The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent):

1. Sets the `az` CLI context to the target subscription. This step is required for [B2B tenant environments](#troubleshoot-b2b-tenant-environments).
2. Runs a subscription-scoped Azure CLI + Bicep deployment from `infra/main.bicep`.
3. Runs `bin/post-provision.sh`, which configures the Kusto connector through the SRE Agent data plane and applies the remaining recipe assets with `srectl`.

The post-provision step uses [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools) to apply 3 skills, 5 subagents, 34 tools, 19 scheduled tasks, and 6 knowledge documents.

### Grant the optional Azure Data Explorer viewer role

To grant the agent's managed identity the `AllDatabasesViewer` role on your Azure Data Explorer cluster, pass `--cluster-resource-id` with `--cluster-uri`. The deployment uses the [Azure Data Explorer role module](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/modules/kusto-viewer-rbac.bicep):

```bash
--cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
--cluster-resource-id /subscriptions/.../resourceGroups/<adx-rg>/providers/Microsoft.Kusto/clusters/<adx-cluster-name>
```

### Redeploy an existing agent

To update an existing agent, rerun the [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) with the same resource group and agent name:

```bash
bash bin/deploy.sh \
  --recipe recipes/finops-hub \
  --subscription <subscription-id> \
  --resource-group <your-rg> \
  --name <your-agent-name> \
  --location <your-region> \
  --cluster-uri https://<your-cluster>.<your-region>.kusto.windows.net/Hub \
  --cluster-resource-id /subscriptions/.../providers/Microsoft.Kusto/clusters/<name>
```

### Delete the deployment

To delete Azure resources, delete the resource group that contains the SRE Agent resources after confirming no other resources share it:

```bash
az group delete --subscription <subscription-id> --name <your-rg>
```

<br>

## Verify the deployment

After `bin/deploy.sh` completes, use the template's [post-deployment verification guidance](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent#verify):

1. Confirm `bin/post-provision.sh` completed without errors.
2. Open [sre.azure.com](https://sre.azure.com), switch to the directory that contains your subscription, and select your agent.
3. Confirm 5 subagents, 3 skills, and 34 tools appear in **Builder**.
4. Go to **Scheduled tasks** and confirm 19 tasks are listed and active.
5. Ask the agent: `What knowledge documents do you have?` and confirm the shipped knowledge is available.

<br>

## Configure Teams notifications

Scheduled tasks can send reports to a Teams channel through the [Teams notification connector](https://learn.microsoft.com/azure/sre-agent/send-notifications). The connector requires interactive OAuth setup in the portal.

1. Open [sre.azure.com](https://sre.azure.com), open your agent, then go to **Builder** > **Connectors**.
2. Select **Add connector** > **Send notification (Microsoft Teams)**.
3. Sign in with your Microsoft 365 account and paste the channel URL from **Get link to channel** in Teams.
4. Select the agent's managed identity and save.
5. Test from chat: `Post a test message to our Teams channel saying "FinOps SRE agent connected."`

Use the built-in `PostTeamsMessage` tool from the [Teams notification guidance](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/recipes/finops-hub/knowledge/teams-notification-guide.md). Don't call the Microsoft Graph API or the connection's `dynamicInvoke` endpoint directly because that path returns a 403 error for this connector configuration.

For Outlook notifications, follow the same pattern with the **Outlook Tools (Office 365 Outlook)** connector. See [Send notifications](https://learn.microsoft.com/azure/sre-agent/send-notifications) for details.

<br>

## Review scheduled tasks

The template deploys 19 scheduled tasks from the [`recipes/finops-hub/automations/scheduled-tasks`](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/recipes/finops-hub/automations/scheduled-tasks) folder. When the Teams connector is configured, each task posts its final report to the connected channel:

| Task | Agent | Schedule | What it reports |
|------|-------|----------|-----------------|
| HubsHealthCheck | ftk-hubs-agent | Daily 6:00 AM | Hub version, data freshness, and pipeline status |
| CapacityDailyMonitor | azure-capacity-manager | Daily 6:30 AM | Quota usage, CRG utilization, and alert status |
| Monthly | finops-practitioner | Monthly on the 5th at 5:15 PM | Month-over-month cost analysis with FinOps Kusto tools |
| CostOptimization | finops-practitioner | Weekly Monday 8:00 AM | Orphaned resources, rightsizing, and commitment opportunities |
| CapacityWeeklySupplyReview | azure-capacity-manager | Weekly Monday 8:00 AM | Quota headroom, CRG cost-waste audit, and benefit recommendations |
| CapacityMonthlyPlanning | azure-capacity-manager | Monthly 1st 9:00 AM | Demand forecast, procurement pipeline, and governance review |
| YOY | chief-financial-officer | January 5 and July 5 at 9:00 AM | Semiannual year-over-year finance analysis with forecast |
| AIWorkloadCostAnalysis | chief-financial-officer | Monthly 1st 10:00 AM | AI token economics, model efficiency, and cost allocation |
| CapacityQuarterlyStrategy | azure-capacity-manager | Quarterly 9:00 AM | Supply chain maturity, commitment alignment, and architecture review |

Each scheduled task reads the uploaded knowledge documents before it starts and applies `ftk-output-style.md` for evidence, formatting, capacity-risk, confidence, and caveat conventions. Send financial results to Teams through the configured [notification connector](https://learn.microsoft.com/azure/sre-agent/send-notifications). Save only operational notes, such as tool errors, workarounds, and patterns, to agent [memory](https://learn.microsoft.com/azure/sre-agent/memory) with `#remember`; don't save financial data.

<br>

## Troubleshoot B2B tenant environments

In B2B environments, the Azure subscription and Azure SRE Agent resource can live in a different Microsoft Entra tenant than your Microsoft 365 home tenant. The deployment script sets the active subscription before deployment to align the CLI context with the resource tenant.

If [sre.azure.com](https://sre.azure.com) shows the agent correctly but [`srectl`](https://learn.microsoft.com/azure/sre-agent/tools) returns `401`, `403`, or `Forbidden: Access denied by PDP`, use the [B2B tenant troubleshooting steps](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent#b2b-tenant-note-for-srectl):

1. Confirm the active Azure CLI context points at the subscription that owns the SRE agent resource.
2. Re-authenticate against the tenant that owns the subscription.
3. Re-run `srectl init --resource-url <endpoint>`, then retry `srectl status`.

Browser success with CLI failure indicates that the CLI token was issued for the wrong tenant. The [deployment script](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent) runs `az account set --subscription` before deployment to set the target subscription context.

<br>

## Review built-in capabilities

Azure SRE Agent includes platform capabilities that are on by default in this template:

- **Code interpreter**: Azure SRE Agent can run Python and shell commands in a sandboxed environment for data analysis, chart generation, and report formatting. The [Bicep template](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/modules/sre-agent.bicep) sets `experimentalSettings.EnableWorkspaceTools`. See [Use code interpreter](https://learn.microsoft.com/azure/sre-agent/use-code-interpreter).
- **DocsGuide**: DocsGuide provides Azure documentation grounding for agent responses. See [Use DocsGuide](https://learn.microsoft.com/azure/sre-agent/use-docsguide).
- **Visualization**: Built-in chart and table rendering for investigation results. See [Tools](https://learn.microsoft.com/azure/sre-agent/tools).
- **Memory**: Memory stores operational knowledge across sessions. See [Memory and knowledge](https://learn.microsoft.com/azure/sre-agent/memory).

The analytical subagents (`finops-practitioner`, `chief-financial-officer`, `azure-capacity-manager`, and `ftk-database-query`) include `execute_python` in the [agent configuration](https://github.com/microsoft/finops-toolkit/tree/main/src/templates/sre-agent/recipes/finops-hub/config/subagents) so they can produce charts, tables, and downloadable artifacts from FinOps data.

<br>

## Review supported regions

The Azure SRE Agent deployment supports `swedencentral`, `eastus2`, and `australiaeast`. The [Bicep template](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/infra/main.bicep) restricts the `location` parameter with `@allowed`.

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
