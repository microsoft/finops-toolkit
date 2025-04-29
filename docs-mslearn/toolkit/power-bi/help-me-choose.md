---
title: Choose a Power BI data source
description: Learn about different ways to connect Power BI to your data to analyze and report on cloud costs, including connectors and exports.
author: flanakin
ms.author: micflan
ms.date: 04/29/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the different ways to connect Power BI to your data so that I can do it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Choosing a Power BI data source

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](/azure/cost-management-billing/costs/quick-acm-cost-analysis) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following sections to determine the best approach for you.

<br>

## At a glance

Use the following list as a quick guide for selecting a recommended data source for your Power BI reports. If you need more detail, refer to the [comparison table](#comparison-table). The following list is based on $100K due to the cost of recommended solutions to keep cost under 0.2% of monitored spend.

- If you need to monitor **less than $100K**:
  - Start with raw exports in Azure Data Lake Storage Gen2.
  - If you need to pull data from multiple tenants, use FinOps hubs with remote hubs.
  - If you need to schedule export times, use FinOps hubs with managed exports (EA only).
- If you need to monitor **more than $100K** and don't use Microsoft Fabric:
  - Start with FinOps hubs with Data Explorer.
- If you need to monitor **more than $100K** and use **Microsoft Fabric**:
  - If you don't need pre-built reports, use raw exports to OneLake.
  - If you want pre-built reports, use FinOps hubs with Real-Time Intelligence.

For the **best performance** and **most capabilities**, we recommend **FinOps hubs with Microsoft Fabric Real-Time Intelligence**.

For the **best performance** at **lower cost**, we recommend **FinOps hubs with Data Explorer**.

For the **quickest setup** at the **lowest cost**, use **raw Cost Management exports**.

The Cost Management connector and app for Power BI are free, available, and supported, but **not recommended** due to performance, data completeness, and functionality limitations. The connector and app are not being maintained and will not have feature updates. The app is only supported for EA accounts and will not be updated to support MCA accounts.

<br>

## Comparison table

The following table outlines the supported features by each data source option. Storage covers both raw exports to storage and FinOps hubs with storage.

| Capabilities                                     |           Connector           |                 Storage                  |  FinOps hubs + Data Explorer  |         Fabric OneLake         | Fabric RTI (via FinOps hubs)  |
| ------------------------------------------------ | :---------------------------: | :--------------------------------------: | :---------------------------: | :----------------------------: | :---------------------------: |
| Monthly Azure cost (based on list prices)        |              $0               |              ~$3-5 per $1M¹              | Starts at $120 + ~$10 per $1M |         Starts at $300         | Starts at $300 + ~$10 per $1M |
| Monthly Power BI cost (based on list prices)     |         $20 per user          |               $20 per user               |    $20 per user (optional)    |               $0               |              $0               |
| Data storage                                     |           Power BI            |            Data Lake Storage             |         Data Explorer         |            OneLake             |    Real-Time Intelligence     |
| Est. max cost data                               |          Up to $2M²           | Up to $2M/mo<br>with incremental refresh |              N/A              |              N/A               |              N/A              |
| Supported by FinOps toolkit reports              |               ✅               |                    ✅                     |               ✅               |               ❌                |               ✅               |
| Latest API version³                              |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Azure Gov + Azure China                          |               ❌               |                    ✅                     |               ✅               |               ❌                |               ❌               |
| Enterprise Agreement                             |  ☑️<br>(billing scopes only)   |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Microsoft Customer Agreement                     |  ☑️<br>(billing scopes only)   |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Microsoft Partner Agreement                      |     ☑️<br>(partners only)      |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Microsoft Online Services Agreement              |               ❌               |                    ❌                     |               ❌               |               ❌                |               ❌               |
| Billing accounts and billing profiles            |               ✅               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Invoice sections                                 |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Cloud Solution Provider customers (partner only) |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Management groups                                |               ❌               |                    ❌                     |               ❌               |               ❌                |               ❌               |
| Subscriptions and resource groups                |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Calculate EA and MCA cost savings                |               ❌               |                    ✅                     |               ✅               |               ❌                |               ✅               |
| Supports savings plans³                          |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Supports multiple scopes                         |               ❌               |                    ✅                     |               ✅               |               ✅                |               ✅               |
| Supports scopes in different tenants             |               ❌               |         ☑️<br>(via FinOps hubs¹)          |               ✅               |               ❌                |               ✅               |
| Faster data load times                           |               ❌               |                    ❌                     |               ✅               |               ✅                |               ✅               |
| Supports >$65M in cost details                   |               ❌               |                    ❌                     |               ✅               |               ✅                |               ✅               |
| Accessible outside of Power BI                   |               ❌               |           ✅<br>(CSV/parquet¹)            |     ✅<br>(parquet or API)     |   ✅<br>(CSV/parquet or API)    |     ✅<br>(parquet or API)     |
| Kusto Query Language (KQL) support               |               ❌               |                    ❌                     |               ✅               |    ☑️<br>(small perf impact)    |               ✅               |
| Data Explorer / Real-Time dashboard support      |               ❌               |                    ❌                     |               ✅               |               ❌                |               ✅               |
| Azure Monitor workbooks support                  |               ❌               |                    ❌                     |               ✅               |               ❌                |               ✅               |
| Learn more                                       | [Learn more][about-connector] |      [Learn more][about-rawexports]      |   [Learn more][about-hubs]    | [Learn more][about-workspaces] |   [Learn more][about-hubs]    |

[about-connector]: /power-bi/connect-data/desktop-connect-azure-cost-management
[about-rawexports]: ../power-bi/setup.md
[about-hubs]: ../hubs/finops-hubs-overview.md
[about-workspaces]: ../../fabric/create-fabric-workspace-finops.md

_¹ FinOps hubs include a Data Factory pipeline for added benefits on top of Cost Management exports. Pipeline costs are $2/mo per $1 million in spend based on list prices and add support for multiple tenants, scheduling export times, and parquet data conversion._

_² The Cost Management connector for Power BI doesn't support incremental refresh, so the limits are the same as the per-month estimation. Storage-based estimates are based on incremental refresh being enabled, which requires configuration after your report is published._

_³ The Cost Management connector uses an old API version and doesn't include details for some features, like savings plans. Use exports or FinOps hubs for the latest version with all details._

If you're unsure where to start, follow the [at a glance](#at-a-glance) guide above.

<br>

## Related content

Related resources:

- [What is FOCUS?](../../focus/what-is-focus.md)
- [How to convert Cost Management data to FOCUS](../../focus/convert.md)
- [How to update existing reports to FOCUS](../../focus/mapping.md)
- [Common terms](../help/terms.md)
- [Data dictionary](../help/data-dictionary.md)

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
