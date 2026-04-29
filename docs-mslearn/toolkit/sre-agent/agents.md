---
title: FinOps SRE Agent agents and skills
description: Understand how FinOps SRE Agent uses specialist agents, tools, skills, and knowledge to automate FinOps and capacity management work.
author: msbrett
ms.author: brettwil
ms.date: 04/29/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps practitioner, I want to understand how FinOps SRE Agent agents and skills work so that I can route work to the right specialist.
---

# FinOps SRE Agent agents and skills

FinOps SRE Agent uses a multi-agent architecture built on [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview). One orchestrator receives prompts and scheduled tasks, then delegates work to specialist subagents with focused FinOps, finance, capacity, database, and hub operations expertise.

The template configures 5 subagents, 3 skills, 33 tools (21 Kusto tools and 12 Python tools), and a FinOps hub connector. The orchestrator keeps the experience simple. The specialist agents keep answers grounded in the right domain.

<br>

## finops-practitioner

Domain: FinOps practice guidance, cost allocation, optimization, anomaly response, AI cost management, governance, and operating-model design.

The `finops-practitioner` agent helps teams apply FinOps principles to real Azure cost and usage questions. It assesses business context, maturity, stakeholders, and trade-offs before recommending actions.

What it does:

- Guides cost allocation, shared-cost strategy, showback, and chargeback.
- Investigates cost anomalies and cost drivers.
- Plans workload optimization, rate optimization, governance, and practice health improvements.
- Translates FinOps concepts into practical Azure Cost Management and FinOps Toolkit steps.
- Keeps recommendations maturity-aware across Crawl, Walk, and Run stages.

Key tools it uses:

- Azure discovery tools, such as `CheckAzureResource` and `RunAzCliReadCommands`
- Python analysis through `execute_python`
- FinOps hub Kusto tools, such as `costs-enriched-base`, `cost-anomaly-detection`, `cost-by-financial-hierarchy`, `monthly-cost-trend`, `reservation-recommendation-breakdown`, and `savings-summary-report`
- AI cost tools, such as `ai-token-usage-breakdown`, `ai-model-cost-comparison`, and `ai-cost-by-application`

When it's invoked:

- A user asks for FinOps practice guidance, anomaly triage, allocation, governance, reporting, optimization, or maturity planning.
- A scheduled task needs recurring cost visibility, optimization review, AI cost analysis, or FinOps practice health checks.
- The orchestrator needs a general FinOps owner before handing deeper Kusto or finance work to another specialist.

<br>

## azure-capacity-manager

Domain: Azure quota, capacity reservations, quota groups, region access, zone mapping, AKS capacity, and capacity-to-rate alignment.

The `azure-capacity-manager` agent manages the Azure capacity supply chain: forecast, procure, allocate, and monitor. It separates capacity guarantees from pricing commitments so teams can make better quota, reservation, and savings decisions.

What it does:

- Reviews quota usage, quota increases, quota groups, transfers, and headroom.
- Plans capacity reservation groups, sharing, overallocation, and utilization checks.
- Evaluates region access, zonal enablement, and logical-to-physical zone alignment.
- Checks AKS node pool capacity readiness and non-compute quota constraints.
- Aligns capacity planning with reservation and savings plan recommendations.

Key tools it uses:

- Azure CLI tools, such as `RunAzCliReadCommands`, `RunAzCliWriteCommands`, and `GetAzCliHelp`
- Python analysis through `execute_python`
- FinOps hub tools, such as `commitment-discount-utilization`, `cost-forecasting-model`, `costs-enriched-base`, `reservation-recommendation-breakdown`, and `savings-summary-report`
- Cost anomaly context through `cost-anomaly-detection`

When it's invoked:

- A user asks about quota, capacity reservations, region access, availability zones, AKS capacity, or capacity governance.
- A scheduled capacity task checks daily quota usage, weekly supply readiness, monthly planning, or quarterly strategy.
- Another agent needs capacity context before recommending commitments, scaling changes, or regional moves.

