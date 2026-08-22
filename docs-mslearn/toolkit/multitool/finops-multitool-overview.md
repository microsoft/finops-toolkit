---
title: FinOps multitool overview
description: FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights from a terminal UI, with agent skills so AI assistants can run the same analysis.
author: z-larsen
ms.author: zlarsen
ms.date: 08/22/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I need to learn about the FinOps multitool.
---

# FinOps multitool

FinOps multitool scans an Azure environment for cost optimization, governance, and FinOps insights and grounds its findings in your live resource state. It surfaces cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance—from an interactive terminal or as tools an AI agent can call.

## How it works

FinOps multitool runs 30 scan modules against the subscriptions you select and renders the findings in one place:

- **Interactive scanning** <br> Choose the subscriptions and scan modules you want, then review results in the terminal. Findings can be exported to CSV, an HTML report, and a text summary. Consoles that can't render the arrow-key menus fall back to numbered prompts, and a non-interactive mode runs the same scans from a pipeline or a scheduled job.

- **AI agent support** <br> A companion set of agent skills teaches AI assistants the same investigations, the queries behind them, and how to read the results, so they can answer cost questions grounded in your environment instead of general guidance.

- **Scales with your data** <br> When a [FinOps hub](../hubs/finops-hubs-overview.md) is available, cost scans query the hub's Azure Data Explorer or Microsoft Fabric database and push aggregation into the engine, returning only summarized results. A storage reader covers smaller datasets, and the Cost Management API is used when no hub is present.

- **Read-only** <br> Every scan reads your environment and reports what it finds. The multitool never creates, changes, or deletes a resource.

## Benefits

FinOps multitool shortens the path from "what is this costing us?" to a specific, actionable list. Instead of checking Azure Advisor, Cost Analysis, Resource Graph, and the budgets blade separately, you run one scan and get the findings together, scoped to the subscriptions you care about.

## Why FinOps multitool?

[FinOps workbooks](../workbooks/finops-workbooks-overview.md) and the [Azure Optimization Engine](../optimization-engine/overview.md) surface optimization opportunities in the Azure portal. FinOps multitool brings the same class of insight to the terminal and to AI agents, so engineers can scan an environment during a working session without switching context, and agents can ground their answers in real resource state.

## Required permissions

Most scans need [Reader](/azure/role-based-access-control/built-in-roles#reader) or [Cost Management Reader](/azure/role-based-access-control/built-in-roles#cost-management-reader) on the target scope. Account scans (billing structure, contract info, and Microsoft Azure Consumption Commitment balance) also need [Billing Reader](/azure/role-based-access-control/built-in-roles#billing-reader), or Enterprise Administrator (reader) on an Enterprise Agreement. The carbon scan needs Reader or [Carbon Optimization Reader](/azure/carbon-optimization/permissions) assigned at the subscription. Carbon emissions permissions don't apply at resource group or resource scope.

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
