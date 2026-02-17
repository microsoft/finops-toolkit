---
title: Rate optimization
description: This article helps you understand the rate optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/04/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: kedelaro
# customer intent: As a FinOps practitioner, I want to understand the rate optimization capability so that I can implement that in the Microsoft cloud.
---

# Rate optimization

This article helps you understand the rate optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Rate optimization is the practice of obtaining reduced rates on cloud services, often by committing to a certain level of usage or spend over a specific period.**

Review daily usage and cost trends to estimate how much you expect to use or spend over the next one to five years. Use [Forecasting](../quantify/forecasting.md) and account for future plans.

Commit to specific hourly usage targets to receive discounted rates and save up to 72% with [Azure reservations](/azure/cost-management-billing/reservations/save-compute-costs-reservations). Or for more flexibility, commit to a specific hourly spend to save up to 65% with [Azure savings plans for compute](/azure/cost-management-billing/savings-plan/savings-plan-compute-overview). Reservation discounts can be applied to resources of the specific type, SKU, and location only. Savings plan discounts are applied to a family of compute resources across types, SKUs, and locations. The extra specificity with reservations is what drives more favorable discounting.

Adopting a commitment-based strategy allows organizations to reduce their overall cloud costs while maintaining the same or higher usage by taking advantage of discounts on the resources they already use.

<br>

## Before you begin

While you can save by using reservations and savings plans, there's also a risk that you might not end up using that capacity. You could end up under-utilizing the commitment and lose money. While losing money is rare, it's possible. We recommend starting small and making targeted, high-confidence decisions. We also recommend not waiting too long to decide on how to approach commitment-based discounts when you do have consistent usage because you're effectively losing money. Start small and learn as you go. But first, learn how [reservation](/azure/cost-management-billing/reservations/reservation-discount-application) and [savings plan](/azure/cost-management-billing/savings-plan/discount-application) discounts are applied.

Consider the usage you want to commit to before you purchase either a reservation or a savings plan. If you have high confidence, you maintain a specific level of usage for that type, SKU, and location, strongly consider starting with a reservation. For maximum flexibility, you can use savings plans to cover a wide range of compute costs by committing to a specific hourly spend instead of hourly usage.

<br>

## Getting started

<!-- TODO: Consider adding dev/test, but make sure it's for more than just EA 
Leverage the [Azure Dev/Test](https://azure.microsoft.com/pricing/offers/ms-azr-0148p/) offer that comes with a Visual Studio subscription to take advantage of Azure monthly credits to explore and try various Azure services, benefit from discounted Azure dev/test rates, and enable cost-efficient developing and testing. Although rate optimization strategies can be applied to resources in a development environment, the Azure Dev/Test environment is primarily used for learning and training, development and testing, evaluating proof of concepts, and experimenting and innovating to ensure efficient use of resources.
-->

Microsoft offers several tools to help you identify when you should consider purchasing reservations or savings plans. You can choose whether you want to start by analyzing usage or by reviewing the system-generated recommendations based on your historical usage and cost. We recommend starting with the recommendations to focus your initial efforts:

- One of the most common starting points is [Azure Advisor cost recommendations](/azure/advisor/advisor-reference-cost-recommendations).
- For more flexibility, you can view and filter recommendations in the [reservation](/azure/cost-management-billing/reservations/reserved-instance-purchase-recommendations) and [savings plan](/azure/cost-management-billing/savings-plan/purchase-recommendations#purchase-recommendations-in-the-azure-portal) purchase experiences.
- Lastly, you can also view reservation recommendations in [Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management).
- After you know what to look for, you can [analyze your usage data](/azure/cost-management-billing/reservations/determine-reservation-purchase#analyze-usage-data) to look for the specific usage you want to purchase a reservation for.

After purchasing commitments, you can:

- View utilization from the [reservation](/azure/cost-management-billing/reservations/reservation-utilization) or [savings plan](/azure/cost-management-billing/savings-plan/view-utilization) page in the portal.
  - Consider expanding the scope or enabling instance size flexibility (when available) to increase utilization and maximize savings of an existing commitment.
  - [Configure reservation utilization alerts](/azure/cost-management-billing/costs/reservation-utilization-alerts) to notify stakeholders if utilization drops below a desired threshold.
- View showback and chargeback reports for [reservations](/azure/cost-management-billing/reservations/charge-back-usage) and [savings plans](/azure/cost-management-billing/savings-plan/charge-back-costs).

<br>

## Building on the basics

You have commitment discounts in place at this point. As you move beyond the basics, consider the following points:

- Configure commitments to automatically renew for [reservations](/azure/cost-management-billing/reservations/reservation-renew) and [savings plans](/azure/cost-management-billing/savings-plan/renew-savings-plan).
- Calculate cost savings for [reservations](/azure/cost-management-billing/reservations/calculate-ea-reservations-savings) and [savings plans](/azure/cost-management-billing/savings-plan/calculate-ea-savings-plan-savings).
- If you use multiple accounts, clouds, or providers, expand coverage of your commitment discounts efforts to include all accounts.
  - Consider implementing a consistent utilization and coverage monitoring system that covers all accounts.
- Establish a process for centralized purchasing of commitment-based offers, assigning responsibility to a dedicated team or individual.
- Consider programmatically aligning governance policies with commitments to prioritize SKUs and locations that are covered by reservations and aren't fully utilized when deploying new applications.
- If you need to monitor the usage of commitment discounts outside of the Azure portal, consider deploying FinOps hubs, which include a [Rate optimization report](../../toolkit/power-bi/rate-optimization.md). It summarizes existing and potential savings from commitment discounts, like reservations and savings plans.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Rate optimization](https://www.finops.org/framework/capabilities/rate-optimization/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/jO2WlOHmbN8?list=PLUSCToibAswm37b7-VLl3nJ7A4wuGSpCI]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.Framework/featureName/Capabilities.Optimize.Rates)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Data analysis and showback](../understand/reporting.md)
- [Policy and governance](../manage/governance.md)

Related products:

- [Azure Advisor](/azure/advisor/)
- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps workbooks](../../toolkit/workbooks/finops-workbooks-overview.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)

<br>
