---
title: Azure SRE Agent in the FinOps toolkit
description: Learn how the FinOps toolkit deploys Azure SRE Agent with FinOps and capacity management automation on top of FinOps hubs.
author: msbrett
ms.author: brettwil
ms.date: 05/06/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand what the FinOps toolkit's Azure SRE Agent deployment provides so that I can automate cost, capacity, and operations workflows.
---

# Azure SRE Agent in the FinOps toolkit

The FinOps toolkit ships an Azure Developer CLI template that deploys [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview) and configures it for FinOps and capacity management workflows on top of [FinOps hubs](../hubs/finops-hubs-overview.md). The deployment includes specialist subagents, FOCUS-aligned Kusto and Python tools, scheduled tasks, and grounded knowledge so the agent can investigate cost changes, monitor quota and capacity signals, prepare executive summaries, and deliver scheduled updates. The deployment focuses on three core design principles:

- **Automate the rhythm**<br>_Run daily, weekly, monthly, and quarterly FinOps workflows without waiting for manual report requests._
- **Ground every answer**<br>_Use FinOps hub data, FOCUS-aligned Kusto tools, and Azure platform context to keep recommendations tied to evidence._
- **Act with experts**<br>_Route work to specialized FinOps, finance, capacity, database, and hubs agents instead of a single generic assistant._

The FinOps toolkit deployment helps teams move from dashboards and alerts to an operating model where the agent investigates cost changes, monitors quota and capacity signals, prepares executive summaries, and delivers scheduled updates through Azure SRE Agent.

<!-- prettier-ignore-start -->
> [!NOTE]
> Estimated cost: Varies by Azure SRE Agent preview pricing, telemetry ingestion, and your existing FinOps hub footprint.
>
> The template provisions an Azure SRE Agent, Log Analytics workspace, Application Insights resource, and user-assigned managed identity. Costs depend on the selected region, Azure SRE Agent pricing, Log Analytics and Application Insights ingestion and retention, and the Azure Data Explorer footprint you connect to. The managed identity and RBAC assignments don't typically add direct cost.
<!-- prettier-ignore-end -->

<br>

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
<!-- prettier-ignore-end -->

<br>

## What you get

The FinOps toolkit's Azure SRE Agent template deploys and configures these resources and Azure SRE Agent objects:

| Component | Count | Description |
|-----------|-------|-------------|
| Azure SRE Agent | 1 | `Microsoft.App/agents` resource in autonomous mode |
| Managed identity | 1 | User-assigned managed identity for the agent |
| Log Analytics | 1 | Workspace for agent telemetry |
| Application Insights | 1 | Linked to Log Analytics for monitoring |
| Subscription RBAC | 2 | Reader and Monitoring Contributor role assignments |
| Custom role | 1 | `FinOps SRE Zone Peers Reader` for cross-subscription zone mapping |
| Azure Data Explorer role | Optional | `AllDatabasesViewer` when Azure Data Explorer parameters are provided |
| Subagents | 5 | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, and `ftk-hubs-agent` |
| Skills | 3 | `azure-capacity-management`, `azure-cost-management`, and `finops-toolkit` |
| Tools | 33 | 21 Kusto tools for FinOps hub queries and 12 Python tools for Azure capacity APIs |
| Scheduled tasks | 18 | 9 core reporting tasks and 9 capacity and governance audits |
| Connector | 1 | Kusto MCP connector to your FinOps hub Azure Data Explorer cluster |
| Notification connectors | 0 by default | Outlook and Teams can be added after deployment in the Azure SRE Agent portal |

<br>

## Architecture overview

The FinOps toolkit deployment uses Azure Developer CLI (`azd`) for the Bicep template and `srectl` to configure Azure SRE Agent. The deployment runs in this order:

1. `azd up` deploys the subscription-scoped Bicep template.
2. Bicep creates the resource group, managed identity, monitoring resources, and Azure SRE Agent.
3. Bicep assigns Reader and Monitoring Contributor at the subscription scope.
4. Bicep can optionally assign `AllDatabasesViewer` on your FinOps hub Azure Data Explorer cluster.
5. When `finopsHubClusterUri` is provided, Bicep creates the Kusto connector for the FinOps hub Azure Data Explorer cluster.
6. The post-provision hook installs `srectl`, initializes it with the deployed agent endpoint, and applies skills, agents, tools, knowledge, and scheduled tasks.
7. You optionally add Outlook and Teams connectors in [sre.azure.com](https://sre.azure.com) when you want scheduled reports delivered outside the agent chat.

The result is a single Azure SRE Agent with a FinOps operating model layered on top. The `finops-practitioner` agent handles cost visibility, anomaly response, allocation, optimization, AI cost management, and practice health. The `azure-capacity-manager` agent monitors quota, capacity reservations, regional access, zone mapping, and capacity-to-rate alignment. The `chief-financial-officer` agent prepares budgeting, forecasting, executive finance, and unit economics narratives. The `ftk-database-query` agent runs focused Kusto diagnostics, and the `ftk-hubs-agent` monitors FinOps hub health and data freshness.

<br>

## When to use the agent

FinOps teams often have the data they need but not the time to run every investigation on schedule. The agent gives the team an automated operating rhythm that can review cost changes, check commitment coverage, monitor capacity headroom, and summarize action items before the next stakeholder meeting.

Use the agent when you want to:

- Review FinOps hub data through conversational and scheduled agent workflows.
- Monitor cost anomalies, budget variance, and forecast drift.
- Track quota usage, capacity reservation utilization, region access, and zone readiness.
- Prepare daily, weekly, monthly, and quarterly cost and capacity summaries.
- Route questions to specialized agents with FinOps, finance, capacity, database, and hubs context.

<br>

## Get started

Deploy the agent when you have a FinOps hub with an Azure Data Explorer cluster and an Azure subscription where you can deploy Azure SRE Agent resources. After deployment, open the agent in [sre.azure.com](https://sre.azure.com), verify the subagents, skills, tools, and scheduled tasks, and add notification connectors if you want reports sent to Teams or Outlook.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
<!-- prettier-ignore-end -->

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

- [Anomaly management](../../framework/understand/anomalies.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Azure SRE Agent template reference (FinOps toolkit)](template.md)

<br>
