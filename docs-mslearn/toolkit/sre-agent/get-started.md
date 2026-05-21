---
title: Get started with the FinOps toolkit on Azure SRE Agent
description: Learn what to do after deploying Azure SRE Agent with the FinOps toolkit — first queries, scheduled tasks, and specialized subagents.
author: flanakin
ms.author: micflan
ms.date: 05/06/2026
ms.topic: quickstart
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: arclares
# customer intent: As a FinOps practitioner, I want to know what to do after deploying the FinOps toolkit's Azure SRE Agent so I can start getting value from it immediately.
---

# Get started with the FinOps toolkit on Azure SRE Agent

You've deployed [Azure SRE Agent with the FinOps toolkit](overview.md). Here's how to start using it after the [deployment workflow](deploy.md) finishes.

The [deployment guide](deploy.md) covers how to deploy and configure the agent. This guide focuses on what to do next: post-deployment prompts, [scheduled tasks](scheduled-tasks.md), [specialist agents](agents.md), and customization.

<br>

## Talk to the agent

Azure SRE Agent responds to natural language questions about your Azure environment. The [tool catalog](tools.md) describes how Kusto tools query [FinOps hubs](../hubs/finops-hubs-overview.md) data, while Python tools call Azure APIs.

Ask questions the same way you'd ask another FinOps or platform engineer. The [agent and skills reference](agents.md) explains how the orchestrator routes work to specialist agents that use tools, skills, and knowledge to ground recommendations.

<br>

## Automation map

Use this map to connect each post-deployment activity to the agent, task, tool, output, and decision pattern. The [Azure SRE Agent overview](overview.md), [agents reference](agents.md), [tools reference](tools.md), and [scheduled tasks reference](scheduled-tasks.md) document the full catalog.

