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

| Category     | Scans                                                        | Required Role            | Scope               |
| ------------ | ------------------------------------------------------------ | ------------------------ | ------------------- |
| Optimization | Orphaned Resources, Idle VMs, Storage Tier Advice, AHB       | Reader                   | Subscription        |
| Governance   | Tag Inventory, Tag Recommendations, Policy Inventory/Recs    | Reader                   | Subscription        |
| Cost         | Cost Data, Resource Costs, Cost by Tag, Cost Trend           | Cost Management Reader   | Subscription or MG  |
| Commitments  | Reservation Advice, Commitment Utilization, Savings Realized | Cost Management Reader   | Subscription        |
| Monitoring   | Budget Status, Anomaly Alerts                                | Cost Management Reader   | Subscription        |
| Advisor      | Optimization Advice                                          | Reader                   | Subscription        |
| Account      | Billing Structure, Contract Info                             | Billing Reader           | Billing Account     |
| Hub (opt.)   | All scans via Hub data                                       | Storage Blob Data Reader | Hub Storage Account |

## Available Scans

### Optimization (Resource Graph)

| Scan                | What it finds                                                         |
| ------------------- | --------------------------------------------------------------------- |
| Orphaned Resources  | Unattached disks, NICs, public IPs, NSGs                              |
| Idle VMs            | VMs with <5% CPU over 30 days                                         |
| Storage Tier Advice | Blob storage that could move to cooler tiers                          |
| AHB Opportunities   | Windows/SQL VMs not using Azure Hybrid Benefit                        |
| Legacy Resources    | Legacy/retiring SKUs (v1 VM families, unmanaged disks, Basic IPs/LBs) |

### Governance

| Scan                   | What it finds                                             |
| ---------------------- | --------------------------------------------------------- |
| Tag Inventory          | All tags across resources — names, values, coverage %     |
| Tag Recommendations    | Inconsistent casing, similar names, missing standard tags |
| Policy Inventory       | Azure Policy assignments with scope and compliance        |
| Policy Recommendations | Gaps in policy coverage for cost governance               |

### Cost Analysis

| Scan           | What it finds                            |
| -------------- | ---------------------------------------- |
| Cost Data      | Monthly spend per subscription           |
| Resource Costs | Top resources by cost                    |
| Cost by Tag    | Spend breakdown by tag key/value         |
| Cost Trend     | Month-over-month spend comparison        |
| Unit Economics | Cost per vCPU, per VM, and per GB stored |

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

## FinOps KPI Coverage

