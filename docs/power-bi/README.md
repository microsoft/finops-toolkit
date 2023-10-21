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

</details>

---

{% include_relative _intro.md %}

<br>

## 📈 Available reports

The following reports are currently available for within the FinOps toolkit:

- [Cost summary](./cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Commitment discounts](./commitment-discounts.md) – Summarizes existing and potential savings from commitment-based discounts.
- [FOCUS](./focus.md) – See your data in the FinOps Open Cost and Usage Specification (FOCUS) schema.
- [Cost Management template app](./template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
[How to setup](#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<br>

## ⚖️ Help me choose

In general, we recommend starting with the Cost Management connector when getting started with Power BI reports. The most common reasons to switch to FinOps hubs are for additional account types and scopes or to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                                 |                   Connector                   |              FinOps hubs              |
| ------------------------------------------------------------ | :-------------------------------------------: | :-----------------------------------: |
| Cost                                                         |                      $0                       |             ~$25 per $1M              |
| Data storage                                                 |                   Power BI                    |           Data Lake Storage           |
| Estimated maximum raw cost details per month<sup>1</sup>     |       $2M/mo (Pro)<br>$5M/mo (Premium)        |   $2M/mo (Pro)<br>$5M/mo (Premium)    |
| Estimated maximum total with incremental refresh<sup>2</sup> |          $2M (Pro)<br>$5M (Premium)           |      $2M (Pro)<br>$65M (Premium)      |
| Direct data connection (no deployment)                       |                      ✅                       |                  ❌                   |
| Latest API version<sup>3</sup>                               |                      ❌                       |                  ✅                   |
| Azure Government                                             |                      ❌                       |                  ✅                   |
| Azure China                                                  |                      ❌                       |                  🔜                   |
| Enterprise Agreement                                         |                      ✅                       |                  ✅                   |
| Microsoft Customer Agreement                                 |                      ✅                       |                  ✅                   |
| Microsoft Partner Agreement                                  |                      ✅                       |                  ✅                   |
| Microsoft Online Services Agreement                          |                      ❌                       |                  🔜                   |
| Billing accounts                                             |                      ✅                       |                  ✅                   |
| Billing profiles                                             |                      ✅                       |                  ✅                   |
| Invoice sections                                             |                      ❌                       |                  ✅                   |
| CSP customers (partner only)                                 |                      ❌                       |                  ✅                   |
| Management groups                                            |                      ❌                       |                  🔜                   |
| Subscriptions                                                |                      ❌                       |                  ✅                   |
| Resource groups                                              |                      ❌                       |                  ✅                   |
| Supports savings plans<sup>3</sup>                           |                      ❌                       |                  ✅                   |
| Supports savings plan recommendations                        |                      ❌                       |                  ❌                   |
| Supports multiple scopes                                     |                      ❌                       |                  ✅                   |
| Supports scopes in different tenants                         |                      ❌                       |               🔜 (0.2)                |
| Faster data load times                                       |                      ❌                       |                  ✅                   |
| Actual and amortized cost data                               |                      ✅                       |               🔜 (0.2)                |
| Supports >$16M in cost details                               |                      ❌                       |               🔜 (0.3)                |
| Analytical engine                                            |                      ❌                       |               🔜 (0.3)                |
| Can be used outside of Power BI                              |                      ❌                       |                  ✅                   |
| Learn more                                                   | [Learn more](https://aka.ms/costmgmt/powerbi) | [Learn more](../finops-hub/README.md) |

_<sup>1) Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You may see different limits based on services you use and other datasets you ingest.</sup>_

_<sup>2) The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. The FinOps hub estimate is based on incremental refresh being enabled, which requires additional configuration after your report is published.</sup>_

_<sup>3) The Cost Management connector uses an old API version and does not include details for some features, like savings plans. Please use FinOps hubs for the latest version with all details.</sup>_

If you're not sure, start with the Cost Management connector. You will usually be able to tell if that works for you within the first 5-10 minutes. If you experience delays in pulling your data, try requesting fewer months. If you still experience issues, it's time to consider switching to FinOps hubs.

<br>

## ✨ Connect to your data

All FinOps toolkit reports, come with sample data to explore without connecting to your account. Reports have a built-in tutorial to help you connect to your data.

1. Select the **Transform data** button (table with a pencil icon) in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

2. Select **Queries** > **🛠️ Setup** > **▶️ START HERE** and follow the instructions.

   To connect to a FinOps hub instance, you will need the `storageUrlForPowerBI` value from the deployment outputs. Make sure you have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) on the storage account so you can access the data.

   ![Screenshot of instructions to connect to a FinOps hub](https://github.com/microsoft/finops-toolkit/assets/399533/3f53e501-0c83-4362-be6d-f276cf39acaa)

   To connect to the Cost Management connector, you will need the billing account ID and/or billing profile ID. You can find this in [Cost Management configuration settings](https://aka.ms/costmgmt/config) > **Properties**.

   ![Screenshot of instructions to connect to the Cost Management connector](https://github.com/microsoft/finops-toolkit/assets/399533/3bc5eb22-a7e7-4d13-a3a3-91d0bc48800e)

3. Select **Close & Apply** in the toolbar and allow Power BI to refresh to see your data.

For more details, see [How to setup Power BI](./setup.md).

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://github.com/microsoft/finops-toolkit/issues/new/choose){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

{% include tools.md finops-hub optimization-workbook governance-workbook %}
