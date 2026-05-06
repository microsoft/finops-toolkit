---
title: Scheduled tasks (Azure SRE Agent in the FinOps toolkit)
description: Learn how the FinOps toolkit's scheduled tasks automate daily, weekly, monthly, and quarterly FinOps operating rhythms on Azure SRE Agent.
author: msbrett
ms.author: brettwil
ms.date: 05/06/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand the scheduled tasks the FinOps toolkit deploys to Azure SRE Agent so that I can plan recurring cost, capacity, and finance reviews.
---

# Scheduled tasks (Azure SRE Agent in the FinOps toolkit)

The FinOps toolkit ships scheduled tasks that run recurring FinOps operating-rhythm workflows on Azure SRE Agent. They turn common reviews into autonomous checks that gather data, route work to the right specialist agent, generate charts where the data supports them, and post completed reports to Microsoft Teams when a Teams notification connector is configured.

The template deploys 18 scheduled tasks from `src/templates/sre-agent/sre-config/scheduled-tasks/`. These tasks cover daily health checks, weekly optimization and capacity reviews, monthly planning and finance reports, and quarterly strategy.

<br>

## Daily tasks

Daily tasks run every morning to validate FinOps hub health, monitor capacity supply chain signals, and analyze month-over-month cost movement. They keep cost and capacity surprises visible before each business day.

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `HubsHealthCheck` | `ftk-hubs-agent` | Daily at 6:00 AM<br>`0 6 * * *` | FinOps hub version and data freshness validation |
| `CapacityDailyMonitor` | `azure-capacity-manager` | Daily at 6:30 AM<br>`30 6 * * *` | Daily capacity supply chain health check — quota usage, CRG utilization, zone capacity |
| `MOM` | `finops-practitioner` | Daily at 5:15 PM<br>`15 17 * * *` | Autonomous month-over-month cost analysis with all 17 Kusto tools |

<br>

## Weekly tasks

Weekly tasks summarize cost optimization, capacity supply chain, and benefit recommendation activity for the previous week. They give the team a recurring rhythm for deeper analysis without manual report requests.

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `ComputeUtilizationTrend` | `azure-capacity-manager` | Weekly on Monday at 7:00 AM<br>`0 7 * * 1` | Weekly VM quota utilization trend review across subscriptions and regions |
| `CostOptimization` | `finops-practitioner` | Weekly on Monday at 8:00 AM<br>`0 8 * * 1` | Comprehensive cost optimization report with orphaned resources, rightsizing, and commitment analysis |
| `CapacityWeeklySupplyReview` | `azure-capacity-manager` | Weekly on Monday at 8:00 AM<br>`0 8 * * 1` | Weekly capacity supply chain review — quota headroom, CRG cost optimization, SKU availability, benefit recommendations |
| `NonComputeQuotaAudit` | `azure-capacity-manager` | Weekly on Tuesday at 7:00 AM<br>`0 7 * * 2` | Weekly audit of storage, network, and non-compute quota usage at risk |
| `SkuAvailabilityAudit` | `azure-capacity-manager` | Weekly on Wednesday at 7:00 AM<br>`0 7 * * 3` | Weekly audit of regional SKU availability and restrictions that could block deployments |
| `MonitoringScopeValidation` | `ftk-hubs-agent` | Weekly on Thursday at 9:00 AM<br>`0 9 * * 4` | Weekly validation that FinOps hub monitoring covers all active subscriptions |
| `BenefitRecommendationReview` | `chief-financial-officer` | Weekly on Friday at 8:00 AM<br>`0 8 * * 5` | Weekly executive review of reservation and savings plan recommendations |

<br>

## Monthly tasks

Monthly tasks run after billing data finalizes to produce year-to-date analysis, capacity planning forecasts, AI workload cost reviews, and audit reports for budget and alert coverage. Use them to anchor monthly business reviews.

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `StoragePaasGrowthForecast` | `azure-capacity-manager` | Monthly on the 1st at 8:00 AM<br>`0 8 1 * *` | Monthly storage and PaaS quota growth forecast across active subscriptions |
| `AdvisorSuppressionReview` | `finops-practitioner` | Monthly on the 1st at 9:00 AM<br>`0 9 1 * *` | Monthly review of active Advisor recommendation suppressions for stale or expired decisions |
| `CapacityMonthlyPlanning` | `azure-capacity-manager` | Monthly on the 1st at 9:00 AM<br>`0 9 1 * *` | Monthly capacity planning cycle — forecast demand, procurement pipeline, governance review |
| `YTD` | `chief-financial-officer` | Monthly on the 1st at 9:00 AM<br>`0 9 1 * *` | Fiscal year-to-date analysis with forecast through end of fiscal year |
| `AIWorkloadCostAnalysis` | `chief-financial-officer` | Monthly on the 1st at 10:00 AM<br>`0 10 1 * *` | Monthly AI workload cost analysis — token economics, model efficiency, and cost allocation for Azure OpenAI |
| `BudgetCoverageAudit` | `finops-practitioner` | Monthly on the 15th at 8:00 AM<br>`0 8 15 * *` | Monthly audit of subscription budget coverage and missing budget controls |
| `AlertCoverageAudit` | `finops-practitioner` | Monthly on the 16th at 8:00 AM<br>`0 8 16 * *` | Monthly audit of cost anomaly alert coverage across active subscriptions |