<br>

## chief-financial-officer

Domain: Executive finance, budgeting, forecasting, risk, capital allocation, cloud economics, and board-ready FinOps narratives.

The `chief-financial-officer` agent turns cost and usage evidence into financial guidance. It focuses on business outcomes, executive summaries, quantified assumptions, and decision-ready recommendations.

What it does:

- Prepares budgeting, rolling forecasts, variance analysis, and KPI-driven performance views.
- Evaluates investment priorities, capital allocation, risk, controls, and compliance exposure.
- Assesses cloud spend through unit economics, commitment decisions, and value creation.
- Produces recommendations for boards, CEOs, finance leaders, and FinOps stakeholders.
- Calls out missing data, uncertainty, risks, and follow-up steps.

Key tools it uses:

- Azure discovery through `RunAzCliReadCommands`
- Python analysis through `execute_python`
- Finance and trend tools, such as `cost-forecasting-model`, `monthly-cost-trend`, `monthly-cost-change-percentage`, `cost-by-financial-hierarchy`, and `quarterly-cost-by-resource-group`
- Savings and pricing tools, such as `savings-summary-report`, `service-price-benchmarking`, `commitment-discount-utilization`, and `top-commitment-transactions`
- AI unit economics tools, such as `ai-token-usage-breakdown`, `ai-model-cost-comparison`, and `ai-cost-by-application`

When it's invoked:

- A user asks for executive summaries, budget variance, forecast drift, board narratives, or portfolio trade-offs.
- A scheduled finance task prepares daily budget checks, weekly variance reviews, monthly forecasts, quarterly business reviews, or annual planning.
- The `finops-practitioner` agent needs finance leadership for executive framing or prioritization.

<br>

## ftk-database-query

Domain: FinOps hub database analysis, FOCUS-aligned KQL, schema validation, query diagnostics, pricing, recommendations, and transactions.

The `ftk-database-query` agent is the KQL specialist. It queries the Hub database, explains schema choices, and adapts catalog queries before writing custom KQL.

What it does:

- Uses the Hub database for analytics and avoids the Ingestion database for end-user analysis.
- Starts with the query catalog and adapts the closest existing query when possible.
- Builds custom analysis from `costs-enriched-base` when no catalog query fits.
- Uses `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()` for FOCUS-aligned analysis.
- Explains filters, functions, metrics, missing data, and data freshness concerns.

Key tools it uses:

- Memory and Azure discovery through `SearchMemory`, `RunAzCliReadCommands`, and `GetAzCliHelp`
- Python analysis through `execute_python`
- The full FinOps hub Kusto catalog, including `costs-enriched-base`, `monthly-cost-trend`, `top-services-by-cost`, `cost-by-region-trend`, `cost-anomaly-detection`, `cost-forecasting-model`, `commitment-discount-utilization`, `savings-summary-report`, `top-other-transactions`, and AI cost tools

When it's invoked:

- A user asks for a KQL query, schema explanation, pricing lookup, recommendation analysis, transaction analysis, or cost drill-down.
- A scheduled task needs exact FinOps hub data, a focused diagnostic, or FOCUS-aligned query execution.
- Another agent needs live cost data or schema-aware analysis before making a recommendation.

<br>

## ftk-hubs-agent

Domain: FinOps hubs deployment, upgrades, configuration, exports, dashboards, connectivity, and health.

The `ftk-hubs-agent` agent keeps FinOps hubs running. It uses validation-first workflows for deployment, upgrade, maintenance, and troubleshooting.

What it does:

- Deploys and upgrades FinOps hubs.
- Maintains hub configuration, exports, dashboards, and connectivity.
- Troubleshoots deployment failures and unhealthy hub environments.
- Checks prerequisites, required resource providers, RBAC, regions, quotas, naming conflicts, and existing resources.
- Runs template validation and what-if checks before deploy or upgrade changes.

Key tools it uses:

