---
title: FinOps toolkit SRE Agent tools
description: Review the Kusto and Python tools included with the FinOps toolkit SRE Agent for cost analysis, anomaly detection, rate optimization, capacity management, and operations.
author: msbrett
ms.author: brettwil
ms.date: 05/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand which tools the FinOps toolkit SRE Agent includes so that I can choose the right agent workflow for cost, capacity, and operations analysis.
---

# FinOps toolkit SRE Agent tools

The FinOps toolkit SRE Agent uses tools to ground agent responses in live Azure and FinOps hub data. [Kusto tools](kusto-tools.md) query the FinOps hub Azure Data Explorer database, and [Python tools](python-tools.md) call Azure APIs through the agent managed identity.

Use this article as a catalog of the tools included with the template. For deeper implementation details, review the [Kusto tools](kusto-tools.md) and [Python tools](python-tools.md) references.

The agent includes 33 tools: 21 Kusto query tools and 12 Python tools, as documented in the [Kusto tools](kusto-tools.md) and [Python tools](python-tools.md) references.

> [!NOTE]
> The agent list shows subagents that reference each tool in `sre-config/agents`. Tools marked "Not assigned" are included in the tool catalog, but aren't referenced by a subagent configuration. For agent roles and tool usage, see [agents and skills](agents.md).

<br>

## AI cost management