The scan modules map directly to [FinOps Foundation KPIs](https://www.finops.org/finops-kpis/). When using the MCP server, you ask in natural language and the agent calls the matching tool. A few examples of prompt → output:

### Percentage of Legacy Resource → `scan_legacy_resources`

> "Which of my resources are running on legacy or retiring SKUs?"

```
Legacy / Retiring Resources — 47 found across 156 subscriptions

By category:
  Legacy v1 VM families        18   (Basic_A / Standard_A0-A7 / D / DS / G)
  Unmanaged VHD disks           9   (migrate to managed disks)
  HDD Standard_LRS ≥128GB      11   (upgrade to Premium SSD)
  Basic SKU Public IPs          6   (retiring Sep 2025 → Standard)
  Basic SKU Load Balancers      3   (retiring Sep 2025 → Standard)
```

Legacy % = 47 ÷ total resources in scope.

### Cost per Gigabyte Stored / Hourly Cost per CPU Core → `scan_unit_economics`

> "What's my cost per vCPU and per GB of storage this month?"

```
Unit Economics — Month to Date (USD)

Compute cost      $128,400      VMs: 312     Total vCPU: 1,840
Storage cost      $ 41,200      Provisioned: 84,600 GB

  Cost per vCPU     $69.78 / month
  Cost per VM       $411.54 / month
  Cost per GB       $0.487 / month
```

Directly produces `Cost per GB Stored`; feeds `Hourly Cost per CPU Core` (÷ 730) and `Effective Avg Compute Cost per Core`.

### Carbon per Unit of Spend / Carbon Efficiency → `scan_carbon`

> "Show my cloud carbon footprint and how it changed month over month."

```
Carbon Emissions — latest available month: 2026-04 (data lags ~2 mo)

Total emissions      18,420 kgCO2e
Previous month       20,110 kgCO2e
Change               -1,690 kgCO2e  (-8.4%)   ↓ improving

Top emitting subscriptions:
  Production-East   2693c348…   7,910 kgCO2e
  Data-Platform     a1b2c3d4…   4,330 kgCO2e
```

Combined with `scan_cost_data`, `Carbon per Unit of Spend` = total emissions ÷ monthly spend.

### Commitment Utilization Score / % Discount Waste → `scan_commitment_utilization`

> "How well are my reservations and savings plans being used?"

```
Commitment Utilization — trailing 30 days

Reserved Instances    94.2% utilized   ($3,120 unused)
Savings Plans         88.7% utilized   ($1,540 unused)
Overall score         91.8%
```

`Commitment Utilization Score` = 91.8%; `% Commitment Discount Waste` = 100 − 91.8 = 8.2%.

### % Costs from Untagged Resources → `scan_cost_by_tag`

> "How much of my spend is on untagged resources?"

```
Cost by Tag — Month to Date

Tagged spend       $612,300   (87.4%)
Untagged spend     $ 88,200   (12.6%)   ← KPI
```

`% Costs from Untagged Resources` = 12.6%.

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

## MCP Server (AI Integration)

The FinOps Multitool includes an MCP (Model Context Protocol) server that exposes all 23 scan modules — plus a `run_full_scan` composite (24 tools total) — as AI-callable tools. This lets Copilot, Claude, custom agents, and SRE automation call the same functions used by the TUI and GUI.

### Setup

For a standalone `.vscode/mcp.json` (workspace or user level), use a top-level `servers` block:

```json
{
  "servers": {
    "finops-multitool": {
      "type": "stdio",
      "command": "pwsh",
      "args": ["-NoProfile", "-File", "path/to/Start-McpServer.ps1"]
    }
  }
}
```

For VS Code `settings.json`, nest the same under an `mcp` key:

```json
{
  "mcp": {
    "servers": {
      "finops-multitool": {
        "type": "stdio",
        "command": "pwsh",
        "args": ["-NoProfile", "-File", "path/to/Start-McpServer.ps1"]
      }
    }
  }
}
```

### Available Tools

| Tool                          | Description                                       |
| ----------------------------- | ------------------------------------------------- |
| `scan_orphaned_resources`     | Find unattached disks, NICs, public IPs, NSGs     |
| `scan_idle_vms`               | Find VMs with <5% CPU over 14-30 days             |
| `scan_storage_tier_advice`    | Storage accounts that could use cooler tiers      |
| `scan_ahb_opportunities`      | VMs/SQL not using Azure Hybrid Benefit            |
| `scan_tag_inventory`          | Tag coverage %, tag names, resource counts        |
| `scan_tag_recommendations`    | Inconsistent casing, missing standard tags        |
| `scan_policy_inventory`       | Policy assignments with compliance status         |
| `scan_policy_recommendations` | Policy coverage gaps for cost governance          |
| `scan_cost_data`              | Actual + forecasted cost per subscription         |
| `scan_resource_costs`         | Top resources by cost (MTD)                       |
| `scan_cost_by_tag`            | Spend breakdown by tag key/value                  |
| `scan_cost_trend`             | Month-over-month spend comparison                 |
| `scan_reservation_advice`     | RI purchase recommendations                       |
| `scan_commitment_utilization` | RI and Savings Plan usage rates                   |
| `scan_savings_realized`       | Actual savings from commitments                   |
| `scan_budget_status`          | Budget consumption vs thresholds                  |
| `scan_anomaly_alerts`         | Recent cost anomaly detections                    |
| `scan_legacy_resources`       | Legacy/retiring SKUs needing modernization        |
| `scan_unit_economics`         | Cost per vCPU, per VM, and per GB stored          |
| `scan_carbon`                 | Cloud carbon emissions and month-over-month trend |
| `scan_optimization_advice`    | Azure Advisor cost recommendations                |
| `scan_billing_structure`      | Billing account hierarchy                         |
| `scan_contract_info`          | Agreement type, offer, support plan               |
| `run_full_scan`               | Run all modules — comprehensive assessment        |

### Resources

| URI                    | Description                         |
| ---------------------- | ----------------------------------- |
| `finops://permissions` | Required RBAC roles per scan module |
| `finops://modules`     | List of all available scan modules  |

### Architecture

```
AI Agent (Copilot / Claude / SRE Agent)
    │ MCP Protocol (stdio JSON-RPC)
    ▼
Start-McpServer.ps1
    │ Imports FinOpsMultitool.psm1
    ▼
Get-CostData, Get-TagInventory, etc.
    │ Same functions used by TUI and GUI
    ▼
Azure APIs (Cost Management, Resource Graph, Advisor, etc.)
```

## File Structure

```
FinOpsMultitool/
├── README.md                  # This file
├── FinOpsMultitool.psm1       # Module loader (dot-sources all scan modules)
├── Invoke-FinOpsMultitool.ps1 # TUI entry point
├── Start-FinOpsMultitool.ps1  # GUI entry point (WPF/XAML, Windows only)
├── Start-McpServer.ps1        # MCP server (AI integration, stdio JSON-RPC)
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