- Knowledge search through `SearchMemory`
- Azure CLI tools, such as `RunAzCliReadCommands`, `RunAzCliWriteCommands`, and `GetAzCliHelp`

When it's invoked:

- A user asks to deploy, upgrade, configure, maintain, or troubleshoot FinOps hubs.
- A scheduled health task checks FinOps hub readiness, export freshness, version status, or connectivity.
- Another agent needs hub health context before trusting query results or scheduled reports.

<br>

## Handoff model

The orchestrator starts with the user's prompt or scheduled task instructions. It selects the agent whose `handoffDescription` best matches the task, then passes the conversation to that specialist.

Agents can also recommend handoffs when the work crosses domain boundaries:

- `finops-practitioner` hands executive finance narratives, portfolio prioritization, and board-level recommendations to `chief-financial-officer`.
- `finops-practitioner` hands deep FinOps hub database and KQL work to `ftk-database-query`.
- `finops-practitioner` hands hub deployment, upgrade, and troubleshooting work to `ftk-hubs-agent`.
- Capacity work routes to `azure-capacity-manager` when the task involves quota, capacity reservations, region access, zones, AKS capacity, or capacity governance.

Handoffs keep each response focused. The FinOps specialist can frame the business problem, the KQL specialist can gather evidence, the capacity specialist can validate supply constraints, and the finance specialist can turn the findings into an executive decision.

<br>

## Skills

Skills give agents a domain reference map. The template applies all three skills to Azure SRE Agent. When a prompt or scheduled task enters one of these domains, the matching skill can load before the agent responds.

### azure-capacity-management

Provides Azure capacity management guidance for SaaS ISVs running workloads in their own Azure subscriptions under Enterprise Agreement or Microsoft Customer Agreement billing. It covers quota operations, quota groups, capacity reservation groups, region access, zonal enablement, AKS capacity governance, non-compute quotas, capacity alerts, and capacity supply-chain planning.

The `azure-capacity-manager` agent is instructed to load this skill before capacity work. Capacity scheduled tasks also tell the agent to load it before checking quota, capacity reservation, SKU, or supply-readiness signals.

### azure-cost-management

Provides Azure cost optimization and financial governance guidance. It covers Advisor recommendations, commitment discounts, budgets, exports, anomaly alerts, credits, Microsoft Azure Consumption Commitment tracking, orphaned resources, VM rightsizing, and Azure retail price lookup.

FinOps and reporting scheduled tasks load this skill with the `finops-toolkit` skill when they need Azure Cost Management context beyond FinOps hub Kusto data.

### finops-toolkit

Provides FinOps Toolkit and FinOps hubs guidance. It maps tasks to the right references, explains Hub database functions, lists the Kusto query catalog, and covers hub deployment, upgrade, health checks, FOCUS mapping, Power BI, alerts, workbooks, and Toolkit PowerShell commands.

FinOps hub query, reporting, and AI cost tasks load this skill so agents can use the Hub database, `Costs()`, `Prices()`, `Recommendations()`, `Transactions()`, and the predefined Kusto query catalog correctly.

<br>

## How agents, tools, skills, and knowledge work together

FinOps SRE Agent combines four layers:

1. **Agents** route the work to the right specialist.
2. **Skills** load domain guidance and reference maps.
3. **Tools** gather evidence from Azure, FinOps hubs, Python analysis, and Kusto queries.
4. **Knowledge** supplies onboarding guidance, notification patterns, and known issue context.

Together, these layers help the agent move from a question to an evidence-backed recommendation. The orchestrator delegates, the specialist loads the right skill, tools collect the data, and knowledge keeps the answer aligned with the deployed environment.

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

- [Anomaly management](../../framework/understand/anomalies.md)
- [Cost allocation](../../framework/understand/allocation.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [FinOps SRE Agent](overview.md)
- [Deploy FinOps SRE Agent](deploy.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps SRE Agent template reference](template.md)

<br>
