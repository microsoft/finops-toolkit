---
title: Rate optimization report
description: Learn about the Rate Optimization Report in Power BI, which summarizes savings from commitment discounts like reservations and savings plans.
author: bandersmsft
ms.author: banders
ms.date: 10/10/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the Rate optimization report so that I can understand savings from discounts.
---

<!-- markdownlint-disable-next-line MD025 -->
# Rate optimization report

The **Rate optimization report** summarizes existing and potential savings from commitment discounts, like reservations and savings plans. This report enables you to:

- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments (also called utilization).
- Identify opportunity to save with more commitment discounts (also called coverage).
- Determine which resources used commitment discounts (also called chargeback).
- Summarize cost savings from commitment discounts.

You can download the Rate optimization report from the [latest release](https://github.com/microsoft/finops-toolkit/releases).

> [!NOTE]
> The "Commitment discounts" report was renamed to "Rate optimization" in FinOps toolkit 0.4. The purpose and intent of the report remains the same.

<br>

## Working with this report

This report includes the following filters on each page:

- Charge period (date range)
- Subscription and resource group
- Region
- Commitment (for example, reservation and savings plan)
- Service (for example, virtual machines and SQL database)
- Currency

A few common KPIs you fill find in this report are:

- **Effective cost** shows the effective cost for the period with reservation purchases amortized across the commitment term.
- **Utilization** shows the percentage of your current commitments were used during the period.
- **Commitment savings** shows how much you're saving with commitment discounts.
  > [!IMPORTANT]
  > Microsoft Cost Management does not include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with links to learn more.

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

:::image type="content" source="./media/rate-optimization/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows basic information about commitment discounts." lightbox="./media/rate-optimization/get-started.png" :::

<br>

## Commitments

The **Commitments** page provides a list of your commitment discounts and offers a summary of the quantity used, utilization, savings, and effective cost for the period.

The chart breaks down the cost of used (utilized) vs. unused charges. The commitment type (for example, reservation and savings plan) splits unused charges.

:::image type="content" source="./media/rate-optimization/commitment-discounts.png" border="true" alt-text="Screenshot of the Commitments page that shows a list of your commitment discounts." lightbox="./media/rate-optimization/commitment-discounts.png" :::

<br>

## Savings

The **Savings** page summarizes cost savings obtained from commitment discounts. Commitments are grouped by program and service.

The chart shows total cost savings for the period split out by commitment type (for example, reservation and savings plan).

> [!WARNING]
> Microsoft Cost Management does not include the unit price for amortized charges with Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this.

:::image type="content" source="./media/rate-optimization/savings.png" border="true" alt-text="Screenshot of the Savings page that shows cost savings from commitment discounts." lightbox="./media/rate-optimization/savings.png" :::

<br>

## Chargeback

The **Chargeback** page helps facilitate chargeback at a subscription, resource group, or resource level. Use the table for chargeback.
<!-- NOTE: This page is duplicated in the cost-summary.md file as "Commitments". Please keep both updated at the same time. -->

The chart shows the amortized cost for each subscription that used a commitment. If you see **Unassigned**, that is the unused cost that isn't associated with a subscription.

> [!NOTE]
> This page is also available in the Cost summary report as "Commitments" to show how commitments impact resource costs.

:::image type="content" source="./media/rate-optimization/chargeback.png" border="true" alt-text="Screenshot of the Chargeback page that shows information used for chargeback." lightbox="./media/rate-optimization/chargeback.png" :::

### Chargeback customization tips

- Consider changing the columns in the table based on your chargeback needs.
- If you use tags for cost allocation, create custom columns in the CostDetails table that extract their values, then add them as columns into the visual for reporting.
- Consider bringing in external data for more allocation options.

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

<!-- NOTE: There is a similar page in the cost-summary.md file. They are not identical. Please keep both updated at the same time. -->

There's one, **Billed cost** KPI which shows the total cost of the purchases as it appears on your invoice. It's different than the cost on other pages, which show amortized cost.

The chart shows the purchases over time and the table shows a list of the commitments that were purchased, including the term, product, and payment frequency. **OneTime** is for upfront payments and **Recurring** is for monthly.

:::image type="content" source="./media/rate-optimization/purchases.png" border="true" alt-text="Screenshot of the Purchases page that shows new commitment discount purchases." lightbox="./media/rate-optimization/purchases.png" :::

<br>

## Hybrid Benefit

The **Hybrid Benefit** page shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).

<!-- NOTE: This page is duplicated in the cost-summary.md file. Please keep both updated at the same time. -->

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

<!-- NOTE: There is a similar page in the cost-summary.md file. They are not identical. Please keep both updated at the same time. -->

The chart shows a summary of the meters that got used the most.

:::image type="content" source="./media/rate-optimization/prices.png" border="true" alt-text="Screenshot of the Prices page that shows prices for all products that were used with commitment discounts." lightbox="./media/rate-optimization/prices.png" :::

<br>

## Data quality

The **Data quality** page shows some of the data used to calculate savings at a cost and unit price level. It can be helpful in understanding the data but also in identifying issues in Cost Management data that result in an incomplete picture of cost savings (for example, missing price and cost values). If you're missing any data, contact support to help raise the priority of these bugs in Cost Management.

:::image type="content" source="./media/rate-optimization/data-quality.png" border="true" alt-text="Screenshot of the Data quality page that shows some of the data used to calculate savings at a cost and unit price level." lightbox="./media/rate-optimization/data-quality.png" :::

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea)

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)

<!-- TODO: Bring in after these resources are moved
- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)
-->

Related FinOps capabilities:

- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [FinOps toolkit open data](../open-data.md)

<br>

