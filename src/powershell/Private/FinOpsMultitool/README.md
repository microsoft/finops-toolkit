<!-- markdownlint-disable -->

# FinOps multitool terminal UI (TUI)

Terminal interface for running FinOps scans against Azure subscriptions without GUI dependencies. PowerShell 7 is required.

The [PR test workflow](../../../../.github/workflows/dev.yml) defines Windows, macOS, and Ubuntu jobs for the multitool suites and packaged launcher. Its signed Parquet integration jobs target Windows and Ubuntu. The jobs require no Azure sign-in or deployment credentials. Use each platform's result for the tested commit; Windows results don't establish native compatibility.

NuGet signed-package verification [isn't supported on macOS](https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification#macos). Parquet setup stops with that reason before invoking a package client or downloading packages. Use a configured Kusto endpoint or available CSV exports there. The reader doesn't bypass signature verification to load Parquet.

## Quick start

```powershell
# From the FinOpsMultitool directory
. .\Invoke-FinOpsMultitool.ps1
Invoke-FinOpsMultitool
```

Or target a specific subscription:

```powershell
Invoke-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'
```

## Requirements

| Requirement                                  | Details                                                                              |
| -------------------------------------------- | ------------------------------------------------------------------------------------ |
| PowerShell                                   | 7.0 or later (Windows, macOS, Linux)                                                 |
| Az modules                                   | `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`                                      |
| Azure role-based access control (Azure RBAC) | Reader and Cost Management Reader on the target scope                                |
| FinOps hub storage (optional)                | Storage Blob Data Reader on the hub storage account                                  |
| FinOps hub Kusto (optional)                  | Query access to the hub database. A local ftklocal instance uses its local endpoint. |

Install Az modules if needed:

```powershell
Install-Module Az.Accounts, Az.ResourceGraph, Az.Storage -Scope CurrentUser
```

## How it works

### 1. Authentication

On an interactive launch, the TUI checks for an existing `Az.Accounts` session and starts `Connect-AzAccount` when needed. `-NonInteractive` requires an existing Azure context; authenticate with the intended identity first. If you supply `-SubscriptionId`, the subscription must resolve in the current tenant. A failed or mismatched lookup stops without searching other tenants or widening the scan. A valid lookup selects that subscription for the current process only. Otherwise, the tool offers a tenant menu when supported and discovers subscriptions in the selected tenant. A missing or changed tenant stops subscription enumeration, and every selected subscription must belong to that tenant before source discovery.

### 2. Data source selection

During interactive source selection, you can choose Cost Management API, Resource Graph only, or **Cost Management exports (CSV storage)**. FinOps Hub is also offered when a hub is detected. Exports don't require a Hub. If you choose exports and none can be verified, you're asked whether to use the Cost Management API instead; `-DataSource Export` stops without switching sources.

Automatic Hub discovery queries only the selected subscriptions in the verified Azure context. If a Hub can't be verified, discovery failures remain visible, interactive runs still offer API or GraphOnly, and `-NonInteractive` defaults to API without changing scope. This applies even when every discovery probe fails. An explicit Hub request still stops if no configured endpoint or detected storage account is available. Explicit API and GraphOnly selections skip Hub discovery.

If provider discovery throws for a detected Hub, the tool warns and checks that Hub's storage reader. Storage sizing and reachability warnings still apply. The selected storage path is carried into the scan runner without repeating provider discovery. A configured Kusto endpoint or a failed Kusto cost query doesn't silently switch to storage or API.

The internal Kusto lookup warns when Resource Graph fails or returns an unreadable response; a verified empty lookup remains distinct. Kusto transport rejects malformed tables, invalid row widths, colliding column names, and partial query failures before returning data. Valid empty results, measured zero, and credits remain valid.

| Source                      | Description                                                                                                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **FinOps Hub**              | Reads available cost data from the hub. Kusto summarizes data in the engine; the storage reader is for small datasets.                                                            |
| **Cost Management exports** | Discovers existing CSV/CSV.gz exports and reads one selected destination. Uses ActualCost or FOCUS BilledCost, filters row subscriptions, and leaves missing coverage unverified. |
| **Cost Management API**     | Queries currently available cost data through the Cost Management REST API. Doesn't preload hub data.                                                                             |
| **Resource Graph only**     | Excludes cost-dependent scans and orphan cost enrichment. Remaining scans can still use Azure Monitor metrics, Advisor, policy, and carbon APIs.                                  |

When the **FinOps Hub** source is chosen, the tool prefers the hub's **Kusto database** (Azure Data Explorer / Fabric, or a local ftklocal emulator) and pushes aggregation into the engine, returning only summarized results. This is the scalable path for large customer datasets — it never loads the raw cost rows into PowerShell. See [FinOps Hub data paths](#finops-hub-data-paths) below. The storage-export reader remains as a small-dataset fallback.

Use `-DataSource Export` to request ordinary export discovery explicitly. The picker first reads export definitions for the selected subscriptions, their management-group ancestors, and billing accounts linked to those subscriptions, reporting progress per scope and the number found. Storage-first discovery then runs even when definitions are found, deduped against them, because a cross-tenant scan can see some subscriptions' exports while a central management-group export stays invisible to Cost Management. With more than 100 storage accounts, interactive runs ask before scanning them, because Azure allows 100 container listings per 5 minutes in each subscription and region; a skipped scan is reported. It uses Azure Resource Manager container metadata before blob-service enumeration, probes containers whose names contain `export`, `msexports`, `ingestion`, `finops`, `cost`, or `focus` plus any container a visible definition names, and reports progress per storage account. You choose an export; you don't need to know its container name. A definition found at a management-group or billing-account scope can deliver to storage outside the selected subscriptions, and that destination is read. Readable candidates remain available when other probes fail, and candidates this path cannot read are listed as such. Discovery warnings are summarized, with details under `-Verbose`. Storage Blob Data Reader or equivalent data access and storage network access are still required to read the chosen data. This path does not create or run exports, ingest local files, or parse Parquet. Reads stay inside the chosen export folder; when the selected run has a manifest, every declared partition must be readable or the run is reported as incomplete. It loads CSV parts into memory, so use a compatible Kusto database for very large datasets.

Choose one export when prompted; exports aren't combined automatically. Unattended Export mode requires exactly one candidate. Cost totals, resource costs, cost by tag, and trends use only matching export rows. Trend history is limited to the chosen run's dates. Separate live financial scans are excluded; inventory and metrics scans can still query Azure in the selected scope. Failed or unsupported export reads never switch to API costs. Missing subscriptions are unverified, not zero, and neither blob timestamps nor observed row dates prove billing completeness. Rows with no subscription, such as purchases or refunds billed outside a subscription, aren't included in subscription totals; the export coverage note reports their count and amount in each currency.

### 3. Scan selection

Use arrow-key menus to select scans when your host supports them. Other hosts use numbered prompts. Use `-Accessible` to select numbered prompts in any console without clearing the screen or repainting menu rows. This mode stays in the signed-in tenant; sign in separately to use another tenant. For automation, use `-NonInteractive` with `-Scans`, `-DataSource`, and `-SubscriptionId`. `-NonInteractive` disables prompts even when `-Accessible` is also set. Reports are saved automatically; `-OutputPath` changes their parent folder. All menu scans are selected by default except **Billing Structure**.

In accessible mode, three invalid or blank source-menu answers cancel the run instead of choosing a source. A Hub-to-API confirmation requires an explicit yes or no; invalid or blank answers cancel without starting a scan.

Use `-Scans All` on its own to select every menu scan. GraphOnly removes cost-dependent scans from that selection, including budget history, unit economics, AI workload metrics, and MACC. Dependencies can't re-enable excluded scans.

An explicit null or empty `-Scans` list is rejected before the tool starts. Omit the parameter to use the normal menu or unattended defaults.

| Key       | Action             |
| --------- | ------------------ |
| `↑` / `↓` | Navigate scan list |
| `Space`   | Toggle scan on/off |
| `A`       | Select all         |
| `N`       | Deselect all       |
| `Enter`   | Run selected scans |
| `Q`       | Quit               |

### 4. Scan execution

Selected scans run sequentially with a progress bar. Supported scans reuse available hub summaries or preloaded rows. The tool reports hub query failures as scan errors and doesn't silently switch data sources. It reports AI metrics from a Kusto-only hub as unavailable. Select **Cost Management API** to run a separate live AI scan.

Incomplete billing-scope discovery leaves overall commitment utilization unavailable. Unreadable Hub tags and malformed budget records remain unverified, rather than counting as missing tags or confirmed budget coverage. Budget history retains usable rows from a partial inventory with a coverage note; failed or incomplete inventory with no usable budgets produces an error instead of a clean empty result.

Inventory scans that request all Resource Graph pages fail when a page is unreadable, a continuation token repeats, or the page limit is reached. A full page without a continuation token is also unverified, even if the true result happens to equal the page size. Resource queries retain `id`, which [Resource Graph requires for continuation tokens](https://learn.microsoft.com/powershell/module/az.resourcegraph/search-azgraph#example-3). These scans don't report an unverified inventory as complete.

### 5. Results

Results display inline with formatted tables, severity-colored guidance, and permission diagnostics.

**Guidance system** — After each scan result, contextual FinOps guidance appears with severity-based coloring:

| Icon  | Color  | Meaning                            |
| ----- | ------ | ---------------------------------- |
| `[!]` | Red    | Critical finding — action required |
| `[~]` | Yellow | Warning — improvement recommended  |
| `[+]` | Green  | Healthy — good practices confirmed |

Guidance includes FinOps Foundation best practices, actionable next steps, and links to Microsoft Learn documentation.

**Dollar colorization** — All dollar amounts in results are highlighted in green for quick scanning. Budget rows are colored by risk severity (red for over budget, yellow for at risk, green for on track).

**Permission diagnostics** — When a scan returns no data, the TUI explains why:

- **Access denied** (403/401) — Shows the exact error, required RBAC role, scope, and API
- **No data** — Explains whether the module requires specific resources (e.g., "Returns empty if no budgets are configured")

Each completed run automatically saves one CSV file per selected scan, a `FinOpsReport.html` summary, and a `ScanSummary.txt` text summary on the machine running the multitool. Failed or empty scans have a CSV status record. There's no export prompt or format picker.

The HTML report opens with the **FinOps story**: selected tenant and subscriptions, observed spend, largest resource costs, scan status, and follow-up actions. Actual costs stay separate by subscription, currency, and reported period. Full-month forecasts are separate estimates, and unavailable amounts aren't treated as zero. Failed scans and evidence gaps link to their detailed results.

For more than five subscriptions, the report shows a compact scope count with an expandable list of names and IDs. Result tables have sticky headers, row numbers, local search, sortable columns, and 25-row pages. Filters include text in collapsed details. Column edges support pointer dragging or keyboard arrow keys, and **Expand** opens a larger table view; **Close** or Escape restores its place and state. Tag inventory and policy recommendations retain expandable details. Each scan's summaries, notes, and guidance are grouped in one panel below its heading. The panel scrolls when its content is long, so notes don't lengthen the page. Wide tables scroll within their own frames on small screens. Printing includes all matching rows, not just the current page, and removes the notes panel's height limit. Collapsed details print only their summary line. These display controls don't change scan results or remove data from CSV exports. The HTML is self-contained and makes no external requests for these controls.

The story highlights up to five positive resource costs per subscription, currency, and period. **All returned resource costs** opens the complete returned resource table, including credits and any resource IDs and periods the data source provided. Source query limits can omit resources; this view doesn't prove the inventory is complete. A high cost alone isn't evidence of waste.

By default, reports go under the current user's local application data directory, in `FinOpsToolkit/Multitool/Reports`. On Windows, that's usually `%LOCALAPPDATA%\FinOpsToolkit\Multitool\Reports`. Each run creates a timestamped, uniquely named subfolder. The terminal prints its full path. `-OutputPath` selects a different local parent folder; it doesn't replace reports from an earlier run.

The run folder allows access only to the current user through filesystem permissions. On Unix, directories use mode `700` and files use mode `600`. The tool rejects Git repositories and worktrees, UNC paths, mapped Windows network drives, symbolic links, and junctions, and adds an ignore-all `.gitignore` as a backup against accidental staging. Unix network mounts aren't detected; choose a path on a local filesystem. If it can't safely save, it reports an error and keeps the scan results in `$FinOpsResults`; it doesn't fall back to the working directory.

Reports are plaintext and can contain subscription, resource, tag, and billing details. They aren't encrypted or uploaded by the tool. Administrators and processes running as your account can still access them. Keep custom locations outside synced folders, follow your organization's retention policy, and delete reports when they're no longer needed. These safeguards don't stop someone from moving or force-adding the files to a repository later.

Raw Hub downloads use private, per-run folders under the user's `FinOpsMultitool` application-data directory, not shared temporary storage. The reader removes these folders when a read finishes or returns an error. A process termination or host failure can leave a private `download-*` folder behind; after confirming no scan is using it, delete it according to your retention policy. The Parquet cache stays under `FinOpsMultitool/parquet`. Cached assemblies must match signature-verified package archives before loading. Untrusted ownership, replacement permissions on ancestor directories, write access by other accounts, and linked cache paths are rejected.

The Parquet reader pins its net8.0 dependency versions and SHA-512 archive hashes in [Get-FinOpsParquetPackageLock](modules/helpers/Read-FinOpsHubData.ps1), using published [NuGet package metadata](https://www.nuget.org/api/v2/). Corporate feeds must return the same archives; repackaged or unexpected dependencies are rejected. The pins include Snappier 1.3.1, which addresses [CVE-2026-44302](https://github.com/advisories/GHSA-pggp-6c3x-2xmx). Dependency updates require reviewing and updating the pins together.

CSV files use `RecordType` to distinguish datasets when a scan returns several collections, such as reservations and savings plans. Scalar `Summary.*` columns retain scan diagnostics and estimate assumptions. Nested summary collections appear once as separate record types, such as `Summary.UnderutilizedRIs`, instead of repeating in every row. Nested values within a record are JSON. CSV headers include fields from every exported record type, amounts use a decimal point regardless of your system locale, and dates use ISO 8601. Aggregate and detailed records are separate views, not amounts to add together.

The terminal limits tag inventory to a compact preview. The HTML tag inventory includes every returned tag and value, and wraps long cell text instead of shortening it. CSV exports preserve the underlying value records and their counts.

The TUI's results renderer escapes control characters before printing, so resource metadata isn't emitted as terminal escape sequences. Progress and warning messages written directly by scan modules aren't covered by this renderer. The underlying scan data and CSV values aren't rewritten by this display protection.

## Required permissions

Each scan requires specific permissions. The TUI identifies the required role when a scan fails because of missing permissions. Billing permissions depend on your agreement, such as a Microsoft Customer Agreement (MCA) or Enterprise Agreement (EA).

| Category               | Scans                                                                    | Required role                                                                                                                             | Scope                            |
| ---------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Optimization           | Orphaned Resources, Idle VMs, Storage Tier Advice, AHB, Legacy Resources | Reader                                                                                                                                    | Subscription                     |
| Governance             | Tag Inventory, Tag Recommendations, Policy Inventory/Recs                | Reader                                                                                                                                    | Subscription                     |
| Cost                   | Cost Data, Resource Costs, Cost by Tag, Cost Trend                       | Cost Management Reader                                                                                                                    | Subscription or management group |
| Commitments            | Reservation Advice, Savings Realized estimates                           | Cost Management Reader, and Reader for Azure Hybrid Benefit inventory                                                                     | Subscription or management group |
| Commitment utilization | Reservation and savings plan usage                                       | Billing access for the agreement, such as EA Enterprise Administrator (read only) or MCA Billing account reader or Billing profile reader | Billing account or profile       |
| Monitoring             | Budget Status, Anomaly Alerts                                            | Cost Management Reader                                                                                                                    | Subscription                     |
| Advisor                | Optimization Advice                                                      | Reader                                                                                                                                    | Subscription                     |
| Account                | Billing Structure, Contract Info, MACC                                   | Billing access for the agreement                                                                                                          | Billing account or profile       |
| Hub storage (optional) | Storage-backed cost and tag scans                                        | Storage Blob Data Reader                                                                                                                  | Hub storage account              |
| Hub Kusto (optional)   | Kusto-backed cost summaries                                              | Database query access                                                                                                                     | Hub database                     |

Subscription Reader access alone doesn't grant billing access. See [MCA billing roles](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-mca-roles), [EA roles](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-ea-roles), and [Kusto database roles](https://learn.microsoft.com/kusto/management/manage-database-security-roles). Reading hub data also requires network access to the storage or Kusto endpoint. If you receive a 403 response, check the firewall or private endpoint as well as role assignments.

## Available scans

The menu contains 26 scans. Four additional modules support direct investigations: VM cost breakdown, shared cost allocation, usage-proportional allocation, and billing account.

### Optimization

| Scan                | What it finds                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Orphaned Resources  | Unattached disks, NICs, public IPs, stopped VMs, empty App Service plans, and old snapshots for review                                 |
| Idle VMs            | Running VMs with average CPU below 5% and network traffic below 1 MB per day over 14 days. A second threshold flags underutilized VMs. |
| Storage Tier Advice | Blob storage that could move to cooler tiers                                                                                           |
| AHB Opportunities   | Windows/SQL VMs not using Azure Hybrid Benefit                                                                                         |
| Legacy Resources    | Legacy/retiring SKUs (v1 VM families, unmanaged disks, Basic IPs/LBs)                                                                  |

Storage tier advice uses 30-day transaction and capacity metrics. Missing or invalid samples leave an account unevaluated, not idle. Recommendations are review candidates, not proof that a tier change will save money; validate retrieval needs, eligibility, and retention charges before acting.

Idle VM checks likewise require CPU and inbound/outbound network samples. Failed or missing measurements leave the VM unevaluated and the utilization KPI unavailable. AHB license estimates use USD retail rates for a 730-hour month; `SavingsCurrency` and `SavingsPeriod` identify the units.

### Governance

| Scan                   | What it finds                                             |
| ---------------------- | --------------------------------------------------------- |
| Tag Inventory          | All tags across resources — names, values, coverage %     |
| Tag Recommendations    | Inconsistent casing, similar names, missing standard tags |
| Policy Inventory       | Azure Policy assignments with scope and compliance        |
| Policy Recommendations | Gaps in policy coverage for cost governance               |

**Policy Recommendations** checks definition IDs in direct assignments and in assigned initiatives. Policies found through an initiative appear as **Assigned (Initiative)**, with the matching assignment, scope, and enforcement mode in the report. Reading custom initiative members requires access to the definition's subscription or management group. Each distinct initiative is read once per scan.

If an initiative can't be read, unmatched policies appear as **Unknown**, not **Missing**. If the effective assignment inventory is incomplete, the launcher keeps the partial inventory but skips recommendations; it doesn't assume unread assignments are missing. Assignment coverage is the percentage of recommended definition IDs found in the supplied inventory, not Azure Policy compliance or proof of enforcement. Review parameters, exclusions, enforcement modes, and equivalent custom policies before treating a recommendation as a governance gap.

Policy compliance coverage is separate from assignment coverage. When ARG coverage is incomplete, the tool requests REST resource summaries for every selected subscription rather than combining the two counting methods. If those requests don't establish complete coverage, the report retains available evidence but leaves the overall percentage unverified. Assignments are identified by resource ID, so different assignments with the same display name remain distinct.

Policy definition reads have separate coverage too. Failed or malformed reads produce a visible warning and a **Limited data** result. `DefinitionCoverageIncomplete` and `DefinitionErrors` identify the gap in the scan result and CSV export. Already-read assignments and valid compliance percentages remain available. An unresolved effect in a successfully read definition isn't counted as a failed read.

Policy locations display available subscription and management-group names while retaining the original scope IDs. Subscription names come from the selected scope. The inventory looks up only distinct management groups referenced by its assignments and accepts a display name only when the response matches the requested group and tenant. If a name can't be verified, the ID remains visible and `ScopeNameErrors` records the reason; assignment and compliance results aren't discarded. HTML details retain the raw IDs, and CSV includes `Scope` and `ScopeDisplayName`.

### Cost Analysis

| Scan           | What it finds                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------- |
| Cost Data      | Monthly spend per subscription                                                                      |
| Resource Costs | Top resources by cost                                                                               |
| Cost by Tag    | Spend breakdown by tag key/value                                                                    |
| Cost Trend     | Month-over-month spend comparison                                                                   |
| Unit Economics | Cost per vCPU, per GB RAM, per VM, and per GB stored (disk + blob/file, with compute/storage split) |

Resource-cost API queries capture one UTC window from the first day of the current month to the query time. Every returned row carries that same window in `ActualPeriod`, `ActualPeriodStart`, and `ActualPeriodEnd`, with `ActualPeriodSource` set to `Query window`. This describes the requested period, not proof that billing data is complete through its end. Resource names and types are derived from the returned ID, including nested resources and reservation charges. The original `ResourcePath` remains in CSV and expandable HTML details. Charges without subscription attribution aren't assigned to an arbitrary subscription; subscription-scoped responses retain their known query scope.

Cost trend shows a selected-scope aggregate and a subscription view with names and IDs. API queries capture one UTC window covering six full months and the current partial month. HTML labels that partial month from the captured query end, not the date you open the report. `CostPeriodStartUtc`, `CostPeriodEndUtc`, `CostBasis`, and `QueryScope` retain the request context in the result and CSV export. The window doesn't establish billing-data completeness.

A management-group response can omit selected subscriptions that sit outside that group or have no cost rows. The scan queries each omitted subscription individually and records it in `IndividuallyQueriedIds`. If the management-group response has no rows for any selected subscription, the scan queries every selected subscription individually instead; `IndividuallyQueriedIds` stays empty, and a failed query fails the scan. Coverage distinguishes subscriptions with returned rows, successful empty subscription queries (`NoDataSubscriptionIds`), and omitted subscriptions whose individual results couldn't be added because the query failed or a month's currency differed from the trend total (`UnverifiedSubscriptionIds`, with reasons in `QueryErrors`). An unverified subscription isn't assumed to have zero cost, and a failed query isn't proof of missing access. Unverified coverage sets `CoverageIncomplete`; the aggregate isn't described as a whole-tenant total. Requests and returned grouped rows are filtered to the selected IDs. Missing months aren't filled with zero, and switching views doesn't remove aggregate or per-subscription CSV data. Older results without metadata remain readable but show unverified coverage and an unrecorded query window.

Cost trend requires explicit cost, date, and currency fields. It rejects monthly totals that would combine different currencies rather than labeling the combined amount with one currency. Failed required responses or continuation pages still fail the scan instead of publishing a partial total. When the individual query for an omitted subscription fails, or a month's currency differs from the trend total, only that subscription stays unverified.

Management-group cost-scope discovery tries at most 25 distinct candidates: up to 24 non-root groups, then the tenant root. List pagination remains intact, and each candidate keeps the existing low retry budget. The limit applies to candidates, not total HTTP requests. A warning identifies when groups are left unprobed; this doesn't establish that those groups lack cost access. If none of the bounded candidates works, cost scans query the selected subscriptions individually. Discovery results and failure state are cached only for the requested tenant during the scan.

On the API path, **Cost by Tag** keeps results from subscriptions whose full cost query succeeded when another subscription fails. `CoverageIncomplete`, `ScannedSubs`, `TotalSubs`, `SuccessfulSubscriptionIds`, and `FailedSubscriptions` identify the coverage and failures. Reports show **Limited data**, and whole-scope allocation KPIs remain unavailable. If every subscription fails, the scan reports an error. Failed continuation pages don't contribute partial costs, and missing resource or resource-group tag maps stop the scan rather than classifying unknown tags as untagged. Amounts from different currencies aren't combined.

**Unit Economics** retains measured VM, vCPU, memory, and storage capacity when currency evidence is missing or mixed. Combined costs, cost shares, and monetary unit rates remain empty, with `CostAvailable = false` and an explanatory `CostIssue`. A measured zero with known currency remains zero.

Advisor and reservation recommendations retain each recommendation's savings currency. Combined estimates remain unavailable when currency is missing or mixed; a dollar symbol is not substituted for an unknown currency. Tag inventory, alerts, and billing inventories expose `CoverageIncomplete`, read errors, and explanatory notes when a required read fails. Incomplete tag inventory doesn't become missing-tag recommendations.

### AI & ML

| Scan                | What it finds                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| AI Workload Metrics | Detects AI workloads, then token consumption by model, AI spend, cost per 1K tokens, cost per call |

AI usage counts remain available when monetary rates can't be calculated. Missing or mixed billing currencies suppress combined and per-account monetary outputs; `CostIssue` explains why. Token and request rates use costs from accounts with the corresponding measured usage, not all Cognitive Services spend. Failed metric reads suppress aggregate rates and expose a `RateIssue`; reports retain the separate spend and available usage evidence. Missing measurements aren't treated as measured zero.

Live AI queries share one captured UTC month-to-date window for Azure Monitor usage and amortized account cost. Token totals use the measured `TokenTransaction` value per account and deployment, including zero; the fallback uses prompt plus generated tokens only when both were measured. Account, deployment, and overall totals use that same basis. `TokenBasis`, `ResourceId`, and `SubscriptionId` retain the identity and calculation, so same-named deployments in different accounts don't merge. Hub model-meter rows also retain account identity. Missing requests or tokens remain unavailable, and incomplete measurements suppress account and aggregate rates. These are effective account rates, not model prices or a billing reconciliation. See the [Azure OpenAI metric definitions](https://learn.microsoft.com/azure/foundry/openai/monitor-openai-reference#metrics).

### Commitments

| Scan                   | What it finds                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------- |
| Reservation Advice     | RI purchase recommendations from Advisor                                                |
| Commitment Utilization | RI and Savings Plan usage rates                                                         |
| Savings Realized       | Estimates of commitment and Azure Hybrid Benefit savings, not measured realized savings |

Commitment utilization shows all returned reservations and savings plans, with their IDs and latest returned usage periods. Missing SKU or resource-kind metadata triggers a targeted [reservation details](https://learn.microsoft.com/rest/api/reserved-vm-instances/reservation/get?view=rest-reserved-vm-instances-2022-11-01) lookup; a returned name is accepted only when its resource ID matches. Denied or invalid metadata retains the ID and known utilization. Provisioning state and billing scope aren't substituted for SKU or kind. Missing percentages and absent commitment types have unavailable averages, not 0%; a measured 0% remains zero. Averages are unweighted and aren't reported for incomplete or unscoped coverage. Billing-scope results and the explicitly labeled reservation-order fallback can include commitments outside the selected subscriptions.

The scan keeps the **Savings Realized** name for compatibility. Reservation and savings plan estimates use assumed effective discounts of 40% and 25%. Azure Hybrid Benefit estimates use a Windows license premium when available, with a fallback estimate otherwise. Results include `IsEstimate` and `EstimateBasis`. Compare the estimates with matching pay-as-you-go rates and benefit usage before reporting realized savings.

Commitment estimates cover usage charges in the captured UTC month-to-date period and retain the billing currency. Purchases, refunds, and unused commitment charges are excluded before aggregation. Unknown, nonmonetary, or mixed billing currencies stop the scan instead of producing a combined amount. Negative usage adjustments also stop the estimate because the assumed discount can't produce a comparable savings amount. Use `RISavingsMonthToDate`, `SPSavingsMonthToDate`, and `CommitmentSavingsMonthToDate`, together with `Currency` and `Period`.

The AHB estimate is separate: `AHBSavingsMonthly` represents 730 hours for the current VM inventory in USD, using a retail Windows license premium or a USD 50 per-VM fallback. `AHBCurrency` and `AHBPeriod` identify those units. The scan doesn't combine these amounts or annualize them. The legacy `RISavingsMonthly`, `SPSavingsMonthly`, `TotalMonthly`, and `TotalAnnual` fields remain present but are empty.

### Monitoring

For more than 50 selected subscriptions, Budget Status samples ten first. If all ten queries succeed without budgets, the remaining subscriptions aren't queried and coverage stays unverified. The report labels this as sampling, not an access denial. Smaller selections query every selected subscription. The scan covers subscription budgets, not all resource-group, management-group, or billing-scope budgets.

| Scan           | What it finds                                                  |
| -------------- | -------------------------------------------------------------- |
| Budget Status  | Budget consumption vs. thresholds                              |
| Budget History | Completed-month costs compared with the current monthly budget |
| Anomaly Alerts | Recent cost anomaly detections                                 |

**Budget History** supports monthly cost budgets with no filter, a tag or dimension `In` filter, or an `and` combination of those filters. An empty filter object (`{}`) means no filter. Filtered budgets use a Cost Management query with the matching filter, even when the primary cost source is a hub. Only unfiltered budgets can reuse the subscription cost trend. Results are cached separately for each subscription and exact filter, including case-sensitive tag values.

Months before a budget was active for the full month remain **Unavailable**. Unsupported filters, nonmonthly periods, missing budget details, and currency mismatches also remain unavailable; the tool doesn't substitute whole-subscription spend for a filtered budget. Failed or incomplete cost queries remain errors rather than zero spend. Comparisons use the current budget amount and filter, not historical budget revisions. See the [budget filter schema](https://learn.microsoft.com/azure/templates/microsoft.consumption/2023-11-01/budgets#budgetfilter) and [Cost Management query API](https://learn.microsoft.com/rest/api/cost-management/query/usage?view=rest-cost-management-2023-11-01).

Current forecasts in **Budget Status** come from Azure's budget response, independently of historical actual costs. If the response omits a forecast amount or a compatible currency, the forecast remains **Unavailable**.

### Sustainability

Carbon reports retain available detail when another report section fails, but leave missing headline measurements unavailable. Percentage change requires a positive previous-month measurement. A failed permission check is reported separately from a window with no published measurements.

| Scan             | What it finds                                                                               |
| ---------------- | ------------------------------------------------------------------------------------------- |
| Carbon Emissions | Cloud carbon emissions, month-over-month change, 12-month trend, per-subscription breakdown |

### Advisor & Account

| Scan                | What it finds                                               |
| ------------------- | ----------------------------------------------------------- |
| Optimization Advice | Azure Advisor cost recommendations                          |
| Billing Structure   | Account hierarchy and enrollment details                    |
| Contract Info       | Agreement type, offer, support plan                         |
| MACC Commitment     | Microsoft Azure Consumption Commitment balance and drawdown |

## FinOps KPI coverage

The scan modules provide measurements, estimates, or proxies related to [FinOps Foundation KPIs](https://www.finops.org/finops-kpis/). Some KPI definitions need additional inputs and aren't calculated by this tool. The `finops-multitool` agent skill routes a natural-language question to the matching investigation.

The HTML report's **KPI reference** tab lists every entry from the shared [KPI catalog](kpi/kpi-catalog.json), including entries not measured in the run. Search or filter by status, expand **Calculation and interpretation**, and follow a source-scan link when that scan was included. Each entry identifies the formula, required inputs, interpretation, and limitations.

| Status        | Meaning                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Computed      | A value was derived from the scan. It can be an estimate or proxy; this isn't a health rating.   |
| Unavailable   | The selected scan failed or lacks comparable measurements. Missing values aren't measured zeros. |
| Not run       | The scan for a calculable KPI wasn't selected.                                                   |
| Informational | The catalog explains the KPI, but this tool doesn't calculate it.                                |

**Calculation and thresholds** disclosures beside Unit Economics, Idle VMs, Storage Tier Advice, and Budget Status explain the values in place. Unit Economics names the VM-compute-plus-storage denominator, subtotal, captured UTC window, and amortized basis. The percentage isn't a share of the entire Azure bill or an efficiency score. Unit rates divide period cost by current capacity, including stopped VMs, rather than time-weighted running-resource capacity.

Idle VM screening uses 14-day average CPU below 5% and combined network below 1 MiB/day; otherwise, CPU below 10% and network below 10 MiB/day flags underutilization. Storage screening uses 30-day blob transactions: fewer than 100 with positive rounded capacity suggests an Archive candidate; otherwise, fewer than 1,000 with capacity above 1 GiB suggests Cool. These are scanner rules, not Azure Advisor criteria or per-blob last-access analysis. Evaluated counts exclude unreadable metrics.

Budget coverage counts selected subscriptions with at least one budget, not spend or forecast coverage. Forecast availability is shown separately. A zero at-risk count doesn't establish that budgets with missing forecasts are on track.

There is no universal healthy compute/storage split or unit-cost target. Compare the same scope, period, currency, capacity basis, and service requirements against a workload-specific baseline, as described in the [FinOps unit-economics guidance](https://www.finops.org/framework/capabilities/unit-economics/). Storage-tier decisions also need [retrieval, retention, and eligibility checks](https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview).

A few examples of question and output:

### Percentage of Legacy Resource → legacy resources

> "Which of my resources are running on legacy or retiring SKUs?"

```text
Legacy / Retiring Resources — 47 found across 156 subscriptions

By category:
  Legacy v1 VM families        18   (Basic_A / Standard_A0-A7 / D / DS / G)
  Unmanaged VHD disks           9   (migrate to managed disks)
  HDD Standard_LRS ≥128GB      11   (upgrade to Premium SSD)
  Basic SKU Public IPs          6   (retiring Sep 2025 → Standard)
  Basic SKU Load Balancers      3   (retiring Sep 2025 → Standard)
```

The scan returns candidate counts. A legacy percentage also needs a complete, comparable resource denominator; the catalog entry remains informational.

### Cost per Gigabyte Stored / Hourly Cost per CPU Core → unit economics

> "What's my cost per vCPU and per GB of storage this month?"

Abridged example:

```text
Unit Economics — Month to Date (USD)

Compute  USD 128,400 (75.7% of VM compute + storage spend)
Storage  USD  41,200 (24.3% of VM compute + storage spend)
Subtotal USD 169,600; other Azure services excluded
Capacity 312 VMs / 1,840 vCPU / 7,360 GB RAM / 126,400 GB storage

  Cost per vCPU      USD 69.78   (month-to-date)
  Cost per GB RAM    USD 17.45   (month-to-date)
  Cost per VM        USD 411.54  (month-to-date)
  Cost per GB stored USD 0.326  (month-to-date)
```

vCPU and RAM come from Compute SKU capabilities. Storage capacity combines provisioned managed disk capacity with storage account usage from the Azure Monitor `UsedCapacity` metric. The tool reports the combined capacity in GB. Cost queries cover the selected subscriptions. If the tool can't access the management group scope, it queries each subscription separately and reports failed queries as errors. **Hourly Cost per CPU Core** divides cost per vCPU by the elapsed hours in the recorded UTC cost period, with a one-hour minimum. It doesn't use a fixed 730-hour month.

### Token Consumption / Cost per 1K Tokens / Cost per API Call → ai workloads

> "What are my AI/LLM workloads costing per token and per request this month?"

This scan first queries Resource Graph for AI workloads (Azure OpenAI, Foundry Tools, Azure Machine Learning, Azure AI Search, and GPU VMs) in the selected subscriptions. When AI workloads are present, the API path combines Azure Monitor token metrics with Cost Management spend over the same month-to-date window.

```text
AI footprint — OpenAI/AIServices: 3   ML workspaces: 1   AI Search: 2   GPU VMs: 0
Tokens (MTD): 412,800,000 total (288,100,000 in / 124,700,000 out) over 1,240,500 requests
AI spend (MTD): USD 3,910.42  |  USD 0.0095 /1K tokens  |  USD 0.00315 /request

Deployment        PromptTokens   GeneratedTokens   TotalTokens   PctOfTokens
gpt-4o            210,400,000     98,200,000        308,600,000   74.8
gpt-4o-mini        77,700,000     26,500,000        104,200,000   25.2
```

Produces `Token Consumption`, `Cost per 1K Tokens` (effective blended rate), and `Cost per API Call`; the per-model breakdown highlights where to shift traffic to cheaper SKUs or evaluate Provisioned Throughput Units (PTUs).

The TUI uses the selected `-DataSource`. When readable hub rows cover the selected subscriptions, AI spend and billed token volume come from those rows and use their observed period. A Kusto-only hub doesn't currently provide this AI scan, so the result is unavailable. Select **Cost Management API** to run a separate live scan. Cost per request is available only on the API path because request counts aren't billed line items.

### Carbon per Unit of Spend / Carbon Efficiency → carbon

> "Show my cloud carbon footprint and how it changed month over month."

```text
Carbon Emissions — latest available month: 2026-04 (data lags ~2 mo)

Total emissions      18,420 kgCO2e
Previous month       20,110 kgCO2e
Change               -1,690 kgCO2e  (-8.4%)   ↓ improving

Top emitting subscriptions:
  Production-East   00000000…   7,910 kgCO2e
  Data-Platform     a1b2c3d4…   4,330 kgCO2e
```

Combined with cost data, `Carbon per Unit of Spend` = total emissions ÷ monthly spend.

### Commitment Utilization Score / % Discount Waste → commitment utilization

> "How well are my reservations and savings plans being used?"

```text
Commitment Utilization — trailing 30 days

Reserved Instances    94.2% utilized   ($3,120 unused)
Savings Plans         88.7% utilized   ($1,540 unused)
Overall score         91.8%
```

`Commitment Utilization Score` = 91.8%; `% Commitment Discount Waste` = 100 − 91.8 = 8.2%.

### % Costs from Untagged Resources → cost by tag

> "How much of my spend is on untagged resources?"

```text
Cost by Tag — Month to Date

Tagged spend       $612,300   (87.4%)
Untagged spend     $ 88,200   (12.6%)   ← KPI
```

**% Costs from Untagged Resources** = 12.6%. The resource-based path measures cost with no allocation tag. Server-aggregated results use the allocation tag with the lowest cost coverage and name that tag in the result. The tool reports the percentage as unavailable when net totals are zero or negative, or when credits make the percentage unsuitable for comparison. It doesn't score those results.

## FinOps hub integration

When you select **FinOps Hub**, supported scans reuse its available cost data:

- **Tag data reuse**: stored cost records can supply tag inventory and cost by tag. Kusto returns aggregated tag costs. Azure Resource Graph supplies resource inventory where needed.
- **Fewer cost queries**: hub summaries reduce Cost Management API calls. Other scans and forecast enrichment can still call Azure APIs and encounter throttling.
- **Observed cost periods**: actual costs use the dates present in the selected subscriptions' hub data, not an assumed current-month window.
- **Forecast enrichment**: for current-month storage data, the TUI can show a separate full-month API forecast with matching currency. It never adds that forecast to hub actuals. The forecast is unavailable for older data and Kusto summaries, or when the API can't supply it.
- **Resource coverage**: a hub contains only resources represented in its cost data. The storage path queries Azure Resource Graph for total and untagged resource counts when available.

### FinOps hub data paths

The **Cost Data**, **Resource Costs**, and **Cost by Tag** scans support three hub paths. The Kusto paths aggregate data in the engine and return summarized results without loading raw cost rows into PowerShell:

| Path                       | When                                                        | How                                                                                                                                                                                                                                     |
| -------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Kusto — online**         | A deployed hub with an Azure Data Explorer / Fabric cluster | The cluster is discovered via Azure Resource Graph (`microsoft.kusto/clusters` tagged `ftk-tool == 'FinOps hubs'`), queried with a bearer token. Aggregation runs in KQL against the `Costs` function.                                  |
| **Local Kusto (ftklocal)** | A local Kusto emulator with cost data in its `Hub` database | Set `FINOPS_HUB_KUSTO_URI`. Optionally, set `FINOPS_HUB_KUSTO_DB`, which defaults to `Hub`. Loopback queries are anonymous. The public launcher still uses Azure context and resource metadata, so this isn't a fully offline workflow. |
| **Storage export reader**  | Small datasets, or when no Kusto cluster is available       | Reads the hub's `ingestion` parquet / `msexports` CSV and aggregates in PowerShell. A convenience fallback, **not** the scalable path.                                                                                                  |

An explicit `-DataSource API` or `-DataSource GraphOnly` takes precedence over `FINOPS_HUB_KUSTO_URI` and doesn't preload hub data. Otherwise, a configured Kusto URI selects the hub without requiring storage-account discovery. For a discovered hub, the tool prefers Kusto and uses the storage reader when no Kusto provider is available. An explicit `-DataSource Hub` fails if neither a configured endpoint nor hub storage is available; it doesn't silently switch to API.

Remote Kusto endpoints and requests carrying access tokens require HTTPS. HTTP is allowed only for a token-free loopback emulator. Endpoint URLs can't contain credentials or fragments. Kusto and export-blob requests don't follow redirects; configure the final endpoint URL.

Reading Parquet requires a signature verifier: NuGet on Windows or .NET SDK 8 or later on Linux. macOS Parquet setup is unavailable because signed-package verification isn't supported. If the verifier is unavailable, the cache remains unloaded and is preserved for a later attempt. If the reader can't be prepared, the tool warns you with the reason and attempts the hub's `msexports` CSV instead of normalized Parquet data. An export read failure still reports an error rather than zero spend.

#### Environment variables

| Variable               | Effect                                                                                                                                      | Default               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `FINOPS_HUB_KUSTO_URI` | Kusto cluster query URI. An `https://...kusto.windows.net` cluster (token auth) or `http://localhost:<port>` ftklocal emulator (anonymous). | unset (auto-discover) |
| `FINOPS_HUB_KUSTO_DB`  | Hub database name.                                                                                                                          | `Hub`                 |

The tool loads hub summaries or storage rows once per run and reuses them for supported scans. It reports a failed query against the selected hub as an error and doesn't silently replace the result with API data.

## Scripting (non-interactive)

The scan modules can be called directly without the TUI:

For usage-proportional showback with an explicit `-PoolAmount`, supply `-PoolCurrency` and `-PoolPeriod` to identify its units. Omitted units remain unknown. Resource-backed pools retain the cost source's period and currency. Rounded showback allocations reconcile to the pool amount; they don't write native billing rules.

```powershell
Import-Module .\FinOpsMultitool.psm1

# Run a single scan
$tags = Get-TagInventory -Subscriptions $subs -TenantId $tid

# Read Hub data and convert
$hubData = Read-FinOpsHubData -StorageAccountName 'myhub' -ResourceGroupName 'rg-hub' -Months 1
$tagInventory = ConvertTo-TagInventoryFromHub -HubData $hubData
$costByTag = ConvertTo-CostByTagFromHub -HubData $hubData -ExistingTags $tagInventory.TagNames
```

## Validation

Run the normal toolkit unit and lint gates from the repository root:

```powershell
./.build/start.ps1 -Task Test.PowerShell.All
```

Run the focused integration checks in a fresh PowerShell 7 session from the repository root. Install Pester 6.0.0 and the Az modules listed in the workflow first. These tests build in a temporary directory, replace Azure access with synthetic responses, and use isolated package caches. They don't scan subscriptions or overwrite the checkout's release output. Package restore and signature verification require network access to the configured NuGet feeds and certificate services.

```powershell
Import-Module Pester -RequiredVersion 6.0.0
$paths = @('src/powershell/Tests/Integration/MultitoolPackage.Tests.ps1')
$minimumPassed = 3
if (-not $IsMacOS) {
  $paths += 'src/powershell/Tests/Integration/MultitoolParquet.Tests.ps1'
  $minimumPassed += 2
}
$configuration = New-PesterConfiguration
$configuration.Run.Path = $paths
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration
if ($null -eq $result -or $result.Result -ne 'Passed' -or
  $result.PassedCount -lt $minimumPassed -or $result.FailedCount -ne 0 -or
  $result.SkippedCount -ne 0 -or $result.NotRunCount -ne 0 -or
  $result.FailedContainersCount -ne 0 -or $result.FailedBlocksCount -ne 0 -or
  $result.Containers.Count -ne $paths.Count) {
  throw 'Multitool integration validation failed or was incomplete.'
}
```

The workflow records the tested merge commit, host, PowerShell version, and test counts in each job summary. Platform-specific `multitool-tests-*` artifacts retain NUnit results for 14 days. Only the two named test-result XML files are uploaded, not scan reports, package caches, or build output. The macOS summary explicitly records that signed Parquet integration wasn't run.

These checks don't establish live Azure API behavior or current tenant access. A live smoke test must use an explicitly selected subscription and matching cost periods and currencies.

## File structure

```text
FinOpsMultitool/
├── README.md                  # This file
├── FinOpsMultitool.psm1       # Module loader (dot-sources all scan modules)
├── Invoke-FinOpsMultitool.ps1 # TUI entry point
├── modules/
│   ├── helpers/
│   │   ├── Read-FinOpsHubData.ps1          # Hub storage reader + converters (small-dataset path)
│   │   ├── Invoke-FOHubKustoQuery.ps1      # Hub Kusto REST transport (ADX/Fabric/ftklocal)
│   │   ├── Get-FOHubProvider.ps1           # Scalable hub provider (discovery + engine-side cost intents)
│   │   ├── Get-PlainAccessToken.ps1        # Token helper
│   │   ├── Invoke-AzRestMethodWithRetry.ps1 # REST retry logic
│   │   ├── Search-AzGraphSafe.ps1          # ARG query wrapper
│   │   └── MgCostScope.ps1                 # Management group scope state
│   ├── Get-CostData.ps1
│   ├── Get-ResourceCosts.ps1
│   ├── Get-TagInventory.ps1
│   ├── Get-CostByTag.ps1
│   ├── Get-OrphanedResources.ps1
│   ├── Get-IdleVMs.ps1
│   └── ...                    # One file per scan module
```
