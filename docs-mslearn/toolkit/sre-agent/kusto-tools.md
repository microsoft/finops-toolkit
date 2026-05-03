---
title: Kusto tools
description: Review the FinOps hub Kusto tools included with the FinOps toolkit SRE Agent and learn when to use each tool for cost, commitment discount, anomaly, forecast, AI, and price analysis.
author: msbrett
ms.author: brettwil
ms.date: 05/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand each FinOps toolkit SRE Agent Kusto tool so that I can choose the right query for cost and optimization analysis.
---

# Kusto tools

The FinOps toolkit SRE Agent includes 21 Kusto tools that query your FinOps hub Azure Data Explorer database through the `finops-hub-kusto` connector. Each tool is configured as a `KustoTool` and uses the FinOps hub query catalog to ground agent responses in cost, price, recommendation, transaction, and AI usage data. Tool source lives at [`src/templates/sre-agent/tools`](../../../src/templates/sre-agent/tools/).

This reference also calls out related optimization tools that appear in scheduled-task requirements when they affect the same analysis path. Those tools aren't Kusto tools unless explicitly marked as `KustoTool`.

Use this reference when you want to understand which tool fits a prompt, scheduled task, or custom agent workflow. For a summary of all the agent's tools, see [FinOps toolkit SRE Agent tools](tools.md).

<br>

## Source validation

The template source contains 34 tool YAML files in [`src/templates/sre-agent/tools`](../../../src/templates/sre-agent/tools/). The production FinOps hub Kusto inventory is the subset with `spec.type: KustoTool` and `spec.connector: finops-hub-kusto`. That subset contains 21 tools. The remaining files are 12 `PythonTool` files and one example `KustoTool` that uses `example_connector`, so they aren't part of the FinOps hub Kusto catalog.

| Source category | Count | Evidence |
|-----------------|------:|----------|
| FinOps hub Kusto tools | 21 | [`ai-cost-by-application`](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml), [`ai-daily-trend`](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml), [`ai-model-cost-comparison`](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml), [`ai-token-usage-breakdown`](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml), [`commitment-discount-utilization`](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml), [`cost-anomaly-detection`](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml), [`cost-by-financial-hierarchy`](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml), [`cost-by-region-trend`](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml), [`cost-forecasting-model`](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml), [`costs-enriched-base`](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml), [`monthly-cost-change-percentage`](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml), [`monthly-cost-trend`](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml), [`quarterly-cost-by-resource-group`](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml), [`reservation-recommendation-breakdown`](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml), [`savings-summary-report`](../../../src/templates/sre-agent/tools/savings-summary-report.yaml), [`service-price-benchmarking`](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml), [`top-commitment-transactions`](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml), [`top-other-transactions`](../../../src/templates/sre-agent/tools/top-other-transactions.yaml), [`top-resource-groups-by-cost`](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml), [`top-resource-types-by-cost`](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml), and [`top-services-by-cost`](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml) |
| Related Python tools | 12 | [`benefit-recommendations`](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml), [`capacity-reservation-groups`](../../../src/templates/sre-agent/tools/capacity-reservation-groups.yaml), [`data-freshness-check`](../../../src/templates/sre-agent/tools/data-freshness-check.yaml), [`deploy-anomaly-alert`](../../../src/templates/sre-agent/tools/deploy-anomaly-alert.yaml), [`deploy-budget`](../../../src/templates/sre-agent/tools/deploy-budget.yaml), [`deploy-bulk-anomaly-alerts`](../../../src/templates/sre-agent/tools/deploy-bulk-anomaly-alerts.yaml), [`deploy-bulk-budgets`](../../../src/templates/sre-agent/tools/deploy-bulk-budgets.yaml), [`non-compute-quotas`](../../../src/templates/sre-agent/tools/non-compute-quotas.yaml), [`resource-graph-query`](../../../src/templates/sre-agent/tools/resource-graph-query.yaml), [`sku-availability`](../../../src/templates/sre-agent/tools/sku-availability.yaml), [`suppress-advisor-recommendations`](../../../src/templates/sre-agent/tools/suppress-advisor-recommendations.yaml), and [`vm-quota-usage`](../../../src/templates/sre-agent/tools/vm-quota-usage.yaml) |
| Excluded example tool | 1 | [`example_tool`](../../../src/templates/sre-agent/tools/example_tool.yaml) is a sample `KustoTool` with `example_connector`, not `finops-hub-kusto`. |

