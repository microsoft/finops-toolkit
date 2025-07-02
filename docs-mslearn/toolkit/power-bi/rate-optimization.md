---
title: FinOps toolkit Rate optimization report
description: Learn about the Rate Optimization Report in Power BI, which summarizes savings from commitment discounts like reservations and savings plans.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Rate optimization report so that I can understand savings from discounts.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Rate optimization report

The **Rate optimization report** summarizes existing and potential savings from commitment discounts, like reservations and savings plans. This report enables you to:

- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments (also called utilization).
- Identify opportunity to save with more commitment discounts (also called coverage).
- Determine which resources used commitment discounts (also called chargeback).
- Summarize cost savings from commitment discounts.

> [!div class="nextstepaction"]
> [Download for KQL](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
> [!div class="nextstepaction"]
> [Download for storage](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20and%20optimize%20cost%20and%20usage%20with%20the%20FinOps%20toolkit%20Rate%20optimization%20report%3F/cvaQuestion/How%20valuable%20is%20the%20Rate%20optimization%20report%3F/surveyId/FTK0.11/bladeName/PowerBI.RateOptimization/featureName/Documentation)

Power BI reports are provided as template (.PBIT) files. Template files are not preconfigured and do not include sample data. When you first open a Power BI template, you will be prompted to specify report parameters, then authenticate with each data source to view your data. To access visuals and queries without loading data, select Edit in the Load menu button.

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (for example, reservation and savings plan)
- Service (for example, virtual machines and SQL database)
- Currency

A few common key performance indicators (KPIs) in this report are:

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Utilization** shows the percentage of your current commitments were used during the period.
- **Commitment savings** shows how much you're saving with commitment discounts.
  > [!IMPORTANT]
  > Microsoft Cost Management does not include the list and contracted prices for all accounts. To calculate accurate and complete savings, you will need to export prices. If using storage reports, enable the "Experimental: Populate Missing Prices" parameter in each report. If using KQL reports, missing prices will be populated automatically when prices are exported.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with links to learn more.

For instructions on how to connect this report to your data, including details about supported parameters, select the **Connect your data** button. Hold <kbd>Ctrl</kbd> when clicking the button in Power BI Desktop. If you need assistance, select the **Get help** button.

:::image type="content" source="./media/rate-optimization/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows basic information about commitment discounts." lightbox="./media/rate-optimization/get-started.png" :::

<br>

## Summary

The **Summary** page provides a high-level breakdown of cost and savings.

There are three cost numbers used on this page:

- **List cost** is the amount you would have paid with _no_ discounts.
- **Contracted cost** is the amount you would have paid with negotiated discounts but no commitment discounts.
- **Effective cost** is the amount paid to date after commitment discount purchases are amortized over the commitment term.

There are four savings numbers shown on this page:

- **Negotiated discount savings** is the difference between list and contracted cost, excluding commitment discount purchases. This number helps show the impact of rate negotiation efforts.
- **Commitment discount savings** is the difference between contracted and effective cost, excluding commitment discount purchases. This number helps show the impact of commitment discount efforts.
- **Total savings** is the difference between list and effective cost, excluding commitment discount purchases, which is the same as the sum of negotiated and commitment discount savings.
- **Effective Savings Rate (ESR)** compares savings to the list cost to calculate an overall percentage savings. This number helps show the overall impact of all discounts.

:::image type="content" source="./media/rate-optimization/summary.png" border="true" alt-text="Screenshot of the Summary page that shows cost and savings breakdown." lightbox="./media/rate-optimization/summary.png" :::

<br>

## Total savings

The **Total savings** page summarizes cost savings obtained from negotiated and commitment discounts. Savings is evaluated by comparing list cost and effective cost and includes Effective Savings Rate (ESR), which shows the percentage savings compared to list cost.

The chart shows effective cost and savings over time, based on the default granularity configured for the report.

The table shows cost, savings, and ESR per month with a breakdown by billing account. Select one or more rows to see a breakdown of on-demand (standard), spot, and committed usage (reservations) and spend (savings plans). Unused usage and spend is from the portion of commitment discounts that were not consumed during each charge period.

> [!IMPORTANT]
> Microsoft Cost Management does not include the list and contracted prices for all accounts. To calculate accurate and complete savings, you will need to export prices. If using storage reports, enable the "Experimental: Populate Missing Prices" parameter in each report. If using KQL reports, missing prices will be populated automatically when prices are exported.

> [!NOTE]
> Savings may appear as negative values when effective prices are higher than list prices, or as zero when price data is missing. For details on how savings are calculated and displayed, see [Understanding savings calculations](../hubs/savings-calculations.md).

:::image type="content" source="./media/rate-optimization/total-savings.png" border="true" alt-text="Screenshot of the Total savings page that shows cost savings from negotiated and commitment discounts." lightbox="./media/rate-optimization/total-savings.png" :::

<br>

## Commitment discount savings

The **Commitment discount savings** page summarizes cost savings obtained from commitment discounts. Commitments get grouped by program and service.

The chart shows total cost savings for the period split out by commitment type (for example, reservation and savings plan).

> [!IMPORTANT]
> Microsoft Cost Management does not include the list and contracted prices for all accounts. To calculate accurate and complete savings, you will need to export prices. If using storage reports, enable the "Experimental: Populate Missing Prices" parameter in each report. If using KQL reports, missing prices will be populated automatically when prices are exported.

:::image type="content" source="./media/rate-optimization/commitment-discount-savings.png" border="true" alt-text="Screenshot of the Commitment discount savings page that shows cost savings from commitment discounts." lightbox="./media/rate-optimization/commitment-discount-savings.png" :::

<br>

## Commitment discounts

The **Commitment discounts** page provides a list of your commitment discounts and offers a summary of the quantity used, utilization, savings, and effective cost for the period.

The chart breaks down the cost of used (utilized) vs. unused charges. The commitment type (for example, reservation and savings plan) splits unused charges.

:::image type="content" source="./media/rate-optimization/commitment-discounts.png" border="true" alt-text="Screenshot of the Commitment discounts page that shows a list of your commitment discounts." lightbox="./media/rate-optimization/commitment-discounts.png" :::

<br>

## Commitment discount utilization

The **Commitment discount utilization** page provides a summary of the utilization of your commitment discounts by showing the total covered usage cost divided by the total effective (amortized) commitment discount cost for the period.

The chart shows the sum of all used cost compared to unused cost as percentages per day. The table shows a list of all commitment discounts. To view the utilization for a single commitment discount in the chart, select the row in the table, set applicable filters on the left, or use the "Drill through" capability from another page.

:::image type="content" source="./media/rate-optimization/commitment-discount-utilization.png" border="true" alt-text="Screenshot of the Commitment discount utilization page that shows an aggregate utilization percentage for the selected commitment discounts." lightbox="./media/rate-optimization/commitment-discount-utilization.png" :::

<br>

## Commitment discount resources

The **Commitment discount resources** page provides a list of all resources that were covered by the selected commitment discounts (all by default).

The chart breaks down the effective cost of your commitment discounts by resource over time. The table shows the utilization, cost, and savings for the entire period. To view resources for a single commitment discount in the chart, set applicable filters on the left or use the "Drill through" capability from another page.

:::image type="content" source="./media/rate-optimization/commitment-discount-resources.png" border="true" alt-text="Screenshot of the Commitment discount resources page that shows a list of resources covered by selected commitment discounts during the period." lightbox="./media/rate-optimization/commitment-discount-resources.png" :::

<br>

## Chargeback

The **Chargeback** page helps facilitate chargeback at a subscription, resource group, or resource level. Use the table for chargeback.

The chart shows the amortized cost for each subscription that used a commitment. If you see **Unassigned**, that is the unused cost that isn't associated with a subscription.

> [!NOTE]
> This page is also available in the Cost summary report as "Commitments" to show how commitments impact resource costs.

:::image type="content" source="./media/rate-optimization/chargeback.png" border="true" alt-text="Screenshot of the Chargeback page that shows information used for chargeback." lightbox="./media/rate-optimization/chargeback.png" :::

### Chargeback customization tips

- Change the columns in the table based on your chargeback needs.
- Create custom columns in the Costs table that extract tags for cost allocation, then add them as columns into the visual for reporting.
- Integrate external data for more allocation options.

<br>

## Reservation recommendations

The **Reservation recommendations** page helps you identify any places where you could potentially save even more based on your historical usage patterns with virtual machine reservations within a single subscription or shared across all subscriptions.

These pages use the following filters for reservation recommendations:

- **Term** – Length of time for a reservation.
- **Lookback** – Period of historical time to use when recommending future reservations (for example, 7-day and 30-day). Options are based on data you export.
- **Scope** – Indicates whether to view shared or single scope recommendations. Options are based on data you export.
- **Subscription** – Indicates which subscription you want to see recommendations for. All are shown by default.

The KPIs on this page cover:

- **Potential savings** shows what you could save if you purchase the recommended virtual machine (VM) reservations.
- **Contracted cost** shows the cost that would be covered by the recommended reservations.

There are two charts on the page that offer a breakdown of location, instance size flexibility group, and size; and, CPU hours over time. Your goal is to increase the committed usage in green and spend in blue in order to decrease the contracted cost in red, which costs you more.

The table below the charts shows the recommended reservations based on the specified lookback period.

> [!IMPORTANT]
> The reservation recommendations page utilizes Cost Management exports either directly in storage (via the **Export Storage URL** parameter) or as part of FinOps hubs. If you do not see recommendations, confirm that you have configured exports and the filters at the top of the page align to the recommendations you exported (for example, term, lookback, and scope).

<br>

> [!IMPORTANT]
> Potential savings and contracted cost estimations are only available for VM reservation recommendations. This page has not been tested for non-VM recommendations. You can view savings plan and reservation recommendations for other services in the Azure portal.

:::image type="content" source="./media/rate-optimization/reservation-recommendations.png" border="true" alt-text="Screenshot of the Reservation recommendations page that shows reservation purchase recommendations." lightbox="./media/rate-optimization/reservation-recommendations.png" :::

<br>

## Purchases

The **Purchases** page shows any new commitment discount purchases, either monthly or upfront payments, within the specified period.

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

There's one, **Billed cost** KPI which shows the total cost of the purchases as it appears on your invoice. It's different than the cost on other pages, which show amortized cost.

The chart shows the purchases over time and the table shows a list of the commitments that were purchased, including the term, product, and payment frequency. **OneTime** is for upfront payments and **Recurring** is for monthly.

:::image type="content" source="./media/rate-optimization/purchases.png" border="true" alt-text="Screenshot of the Purchases page that shows new commitment discount purchases." lightbox="./media/rate-optimization/purchases.png" :::

<br>

## Hybrid Benefit

The **Hybrid Benefit** page shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).

