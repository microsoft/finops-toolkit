---
title: Kusto tools
description: Review the FinOps hub Kusto tools the FinOps toolkit ships for Azure SRE Agent and learn when to use each tool for cost, commitment discount, anomaly, forecast, AI, and price analysis.
author: msbrett
ms.author: brettwil
ms.date: 06/17/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand each Kusto tool the FinOps toolkit ships for Azure SRE Agent so that I can choose the right query for cost and optimization analysis.
---

# Kusto tools

The FinOps toolkit deployment configures Azure SRE Agent with 37 Kusto tools that query your FinOps hub Azure Data Explorer database through the `finops-hub-kusto` connector. Each tool is configured as a `KustoTool` and generated from the FinOps hub query catalog to ground agent responses in cost, price, recommendation, transaction, KPI, and AI usage data. Query source lives at [`src/queries/catalog`](../../../src/queries/catalog/). The SRE Agent recipe rejects explicit Kusto YAML files so the query catalog stays the only source for Kusto tool definitions.

This reference also calls out related optimization tools that appear in scheduled-task requirements when they affect the same analysis path. Those tools aren't Kusto tools unless explicitly marked as `KustoTool`.

> [!IMPORTANT]
> Kusto tools require the hosted Azure SRE Agent to reach the Azure Data Explorer query endpoint. If the FinOps hub cluster has `publicNetworkAccess` set to `Disabled`, the toolkit still deploys the agent, assigns `AllDatabasesViewer`, and creates the connector, but the connector is expected to remain unhealthy. Review the [Azure SRE Agent VNET known limitations](https://sre.azure.com/docs/capabilities/azure-observability-vnet#known-limitations), then decide whether to enable public query access for the cluster.

Use this reference when you want to understand which tool fits a prompt, scheduled task, or custom agent workflow. For a summary of all the agent's tools, see [Tools shipped for Azure SRE Agent in the FinOps toolkit](tools.md).

<br>

## Source validation

The template generates every FinOps hub Kusto tool from the 37 `.kql` files in [`src/queries/catalog`](../../../src/queries/catalog/). The recipe keeps 13 `PythonTool` YAML files in [`src/templates/sre-agent/recipes/finops-hub/config/tools`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/). Build validation fails if an explicit Kusto YAML file is added, if a catalog query doesn't generate exactly one Kusto tool, if a KPI-linked query isn't generated as a Kusto tool, or if a KPI-linked query isn't requested by any scheduled task.

| Source category | Count | Evidence |
|-----------------|------:|----------|
| FinOps hub Kusto tools | 37 | Generated from [`src/queries/catalog/*.kql`](../../../src/queries/catalog/) by [`build-extras.py`](../../../src/templates/sre-agent/bin/build-extras.py). The catalog is indexed in [`src/queries/INDEX.md`](../../../src/queries/INDEX.md), and KPI-linked tools are mapped in [`src/queries/KPI.md`](../../../src/queries/KPI.md). |
| Related Python tools | 13 | [`benefit-recommendations`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/benefit-recommendations.yaml), [`capacity-reservation-groups`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/capacity-reservation-groups.yaml), [`data-freshness-check`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/data-freshness-check.yaml), [`db-service-quotas`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/db-service-quotas.yaml), [`deploy-anomaly-alert`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/deploy-anomaly-alert.yaml), [`deploy-budget`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/deploy-budget.yaml), [`deploy-bulk-anomaly-alerts`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/deploy-bulk-anomaly-alerts.yaml), [`deploy-bulk-budgets`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/deploy-bulk-budgets.yaml), [`non-compute-quotas`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/non-compute-quotas.yaml), [`resource-graph-query`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/resource-graph-query.yaml), [`sku-availability`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/sku-availability.yaml), [`suppress-advisor-recommendations`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/suppress-advisor-recommendations.yaml), and [`vm-quota-usage`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/vm-quota-usage.yaml) |

<br>

## Cost analysis

Use cost analysis tools to review cost and usage from different reporting angles, including time, service, resource group, region, billing hierarchy, and resource type.

### costs-enriched-base

Source query: [`costs-enriched-base.kql`](../../../src/queries/catalog/costs-enriched-base.kql).

Queries a guarded, enriched row-level cost and usage sample with tags, resource details, savings fields, commitment fields, and FinOps toolkit metadata.

Use it only for narrow detail drill-downs after an aggregate result identifies the scope to inspect. The tool rejects windows greater than one day to avoid Azure Data Explorer result truncation. For full-month, fiscal-period, scheduled report, dashboard export, allocation, showback, chargeback, tag-coverage, or broad custom analysis, use aggregate tools first, such as `monthly-cost-trend`, `cost-by-financial-hierarchy`, `top-services-by-cost`, `top-resource-groups-by-cost`, or `top-resource-types-by-cost`.

Example prompt: "Show me enriched cost details for yesterday's top resource group, including tags and resource group."

Sample output shape: One row per cost record with fields such as `ChargePeriodStart`, `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `ServiceName`, `x_ResourceGroupName`, `BilledCost`, `EffectiveCost`, `ContractedCost`, `ListCost`, `PricingQuantity`, `Tags`, `CommitmentDiscountType`, `CommitmentDiscountStatus`, `x_TotalSavings`, and `x_FreeReason`.

### monthly-cost-trend

Source query: [`monthly-cost-trend.kql`](../../../src/queries/catalog/monthly-cost-trend.kql).

Queries monthly billed and effective cost totals to show cost trends over time.

Use it when you need a month-by-month view for budget reviews, executive summaries, or recurring FinOps reporting. It helps identify whether spend is increasing, decreasing, or stabilizing.

Example prompt: "Show the monthly cost trend for the last six months."

Sample output shape: One row per month with `x_ChargeMonth`, `BilledCost`, and `EffectiveCost`.

### monthly-cost-change-percentage

Source query: [`monthly-cost-change-percentage.kql`](../../../src/queries/catalog/monthly-cost-change-percentage.kql).

Queries month-over-month billed and effective cost changes as percentages.

Use it when stakeholders ask how much costs changed between months or when you need to find volatility quickly. It works well for variance reviews and cost spike triage.

Example prompt: "Which months had the largest percentage increase in effective cost?"

Sample output shape: One row per month with `ChargePeriodStart`, `BilledCost`, `EffectiveCost`, `PreviousBilledCost`, `PreviousEffectiveCost`, billed-cost change percentage, and effective-cost change percentage.

### quarterly-cost-by-resource-group

Source query: [`quarterly-cost-by-resource-group.kql`](../../../src/queries/catalog/quarterly-cost-by-resource-group.kql).

Queries quarterly cost by resource group, subscription, and month for a reporting window.

Use it when preparing quarterly business reviews or resource-group-level accountability reports. It helps teams connect quarterly cost movement to resource ownership and subscription context.

Example prompt: "Break down quarterly costs by resource group for the last quarter."

Sample output shape: One row per subscription, resource group, and month with `SubAccountName`, `x_ResourceGroupName`, `x_ChargeMonth`, and `EffectiveCost`.

### cost-by-region-trend

Source query: [`cost-by-region-trend.kql`](../../../src/queries/catalog/cost-by-region-trend.kql).

Queries effective cost trends by Azure region.

Use it when you need to understand regional cost distribution, investigate regional growth, or evaluate whether workloads are shifting between regions. It can also support capacity and placement discussions.

Example prompt: "Show cost trends by Azure region over the last three months."

Sample output shape: One row per region with `RegionName` and `EffectiveCost`.

### cost-by-financial-hierarchy

Source query: [`cost-by-financial-hierarchy.kql`](../../../src/queries/catalog/cost-by-financial-hierarchy.kql).

Queries costs organized by billing profile, invoice section, team, product, application, environment, and other financial hierarchy fields.

Use it when you need a finance-aligned view for allocation, showback, chargeback, or executive reporting. It helps translate resource-level usage into business ownership.

Example prompt: "Summarize costs by billing profile, team, product, and application."

Sample output shape: One row per financial hierarchy combination with `x_BillingProfileName`, `x_InvoiceSectionName`, `x_Team`, `x_Product`, `x_Application`, `x_Environment`, `EffectiveCost`, and `PercentOfTotal`.

### top-services-by-cost

Source query: [`top-services-by-cost.kql`](../../../src/queries/catalog/top-services-by-cost.kql).

Queries the Azure services with the highest effective cost.

Use it when you need to prioritize service-level optimization or identify which services drive overall spend. Start here for broad cost reviews before drilling into resources or resource groups.

Example prompt: "What are the top 10 Azure services by cost this month?"

Sample output shape: One row per service with `ServiceName` and `EffectiveCost`.

### top-resource-types-by-cost

Source query: [`top-resource-types-by-cost.kql`](../../../src/queries/catalog/top-resource-types-by-cost.kql).

Queries the resource types with the highest effective cost and resource counts.

Use it when you need to understand which resource categories are driving spend, such as virtual machines, disks, databases, or networking resources. It helps identify optimization themes across many resources.

Example prompt: "List the top resource types by effective cost and resource count."

Sample output shape: One row per resource type with `ResourceType`, `ResourceCount`, and `EffectiveCost`.

### top-resource-groups-by-cost

Source query: [`top-resource-groups-by-cost.kql`](../../../src/queries/catalog/top-resource-groups-by-cost.kql).

Queries the resource groups with the highest effective cost.

Use it when you need an owner-friendly cost view or want to focus optimization work on the most expensive resource groups. It is useful for team accountability and workload-level reviews.

Example prompt: "Which resource groups had the highest costs in the last 30 days?"

Sample output shape: One row per subscription and resource group with `SubAccountName`, `x_ResourceGroupName`, and `EffectiveCost`.

<br>

## Commitment discounts

Use commitment discount tools to review reservation and savings plan utilization, recommendations, realized savings, and purchase transactions.

### commitment-discount-utilization

Source query: [`commitment-discount-utilization.kql`](../../../src/queries/catalog/commitment-discount-utilization.kql).

Queries consumed core hours by commitment discount type, including reservation, savings plan, and on-demand usage.

Use it when you need to understand how well commitments are being used and whether uncovered on-demand usage remains. It helps compare capacity planning, usage patterns, and commitment coverage.

Example prompt: "Show reservation and savings plan utilization for the last month."

Sample output shape: One row per commitment category with `CommitmentDiscountType`, `TotalConsumedCoreHours`, and `PercentOfTotal`. Empty commitment types are reported as `On Demand`.

### reservation-recommendation-breakdown

Source query: [`reservation-recommendation-breakdown.kql`](../../../src/queries/catalog/reservation-recommendation-breakdown.kql).

Queries detailed reservation recommendations, including savings, break-even dates, normalized sizes, scope, and term details.

Use it when evaluating whether to buy reservations or when preparing a recommendation package for finance and workload owners. It helps compare potential savings with commitment risk.

Example prompt: "Break down reservation purchase recommendations by service, term, and expected savings."

Sample output shape: One row per reservation recommendation with fields such as `RegionId`, normalized size or group details, `x_SkuMeterId`, `x_SkuTerm`, expected before and after effective cost, `x_BreakEvenMonths`, and `x_BreakEvenDate`.

### benefit-recommendations

Source query: [`benefit-recommendations.kql`](../../../src/queries/catalog/benefit-recommendations.kql).

Gets Microsoft Cost Management benefit recommendations for savings plans and reserved instances at a billing scope.

This is a related optimization tool, but it's a `PythonTool`, not a Kusto tool. Use it when the agent needs current Cost Management recommendation API results by billing scope, lookback period, and term. Use `reservation-recommendation-breakdown` when you need FinOps hub recommendation data from `Recommendations()`.

Example prompt: "Get current savings plan and reservation benefit recommendations for this billing profile."

Sample output shape: A JSON object with `billing_scope`, `lookback_period`, `term`, `count`, and `recommendations`. Each recommendation includes fields such as `type`, `savings`, `cost`, `total_cost`, `cost_without_benefit`, `term`, `break_even`, `id`, and `name`. If the request can't run, the object includes an `error` field.

### savings-summary-report

Source query: [`savings-summary-report.kql`](../../../src/queries/catalog/savings-summary-report.kql).

Queries list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate.

Use it when you need a summary of savings from discounts and commitments compared with pay-as-you-go pricing. It works well for executive reporting and rate optimization reviews.

Example prompt: "Summarize total savings from negotiated rates and commitment discounts this month."

Sample output shape: One row per billing currency with `BillingCurrency`, `ListCost`, `ContractedCost`, `EffectiveCost`, `x_NegotiatedDiscountSavings`, `x_CommitmentDiscountSavings`, `x_TotalSavings`, and `x_EffectiveSavingsRate`.

### top-commitment-transactions

Source query: [`top-commitment-transactions.kql`](../../../src/queries/catalog/top-commitment-transactions.kql).

Queries the largest non-usage commitment discount purchase transactions, including reservations and savings plans.

Use it when investigating major commitment-related charges, purchase timing, or renewal activity. It helps separate commitment purchases from normal usage costs.

Example prompt: "Show the largest reservation and savings plan transactions this quarter."

Sample output shape: One row per commitment purchase transaction with `ChargePeriodStart`, `ChargeCategory`, `BilledCost`, `BillingCurrency`, `CommitmentDiscountName`, `CommitmentDiscountNameUnique`, `CommitmentDiscountType`, `SubAccountName`, `SubAccountNameUnique`, `ResourceNameUnique`, and `x_ResourceGroupNameUnique`.

<br>

## Anomaly detection

Use anomaly detection tools to identify unusual cost patterns that need investigation.

### cost-anomaly-detection

Source query: [`cost-anomaly-detection.kql`](../../../src/queries/catalog/cost-anomaly-detection.kql).

Queries cost time series and detects unusual spikes or drops across a configurable history window.

Use it when you need to triage unexpected spend changes, monitor recurring cost health, or explain why costs moved outside the normal pattern. Pair it with cost drill-down tools to find the affected service, region, or resource group.

Example prompt: "Detect cost anomalies over the last 90 days and explain the biggest spikes."

Sample output shape: One time-series row with `ChargePeriodStart`, `CostSeries`, and `anomalies`, where the series arrays represent the analyzed interval and the anomaly markers.

<br>

## Forecasting

Use forecasting tools to project future cost based on historical patterns.

### cost-forecasting-model

Source query: [`cost-forecasting-model.kql`](../../../src/queries/catalog/cost-forecasting-model.kql).

Queries historical cost trends and projects future effective cost.

Use it when preparing budgets, rolling forecasts, or expected run-rate discussions. It is most helpful when recent historical usage is representative of near-term demand.

Example prompt: "Forecast effective cost for the next three months based on recent trends."

Sample output shape: One time-series row with `ChargePeriodStart`, `EffectiveCostSeries`, and `forecast`, where the forecast array extends the historical cost series for the requested future periods.

<br>

## AI/ML costs

Use AI/ML cost tools to analyze Azure OpenAI and related AI service costs, token usage, model efficiency, and application ownership.

### ai-cost-by-application

Source query: [`ai-cost-by-application.kql`](../../../src/queries/catalog/ai-cost-by-application.kql).

Queries AI and machine learning costs by application, team, and environment tags.

Use it when you need showback, chargeback, or ownership analysis for AI workloads. It helps map AI spend to the applications and teams consuming it.

Example prompt: "Break down AI costs by application and environment for this month."

Sample output shape: One row per application, team, environment, and cost center with fields such as `Application`, `Team`, `Environment`, `CostCenter`, `EffectiveCost`, `TokenCount`, and `CostPer1KTokens`.

### ai-daily-trend

Source query: [`ai-daily-trend.kql`](../../../src/queries/catalog/ai-daily-trend.kql).

Queries daily AI and machine learning cost trends.

Use it when you need to monitor day-to-day AI spend, spot sudden changes, or prepare daily operating reports. It can also provide context before investigating token or model-level drivers.

Example prompt: "Show the daily AI cost trend for the last 30 days."

Sample output shape: One row per day with `ChargePeriodStart`, daily AI cost, daily token count, and cost per 1,000 tokens.

### ai-model-cost-comparison

Source query: [`ai-model-cost-comparison.kql`](../../../src/queries/catalog/ai-model-cost-comparison.kql).

Queries AI model costs so the agent can compare costs across models.

Use it when evaluating model efficiency, unit economics, or opportunities to shift workloads to lower-cost models. It is useful for comparing model choices before changing application behavior.

Example prompt: "Compare costs across AI models and identify the most expensive models per 1,000 tokens."

Sample output shape: One row per model with `Model`, `TokenCount`, `EffectiveCost`, `ListCost`, `CostPer1KTokens`, `ListPer1KTokens`, and `DiscountPercent`.

### ai-token-usage-breakdown

Source query: [`ai-token-usage-breakdown.kql`](../../../src/queries/catalog/ai-token-usage-breakdown.kql).

Queries AI token usage by model, model version, and input or output direction.

Use it when token consumption is the suspected cost driver or when you need to separate prompt and completion usage. It helps connect AI cost changes to usage behavior.

Example prompt: "Break down token usage by model and input versus output tokens for the last week."

Sample output shape: One row per model and token direction with `Model`, `Direction`, `TokenCount`, `EffectiveCost`, `UnitCostPerToken`, and `CostPer1KTokens`.

<br>

## FinOps KPI tools

FinOps KPI tools are generated from the query catalog and map to query links in [`src/queries/KPI.md`](../../../src/queries/KPI.md). Scheduled tasks request these tools through `ftk-database-query` for monthly, semiannual, health, anomaly, capacity, storage, monitoring, AI, and benefit-review scorecards.

### percentage-unallocated-costs

Source query: [`percentage-unallocated-costs.kql`](../../../src/queries/catalog/percentage-unallocated-costs.kql).

Measures the share of effective cost that lacks required allocation evidence for the reporting window.

### percentage-untagged-costs

Source query: [`percentage-untagged-costs.kql`](../../../src/queries/catalog/percentage-untagged-costs.kql).

Measures the share of effective cost on resources that have no tags.

### tagging-policy-compliance

Source query: [`tagging-policy-compliance.kql`](../../../src/queries/catalog/tagging-policy-compliance.kql).

Measures cost-weighted compliance with required tag keys.

### allocation-accuracy-index

Source query: [`allocation-accuracy-index.kql`](../../../src/queries/catalog/allocation-accuracy-index.kql).

Measures directly attributed cost as a share of total effective cost.

### anomaly-detection-rate

Source query: [`anomaly-detection-rate.kql`](../../../src/queries/catalog/anomaly-detection-rate.kql).

Measures the share of effective spend in anomaly-flagged daily buckets.

### anomaly-variance-total

Source query: [`anomaly-variance-total.kql`](../../../src/queries/catalog/anomaly-variance-total.kql).

Quantifies signed and absolute unpredicted spend variance for detected anomaly events.

### cost-visibility-delay

Source query: [`cost-visibility-delay.kql`](../../../src/queries/catalog/cost-visibility-delay.kql).

Measures cost data visibility delay from charge period end to Hub ingestion.

### data-update-frequency

Source query: [`data-update-frequency.kql`](../../../src/queries/catalog/data-update-frequency.kql).

Measures FinOps hub ingestion update cadence from distinct ingestion timestamps.

### commitment-utilization-score

Source query: [`commitment-utilization-score.kql`](../../../src/queries/catalog/commitment-utilization-score.kql).

Computes commitment utilization amount, potential, and score by commitment and currency.

### commitment-discount-waste

Source query: [`commitment-discount-waste.kql`](../../../src/queries/catalog/commitment-discount-waste.kql).

Measures unused commitment value as a share of total commitment cost.

### compute-spend-commitment-coverage

Source query: [`compute-spend-commitment-coverage.kql`](../../../src/queries/catalog/compute-spend-commitment-coverage.kql).

Measures compute spend covered by commitment discounts.

### compute-cost-per-core

Source query: [`compute-cost-per-core.kql`](../../../src/queries/catalog/compute-cost-per-core.kql).

Computes hourly and effective average compute cost per consumed vCPU core hour.

### cost-optimization-index

Source query: [`cost-optimization-index.kql`](../../../src/queries/catalog/cost-optimization-index.kql).

Computes the Hub-wide cost optimization index from current recommendations and cost context.

### cost-per-gb-stored

Source query: [`cost-per-gb-stored.kql`](../../../src/queries/catalog/cost-per-gb-stored.kql).

Calculates storage cost per normalized GB-month.

### macc-consumption-vs-commitment

Source query: [`macc-consumption-vs-commitment.kql`](../../../src/queries/catalog/macc-consumption-vs-commitment.kql).

Measures Microsoft Azure Consumption Commitment drawdown by billing profile and month.

### storage-tier-distribution

Source query: [`storage-tier-distribution.kql`](../../../src/queries/catalog/storage-tier-distribution.kql).

Summarizes storage cost and GB-month distribution by access-tier bucket.

<br>

## Usage optimization

Use Usage Optimization tools to identify idle, orphaned, or wasteful resources before starting cleanup work.

### idle-resource-sweep

Source status: No `idle-resource-sweep.yaml` file appears in the source inventory for [`src/templates/sre-agent/recipes/finops-hub/config/tools`](../../../src/templates/sre-agent/recipes/finops-hub/config/tools/).

Reviews idle or orphaned resource candidates for Usage Optimization.

This Gate-named tool is a required analysis path, but the current template doesn't include an `idle-resource-sweep` Kusto tool YAML file. Until a dedicated tool is added, ground idle-resource reviews with `top-resource-types-by-cost`, `top-resource-groups-by-cost`, and narrow `costs-enriched-base` drill-downs. Then correlate candidates with Azure Resource Graph or Azure Advisor data through the relevant Python or built-in Azure tools before recommending cleanup.

Example prompt: "Find likely idle or orphaned resources and group them by resource type, subscription, and estimated monthly cost."

Sample output shape: A candidate list with fields such as `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `x_ResourceGroupName`, `RegionName`, `ServiceName`, `EffectiveCost`, `LastUsageSignal`, `IdleReason`, `RecommendedAction`, and `Confidence`. When using the current template, this shape is assembled from existing cost aggregates, enriched cost rows, and external Azure inventory or recommendation signals rather than returned by a single shipped Kusto tool.

<br>

## Price analysis

Use price analysis tools to compare prices, savings, and non-commitment transactions that affect total cost.

### service-price-benchmarking

Source query: [`service-price-benchmarking.kql`](../../../src/queries/catalog/service-price-benchmarking.kql).

Queries service price benchmarks, including list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings.

Use it when you need to compare prices across services or understand how negotiated and commitment discounts affect effective rates. It helps identify services with the largest rate optimization opportunity.

Example prompt: "Benchmark service prices and show where negotiated or commitment savings are highest."

Sample output shape: One row per service with `ServiceName`, `ListCost`, `ContractedCost`, `EffectiveCost`, negotiated savings, commitment discount savings, total savings, and savings percentages.

### top-other-transactions

Source query: [`top-other-transactions.kql`](../../../src/queries/catalog/top-other-transactions.kql).

Queries the largest non-usage and non-commitment transactions, such as Marketplace or miscellaneous charges.

Use it when costs don't reconcile to normal usage or commitment purchases. It helps isolate large one-time or nonstandard transactions that can distort monthly cost trends.

Example prompt: "Show the largest non-usage and non-commitment transactions this month."

Sample output shape: One row per non-usage, non-commitment transaction with `ChargePeriodStart`, `ChargeCategory`, `BilledCost`, `BillingCurrency`, `SubAccountName`, `x_InvoiceSectionName`, `PricingCategory`, `PricingQuantity`, `PricingUnit`, `ProviderName`, and `PublisherName`.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/KustoTools)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20SRE%20Agent%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related FinOps capabilities:

- [Anomaly management](../../framework/understand/anomalies.md)
- [Cost allocation](../../framework/understand/allocation.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)

Related products:

- [Azure SRE Agent](/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)
- [Microsoft Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [Tools shipped for Azure SRE Agent in the FinOps toolkit](tools.md)
- [Python tools](python-tools.md)

<br>
