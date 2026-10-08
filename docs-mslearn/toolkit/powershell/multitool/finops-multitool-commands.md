---
title: FinOps multitool commands
description: Learn about PowerShell commands in the FinOpsToolkit module that scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 10/07/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps multitool commands are available in the FinOpsToolkit module.
---

# FinOps multitool commands

The FinOps multitool PowerShell commands help you scan an Azure environment for cost optimization, governance, and FinOps insights. Findings are grounded in your live resource state and cover cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

The multitool supports two ways to investigate FinOps data:

- **Terminal UI (TUI)** – An interactive terminal experience launched with [Start-FinOpsMultitool](start-finopsmultitool.md). It surfaces 26 of the 30 scans.
- **Agent skills** – A set of skills that describe which investigation answers a question, the queries behind it, and how to read the results.

The terminal UI prompts for each choice by default. Consoles that can't render the arrow-key menus, such as PowerShell remoting sessions, fall back to numbered prompts. Use `-Accessible` to select numbered prompts without clearing the screen or repainting menu rows in any console. This mode stays in the signed-in tenant. To run the tool from a pipeline or a scheduled job, use `-NonInteractive` and supply the choices as parameters; it takes precedence over `-Accessible`.

Automation requires an existing Azure context established with the intended identity. Without one, `-NonInteractive` fails before scanning. PowerShell 7 or later is required. For the macOS Parquet limitation and alternative data sources, see [FinOps hub data paths](#finops-hub-data-paths).

An explicit `-SubscriptionId` must resolve in the current tenant. Unresolved or mismatched subscriptions stop the run without searching other tenants or widening scope. Sign in to the intended tenant before trying again. A valid subscription selection changes context only in the current PowerShell process. The tool verifies tenant ownership before source discovery and stops subscription enumeration if the tenant is missing or changed.

CSV, HTML, and text reports are saved automatically on the machine running the multitool, in a new private folder under the current user's local application data. Use `-OutputPath` to select a different local parent folder outside Git repositories. For location details and privacy limits, see [Report storage](start-finopsmultitool.md#report-storage).

The HTML report's **KPI reference** tab lists the available KPI definitions, including entries not measured in the current run. Each entry includes its status, calculation, required inputs, interpretation, limitations, and a link to its source scan when that scan was included. **Computed** means a value was derived, not that the environment is healthy; some values are estimates or proxies. **Unavailable**, **Not run**, and **Informational** distinguish missing measurements, unselected scans, and definitions that need additional data or calculations.

Existing result tables provide sticky headers, row numbers, local search, sorting, resizable columns, and 25-row pages. **Expand** opens the same table in a larger view; **Close** or Escape restores its position and state. Search includes collapsed details. Wide tables scroll within the report, and printing retains all matching rows. Each scan's summaries, notes, and guidance share one panel below its heading, which scrolls when the content is long; printing includes the complete notes. The controls work locally without external scripts, uploads, or changes to CSV data.

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

**Cost Trend** provides selected-scope aggregate and per-subscription HTML views with names, IDs, and row currencies. API queries record one UTC window covering six full months and the current partial month; the report labels that partial month from the captured query end. When the management-group response omits selected subscriptions, such as subscriptions outside that group, the scan queries those subscriptions individually. Coverage distinguishes returned rows, successful empty subscription queries, and subscriptions whose individual queries failed. Missing subscriptions and months aren't treated as zero cost, and an unverified aggregate isn't a whole-tenant total. Requests and grouped results stay filtered to the selected IDs. Both trend datasets and the captured metadata remain in CSV. Older results without metadata show unverified coverage and an unrecorded query window.

Resource-cost API results include the requested UTC month-to-date window in HTML and CSV. The period comes from the [Cost Management query request](/rest/api/cost-management/query/usage), not a billing-completeness timestamp. Friendly resource names, nested resource types, and reservation-charge labels retain their original resource IDs. Charges without subscription attribution remain separate instead of being assigned to an arbitrary subscription.

Management-group cost-scope discovery probes at most 25 distinct candidates: up to 24 non-root groups, followed by the tenant root. List pagination and the existing per-candidate retry budget are preserved; this isn't a limit on total HTTP requests. When the candidate list is capped, a warning explains that other groups remain unprobed. If no candidate succeeds, cost scans query the selected subscriptions individually. Cached scopes and discovery failures aren't reused for a different tenant.

On the API path, **Cost by Tag** retains successful subscription queries when another subscription fails. Reports identify incomplete coverage and failed subscriptions, and whole-scope allocation KPIs remain unavailable. Failed continuation pages don't contribute partial costs. The scan rejects mixed-currency totals and incomplete tag maps; if no subscription can be read, it reports an error.

**Unit Economics** and **AI Workload Metrics** retain capacity or usage measurements when currency evidence is missing or mixed, but leave monetary totals and rates unavailable with an explanation. AI rates use matching account costs and usage rather than total AI spend, and incomplete metric reads suppress aggregate rates. A measured zero with known currency stays zero.

Live AI metrics and amortized account cost share a captured UTC window. Token totals use the same measured basis per account and deployment, with prompt-plus-generated fallback only when both measurements exist. The report separates account costs from token usage, retains resource and subscription identity, and doesn't combine same-named deployments across accounts. Missing measurements stay unavailable. These effective account rates aren't per-model prices or a billing reconciliation. Cost covers Cognitive Services accounts, not the separate ML, Search, or GPU inventory.

Commitment utilization retains every returned reservation and savings plan with its latest returned period and identity. Missing reservation SKU or kind can be enriched from matching reservation details; denied metadata doesn't discard known utilization. Absent commitment types and unknown percentages have unavailable averages instead of 0%. A measured zero stays zero. Averages are unweighted and suppressed when coverage or scope is unverified; utilization isn't a measurement of realized savings.

Advisor and reservation savings retain each recommendation's currency and don't combine incompatible amounts. Billing account, profile, invoice-section, department, rule, and MACC reads follow all returned pages; failures remain visible as incomplete coverage. Tag inventory and anomaly scans also report incomplete reads rather than presenting them as measured zero or healthy coverage.

For large subscription selections, budget status can sample subscriptions first. If the sample contains no budgets, it skips the remainder and reports coverage as unverified. Unreadable subscriptions aren't counted as having no budget. Policy inventory tracks assignment coverage separately from compliance coverage; incomplete compliance reads suppress the overall percentage. Storage tier advice leaves accounts with missing measurements unevaluated rather than treating absent samples as zero activity.

Policy inventory also tracks definition-read coverage separately. Failed or malformed definition reads produce visible warnings and a **Limited data** result. `DefinitionCoverageIncomplete` and `DefinitionErrors` preserve the failure details in the scan result and CSV export without discarding assignments or valid compliance percentages. An unresolved effect in a successfully read definition isn't treated as a read failure.

Policy locations show available subscription and management-group names, with the original scope IDs retained in HTML details and CSV. Only management groups referenced by assignments are looked up, and a name is accepted only when the returned group ID and tenant match. Missing access or an invalid response leaves the ID visible and records a `ScopeNameErrors` entry without changing assignment or compliance results.

Budget history supports monthly cost budgets with no filter, tag or dimension `In` filters, or `and` combinations. Empty filter objects mean no filter. Filtered budgets query matching costs rather than reusing whole-subscription totals, including when the primary source is a hub. Months outside the budget's full-month validity, unsupported filters, and incompatible currencies remain unavailable. Comparisons use the current budget amount and filter, not historical budget revisions. Current forecasts separately remain unavailable when Azure doesn't return a forecast amount and compatible currency.

The scan keeps the **Savings Realized** menu name for compatibility. It estimates savings using assumed discounts. It doesn't measure realized savings or calculate a savings percentage. Results include `IsEstimate` and `EstimateBasis`. Compare the estimates with matching pay-as-you-go rates and benefit usage before reporting realized savings.

Commitment estimates cover usage charges in the reported UTC month-to-date period and retain the billing currency. Purchases, refunds, and unused commitment charges are excluded. Unknown, nonmonetary, or mixed currencies and negative usage adjustments stop the estimate. Azure Hybrid Benefit uses a separate USD estimate for 730 hours on the current VM inventory. The scan doesn't combine or annualize these amounts. For scripts, use `RISavingsMonthToDate`, `SPSavingsMonthToDate`, and `CommitmentSavingsMonthToDate` with `Currency` and `Period`. The old monthly commitment fields and combined monthly and annual totals remain empty.

<br>

## FinOps hub data paths

When a [FinOps hub](../../hubs/finops-hubs-overview.md) is present, cost scans read from the hub and choose the path automatically:

- **Kusto database (used when available)** – When the hub has an Azure Data Explorer or Microsoft Fabric cluster, the multitool discovers it through Azure Resource Graph and pushes aggregation into the engine, returning only summarized results. This scales to large datasets without loading raw cost rows into PowerShell. To query a local hub on your own hardware, set the `FINOPS_HUB_KUSTO_URI` environment variable to a local Kusto endpoint (optionally set `FINOPS_HUB_KUSTO_DB`, which defaults to `Hub`).
- **Storage reader (small-dataset fallback)**: when no Kusto endpoint is configured or discovered, the multitool reads the hub's storage export and aggregates in PowerShell. Use this for smaller datasets. Reading Parquet exports prepares a pinned reader using NuGet on Windows or .NET SDK 8 or later on Linux. NuGet signed-package verification [isn't supported on macOS](/dotnet/core/tools/nuget-signed-package-verification#macos); use Kusto or available CSV exports there. The reader doesn't bypass signature verification. If it can't be prepared, the tool warns with the reason and attempts `msexports` CSV instead. The CSV fallback checks at most 2,000 export manifests; above that, use Kusto or the Cost Management API. It doesn't download a manifest larger than 1 MB, and it stops instead of counting a CSV file that two export runs list. A failed export read remains an error, not zero cost.

Storage reads require Storage Blob Data Reader or equivalent data access. Kusto queries require database query access. Both paths need network access to the endpoint. Local Kusto queries are anonymous, but the public launcher still uses Azure context and resource metadata.

An explicit `-DataSource API` or `-DataSource GraphOnly` takes precedence over `FINOPS_HUB_KUSTO_URI` and doesn't preload hub data. A configured Kusto URI can select a hub without a discovered storage account. An explicit `-DataSource Hub` reports an error if no configured endpoint or hub storage is available.

Ordinary Cost Management exports are a separate source: select **Cost Management exports (CSV storage)** or use `-DataSource Export`. No hub is required. Discovery first reads export definitions for the selected subscriptions, their management-group ancestors, and linked billing accounts, reporting progress per scope. It then scans storage accounts in those subscriptions and merges anything Cost Management can't see, reporting progress per storage account. With more than 100 storage accounts, interactive runs ask before scanning them, because Azure allows 100 container listings per 5 minutes in each subscription and region; a skipped scan is reported. Container names are discovered automatically, so you don't enter them; that scan looks at containers whose names contain `export`, `msexports`, `ingestion`, `finops`, `cost`, or `focus`, plus any container a visible definition names. Unavailable locations produce summarized warnings, with details under `-Verbose`. The reader requires ActualCost or FOCUS BilledCost and storage data and network access; it doesn't create exports, read local files, or parse Parquet. Unattended runs require exactly one readable candidate. If you choose exports from the interactive menu and no export can be verified, you're asked whether to use the Cost Management API instead; `-DataSource Export` stops without switching sources. When the chosen run has a manifest, every declared partition must be readable or the run is reported as incomplete. Supported views are cost totals, resource costs, cost by tag, and the months present in that export run. Separate financial API scans are excluded, while inventory scans can still query Azure. Reads remain inside the chosen folder, filter row subscriptions, and retain partial coverage as unverified instead of filling gaps with live costs. Rows with no subscription, such as purchases or refunds billed outside a subscription, aren't included in subscription totals; the export coverage note reports their count and amount in each currency. Use Kusto for very large datasets because this CSV reader loads parts into memory.

Automatic hub discovery queries only the selected subscriptions in the verified Azure context. When a hub can't be verified, discovery failures remain visible, interactive runs still offer API or GraphOnly, and `-NonInteractive` defaults to API without changing scope, even if every probe fails. An explicit `-DataSource Hub` request that can't be satisfied still stops instead of switching sources.

Provider-discovery exceptions for a detected hub warn and fall back to that hub's storage-reader checks. Existing size and reachability warnings still apply. The scan runner keeps the selected storage path without repeating provider discovery. Explicit Kusto endpoint failures and failed Kusto cost queries don't silently switch sources.

The internal Kusto provider lookup also warns for failed or unreadable Resource Graph responses. Kusto query results must contain valid table and row shapes with nonblank, noncolliding column names. A partial failure reported by `QueryStatus` rejects the response rather than returning partial cost rows. Valid empty results, zero amounts, and credits are preserved.

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
