---
layout: default
title: Power BI
has_children: true
nav_order: 21
description: 'Accelerate your FinOps reporting with Power BI starter kits.'
permalink: /power-bi
---

<span class="fs-9 d-block mb-4">Power BI reports</span>
Accelerate your analytics efforts with simple, targeted reports. Summarize and break costs down, or customize to meet your needs.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [📈 Available reports](#-available-reports)
- [⚖️ Help me choose](#️-help-me-choose)
- [✨ Connect to your data](#-connect-to-your-data)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---

<!-- markdownlint-disable-line --> {% include_relative _intro.md %}

<blockquote class="note" markdown="1">
   _As of FinOps toolkit 0.2, all reports have been updated to use the FinOps Open Cost and Usage Specification (FOCUS). To learn more, see [About FOCUS](../focus/README.md)._
</blockquote>

<br>

## 📈 Available reports

The FinOps toolkit includes the following reports:

- [Cost summary](./cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Commitment discounts](./commitment-discounts.md) – Summarizes existing and potential savings from commitment-based discounts.
- [Cost Management connector](./connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector.
- [Cost Management template app](./template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .mb-4 .mb-md-0 .mr-4 }
[How to setup](#-connect-to-your-data){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## ⚖️ Help me choose

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](https://aka.ms/costanalysis/docs) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following to determine the best approach for you:

1. For costs under $2-5M in total<sup>1</sup> that don't need savings plan data, you can use the Cost Management connector for Power BI.
   - The connector uses existing raw cost data APIs and cannot scale to data sizes beyond $5M<sup>1</sup>.
   - Due to the size constraints, the connector will be phased out by the Cost Management team starting in 2024.
   - The APIs do not include some key columns for savings plans, like the BenefitId/Name columns. All costs are covered but not always easily identifiable.
2. _**Coming soon:**_ For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use raw exports with Power BI.
   - This is in preview and will be included in a future FinOps toolkit release.
   - To enable the preview, see the "Exports (preview)" feature in [Cost Management Labs](https://aka.ms/costmgmt/trypreview).
3. For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use FinOps hubs with Power BI.
   - Requires incremental refresh to be enabled to load more than $5M over multiple months.
4. _**Coming soon:**_ For costs over $5M/month or for additional capabilities, you can connect Fabric to either FinOps hubs or raw exports.
   - This is possible today, but is not supported in FinOps toolkit reports yet. Support will be added in a future release.

_<sup>1) Power BI Pro can handle ~$2M of raw cost data. Power BI Premium can handle ~$5M.</sup>_

_<sup>2) The $2-5M limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $65M with incremental refresh enabled.</sup>_

In general, we recommend starting with the Cost Management connector when getting started with Power BI reports. The most common reasons to switch to FinOps hubs are for additional account types and scopes or to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                        |            Connector             |       Exports<sup>1</sup>        |           FinOps hubs            | Microsoft Fabric<sup>2</sup> |
| --------------------------------------------------- | :------------------------------: | :------------------------------: | :------------------------------: | :--------------------------: |
| Cost                                                |                $0                |           ~$10 per $1M           |           ~$25 per $1M           |             TBD              |
| Data storage                                        |             Power BI             |        Data Lake Storage         |        Data Lake Storage         |      Data Lake Storage       |
| Est. max raw cost details per month<sup>3</sup>     | $2M/mo (Pro)<br>$5M/mo (Premium) | $2M/mo (Pro)<br>$5M/mo (Premium) | $2M/mo (Pro)<br>$5M/mo (Premium) |             TBD              |
| Est. max total with incremental refresh<sup>4</sup> |    $2M (Pro)<br>$5M (Premium)    |   $2M (Pro)<br>$65M (Premium)    |   $2M (Pro)<br>$65M (Premium)    |             TBD              |
| Does not require a deployment                       |                ✅                 |         ❌ (storage only)         |   ❌ ([details][hubs-template])   |              ❌               |
| Latest API version<sup>5</sup>                      |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Azure Government                                    |                ❌                 |                🔜                 |                ✅                 |           ✅ (Hubs)           |
| Azure China                                         |                ❌                 |                🔜                 |                ✅                 |           ✅ (Hubs)           |
| Enterprise Agreement                                |                ✅                 |                ✅                 |                ✅                 |              ✅               |
| Microsoft Customer Agreement                        |                ✅                 |                ✅                 |                ✅                 |              ✅               |
| Microsoft Partner Agreement                         |                ✅                 |                ✅                 |                ✅                 |              ✅               |
| Microsoft Online Services Agreement                 |                ❌                 |         ❌ (if requested)         |         ❌ (if requested)         |              ❌               |
| Billing accounts                                    |                ✅                 |                ✅                 |                ✅                 |              ✅               |
| Billing profiles                                    |                ✅                 |                ✅                 |                ✅                 |              ✅               |
| Invoice sections                                    |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| CSP customers (partner only)                        |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Management groups                                   |                ❌                 |                ❌                 |         ❌ (if requested)         |              ❌               |
| Subscriptions                                       |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Resource groups                                     |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Supports savings plans<sup>5</sup>                  |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Supports savings plan recommendations               |                ❌                 |                ❌                 |             🔜 (0.4)              |              🔜               |
| Supports multiple scopes                            |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Supports scopes in different tenants                |                ❌                 |                ❌                 |             🔜 (0.3)              |           🔜 (Hubs)           |
| Faster data load times                              |                ❌                 |                🔜                 |                ✅                 |           ✅ (Hubs)           |
| Supports >$65M in cost details                      |                ❌                 |                ❌                 |             🔜 (0.4)              |              ✅               |
| Analytical engine                                   |                ❌                 |                ❌                 |             🔜 (0.4)              |              ✅               |
| Accessible outside of Power BI                      |                ❌                 |                ✅                 |                ✅                 |              ✅               |
| Learn more                                          |  [Learn more][about-connector]   |                                  |     [Learn more][about-hubs]     |

[about-connector]: https://aka.ms/costmgmt/powerbi
[about-hubs]: ../finops-hub/README.md
[hubs-template]: ../finops-hub/template.md

_<sup>1) Support for raw exports requires a Cost Management preview feature available from [Cost Management Labs](https://aka.ms/costmgmt/trypreview). The FinOps toolkit does not support raw exports yet but will in a future release.</sup>_

_<sup>2) Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports do not support Microsoft Fabric yet but will in a future release.</sup>_

_<sup>3) Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You may see different limits based on services you use and other datasets you ingest.</sup>_

_<sup>4) The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. The FinOps hub estimate is based on incremental refresh being enabled, which requires additional configuration after your report is published.</sup>_

_<sup>5) The Cost Management connector uses an old API version and does not include details for some features, like savings plans. Please use FinOps hubs for the latest version with all details.</sup>_

