# FinOps Multitool — Terminal UI (TUI)

Interactive terminal interface for running FinOps scans against Azure subscriptions. No GUI dependencies — works in any terminal on Windows, macOS, and Linux.

## Quick Start

```powershell
# From the FinOpsMultitool directory
Import-Module .\FinOpsMultitool.psm1
Invoke-FinOpsMultitool
```

Or target a specific subscription:

```powershell
Invoke-FinOpsMultitool -SubscriptionId '2693c348-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

## Requirements

| Requirement           | Details                                                         |
| --------------------- | --------------------------------------------------------------- |
| PowerShell            | 5.1+ (Windows) or 7+ (cross-platform)                           |
| Az modules            | `Az.Accounts`, `Az.Resources`, `Az.ResourceGraph`, `Az.Storage` |
| Azure RBAC            | Reader + Cost Management Reader on target scope                 |
| FinOps Hub (optional) | Storage Blob Data Reader on Hub storage account                 |

Install Az modules if needed:

```powershell
Install-Module Az.Accounts, Az.Resources, Az.ResourceGraph, Az.Storage -Scope CurrentUser
```

## How It Works

### 1. Authentication

On launch, the TUI checks for an existing `Az.Accounts` session. If you're not logged in, it prompts you to run `Connect-AzAccount`. If your account has access to multiple Azure AD tenants, a tenant picker appears so you can select which tenant to scan. It then discovers all accessible subscriptions and lets you select which ones to scan.

### 2. Data Source Selection

If a FinOps Hub is detected in any of your subscriptions, you'll be asked to choose a data source:

| Source                  | Description                                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **FinOps Hub**          | Reads pre-exported FOCUS cost data from Hub storage. Faster, no API throttling. Tag and cost-by-tag scans are instant.   |
| **Cost Management API** | Queries the Cost Management REST API in real-time. Slower but always current. Hub tag data is still used when available. |
| **Resource Graph only** | Skips all cost APIs. Only runs scans that use Azure Resource Graph (orphaned resources, idle VMs, etc).                  |

### 3. Scan Selection

Arrow-key driven menu to toggle individual scans on/off. All scans are selected by default except Billing Structure.

| Key       | Action             |
| --------- | ------------------ |
| `↑` / `↓` | Navigate scan list |
| `Space`   | Toggle scan on/off |
| `A`       | Select all         |
| `N`       | Deselect all       |
| `Enter`   | Run selected scans |
| `Q`       | Quit               |

### 4. Scan Execution

Selected scans run sequentially with a progress bar. When a FinOps Hub is available, tag-related scans (Tag Inventory, Cost by Tag) use pre-loaded Hub data instead of API calls — completing in under a second.

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

An optional CSV/JSON export saves to the output path.

## Required Permissions

Each scan module requires specific Azure RBAC roles. The TUI will tell you which role is needed if a scan fails due to missing permissions.

| Category     | Scans                                                             | Required Role              | Scope                        |
| ------------ | ----------------------------------------------------------------- | -------------------------- | ---------------------------- |
| Optimization | Orphaned Resources, Idle VMs, Storage Tier Advice, AHB            | Reader                     | Subscription                 |
| Governance   | Tag Inventory, Tag Recommendations, Policy Inventory/Recs         | Reader                     | Subscription                 |
| Cost         | Cost Data, Resource Costs, Cost by Tag, Cost Trend                | Cost Management Reader     | Subscription or MG           |
| Commitments  | Reservation Advice, Commitment Utilization, Savings Realized      | Cost Management Reader     | Subscription                 |
| Monitoring   | Budget Status, Anomaly Alerts                                     | Cost Management Reader     | Subscription                 |
| Advisor      | Optimization Advice                                               | Reader                     | Subscription                 |
| Account      | Billing Structure, Contract Info                                  | Billing Reader             | Billing Account              |
| Hub (opt.)   | All scans via Hub data                                            | Storage Blob Data Reader   | Hub Storage Account          |

## Available Scans

### Optimization (Resource Graph)

| Scan                | What it finds                                  |
| ------------------- | ---------------------------------------------- |
| Orphaned Resources  | Unattached disks, NICs, public IPs, NSGs       |
| Idle VMs            | VMs with <5% CPU over 30 days                  |
| Storage Tier Advice | Blob storage that could move to cooler tiers   |
| AHB Opportunities   | Windows/SQL VMs not using Azure Hybrid Benefit |

### Governance

| Scan                   | What it finds                                             |
| ---------------------- | --------------------------------------------------------- |
| Tag Inventory          | All tags across resources — names, values, coverage %     |
| Tag Recommendations    | Inconsistent casing, similar names, missing standard tags |
| Policy Inventory       | Azure Policy assignments with scope and compliance        |
| Policy Recommendations | Gaps in policy coverage for cost governance               |

### Cost Analysis

| Scan           | What it finds                     |
| -------------- | --------------------------------- |
| Cost Data      | Monthly spend per subscription    |
| Resource Costs | Top resources by cost             |
| Cost by Tag    | Spend breakdown by tag key/value  |
| Cost Trend     | Month-over-month spend comparison |

### Commitments

| Scan                   | What it finds                            |
| ---------------------- | ---------------------------------------- |
| Reservation Advice     | RI purchase recommendations from Advisor |
| Commitment Utilization | RI and Savings Plan usage rates          |
| Savings Realized       | Actual savings from existing commitments |

### Monitoring

| Scan           | What it finds                     |
| -------------- | --------------------------------- |
| Budget Status  | Budget consumption vs. thresholds |
| Anomaly Alerts | Recent cost anomaly detections    |

### Advisor & Account

| Scan                | What it finds                            |
| ------------------- | ---------------------------------------- |
| Optimization Advice | Azure Advisor cost recommendations       |
| Billing Structure   | Account hierarchy and enrollment details |
| Contract Info       | Agreement type, offer, support plan      |

## FinOps Hub Integration

When a Hub is detected, the TUI automatically loads FOCUS cost data from the Hub's storage account. This enables:

- **Instant tag scans** — Tag Inventory and Cost by Tag read directly from Hub CSV/parquet data instead of querying the Cost Management API
- **No API throttling** — Hub data is read from Azure Storage, avoiding Cost Management API rate limits
- **Richer tag data** — Hub exports contain the full Tags JSON per cost record, enabling accurate per-resource tag parsing
- **Forecast enrichment** — Hub data contains actuals only, so the TUI calls the Cost Management Forecast API to project full-month costs and adds them to Hub actuals
- **Accurate tag coverage** — Hub only sees resources with cost data. The TUI queries Azure Resource Graph for the true total/untagged resource count and overrides the Hub-derived coverage percentage

Hub data is loaded once at startup and reused across all scans that need it.

## Scripting (Non-Interactive)

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

## File Structure

```
FinOpsMultitool/
├── README.md                  # This file
├── FinOpsMultitool.psm1       # Module loader (dot-sources all scan modules)
├── Invoke-FinOpsMultitool.ps1 # TUI entry point
├── Start-FinOpsMultitool.ps1  # GUI entry point (WPF/XAML, Windows only)
├── modules/
│   ├── helpers/
│   │   ├── Read-FinOpsHubData.ps1          # Hub storage reader + converters
│   │   ├── Get-PlainAccessToken.ps1        # Token helper
│   │   ├── Invoke-AzRestMethodWithRetry.ps1 # REST retry logic
│   │   ├── Search-AzGraphSafe.ps1          # ARG query wrapper
│   │   └── MgCostScope.ps1                 # Management group scope state
│   ├── Initialize-Scanner.ps1
│   ├── Get-CostData.ps1
│   ├── Get-ResourceCosts.ps1
│   ├── Get-TagInventory.ps1
│   ├── Get-CostByTag.ps1
│   ├── Get-OrphanedResources.ps1
│   ├── Get-IdleVMs.ps1
│   └── ...                    # One file per scan module
└── gui/                       # WPF/XAML assets for GUI mode
```
