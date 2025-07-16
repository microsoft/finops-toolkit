---
title: Cost Management connector report
description: Understand the Power BI report for the Cost Management connector, including cost overviews, commitment discounts, and savings insights.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand the Power BI report for the Cost Management connector so that I can use it.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Cost Management connector report

The **Cost Management connector** report provides a general overview of cost, commitment discounts, and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments, also called utilization.
- Identify opportunity to save with more commitment discounts, also called coverage.
- Determine which resources used commitment discounts, also called chargeback.
- Summarize cost savings from negotiated and commitment discounts.

> [!div class="nextstepaction"]
> [Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostManagementConnector.pbix)
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20and%20optimize%20cost%20and%20usage%20with%20the%20FinOps%20toolkit%20Cost%20Management%20connector%20report%3F/cvaQuestion/How%20valuable%20is%20the%20Cost%20Management%20connector%20report%3F/surveyId/FTK/bladeName/PowerBI.CMConnector/featureName/Documentation)

<br>

> [!WARNING]
> The Cost Management connector uses an older API that doesn't include all details about savings plans. You'll see unused savings plan charges that don't have identifiable usage for due to this gap. This issue  skews numbers, if you have savings plans. Consider using [FinOps hubs](../hubs/finops-hubs-overview.md) to use savings plans.

<br>

> [!IMPORTANT]
> The Cost Management connector is in maintenance mode and no longer being updated. Cost Management support for Power BI is moving to use exports instead of the connector. With native support for [FOCUS](../../focus/what-is-focus.md) and the deprecation of the connector, the Cost Management connector report is a copy of the [Cost summary](./cost-summary.md) and [Commitment discounts](./rate-optimization.md) reports from the FinOps toolkit 0.2 release for backwards compatibility. However, support for the connector will end.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (for example, reservation, savings plan)
- Service (for example, Virtual machines, SQL database)
- Currency

A few common KPIs you fill find in this report are:

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Utilization** shows the percentage of your current commitments were used during the period.
- **Total savings** shows how much you're saving compared to list prices.
- **Commitment savings** shows how much you're saving with commitment discounts.
  > [!IMPORTANT]
  > Microsoft Cost Management doesn't include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. File a support request and speak to your field rep to escalate this issue.
  
<br>

## Pages

This report includes the following pages:

- **Get started** includes a basic introduction to the report with links to learn more.
- **Summary** shows the running total (or accumulated cost) for the selected period. It's helpful in determining what your cost trends are.
- **Services** offers a breakdown of cost by service. It's useful for determining how service usage changes over time at a high level, which is usually across multiple subscriptions or the entire billing account.
- **Subscriptions** includes a breakdown of cost by subscription. It's useful for building a chargeback report and determining which departments/teams/environments (depending on how you use subscriptions) are accruing the most cost.
- **Resource groups** includes a breakdown of cost by resource group. It's useful for building a chargeback report and determining which teams/projects (depending on how you use resource groups) are accruing the most cost.
- **Resources** includes a breakdown of cost by resource. It's useful for determining which resources are accruing the most cost.
- **Regions** includes a breakdown of cost by region with a map showing the cost from each region. The map shows approximate locations and isn't exact.
  > [!NOTE]
  > The Cost Management connector report performs additional data cleansing for the Region column to better align with Azure regions and may not match values you see in actual and amortized datasets in Cost Management.
- **Charge breakdown** shows a breakdown of all charges using the following information hierarchy:
  - ChargeCategory
  - ChargeSubcategory
  - PricingCategory
  - x_PricingSubcategory
  - ServiceCategory
  - ServiceName
  - x_SkuMeterCategory
  - x_SkuMeterSubcategory
  - x_SkuMeterName
  - SubAccountName
  - x_ResourceGroupName
  - ResourceName
- **Prices** shows the prices for all products that were used during the period.
- **Hybrid Benefit** shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).
- **Purchases** shows a list of products that were purchased during the period.
- **Commitments** serves 3 primary purposes:
  - Determine if there are any under-utilized commitments.
  - Facilitate chargeback at a subscription, resource group, or resource level.
  - Summarize cost savings obtained from commitment discounts.
- **Commitment savings** summarizes cost savings obtained from commitment discounts. Commitments get grouped by program and service.
  > [!WARNING]
  > Microsoft Cost Management doesn't include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this issue.
- **Commitment chargeback** helps facilitate chargeback at a subscription, resource group, or resource level. Use the table for chargeback.
- There are two **Reservation coverage** pages that help you identify any places where you could potentially save even more based on your historical usage patterns with virtual machine reservations within a single subscription or shared across all subscriptions.
- **Raw data** shows a table with most columns to help you explore FOCUS columns.
- **Data quality** is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions.

<br>

## Known issues

Here's a list of known issues with the Cost Management connector report:

- `ChargeSubcategory` for uncommitted usage shows **On-Demand**. This value should be null. (Applies to all Cost Management data.)
- `InvoiceIssuerName` doesn't account for indirect Enterprise Agreement and Microsoft Customer Agreement partners. The value appears as **Microsoft**. (Applies to all Cost Management data.)
- `ListUnitPrice` and `ListCost` can be 0 when the data isn't available. (Applies to all Cost Management data.)
- `PricingUnit` and `UsageUnit` both include the pricing block size. Exports (and FinOps hubs) separate the block size into `x_PricingBlockSize`.
- `SkuPriceId` isn't set due to the connector not having the data to populate the value.
- `ServiceName` is empty for unused savings plan records (`ChargeSubcategory == "Unused Commitment" and CommitmentDiscountType == "Savings Plan"`).
- Savings plan usage isn't identifiable in the connector. Use [FinOps hubs](../hubs/finops-hubs-overview.md) to report on savings plans.

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you think you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [How to convert Cost Management data to FOCUS](../../focus/convert.md)
- [How to update existing reports to FOCUS](../../focus/mapping.md)

<!-- TODO: Bring in after these resources are moved
- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)
-->

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
