---
title: Power BI
description: Learn about the different ways to connect Power BI to your data.
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Choosing a Power BI data source

Microsoft offers several ways to analyze and report on your cloud costs. For quick exploration of subscriptions and billing accounts, we recommend starting with smart views in [Cost analysis](https://learn.microsoft.com/azure/cost-management-billing/costs/quick-acm-cost-analysis) in the Azure portal or Microsoft 365 admin center. When you need more control or to save and share charts, switch to customizable views.

When you need more advanced reporting or to merge with your own data, we recommend using Microsoft Fabric, Power BI, or a custom or third-party solution. Use the following to determine the best approach for you:

1. For costs under $2-5M in total<sup>1</sup> that don't need savings plan data, you can use the Cost Management connector for Power BI.
   - The connector uses existing raw cost data APIs and cannot scale to data sizes beyond $5M<sup>1</sup>.
   - Due to the size constraints, the connector will be phased out by the Cost Management team starting in 2025.
   - The APIs do not include some key columns for savings plans, like the BenefitId/Name columns. All costs are covered but not always easily identifiable.
2. For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use raw exports with Power BI.
3. For costs under $2-5M/month (~$65M total)<sup>2</sup> that need savings plan data, you can use FinOps hubs with Power BI.
4. For costs over $5M/month or for additional capabilities, you can connect Fabric to either FinOps hubs or raw exports. [Learn more](../../fabric/create-fabric-workspace-finops.md)
   - Please note FinOps toolkit reports do not directly support Microsoft Fabric. Support for Microsoft Fabric will be added in a future release.

_<sup>1) Power BI Pro can handle ~$2M of raw cost data. Power BI Premium can handle ~$5M.</sup>_

_<sup>2) The $2-5M limits are for Power BI data refreshes and apply on a monthly basis for hubs and raw exports. They can load up to $65M with incremental refresh enabled.</sup>_

<br>

## Comparison table

In general, we recommend starting with the Cost Management connector when getting started with Power BI reports. The most common reasons to switch to FinOps hubs are for additional account types and scopes or to enable more advanced capabilities. Use the following comparison to help you make the decision:

| Capabilities                                        |            Connector             |             Exports              |           FinOps hubs            |  Microsoft Fabric<sup>1</sup>  |
| --------------------------------------------------- | :------------------------------: | :------------------------------: | :------------------------------: | :----------------------------: |
| Azure cost (based on list prices)                   |                $0                |           ~$3 per $1M            |           ~$5 per $1M            |          ~$3 per $1M           |
| Power BI cost                                       |           $10-20/user            |           $10-20/user            |           $10-20/user            |             $300+              |
| Data storage                                        |             Power BI             |        Data Lake Storage         |        Data Lake Storage         |       Data Lake Storage        |
| Est. max raw cost details per month<sup>2</sup>     | $2M/mo (Pro)<br>$5M/mo (Premium) | $2M/mo (Pro)<br>$5M/mo (Premium) | $2M/mo (Pro)<br>$5M/mo (Premium) |              TBD               |
| Est. max total with incremental refresh<sup>3</sup> |    $2M (Pro)<br>$5M (Premium)    |   $2M (Pro)<br>$65M (Premium)    |   $2M (Pro)<br>$65M (Premium)    |              TBD               |
| Does not require a deployment                       |                ✅                 |         ❌ (storage only)         |   ❌ ([details][hubs-template])   |               ❌                |
| Latest API version<sup>4</sup>                      |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Azure Government                                    |                ❌                 |                🔜                 |            ✅ (0.1.1)             |          ✅ (via Hubs)          |
| Azure China                                         |                ❌                 |                🔜                 |            ✅ (0.1.1)             |          ✅ (via Hubs)          |
| Enterprise Agreement                                |                ✅                 |                ✅                 |                ✅                 |               ✅                |
| Microsoft Customer Agreement                        |                ✅                 |                ✅                 |                ✅                 |               ✅                |
| Microsoft Partner Agreement                         |                ✅                 |                ✅                 |                ✅                 |               ✅                |
| Microsoft Online Services Agreement                 |                ❌                 |         ❌ (if requested)         |         ❌ (if requested)         |               ❌                |
| Billing accounts                                    |                ✅                 |                ✅                 |                ✅                 |               ✅                |
| Billing profiles                                    |                ✅                 |                ✅                 |                ✅                 |               ✅                |
| Invoice sections                                    |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| CSP customers (partner only)                        |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Management groups                                   |                ❌                 |         ❌ (if requested)         |         ❌ (if requested)         |               ❌                |
| Subscriptions                                       |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Resource groups                                     |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Supports savings plans<sup>4</sup>                  |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Supports savings plan recommendations               |                ❌                 |                ❌                 |                🔜                 |               🔜                |
| Supports multiple scopes                            |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Supports scopes in different tenants<sup>5</sup>    |                ❌                 |          ❌<sup>5</sup>           |                ✅                 |          ✅ (via Hubs)          |
| Faster data load times                              |                ❌                 |                🔜                 |                ✅                 |          ✅ (via Hubs)          |
| Supports >$65M in cost details                      |                ❌                 |                ❌                 |             🔜 (0.6)              |               ✅                |
| Analytical engine                                   |                ❌                 |                ❌                 |             🔜 (0.6)              |               ✅                |
| Accessible outside of Power BI                      |                ❌                 |                ✅                 |                ✅                 |               ✅                |
| Learn more                                          |  [Learn more][about-connector]   |                                  |     [Learn more][about-hubs]     | [Learn more][about-workspaces] |

[about-connector]: /power-bi/connect-data/desktop-connect-azure-cost-management
[about-hubs]: ../hubs/finops-hubs-overview.md
[about-workspaces]: ../../fabric/create-fabric-workspace-finops.md
[hubs-template]: ../hubs/template.md

_<sup>1) Microsoft Fabric can connect to either raw exports or FinOps hubs. FinOps toolkit reports do not support Microsoft Fabric yet but will in a future release.</sup>_

_<sup>2) Power BI constraints are based on data size and processing time. Monitored spend estimations are for reference only. You may see different limits based on services you use and other datasets you ingest.</sup>_

_<sup>3) The Cost Management connector for Power BI does not support incremental refresh, so the limits are the same as the per-month estimation. The FinOps hub estimate is based on incremental refresh being enabled, which requires additional configuration after your report is published.</sup>_

_<sup>4) The Cost Management connector uses an old API version and does not include details for some features, like savings plans. Please use FinOps hubs for the latest version with all details.</sup>_

_<sup>5) EA billing scopes can be exported to any tenant today. Simply sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Non-billing scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today but will be supported via a "remote hubs" feature in a future FinOps hubs release.</sup>_

If you're not sure, start with the Cost Management connector. You will usually be able to tell if that works for you within the first 5-10 minutes. If you experience delays in pulling your data, try requesting fewer months. If you still experience issues, it's time to consider switching to FinOps hubs.

<br>
