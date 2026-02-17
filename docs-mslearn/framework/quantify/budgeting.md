---
title: Budgeting
description: This article helps you understand the budgeting capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the budgeting capability so that I can implement it in the Microsoft Cloud.
---

# Budgeting

This article helps you understand the budgeting capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Budgeting refers to the process of overseeing and tracking financial plans and limits over a given period to effectively manage and control spending.**

Analyze historical usage and cost trends and adjust for future plans to estimate monthly, quarterly, and yearly costs that are realistic and achievable. Repeat for each level in the organization for a complete picture of organizational budgets.

Configure alerting and automated actions to notify stakeholders and protect against budget overages. Investigate unexpected variance to budget and take appropriate actions. Review and adjust budgets regularly to ensure they remain accurate and reflect any changes in the organization's financial situation.

Effective budgeting helps ensure organizations operate within their means and are able to achieve financial goals. Unexpected costs can affect external business decisions and initiatives that could have widespread influence.

<br>

## Getting started

When you first start managing cost in the cloud, you might not have your financial budgets mapped to every subscription and resource group. You might not even have the budget mapped to your billing account yet. It's okay. Start by configuring cost alerts. The exact amount you use isn't as important as having _something_ to let you know when costs are escalating.

- Start by [creating a monthly budget in Cost Management](/azure/cost-management-billing/costs/tutorial-acm-create-budgets) at the primary scope you manage, whether that's a billing account, management group, subscription, or resource group.
  - If you're not sure where to start, set your budget amount based on the cost of the previous months. You can also set it to be explicitly higher than what you intend, to catch an exceedingly high jump in costs, if you're not concerned with smaller moves. No matter what you set, you can always change it later.
  - If you do want to provide a more realistic alert threshold, see [Estimate the initial cost of your cloud project](/azure/well-architected/cost/design-initial-estimate).
  - Configure one or more alerts on actual or forecast cost to be sent to stakeholders.
  - If you need to proactively stop billing before costs exceed a certain threshold on a subscription or resource group, [execute an automated action when alerts are triggered](/azure/cost-management-billing/manage/cost-management-budget-scenario).
- If you have concerns about rollover costs from one month to the next as they accumulate for the quarter or year, create quarterly and yearly budgets.
- If you're not concerned about "overage," but would still like to stay informed about costs, [save a view in Cost analysis](/azure/cost-management-billing/costs/save-share-views), and [subscribe to scheduled alerts](/azure/cost-management-billing/costs/save-share-views#subscribe-to-scheduled-alerts). Then share a chart of the cost trends to stakeholders. It can help you drive accountability and awareness as costs change over time before you go over budget.
- Consider [subscribing to anomaly alerts](/azure/cost-management-billing/understand/analyze-unexpected-charges#create-an-anomaly-alert) for each subscription to ensure everyone is aware of anomalies as they're identified.
- Repeat these steps to configure alerts for the stakeholders of each scope and application you want to be monitored for maximum visibility and accountability.
- Consider reviewing costs against your budget periodically to ensure costs remain on track with your expectations.

<br>

## Building on the basics

So far, you defined granular and targeted cost alerts for each scope and application and ideally review your cost as a KPI with all stakeholders at regular meetings. Consider the following points to further refine your budget management process:

- Refine the budget granularity to enable more targeted oversight.
- Encourage all teams to take ownership of their budget allocations and expenses.
  - Educate them about the consequence of their actions on the overall budget and empower them to make informed decisions.
- Streamline the process for making budget adjustments, ensuring teams easily understand and follow it.
- [Automate budget creation](/azure/cost-management-billing/automate/automate-budget-creation) with new subscriptions and resource groups.
- If not done earlier, use automation tools like Azure Logic Apps or Alerts to [execute automated actions when budget alerts are triggered](/azure/cost-management-billing/manage/cost-management-budget-scenario). Tools can be especially helpful on test subscriptions.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see to the [Budgeting](https://www.finops.org/framework/capabilities/budgeting) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/exxxlTwqzrs?list=PLUSCToibAswnjB7fYRA02ePxySkpDex6q]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.Framework/featureName/Capabilities.Quantify.Budgeting)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Forecasting](./forecasting.md)
- [Onboarding workloads](../manage/onboarding.md)
- [Chargeback and finance integration](../manage/invoicing-chargeback.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)

<br>
