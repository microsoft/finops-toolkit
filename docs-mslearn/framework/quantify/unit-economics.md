---
title: Unit economics
description: This article helps you understand the unit economics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the unit economics capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Unit economics

This article helps you understand the unit economics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Unit economics refers to the process of calculating the cost of a single unit of a business that can show the business value of the cloud.**

Identify what a single unit is for your business – like a sale transaction for an ecommerce site or a user for a social app. Map each unit to the supporting cloud services that support it. To quantify the total cost of each unit, split the cost of shared infrastructure with utilization data.

Unit economics provides insights into profitability and allows organizations to make data-driven business decisions regarding cloud investments. Unit economics is what ties the cloud to measurable business value.

The ultimate goal of unit economics, as a derivative of activity-based costing methodology, is to factor in the whole picture of your business's cost. This article focuses on capturing how you can factor your Microsoft Cloud costs into those efforts. As your FinOps practice matures, consider the manual processes and steps outside of the cloud that might be important for calculating units that are critical for your business to track the most accurate cost per unit.

<br>

## Before you begin

Before you can effectively measure unit costs, you need to familiarize yourself with [how you're charged for the services you use](https://azure.microsoft.com/pricing#product-pricing). Understanding the factors that contribute to costs, helps you break down the usage and costs and map them to individual units. Cost contributing-factors factors include compute, storage, networking, and data transfer. How your service usage aligns with the various pricing models (for example, pay-as-you-go, reservations, and Azure Hybrid Benefit) also impacts your costs.

<br>

## Getting started

Unit economics isn't a simple task. Unit economics requires a deep understanding of your architecture and needs multiple datasets to pull together the full picture. The exact data you need depends on the services you use and the telemetry you have in place.

- Start with application telemetry.
  - The more comprehensive your application telemetry is, the simpler unit economics can be to generate. Log when critical functions are executed and how long they run. You can use that to deduce the run time of each unit or relative to a function that correlates back to the unit.
  - When application telemetry isn't directly possible, consider workarounds that can log telemetry, like [API Management](/azure/api-management/api-management-key-concepts) or even [configuring alert rules in Azure Monitor](/azure/azure-monitor/alerts/alerts-create-new-alert-rule) that trigger [action groups](/azure/azure-monitor/alerts/action-groups) that log the telemetry. The goal is to get all usage telemetry into a single, consistent data store.
  - If you don't have telemetry in place, consider setting up [Application Insights](/azure/azure-monitor/app/app-insights-overview), which is an extension of Azure Monitor.
- Use [Azure Monitor metrics](/azure/azure-monitor/essentials/data-platform-metrics) to pull resource utilization data.
  - If you don't have telemetry, see what metrics are available in Azure Monitor that can map your application usage to the costs. You need anything that can break down the usage of your resources to give you an idea of what percentage of the billed usage was from one unit vs. another.
  - If you don't see the data you need in metrics, also check [logs and traces in Azure Monitor](/azure/azure-monitor/overview#data-platform). It might not be a direct correlation to usage but might be able to give you some indication of usage.
- Use service-specific APIs to get detailed usage telemetry.
  - Every service uses Azure Monitor for a core set of logs and metrics. Some services also provide more detailed monitoring and utilization APIs to get more details than are available in Azure Monitor. Explore [Azure service documentation](/azure) to find the right API for the services you use.
- Using the data you collected, quantify the percentage of usage coming from each unit.
  - Use pricing and usage data to facilitate this effort. It's typically best to do after [Data ingestion and normalization](../understand/ingestion.md) due to the high amount of data required to calculate accurate unit costs.
  - Some amount of usage isn't mapped back to a unit. There are several ways to account for this cost, like distributing based on those known usage percentages or treating it as overhead cost that should be minimized separately.

<br>

## Building on the basics

- Automate any aspects of the unit cost calculation that aren't fully automated.
- Consider expanding unit cost calculations to include other costs, like external licensing, on-premises operational costs, and labor.
- Build unit costs into business KPIs to maximize the value of the data you collected.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Unit economics capability](https://www.finops.org/framework/capabilities/unit-economics/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/wrUsblmKCKU?list=PLUSCToibAswkxZme8TQKg3uBNh2Qk1MvL&pp=iAQB]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.Framework/featureName/Capabilities.Quantify.UnitEconomics)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Data analysis and showback](../understand/reporting.md)
- [Cost Allocation](../understand/allocation.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Application Insights](/azure/azure-monitor/app/app-insights-overview)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)

<br>
