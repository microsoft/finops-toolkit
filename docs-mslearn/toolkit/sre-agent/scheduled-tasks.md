---
title: FinOps SRE Agent scheduled tasks
description: Learn how FinOps SRE Agent scheduled tasks automate daily, weekly, monthly, and quarterly FinOps operating rhythms.
author: msbrett
ms.author: brettwil
ms.date: 04/29/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand the deployed FinOps SRE Agent scheduled tasks so that I can plan recurring cost, capacity, and finance reviews.
---

# FinOps SRE Agent scheduled tasks

FinOps SRE Agent scheduled tasks run recurring Azure SRE Agent workflows for the FinOps operating rhythm. They turn common reviews into autonomous checks that gather data, route work to the right specialist agent, generate charts where the data supports them, and post completed reports to Microsoft Teams when a Teams notification connector is configured.

The template deploys 18 scheduled tasks from `src/templates/sre-agent/sre-config/scheduled-tasks/`. These tasks cover daily health checks, weekly optimization and capacity reviews, monthly planning and finance reports, and quarterly strategy.

<br>

## Daily tasks

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `HubsHealthCheck` | `ftk-hubs-agent` | Daily at 6:00 AM<br>`0 6 * * *` | FinOps hub version and data freshness validation |
| `CapacityDailyMonitor` | `azure-capacity-manager` | Daily at 6:30 AM<br>`30 6 * * *` | Daily capacity supply chain health check — quota usage, CRG utilization, zone capacity |
| `MOM` | `finops-practitioner` | Daily at 5:15 PM<br>`15 17 * * *` | Autonomous month-over-month cost analysis with all 17 Kusto tools |

<br>

## Weekly tasks

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

| Task | Agent | Schedule | Description |
|------|-------|----------|-------------|
| `CapacityQuarterlyStrategy` | `azure-capacity-manager` | Quarterly on January 1, April 1, July 1, and October 1 at 9:00 AM<br>`0 9 1 1,4,7,10 *` | Quarterly capacity strategy review — supply chain maturity, commitment alignment, architecture evolution |

<br>

## Notification behavior

Scheduled tasks deliver final reports through Azure SRE Agent notification connectors. When you configure the Microsoft Teams connector, each task posts only the completed summary to the connected Teams channel. The task prompts explicitly avoid posting intermediate findings so the channel stays focused on ready-to-use results.

The prompts also split what goes to Teams and what goes to the agent knowledge base:

- **Teams** receives financial, status, capacity, and strategy results. This includes charts, executive summaries, action items, savings opportunities, quota risks, and capacity recommendations.
- **Knowledge base** receives operational learnings only. Examples include tool errors, query patterns, API workarounds, pipeline failure modes, and troubleshooting steps that worked.
- **Financial detail stays out of memory.** Prompts tell the agents not to save customer financial data, cost amounts, savings numbers, token costs, or similar financial details to the knowledge base.

For connector setup, see [Deploy and configure the FinOps SRE Agent](deploy.md#configure-notifications).

<br>

## Roadmap

The deployed template includes the 18 scheduled tasks listed on this page. The repository also includes a broader planned task roadmap in the [FinOps SRE Agent scheduled task catalog](https://github.com/microsoft/finops-toolkit/blob/main/src/templates/sre-agent/CATALOG.md).

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

- [FinOps SRE Agent](overview.md)
- [Deploy and configure the FinOps SRE Agent](deploy.md)
- [FinOps SRE Agent template reference](template.md)

<br>
