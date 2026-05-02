---
title: Kusto tools
description: Review the FinOps hub Kusto tools included with the FinOps toolkit SRE Agent and learn when to use each tool for cost, commitment discount, anomaly, forecast, AI, and price analysis.
author: msbrett
ms.author: brettwil
ms.date: 05/02/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand each FinOps toolkit SRE Agent Kusto tool so that I can choose the right query for cost and optimization analysis.
---

# Kusto tools

The FinOps toolkit SRE Agent includes 21 Kusto tools that query your FinOps hub Azure Data Explorer database through the `finops-hub-kusto` connector, as shown by the Kusto tool source inventory ([tool source](../../../src/templates/sre-agent/tools/)). Each Kusto tool is configured as a `KustoTool` and uses the FinOps hub query catalog to ground agent responses in cost, price, recommendation, transaction, and AI usage data ([tool source](../../../src/templates/sre-agent/tools/)).

This reference also calls out related required optimization tools that appear in scheduled-task and Gate requirements when they affect the same analysis path ([benefit recommendations source](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml)). Those tools aren't Kusto tools unless explicitly marked as `KustoTool` ([tool source](../../../src/templates/sre-agent/tools/)).

Use this reference when you want to understand which tool fits a prompt, scheduled task, or custom agent workflow ([tool source](../../../src/templates/sre-agent/tools/)). For a summary of all FinOps toolkit SRE Agent tools, see [FinOps toolkit SRE Agent tools](tools.md).

<br>

## Source validation

The template source contains 34 tool YAML files in [`src/templates/sre-agent/tools`](../../../src/templates/sre-agent/tools/). The production FinOps hub Kusto inventory is the subset with `spec.type: KustoTool` and `spec.connector: finops-hub-kusto`; it contains 21 tools ([tool source](../../../src/templates/sre-agent/tools/)). The remaining tool YAML files are 12 `PythonTool` files and one example `KustoTool` that uses `example_connector`, so they aren't part of the FinOps hub Kusto catalog ([tool source](../../../src/templates/sre-agent/tools/)).

| Source category | Count | Evidence |
|-----------------|------:|----------|
| FinOps hub Kusto tools | 21 | [`ai-cost-by-application`](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml), [`ai-daily-trend`](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml), [`ai-model-cost-comparison`](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml), [`ai-token-usage-breakdown`](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml), [`commitment-discount-utilization`](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml), [`cost-anomaly-detection`](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml), [`cost-by-financial-hierarchy`](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml), [`cost-by-region-trend`](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml), [`cost-forecasting-model`](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml), [`costs-enriched-base`](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml), [`monthly-cost-change-percentage`](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml), [`monthly-cost-trend`](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml), [`quarterly-cost-by-resource-group`](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml), [`reservation-recommendation-breakdown`](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml), [`savings-summary-report`](../../../src/templates/sre-agent/tools/savings-summary-report.yaml), [`service-price-benchmarking`](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml), [`top-commitment-transactions`](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml), [`top-other-transactions`](../../../src/templates/sre-agent/tools/top-other-transactions.yaml), [`top-resource-groups-by-cost`](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml), [`top-resource-types-by-cost`](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml), and [`top-services-by-cost`](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml) |
| Related Python tools | 12 | [`benefit-recommendations`](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml), [`capacity-reservation-groups`](../../../src/templates/sre-agent/tools/capacity-reservation-groups.yaml), [`data-freshness-check`](../../../src/templates/sre-agent/tools/data-freshness-check.yaml), [`deploy-anomaly-alert`](../../../src/templates/sre-agent/tools/deploy-anomaly-alert.yaml), [`deploy-budget`](../../../src/templates/sre-agent/tools/deploy-budget.yaml), [`deploy-bulk-anomaly-alerts`](../../../src/templates/sre-agent/tools/deploy-bulk-anomaly-alerts.yaml), [`deploy-bulk-budgets`](../../../src/templates/sre-agent/tools/deploy-bulk-budgets.yaml), [`non-compute-quotas`](../../../src/templates/sre-agent/tools/non-compute-quotas.yaml), [`resource-graph-query`](../../../src/templates/sre-agent/tools/resource-graph-query.yaml), [`sku-availability`](../../../src/templates/sre-agent/tools/sku-availability.yaml), [`suppress-advisor-recommendations`](../../../src/templates/sre-agent/tools/suppress-advisor-recommendations.yaml), and [`vm-quota-usage`](../../../src/templates/sre-agent/tools/vm-quota-usage.yaml) |
| Excluded example tool | 1 | [`example_tool`](../../../src/templates/sre-agent/tools/example_tool.yaml) is a sample `KustoTool` with `example_connector`, not `finops-hub-kusto`. |

