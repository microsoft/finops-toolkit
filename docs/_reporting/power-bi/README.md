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

<br>

## 📈 Available reports

The FinOps toolkit includes reports that connect to different data sources. We recommend using the following reports which connect to Cost Management exports or [FinOps hubs](../hubs/README.md):

- [Cost summary](./cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Rate optimization](./rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.
- [Workload optimization](./workload-optimization.md) – Summarizes opportunities to achieve resource cost and usage efficiencies.
- [Cloud policy and governance](./governance.md) – Summarize cloud governance posture including areas like compliance, security, operations, and resource management.
- [Data ingestion](./data-ingestion.md) – Provides insights into your data ingestion layer.

If you need to monitor more than $5M in spend, we generally recommend using KQL-based reports that connect to [FinOps hubs](../hubs/README.md) with Azure Data Explorer. As of November 2024, only the Cost summary and Rate optimization reports connect to Data Explorer. Additional reports will come in future updates. Organizations who need other reports can continue to connect to the underlying hub storage account.

In addition, the following reports use the Cost Management connector for Power BI to connect to your data. While the connector is not recommended, these reports will be available as long as the connector is supported by the Cost Management team.

- [Cost Management connector](./connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for EA and MCA accounts.
- [Cost Management template app](./template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .mb-4 .mb-md-0 .mr-4 }
[How to setup](#-connect-to-your-data){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## ⚖️ Help me choose

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](https://aka.ms/costanalysis/docs) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following to determine the best approach for you:

1. For costs under $2M in total<sup>1</sup> that don't need savings plan data, you can use the Cost Management connector for Power BI.
   - The connector uses existing raw cost data APIs and cannot scale to data sizes beyond $2M<sup>1</sup>.
   - Due to the size constraints, the connector will be phased out by the Cost Management team starting in 2025.
   - The APIs do not include some key columns for savings plans, like the BenefitId/Name columns. All costs are covered but are not always easily identifiable.
2. For costs under $2M/month (~$26M total)<sup>2</sup> that need savings plan data, you can connect to raw exports in Azure Data Lake Storage Gen2.
3. For costs under $2M/month (~$26M total)<sup>2</sup> that need managed exports or to connect to multiple tenants, you can connect to FinOps hubs storage.
4. For costs over $2M/month or that need advanced, high performance analytics, you can connect to FinOps hubs with Data Explorer.
   - While not directly supported by FinOps toolkit reports at this time, you can build reports that connect to data in Microsoft Fabric. Direct support will be added in a future release.

_<sup>1) Power BI Pro can handle under $1M of raw cost data. Power BI Premium can handle ~$2M.</sup>_

_<sup>2) The $2M limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $26M with incremental refresh enabled.</sup>_

In general, we recommend starting with Power BI reports by connecting to the Cost Management exports. The most common reasons to switch to FinOps hubs are for performance, scale, and to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                        |           Connector           |            Exports             |  FinOps hubs (storage)   |       FinOps hubs (Data Explorer)       | Microsoft Fabric<sup>1</sup> |
| --------------------------------------------------- | :---------------------------: | :----------------------------: | :----------------------: | :-------------------------------------: | :--------------------------: |
| Monthly Azure cost (based on list prices)           |              $0               |          ~$3 per $1M           |       ~$5 per $1M        |      Starts at $120 + ~$10 per $1M      |            $300+             |
| Monthly Power BI cost (based on list prices)        |         $20 per user          |          $20 per user          |       $20 per user       |              $20 per user               |              $0              |
| Data storage                                        |           Power BI            |       Data Lake Storage        |    Data Lake Storage     | Data Lake Storage + Azure Data Explorer |      Data Lake Storage       |
| Est. max raw cost details per month<sup>3</sup>     |           Up to $2M           |          Up to $2M/mo          |       Up to $2M/mo       |                   TBD                   |             TBD              |
| Est. max total with incremental refresh<sup>3</sup> |           Up to $2M           |           Up to $26M           |        Up to $26M        |                   TBD                   |             N/A              |
| Latest API version<sup>4</sup>                      |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Azure Government                                    |               ❌               |               🔜                |        ✅ (0.1.1)         |                    🔜                    |         ✅ (via Hubs)         |
| Azure China                                         |               ❌               |               🔜                |        ✅ (0.1.1)         |                    🔜                    |         ✅ (via Hubs)         |
| Enterprise Agreement                                |    ✅ (billing scopes only)    |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Microsoft Customer Agreement                        |    ✅ (billing scopes only)    |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Microsoft Partner Agreement                         |       ✅ (partners only)       |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Microsoft Online Services Agreement                 |               ❌               |               ❌                |            ❌             |                    ❌                    |              ❌               |
| Billing accounts                                    |               ✅               |               ✅                |            ✅             |                    ✅                    |
| Billing profiles                                    |               ✅               |               ✅                |            ✅             |                    ✅                    |
| Invoice sections                                    |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| CSP customers (partner only)                        |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Management groups                                   |               ❌               |               ❌                |            ❌             |                    ❌                    |              ❌               |
| Subscriptions                                       |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Resource groups                                     |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Calculate EA and MCA cost savings                   |               ❌               |               ❌                |            ❌             |                    ✅                    |    ✅ (via Hubs with ADX)     |
| Supports savings plans<sup>4</sup>                  |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Supports savings plan recommendations               |               ❌               |               ❌                |            🔜             |                    🔜                    |              🔜               |
| Supports multiple scopes                            |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Supports scopes in different tenants                |               ❌               |         ❌<sup>5</sup>          |            ✅             |                    ✅                    |         ✅ (via Hubs)         |
| Faster data load times                              |               ❌               |               ❌                |            ❌             |                    ✅                    |              ✅               |
| Supports >$65M in cost details                      |               ❌               |               ❌                |            ❌             |                    ✅                    |              ✅               |
| Accessible outside of Power BI                      |               ❌               |               ✅                |            ✅             |                    ✅                    |              ✅               |
| Kusto Query Language (KQL) support                  |               ❌               |               ❌                |            ❌             |                    ✅                    |              ✅               |
| Native integration with Azure Monitor workbooks     |               ❌               |               ❌                |            ❌             |                    🔜                    |              ❌               |
| Learn more                                          | [Learn more][about-connector] | [Learn more][about-rawexports] | [Learn more][about-hubs] |        [Learn more][about-hubs]         |   [Learn more][about-hubs]   |

[about-connector]: https://aka.ms/costmgmt/powerbi
[about-hubs]: ../hubs/README.md
[about-rawexports]: ../power-bi/setup.md
[hubs-template]: ../hubs/template.md

_<sup>1) Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports do not support Microsoft Fabric yet but will in a future release.</sup>_