| Capability | Agent | Tasks | Tools | Output | You decide |
|------------|-------|-------|-------|--------|------------|
| Cost visibility and anomaly review | [`finops-practitioner`](agents.md#finops-practitioner) | [`MOM`](scheduled-tasks.md#mom), [`CostOptimization`](scheduled-tasks.md#costoptimization), and [`AlertCoverageAudit`](scheduled-tasks.md#alertcoverageaudit) | [Cost analysis](tools.md#cost-analysis-and-reporting), [anomaly detection](tools.md#anomaly-detection-and-forecasting), [forecasting](tools.md#anomaly-detection-and-forecasting), and [rate optimization](tools.md#rate-optimization) tools | Cost drivers, anomaly findings, forecasts, and prioritized actions from the scheduled task outputs | Which owners investigate, which anomalies are expected, and which optimization actions should move first |
| Capacity and quota posture | [`azure-capacity-manager`](agents.md#azure-capacity-manager) | [`CapacityDailyMonitor`](scheduled-tasks.md#capacitydailymonitor), [`ComputeUtilizationTrend`](scheduled-tasks.md#computeutilizationtrend), [`CapacityWeeklySupplyReview`](scheduled-tasks.md#capacityweeklysupplyreview), and [`NonComputeQuotaAudit`](scheduled-tasks.md#noncomputequotaaudit) | [`vm-quota-usage`](tools.md#capacity-management), [`capacity-reservation-groups`](tools.md#capacity-management), [`non-compute-quotas`](tools.md#capacity-management), and [`sku-availability`](tools.md#capacity-management) | Quota pressure, capacity reservation waste, SKU restrictions, and capacity blockers from the capacity task outputs | Which quota requests, region changes, reservation changes, or workload moves need action |
| Finance and commitment decisions | [`chief-financial-officer`](agents.md#chief-financial-officer) | [`BenefitRecommendationReview`](scheduled-tasks.md#benefitrecommendationreview), [`YTD`](scheduled-tasks.md#ytd), and [`AIWorkloadCostAnalysis`](scheduled-tasks.md#aiworkloadcostanalysis) | [Benefit, savings, commitment, forecasting, and AI cost tools](tools.md#rate-optimization) | Executive summaries, savings opportunities, forecast risk, and decision-ready commitment context from finance task outputs | Which purchases, deferrals, budget changes, or executive escalations are approved |
| Hub health and data trust | [`ftk-hubs-agent`](agents.md#ftk-hubs-agent) | [`HubsHealthCheck`](scheduled-tasks.md#hubshealthcheck) and [`MonitoringScopeValidation`](scheduled-tasks.md#monitoringscopevalidation) | [`data-freshness-check`](tools.md#data-ingestion-and-health), Azure discovery, and hub configuration tools | Hub version, connectivity, data freshness, and monitoring coverage findings from hub health task outputs | Whether reports are trustworthy, which exports need repair, and when to pause analysis that depends on stale data |

<br>

## Getting started: first things to try

Start with focused questions that validate your data, summarize spend, and find common optimization opportunities that map to the documented [tool catalog](tools.md) and [scheduled-task coverage](scheduled-tasks.md#task-details).

1. Check your data pipeline and scheduled outputs: "Is my FinOps hubs data fresh, which [scheduled tasks](scheduled-tasks.md#task-details) ran recently, and what reports or Teams notifications did they produce?"
2. Review your spending and waste: "What did we spend last month by subscription, and which idle VMs across subscriptions should we investigate first?"
3. Review anomalies: "Show me this week's cost anomalies, explain the likely drivers, and recommend who should investigate each one."
4. Find savings: "What reservation recommendations do I have?"
5. Check capacity posture: "What's my quota utilization in eastus?"

If a response doesn't have enough context, narrow the question by subscription, management group, billing scope, region, resource type, or reporting period so the agent can select focused tools and filters from the [tool catalog](tools.md).

<br>

## Scheduled tasks run automatically

The agent runs [18 scheduled tasks](scheduled-tasks.md) on daily, weekly, monthly, and quarterly cadences. The [scheduled tasks reference](scheduled-tasks.md) lists daily, weekly, monthly, and quarterly tasks for health, optimization, capacity, planning, finance, and strategy reviews.

You don't need to trigger scheduled tasks because each task has a cron expression in its task definition, and [task details](scheduled-tasks.md#task-details) describe how reports are formatted for Microsoft Teams when notifications are configured.

Customize the defaults before you rely on the automation in production. Review each scheduled task's `cron_expression` and prompt thresholds in the [task details](scheduled-tasks.md#task-details), then adjust schedules and thresholds to match your operating rhythm, time zone, reporting calendar, and risk tolerance.

For example, move the month-over-month report to run after billing data settles. Lower quota headroom thresholds for regions with known capacity pressure. Raise anomaly review thresholds for subscriptions with expected seasonal spikes. The [customization options](scheduled-tasks.md#task-details) cover each task in detail.

<br>

## Build on the basics

The agent includes [5 specialized subagents](agents.md), and you can ask the orchestrator to route the work or mention the specialist when you know which domain you need.

- [`finops-practitioner`](agents.md#finops-practitioner) — cost analysis, optimization, budgets, alerts, and FinOps practice guidance
- [`azure-capacity-manager`](agents.md#azure-capacity-manager) — quota, capacity reservations, SKU availability, and capacity governance
- [`chief-financial-officer`](agents.md#chief-financial-officer) — financial strategy, commitment decisions, budgeting, forecasting, and executive finance narratives
- [`ftk-database-query`](agents.md#ftk-database-query) — direct Kusto queries, schema validation, pricing, recommendations, and transactions against FinOps hubs
- [`ftk-hubs-agent`](agents.md#ftk-hubs-agent) — hub health, data freshness, exports, connectivity, deployment, and upgrade troubleshooting

Use specialist names when you want a specific lens. For example, ask the [`chief-financial-officer`](agents.md#chief-financial-officer) agent to frame a commitment decision for leadership, or ask the [`ftk-database-query`](agents.md#ftk-database-query) agent to explain the KQL behind a cost trend.

<br>

## Learn more

Use these pages as your next steps:

- [Tools shipped for Azure SRE Agent in the FinOps toolkit](tools.md)
- [Specialist agents and skills](agents.md)
- [Scheduled tasks (Azure SRE Agent in the FinOps toolkit)](scheduled-tasks.md)
- [FinOps toolkit best practices](../../best-practices/library.md)

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20SRE%20Agent%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20SRE%20Agent%3F/surveyId/FTK/bladeName/SREAgent/featureName/GetStarted)
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
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](/azure/data-explorer/)
- [Microsoft Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Azure SRE Agent in the FinOps toolkit](overview.md)
- [Tools shipped for Azure SRE Agent in the FinOps toolkit](tools.md)
- [Specialist agents and skills](agents.md)
- [Scheduled tasks (Azure SRE Agent in the FinOps toolkit)](scheduled-tasks.md)
- [FinOps toolkit best practices](../../best-practices/library.md)

<br>