If you're not sure, start with the Cost Management connector. You will usually be able to tell if that works for you within the first 5-10 minutes. If you experience delays in pulling your data, try requesting fewer months. If you still experience issues, it's time to consider switching to FinOps hubs.

<br>

## ✨ Connect to your data

All FinOps toolkit reports, come with sample data to explore without connecting to your account. Reports have a built-in tutorial to help you connect to your data.

1. Select the **Transform data** button (table with a pencil icon) in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

2. Select **Queries** > **🛠️ Setup** > **Instructions** > **▶ START HERE** and follow the instructions.

   To connect to a FinOps hub instance, you will need the `storageUrlForPowerBI` value from the deployment outputs. Make sure you have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) on the storage account so you can access the data.

   ![Screenshot of instructions to connect to a FinOps hub](https://github.com/microsoft/finops-toolkit/assets/399533/5582b428-e811-4d7e-83d0-4a8fbb905d30)

   To connect to the Cost Management connector, you will need the billing account ID and/or billing profile ID. You can find this in [Cost Management configuration settings](https://aka.ms/costmgmt/config) > **Properties**.

   ![Screenshot of instructions to connect to the Cost Management connector](https://github.com/microsoft/finops-toolkit/assets/399533/efeb85d6-cdd3-40f8-a501-e1959fdb1d4f)

3. Select **Close & Apply** in the toolbar and allow Power BI to refresh to see your data.

For more details, see [How to setup Power BI](./setup.md).

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" opt="1" gov="1" data="1" %}

<br>