_<sup>2) Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You may see different limits based on services you use and other datasets you ingest.</sup>_

_<sup>3) The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. Storage-based estimates are based on incremental refresh being enabled, which requires additional configuration after your report is published.</sup>_

_<sup>4) The Cost Management connector uses an old API version and does not include details for some features, like savings plans. Please use exports or FinOps hubs for the latest version with all details.</sup>_

_<sup>5) EA billing scopes can be exported to any tenant today. Simply sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Non-billing scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today but will be supported via a "remote hubs" feature in a future FinOps hubs release.</sup>_

If you're unsure where to start, we recommend downloading the Power BI dashboards and connecting them to Cost Management exports in storage. This will allow you to explore the reports and see how they work with your data. Alternatively, you can open the Power BI reports using the provided sample data.

For the best performance and capabilities, we recommend using FinOps hubs with Data Explorer, as it offers exclusive features not available in other options listed above.

<br>

## ✨ Connect to your data

All FinOps toolkit reports, come with sample data to explore without connecting to your account. Reports have a built-in tutorial to help you connect to your data.

1. Configure Cost Management exports for any data you would like to include in reports, including:

   - Cost and usage (FOCUS) &ndash; Required for all reports.
   - Price sheet
   - Reservation details
   - Reservation recommendations &ndash; Required to see reservation recommendations in the Rate optimization report.
   - Reservation transactions

2. Select the **Transform data** button (table with a pencil icon) in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

3. Select **Queries** > **🛠️ Setup** > **▶ START HERE** and follow the instructions.

   Make sure you have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) on the storage account so you can access the data.

   ![Screenshot of instructions to connect to a storage account](https://github.com/user-attachments/assets/3723c94b-d853-420e-9101-98d1ca518fa0)

4. Select **Close & Apply** in the toolbar and allow Power BI to refresh to see your data.

For more details, see [How to setup Power BI](./setup.md).

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" opt="1" gov="1" data="1" %}

<br>