<br>

## Cost analysis

Use cost analysis tools to review cost and usage from different reporting angles, including time, service, resource group, region, billing hierarchy, and resource type.

### costs-enriched-base

Source YAML: [`costs-enriched-base.yaml`](../../../src/templates/sre-agent/tools/costs-enriched-base.yaml).

Queries a guarded, enriched row-level cost and usage sample with tags, resource details, savings fields, commitment fields, and FinOps Toolkit metadata.

Use it only for narrow detail drill-downs after an aggregate result identifies the scope to inspect. The tool rejects windows greater than one day to avoid Azure Data Explorer result truncation. For full-month, fiscal-period, scheduled report, dashboard export, allocation, showback, chargeback, tag-coverage, or broad custom analysis, use aggregate tools first, such as `monthly-cost-trend`, `cost-by-financial-hierarchy`, `top-services-by-cost`, `top-resource-groups-by-cost`, or `top-resource-types-by-cost`.

Example prompt: "Show me enriched cost details for yesterday's top resource group, including tags and resource group."

Sample output shape: One row per cost record with fields such as `ChargePeriodStart`, `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `ServiceName`, `x_ResourceGroupName`, `BilledCost`, `EffectiveCost`, `ContractedCost`, `ListCost`, `PricingQuantity`, `Tags`, `CommitmentDiscountType`, `CommitmentDiscountStatus`, `x_TotalSavings`, and `x_FreeReason`.

### monthly-cost-trend

Source YAML: [`monthly-cost-trend.yaml`](../../../src/templates/sre-agent/tools/monthly-cost-trend.yaml).

Queries monthly billed and effective cost totals to show cost trends over time.

Use it when you need a month-by-month view for budget reviews, executive summaries, or recurring FinOps reporting. It helps identify whether spend is increasing, decreasing, or stabilizing.

Example prompt: "Show the monthly cost trend for the last six months."

Sample output shape: One row per month with `x_ChargeMonth`, `BilledCost`, and `EffectiveCost`.

### monthly-cost-change-percentage

Source YAML: [`monthly-cost-change-percentage.yaml`](../../../src/templates/sre-agent/tools/monthly-cost-change-percentage.yaml).

Queries month-over-month billed and effective cost changes as percentages.

Use it when stakeholders ask how much costs changed between months or when you need to find volatility quickly. It works well for variance reviews and cost spike triage.

Example prompt: "Which months had the largest percentage increase in effective cost?"

Sample output shape: One row per month with `ChargePeriodStart`, `BilledCost`, `EffectiveCost`, `PreviousBilledCost`, `PreviousEffectiveCost`, billed-cost change percentage, and effective-cost change percentage.

### quarterly-cost-by-resource-group

Source YAML: [`quarterly-cost-by-resource-group.yaml`](../../../src/templates/sre-agent/tools/quarterly-cost-by-resource-group.yaml).

Queries quarterly cost by resource group, subscription, and month for a reporting window.

Use it when preparing quarterly business reviews or resource-group-level accountability reports. It helps teams connect quarterly cost movement to resource ownership and subscription context.

Example prompt: "Break down quarterly costs by resource group for the last quarter."

Sample output shape: One row per subscription, resource group, and month with `SubAccountName`, `x_ResourceGroupName`, `x_ChargeMonth`, and `EffectiveCost`.

### cost-by-region-trend

Source YAML: [`cost-by-region-trend.yaml`](../../../src/templates/sre-agent/tools/cost-by-region-trend.yaml).

Queries effective cost trends by Azure region.

Use it when you need to understand regional cost distribution, investigate regional growth, or evaluate whether workloads are shifting between regions. It can also support capacity and placement discussions.

Example prompt: "Show cost trends by Azure region over the last three months."

Sample output shape: One row per region with `RegionName` and `EffectiveCost`.

### cost-by-financial-hierarchy

Source YAML: [`cost-by-financial-hierarchy.yaml`](../../../src/templates/sre-agent/tools/cost-by-financial-hierarchy.yaml).

Queries costs organized by billing profile, invoice section, team, product, application, environment, and other financial hierarchy fields.

Use it when you need a finance-aligned view for allocation, showback, chargeback, or executive reporting. It helps translate resource-level usage into business ownership.

Example prompt: "Summarize costs by billing profile, team, product, and application."

Sample output shape: One row per financial hierarchy combination with `x_BillingProfileName`, `x_InvoiceSectionName`, `x_Team`, `x_Product`, `x_Application`, `x_Environment`, `EffectiveCost`, and `PercentOfTotal`.

### top-services-by-cost

Source YAML: [`top-services-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-services-by-cost.yaml).