<br>

## Cost analysis

Use cost analysis tools to review cost and usage from different reporting angles, including time, service, resource group, region, billing hierarchy, and resource type ([cost tools source](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml)).

### costs-enriched-base

Source YAML: [`costs-enriched-base.yaml`](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml).

Queries a guarded, enriched row-level cost and usage sample with tags, resource details, savings fields, commitment fields, and FinOps Toolkit metadata ([source YAML](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml)).

Use it only for narrow detail drill-downs after an aggregate result identifies the scope to inspect. The tool rejects windows greater than one day to avoid Azure Data Explorer result truncation. For full-month, fiscal-period, scheduled report, dashboard export, allocation, showback, chargeback, tag-coverage, or broad custom analysis, use aggregate tools first, such as `monthly-cost-trend`, `cost-by-financial-hierarchy`, `top-services-by-cost`, `top-resource-groups-by-cost`, or `top-resource-types-by-cost` ([source YAML](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml)).

Example prompt: "Show me enriched cost details for yesterday's top resource group, including tags and resource group."

Sample output shape: One row per cost record with fields such as `ChargePeriodStart`, `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `ServiceName`, `x_ResourceGroupName`, `BilledCost`, `EffectiveCost`, `ContractedCost`, `ListCost`, `PricingQuantity`, `Tags`, `CommitmentDiscountType`, `CommitmentDiscountStatus`, `x_TotalSavings`, and `x_FreeReason` ([source YAML](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml)).

### monthly-cost-trend

Source YAML: [`monthly-cost-trend.yaml`](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml).

Queries monthly billed and effective cost totals to show cost trends over time ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml)).

Use it when you need a month-by-month view for budget reviews, executive summaries, or recurring FinOps reporting. It helps identify whether spend is increasing, decreasing, or stabilizing ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml)).

Example prompt: "Show the monthly cost trend for the last six months."

Sample output shape: One row per month with `x_ChargeMonth`, `BilledCost`, and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml)).

### monthly-cost-change-percentage

Source YAML: [`monthly-cost-change-percentage.yaml`](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml).

Queries month-over-month billed and effective cost changes as percentages ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml)).

Use it when stakeholders ask how much costs changed between months or when you need to find volatility quickly. It works well for variance reviews and cost spike triage ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml)).

Example prompt: "Which months had the largest percentage increase in effective cost?"

Sample output shape: One row per month with `ChargePeriodStart`, `BilledCost`, `EffectiveCost`, `PreviousBilledCost`, `PreviousEffectiveCost`, billed-cost change percentage, and effective-cost change percentage ([source YAML](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml)).

### quarterly-cost-by-resource-group

Source YAML: [`quarterly-cost-by-resource-group.yaml`](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml).

Queries quarterly cost by resource group, subscription, and month for a reporting window ([source YAML](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml)).

Use it when preparing quarterly business reviews or resource-group-level accountability reports. It helps teams connect quarterly cost movement to resource ownership and subscription context ([source YAML](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml)).

Example prompt: "Break down quarterly costs by resource group for the last quarter."

Sample output shape: One row per subscription, resource group, and month with `SubAccountName`, `x_ResourceGroupName`, `x_ChargeMonth`, and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml)).

### cost-by-region-trend

Source YAML: [`cost-by-region-trend.yaml`](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml).

Queries effective cost trends by Azure region ([source YAML](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml)).

Use it when you need to understand regional cost distribution, investigate regional growth, or evaluate whether workloads are shifting between regions. It can also support capacity and placement discussions ([source YAML](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml)).

Example prompt: "Show cost trends by Azure region over the last three months."

Sample output shape: One row per region with `RegionName` and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml)).

### cost-by-financial-hierarchy

Source YAML: [`cost-by-financial-hierarchy.yaml`](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml).

Queries costs organized by billing profile, invoice section, team, product, application, environment, and other financial hierarchy fields ([source YAML](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml)).

Use it when you need a finance-aligned view for allocation, showback, chargeback, or executive reporting. It helps translate resource-level usage into business ownership ([source YAML](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml)).

Example prompt: "Summarize costs by billing profile, team, product, and application."

Sample output shape: One row per financial hierarchy combination with `x_BillingProfileName`, `x_InvoiceSectionName`, `x_Team`, `x_Product`, `x_Application`, `x_Environment`, `EffectiveCost`, and `PercentOfTotal` ([source YAML](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml)).

### top-services-by-cost

Source YAML: [`top-services-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml).

