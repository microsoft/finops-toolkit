---
title: EA template app
description: 'Cost Management template app for Enterprise Agreement accounts.'
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Cost Management template app for Enterprise Agreement accounts

The **EA template app** is the PBIX version of the "Cost Management app" in Microsoft AppSource. The template app is not customizable or downloadable, so we are making the PBIX file available here. We do not recommend using this report as it only works for Enterprise Agreement billing accounts and is no longer being updated. You are welcome to download and customize it as needed, but you may want to check out the other [FinOps toolkit reports](./reports.md), which have been updated to cover new scenarios. The [Cost summary](./cost-summary.md) and [Rate optimization](./rate-optimization.md) reports were both created based on the template app, so you should find most capabilities within those reports. If you feel something is missing, [let us know](https://aka.ms/ftk/idea)!

<br>

## About the Cost Management app

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

To learn more, see [Analyze cost with the Cost Management Power BI app for Enterprise Agreements (EA)](/azure/cost-management-billing/costs/analyze-cost-data-azure-cost-management-power-bi-template-app).

<br>

## What's changed

In general, we don't plan to make changes to the template app. The following minor tweaks were made to resolve bugs:

- Added `Tags` and `TagsAsJson` columns to both the **Usage details** and **Usage details amortized** tables.

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea)

<br>