<br>

## Quarterly tasks

Quarterly tasks run at the start of each calendar quarter to summarize capacity supply chain maturity, commitment alignment, and architecture evolution. Use them to feed leadership reviews and the next quarter's planning cycle.

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `CapacityQuarterlyStrategy` | `azure-capacity-manager` | Quarterly on January 1, April 1, July 1, and October 1 at 9:00 AM<br>`0 9 1 1,4,7,10 *` | Quarterly capacity strategy review — supply chain maturity, commitment alignment, architecture evolution |

<br>

## Task details

Each scheduled task is defined in YAML under `src/templates/sre-agent/sre-config/scheduled-tasks/`. You can customize the schedule by changing the `cron_expression` in the task definition before deployment. You can also tune the task prompt to change thresholds, scope, report sections, and recommended actions for your operating model.

### HubsHealthCheck

- **Data sources queried:** GitHub release metadata for the latest FinOps hub version, Azure resource discovery for deployed hub resources, and the `data-freshness-check` tool for the latest `Costs()` update date. The task also validates hub connectivity before trusting downstream scheduled reports.
- **Output format and content:** A daily health summary that reports deployed version status, latest available version, data refresh status, connectivity findings, and any blocking hub issues. The report is formatted for Teams when notifications are configured.
- **Recommended actions generated:** Upgrade FinOps hubs when the deployed version is behind, investigate stale exports or ingestion failures, restore connectivity, and delay cost analysis that depends on stale hub data.
- **Customization options:** Change the daily cron from `0 6 * * *`, adjust how many days of data freshness lag is acceptable, add organization-specific hub resource filters, and add required escalation steps for stale data or version drift.

### CapacityDailyMonitor

- **Data sources queried:** VM quota usage through `vm-quota-usage`, capacity reservation group data through `capacity-reservation-groups`, non-compute quota context through `non-compute-quotas`, Azure CLI discovery for AKS and regional resources, and hub freshness checks where cost context is needed.
- **Output format and content:** A daily capacity supply-chain health report with quota pressure, capacity reservation utilization, AKS node pool readiness, alert status, and urgent capacity blockers.
- **Recommended actions generated:** File quota increases, redistribute workload demand, adjust capacity reservation groups, investigate underutilized reservations, validate AKS node pool capacity, and escalate imminent deployment blockers.
- **Customization options:** Change the daily cron from `30 6 * * *`, tune warning and critical quota-utilization thresholds, define target capacity reservation utilization bands, scope monitored subscriptions or regions, and add workload-specific AKS node pool checks.

### MOM

- **Data sources queried:** FinOps hub Kusto tools including `data-freshness-check`, `monthly-cost-trend`, `monthly-cost-change-percentage`, `top-services-by-cost`, `top-resource-groups-by-cost`, `cost-by-region-trend`, `cost-anomaly-detection`, `savings-summary-report`, `commitment-discount-utilization`, `cost-forecasting-model`, `reservation-recommendation-breakdown`, `top-resource-types-by-cost`, `service-price-benchmarking`, `top-other-transactions`, and `costs-enriched-base`.
- **Output format and content:** A daily month-over-month cost analysis with executive summary, service and resource group drivers, anomalies, forecasts, savings and commitment signals, regional distribution, tag coverage, marketplace or other purchases, charts where data supports them, and action items.
- **Recommended actions generated:** Investigate anomalies, correct cost allocation gaps, prioritize cost drivers, act on savings opportunities, review commitment utilization, address forecast risk, and validate tags or financial hierarchy gaps.
- **Customization options:** Change the daily cron from `15 17 * * *`, adjust anomaly and variance thresholds, change the comparison window, scope the analysis to selected subscriptions or billing entities, and add or remove Kusto sections from the report.

### ComputeUtilizationTrend

