---
layout: default
parent: Power BI
title: EA template app
nav_order: zzz
description: 'Cost Management template app for Enterprise Agreement accounts.'
permalink: /power-bi/template-app
---

<span class="fs-9 d-block mb-4">EA template app</span>
Cost Management template app available for Enterprise Agreement billing accounts
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [ℹ️ About the Cost Management app](#ℹ️-about-the-cost-management-app)
- [🆕 What's changed](#-whats-changed)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **EA template app** is the PBIX version of the "Cost Management app" in Microsoft AppSource. The template app is not customizable or downloadable, so we are making the PBIX file available here. We do not recommend using this report as it only works for Enterprise Agreement billing accounts and is no longer being updated. You are welcome to download and customize it as needed, but you may want to check out the other [FinOps toolkit reports](./README.md), which have been updated to cover new scenarios. The [Cost summary](./cost-summary.md) and [Rate optimization](./rate-optimization.md) reports were both created based on the template app, so you should find most capabilities within those reports. If you feel something is missing, [let us know](https://aka.ms/ftk/idea)!

<br>

## ℹ️ About the Cost Management app

Using the Cost Management template app for Power BI, you can import and analyze your Azure cost and usage data within Power BI. The reports provided allow you to gain insights into which subscriptions or resource groups are consuming the most and visibility into spending trends and overall usage.

Included reports:

- Account overview
- Usage by subscriptions and resource groups
- Top 5 usage drivers
- Usage by services
- Windows Server AHB usage
- VM reservation coverage (shared recommendation)
- VM reservation coverage (single recommendation)
- Reservation savings
- Reservation chargeback
- Reservation purchases
- Price sheet

To learn more, see [Analyze cost with the Cost Management Power BI app for Enterprise Agreements (EA)](https://learn.microsoft.com/azure/cost-management-billing/costs/analyze-cost-data-azure-cost-management-power-bi-template-app).

<br>

## 🆕 What's changed

In general, we don't plan to make changes to the template app. The following minor tweaks were made to resolve bugs:

- Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables.

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
