---
title: Invoicing and chargeback
description: This article helps you understand the invoicing and chargeback capability in the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
ms.topic: concept-article
# customer intent: As a FinOps practitioner, I want to understand the invoicing and chargeback capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Invoicing and chargeback

This article helps you understand the invoicing and chargeback capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Invoicing and chargeback refers to the process of receiving, reconciling, and paying provider invoices, and then billing internal teams for their respective cloud costs using existing internal finance tools and processes.**

Plan the chargeback model with IT and Finance departments. Use the organizational cost allocation strategy that factors in how stakeholders agreed to account for shared costs and commitment discounts.

Use existing tools and processes to manage cloud costs as part of organizational finances. Chargeback is represented in the accounting system. [Budgets](../quantify/budgeting.md) are managed through the budget system.

Invoicing and chargeback enable increased transparency, more direct accountability for the costs each department incurs, and reduced overhead costs.

<br>

## Before you begin

Chargeback, cost allocation, and showback are all important components of your FinOps practice. While you can implement them in any order, we generally recommend most organizations start with [showback](../understand/reporting.md) to ensure each team has visibility of the charges they're responsible for – at least at a cloud scope level. Then implement [cost allocation](../understand/allocation.md) to align cloud costs to the organizational reporting hierarchies, and lastly implement chargeback based on that cost allocation strategy. Consider reviewing the [Data analysis and showback](../understand/reporting.md) and [Cost allocation](../understand/allocation.md) capabilities if you didn't implement them yet. You might also find the [Rate optimization](../optimize/rates.md) capability to be helpful in implementing a complete chargeback solution that covers commitment discounts.

<br>

## Getting started

Invoicing and chargeback are all about integrating with your own internal tools. Consider the following points:

- To plan and prepare for chargeback, collaborate with stakeholders across finance, business, and technology.
- Document how chargeback works and be prepared for questions.
- Use the organizational [cost allocation](../understand/allocation.md) strategy that factors in how stakeholders agreed to account for shared costs and [commitment discounts](../optimize/rates.md).
  - If you didn't establish one, consider simpler chargeback models that are fair and agreed upon by all stakeholders.
- Use existing tools and processes to manage cloud costs as part of organizational finances.

<br>

## Building on the basics

At this point, you have a basic chargeback model that all stakeholders agreed to. As you move beyond the basics, consider the following points:

- Think about setting up a one-way synchronization from your budget system to [Cost Management budgets](/azure/cost-management-billing/automate/automate-budget-creation). It  allows you to use automated alerts that are based on machine learning predictions.
- If you track manual forecasts, consider creating Cost Management budgets for your forecast values as well. It gives you separate tracking and alerting for budgets separate from your forecast.
- Automate your [cost allocation](../understand/allocation.md) strategy through tagging.
- Expand coverage of shared costs and [commitment discounts](../optimize/rates.md) if not already included.
- Fully integrate chargeback and showback reporting with the organization's finance tools.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [invoicing and Chargeback capability](https://www.finops.org/framework/capabilities/invoicing-chargeback/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/9JQQOVkN51g?list=PLUSCToibAswkALdvffeZWF-3L4ubFuobD]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.Framework/featureName/Capabilities.Manage.Invoicing)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../understand/reporting.md)
- [Allocation](../understand/allocation.md)
- [Rate optimization](../optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Billing](/azure/cost-management-billing/manage/)
- [Azure Monitor](/azure/azure-monitor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../../toolkit/powershell/powershell-commands.md)

<br>
