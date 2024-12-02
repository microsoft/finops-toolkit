---
layout: default
parent: Power BI
title: Cost summary
nav_order: 20
description: 'Identify top contributors, review changes over time, build a chargeback report, and summarize savings in Power BI.'
permalink: /power-bi/cost-summary
---

<span class="fs-9 d-block mb-4">Cost summary report</span>
Common breakdowns of your cost to identify top contributors, review changes over time, build a chargeback report, and summarize savings.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostSummary.pbix){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](./README.md#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Working with this report](#working-with-this-report)
- [Get started](#get-started)
- [Summary](#summary)
- [Services](#services)
- [Subscriptions](#subscriptions)
- [Resource groups](#resource-groups)
- [Resources](#resources)
- [Regions](#regions)
- [Inventory](#inventory)
- [Prices](#prices)
- [Purchases](#purchases)
- [Charge breakdown](#charge-breakdown)
- [Raw data](#raw-data)
- [DQ](#dq)
- [See also](#see-also)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **Cost summary report** provides a general overview of cost and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Build a chargeback report.
- Summarize cost savings from negotiated and commitment discounts.

You can download the Cost summary report from the [latest release](https://github.com/microsoft/finops-toolkit/releases/latest).

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
- **Total savings** shows how much you're saving compared to list prices.

Note the currency must be single-select to ensure costs in different currencies aren't mixed.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

![Screenshot of the Get started page](https://github.com/microsoft/finops-toolkit/assets/399533/653c4890-f723-4126-8927-3d5d7dd2c588)

<br>

## Summary

The **Summary** page shows the running total (or accumulated cost) for the selected period. This is helpful in determining what your cost trends are.

The page uses the standard layout with cost, negotiated discount savings, and commitment discount savings in the chart and the subscription hierarchy with resource groups and resources in the table.

![Screenshot of the Summary page](https://github.com/microsoft/finops-toolkit/assets/399533/68ed0586-0c68-4989-8d1e-65db618c4e71)

<br>

## Services

The **Services** page offers a breakdown of cost by service. This is useful for determining how service usage changes over time at a high level, usually across multiple subscriptions or the entire billing account.

The page uses the standard layout with a breakdown of services (meter category) in the chart and table. The table has a further breakdown by tier (meter subcategory), meter, and product.

![Screenshot of the Services page](https://github.com/microsoft/finops-toolkit/assets/399533/424aa533-2601-4301-bc31-a94fc7cd6235)

<br>

## Subscriptions

The **Subscriptions** page includes a breakdown of cost by subscription. This is useful for building a chargeback report and determining which departments/teams/environments (depending on how you use subscriptions) are accruing the most cost.

The page uses the standard layout with a breakdown of subscriptions in the chart and table. The table has a further breakdown by resource group and resource.

![Screenshot of the Subscriptions page](https://github.com/microsoft/finops-toolkit/assets/399533/b7fb0e76-30e7-4717-a476-4af757056169)

<br>

## Resource groups

The **Resource groups** page includes a breakdown of cost by resource group. This is useful for building a chargeback report and determining which teams/projects (depending on how you use resource groups) are accruing the most cost.

The page uses the standard layout with a breakdown of resource groups in the chart and table. The table has a further breakdown by resource.

![Screenshot of the Resource groups page](https://github.com/microsoft/finops-toolkit/assets/399533/b857c11c-1652-4550-a709-e55ddc9f9ef0)

<br>

## Resources

The **Resources** page includes a breakdown of cost by resource. This is useful for determining which resources are accruing the most cost.

The page uses the standard layout with a breakdown of resources in the chart and table. Instead of a hierarchy, The table includes columns about the resource location, resource group, subscription, and tags.

![Screenshot of the Resources page](https://github.com/microsoft/finops-toolkit/assets/399533/5f789571-f940-463f-9931-3f191737c362)

<br>

## Regions

The **Regions** page includes a breakdown of cost by region with a map showing the cost from each region. The map shows approximate locations and is not exact.

<blockquote class="note" markdown="1">
   _Regions in the Cost Management FOCUS dataset include additional data cleansing for consistency with Azure regions and may not match the exact values in actual and amortized datasets._
</blockquote>

![Screenshot of the Regions page](https://github.com/microsoft/finops-toolkit/assets/399533/dd95301a-4227-46d5-8a62-e31b812dee2a)

<br>

## Inventory

The **Inventory** page includes a list of resource types with the count, total cost, and cost per resource for each type.

![Screenshot of the Inventory page](https://github.com/microsoft/finops-toolkit/assets/399533/a9a9b252-f306-49f9-842c-e3f196638ed6)

<br>

## Prices

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

The **Prices** page shows the prices for all products that were used during the period.

The chart shows a summary of the meters that were used the most.

![Screenshot of the Prices page](https://github.com/microsoft/finops-toolkit/assets/399533/5ef75a7c-43cc-4ac4-b977-982ab15ad55c)

<br>

## Purchases

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

The **Purchases** page shows a list of products that were purchased during the period.

> ![Screenshot of the Purchases page](https://github.com/microsoft/finops-toolkit/assets/399533/5a3320cc-bb0d-498b-8edc-3d1a56c868dd)

<br>

## Charge breakdown

The **Charge breakdown** page shows a breakdown of all charges using the following information hierarchy:

1. ChargeCategory
2. ChargeSubcategory
3. PricingCategory
4. x_PricingSubcategory
5. ServiceCategory
6. ServiceName
7. x_SkuMeterCategory
8. x_SkuMeterSubcategory
9. x_SkuMeterName
10. SubAccountName
11. x_ResourceGroupName
12. ResourceName

> ![Screenshot of the Charge breakdown page](https://github.com/microsoft/finops-toolkit/assets/399533/034e6684-37ed-405f-a64b-50084335982e)

<br>

## Raw data

The **Raw data** page shows a table with most columns to help you explore FOCUS columns. This page is only available in storage-based reports. If using Data Explorer, please use the [Data Explorer query console](https://dataexplorer.azure.com).

> ![Screenshot of the Raw data page](https://github.com/microsoft/finops-toolkit/assets/399533/3c74bceb-202f-4830-99f6-f02d1e831340)

<br>

## DQ

The **Data quality** page is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions. This page is only available in storage-based reports. If using Data Explorer, please use the [Data Explorer query console](https://dataexplorer.azure.com).

> ![Screenshot of the Data quality page](https://github.com/microsoft/finops-toolkit/assets/399533/e4d52402-5b3c-48ea-816c-934b29b8fdc6)

<br>

## See also

- [About FOCUS](../../_docs/focus/README.md)
- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