Queries the Azure services with the highest effective cost ([source YAML](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml)).

Use it when you need to prioritize service-level optimization or identify which services drive overall spend. Start here for broad cost reviews before drilling into resources or resource groups ([source YAML](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml)).

Example prompt: "What are the top 10 Azure services by cost this month?"

Sample output shape: One row per service with `ServiceName` and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml)).

### top-resource-types-by-cost

Source YAML: [`top-resource-types-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml).

Queries the resource types with the highest effective cost and resource counts ([source YAML](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml)).

Use it when you need to understand which resource categories are driving spend, such as virtual machines, disks, databases, or networking resources. It helps identify optimization themes across many resources ([source YAML](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml)).

Example prompt: "List the top resource types by effective cost and resource count."

Sample output shape: One row per resource type with `ResourceType`, `ResourceCount`, and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml)).

### top-resource-groups-by-cost

Source YAML: [`top-resource-groups-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml).

Queries the resource groups with the highest effective cost ([source YAML](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml)).

Use it when you need an owner-friendly cost view or want to focus optimization work on the most expensive resource groups. It is useful for team accountability and workload-level reviews ([source YAML](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml)).

Example prompt: "Which resource groups had the highest costs in the last 30 days?"

Sample output shape: One row per subscription and resource group with `SubAccountName`, `x_ResourceGroupName`, and `EffectiveCost` ([source YAML](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml)).

<br>

## Commitment discounts

Use commitment discount tools to review reservation and savings plan utilization, recommendations, realized savings, and purchase transactions ([commitment tools source](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml)).

### commitment-discount-utilization

Source YAML: [`commitment-discount-utilization.yaml`](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml).

Queries consumed core hours by commitment discount type, including reservation, savings plan, and on-demand usage ([source YAML](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml)).

Use it when you need to understand how well commitments are being used and whether uncovered on-demand usage remains. It helps compare capacity planning, usage patterns, and commitment coverage ([source YAML](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml)).

Example prompt: "Show reservation and savings plan utilization for the last month."

Sample output shape: One row per commitment category with `CommitmentDiscountType`, `TotalConsumedCoreHours`, and `PercentOfTotal`. Empty commitment types are reported as `On Demand` ([source YAML](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml)).

### reservation-recommendation-breakdown

Source YAML: [`reservation-recommendation-breakdown.yaml`](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml).

Queries detailed reservation recommendations, including savings, break-even dates, normalized sizes, scope, and term details ([source YAML](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml)).

Use it when evaluating whether to buy reservations or when preparing a recommendation package for finance and workload owners. It helps compare potential savings with commitment risk ([source YAML](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml)).

Example prompt: "Break down reservation purchase recommendations by service, term, and expected savings."

Sample output shape: One row per reservation recommendation with fields such as `RegionId`, normalized size or group details, `x_SkuMeterId`, `x_SkuTerm`, expected before and after effective cost, `x_BreakEvenMonths`, and `x_BreakEvenDate` ([source YAML](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml)).

### benefit-recommendations

Source YAML: [`benefit-recommendations.yaml`](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml).

Gets Azure Cost Management benefit recommendations for savings plans and reserved instances at a billing scope ([source YAML](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml)).

This is a related required optimization tool, but it is a `PythonTool`, not a Kusto tool. Use it when the agent needs current Cost Management recommendation API results by billing scope, lookback period, and term. Use `reservation-recommendation-breakdown` when you need FinOps hub recommendation data from `Recommendations()` ([source YAML](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml)).

Example prompt: "Get current savings plan and reservation benefit recommendations for this billing profile."

Sample output shape: A JSON object with `billing_scope`, `lookback_period`, `term`, `count`, and `recommendations`. Each recommendation includes fields such as `type`, `savings`, `cost`, `total_cost`, `cost_without_benefit`, `term`, `break_even`, `id`, and `name`. If the request can't run, the object includes an `error` field ([source YAML](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml)).

### savings-summary-report

Source YAML: [`savings-summary-report.yaml`](../../../src/templates/sre-agent/tools/savings-summary-report.yaml).

Queries list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate ([source YAML](../../../src/templates/sre-agent/tools/savings-summary-report.yaml)).

Use it when you need a summary of savings from discounts and commitments compared with pay-as-you-go pricing. It works well for executive reporting and rate optimization reviews ([source YAML](../../../src/templates/sre-agent/tools/savings-summary-report.yaml)).

