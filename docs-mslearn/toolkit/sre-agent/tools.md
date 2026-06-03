---
title: Tools shipped for Azure SRE Agent in the FinOps toolkit
description: Review the Kusto and Python tools the FinOps toolkit ships for Azure SRE Agent for cost analysis, anomaly detection, rate optimization, capacity management, and operations.
author: msbrett
ms.author: brettwil
ms.date: 06/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand which tools the FinOps toolkit ships for Azure SRE Agent so that I can choose the right agent workflow for cost, capacity, and operations analysis.
---

# Tools shipped for Azure SRE Agent in the FinOps toolkit

The FinOps toolkit deployment configures Azure SRE Agent with tools that ground agent responses in live Azure and FinOps hub data. [Kusto tools](kusto-tools.md) query the FinOps hub Azure Data Explorer database, and [Python tools](python-tools.md) call Azure APIs through the agent's managed identity.

Use this article as a catalog of the tools included with the template. For deeper implementation details, review the [Kusto tools](kusto-tools.md) and [Python tools](python-tools.md) references.

The template configures 50 tools: 37 Kusto query tools generated from the FinOps hub query catalog and 13 Python tools, as documented in the [Kusto tools](kusto-tools.md) and [Python tools](python-tools.md) references. All Kusto tools are assigned only to `ftk-database-query`; other agents request Kusto evidence from that specialist instead of querying FinOps hub directly.

> [!NOTE]
> The agent list shows subagents that reference each tool in `recipes/finops-hub/config/subagents`. Tools marked "Not assigned" are included in the tool catalog, but aren't referenced by a subagent configuration. For agent roles and tool usage, see [agents and skills](agents.md).

<br>

## AI cost management