- **Data sources queried:** VM quota utilization through `vm-quota-usage`, Azure Resource Graph subscription and VM inventory, and prior-period utilization signals from the scheduled analysis prompt.
- **Output format and content:** A weekly trend report that lists quota families, subscriptions, regions, current utilization, week-over-week movement, and quota lines approaching defined risk thresholds.
- **Recommended actions generated:** Request quota increases for growing usage, move demand to lower-pressure regions or quota families, validate planned deployments against headroom, and close stale quota allocations that are no longer needed.
- **Customization options:** Change the weekly cron from `0 7 * * 1`, tune warning and critical utilization thresholds, choose the trend lookback window, filter to production subscriptions or priority regions, and add business-unit routing for quota owners.

### CostOptimization

- **Data sources queried:** Azure Resource Graph for orphaned and idle resources, Advisor cost recommendations, commitment and benefit recommendation tools, Azure CLI resource validation, optional VM utilization data, and FinOps hub data when available.
- **Output format and content:** A weekly cost optimization report with executive summary, quick wins, orphaned resources, rightsizing candidates, commitment discount status, effort and risk categories, estimated savings, and charts for major opportunities.
- **Recommended actions generated:** Delete or remediate orphaned resources, resize underutilized workloads, buy or adjust reservations and savings plans, validate Advisor recommendations, and assign owners for high-value optimization actions.
- **Customization options:** Change the weekly cron from `0 8 * * 1`, tune savings and utilization thresholds, exclude protected resource groups or tags, change effort and risk categories, and modify recommendation ranking or minimum savings filters.

### CapacityWeeklySupplyReview

- **Data sources queried:** VM quota usage, `capacity-reservation-groups`, `non-compute-quotas`, `sku-availability`, benefit and reservation recommendations, Azure CLI regional discovery, and commitment-related cost signals.
- **Output format and content:** A weekly capacity supply review covering quota headroom, capacity reservation waste, SKU and zone availability, region access, non-compute constraints, and capacity-to-rate optimization opportunities.
- **Recommended actions generated:** Increase quota, rebalance capacity reservations, release or resize underused CRGs, validate alternate SKUs or regions, align capacity reservations with reservation or savings opportunities, and escalate SKU restrictions.
- **Customization options:** Change the weekly cron from `0 8 * * 1`, tune quota and CRG utilization thresholds, set approved regions and SKU allowlists, scope the review to critical workloads, and adjust how benefit recommendations are ranked.

### NonComputeQuotaAudit

- **Data sources queried:** `non-compute-quotas` for storage, network, and other service quota usage; subscription scope from Azure discovery; and service-specific quota values returned by Azure APIs when available.
- **Output format and content:** A weekly audit that separates reported and estimated limits, lists services and regions near limits, highlights quotas with missing limit telemetry, and summarizes risk by subscription.
- **Recommended actions generated:** Request quota increases, reduce or redistribute usage, add missing quota monitoring, validate estimated limits with service owners, and escalate high-risk storage or network quotas before deployments fail.
- **Customization options:** Change the weekly cron from `0 7 * * 2`, tune at-risk utilization thresholds, choose monitored services, scope subscriptions or regions, and define how to handle quotas that report current usage but not limits.

### SkuAvailabilityAudit

- **Data sources queried:** `sku-availability` for regional SKU availability and restrictions, Azure subscription and region discovery, and workload-provided SKU filters when present.
- **Output format and content:** A weekly availability report that lists requested SKUs by region, availability status, restrictions, deployment blockers, and recommended fallback regions or SKU families.
- **Recommended actions generated:** Change deployment region or SKU, request regional access where possible, update landing-zone allowed SKU lists, revise deployment plans, and escalate blockers that affect production capacity.
- **Customization options:** Change the weekly cron from `0 7 * * 3`, tune the SKU and region scope, add required workload SKUs, define preferred fallback regions, and change the severity threshold for restricted or unavailable SKUs.

### MonitoringScopeValidation

- **Data sources queried:** Azure Resource Graph for active subscription inventory, FinOps hub `data-freshness-check`, hub database and cluster configuration, and subscription coverage comparisons between Azure and hub data.
- **Output format and content:** A weekly monitoring coverage report showing active subscriptions, subscriptions with fresh hub data, subscriptions missing from monitoring, stale coverage, and evidence for scope gaps.
- **Recommended actions generated:** Add missing subscriptions to exports or hub monitoring, fix stale export configuration, validate hub permissions, update subscription onboarding processes, and pause unsupported financial analysis for missing scopes.
- **Customization options:** Change the weekly cron from `0 9 * * 4`, tune data freshness thresholds, filter excluded or retired subscriptions, change the required coverage percentage, and add owner routing for missing subscription remediation.