AI cost management tools help agents analyze Azure OpenAI spend, token usage, model efficiency, and application-level allocation, as described in [AI/ML costs](kusto-tools.md#aiml-costs).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `ai-cost-by-application` | `Kusto` | Breaks down Azure OpenAI costs by application, team, and environment tags for chargeback, showback, and allocation; see [ai-cost-by-application](kusto-tools.md#ai-cost-by-application). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-daily-trend` | `Kusto` | Shows daily Azure OpenAI cost and token trends for AI cost anomaly detection and forecasting; see [ai-daily-trend](kusto-tools.md#ai-daily-trend). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-model-cost-comparison` | `Kusto` | Compares Azure OpenAI model cost per 1,000 tokens to identify model efficiency opportunities; see [ai-model-cost-comparison](kusto-tools.md#ai-model-cost-comparison). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `ai-token-usage-breakdown` | `Kusto` | Breaks down Azure OpenAI token consumption by model version and input or output direction; see [ai-token-usage-breakdown](kusto-tools.md#ai-token-usage-breakdown). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Cost analysis and reporting

Cost analysis and reporting tools summarize FinOps hub cost data by service, region, resource group, financial hierarchy, transaction type, and time period, as described in [Cost analysis](kusto-tools.md#cost-analysis) and [Price analysis](kusto-tools.md#price-analysis).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `costs-enriched-base` | `Kusto` | Returns a guarded row-level enriched cost and usage sample for narrow drill-downs; see [costs-enriched-base](kusto-tools.md#costs-enriched-base). Use aggregate tools for full-month, fiscal-period, scheduled report, and tag-coverage rollup requests. | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `cost-by-financial-hierarchy` | `Kusto` | Reports top costs across billing profile, invoice section, team, product, application, and environment; see [cost-by-financial-hierarchy](kusto-tools.md#cost-by-financial-hierarchy). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `cost-by-region-trend` | `Kusto` | Summarizes effective cost by Azure region to identify regional spend distribution and optimization opportunities; see [cost-by-region-trend](kusto-tools.md#cost-by-region-trend). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `monthly-cost-change-percentage` | `Kusto` | Calculates month-over-month billed and effective cost changes to spot spikes, drops, and volatility; see [monthly-cost-change-percentage](kusto-tools.md#monthly-cost-change-percentage). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `monthly-cost-trend` | `Kusto` | Returns billed and effective cost totals by month for trend review and budget analysis; see [monthly-cost-trend](kusto-tools.md#monthly-cost-trend). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `quarterly-cost-by-resource-group` | `Kusto` | Returns top resource-group cost rows by subscription and month for quarterly reporting windows; see [quarterly-cost-by-resource-group](kusto-tools.md#quarterly-cost-by-resource-group). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-other-transactions` | `Kusto` | Lists top non-usage, non-commitment purchase transactions, such as Marketplace or miscellaneous charges; see [top-other-transactions](kusto-tools.md#top-other-transactions). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-resource-groups-by-cost` | `Kusto` | Returns top resource groups by effective cost for focused reporting and optimization; see [top-resource-groups-by-cost](kusto-tools.md#top-resource-groups-by-cost). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-resource-types-by-cost` | `Kusto` | Returns top resource types by resource count and effective cost to identify costly categories; see [top-resource-types-by-cost](kusto-tools.md#top-resource-types-by-cost). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `top-services-by-cost` | `Kusto` | Returns top Azure services by effective cost to prioritize service-level optimization; see [top-services-by-cost](kusto-tools.md#top-services-by-cost). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Anomaly detection and forecasting

Anomaly detection and forecasting tools help agents identify unexpected cost changes, project future spend, and deploy alerting automation, as described in [Anomaly detection](kusto-tools.md#anomaly-detection), [Forecasting](kusto-tools.md#forecasting), and [Budget and alert deployment](python-tools.md#budget-and-alert-deployment).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `cost-anomaly-detection` | `Kusto` | Detects cost spikes and drops with time-series anomaly detection over a configurable history window; see [cost-anomaly-detection](kusto-tools.md#cost-anomaly-detection). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `cost-forecasting-model` | `Kusto` | Forecasts future effective cost from historical cost data for budgeting and trend projection; see [cost-forecasting-model](kusto-tools.md#cost-forecasting-model). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `deploy-anomaly-alert` | `Python` | Creates or updates a Cost Management scheduled action for anomaly detection in a subscription; see [deploy-anomaly-alert](python-tools.md#deploy-anomaly-alert). | Not assigned |
| `deploy-bulk-anomaly-alerts` | `Python` | Discovers enabled subscriptions in a management group and deploys anomaly alert scheduled actions per subscription; see [deploy-bulk-anomaly-alerts](python-tools.md#deploy-bulk-anomaly-alerts). | Not assigned |

<br>

## Rate optimization

Rate optimization tools help agents review reservations, savings plans, pricing benchmarks, commitment transactions, and Advisor recommendation suppression workflows, as described in [Commitment discounts](kusto-tools.md#commitment-discounts), [Price analysis](kusto-tools.md#price-analysis), [Resource analysis](python-tools.md#resource-analysis), and [Advisor](python-tools.md#advisor).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `benefit-recommendations` | `Python` | Gets Azure Cost Management benefit recommendations for savings plans and reserved instances at a billing scope; see [benefit-recommendations](python-tools.md#benefit-recommendations). | Not assigned |
| `commitment-discount-utilization` | `Kusto` | Analyzes consumed core hours by commitment discount type, including on-demand usage, for a reporting window; see [commitment-discount-utilization](kusto-tools.md#commitment-discount-utilization). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `reservation-recommendation-breakdown` | `Kusto` | Analyzes reservation recommendations, savings, break-even dates, normalized sizes, scope, and term details; see [reservation-recommendation-breakdown](kusto-tools.md#reservation-recommendation-breakdown). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `savings-summary-report` | `Kusto` | Summarizes list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate; see [savings-summary-report](kusto-tools.md#savings-summary-report). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `azure-capacity-manager` |
| `service-price-benchmarking` | `Kusto` | Benchmarks services by list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings; see [service-price-benchmarking](kusto-tools.md#service-price-benchmarking). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |
| `suppress-advisor-recommendations` | `Python` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group with a time to live; see [suppress-advisor-recommendations](python-tools.md#suppress-advisor-recommendations). | Not assigned |
| `top-commitment-transactions` | `Kusto` | Returns top non-usage commitment discount purchase transactions for reservation and savings plan review; see [top-commitment-transactions](kusto-tools.md#top-commitment-transactions). | `chief-financial-officer`, `finops-practitioner`, `ftk-database-query` |

<br>

## Capacity management

Capacity management tools help agents inspect quota, capacity reservations, SKU availability, and non-compute service limits before planning or deployment, as described in [Capacity and quota](python-tools.md#capacity-and-quota) and the [azure-capacity-manager](agents.md#azure-capacity-manager) agent reference.

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `capacity-reservation-groups` | `Python` | Lists capacity reservation groups and compares reserved capacity with allocated virtual machines; see [capacity-reservation-groups](python-tools.md#capacity-reservation-groups). | Not assigned |
| `non-compute-quotas` | `Python` | Checks non-compute service quota usage with provider usage APIs and estimated Resource Graph fallbacks; see [non-compute-quotas](python-tools.md#non-compute-quotas). | Not assigned |
| `sku-availability` | `Python` | Lists Azure Compute SKU availability, zones, and regional restriction reasons before planning or deployment; see [sku-availability](python-tools.md#sku-availability). | Not assigned |
| `vm-quota-usage` | `Python` | Reports VM family quota usage by region and flags families above 80% or 95% utilization; see [vm-quota-usage](python-tools.md#vm-quota-usage). | Not assigned |

<br>

## Governance and automation

Governance and automation tools help agents deploy budget guardrails and run Resource Graph queries for inventory, configuration, and operational checks, as described in [Budget and alert deployment](python-tools.md#budget-and-alert-deployment) and [Resource analysis](python-tools.md#resource-analysis).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `deploy-budget` | `Python` | Creates or updates a subscription-level Cost Management budget with notification contacts; see [deploy-budget](python-tools.md#deploy-budget). | Not assigned |
| `deploy-bulk-budgets` | `Python` | Discovers enabled subscriptions in a management group and creates or updates a Cost Management budget in each subscription; see [deploy-bulk-budgets](python-tools.md#deploy-bulk-budgets). | Not assigned |
| `resource-graph-query` | `Python` | Runs Azure Resource Graph KQL queries across subscriptions for inventory and configuration troubleshooting; see [resource-graph-query](python-tools.md#resource-graph-query). | Not assigned |

<br>

## Data ingestion and health

Data ingestion and health tools help agents validate whether FinOps hub data is fresh enough to trust for analysis and reporting, as described in [Hub management](python-tools.md#hub-management).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `data-freshness-check` | `Python` | Checks FinOps hub function data freshness through direct Azure Data Explorer REST queries. Treats `Costs()` as the authoritative freshness signal with a three-day threshold and supersedes conflicting stale-memory or raw-KQL conclusions; see [data-freshness-check](python-tools.md#data-freshness-check). | `azure-capacity-manager`, `chief-financial-officer`, `finops-practitioner`, `ftk-database-query`, `ftk-hubs-agent` |

<br>

## Give feedback

Let us know how we're doing with a [quick review](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent). We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/SREAgent)
<!-- prettier-ignore-end -->

If you're looking for something specific, [vote for an existing or create a new idea](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc). Share ideas with others to get more votes. We focus on ideas with the most votes.

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

- [FinOps toolkit SRE Agent](overview.md)
- [Deploy and configure the FinOps toolkit SRE Agent](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
