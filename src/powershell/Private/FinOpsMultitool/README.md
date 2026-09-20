<!-- markdownlint-disable -->

# FinOps multitool terminal UI (TUI)

Interactive terminal interface for running FinOps scans against Azure subscriptions. No GUI dependencies — works in any terminal on Windows, macOS, and Linux.

## Quick start

```powershell
# From the FinOpsMultitool directory
Import-Module .\FinOpsMultitool.psm1
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

On launch, the TUI checks for an existing `Az.Accounts` session and starts `Connect-AzAccount` when needed. If you supply `-SubscriptionId`, the tool resolves the subscription and sets the subscription and tenant context before displaying menus. Otherwise, the tool offers a tenant menu when supported and discovers subscriptions in the selected tenant.

### 2. Data source selection

If a FinOps Hub is detected in any of your subscriptions, you'll be asked to choose a data source:

| Source                  | Description                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **FinOps Hub**          | Reads available cost data from the hub. Kusto summarizes data in the engine; the storage reader is for small datasets. |
| **Cost Management API** | Queries currently available cost data through the Cost Management REST API. Doesn't preload hub data.                  |
| **Resource Graph only** | Skips all cost APIs. Only runs scans that use Azure Resource Graph (orphaned resources, idle VMs, etc).                |

When the **FinOps Hub** source is chosen, the tool prefers the hub's **Kusto database** (Azure Data Explorer / Fabric, or a local ftklocal emulator) and pushes aggregation into the engine, returning only summarized results. This is the scalable path for large customer datasets — it never loads the raw cost rows into PowerShell. See [FinOps Hub data paths](#finops-hub-data-paths) below. The storage-export reader remains as a small-dataset fallback.

### 3. Scan selection

Use arrow-key menus to select scans when your host supports them. Other hosts use numbered prompts. For automation, use `-NonInteractive` with `-Scans`, `-DataSource`, and `-SubscriptionId`. Reports are saved automatically; `-OutputPath` changes their parent folder. All menu scans are selected by default except **Billing Structure**.

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

The story highlights up to five positive resource costs per subscription, currency, and period. **All returned resource costs** opens the complete returned resource table, including credits and any resource IDs and periods the data source provided. Source query limits can omit resources; this view doesn't prove the inventory is complete. A high cost alone isn't evidence of waste.

By default, reports go under the current user's local application data directory, in `FinOpsToolkit/Multitool/Reports`. On Windows, that's usually `%LOCALAPPDATA%\FinOpsToolkit\Multitool\Reports`. Each run creates a timestamped, uniquely named subfolder. The terminal prints its full path. `-OutputPath` selects a different local parent folder; it doesn't replace reports from an earlier run.

The run folder allows access only to the current user through filesystem permissions. On Unix, directories use mode `700` and files use mode `600`. The tool rejects Git repositories and worktrees, UNC paths, mapped Windows network drives, symbolic links, and junctions, and adds an ignore-all `.gitignore` as a backup against accidental staging. Unix network mounts aren't detected; choose a path on a local filesystem. If it can't safely save, it reports an error and keeps the scan results in `$FinOpsResults`; it doesn't fall back to the working directory.

Reports are plaintext and can contain subscription, resource, tag, and billing details. They aren't encrypted or uploaded by the tool. Administrators and processes running as your account can still access them. Keep custom locations outside synced folders, follow your organization's retention policy, and delete reports when they're no longer needed. These safeguards don't stop someone from moving or force-adding the files to a repository later.

Raw Hub downloads use private, per-run folders under the user's `FinOpsMultitool` application-data directory, not shared temporary storage. The reader removes these folders when the read finishes or fails. The Parquet cache stays under `FinOpsMultitool/parquet`. Cached assemblies must match signature-verified package archives before loading. Untrusted ownership, replacement permissions on ancestor directories, write access by other accounts, and linked cache paths are rejected.

The Parquet reader pins its net8.0 dependency versions and SHA-512 archive hashes in [Get-FinOpsParquetPackageLock](modules/helpers/Read-FinOpsHubData.ps1), using published [NuGet package metadata](https://www.nuget.org/api/v2/). Corporate feeds must return the same archives; repackaged or unexpected dependencies are rejected. The pins include Snappier 1.3.1, which addresses [CVE-2026-44302](https://github.com/advisories/GHSA-pggp-6c3x-2xmx). Dependency updates require reviewing and updating the pins together.

CSV files use `RecordType` to distinguish datasets when a scan returns several collections, such as reservations and savings plans. Scalar `Summary.*` columns retain scan diagnostics and estimate assumptions. Nested summary collections appear once as separate record types, such as `Summary.UnderutilizedRIs`, instead of repeating in every row. Nested values within a record are JSON. CSV headers include fields from every exported record type, amounts use a decimal point regardless of your system locale, and dates use ISO 8601. Aggregate and detailed records are separate views, not amounts to add together.

The terminal limits tag inventory to a compact preview. The HTML tag inventory includes every returned tag and value, and wraps long cell text instead of shortening it. CSV exports preserve the underlying value records and their counts.

The TUI escapes control characters in displayed text so resource metadata can't supply terminal escape commands through its report renderer. The underlying scan data and CSV values aren't rewritten by this display protection.

## Required permissions

Each scan requires specific permissions. The TUI identifies the required role when a scan fails because of missing permissions. Billing permissions depend on your agreement, such as a Microsoft Customer Agreement (MCA) or Enterprise Agreement (EA).

| Category               | Scans                                                     | Required role                                                                                                                             | Scope                            |
| ---------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Optimization           | Orphaned Resources, Idle VMs, Storage Tier Advice, AHB    | Reader                                                                                                                                    | Subscription                     |
| Governance             | Tag Inventory, Tag Recommendations, Policy Inventory/Recs | Reader                                                                                                                                    | Subscription                     |
| Cost                   | Cost Data, Resource Costs, Cost by Tag, Cost Trend        | Cost Management Reader                                                                                                                    | Subscription or management group |
| Commitments            | Reservation Advice, Savings Realized estimates            | Cost Management Reader, and Reader for Azure Hybrid Benefit inventory                                                                     | Subscription or management group |
| Commitment utilization | Reservation and savings plan usage                        | Billing access for the agreement, such as EA Enterprise Administrator (read only) or MCA Billing account reader or Billing profile reader | Billing account or profile       |
| Monitoring             | Budget Status, Anomaly Alerts                             | Cost Management Reader                                                                                                                    | Subscription                     |
| Advisor                | Optimization Advice                                       | Reader                                                                                                                                    | Subscription                     |
| Account                | Billing Structure, Contract Info, MACC                    | Billing access for the agreement                                                                                                          | Billing account or profile       |
| Hub storage (optional) | Storage-backed cost and tag scans                         | Storage Blob Data Reader                                                                                                                  | Hub storage account              |
| Hub Kusto (optional)   | Kusto-backed cost summaries                               | Database query access                                                                                                                     | Hub database                     |

Subscription Reader access alone doesn't grant billing access. See [MCA billing roles](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-mca-roles), [EA roles](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-ea-roles), and [Kusto database roles](https://learn.microsoft.com/kusto/management/manage-database-security-roles). Reading hub data also requires network access to the storage or Kusto endpoint. If you receive a 403 response, check the firewall or private endpoint as well as role assignments.

## Available scans

### Optimization (Resource Graph)

| Scan                | What it finds                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Orphaned Resources  | Unattached disks, NICs, public IPs, NSGs                                                                                               |
| Idle VMs            | Running VMs with average CPU below 5% and network traffic below 1 MB per day over 14 days. A second threshold flags underutilized VMs. |
| Storage Tier Advice | Blob storage that could move to cooler tiers                                                                                           |
| AHB Opportunities   | Windows/SQL VMs not using Azure Hybrid Benefit                                                                                         |
| Legacy Resources    | Legacy/retiring SKUs (v1 VM families, unmanaged disks, Basic IPs/LBs)                                                                  |

### Governance

| Scan                   | What it finds                                             |
| ---------------------- | --------------------------------------------------------- |
| Tag Inventory          | All tags across resources — names, values, coverage %     |
| Tag Recommendations    | Inconsistent casing, similar names, missing standard tags |
| Policy Inventory       | Azure Policy assignments with scope and compliance        |
| Policy Recommendations | Gaps in policy coverage for cost governance               |

**Policy Recommendations** checks definition IDs in direct assignments and in assigned initiatives. Policies found through an initiative appear as **Assigned (Initiative)**, with the matching assignment, scope, and enforcement mode in the report. Reading custom initiative members requires access to the definition's subscription or management group. Each distinct initiative is read once per scan.

If an initiative can't be read, unmatched policies appear as **Unknown**, not **Missing**. If the effective assignment inventory is incomplete, the launcher keeps the partial inventory but skips recommendations; it doesn't assume unread assignments are missing. Assignment coverage is the percentage of recommended definition IDs found in the supplied inventory, not Azure Policy compliance or proof of enforcement. Review parameters, exclusions, enforcement modes, and equivalent custom policies before treating a recommendation as a governance gap.

### Cost Analysis

| Scan           | What it finds                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------- |
| Cost Data      | Monthly spend per subscription                                                                      |
| Resource Costs | Top resources by cost                                                                               |
| Cost by Tag    | Spend breakdown by tag key/value                                                                    |
| Cost Trend     | Month-over-month spend comparison                                                                   |
| Unit Economics | Cost per vCPU, per GB RAM, per VM, and per GB stored (disk + blob/file, with compute/storage split) |

### AI & ML

| Scan                | What it finds                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| AI Workload Metrics | Detects AI workloads, then token consumption by model, AI spend, cost per 1K tokens, cost per call |

### Commitments

| Scan                   | What it finds                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------- |
| Reservation Advice     | RI purchase recommendations from Advisor                                                |
| Commitment Utilization | RI and Savings Plan usage rates                                                         |
| Savings Realized       | Estimates of commitment and Azure Hybrid Benefit savings, not measured realized savings |

The scan keeps the **Savings Realized** name for compatibility. Reservation and savings plan estimates use assumed effective discounts of 40% and 25%. Azure Hybrid Benefit estimates use a Windows license premium when available, with a fallback estimate otherwise. Results include `IsEstimate` and `EstimateBasis`. Compare the estimates with matching pay-as-you-go rates and benefit usage before reporting realized savings.

Commitment estimates cover usage charges in the captured UTC month-to-date period and retain the billing currency. Purchases, refunds, and unused commitment charges are excluded before aggregation. Unknown, nonmonetary, or mixed billing currencies stop the scan instead of producing a combined amount. Negative usage adjustments also stop the estimate because the assumed discount can't produce a comparable savings amount. Use `RISavingsMonthToDate`, `SPSavingsMonthToDate`, and `CommitmentSavingsMonthToDate`, together with `Currency` and `Period`.

The AHB estimate is separate: `AHBSavingsMonthly` represents 730 hours for the current VM inventory in USD, using a retail Windows license premium or a USD 50 per-VM fallback. `AHBCurrency` and `AHBPeriod` identify those units. The scan doesn't combine these amounts or annualize them. The legacy `RISavingsMonthly`, `SPSavingsMonthly`, `TotalMonthly`, and `TotalAnnual` fields remain present but are empty.

### Monitoring

| Scan           | What it finds                     |
| -------------- | --------------------------------- |
| Budget Status  | Budget consumption vs. thresholds |
| Anomaly Alerts | Recent cost anomaly detections    |

### Sustainability

| Scan           | What it finds                                                                               |
| -------------- | ------------------------------------------------------------------------------------------- |
| Carbon Metrics | Cloud carbon emissions, month-over-month change, 12-month trend, per-subscription breakdown |

### Advisor & Account

| Scan                | What it finds                            |
| ------------------- | ---------------------------------------- |
| Optimization Advice | Azure Advisor cost recommendations       |
| Billing Structure   | Account hierarchy and enrollment details |
| Contract Info       | Agreement type, offer, support plan      |

## FinOps KPI coverage

The scan modules map directly to [FinOps Foundation KPIs](https://www.finops.org/finops-kpis/). Each scan answers a KPI question directly, and the `finops-multitool` agent skill routes a natural-language question to the matching investigation. A few examples of question → output:

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

Legacy % = 47 ÷ total resources in scope.

### Cost per Gigabyte Stored / Hourly Cost per CPU Core → unit economics

> "What's my cost per vCPU and per GB of storage this month?"

```text
Unit Economics — Month to Date (USD)