AI cost management tools help agents analyze Azure OpenAI spend, token usage, model efficiency, and application-level allocation, as described in [AI/ML costs](kusto-tools.md#aiml-costs).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `ai-cost-by-application` | `Kusto` | Breaks down Azure OpenAI costs by application, team, and environment tags for chargeback, showback, and allocation; see [ai-cost-by-application](kusto-tools.md#ai-cost-by-application). | `ftk-database-query` |
| `ai-daily-trend` | `Kusto` | Shows daily Azure OpenAI cost and token trends for AI cost anomaly detection and forecasting; see [ai-daily-trend](kusto-tools.md#ai-daily-trend). | `ftk-database-query` |
| `ai-model-cost-comparison` | `Kusto` | Compares Azure OpenAI model cost per 1,000 tokens to identify model efficiency opportunities; see [ai-model-cost-comparison](kusto-tools.md#ai-model-cost-comparison). | `ftk-database-query` |
| `ai-token-usage-breakdown` | `Kusto` | Breaks down Azure OpenAI token consumption by model version and input or output direction; see [ai-token-usage-breakdown](kusto-tools.md#ai-token-usage-breakdown). | `ftk-database-query` |

<br>

## Cost analysis and reporting

Cost analysis and reporting tools summarize FinOps hub cost data by service, region, resource group, financial hierarchy, transaction type, and time period, as described in [Cost analysis](kusto-tools.md#cost-analysis) and [Price analysis](kusto-tools.md#price-analysis).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `costs-enriched-base` | `Kusto` | Returns a guarded row-level enriched cost and usage sample for narrow drill-downs; see [costs-enriched-base](kusto-tools.md#costs-enriched-base). Use aggregate tools for full-month, fiscal-period, scheduled report, and tag-coverage rollup requests. | `ftk-database-query` |
| `cost-by-financial-hierarchy` | `Kusto` | Reports top costs across billing profile, invoice section, team, product, application, and environment; see [cost-by-financial-hierarchy](kusto-tools.md#cost-by-financial-hierarchy). | `ftk-database-query` |
| `cost-by-region-trend` | `Kusto` | Summarizes effective cost by Azure region to identify regional spend distribution and optimization opportunities; see [cost-by-region-trend](kusto-tools.md#cost-by-region-trend). | `ftk-database-query` |
| `monthly-cost-change-percentage` | `Kusto` | Calculates month-over-month billed and effective cost changes to spot spikes, drops, and volatility; see [monthly-cost-change-percentage](kusto-tools.md#monthly-cost-change-percentage). | `ftk-database-query` |
| `monthly-cost-trend` | `Kusto` | Returns billed and effective cost totals by month for trend review and budget analysis; see [monthly-cost-trend](kusto-tools.md#monthly-cost-trend). | `ftk-database-query` |
| `quarterly-cost-by-resource-group` | `Kusto` | Returns top resource-group cost rows by subscription and month for quarterly reporting windows; see [quarterly-cost-by-resource-group](kusto-tools.md#quarterly-cost-by-resource-group). | `ftk-database-query` |
| `top-other-transactions` | `Kusto` | Lists top non-usage, non-commitment purchase transactions, such as Marketplace or miscellaneous charges; see [top-other-transactions](kusto-tools.md#top-other-transactions). | `ftk-database-query` |
| `top-resource-groups-by-cost` | `Kusto` | Returns top resource groups by effective cost for focused reporting and optimization; see [top-resource-groups-by-cost](kusto-tools.md#top-resource-groups-by-cost). | `ftk-database-query` |
| `top-resource-types-by-cost` | `Kusto` | Returns top resource types by resource count and effective cost to identify costly categories; see [top-resource-types-by-cost](kusto-tools.md#top-resource-types-by-cost). | `ftk-database-query` |
| `top-services-by-cost` | `Kusto` | Returns top Azure services by effective cost to prioritize service-level optimization; see [top-services-by-cost](kusto-tools.md#top-services-by-cost). | `ftk-database-query` |

<br>

## FinOps KPI scorecard

FinOps KPI scorecard tools are generated from [`src/queries/catalog`](../../../src/queries/catalog/) and map directly to query links in [`src/queries/KPI.md`](../../../src/queries/KPI.md). Scheduled monthly, semiannual, health, anomaly, capacity, storage, monitoring, and benefit-review tasks request these tools through `ftk-database-query`.

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `allocation-accuracy-index` | `Kusto` | Measures directly attributed cost as a share of total effective cost. | `ftk-database-query` |
| `anomaly-detection-rate` | `Kusto` | Measures the share of spend in anomaly-flagged daily buckets. | `ftk-database-query` |
| `anomaly-variance-total` | `Kusto` | Quantifies unpredicted spend variance for detected anomaly events. | `ftk-database-query` |
| `commitment-discount-waste` | `Kusto` | Measures unused commitment value as a share of total commitment cost. | `ftk-database-query` |
| `commitment-utilization-score` | `Kusto` | Computes commitment utilization score by commitment and currency. | `ftk-database-query` |
| `compute-cost-per-core` | `Kusto` | Calculates effective and hourly compute cost per consumed vCPU core hour. | `ftk-database-query` |
| `compute-spend-commitment-coverage` | `Kusto` | Measures compute spend covered by commitment discounts. | `ftk-database-query` |
| `cost-optimization-index` | `Kusto` | Computes a cost optimization index from current recommendations and cost context. | `ftk-database-query` |
| `cost-per-gb-stored` | `Kusto` | Calculates storage cost per normalized GB-month. | `ftk-database-query` |
| `cost-visibility-delay` | `Kusto` | Measures cost data visibility delay for data-ingestion KPI reporting. | `ftk-database-query` |
| `data-update-frequency` | `Kusto` | Measures FinOps hub ingestion update cadence. | `ftk-database-query` |
| `macc-consumption-vs-commitment` | `Kusto` | Measures Microsoft Azure Consumption Commitment drawdown against commitment. | `ftk-database-query` |
| `percentage-unallocated-costs` | `Kusto` | Measures the share of cost missing required allocation evidence. | `ftk-database-query` |
| `percentage-untagged-costs` | `Kusto` | Measures the share of cost on resources with no tags. | `ftk-database-query` |
| `storage-tier-distribution` | `Kusto` | Summarizes storage cost and GB-month distribution by access-tier bucket. | `ftk-database-query` |
| `tagging-policy-compliance` | `Kusto` | Measures cost-weighted compliance with required tag keys. | `ftk-database-query` |

<br>

## Anomaly detection and forecasting

Anomaly detection and forecasting tools help agents identify unexpected cost changes, project future spend, and deploy alerting automation, as described in [Anomaly detection](kusto-tools.md#anomaly-detection), [Forecasting](kusto-tools.md#forecasting), and [Budget and alert deployment](python-tools.md#budget-and-alert-deployment).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `cost-anomaly-detection` | `Kusto` | Detects cost spikes and drops with time-series anomaly detection over a configurable history window; see [cost-anomaly-detection](kusto-tools.md#cost-anomaly-detection). | `ftk-database-query` |
| `cost-forecasting-model` | `Kusto` | Forecasts future effective cost from historical cost data for budgeting and trend projection; see [cost-forecasting-model](kusto-tools.md#cost-forecasting-model). | `ftk-database-query` |
| `deploy-anomaly-alert` | `Python` | Creates or updates a Cost Management scheduled action for anomaly detection in a subscription after explicit remediation approval; see [deploy-anomaly-alert](python-tools.md#deploy-anomaly-alert). | `finops-practitioner` |
| `deploy-bulk-anomaly-alerts` | `Python` | Discovers enabled subscriptions in a management group and deploys anomaly alert scheduled actions per subscription after explicit remediation approval; see [deploy-bulk-anomaly-alerts](python-tools.md#deploy-bulk-anomaly-alerts). | `finops-practitioner` |

<br>

## Rate optimization

Rate optimization tools help agents review reservations, savings plans, pricing benchmarks, commitment transactions, and Advisor recommendation suppression workflows, as described in [Commitment discounts](kusto-tools.md#commitment-discounts), [Price analysis](kusto-tools.md#price-analysis), [Resource analysis](python-tools.md#resource-analysis), and [Advisor](python-tools.md#advisor).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `benefit-recommendations` | `Python` | Gets Microsoft Cost Management benefit recommendations for savings plans and reserved instances at a billing scope; see [benefit-recommendations](python-tools.md#benefit-recommendations). | `finops-practitioner`, `azure-capacity-manager` |
| `commitment-discount-utilization` | `Kusto` | Analyzes consumed core hours by commitment discount type, including on-demand usage, for a reporting window; see [commitment-discount-utilization](kusto-tools.md#commitment-discount-utilization). | `ftk-database-query` |
| `reservation-recommendation-breakdown` | `Kusto` | Analyzes reservation recommendations, savings, break-even dates, normalized sizes, scope, and term details; see [reservation-recommendation-breakdown](kusto-tools.md#reservation-recommendation-breakdown). | `ftk-database-query` |
| `savings-summary-report` | `Kusto` | Summarizes list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate; see [savings-summary-report](kusto-tools.md#savings-summary-report). | `ftk-database-query` |
| `service-price-benchmarking` | `Kusto` | Benchmarks services by list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings; see [service-price-benchmarking](kusto-tools.md#service-price-benchmarking). | `ftk-database-query` |
| `suppress-advisor-recommendations` | `Python` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group with a time to live after explicit remediation approval; see [suppress-advisor-recommendations](python-tools.md#suppress-advisor-recommendations). | `finops-practitioner` |
| `top-commitment-transactions` | `Kusto` | Returns top non-usage commitment discount purchase transactions for reservation and savings plan review; see [top-commitment-transactions](kusto-tools.md#top-commitment-transactions). | `ftk-database-query` |

<br>

## Capacity management

Capacity management tools help agents inspect quota, capacity reservations, SKU availability, and non-compute service limits before planning or deployment, as described in [Capacity and quota](python-tools.md#capacity-and-quota) and the [azure-capacity-manager](agents.md#azure-capacity-manager) agent reference.

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `capacity-reservation-groups` | `Python` | Lists capacity reservation groups and compares reserved capacity with allocated virtual machines; see [capacity-reservation-groups](python-tools.md#capacity-reservation-groups). | `azure-capacity-manager` |
| `non-compute-quotas` | `Python` | Checks non-compute service quota usage with provider usage APIs and estimated Resource Graph fallbacks; see [non-compute-quotas](python-tools.md#non-compute-quotas). | `azure-capacity-manager` |
| `sku-availability` | `Python` | Lists Azure Compute or Azure Data Explorer SKU availability, zones, and regional restriction reasons before planning or deployment; see [sku-availability](python-tools.md#sku-availability). | `azure-capacity-manager`, `ftk-hubs-agent` |
| `vm-quota-usage` | `Python` | Reports VM family quota usage by region and flags families above 80% or 95% utilization; see [vm-quota-usage](python-tools.md#vm-quota-usage). | `azure-capacity-manager` |

<br>

## Governance and automation

Governance and automation tools help agents deploy budget guardrails and run Resource Graph queries for inventory, configuration, and operational checks, as described in [Budget and alert deployment](python-tools.md#budget-and-alert-deployment) and [Resource analysis](python-tools.md#resource-analysis).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `deploy-budget` | `Python` | Creates or updates a subscription-level Cost Management budget with notification contacts after explicit remediation approval; see [deploy-budget](python-tools.md#deploy-budget). | `finops-practitioner` |
| `deploy-bulk-budgets` | `Python` | Discovers enabled subscriptions in a management group and creates or updates a Cost Management budget in each subscription after explicit remediation approval; see [deploy-bulk-budgets](python-tools.md#deploy-bulk-budgets). | `finops-practitioner` |
| `resource-graph-query` | `Python` | Runs Azure Resource Graph KQL queries across subscriptions for inventory and configuration troubleshooting; see [resource-graph-query](python-tools.md#resource-graph-query). | `finops-practitioner`, `azure-capacity-manager`, `ftk-hubs-agent` |

<br>

## Data ingestion and health

Data ingestion and health tools help agents validate whether FinOps hub data is fresh enough to trust for analysis and reporting, as described in [Hub management](python-tools.md#hub-management).

| Tool | Type | Description | Agents |
|------|------|-------------|--------|
| `data-freshness-check` | `Python` | Checks FinOps hub function data freshness through direct Azure Data Explorer REST queries. Treats `Costs()` as the authoritative freshness signal with a three-day threshold and supersedes conflicting stale-memory or raw-KQL conclusions; see [data-freshness-check](python-tools.md#data-freshness-check). | `ftk-hubs-agent` |

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
- [Microsoft Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
