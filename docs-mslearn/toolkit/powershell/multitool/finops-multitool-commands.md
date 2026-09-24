---
title: FinOps multitool commands
description: Learn about PowerShell commands in the FinOpsToolkit module that scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 09/24/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps multitool commands are available in the FinOpsToolkit module.
---

# FinOps multitool commands

The FinOps multitool PowerShell commands help you scan an Azure environment for cost optimization, governance, and FinOps insights. Findings are grounded in your live resource state and cover cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

The multitool provides one scan engine with two interfaces:

- **Terminal UI (TUI)** – An interactive terminal experience launched with [Start-FinOpsMultitool](start-finopsmultitool.md). It surfaces 26 of the 30 scans.
- **Agent skills** – A set of skills that describe which investigation answers a question, the queries behind it, and how to read the results.

The terminal UI prompts for each choice by default. Consoles that can't render the arrow-key menus, such as PowerShell remoting sessions, fall back to numbered prompts. To run the tool from a pipeline or a scheduled job, use `-NonInteractive` and supply the choices as parameters.

Automation requires an existing Azure context established with the intended identity. Without one, `-NonInteractive` fails before scanning. PowerShell 7 or later is required. For the macOS Parquet limitation and alternative data sources, see [FinOps hub data paths](#finops-hub-data-paths).

CSV, HTML, and text reports are saved automatically on the machine running the multitool, in a new private folder under the current user's local application data. Use `-OutputPath` to select a different local parent folder outside Git repositories. For location details and privacy limits, see [Report storage](start-finopsmultitool.md#report-storage).

The HTML report's **KPI reference** tab lists the available KPI definitions, including entries not measured in the current run. Each entry includes its status, calculation, required inputs, interpretation, limitations, and a link to its source scan when that scan was included. **Computed** means a value was derived, not that the environment is healthy; some values are estimates or proxies. **Unavailable**, **Not run**, and **Informational** distinguish missing measurements, unselected scans, and definitions that need additional data or calculations.

**Calculation and thresholds** disclosures explain Unit Economics, Idle VMs, Storage Tier Advice, and Budget Status beside their results. Unit Economics percentages are shares of the **VM compute plus storage subtotal**, not total Azure spend or an efficiency score. The report includes the captured UTC cost period and amortized basis. Unit rates use current capacity, including stopped VMs, rather than time-weighted running-resource capacity. Compare with a workload-specific baseline instead of assuming a universal healthy percentage.

Idle and storage screening show their thresholds and evaluated counts. Missing metrics leave resources unevaluated. Budget coverage counts subscriptions with a budget, while usable forecasts are counted separately; zero at-risk budgets isn't an all-clear when forecasts are missing.

<br>

## Commands

- [Start-FinOpsMultitool](start-finopsmultitool.md) – Launch the interactive FinOps multitool terminal UI.

<br>

## Scan coverage

The multitool includes 30 scan modules across the following categories:

- **Optimization** – Orphaned resources, idle VMs, storage tier advice, Azure Hybrid Benefit opportunities, and legacy resources.
- **Governance** – Tag inventory and recommendations, and policy inventory and recommendations.
- **Cost analysis** – Cost data, resource costs, cost by tag, cost trend, unit economics, VM cost breakdown, shared cost allocation, billing account, and usage allocation.
- **Commitments** – Reservation advice, commitment utilization, and estimated savings.
- **Monitoring** – Budget status, budget history, and anomaly alerts.
- **Advisor** – Azure Advisor cost recommendations.
- **Account** – Billing structure, contract info, and Microsoft Azure Consumption Commitment (MACC) balance.
- **AI and ML** – Azure AI workload spend.
- **Sustainability** – Carbon emissions.

VM cost breakdown, shared cost allocation, usage-proportional allocation, and billing account are direct module functions, not menu entries or valid `Start-FinOpsMultitool -Scans` choices. The remaining 26 scans are available through the terminal UI.

Analysis scans are read-only. Most need Reader or Cost Management Reader access. Account scans also need agreement-specific billing access, such as Billing account reader or Billing profile reader for a Microsoft Customer Agreement, or Enterprise Administrator (read only) for an Enterprise Agreement. Commitment utilization reads reservation and savings plan usage at billing account or billing profile scope, so it needs that billing access. The carbon scan needs Reader or Carbon Optimization Reader assigned at the subscription. Carbon emissions permissions don't apply at resource group or resource scope.

Complete Resource Graph reads fail when a page is unreadable, a continuation token repeats, or the page limit is reached. A full page without a continuation token is also unverified, even if the true result happens to equal the page size. Affected inventory scans don't report partial rows as a successful complete inventory. Cost trend also rejects missing currency fields or monthly totals that would mix currencies.

On the API path, **Cost by Tag** retains successful subscription queries when another subscription fails. Reports identify incomplete coverage and failed subscriptions, and whole-scope allocation KPIs remain unavailable. Failed continuation pages don't contribute partial costs. The scan rejects mixed-currency totals and incomplete tag maps; if no subscription can be read, it reports an error.

**Unit Economics** and **AI Workload Metrics** retain capacity or usage measurements when currency evidence is missing or mixed, but leave monetary totals and rates unavailable with an explanation. AI rates use matching account costs and usage rather than total AI spend, and incomplete metric reads suppress aggregate rates. A measured zero with known currency stays zero.

Advisor and reservation savings retain each recommendation's currency and don't combine incompatible amounts. Billing account, profile, invoice-section, department, rule, and MACC reads follow all returned pages; failures remain visible as incomplete coverage. Tag inventory and anomaly scans also report incomplete reads rather than presenting them as measured zero or healthy coverage. Failed Hub discovery requires an explicit source choice rather than silently selecting another source.

For large subscription selections, budget status can sample subscriptions first. If the sample contains no budgets, it skips the remainder and reports coverage as unverified. Unreadable subscriptions aren't counted as having no budget. Policy inventory tracks assignment coverage separately from compliance coverage; incomplete compliance reads suppress the overall percentage. Storage tier advice leaves accounts with missing measurements unevaluated rather than treating absent samples as zero activity.

Budget history supports monthly cost budgets with no filter, tag or dimension `In` filters, or `and` combinations. Empty filter objects mean no filter. Filtered budgets query matching costs rather than reusing whole-subscription totals, including when the primary source is a hub. Months outside the budget's full-month validity, unsupported filters, and incompatible currencies remain unavailable. Comparisons use the current budget amount and filter, not historical budget revisions. Current forecasts separately remain unavailable when Azure doesn't return a forecast amount and compatible currency.

The scan keeps the **Savings Realized** menu name for compatibility. It estimates savings using assumed discounts. It doesn't measure realized savings or calculate a savings percentage. Results include `IsEstimate` and `EstimateBasis`. Compare the estimates with matching pay-as-you-go rates and benefit usage before reporting realized savings.

Commitment estimates cover usage charges in the reported UTC month-to-date period and retain the billing currency. Purchases, refunds, and unused commitment charges are excluded. Unknown, nonmonetary, or mixed currencies and negative usage adjustments stop the estimate. Azure Hybrid Benefit uses a separate USD estimate for 730 hours on the current VM inventory. The scan doesn't combine or annualize these amounts. For scripts, use `RISavingsMonthToDate`, `SPSavingsMonthToDate`, and `CommitmentSavingsMonthToDate` with `Currency` and `Period`. The old monthly commitment fields and combined monthly and annual totals remain empty.

<br>

## FinOps hub data paths

When a [FinOps hub](../../hubs/finops-hubs-overview.md) is present, cost scans read from the hub and choose the path automatically:

- **Kusto database (used when available)** – When the hub has an Azure Data Explorer or Microsoft Fabric cluster, the multitool discovers it through Azure Resource Graph and pushes aggregation into the engine, returning only summarized results. This scales to large datasets without loading raw cost rows into PowerShell. To query a local hub on your own hardware, set the `FINOPS_HUB_KUSTO_URI` environment variable to a local Kusto endpoint (optionally set `FINOPS_HUB_KUSTO_DB`, which defaults to `Hub`).
- **Storage reader (small-dataset fallback)**: when no Kusto endpoint is configured or discovered, the multitool reads the hub's storage export and aggregates in PowerShell. Use this for smaller datasets. Reading Parquet exports prepares a pinned reader using NuGet on Windows or .NET SDK 8 or later on Linux. NuGet signed-package verification [isn't supported on macOS](/dotnet/core/tools/nuget-signed-package-verification#macos); use Kusto or available CSV exports there. The reader doesn't bypass signature verification. If it can't be prepared, the tool warns with the reason and attempts `msexports` CSV instead. A failed export read remains an error, not zero cost.

Storage reads require Storage Blob Data Reader or equivalent data access. Kusto queries require database query access. Both paths need network access to the endpoint. Local Kusto queries are anonymous, but the public launcher still uses Azure context and resource metadata.

An explicit `-DataSource API` or `-DataSource GraphOnly` takes precedence over `FINOPS_HUB_KUSTO_URI` and doesn't preload hub data. A configured Kusto URI can select a hub without a discovered storage account. An explicit `-DataSource Hub` reports an error if no configured endpoint or hub storage is available.

GraphOnly excludes cost-dependent scans and orphan cost enrichment. Remaining scans can still use Azure Monitor, Advisor, policy, and carbon APIs. Dependencies can't re-enable an excluded cost scan.

When no hub is available, the tool offers the Cost Management API. Once you select **FinOps Hub**, the tool reports any read or query failure as an error. Select **Cost Management API** to run a separate live scan. Kusto-only hubs don't currently support the AI workload scan. When forecasts are available for current-month storage data, the tool shows them as separate full-month API totals. It doesn't add forecasts to hub actuals.

<br>

## Agent skills

A companion set of agent skills carries the same analysis as guidance an AI agent can act on: which investigation answers the question, the Resource Graph and Cost Management queries behind it, and the places raw results mislead. Agents run the queries through Azure CLI or an Azure MCP server, so no additional server is required.

The `finops-multitool` skill is the routing hub and hands off to FinOps-adjacent skills for reporting, allocation, governance, unit economics, and more. The skills are read-only, and so is the terminal UI. Both report what they find and recommend a change; applying it stays with you.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Multitool)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit PowerShell module](../powershell-commands.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
