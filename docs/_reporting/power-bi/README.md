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

The FinOps toolkit includes two sets of reports that connect to different data sources. We recommend using the following reports which connect to Cost Management exports or [FinOps hubs](../hubs/README.md):

- [Cost summary](./cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Rate optimization](./rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.
- [Workload optimization](./workload-optimization.md) – Summarizes opportunities to achieve resource cost and usage efficiencies.
- [Cloud policy and governance](./governance.md) – Summarize cloud governance posture including areas like compliance, security, operations, and resource management.
- [Data ingestion](./data-ingestion.md) – Provides insights into your data ingestion layer.

The following reports use the Cost Management connector for Power BI to connect to your data. While the connector is not recommended due to the reasons below, these reports will be available as long as the connector is supported by the Cost Management team.

- [Cost Management connector](./connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for EA and MCA accounts.
- [Cost Management template app](./template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .mb-4 .mb-md-0 .mr-4 }
[How to setup](#-connect-to-your-data){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## ⚖️ Help me choose

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](https://aka.ms/costanalysis/docs) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following to determine the best approach for you:

1. **Power BI on Cost Exports**: For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use raw exports with Power BI.
2. **FinOps Hubs on Azure Data Factory**: For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use FinOps hubs with Power BI.
3. 🆕 **FinOps Hubs on Azure Data Explorer (ADX)**:  For scenarios where you need more advanced exploration, Hubs on ADX allows you to leverage Kusto Query Language (KQL) for in-depth analysis and provides built-in queries to simplify data exploration. ADX also offers scalability, allowing you to increase capacity by adjusting the virtual machine size. The default VM size supports up to $10M/month of cost data.
4. _**Coming soon:**_ For costs over $5M/month or for additional capabilities, you can connect Fabric to either FinOps hubs or raw exports.
   - This is possible today, but is not supported in FinOps toolkit reports yet. Support will be added in a future release.

_<sup>1) Power BI Pro can handle ~$2M of raw cost data. Power BI Premium can handle ~$5M.</sup>_

_<sup>2) The $2-5M limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $65M with incremental refresh enabled.</sup>_

_<sup>3) ❗ The Cost Management connector is no longer recommended as it will be deprecated soon.</sup>_

In general, we recommend starting with the Cost Management connector when getting started with Power BI reports. The most common reasons to switch to FinOps hubs are for additional account types and scopes or to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                        |             Exports              |        FinOps hubs on ADF         |        FinOps hubs on ADX         | Microsoft Fabric<sup>1</sup> |
| --------------------------------------------------- | :------------------------------: | :------------------------------: | :------------------------------: | :--------------------------: |
| Cost (based on list prices)                         |           ~$10 per $1M           |           ~$25 per $1M           |            ~$220 per month<sup>2</sup>        |             TBD              |
| Data storage                                        |        Data Lake Storage         |        Data Lake Storage         | Data Lake Storage + Azure Data Explorer |      Data Lake Storage       |
| Est. max raw cost details per month<sup>3</sup>     | $2M/mo (Pro)<br>$5M/mo (Premium) | $2M/mo (Pro)<br>$5M/mo (Premium) |                                  |             TBD              |
| Est. max total with incremental refresh<sup>4</sup> |   $2M (Pro)<br>$65M (Premium)    |   $2M (Pro)<br>$65M (Premium)    |                                  |             TBD              |
| Azure Government                                    |                🔜                 |            ✅ (0.1.1)             |             🔜                |         ✅ (via Hubs)         |
| Azure China                                         |                🔜                 |            ✅ (0.1.1)             |             🔜               |         ✅ (via Hubs)         |
| Enterprise Agreement                                |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Microsoft Customer Agreement                        |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Microsoft Partner Agreement                         |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Microsoft Online Services Agreement                 |                ❌                 |                ❌                 |                                  |              ❌               |
| Billing accounts                                    |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Billing profiles                                    |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Invoice sections                                    |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| CSP customers (partner only)                        |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Management groups                                   |                ❌                 |                ❌                 |             ✅                     |              ❌               |
| Subscriptions                                       |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Resource groups                                     |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Supports savings plans<sup>4</sup>                  |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Supports savings plan recommendations               |                ❌                 |                🔜                 |             ✅                     |              🔜               |
| Supports multiple scopes                            |                ✅                 |                ✅                 |             ✅                     |              ✅               |
| Supports scopes in different tenants<sup>5</sup>    |          ⚠️<sup>5</sup>           |          ⚠️<sup>5</sup>           |                                  |          ⚠️<sup>5</sup>(via Hubs) |
| Faster data load times                              |                🔜                 |                ✅                 |             ✅                |         ✅ (via Hubs)         |
| Supports >$65M in cost details                      |                ❌                 |                ✅              |                                  |              ✅               |
| Analytical engine                                   |                ❌                 |                ✅              |                ✅               |              ✅               |
| Accessible outside of Power BI                      |                ✅                 |                ✅                 |             ✅                |              ✅               |
| Kusto Query Language support                      |                  ❌                |                ❌                 |             ✅                |              ❌               |
| Native integraiton with Advisor Cost Optimization Workbook |                  ❌                |                ❌                 |             ✅                |              ❌               |
| Azure Portal built-in dashboards |                  ❌                |                ❌                 |             ✅                |              ❌               |
| Learn more                                          |                                    |     [Learn more][about-hubs]     |                                  |                              |



_<sup>1) Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports do not support Microsoft Fabric yet but will in a future release.</sup>_

_<sup>1) Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports do not support Microsoft Fabric yet but will in a future release.</sup>_

<sup>2) The estimated cost of Hubs on ADX assumes the two instances are running 24x7. Costs can be reduced by enabling auto-shutdown outside of business hours or applying commitment discounts. Prices are estiamted in UK North as of October 2024</sup>


_<sup>3) Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You may see different limits based on services you use and other datasets you ingest.</sup>_

_<sup>4) The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. The FinOps hub estimate is based on incremental refresh being enabled, which requires additional configuration after your report is published.</sup>_

_<sup>5) EA billing scopes can be exported to any tenant today. Simply sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Non-billing scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today but will be supported via a "remote hubs" feature in a future FinOps hubs release.</sup>_

If you're not sure, start with the the Power BI experience with Cost Exports. You will usually be able to tell if that works for you within the first 5-10 minutes. If you are xxx ❌  ❌  ❌  

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
