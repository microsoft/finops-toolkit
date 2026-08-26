---
title: FinOps toolkit agent plugin overview
description: The FinOps toolkit agent plugin brings AI-powered cloud financial management to Claude Code and GitHub Copilot CLI.
author: flanakin
ms.author: micflan
ms.date: 08/14/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: msbrett
#customer intent: As a FinOps practitioner, I need to learn about the FinOps toolkit agent plugin.
---

# FinOps toolkit agent plugin

The FinOps toolkit agent plugin brings AI-powered cloud financial management to your coding agent. It works with both [Claude Code](https://claude.com/claude-code) and [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli), pairing role-specific agents, ready-to-run commands, and a FinOps hubs query skill with a read-only [Azure MCP server](https://github.com/Azure/azure-mcp) so you can analyze cost data, review recommendations, and manage FinOps hubs without leaving your terminal.

## Installation

Install the plugin from the FinOps toolkit repository:

```bash
# Claude Code
claude plugin add microsoft/finops-toolkit

# GitHub Copilot CLI
copilot plugin install microsoft/finops-toolkit
```

The plugin registers an Azure MCP server scoped to the Kusto namespace in read-only mode, so it can query FinOps hubs data without being able to modify your environment.

## What's included

### Agents

| Agent                          | Description                                                                                                                                                                                    |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Chief Financial Officer**    | Executive-level guidance across financial strategy, capital allocation, risk management, budgeting, forecasting, and cost optimization.                                                        |
| **FinOps practitioner**        | Domain expertise on FinOps principles, cost allocation, showback/chargeback models, and the FinOps Framework maturity model.                                                                   |
| **FinOps hubs database query** | Queries cost data, resource metadata, pricing, regional data, and service mappings from a FinOps hub's Data Explorer database.                                                                 |
| **FinOps hubs agent**          | Deploys, upgrades, configures, and troubleshoots FinOps hubs, including Cost Management exports and hub architecture questions.                                                                |
| **Azure capacity manager**     | Azure capacity evidence for FinOps work: quota analysis, capacity reservation groups, SKU availability, region and zone access, and coordinating capacity guarantees with pricing commitments. |

### Commands

| Command                 | Description                                                                                                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- |
| `/ftk-hubs-connect`     | Discover FinOps hub instances via Azure Resource Graph, connect to a cluster, and save environment settings.   |
| `/ftk-hubs-healthCheck` | Check a deployed hub's version against the latest stable and dev releases and validate data freshness.         |
| `/ftk-mom-report`       | Autonomous month-over-month cost analysis with anomaly detection, forecasting, and actionable recommendations. |
| `/ftk-ytd-report`       | Comprehensive fiscal year-to-date cost analysis with a forecast through your organization's fiscal year end.   |

### Skill and query catalog

The **finops-toolkit** skill triggers on FinOps hubs, KQL, and Azure Data Explorer topics and provides task routing, a query catalog, and schema guidance for working with a FinOps hub's `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()` functions.

## Required permissions

- [Azure CLI](/cli/azure/install-azure-cli) authenticated (`az login`).
- Azure RBAC permissions for the Cost Management APIs you want to query or manage.
- For FinOps hubs queries: Database Viewer access to the hub's Azure Data Explorer cluster.

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20agent%20plugin%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%20agent%20plugin%3F/surveyId/FTK/bladeName/AgentPlugin/featureName/Overview)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps hubs data model](../hubs/data-model.md)

<br>
