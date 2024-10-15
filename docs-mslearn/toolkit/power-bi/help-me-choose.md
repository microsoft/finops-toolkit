---
title: Choose a Power BI data source
description: Learn about different ways to connect Power BI to your data to analyze and report on cloud costs, including connectors and exports.
author: bandersmsft
ms.author: banders
ms.date: 10/10/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about the different ways to connect Power BI to your data so that I can do it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Choosing a Power BI data source

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](/azure/cost-management-billing/costs/quick-acm-cost-analysis) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following to determine the best approach for you:

- For costs under $2-5 million in total¹ that don't need savings plan data, you can use the Cost Management connector for Power BI.
   - The connector uses existing raw cost data APIs and can't scale to data sizes beyond $5 million¹.
   - Due to the size constraints, the connector is getting deprecated starting in 2025.
   - The APIs don't include some key columns for savings plans, like the BenefitId/Name columns. All costs are covered but not always easily identifiable.
- For costs under $2-5 million/month (~$65 million total)² that need savings plan data, you can use raw exports with Power BI.
- For costs under $2-5 million/month (~$65 million total)² that need savings plan data, you can use FinOps hubs with Power BI.
- For costs over $5 million/month or for more capabilities, you can connect Fabric to either FinOps hubs or raw exports. [Learn more](../../fabric/create-fabric-workspace-finops.md)
   - FinOps toolkit reports don't directly support Microsoft Fabric. Support for Microsoft Fabric is in development.

_¹ Power BI Pro can handle ~$2 million of raw cost data. Power BI Premium can handle ~$5 million._

_² The $2-5 million limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $65 million with incremental refresh enabled._

<br>

## Comparison table

In general, we recommend starting with the Cost Management connector when getting started with Power BI reports. The most common reasons to switch to FinOps hubs are for more account types and scopes or to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                        |            Connector             |             Exports              |           FinOps hubs            |  Microsoft Fabric¹  |
| --------------------------------------------------- | ------------------------------ | ------------------------------ | ------------------------------ | ---------------------------- |
| Azure cost (based on list prices)                   |                $0                |           ~$3 per $1 million            |           ~$5 per $1 million            |          ~$3 per $1 million           |
| Power BI cost                                       |           $10-20/user            |           $10-20/user            |           $10-20/user            |             $300+              |
| Data storage                                        |             Power BI             |        Data Lake Storage         |        Data Lake Storage         |       Data Lake Storage        |
| Est. max raw cost details per month²     | $2 million/mo (Pro)<br>$5 million/mo (Premium) | $2 million/mo (Pro)<br>$5 million/mo (Premium) | $2 million/mo (Pro)<br>$5 million/mo (Premium) |              TBD               |
| Est. max total with incremental refresh³ |    $2 million (Pro)<br>$5 million (Premium)    |   $2 million (Pro)<br>$65 million (Premium)    |   $2M (Pro)<br>$65 million (Premium)    |              TBD               |
| Doesn't require a deployment                       |                ✔                 |         ✘ (storage only)         |   ✘ ([details][hubs-template])   |               ✘                |
| Latest API version⁴                      |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Azure Government                                    |                ✘                 |                In development                 |            ✔ (0.1.1)             |          ✔ (via Hubs)          |
| Azure China 21Vianet                                         |                ✘                 |                In development                 |            ✔ (0.1.1)             |          ✔ (via Hubs)          |
| Enterprise Agreement                                |                ✔                 |                ✔                 |                ✔                 |               ✔                |
| Microsoft Customer Agreement                        |                ✔                 |                ✔                 |                ✔                 |               ✔                |
| Microsoft Partner Agreement                         |                ✔                 |                ✔                 |                ✔                 |               ✔                |
| Microsoft Online Services Agreement                 |                ✘                 |                ✘                 |                ✘                 |              ✘               |
| Billing accounts                                    |                ✔                 |                ✔                 |                ✔                 |               ✔                |
| Billing profiles                                    |                ✔                 |                ✔                 |                ✔                 |               ✔                |
| Invoice sections                                    |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| CSP customers (partner only)                        |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Management groups                                   |                ✘                 |                ✘                 |                ✘                 |              ✘               |
| Subscriptions                                       |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Resource groups                                     |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Supports savings plans⁴                  |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Supports savings plan recommendations               |                ✘                 |                ✘                 |                In development                 |               In development                |
| Supports multiple scopes                            |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Supports scopes in different tenants⁵    |                ✘                 |          ✘⁵           |                ✔                 |          ✔ (via Hubs)          |
| Faster data load times                              |                ✘                 |                In development                 |                ✔                 |          ✔ (via Hubs)          |
| Supports >$65M in cost details                      |                ✘                 |                ✘                 |             In development (0.7)              |              ✔               |
| Analytical engine                                   |                ✘                 |                ✘                 |             In development (0.7)              |              ✔               |
| Accessible outside of Power BI                      |                ✘                 |                ✔                 |                ✔                 |               ✔                |
| Learn more                                          |  [Learn more][about-connector]   |                                  |     [Learn more][about-hubs]     | [Learn more][about-workspaces] |

[about-connector]: /power-bi/connect-data/desktop-connect-azure-cost-management
[about-hubs]: ../hubs/finops-hubs-overview.md
[about-workspaces]: ../../fabric/create-fabric-workspace-finops.md
[hubs-template]: ../hubs/template.md

_¹ Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports don't support Microsoft Fabric yet. Development is underway._

_² Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You might see different limits based on services you use and other datasets you ingest._

_³ The Cost Management connector for Power BI doesn't support incremental refresh, so the limits are the same as the per-month estimation. The FinOps hub estimate is based on incremental refresh being enabled, which requires extra configuration after your report is published._

_⁴ The Cost Management connector uses an old API version and doesn't include details for some features, like savings plans. Use FinOps hubs for the latest version with all details._

_⁵ EA billing scopes can be exported to any tenant today. Sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Nonbilling scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today. Supported using a "remote hubs" feature is in development._

If you're not sure, start with the Cost Management connector. You can often tell if that works for you within the first 5-10 minutes. If you experience delays in pulling your data, try requesting fewer months. If you still experience issues, it's time to consider switching to FinOps hubs.

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
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [FinOps toolkit open data](../open-data.md)

<br>