Example prompt: "Summarize total savings from negotiated rates and commitment discounts this month."

Sample output shape: One row per billing currency with `BillingCurrency`, `ListCost`, `ContractedCost`, `EffectiveCost`, `x_NegotiatedDiscountSavings`, `x_CommitmentDiscountSavings`, `x_TotalSavings`, and `x_EffectiveSavingsRate` ([source YAML](../../../src/templates/sre-agent/tools/savings-summary-report.yaml)).

### top-commitment-transactions

Source YAML: [`top-commitment-transactions.yaml`](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml).

Queries the largest non-usage commitment discount purchase transactions, including reservations and savings plans ([source YAML](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml)).

Use it when investigating major commitment-related charges, purchase timing, or renewal activity. It helps separate commitment purchases from normal usage costs ([source YAML](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml)).

Example prompt: "Show the largest reservation and savings plan transactions this quarter."

Sample output shape: One row per commitment purchase transaction with `ChargePeriodStart`, `ChargeCategory`, `BilledCost`, `BillingCurrency`, `CommitmentDiscountName`, `CommitmentDiscountNameUnique`, `CommitmentDiscountType`, `SubAccountName`, `SubAccountNameUnique`, `ResourceNameUnique`, and `x_ResourceGroupNameUnique` ([source YAML](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml)).

<br>

## Anomaly detection

Use anomaly detection tools to identify unusual cost patterns that need investigation ([anomaly tool source](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml)).

### cost-anomaly-detection

Source YAML: [`cost-anomaly-detection.yaml`](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml).

Queries cost time series and detects unusual spikes or drops across a configurable history window ([source YAML](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml)).

Use it when you need to triage unexpected spend changes, monitor recurring cost health, or explain why costs moved outside the normal pattern. Pair it with cost drill-down tools to find the affected service, region, or resource group ([source YAML](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml)).

Example prompt: "Detect cost anomalies over the last 90 days and explain the biggest spikes."

Sample output shape: One time-series row with `ChargePeriodStart`, `CostSeries`, and `anomalies`, where the series arrays represent the analyzed interval and the anomaly markers ([source YAML](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml)).

<br>

## Forecasting

Use forecasting tools to project future cost based on historical patterns ([forecasting tool source](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml)).

### cost-forecasting-model

Source YAML: [`cost-forecasting-model.yaml`](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml).

Queries historical cost trends and projects future effective cost ([source YAML](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml)).

Use it when preparing budgets, rolling forecasts, or expected run-rate discussions. It is most helpful when recent historical usage is representative of near-term demand ([source YAML](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml)).

Example prompt: "Forecast effective cost for the next three months based on recent trends."

Sample output shape: One time-series row with `ChargePeriodStart`, `EffectiveCostSeries`, and `forecast`, where the forecast array extends the historical cost series for the requested future periods ([source YAML](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml)).

<br>

## AI/ML costs

Use AI/ML cost tools to analyze Azure OpenAI and related AI service costs, token usage, model efficiency, and application ownership ([AI cost tool source](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml)).

### ai-cost-by-application

Source YAML: [`ai-cost-by-application.yaml`](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml).

Queries AI and machine learning costs by application, team, and environment tags ([source YAML](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml)).

Use it when you need showback, chargeback, or ownership analysis for AI workloads. It helps map AI spend to the applications and teams consuming it ([source YAML](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml)).

Example prompt: "Break down AI costs by application and environment for this month."

Sample output shape: One row per application, team, environment, and cost center with fields such as `Application`, `Team`, `Environment`, `CostCenter`, `EffectiveCost`, `TokenCount`, and `CostPer1KTokens` ([source YAML](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml)).

### ai-daily-trend

Source YAML: [`ai-daily-trend.yaml`](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml).

Queries daily AI and machine learning cost trends ([source YAML](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml)).

Use it when you need to monitor day-to-day AI spend, spot sudden changes, or prepare daily operating reports. It can also provide context before investigating token or model-level drivers ([source YAML](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml)).

Example prompt: "Show the daily AI cost trend for the last 30 days."

Sample output shape: One row per day with `ChargePeriodStart`, daily AI cost, daily token count, and cost per 1,000 tokens ([source YAML](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml)).

### ai-model-cost-comparison

Source YAML: [`ai-model-cost-comparison.yaml`](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml).

Queries AI model costs so the agent can compare costs across models ([source YAML](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml)).

Use it when evaluating model efficiency, unit economics, or opportunities to shift workloads to lower-cost models. It is useful for comparing model choices before changing application behavior ([source YAML](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml)).

