---
layout: default
parent: Power BI
title: CM connector
nav_order: yyy
description: 'Power BI report for the Cost Management connector.'
permalink: /power-bi/connector
---

<span class="fs-9 d-block mb-4">Cost Management connector</span>
Power BI report covering cost summaries, breakdowns, and commitment discounts using the Cost Management connector
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostManagementConnector.pbix){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](./README.md#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Working with this report](#working-with-this-report)
- [Pages](#pages)
- [See also](#see-also)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **Cost Management connector** report provides a general overview of cost, commitment discounts, and savings with a few common breakdowns that enable you to:

- Identify the top cost contributors.
- Review changes in cost over time.
- Review Azure Hybrid Benefit usage.
- Identify and resolve any under-utilized commitments (aka utilization).
- Identify opportunity to save with more commitment discounts (aka coverage).
- Determine which resources used commitment discounts (aka chargeback).
- Summarize cost savings from negotiated and commitment discounts.

You can download the Cost Management connector report from the [latest release](https://github.com/microsoft/finops-toolkit/releases/latest).

<blockquote class="warning" markdown="1">
  _The Cost Management connector uses an older API that does not include all details about savings plans. You will see unused savings plan charges that will not have identifiable usage for due to this gap. This will skew numbers, if you have savings plans. Consider using [FinOps hubs](../finops-hub/README.md) to use savings plans._
</blockquote>

<blockquote class="important" markdown="1">
   _The Cost Management connector is in maintenance mode and no longer being updated. Cost Management support for Power BI is moving to utilize exports instead of the connector. With native support for FOCUS and the deprecation of the connector, the Cost Management connector report is a copy of the [Cost summary](./cost-summary.md) and [Commitment discounts](./commitment-discounts.md) reports in the FinOps toolkit 0.2 release for backwards compatibility, but will not be maintained over time._
</blockquote>

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
  <blockquote class="important" markdown="1">
    _Microsoft Cost Management does not include the pricing details for Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this._
  </blockquote>

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
  <blockquote class="note" markdown="1">
     _The Cost Management connector report performs additional data cleansing for the Region column to better align with Azure regions and may not match values you see in actual and amortized datasets in Cost Management._
  </blockquote>
- **Charge breakdown** shows a breakdown of all charges using the following information hierarchy:
- **Prices** shows the prices for all products that were used during the period.
- **Hybrid Benefit** shows Azure Hybrid Benefit (AHB) usage for Windows Server virtual machines (VMs).
- **Purchases** shows a list of products that were purchased during the period.
- **Commitments** serves 3 primary purposes:
  1. Determine if there are any under-utilized commitments.
  2. Facilitate chargeback at a subscription, resource group, or resource level.
  3. Summarize cost savings obtained from commitment discounts.
- **Commitment savings** summarizes cost savings obtained from commitment discounts. Commitments are grouped by program and service.
  <blockquote class="warning" markdown="1">
    _Microsoft Cost Management does not include the pricing details for Microsoft Customer Agreement accounts, so commitment savings cannot be calculated. Please file a support request and speak to your field rep to escalate this._
  </blockquote>
- **Commitment chargeback** helps facilitate chargeback at a subscription, resource group, or resource level. Use the table for chargeback.
- There are two **Reservation coverage** pages that help you identify any places where you could potentially save even more based on your historical usage patterns with virtual machine reservations within a single subscription or shared across all subscriptions.
- **Raw data** shows a table with most columns to help you explore FOCUS columns.
- **Data quality** is for data validation purposes only; however, it can be used to explore charge categories, pricing categories, services, and regions.

<br>

## See also

- [About FOCUS](../focus/README.md)
- [Common terms](../resources/terms.md)
- [Data dictionary](../resources/data-dictionary.md)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
