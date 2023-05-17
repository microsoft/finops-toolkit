# 📊 Commitment discounts report

The **Commitment discounts report** summarizes existing and potential savings from commitment-based discounts, like reservations and savings plans. This report enables you to:

- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments (aka utilization).
- Identify opportunity to save with more commitment-based discounts (aka coverage).
- Determine which resources used commitment-based discounts (aka chargeback).
- Summarize cost savings from commitment-based discounts.

> 🚩 **Important**<br>FinOps hubs uses [amortized costs](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-amortization). Amortization breaks reservation and savings plan purchases down and allocates costs to the resources that received the benefit. Due to this, amortized costs will not show purchase costs and will not match your invoice. Please use [Cost Management](https://aka.ms/costmgmt) to review invoice charges.

On this page:

- [Common page layout](#common-page-layout)
- [Get started](#get-started)
- [Hybrid Benefit](#hybrid-benefit)
- [Commitments](#commitments)
- [Coverage](#coverage)
- [See also](#see-also)

---

## Common page layout

Most report pages follow a standard layout with filters, summary numbers (or KPIs), one or more charts, and a table.

### Filters

Filters differ on each page, but may include one or more of the following:

- Date range
- Subscription
- Resource group
- Commitment (e.g., reservation, savings plan)
- Service/Tier (meter category/subcategory)
- Currency

Note the currency must be single-select to ensure costs in different currencies aren't mixed.

### Key performance indicators (KPIs)

KPIs differ on each page, but may include one or more of the following:

- Amortized cost
- Commitment savings

Both numbers represent the sum for the entire period.

### Charts

The charts section provides a visual summary of the page. Charts differ on each page.

### Table

The table shows a breakdown of the cost or recommendations, depending on the purpose of the page.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

![Screenshot of the Get started page](https://user-images.githubusercontent.com/399533/216883194-47ac6f41-c57f-491b-8b56-dfc2b1ef02f5.png)

<br>

## Hybrid Benefit

<!-- NOTE: This page is duplicated in the cost-summary.md. Please keep both updated at the same time. -->

The **Hybrid Benefit** page shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs). The page uses the standard filters, but differs with the other sections.

Instead of cost KPIs, the page shows how many VMs are currently enabled and how many vCPUs are used.

There are 3 charts on the page:

1. SKU names and number of VMs currently using less than 8 vCPUs. These are under-utilizing AHB.
2. SKU names and number of VMs with 8+ vCPUs that are not currently using AHB.
3. Daily breakdown of AHB and non-AHB usage (excluding those where AHB is not supported).

The table shows a list of VMs that are currently using or could be using AHB with their vCPU count, AHB vCPU count, resource group, subscription, cost and quantity.

![Screenshot of the Hybrid Benefit page](https://user-images.githubusercontent.com/399533/216882954-a83d0c8a-fe6d-4d55-8e8b-45b3df3914a9.png)

<br>

## Commitments

<!-- NOTE: This page is duplicated in the cost-summary.md. Please keep both updated at the same time. -->

The **Commitments** page serves 3 primary purposes:

1. Determine if there are any under-utilized commitments.
2. Facilitate chargeback at a subscription, resource group, or resource level.
3. Summarize cost savings obtained from commitment-based discounts.

This page uses the standard layout with a breakdown of commitment-based discounts in the chart and table.

In addition to cost and savings KPIs, there is also a utilization KPI for the amount of commitment-based discounts that have been utilized during the period. Low utilization will result in lost savings potential, so this number is one of the most important KPIs on the page.

The chart breaks down the cost of used (utilized) vs. unused charges. Unused charges are split out by commitment type (e.g., reservation, savings plan).

The table shows resource usage against commitment-based discounts with columns for resource name, resource group, subscription, and commitment. Use the table for chargeback and savings calculations.

This page filters usage down to only show charges related to commitment-based discounts, which means the total cost on the Commitments page won't match other pages, which aren't filtered by default.

![Screenshot of the Commitment-based discounts page](https://user-images.githubusercontent.com/399533/216882916-bb7ecfa3-d092-4ae2-88e1-7a0425c14dca.png)

### 🛠️ Customization tips

- Consider changing the columns in the table based on your chargeback needs.

<br>

## Coverage

There are two **Coverage** pages that help you identify any places where you could potentially save even more based on your historical usage patterns with virtual machine reservations within a single subscription or shared across all subscriptions. Each page uses the standard layout optimized to show recommendations rather than focusing on cost, so sections differ from other pages.

Most of the common cost filters are not available. The following filters are available for recommendations:

- Term – Length of time for a reservation.
- Scope – Indicates how broadly reservations should be shared (i.e., Billing account, Management group, Subscription, Resource group).
- Lookback – Period of historical time to use when recommending future reservations (e.g., 7-day, 30-day).

The KPIs on this page cover:

- Potential savings (from recommendations)
- On-demand cost (based on the date range)

There are 2 charts on the page that offer a breakdown of location, instance size flexibility group, and size; and, cost over time.

![Screenshot of the VM shared reservation coverage page](https://github.com/microsoft/cloud-hubs/assets/399533/e33abb0b-6b2b-44d7-a9ec-8061b72d7857)

<br>

## See also

- [Power BI ideas and suggestions](https://github.com/microsoft/cloud-hubs/issues?q=is%3Aissue+is%3Aopen+label%3A%22Area%3A+Power+BI%22)
- [Common terms](./terms.md)

<br>