Queries the Azure services with the highest effective cost.

Use it when you need to prioritize service-level optimization or identify which services drive overall spend. Start here for broad cost reviews before drilling into resources or resource groups.

Example prompt: "What are the top 10 Azure services by cost this month?"

Sample output shape: One row per service with `ServiceName` and `EffectiveCost`.

### top-resource-types-by-cost

Source YAML: [`top-resource-types-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-resource-types-by-cost.yaml).

Queries the resource types with the highest effective cost and resource counts.

Use it when you need to understand which resource categories are driving spend, such as virtual machines, disks, databases, or networking resources. It helps identify optimization themes across many resources.

Example prompt: "List the top resource types by effective cost and resource count."

Sample output shape: One row per resource type with `ResourceType`, `ResourceCount`, and `EffectiveCost`.

### top-resource-groups-by-cost

Source YAML: [`top-resource-groups-by-cost.yaml`](../../../src/templates/sre-agent/tools/top-resource-groups-by-cost.yaml).

Queries the resource groups with the highest effective cost.

Use it when you need an owner-friendly cost view or want to focus optimization work on the most expensive resource groups. It is useful for team accountability and workload-level reviews.

Example prompt: "Which resource groups had the highest costs in the last 30 days?"

Sample output shape: One row per subscription and resource group with `SubAccountName`, `x_ResourceGroupName`, and `EffectiveCost`.

<br>

## Commitment discounts

Use commitment discount tools to review reservation and savings plan utilization, recommendations, realized savings, and purchase transactions.

### commitment-discount-utilization

Source YAML: [`commitment-discount-utilization.yaml`](../../../src/templates/sre-agent/tools/commitment-discount-utilization.yaml).

Queries consumed core hours by commitment discount type, including reservation, savings plan, and on-demand usage.

Use it when you need to understand how well commitments are being used and whether uncovered on-demand usage remains. It helps compare capacity planning, usage patterns, and commitment coverage.

Example prompt: "Show reservation and savings plan utilization for the last month."

Sample output shape: One row per commitment category with `CommitmentDiscountType`, `TotalConsumedCoreHours`, and `PercentOfTotal`. Empty commitment types are reported as `On Demand`.

### reservation-recommendation-breakdown

Source YAML: [`reservation-recommendation-breakdown.yaml`](../../../src/templates/sre-agent/tools/reservation-recommendation-breakdown.yaml).

Queries detailed reservation recommendations, including savings, break-even dates, normalized sizes, scope, and term details.

Use it when evaluating whether to buy reservations or when preparing a recommendation package for finance and workload owners. It helps compare potential savings with commitment risk.

Example prompt: "Break down reservation purchase recommendations by service, term, and expected savings."

Sample output shape: One row per reservation recommendation with fields such as `RegionId`, normalized size or group details, `x_SkuMeterId`, `x_SkuTerm`, expected before and after effective cost, `x_BreakEvenMonths`, and `x_BreakEvenDate`.

### benefit-recommendations

Source YAML: [`benefit-recommendations.yaml`](../../../src/templates/sre-agent/tools/benefit-recommendations.yaml).

Gets Azure Cost Management benefit recommendations for savings plans and reserved instances at a billing scope.

This is a related optimization tool, but it's a `PythonTool`, not a Kusto tool. Use it when the agent needs current Cost Management recommendation API results by billing scope, lookback period, and term. Use `reservation-recommendation-breakdown` when you need FinOps hub recommendation data from `Recommendations()`.

Example prompt: "Get current savings plan and reservation benefit recommendations for this billing profile."

Sample output shape: A JSON object with `billing_scope`, `lookback_period`, `term`, `count`, and `recommendations`. Each recommendation includes fields such as `type`, `savings`, `cost`, `total_cost`, `cost_without_benefit`, `term`, `break_even`, `id`, and `name`. If the request can't run, the object includes an `error` field.

### savings-summary-report

Source YAML: [`savings-summary-report.yaml`](../../../src/templates/sre-agent/tools/savings-summary-report.yaml).

Queries list cost, effective cost, negotiated savings, commitment savings, total savings, and savings rate.

Use it when you need a summary of savings from discounts and commitments compared with pay-as-you-go pricing. It works well for executive reporting and rate optimization reviews.

Example prompt: "Summarize total savings from negotiated rates and commitment discounts this month."

Sample output shape: One row per billing currency with `BillingCurrency`, `ListCost`, `ContractedCost`, `EffectiveCost`, `x_NegotiatedDiscountSavings`, `x_CommitmentDiscountSavings`, `x_TotalSavings`, and `x_EffectiveSavingsRate`.

### top-commitment-transactions

Source YAML: [`top-commitment-transactions.yaml`](../../../src/templates/sre-agent/tools/top-commitment-transactions.yaml).

Queries the largest non-usage commitment discount purchase transactions, including reservations and savings plans.

Use it when investigating major commitment-related charges, purchase timing, or renewal activity. It helps separate commitment purchases from normal usage costs.

Example prompt: "Show the largest reservation and savings plan transactions this quarter."

Sample output shape: One row per commitment purchase transaction with `ChargePeriodStart`, `ChargeCategory`, `BilledCost`, `BillingCurrency`, `CommitmentDiscountName`, `CommitmentDiscountNameUnique`, `CommitmentDiscountType`, `SubAccountName`, `SubAccountNameUnique`, `ResourceNameUnique`, and `x_ResourceGroupNameUnique`.

<br>

## Anomaly detection

Use anomaly detection tools to identify unusual cost patterns that need investigation.

### cost-anomaly-detection

Source YAML: [`cost-anomaly-detection.yaml`](../../../src/templates/sre-agent/tools/cost-anomaly-detection.yaml).

Queries cost time series and detects unusual spikes or drops across a configurable history window.

Use it when you need to triage unexpected spend changes, monitor recurring cost health, or explain why costs moved outside the normal pattern. Pair it with cost drill-down tools to find the affected service, region, or resource group.

Example prompt: "Detect cost anomalies over the last 90 days and explain the biggest spikes."

Sample output shape: One time-series row with `ChargePeriodStart`, `CostSeries`, and `anomalies`, where the series arrays represent the analyzed interval and the anomaly markers.

<br>

## Forecasting

Use forecasting tools to project future cost based on historical patterns.

### cost-forecasting-model

Source YAML: [`cost-forecasting-model.yaml`](../../../src/templates/sre-agent/tools/cost-forecasting-model.yaml).

Queries historical cost trends and projects future effective cost.

Use it when preparing budgets, rolling forecasts, or expected run-rate discussions. It is most helpful when recent historical usage is representative of near-term demand.

Example prompt: "Forecast effective cost for the next three months based on recent trends."

Sample output shape: One time-series row with `ChargePeriodStart`, `EffectiveCostSeries`, and `forecast`, where the forecast array extends the historical cost series for the requested future periods.

<br>

## AI/ML costs

Use AI/ML cost tools to analyze Azure OpenAI and related AI service costs, token usage, model efficiency, and application ownership.

### ai-cost-by-application

Source YAML: [`ai-cost-by-application.yaml`](../../../src/templates/sre-agent/tools/ai-cost-by-application.yaml).

Queries AI and machine learning costs by application, team, and environment tags.

Use it when you need showback, chargeback, or ownership analysis for AI workloads. It helps map AI spend to the applications and teams consuming it.

Example prompt: "Break down AI costs by application and environment for this month."

Sample output shape: One row per application, team, environment, and cost center with fields such as `Application`, `Team`, `Environment`, `CostCenter`, `EffectiveCost`, `TokenCount`, and `CostPer1KTokens`.

### ai-daily-trend

Source YAML: [`ai-daily-trend.yaml`](../../../src/templates/sre-agent/tools/ai-daily-trend.yaml).

Queries daily AI and machine learning cost trends.

Use it when you need to monitor day-to-day AI spend, spot sudden changes, or prepare daily operating reports. It can also provide context before investigating token or model-level drivers.

Example prompt: "Show the daily AI cost trend for the last 30 days."

Sample output shape: One row per day with `ChargePeriodStart`, daily AI cost, daily token count, and cost per 1,000 tokens.

### ai-model-cost-comparison

Source YAML: [`ai-model-cost-comparison.yaml`](../../../src/templates/sre-agent/tools/ai-model-cost-comparison.yaml).

Queries AI model costs so the agent can compare costs across models.

Use it when evaluating model efficiency, unit economics, or opportunities to shift workloads to lower-cost models. It is useful for comparing model choices before changing application behavior.

Example prompt: "Compare costs across AI models and identify the most expensive models per 1,000 tokens."

Sample output shape: One row per model with `Model`, `TokenCount`, `EffectiveCost`, `ListCost`, `CostPer1KTokens`, `ListPer1KTokens`, and `DiscountPercent`.

### ai-token-usage-breakdown

Source YAML: [`ai-token-usage-breakdown.yaml`](../../../src/templates/sre-agent/tools/ai-token-usage-breakdown.yaml).

Queries AI token usage by model, model version, and input or output direction.

Use it when token consumption is the suspected cost driver or when you need to separate prompt and completion usage. It helps connect AI cost changes to usage behavior.

Example prompt: "Break down token usage by model and input versus output tokens for the last week."

Sample output shape: One row per model and token direction with `Model`, `Direction`, `TokenCount`, `EffectiveCost`, `UnitCostPerToken`, and `CostPer1KTokens`.

<br>

## Workload optimization

Use workload optimization tools to identify idle, orphaned, or wasteful resources before starting cleanup work.

### idle-resource-sweep

Source status: No `idle-resource-sweep.yaml` file appears in the source inventory for [`src/templates/sre-agent/tools`](../../../src/templates/sre-agent/tools/).

Reviews idle or orphaned resource candidates for workload optimization.

This Gate-named tool is a required analysis path, but the current template doesn't include an `idle-resource-sweep` Kusto tool YAML file. Until a dedicated tool is added, ground idle-resource reviews with `top-resource-types-by-cost`, `top-resource-groups-by-cost`, and narrow `costs-enriched-base` drill-downs. Then correlate candidates with Azure Resource Graph or Azure Advisor data through the relevant Python or built-in Azure tools before recommending cleanup.

Example prompt: "Find likely idle or orphaned resources and group them by resource type, subscription, and estimated monthly cost."

Sample output shape: A candidate list with fields such as `SubAccountName`, `ResourceId`, `ResourceName`, `ResourceType`, `x_ResourceGroupName`, `RegionName`, `ServiceName`, `EffectiveCost`, `LastUsageSignal`, `IdleReason`, `RecommendedAction`, and `Confidence`. When using the current template, this shape is assembled from existing cost aggregates, enriched cost rows, and external Azure inventory or recommendation signals rather than returned by a single shipped Kusto tool.

<br>

## Price analysis

Use price analysis tools to compare prices, savings, and non-commitment transactions that affect total cost.

### service-price-benchmarking

Source YAML: [`service-price-benchmarking.yaml`](../../../src/templates/sre-agent/tools/service-price-benchmarking.yaml).

Queries service price benchmarks, including list cost, contracted cost, effective cost, negotiated savings, commitment savings, and total savings.

Use it when you need to compare prices across services or understand how negotiated and commitment discounts affect effective rates. It helps identify services with the largest rate optimization opportunity.

Example prompt: "Benchmark service prices and show where negotiated or commitment savings are highest."

Sample output shape: One row per service with `ServiceName`, `ListCost`, `ContractedCost`, `EffectiveCost`, negotiated savings, commitment discount savings, total savings, and savings percentages.

### top-other-transactions

Source YAML: [`top-other-transactions.yaml`](../../../src/templates/sre-agent/tools/top-other-transactions.yaml).

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

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Azure Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit SRE Agent](overview.md)
- [FinOps toolkit SRE Agent tools](tools.md)
- [Python tools](python-tools.md)

<br>
