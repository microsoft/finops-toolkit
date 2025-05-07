---
title: Forecasting
description: This article helps you understand the forecasting capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the forecasting capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Forecasting

This article helps you understand the forecasting capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Forecasting involves analyzing historical trends and future plans to predict costs, understand the impact on current budgets, and influence future budgets.**

Analyze historical usage and cost trends to identify any patterns you expect to change. Augment that with future plans to generate an informed forecast.

Periodically review forecasts against the current budgets to identify risk and initiate remediation efforts. Establish a plan to balance budgets across teams and departments and factor the learnings into future budgets.

With an accurate, detailed forecast, organizations are better prepared to adapt to future change.

<br>

## Before you begin

Before you can effectively forecast future usage and costs, you need to familiarize yourself with [how you're charged for the services you use](https://azure.microsoft.com/pricing#product-pricing).

Understanding how changes to your usage patterns affect future costs is informed with:

- Understanding the factors that contribute to costs (for example, compute, storage, networking, and data transfer)
- How your usage of a service aligns with the various pricing models (for example, pay-as-you-go, reservations, and Azure Hybrid Benefit)

<br>

## Getting started

When you first start managing cost in the cloud, you use the native Cost analysis experience in the portal.

The simplest option is to [use Cost analysis to project future costs](/azure/cost-management-billing/costs/cost-analysis-common-uses#view-forecast-costs.md) using the Daily costs or Accumulated costs view. If you have consistent usage with little to no anomalies or large variations, it might be all you need.

If you do see anomalies or large (possibly expected) variations in costs, you might want to customize the view to build a more accurate forecast. To do so, you need to analyze the data and filter out anything that might skew the results.

- Use Cost analysis to analyze historical trends and identify abnormalities.
  - Before you start, determine if you're interested in your costs as they're billed or if you want to forecast the effective costs after accounting for commitment discounts. If you want the effective cost, [change the view to use amortized cost](/azure/cost-management-billing/costs/customize-cost-analysis-views#switch-between-actual-and-amortized-cost).
  - Start with the Daily costs view, then change the date range to look back as far as you're interested in looking forward. For instance, if you want to predict the next 12 months, then set the date range to the last 12 months.
  - Filter out all purchases (`Charge type = Purchase`). Make a note of them as you need to forecast them separately.
  - Group costs to identify new and old (deleted) subscriptions, resource groups, and resources.
    - If you see any deleted items, filter them out.
    - If you see any that are new, make note of them and then filter them out. You forecast them separately. Consider saving your view under a new name as one way to "remember" them for later.
    - If you have future dates included in your view, you might notice the forecast is starting to level out. It happens because the abnormalities are no longer being factored into the algorithm.
  - If you see any large spikes or dips, group the data by one of the [grouping options](/azure/cost-management-billing/costs/group-filter) to identify what the cause was.
    - Try different options until you discover the cause using the same approach as you would in [finding unexpected changes in cost](/azure/cost-management-billing/understand/analyze-unexpected-charges#manually-find-unexpected-cost-changes).
    - If you want to find the exact change that caused the cost spike (or dip), use tools like [Azure Monitor](/azure/azure-monitor/overview) or [Resource Graph](/azure/governance/resource-graph/how-to/get-resource-changes) in a separate window or browser tab.
    - If the change was a segregated charge and shouldn't be factored into the forecast, filter it out. Be careful not to filter out other costs as it will skew the forecast. If necessary, start by forecasting a smaller scope to minimize risk of filtering more and repeat the process per scope.
    - If the change is in a scope that shouldn't get filtered out, make note of that scope and then filter it out. You forecast them separately.
  - Consider filtering out any subscriptions, resource groups, or resources that were reconfigured during the period and might not reflect an accurate picture of future costs. Make note of them so you can forecast them separately.
  - At this point, you should have a fairly clean picture of consistent costs.
- Change the date range to look at the future period. For example, the next 12 months.
  - If interested in the total accumulated costs for the period, change the granularity to `Accumulated`.
- Make note of the forecast, then repeat this process for each of the datasets that were filtered out.
  - You might need to shorten the future date range to ensure the historical anomaly or resource change doesn't affect the forecast. If the forecast is affected, manually project the future costs based on the daily or monthly run rate.
- Next factor in any changes you plan to make to your environment.
  - This part can be a little tricky and needs to be handled separately per workload.
  - Start by filtering down to only the workload that is changing. If the planned change only impacts a single meter, like the number of uptime hours a virtual machine (VM) might have or total data stored in a storage account, then filter down to that meter.
  - Use the [pricing calculator](https://azure.microsoft.com/pricing/calculator) to determine the difference between what you have today and what you intend to have. Then, take the difference and manually apply that to your cost projections for the intended period.
  - Repeat the process for each of the expected changes.

Whichever approach worked best for you, compare your forecast with your current budget to see where you're at today. If you filtered data down to a smaller scope or workload:

- To track that specific scope or workload, consider [creating a budget in Cost Management](/azure/cost-management-billing/costs/tutorial-acm-create-budgets). Specify filters and set alerts for both actual and forecast costs.
- [Save a view in Cost analysis](/azure/cost-management-billing/costs/save-share-views) to monitor that cost and budget over time.
- Consider [subscribing to scheduled alerts](/azure/cost-management-billing/costs/save-share-views#subscribe-to-scheduled-alerts) for this view to share a chart of the cost trends with stakeholders. It can help you drive accountability and awareness as costs change over time before you go over budget.
- Consider [subscribing to anomaly alerts](/azure/cost-management-billing/understand/analyze-unexpected-charges#create-an-anomaly-alert) for each subscription to ensure everyone is aware of anomalies as they're identified.

Consider reviewing forecasts monthly or quarterly to ensure you remain on track with your expectations.

<br>

## Building on the basics

At this point, you have a manual process for generating a forecast. As you move beyond the basics, consider the following points:

- Expand coverage of your forecast calculations to include all costs.
- If ingesting cost data into a separate system, use or introduce a forecast capability that spans all of your cost data. Consider using [Automated Machine Learning (AutoML)](/azure/machine-learning/how-to-auto-train-forecast) to minimize your effort.
- Integrate forecast projections into internal budgeting tools.
- Automate cost variance detection and mitigation.
  - Implement automated processes to identify and address cost variances in real-time.
  - Establish workflows or mechanisms to investigate and mitigate the variances promptly, ensuring cost control and alignment with forecasted budgets.
- Build custom forecast and budget reporting against actual cost that's available to all stakeholders.
- If you're [measuring unit costs](./unit-economics.md), consider establishing a forecast for your unit costs to better understand whether you're trending towards higher or lower cost vs. revenue.
- Establish and automate KPIs, such as:
  - Cost vs. forecast to measure the accuracy of the forecast algorithm.
    - It can only be performed when there are expected usage patterns and no anomalies.
    - Target \<12% variance when there are no anomalies.
  - Cost vs. forecast to measure whether costs were on target.
    - It gets evaluated whether there are anomalies or not to measure the performance of the cloud solution.
    - Target 12-20% variance where \<12% would be an optimized team, project, or workload.
  - Number of unexpected anomalies during the period that caused cost to go outside the expected range.
  - Time to react to forecast alerts.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Forecasting capability](https://www.finops.org/framework/capabilities/forecasting) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/bmbQbMBz9FI?list=PLUSCToibAswkduSzBonLR4Btu4ogHNDSv&pp=iAQB]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.Framework/featureName/Capabilities.Quantify.Forecasting)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Budgeting](./budgeting.md)
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
- [FinOps toolkit bicep modules](../../toolkit/bicep-registry/modules.md)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)
- [Cloud Adoption Framework](/azure/cloud-adoption-framework/)

<br>