### BenefitRecommendationReview

- **Data sources queried:** `benefit-recommendations` for reservation and savings plan opportunities, billing-scope context, commitment discount utilization, and related cost summaries for executive prioritization.
- **Output format and content:** A weekly executive report with total savings opportunity, recommendation categories, term and scope assumptions, purchase candidates, risk notes, and decision-ready next steps.
- **Recommended actions generated:** Approve high-confidence purchases, reject or defer recommendations that conflict with demand forecasts, adjust commitment coverage, request validation from workload owners, and document finance approval decisions.
- **Customization options:** Change the weekly cron from `0 8 * * 5`, tune minimum savings and confidence thresholds, set preferred commitment terms, scope recommendations by billing profile or subscription, and add finance approval rules.

### StoragePaasGrowthForecast

- **Data sources queried:** `non-compute-quotas` for current storage and PaaS quota usage, Azure Resource Graph for service inventory, subscription scope from Azure discovery, and historical growth signals derived from current usage where available.
- **Output format and content:** A monthly forecast that identifies storage and PaaS services approaching limits, current usage and limit signals, projected growth risk, and subscriptions needing quota planning.
- **Recommended actions generated:** Request quota increases, archive or clean up unused capacity, move demand to less constrained subscriptions or regions, add service-specific monitoring, and validate growth assumptions with workload owners.
- **Customization options:** Change the monthly cron from `0 8 1 * *`, tune forecast horizon and risk thresholds, select included PaaS services, define acceptable headroom, and add workload-specific growth assumptions.

### AdvisorSuppressionReview

- **Data sources queried:** Azure Resource Graph for Advisor suppression resources and metadata, subscription inventory, suppression age and expiration fields, and related recommendation context where available.
- **Output format and content:** A monthly suppression inventory with active, stale, expired, and undocumented suppressions; affected recommendations; age; owner information; and remediation status.
- **Recommended actions generated:** Remove expired suppressions, renew justified suppressions with documentation, restore important Advisor recommendations, assign owners for stale decisions, and create follow-up work for risky suppressed savings.
- **Customization options:** Change the monthly cron from `0 9 1 * *`, tune stale-age and expiration thresholds, scope suppression review by subscription or owner tag, add required justification fields, and define exception approval rules.

### CapacityMonthlyPlanning

- **Data sources queried:** `cost-forecasting-model`, `vm-quota-usage`, `capacity-reservation-groups`, `resource-graph-query`, `commitment-discount-utilization`, `savings-summary-report`, and benefit recommendations for demand, procurement, allocation, and cost impact.
- **Output format and content:** A monthly capacity planning packet with demand forecast, procurement pipeline, quota and CRG allocation review, cost impact, governance findings, and planning decisions.
- **Recommended actions generated:** Submit quota and capacity requests, adjust capacity reservations, align procurement with forecasted demand, rebalance allocation across subscriptions, and update governance controls for capacity planning.
- **Customization options:** Change the monthly cron from `0 9 1 * *`, tune forecast horizon and growth thresholds, choose capacity planning regions and SKUs, set acceptable CRG utilization bands, and add procurement workflow fields.

### YTD

- **Data sources queried:** FinOps hub Kusto tools including `monthly-cost-trend`, `quarterly-cost-by-resource-group`, `cost-anomaly-detection`, `savings-summary-report`, `commitment-discount-utilization`, `cost-by-financial-hierarchy`, `cost-forecasting-model`, `reservation-recommendation-breakdown`, `cost-by-region-trend`, `top-resource-types-by-cost`, `service-price-benchmarking`, `monthly-cost-change-percentage`, `top-commitment-transactions`, `top-other-transactions`, and `costs-enriched-base`.
- **Output format and content:** A monthly fiscal year-to-date finance report with year-to-date spend, end-of-year forecast, quarterly trends, service portfolio analysis, anomaly narrative, savings realization, commitment performance, hierarchy views, and executive actions.
- **Recommended actions generated:** Reforecast budgets, address variance drivers, approve savings actions, adjust commitments, escalate financial hierarchy gaps, and document finance risks before fiscal reviews.
- **Customization options:** Change the monthly cron from `0 9 1 * *`, align fiscal calendar assumptions, tune variance and forecast thresholds, scope the report by billing or management group hierarchy, and add finance-specific KPI sections.

### AIWorkloadCostAnalysis

