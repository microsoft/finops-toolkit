---
title: Cost summary report
description: Learn about the Cost Summary Report in Power BI to identify top cost contributors, review cost changes over time, and summarize savings.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Cost summary report so that I can understand my costs.
---

<!-- markdownlint-disable-next-line MD025 -->
# Cost summary report

The **Cost summary report** provides a general overview of cost and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Build a chargeback report.
- Summarize cost savings from negotiated and commitment discounts.

You can download the Cost summary report from the [latest release](https://github.com/microsoft/finops-toolkit/releases/latest).

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (for example, reservation and savings plan)
- Service (for example, Virtual machines and SQL database)
- Currency

A few common KPIs you fill find in this report are:

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Total savings** shows how much you're saving compared to list prices.

The currency must be single-select to ensure costs in different currencies aren't mixed.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with more links to learn more.

:::image type="content" source="./media/cost-summary/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows a basic introduction to the report." lightbox="./media/cost-summary/get-started.png" :::

<br>

## Summary

The **Summary** page shows the running total (or accumulated cost) for the selected period. This page is helpful in determining what your cost trends are.

The page uses the standard layout with cost, negotiated discount savings, and commitment discount savings in the chart. The subscription hierarchy with resource groups and resources are shown in the table.

:::image type="content" source="./media/cost-summary/summary.png" border="true" alt-text="Screenshot of the Summary page that shows a running total." lightbox="./media/cost-summary/summary.png" :::

<br>

## Services

The **Services** page offers a breakdown of cost by service. This page is useful for determining how service usage changes over time at a high level - usually across multiple subscriptions or the entire billing account.

The page uses the standard layout with a breakdown of services (meter category) in the chart and table. The table has a further breakdown by tier (meter subcategory), meter, and product.

:::image type="content" source="./media/cost-summary/services.png" border="true" alt-text="Screenshot of the Services page that shows a breakdown of cost by service." lightbox="./media/cost-summary/services.png" :::

<br>

## Subscriptions

The **Subscriptions** page includes a breakdown of cost by subscription. This page is useful for building a chargeback report and determining which departments/teams/environments, depending on how you use subscriptions, are accruing the most cost.

The page uses the standard layout with a breakdown of subscriptions in the chart and table. The table has a further breakdown by resource group and resource.

:::image type="content" source="./media/cost-summary/subscriptions.png" border="true" alt-text="Screenshot of the Subscriptions page that shows a breakdown of cost by subscription." lightbox="./media/cost-summary/subscriptions.png" :::

<br>

## Resource groups

The **Resource groups** page includes a breakdown of cost by resource group. This page is useful for building a chargeback report and determining which teams/projects, depending on how you use resource groups, are accruing the most cost.

The page uses the standard layout with a breakdown of resource groups in the chart and table. The table has a further breakdown by resource.

:::image type="content" source="./media/cost-summary/resource-groups.png" border="true" alt-text="Screenshot of the Resource groups page that shows a breakdown of cost by resource group." lightbox="./media/cost-summary/resource-groups.png" :::

<br>

## Resources

The **Resources** page includes a breakdown of cost by resource. This page is useful for determining which resources are accruing the most cost.

The page uses the standard layout with a breakdown of resources in the chart and table. Instead of a hierarchy, The table includes columns about the resource location, resource group, subscription, and tags.

:::image type="content" source="./media/cost-summary/resources.png" border="true" alt-text="Screenshot of the Resources page that shows a breakdown of cost by resource." lightbox="./media/cost-summary/resources.png" :::

<br>

## Regions

The **Regions** page includes a breakdown of cost by region with a map showing the cost from each region. The map shows approximate locations and isn't exact.

> [!NOTE]
> Regions in the Cost Management FOCUS dataset include additional data cleansing for consistency with Azure regions and may not match the exact values in actual and amortized datasets.

:::image type="content" source="./media/cost-summary/regions.png" border="true" alt-text="Screenshot of the Regions page that shows a breakdown of cost by region." lightbox="./media/cost-summary/regions.png" :::

<br>

## Inventory

The **Inventory** page includes a list of resource types with the count, total cost, and cost per resource for each type.

:::image type="content" source="./media/cost-summary/inventory.png" border="true" alt-text="Screenshot of the Inventory page that shows a list of resource types." lightbox="./media/cost-summary/inventory.png" :::

<br>

## Commitments

The **Commitments** page serves the following three primary purposes:

<!-- NOTE: This page is duplicated in the rate-optimization.md. Please keep both updated at the same time. -->

- Determine if there are any under-utilized commitments.
- Facilitate chargeback at a subscription, resource group, or resource level.
- Summarize cost savings obtained from commitment discounts.

This page uses the standard layout with a breakdown of commitment discounts in the chart and table.

In addition to cost and savings KPIs, there's also a utilization KPI for the commitment discounts amount that were utilized during the period. Low utilization results in lost savings potential, so this number is one of the most important KPIs on the page.

The chart breaks down the cost of used (utilized) vs. unused charges. The commitment type (for example, reservation and savings plan) splits unused charges.

The table shows resource usage against commitment discounts with columns for resource name, resource group, subscription, and commitment. Use the table for chargeback and savings calculations.

This page filters usage down to only show charges related to commitment discounts. That means the total cost on the Commitments page doesn't match other pages, which aren't filtered by default.

:::image type="content" source="./media/cost-summary/commitment-discounts.png" border="true" alt-text="Screenshot of the Commitment discounts page that shows a breakdown of commitment discounts." lightbox="./media/cost-summary/commitment-discounts.png" :::

<br>

## Hybrid Benefit

The **Hybrid Benefit** page shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).

