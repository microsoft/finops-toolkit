---
title: Cost Management connector report
description: 'Power BI report for the Cost Management connector.'
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Cost Management connector report

The **Cost Management connector** report provides a general overview of cost, commitment discounts, and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments (aka utilization).
- Identify opportunity to save with more commitment discounts (aka coverage).
- Determine which resources used commitment discounts (aka chargeback).
- Summarize cost savings from negotiated and commitment discounts.

You can download the Cost Management connector report from the [latest release](https://github.com/microsoft/finops-toolkit/releases/latest).

> [!WARNING]
> The Cost Management connector uses an older API that does not include all details about savings plans. You will see unused savings plan charges that will not have identifiable usage for due to this gap. This will skew numbers, if you have savings plans. Consider using [FinOps hubs](../hubs/finops-hubs-overview.md) to use savings plans.

<br>

> [!IMPORTANT]
> The Cost Management connector is in maintenance mode and no longer being updated. Cost Management support for Power BI is moving to utilize exports instead of the connector. With native support for [FOCUS](../../focus/what-is-focus.md) and the deprecation of the connector, the Cost Management connector report is a copy of the [Cost summary](./cost-summary.md) and [Commitment discounts](./rate-optimization.md) reports from the FinOps toolkit 0.2 release for backwards compatibility, but will not be maintained over time.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (e.g., reservation, savings plan)
- Service (e.g., Virtual machines, SQL database)
- Currency

A few common KPIs you fill find in this report are:

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Utilization** shows the percentage of your current commitments were used during the period.
- **Total savings** shows how much you're saving compared to list prices.
- **Commitment savings** shows how much you're saving with commitment discounts.
  > [!IMPORTANT]
  > Microsoft Cost Management does not include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this.
  
<br>

## Pages

This report includes the following pages:

- **Get started** includes a basic introduction to the report with additional links to learn more.
- **Summary** shows the running total (or accumulated cost) for the selected period. This is helpful in determining what your cost trends are.
- **Services** offers a breakdown of cost by service. This is useful for determining how service usage changes over time at a high level, usually across multiple subscriptions or the entire billing account.
- **Subscriptions** includes a breakdown of cost by subscription. This is useful for building a chargeback report and determining which departments/teams/environments (depending on how you use subscriptions) are accruing the most cost.
- **Resource groups** includes a breakdown of cost by resource group. This is useful for building a chargeback report and determining which teams/projects (depending on how you use resource groups) are accruing the most cost.
- **Resources** includes a breakdown of cost by resource. This is useful for determining which resources are accruing the most cost.
- **Regions** includes a breakdown of cost by region with a map showing the cost from each region. The map shows approximate locations and is not exact.
  > [!NOTE]
  > The Cost Management connector report performs additional data cleansing for the Region column to better align with Azure regions and may not match values you see in actual and amortized datasets in Cost Management.
  - **Charge breakdown** shows a breakdown of all charges using the following information hierarchy:
- **Prices** shows the prices for all products that were used during the period.
- **Hybrid Benefit** shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).
- **Purchases** shows a list of products that were purchased during the period.
- **Commitments** serves 3 primary purposes:
  1. Determine if there are any under-utilized commitments.
  2. Facilitate chargeback at a subscription, resource group, or resource level.
  3. Summarize cost savings obtained from commitment discounts.
- **Commitment savings** summarizes cost savings obtained from commitment discounts. Commitments are grouped by program and service.
  > [!WARNING]
  > Microsoft Cost Management does not include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this.
  - **Commitment chargeback** helps facilitate chargeback at a subscription, resource group, or resource level. Use the table for chargeback.
- There are two **Reservation coverage** pages that help you identify any places where you could potentially save even more based on your historical usage patterns with virtual machine reservations within a single subscription or shared across all subscriptions.
- **Raw data** shows a table with most columns to help you explore FOCUS columns.
- **Data quality** is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions.

<br>

## Known issues

1. `ChargeSubcategory` for uncommitted usage shows "On-Demand". This value should be null. (Applies to all Cost Management data.)
2. `InvoiceIssuerName` does not account for indirect EA and MCA partners. The value will show as "Microsoft". (Applies to all Cost Management data.)
3. `ListUnitPrice` and `ListCost` can be 0 when the data is not available. (Applies to all Cost Management data.)
4. `PricingUnit` and `UsageUnit` both include the pricing block size. Exports (and FinOps hubs) separate the block size into `x_PricingBlockSize`.
5. `SkuPriceId` is not set due to the connector not having the data to populate the value.
6. `ServiceName` is empty for unused savings plan records (`ChargeSubcategory == "Unused Commitment" and CommitmentDiscountType == "Savings Plan"`).
7. Savings plan usage is not identifiable in the connector. Please use [FinOps hubs](../hubs/finops-hubs-overview.md) to report on savings plans.

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, please start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you've found a bug, please [create an issue](https://aka.ms/ftk/idea).

If you have feedback about FOCUS, please [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make this the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

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
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [FinOps toolkit open data](../open-data.md)

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea)

<br>
