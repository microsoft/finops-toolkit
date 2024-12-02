---
title: Choose a Power BI data source
description: Learn about different ways to connect Power BI to your data to analyze and report on cloud costs, including connectors and exports.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the different ways to connect Power BI to your data so that I can do it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Choosing a Power BI data source

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](/azure/cost-management-billing/costs/quick-acm-cost-analysis) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following sections to determine the best approach for you.

## At a glance

Use the following as a quick guide for selecting the most appropriate data source for your Power BI reports. If you need more detail, refer to the [comparison table](#comparison-table).

- For costs under $2M in total¹ that don't need savings plan data, you can use the Cost Management connector for Power BI.
  - The connector uses existing raw cost data APIs and cannot scale to data sizes beyond $2M¹.
  - Due to the size constraints, the connector will be phased out by the Cost Management team starting in 2025.
  - The APIs do not include some key columns for savings plans, like the BenefitId/Name columns. All costs are covered but are not always easily identifiable.
- For costs under $2M/month (~$26M total)² that need savings plan data, you can connect to raw exports in Azure Data Lake Storage Gen2.
- For costs under $2M/month (~$26M total)² that need managed exports or to connect to multiple tenants, you can connect to FinOps hubs storage.
- For costs over $2M/month or that need advanced, high performance analytics, you can connect to FinOps hubs with Data Explorer.
  - While not directly supported by FinOps toolkit reports at this time, you can build reports that connect to data in Microsoft Fabric. Direct support will be added in a future release.

_¹ Power BI Pro can handle under $1M of raw cost data. Power BI Premium can handle ~$2M._

_² The $2M limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $26M with incremental refresh enabled._

<br>

## Comparison table

In general, we recommend starting with Power BI reports by connecting to the Cost Management exports. The most common reasons to switch to FinOps hubs are for performance, scale, and to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                    |           Connector           |            Exports             |  FinOps hubs (storage)   |    FinOps hubs (Data Explorer)    |       Microsoft Fabric¹        |
| ----------------------------------------------- | :---------------------------: | :----------------------------: | :----------------------: | :-------------------------------: | :----------------------------: |
| Monthly Azure cost (based on list prices)       |              $0               |          ~$3 per $1M           |       ~$5 per $1M        |   Starts at $120 + ~$10 per $1M   |             $300+              |
| Monthly Power BI cost (based on list prices)    |         $20 per user          |          $20 per user          |       $20 per user       |           $20 per user            |               $0               |
| Data storage                                    |           Power BI            |       Data Lake Storage        |    Data Lake Storage     | Data Lake Storage + Data Explorer |       Data Lake Storage        |
| Est. max raw cost details per month²            |           Up to $2M           |          Up to $2M/mo          |       Up to $2M/mo       |                TBD                |              TBD               |
| Est. max total with incremental refresh²        |           Up to $2M           |           Up to $26M           |        Up to $26M        |                TBD                |              N/A               |
| Latest API version³                             |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Azure Government                                |               ✘               |         In development         |        ✔ (0.1.1)         |          In development           |          ✔ (via Hubs)          |
| Azure China                                     |               ✘               |         In development         |        ✔ (0.1.1)         |          In development           |          ✔ (via Hubs)          |
| Enterprise Agreement                            |    ✔ (billing scopes only)    |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Microsoft Customer Agreement                    |    ✔ (billing scopes only)    |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Microsoft Partner Agreement                     |       ✔ (partners only)       |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Microsoft Online Services Agreement             |               ✘               |               ✘                |            ✘             |                 ✘                 |               ✘                |
| Billing accounts                                |               ✔               |               ✔                |            ✔             |                 ✔                 |
| Billing profiles                                |               ✔               |               ✔                |            ✔             |                 ✔                 |
| Invoice sections                                |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| CSP customers (partner only)                    |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Management groups                               |               ✘               |               ✘                |            ✘             |                 ✘                 |               ✘                |
| Subscriptions                                   |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Resource groups                                 |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Calculate EA and MCA cost savings               |               ✘               |               ✘                |            ✘             |                 ✔                 |     ✔ (via Hubs with ADX)      |
| Supports savings plans³                         |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Supports savings plan recommendations           |               ✘               |               ✘                |      In development      |          In development           |         In development         |
| Supports multiple scopes                        |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Supports scopes in different tenants            |               ✘               |               ✘⁴               |            ✔             |                 ✔                 |          ✔ (via Hubs)          |
| Faster data load times                          |               ✘               |               ✘                |            ✘             |                 ✔                 |               ✔                |
| Supports >$65M in cost details                  |               ✘               |               ✘                |            ✘             |                 ✔                 |               ✔                |
| Accessible outside of Power BI                  |               ✘               |               ✔                |            ✔             |                 ✔                 |               ✔                |
| Kusto Query Language (KQL) support              |               ✘               |               ✘                |            ✘             |                 ✔                 |               ✔                |
| Native integration with Azure Monitor workbooks |               ✘               |               ✘                |            ✘             |          In development           |               ✘                |
| Learn more                                      | [Learn more][about-connector] | [Learn more][about-rawexports] | [Learn more][about-hubs] |     [Learn more][about-hubs]      | [Learn more][about-workspaces] |

[about-connector]: /power-bi/connect-data/desktop-connect-azure-cost-management
[about-rawexports]: ../power-bi/setup.md
[about-hubs]: ../hubs/finops-hubs-overview.md
[about-workspaces]: ../../fabric/create-fabric-workspace-finops.md

_¹ Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports don't support Microsoft Fabric yet._

_² The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. Storage-based estimates are based on incremental refresh being enabled, which requires additional configuration after your report is published._

_³ The Cost Management connector uses an old API version and does not include details for some features, like savings plans. Please use exports or FinOps hubs for the latest version with all details._

_⁴ EA billing scopes can be exported to any tenant today. Sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Other scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today. Supported using a "remote hubs" feature is in development._

If you're unsure where to start, we recommend downloading the Power BI dashboards and connecting them to Cost Management exports in storage. This will allow you to explore the reports and see how they work with your data. Alternatively, you can open the Power BI reports using the provided sample data.

For the best performance and capabilities, we recommend using FinOps hubs with Data Explorer, as it offers exclusive features not available in other options listed above.

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [How to convert Cost Management data to FOCUS](../../focus/convert.md)
- [How to update existing reports to FOCUS](../../focus/mapping.md)

<!-- TODO: Bring in after these resources are moved
- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)
-->

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