KPIs show how many VMs are using Azure Hybrid Benefit and how many vCPUs are used.

There are three charts on the page:

- SKU names and number of VMs currently using fewer than 8 vCPUs. They're under-utilizing AHB.
- SKU names and number of VMs with 8+ vCPUs that aren't currently using AHB.
- Daily breakdown of AHB and non-AHB usage (excluding VMs where AHB isn't supported).

The table shows a list of VMs that are currently using or could be using AHB. It shows their vCPU count, AHB vCPU count, resource group, subscription, cost, and quantity.

:::image type="content" source="./media/cost-summary/hybrid-benefit.png" border="true" alt-text="Screenshot of the Hybrid Benefit page that shows AHB usage for VMs." lightbox="./media/cost-summary/hybrid-benefit.png" :::

<br>

## Prices

The **Prices** page shows the prices for all products used during the period.

<!-- NOTE: There is a similar page in the cost-summary.md file. They are not identical. Please keep both updated at the same time. -->

The chart shows a summary of the meters that were most used.

:::image type="content" source="./media/cost-summary/prices.png" border="true" alt-text="Screenshot of the Prices page that shows prices for all products." lightbox="./media/cost-summary/prices.png" :::

<br>

## Purchases

The **Purchases** page shows a list of products that were purchased during the period.

:::image type="content" source="./media/cost-summary/purchases.png" border="true" alt-text="Screenshot of the Purchases page that shows a list of purchased products." lightbox="./media/cost-summary/purchases.png" :::

<br>

## Charge breakdown

The **Charge breakdown** page shows a breakdown of all charges using the following information hierarchy:

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

:::image type="content" source="./media/cost-summary/charge-breakdown.png" border="true" alt-text="Screenshot of the Charge breakdown page that shows a breakdown of all charges." lightbox="./media/cost-summary/charge-breakdown.png" :::

<br>

## Raw data

The **Raw data** page shows a table with most columns to help you explore FOCUS columns.

:::image type="content" source="./media/cost-summary/raw-data.png" border="true" alt-text="Screenshot of the Raw data page that shows a table with most FOCUS columns." lightbox="./media/cost-summary/raw-data.png" :::

<br>

## Data quality

The **Data quality** page is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions.

:::image type="content" source="./media/cost-summary/data-quality.png" border="true" alt-text="Screenshot of the Data quality page that shows several data categories." lightbox="./media/cost-summary/data-quality.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/ideas)

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)

<!-- TODO: Uncomment when files are added
- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)
-->

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>