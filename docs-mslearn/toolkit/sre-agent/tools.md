---
title: FinOps SRE Agent tools
description: Review the Kusto and Python tools included with the FinOps SRE Agent for cost analysis, anomaly detection, rate optimization, capacity management, and operations.
author: msbrett
ms.author: brettwil
ms.date: 04/29/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand which tools the FinOps SRE Agent includes so that I can choose the right agent workflow for cost, capacity, and operations analysis.
---

# FinOps SRE Agent tools

The FinOps SRE Agent uses tools to ground agent responses in live Azure and FinOps hub data. Kusto tools query the FinOps hub ADX cluster through the configured Kusto connector. Python tools call Azure REST APIs via the agent managed identity to inspect or update Azure resources.

The FinOps SRE Agent includes 33 tools: 21 Kusto query tools and 12 Python tools.

> [!NOTE]
> The agent list shows subagents that reference each tool in `sre-config/agents`. Tools marked "Not assigned" are included in the tool catalog, but aren't referenced by a subagent configuration.

<br>

## AI cost management

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `ai-cost-by-application` | `Kusto` | Breaks down Azure OpenAI costs by application, team, and environment tags for chargeback, showback, and allocation. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-daily-trend` | `Kusto` | Shows daily Azure OpenAI cost and token trends for AI cost anomaly detection and forecasting. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-model-cost-comparison` | `Kusto` | Compares Azure OpenAI model cost per 1,000 tokens to identify model efficiency opportunities. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-token-usage-breakdown` | `Kusto` | Breaks down Azure OpenAI token consumption by model version and input or output direction. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Cost analysis and reporting

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `costs-enriched-base` | `Kusto` | Returns an enriched cost and usage dataset with toolkit metadata, savings fields, commitment fields, resource helpers, and zero-cost reason enrichment. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `cost-by-financial-hierarchy` | `Kusto` | Reports top costs across billing profile, invoice section, team, product, application, and environment. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `cost-by-region-trend` | `Kusto` | Summarizes effective cost by Azure region to identify regional spend distribution and optimization opportunities. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `monthly-cost-change-percentage` | `Kusto` | Calculates month-over-month billed and effective cost changes to spot spikes, drops, and volatility. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `monthly-cost-trend` | `Kusto` | Returns billed and effective cost totals by month for trend review and budget analysis. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `quarterly-cost-by-resource-group` | `Kusto` | Returns top resource-group cost rows by subscription and month for quarterly reporting windows. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-other-transactions` | `Kusto` | Lists top non-usage, non-commitment purchase transactions, such as Marketplace or miscellaneous charges. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-resource-groups-by-cost` | `Kusto` | Returns top resource groups by effective cost for focused reporting and optimization. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-resource-types-by-cost` | `Kusto` | Returns top resource types by resource count and effective cost to identify costly categories. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-services-by-cost` | `Kusto` | Returns top Azure services by effective cost to prioritize service-level optimization. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Anomaly detection and forecasting

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `cost-anomaly-detection` | `Kusto` | Detects cost spikes and drops with time-series anomaly detection over a configurable history window. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `cost-forecasting-model` | `Kusto` | Forecasts future effective cost from historical cost data for budgeting and trend projection. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `deploy-anomaly-alert` | `Python` | Creates or updates a Cost Management scheduled action for anomaly detection in a subscription. | Not assigned |
| `deploy-bulk-anomaly-alerts` | `Python` | Discovers enabled subscriptions in a management group and deploys anomaly alert scheduled actions per subscription. | Not assigned |

<br>

## Rate optimization

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `benefit-recommendations` | `Python` | Gets Azure Cost Management benefit recommendations for savings plans and reserved instances at a billing scope. | Not assigned |
| `commitment-discount-utilization` | `Kusto` | Analyzes consumed core hours by commitment discount type, including on-demand usage, for a reporting window. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `reservation-recommendation-breakdown` | `Kusto` | Analyzes reservation recommendations, savings, break-even dates, normalized sizes, scope, and term details. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `savings-summary-report` | `Kusto` | Summarizes list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `service-price-benchmarking` | `Kusto` | Benchmarks services by list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `suppress-advisor-recommendations` | `Python` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group with a time to live. | Not assigned |
| `top-commitment-transactions` | `Kusto` | Returns top non-usage commitment discount purchase transactions for reservation and savings plan review. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Capacity management

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `capacity-reservation-groups` | `Python` | Lists capacity reservation groups and compares reserved capacity with allocated virtual machines. | Not assigned |
| `non-compute-quotas` | `Python` | Checks non-compute service quota usage with provider usage APIs and estimated Resource Graph fallbacks. | Not assigned |
| `sku-availability` | `Python` | Lists Azure Compute SKU availability, zones, and regional restriction reasons before planning or deployment. | Not assigned |
| `vm-quota-usage` | `Python` | Reports VM family quota usage by region and flags families above 80% or 95% utilization. | Not assigned |

<br>

## Governance and automation

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `deploy-budget` | `Python` | Creates or updates a subscription-level Cost Management budget with notification contacts. | Not assigned |
| `deploy-bulk-budgets` | `Python` | Discovers enabled subscriptions in a management group and creates or updates a Cost Management budget in each subscription. | Not assigned |
| `resource-graph-query` | `Python` | Runs Azure Resource Graph KQL queries across subscriptions for inventory and configuration troubleshooting. | Not assigned |

<br>

## Data ingestion and health

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `data-freshness-check` | `Python` | Checks FinOps hub function data freshness in Azure Data Explorer and reports stale functions with a two-day threshold. | Not assigned |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)
- [Azure Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps SRE Agent](overview.md)
- [Deploy and configure the FinOps SRE Agent](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
