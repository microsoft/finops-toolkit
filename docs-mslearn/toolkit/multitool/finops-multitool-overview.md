---
title: FinOps multitool overview
description: FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights from a terminal UI, with agent skills so AI assistants can run the same analysis.
author: z-larsen
ms.author: zlarsen
ms.date: 09/20/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I need to learn about the FinOps multitool.
---

# FinOps multitool

FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights, grounded in your live resource state. It reports on cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance. Run it from an interactive terminal, or call it as tools from an AI agent.

## How it works

FinOps multitool provides 30 scan modules, with 26 available in the terminal menu, and renders findings for the subscriptions you select:

- **Interactive scanning** <br> Choose the subscriptions and scan modules you want, then review results in the terminal. Every completed run automatically saves CSV files, an HTML report, and a text summary to a private local folder. See [Report storage](../powershell/multitool/start-finopsmultitool.md#report-storage) for locations and privacy limits. Consoles that can't render the arrow-key menus fall back to numbered prompts. Non-interactive runs require an existing Azure sign-in context.

- **AI agent support** <br> Agent skills describe the same investigations, the queries behind them, and how to read the results, so AI assistants can answer cost questions from your environment's data.

- **Cost data sources** <br> When a [FinOps hub](../hubs/finops-hubs-overview.md) is available, cost scans query the hub's Azure Data Explorer or Microsoft Fabric database and push aggregation into the engine, returning only summarized results. A storage reader covers smaller datasets, and the Cost Management API is used when no hub is present.

- **Read-only** <br> The multitool never creates, changes, or deletes a resource.

## Benefits

FinOps multitool provides the following benefits:

- Choose from 26 menu scans across optimization, governance, cost analysis, commitments, monitoring, and sustainability, with four more modules for direct investigations.
- Scope each scan to the subscriptions you select.
- Get a CSV file per selected scan, an HTML report, and a text summary saved automatically to a private local folder.
- Read costs from a FinOps hub or the Cost Management API, with resource inventory from Azure Resource Graph.
- Run the same scans from a pipeline or a scheduled job with `-NonInteractive`.
- Run the same investigations from an AI assistant through agent skills.

## Why FinOps multitool?

[FinOps workbooks](../workbooks/finops-workbooks-overview.md) and the [Azure Optimization Engine](../optimization-engine/overview.md) surface optimization opportunities in the Azure portal. FinOps multitool reports the same kinds of findings in the terminal and through AI agent skills, so you can scan an environment during a working session without leaving the command line.

## Required permissions

Most scans need [Reader](/azure/role-based-access-control/built-in-roles#reader) or [Cost Management Reader](/azure/role-based-access-control/built-in-roles#cost-management-reader) on the target scope. Account scans (billing structure, contract info, and Microsoft Azure Consumption Commitment balance) also need agreement-specific billing access: [Billing account reader or Billing profile reader for a Microsoft Customer Agreement](/azure/cost-management-billing/manage/understand-mca-roles), or [Enterprise Administrator (read only) for an Enterprise Agreement](/azure/cost-management-billing/manage/understand-ea-roles), at the scope the scan reads.

Commitment utilization reads reservation and savings plan usage at billing account or billing profile scope, so it needs the same access as account scans. Reader on a subscription isn't enough. Without it, the scan tells you it couldn't reach a billing scope instead of showing zero commitments.

The carbon scan needs Reader or [Carbon Optimization Reader](/azure/carbon-optimization/permissions) assigned at the subscription. Carbon emissions permissions don't apply at resource group or resource scope.

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20multitool%3F/cvaQuestion/How%20valuable%20are%20FinOps%20multitool%3F/surveyId/FTK/bladeName/Multitool/featureName/Overview)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Workload optimization](../../framework/optimize/workloads.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Cost Management](/azure/cost-management-billing/)

Related solutions:

- [FinOps multitool commands](../powershell/multitool/finops-multitool-commands.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)

<br>
