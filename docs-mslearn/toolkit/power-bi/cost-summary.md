---
title: FinOps toolkit Cost summary report
description: Learn about the Cost Summary Report in Power BI to identify top cost contributors, review cost changes over time, and summarize savings.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Cost summary report so that I can understand my costs.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Cost summary report

The **Cost summary report** provides a general overview of cost and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Build a chargeback report.

> [!div class="nextstepaction"]
> [Download for KQL](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
> [!div class="nextstepaction"]
> [Download for storage](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20and%20optimize%20cost%20and%20usage%20with%20the%20FinOps%20toolkit%20Cost%20summary%20report%3F/cvaQuestion/How%20valuable%20is%20the%20Cost%20summary%20report%3F/surveyId/FTK0.10/bladeName/PowerBI.CostSummary/featureName/Documentation)

Power BI reports are provided as template (.PBIT) files. Template files are not preconfigured and do not include sample data. When you first open a Power BI template, you will be prompted to specify report parameters, then authenticate with each data source to view your data. To access visuals and queries without loading data, select Edit in the Load menu button.

This article contains images showing example data. Any price data is for test purposes only.

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

For instructions on how to connect this report to your data, including details about supported parameters, select the **Connect your data** button. Hold <kbd>Ctrl</kbd> when clicking the button in Power BI Desktop. If you need assistance, select the **Get help** button.

:::image type="content" source="./media/cost-summary/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows a basic introduction to the report." lightbox="./media/cost-summary/get-started.png" :::

<br>

## Summary

The **Summary** page shows the running total (or accumulated cost) for the selected period. This page is helpful in determining what your cost trends are.

The page uses the standard layout with cost, negotiated discount savings, and commitment discount savings in the chart. The subscription hierarchy with resource groups and resources are shown in the table.

:::image type="content" source="./media/cost-summary/summary.png" border="true" alt-text="Screenshot of the Summary page that shows a running total." lightbox="./media/cost-summary/summary.png" :::

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

## Services

The **Services** page offers a breakdown of cost by service. This page is useful for determining how service usage changes over time at a high level - usually across multiple subscriptions or the entire billing account.

The page uses the standard layout with a breakdown of services (meter category) in the chart and table. The table has a further breakdown by tier (meter subcategory), meter, and product.

:::image type="content" source="./media/cost-summary/services.png" border="true" alt-text="Screenshot of the Services page that shows a breakdown of cost by service." lightbox="./media/cost-summary/services.png" :::

<br>

## Usage analysis

The **Usage analysis** page shows the consumed quantity compared to cost for a specific unit (for instance, hours). You can further filter the SKUs by meter hierarchy to analyze specific usage trends over time.

This page requires a single unit filter to ensure quantity numbers are comparable. Quantities of different units cannot be added together correctly. If you find unit is not set as you expect, submit a [change request](https://aka.ms/ftk/ideas).

:::image type="content" source="./media/cost-summary/usage-analysis.png" border="true" alt-text="Screenshot of the Usage analysis page that shows a breakdown of usage and cost over time." lightbox="./media/cost-summary/usage-analysis.png" :::

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

## Prices

The **Prices** page shows the prices for all products used during the period.

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

The chart shows a summary of the meters that were most used.

:::image type="content" source="./media/cost-summary/prices.png" border="true" alt-text="Screenshot of the Prices page that shows prices for all products." lightbox="./media/cost-summary/prices.png" :::

<br>

## Purchases

The **Purchases** page shows a list of products that were purchased during the period.

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

:::image type="content" source="./media/cost-summary/purchases.png" border="true" alt-text="Screenshot of the Purchases page that shows a list of purchased products." lightbox="./media/cost-summary/purchases.png" :::

<br>

## Data quality

The **Data quality** page is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions. This page is only available in storage-based reports. If using Data Explorer, use the [Data Explorer query console](https://dataexplorer.azure.com).

:::image type="content" source="./media/cost-summary/data-quality.png" border="true" alt-text="Screenshot of the Data quality page that shows several data categories." lightbox="./media/cost-summary/data-quality.png" :::

<br>

## Tags example

The **Tags example** page provides a set of visuals to demonstrate promoted tags in Power BI reports. Promoted tags are configured directly in the **Costs** query in Power BI.

:::image type="content" source="./media/cost-summary/tags-example.png" border="true" alt-text="Screenshot of the Tags example page that shows several data categories." lightbox="./media/cost-summary/tags-example.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [Common terms](../help/terms.md)
- [Data dictionary](../help/data-dictionary.md)

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>