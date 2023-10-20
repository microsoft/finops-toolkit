---
layout: default
grand_parent: FinOps hubs
parent: Reports
title: FOCUS
nav_order: 90
description: 'Identify top contributors, review changes over time, build a chargeback report, and summarize savings in Power BI.'
permalink: /hubs/reports/focus
---

<span class="fs-9 d-block mb-4">FOCUS 0.5 sample report</span>
Explore the FinOps Open Cost and Usage Specification (FOCUS) with an interactive dashboard and connect to your data.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/FOCUS.pbix){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](./README.md#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Working with this report](#working-with-this-report)
- [Get started](#get-started)
- [Raw data](#raw-data)
- [Services](#services)
- [Regions](#regions)
- [Sub accounts](#sub-accounts)
- [Resources](#resources)
- [DQ](#dq)
- [Working draft](#working-draft)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **FOCUS report** is an example Azure dataset that aligns to the FinOps Open Cost and Usage Specification (FOCUS), an open specification that provides a common schema for cost and usage data. To learn more, see [focus.finops.org](https://focus.finops.org).

You can download the FOCUS report from the [latest release](https://github.com/microsoft/finops-toolkit/releases/latest).

<br>

## Working with this report

This report includes the following filters on each page:

- Date range
- Sub account (subscription)
- Service category
- Service name
- Region
- Currency

A few common KPIs you fill find in this report are:

- **Amortized cost** shows the effective cost for the period with commitment-based discount purchases amortized across the commitment term.
- **Billed cost** shows the billed cost as it would appear on your invoice.

Note the currency must be single-select to ensure costs in different currencies aren't mixed.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

![Screenshot of the Get started page](https://github.com/microsoft/finops-toolkit/assets/399533/9e427f36-414a-43bc-840e-167fab30b98e)

<br>

## Raw data

The **Raw data** page includes a table with all FOCUS columns (except the IDs to conserve space). This page is useful to familiarize yourself with the columns themselves.

![Screenshot of the Raw data page](https://github.com/microsoft/finops-toolkit/assets/399533/3ed4a3a9-7060-44ff-bf35-9ebd5ffdfc6c)

<br>

## Services

The **Services** page offers a breakdown of cost by service. Each service is grouped into a **service category**, which is similar to how service are organized on the Azure.com website.

<blockquote class="important" markdown="1">
   _The FOCUS ServiceName column is not the same thing as MeterCategory or the ServiceName column for Enterprise Agreement accounts. FOCUS ServiceName is a grouping of resources in each category. This means bandwidth charges for a VM will be grouped under the Compute service category rather than the Network meter category. This distinction is very important when comparing numbers between FOCUS and Azure schemas._
</blockquote>

![Screenshot of the Services page](https://github.com/microsoft/finops-toolkit/assets/399533/c35b3400-821b-418b-ab42-fda7888d351a)

<br>

## Regions

The **Regions** page includes a breakdown of cost by region.

<blockquote class="note" markdown="1">
   _FinOps toolkit reports perform additional data cleansing for ResourceLocation and FOCUS Region columns. What you see in FinOps toolkit reports may not match other reporting._
</blockquote>

![Screenshot of the Regions page](https://github.com/microsoft/finops-toolkit/assets/399533/7343323d-7344-414f-a2f3-a9ff443c9077)

<br>

## Sub accounts

The **Sub accounts** page includes a breakdown of cost by sub account (subscription).

![Screenshot of the Sub accounts page](https://github.com/microsoft/finops-toolkit/assets/399533/6365f652-411f-4c52-aeb9-9e60e0627376)

<br>

## Resources

The **Resources** page includes a breakdown of cost by resource.

![Screenshot of the Resources page](https://github.com/microsoft/finops-toolkit/assets/399533/1b566641-8af3-4f2f-abd6-c5a0efa2fbc6)

<br>

## DQ

<!-- NOTE: This page is duplicated in the commitment-discounts.md. Please keep both updated at the same time. -->

The **Data quality** page is for data validation purposes only; however, it can be used to explore service categories, names, regions, and charge types.

![Screenshot of the Data quality page](https://github.com/microsoft/finops-toolkit/assets/399533/a1b55496-c395-4eca-a487-07f6abc1028d)

<br>

## Working draft

The **Working draft** page shows the latest developments from the FOCUS working draft, which currently includes the following changes compared to FOCUS 0.5:

- `AmortizedCost` was renamed to `EffectiveCost`.
- `ChargeFrequency` was added to indicate how often a charge will be repeated.
- `CommitmentDiscountId` and `CommitmentDiscountName` were added to indicate the commitment discount that was applied to a charge.
- `ListUnitPrice` was added to indicate the list (or retail) price for a charge.

![Screenshot of the Working draft page](https://github.com/microsoft/finops-toolkit/assets/399533/01e17591-32f7-4d6c-81f7-2e18da8e68bc)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
