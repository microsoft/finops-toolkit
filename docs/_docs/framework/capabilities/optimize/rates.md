---
layout: default
grand_parent: FinOps Framework
parent: Optimize
title: Rate optimization
permalink: /framework/capabilities/optimize/rates
nav_order: 3
description: This article helps you understand the rate optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/22/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Rate optimization</span>
This article helps you understand the rate optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
{: .fs-6 .fw-300 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [✋ Before you begin](#-before-you-begin)
- [▶️ Getting started](#️-getting-started)
- [🏗️ Building on the basics](#️-building-on-the-basics)
- [🍎 Learn more at the FinOps Foundation](#-learn-more-at-the-finops-foundation)
- [⏩ Next steps](#-next-steps)
- [🧰 Related tools](#-related-tools)

</details>

---

<a name="definition"></a>
**Rate otpimization is the practice of obtaining reduced rates on cloud services, often by committing to a certain level of usage or spend over a specific period.**
{: .fs-6 .fw-300 }

Review daily usage and cost trends to estimate how much you expect to use or spend over the next one to five years. Use [Forecasting](../quantify/forecasting.md) and account for future plans.

Commit to specific hourly usage targets to receive discounted rates and save up to 72% with [Azure reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations). Or for more flexibility, commit to a specific hourly spend to save up to 65% with [Azure savings plans for compute](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview). Reservation discounts can be applied to resources of the specific type, SKU, and location only. Savings plan discounts are applied to a family of compute resources across types, SKUs, and locations. The extra specificity with reservations is what drives more favorable discounting.

Adopting a commitment-based strategy allows organizations to reduce their overall cloud costs while maintaining the same or higher usage by taking advantage of discounts on the resources they already use.

<br>

## ✋ Before you begin

<!-- TODO: Add context on all rate optimization opportunities -->

While you can save by using reservations and savings plans, there's also a risk that you may not end up using that capacity. You could end up underutilizing the commitment and lose money. While losing money is rare, it's possible. We recommend starting small and making targeted, high-confidence decisions. We also recommend not waiting too long to decide on how to approach commitment discounts when you do have consistent usage because you're effectively losing money. Start small and learn as you go. But first, learn how [reservation](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-discount-application) and [savings plan](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/discount-application) discounts are applied.

Before you purchase either a reservation or a savings plan, consider the usage you want to commit to. If you have high confidence, you maintain a specific level of usage for that type, SKU, and location, strongly consider starting with a reservation. For maximum flexibility, you can use savings plans to cover a wide range of compute costs by committing to a specific hourly spend instead of hourly usage.

<br>

## ▶️ Getting started

<!-- TODO: Consider adding dev/test, but make sure it's for more than just EA 
Leverage the [Azure Dev/Test](https://azure.microsoft.com/pricing/offers/ms-azr-0148p/) offer that comes with a Visual Studio subscription to take advantage of Azure monthly credits to explore and try various Azure services, benefit from discounted Azure dev/test rates, and enable cost-efficient developing and testing. Although rate optimization strategies can be applied to resources in a development environment, the Azure Dev/Test environment is primarily used for learning and training, development and testing, evaluating proof of concepts, and experimenting and innovating to ensure efficient use of resources.
-->

Microsoft offers several tools to help you identify when you should consider purchasing reservations or savings plans. You can choose whether you want to start by analyzing usage or by reviewing the system-generated recommendations based on your historical usage and cost. We recommend starting with the recommendations to focus your initial efforts:

- One of the most common starting points is [Azure Advisor cost recommendations](https://learn.microsoft.com/azure/advisor/advisor-reference-cost-recommendations).
- For more flexibility, you can view and filter recommendations in the [reservation](https://learn.microsoft.com/azure/cost-management-billing/reservations/reserved-instance-purchase-recommendations) and [savings plan](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/purchase-recommendations#purchase-recommendations-in-the-azure-portal) purchase experiences.
- Lastly, you can also view reservation recommendations in [Power BI](https://learn.microsoft.com/power-bi/connect-data/desktop-connect-azure-cost-management).
- After you know what to look for, you can [analyze your usage data](https://learn.microsoft.com/azure/cost-management-billing/reservations/determine-reservation-purchase#analyze-usage-data) to look for the specific usage you want to purchase a reservation for.

After purchasing commitments, you can:

- View utilization from the [reservation](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-utilization) or [savings plan](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/view-utilization) page in the portal.
  - Consider expanding the scope or enabling instance size flexibility (when available) to increase utilization and maximize savings of an existing commitment.
  - [Configure reservation utilization alerts](https://learn.microsoft.com/azure/cost-management-billing/costs/reservation-utilization-alerts) to notify stakeholders if utilization drops below a desired threshold.
- View showback and chargeback reports for [reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/charge-back-usage) and [savings plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/charge-back-costs).

<br>

## 🏗️ Building on the basics

At this point, you have commitment discounts in place. As you move beyond the basics, consider the following points:

- Configure commitments to automatically renew for [reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-renew) and [savings plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/renew-savings-plan).
- Calculate cost savings for [reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/calculate-ea-reservations-savings) and [savings plans](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/calculate-ea-savings-plan-savings).
- If you use multiple accounts, clouds, or providers, expand coverage of your commitment discounts efforts to include all accounts.
  - Consider implementing a consistent utilization and coverage monitoring system that covers all accounts.
- Establish a process for centralized purchasing of commitment-based offers, assigning responsibility to a dedicated team or individual.
- Consider programmatically aligning governance policies with commitments to prioritize SKUs and locations that are covered by reservations and aren't fully utilized when deploying new applications.
- If you need to monitor the usage of commitment discounts outside of the Azure portal, consider deploying FinOps hubs which includes a [Rate optimization report](../../../../_reporting/power-bi/rate-optimization.md) that summarizes existing and potential savings from commitment discounts, like reservations and savings plans.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Rate optimization](https://www.finops.org/framework/capabilities/rate-optimization/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/jO2WlOHmbN8?list=PLUSCToibAswm37b7-VLl3nJ7A4wuGSpCI&pp=iAQB]-->
{% include video.html title="Rate optimization videos" id="jO2WlOHmbN8" list="PLUSCToibAswm37b7" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Data analysis and showback](../understand/reporting.md)
- [Cloud policy and governance](../manage/policy.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="1" pbi="1" ps="0" %}

<br>
