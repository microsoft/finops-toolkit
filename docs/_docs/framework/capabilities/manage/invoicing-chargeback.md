---
layout: default
grand_parent: FinOps Framework
parent: Manage
title: Chargeback
permalink: /framework/capabilities/manage/invoicing-chargeback
nav_order: 6
description: This article helps you understand the chargeback and finance integration capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/23/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Chargeback and finance integration</span>
This article helps you understand the chargeback and finance integration capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
{: .fs-6 .fw-300 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [Before you begin](#before-you-begin)
- [Getting started](#getting-started)
- [Building on the basics](#building-on-the-basics)
- [Learn more at the FinOps Foundation](#learn-more-at-the-finops-foundation)
- [Next steps](#next-steps)

</details>

---

<a name="definition"></a>
**Chargeback refers to the process of billing internal teams for their respective cloud costs. Finance integration involves leveraging existing internal finance tools and processes.**
{: .fs-6 .fw-300 }

Plan the chargeback model with IT and Finance departments. Use the organizational cost allocation strategy that factors in how stakeholders agreed to account for shared costs and commitment-based discounts.

Use existing tools and processes to manage cloud costs as part of organizational finances. Chargeback is represented in the accounting system, [budgets](capabilities-budgets.md) are managed through the budget system, etc.

Chargeback and finance integration enables increased transparency, more direct accountability for the costs each department incurs, and reduced overhead costs.

<br>

## Before you begin

Chargeback, cost allocation, and showback are all important components of your FinOps practice. While you can implement them in any order, we generally recommend most organizations start with [showback](capabilities-analysis-showback.md) to ensure each team has visibility of the charges they're responsible for – at least at a cloud scope level. Then implement [cost allocation](capabilities-allocation.md) to align cloud costs to the organizational reporting hierarchies, and lastly implement chargeback based on that cost allocation strategy. Consider reviewing the [Data analysis and showback](capabilities-analysis-showback.md) and [Cost allocation](capabilities-allocation.md) capabilities if you haven't implemented them yet. You may also find [Managing shared costs](capabilities-shared-cost.md) and [Managing commitment-based discounts](capabilities-commitment-discounts.md) capabilities to be helpful in implementing a complete chargeback solution.

<br>

## Getting started

Chargeback and finance integration is all about integrating with your own internal tools. Consider the following points:

- Collaborate with stakeholders across finance, business, and technology to plan and prepare for chargeback.
- Document how chargeback works and be prepared for questions.
- Use the organizational [cost allocation](capabilities-allocation.md) strategy that factors in how stakeholders agreed to account for [shared costs](capabilities-shared-cost.md) and [commitment-based discounts](capabilities-commitment-discounts.md).
  - If you haven't established one, consider simpler chargeback models that are fair and agreed upon by all stakeholders.
- Use existing tools and processes to manage cloud costs as part of organizational finances.

<br>

## Building on the basics

At this point, you have a basic chargeback model that all stakeholders have agreed to. As you move beyond the basics, consider the following points:

- Consider implementing a one-way sync from your budget system to [Cost Management budgets](https://learn.microsoft.com/azure/cost-management-billing/automate/automate-budget-creation.md) to use automated alerts based on machine learning forecasts.
- If you track manual forecasts, consider creating Cost Management budgets for your forecast values as well. It gives you separate tracking and alerting for budgets separate from your forecast.
- Automate your [cost allocation](capabilities-allocation.md) strategy through tagging.
- Expand coverage of [shared costs](capabilities-shared-cost.md) and [commitment-based discounts](capabilities-commitment-discounts.md) if not already included.
- Fully integrate chargeback and showback reporting with the organization's finance tools.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Chargeback and finance integration capability](https://www.finops.org/framework/capabilities/chargeback/) article in the FinOps Framework documentation.

<br>

## Next steps

- [Data analysis and showback](../understand/reporting.md)
- [Managing shared costs](../understand/shared-cost.md)
- [Managing commitment-based discounts](../optimize/commitment-discounts.md)

<br>