- **Data sources queried:** AI cost tools including `ai-token-usage-breakdown`, `ai-model-cost-comparison`, `ai-daily-trend`, and `ai-cost-by-application`, plus cost and capacity context from Azure discovery when needed.
- **Output format and content:** A monthly AI cost report covering token economics, model mix, application allocation, daily trends, input and output ratios, month-over-month AI cost movement, optimization opportunities, and charts.
- **Recommended actions generated:** Substitute models where quality allows, optimize prompts, rightsize environments, improve application cost allocation, assess commitment coverage, and prioritize workloads with high token cost growth.
- **Customization options:** Change the monthly cron from `0 10 1 * *`, tune token-cost and growth thresholds, choose model families or applications in scope, add quality or latency guardrails for model substitution, and change chargeback allocation rules.

### BudgetCoverageAudit

- **Data sources queried:** Azure Resource Graph for subscription inventory and budget resources, subscription metadata, and budget configuration details such as amount, period, contact, and scope.
- **Output format and content:** A monthly budget coverage report with active subscriptions, configured budgets, missing or incomplete budgets, coverage gaps, and budget-control remediation items.
- **Recommended actions generated:** Create missing budgets, update budget contacts and thresholds, align budget scopes to subscription ownership, retire budgets for inactive subscriptions, and escalate subscriptions without financial guardrails.
- **Customization options:** Change the monthly cron from `0 8 15 * *`, define required budget coverage thresholds, exclude sandbox or retired subscriptions, set minimum alert percentages, and add owner or cost-center routing.

### AlertCoverageAudit

- **Data sources queried:** Azure Resource Graph for active subscriptions and anomaly alert resources, cost alert configuration, and subscription metadata for ownership and scope validation.
- **Output format and content:** A monthly alert coverage report that lists subscriptions with and without cost anomaly alerts, stale or incomplete alert configuration, missing contacts, and remediation priority.
- **Recommended actions generated:** Create missing anomaly alerts, repair alert scopes or contacts, standardize alert thresholds, remove obsolete alerts, and assign owners for unmonitored high-spend subscriptions.
- **Customization options:** Change the monthly cron from `0 8 16 * *`, tune required alert coverage and severity thresholds, exclude low-risk subscriptions, set required notification contacts, and customize anomaly alert policy standards.

### CapacityQuarterlyStrategy

- **Data sources queried:** VM quota usage, reservation and savings recommendations, `commitment-discount-utilization`, `savings-summary-report`, `reservation-recommendation-breakdown`, Azure Resource Graph, Azure CLI architecture signals, and non-compute quota context.
- **Output format and content:** A quarterly strategy report covering supply-chain maturity, commitment alignment, architecture evolution, region and quota strategy, governance health, risk register, and executive recommendations.
- **Recommended actions generated:** Mature capacity governance, align reservations and savings plans with demand, update regional architecture, address non-compute quota constraints, revise procurement processes, and set quarterly capacity objectives.
- **Customization options:** Change the quarterly cron from `0 9 1 1,4,7,10 *`, tune maturity scoring and risk thresholds, set strategic regions and SKU families, align with quarterly business review dates, and add organization-specific governance criteria.

<br>

## Notification behavior

Scheduled tasks deliver final reports through Azure SRE Agent notification connectors. When you configure the Microsoft Teams connector, each task posts only the completed summary to the connected Teams channel. The task prompts explicitly avoid posting intermediate findings so the channel stays focused on ready-to-use results.

The prompts also split what goes to Teams and what goes to the agent knowledge base:

- **Teams** receives financial, status, capacity, and strategy results. This includes charts, executive summaries, action items, savings opportunities, quota risks, and capacity recommendations.
- **Knowledge base** receives operational learnings only. Examples include tool errors, query patterns, API workarounds, pipeline failure modes, and troubleshooting steps that worked.
- **Financial detail stays out of memory.** Prompts tell the agents not to save customer financial data, cost amounts, savings numbers, token costs, or similar financial details to the knowledge base.

For connector setup, see [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md#configure-notifications).

<br>

## Roadmap

The deployed template includes the 18 scheduled tasks listed on this page. The repository also includes a broader planned task roadmap in the [scheduled task catalog](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/CATALOG.md).

The catalog is a roadmap for future automation ideas. It includes more than 74 potential daily, weekly, monthly, quarterly, and annual tasks across FinOps, capacity management, FinOps for AI, governance, optimization, benchmarking, and executive reporting. Those catalog entries are planned ideas, not deployed scheduled tasks, unless they are listed in the deployed task catalog above.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/ScheduledTasks)
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
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [Deploy Azure SRE Agent with the FinOps toolkit](deploy.md)
- [Azure SRE Agent template reference (FinOps toolkit)](template.md)

<br>