Example prompt: "Compare costs across AI models and identify the most expensive models per 1,000 tokens."

Sample output shape: One row per model with `Model`, `TokenCount`, `EffectiveCost`, `ListCost`, `CostPer1KTokens`, `ListPer1KTokens`, and `DiscountPercent` ([source YAML](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml)).

### ai-token-usage-breakdown

Source YAML: [`ai-token-usage-breakdown.yaml`](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml).

Queries AI token usage by model, model version, and input or output direction ([source YAML](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml)).

Use it when token consumption is the suspected cost driver or when you need to separate prompt and completion usage. It helps connect AI cost changes to usage behavior ([source YAML](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml)).

Example prompt: "Break down token usage by model and input versus output tokens for the last week."

Sample output shape: One row per model and token direction with `Model`, `Direction`, `TokenCount`, `EffectiveCost`, `UnitCostPerToken`, and `CostPer1KTokens` ([source YAML](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml)).

<br>

## Workload optimization

Use workload optimization tools to identify idle, orphaned, or wasteful resources before starting cleanup work ([current tool inventory](../../../src/templates/sre-agent/tools/)).

### idle-resource-sweep

Source status: No `idle-resource-sweep.yaml` file appears in the source inventory for [`src/templates/sre-agent/tools`](../../../src/templates/sre-agent/tools/).

Reviews idle or orphaned resource candidates for workload optimization ([source inventory](../../../src/templates/sre-agent/tools/)).

This Gate-named tool is a required analysis path, but the current template doesn't include an `idle-resource-sweep` Kusto tool YAML file. Until a dedicated tool is added, ground idle-resource reviews with `top-resource-types-by-cost`, `top-resource-groups-by-cost`, and narrow `costs-enriched-base` drill-downs, then correlate candidates with Azure Resource Graph or Azure Advisor data through the relevant Python or built-in Azure tools before recommending cleanup ([source inventory](../../../src/templates/sre-agent/tools/)).

Example prompt: "Find likely idle or orphaned resources and group them by resource type, subscription, and estimated monthly cost."

Sample output shape: A candidate list with fields such as `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `x_ResourceGroupName`, `RegionName`, `ServiceName`, `EffectiveCost`, `LastUsageSignal`, `IdleReason`, `RecommendedAction`, and `Confidence`. When using the current template, this shape is assembled from existing cost aggregates, enriched cost rows, and external Azure inventory or recommendation signals rather than returned by a single shipped Kusto tool ([source inventory](../../../src/templates/sre-agent/tools/)).

<br>

## Price analysis

Use price analysis tools to compare prices, savings, and non-commitment transactions that affect total cost ([price analysis tool source](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml)).

### service-price-benchmarking

Source YAML: [`service-price-benchmarking.yaml`](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml).

Queries service price benchmarks, including list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings ([source YAML](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml)).

Use it when you need to compare prices across services or understand how negotiated and commitment discounts affect effective rates. It helps identify services with the largest rate optimization opportunity ([source YAML](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml)).

Example prompt: "Benchmark service prices and show where negotiated or commitment savings are highest."

Sample output shape: One row per service with `ServiceName`, `ListCost`, `ContractedCost`, `EffectiveCost`, negotiated savings, commitment discount savings, total savings, and savings percentages ([source YAML](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml)).

### top-other-transactions

Source YAML: [`top-other-transactions.yaml`](../../../src/templates/sre-agent/tools/top-other-transactions.yaml).

Queries the largest non-usage and non-commitment transactions, such as Marketplace or miscellaneous charges ([source YAML](../../../src/templates/sre-agent/tools/top-other-transactions.yaml)).

Use it when costs don't reconcile to normal usage or commitment purchases. It helps isolate large one-time or nonstandard transactions that can distort monthly cost trends ([source YAML](../../../src/templates/sre-agent/tools/top-other-transactions.yaml)).

Example prompt: "Show the largest non-usage and non-commitment transactions this month."

Sample output shape: One row per non-usage, non-commitment transaction with `ChargePeriodStart`, `ChargeCategory`, `BilledCost`, `BillingCurrency`, `SubAccountName`, `x_InvoiceSectionName`, `PricingCategory`, `PricingQuantity`, `PricingUnit`, `ProviderName`, and `PublisherName` ([source YAML](../../../src/templates/sre-agent/tools/top-other-transactions.yaml)).

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

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Azure Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit SRE Agent](overview.md)
- [FinOps toolkit SRE Agent tools](tools.md)
- [Python tools](python-tools.md)

<br>