Compute  $128,400 (75.7%)   312 VMs / 1,840 vCPU / 7,360 GB RAM
Storage  $ 41,200 (24.3%)   126,400 GB (84,600 GB disk + 41,800 GB blob/file)

  Cost per vCPU      $69.78 / month
  Cost per GB RAM    $17.45 / month
  Cost per VM        $411.54 / month
  Cost per GB stored $0.326 / month
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

#### Environment variables

| Variable               | Effect                                                                                                                                      | Default               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `FINOPS_HUB_KUSTO_URI` | Kusto cluster query URI. An `https://...kusto.windows.net` cluster (token auth) or `http://localhost:<port>` ftklocal emulator (anonymous). | unset (auto-discover) |
| `FINOPS_HUB_KUSTO_DB`  | Hub database name.                                                                                                                          | `Hub`                 |

The tool loads hub summaries or storage rows once per run and reuses them for supported scans. It reports a failed query against the selected hub as an error and doesn't silently replace the result with API data.

## Scripting (non-interactive)

The scan modules can be called directly without the TUI:

```powershell
Import-Module .\FinOpsMultitool.psm1

# Run a single scan
$tags = Get-TagInventory -Subscriptions $subs -TenantId $tid

# Read Hub data and convert
$hubData = Read-FinOpsHubData -StorageAccountName 'myhub' -ResourceGroupName 'rg-hub' -Months 1
$tagInventory = ConvertTo-TagInventoryFromHub -HubData $hubData
$costByTag = ConvertTo-CostByTagFromHub -HubData $hubData -ExistingTags $tagInventory.TagNames
```

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