KPIs show how many VMs are using Azure Hybrid Benefit and how many vCPUs are used.

There are three charts on the page:

- SKU names and number of VMs currently using fewer than 8 vCPUs. They're under-utilizing AHB.
- SKU names and number of VMs with 8+ vCPUs that aren't currently using AHB.
- Daily breakdown of AHB and non-AHB usage (excluding VMs where AHB isn't supported).

The table shows a list of VMs that are currently using or could be using AHB, showing:

- vCPU count
- AHB vCPU count
- Resource group
- Subscription
- Cost
- Quantity

:::image type="content" source="./media/rate-optimization/hybrid-benefit.png" border="true" alt-text="Screenshot of the Hybrid Benefit page that shows usage for Windows server VMs." lightbox="./media/rate-optimization/hybrid-benefit.png" :::

<br>

## Prices

The **Prices** page shows the prices for all products that were used with commitment discounts during the period.

<!-- NOTE: There are similar pages in the cost-summary.md and rate-optimization files. They are not identical. Please keep both updated at the same time. -->

The chart shows a summary of the meters that got used the most.

:::image type="content" source="./media/rate-optimization/prices.png" border="true" alt-text="Screenshot of the Prices page that shows prices for all products that were used with commitment discounts." lightbox="./media/rate-optimization/prices.png" :::

<br>

## Data quality

The **Data quality** page shows some of the data used to calculate savings at a cost and unit price level. It can be helpful in understanding the data but also in identifying issues in Cost Management data that result in an incomplete picture of cost savings (for example, missing price and cost values). If you're missing any data, contact support to help raise the priority of these bugs in Cost Management. This page is only available in storage-based reports. If using Data Explorer, use the [Data Explorer query console](https://dataexplorer.azure.com).

:::image type="content" source="./media/rate-optimization/data-quality.png" border="true" alt-text="Screenshot of the Data quality page that shows some of the data used to calculate savings at a cost and unit price level." lightbox="./media/rate-optimization/data-quality.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [Common terms](../help/terms.md)
- [Data dictionary](../help/data-dictionary.md)

Related FinOps capabilities:

- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
