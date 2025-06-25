---
title: Planning and estimating
description: This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the FinOps practice operations capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Planning and estimating

This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Planning and estimating refers to the process of estimating the cost and usage of new and existing workloads based on exploratory or planned architectural changes and evolving business priorities.**

To estimate initial costs for new workloads, apply historical usage and cost trends from similar workloads. Adjust or augment that based on the unique of new or changing workloads.

Work with other teams to align business goals with product requirements and technical needs. This collaboration ensures that leadership, finance, product, engineering, and FinOps teams are on the same page during planning and estimation. It also ensures that the solution meets both business and customer needs.

With accurate and detailed architectural plans and cost estimates, organizations are better prepared to deploy new workloads and efficiently scale existing ones to achieve business goals.

<br>

## Before you begin

To effectively plan and estimate usage and costs for a cloud workload, first align stakeholders on the goals and priorities. Then, map them to the product requirements and technical needs.

- Document requirements, motivations, and expected outcomes for building new or improving existing workloads, including cloud migrations.
  - Motivations might include cost savings, scaling abilities, or building new technical capabilities within your organization. Use existing KPIs and project potential impact.
  - Describe any requirements necessary for successful delivery, such as executive sponsorship or support from individual teams.
  - Define the scope of the effort, including detailed requirements, and unique needs of the workload necessary to meet business goals.
- Understand financial constraints and considerations, like staff productivity, cloud economics, and the nuances with an OpEx model.
- Define technical considerations:
  - Scalability
  - Availability
  - Resiliency
  - Security and Compliance
  - Elasticity (managed, maintain, pay for cloud)
  - Capacity optimization
- Familiarize yourself with [how you’re charged for the services you use](https://azure.microsoft.com/pricing#product-pricing) to understand:
  - Factors that contribute to costs (for example, compute, storage, networking, and data transfer).
  - How usage aligns with the various pricing models (for example, pay-as-you-go, reservations, and Azure Hybrid Benefit).

Starting with well-defined requirements that are aligned across teams helps set clear expectations and establishes a solid foundation for effective cross-group collaboration over the lifecycle of each workload.

<br>

## Getting started

- If you're migrating on-premises infrastructure to the cloud:
  - Use the [Total Cost of Ownership (TCO) Calculator](https://azure.microsoft.com/pricing/tco/calculator) to get a high-level comparison of on-premises vs. cloud servers, databases, storage, and networking infrastructure.
    > After entering details of your on-premises infrastructure, the TCO Calculator presents cost reports showcasing the cost differences between running workloads on-premises compared to Azure that can be saved and shared across team members.
  - Use [Azure Migrate](https://azure.microsoft.com/products/azure-migrate) to automate the discovering and migration of your on-premises workloads.
- If you're estimating changes to an existing workload, review the [Forecasting](./forecasting.md) capability.
- If you're building a new solution, start with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator) to estimate costs based on projected usage patterns.
  > Within the pricing calculator, custom scenarios can be analyzed by generating estimates and configuring resources to match specific parameters. Cost savings such as reservations, savings plans, and Azure Hybrid Benefit can also be evaluated. Sign in to save estimates based on your enterprise pricing.

<br>

## Building on the basics

- Use the [Cost optimization workbook](../../toolkit/workbooks/optimization.md) to optimize current workloads and reduce potential future estimates.
- Review the [Architecting for cloud](../optimize/architecting.md) capability to ensure workloads are designed for efficiency.
- Evaluate options to reduce costs through the [Rate optimization](../optimize/rates.md) capability.
- Automate best practices through [Azure Policy](/azure/governance/policy/overview) to enforce organizational standards at scale.

With these insights, you can make more accurate cost predictions and manage your cloud budget effectively.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see to the [planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/) article in the FinOps Framework documentation.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.Framework/featureName/Capabilities.Quantify.Planning)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Forecasting](./forecasting.md)
- [Architecting for cloud](../optimize/architecting.md)
- [Workload optimization](../optimize/workloads.md)
- [Rate optimization](../optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)

<br>
