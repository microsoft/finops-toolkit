---
title: Start-FinOpsMultitool command
description: Launche the Azure FinOps Multitool interactive terminal UI using the Start-FinOpsMultitool command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 11/23/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Start-FinOpsMultitool command in the FinOpsToolkit module.
---

# Start-FinOpsMultitool command

The **Start-FinOpsMultitool** command launches an interactive terminal UI (TUI) that
scans an Azure tenant for cost optimization, governance, and FinOps insights. The
tool authenticates to Azure, discovers subscriptions, and runs the scan modules you
select - covering cost trends, orphaned resources, idle VMs, tag hygiene, reservation
and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly
alerts, and policy compliance.

Results are rendered in the terminal and saved automatically on the machine running
the command. Each run gets a private folder with one CSV file per selected scan,
an HTML report, and a text summary. Failed or empty scans have a CSV status record.

The scan modules are read-only. The TUI requires PowerShell 7 or later on Windows,
macOS, and Linux, the Az modules (Az.Accounts,
Az.ResourceGraph, Az.Storage) and Reader access on the target scope.

Consoles that cannot drive the arrow-key menus, such as remoting sessions and some
editor terminals, automatically fall back to numbered prompts. Use Accessible to
select numbered prompts in any console, or NonInteractive to run with no prompts at all.

<br>

## Syntax

```powershell
Start-FinOpsMultitool `
    [[-SubscriptionId] <string>] `
    [[-OutputPath] <string>] `
    [[-Scans] <String[]>] `
    [[-DataSource] <string>] `
    [-NonInteractive] `
    [-Accessible] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name              | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑SubscriptionId` | Optional subscription ID in the current tenant. An unresolved or mismatched<br>subscription stops the scan without searching other tenants or widening scope.<br>When omitted, the tool discovers accessible subscriptions in the selected tenant.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `‑OutputPath`     | Optional local parent directory for reports. Each run creates a new timestamped<br>subfolder and never overwrites earlier reports. The default is FinOpsToolkit/Multitool/Reports<br>under the current user's LocalApplicationData directory, usually LOCALAPPDATA on Windows.<br>Git repositories, UNC paths, mapped Windows network drives, symbolic links, and<br>junctions are rejected. Unix network mounts aren't detected; choose a local filesystem.<br>Reports contain sensitive cost and resource data; keep custom destinations outside synced folders.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `‑Scans`          | Optional list of scans to run, replacing the default selection. Accepts either the<br>scan function name, such as Get-OrphanedResources, or its menu label, such as<br>'Orphaned Resources'. Use 'All' on its own to select every scan. An unrecognized name is an error.<br>Explicit null or empty lists, and empty entries, are rejected before the tool starts.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `‑DataSource`     | Optional data source, which skips the data source prompt. Hub reads a configured<br>Kusto endpoint or a discovered FinOps hub. Export discovers existing CSV/CSV.gz Cost<br>Management exports without requiring a hub, looking at definitions for the selected<br>subscriptions, their management-group ancestors, and linked billing accounts, and at<br>storage accounts in the selected subscriptions. A definition found at a wider scope can<br>deliver to storage outside the selected subscriptions, and that destination is read. It<br>reads one chosen export and filters rows to the selected subscriptions. ActualCost or FOCUS<br>BilledCost is required; Parquet and local-file input aren't supported on this path.<br>API queries Cost Management directly, and<br>GraphOnly skips cost-dependent scans and orphan cost enrichment; remaining scans can<br>still use Azure Monitor, Advisor, policy, and carbon APIs. API and GraphOnly ignore FINOPS_HUB_KUSTO_URI and<br>don't preload hub data. An explicit Hub selection fails if no hub source is available.<br>Select API separately to run a live scan. Export also ignores FINOPS_HUB_KUSTO_URI;<br>a failed export read never switches to live costs. NonInteractive Export requires<br>exactly one readable discovered candidate. Export mode supports cost totals, resource costs,<br>cost by tag, and the months present in that export run; separate financial API scans are excluded. |
| `‑NonInteractive` | Runs without prompting, for automation and scheduled jobs. Every choice comes from the<br>parameters or their defaults: all accessible subscriptions in the current tenant unless<br>SubscriptionId is set, a configured or detected hub or the Cost Management API unless DataSource is<br>set. Failed automatic hub discovery warns and continues to API in the same scope,<br>even when every probe fails. Explicit Hub selections never switch to API.<br>Requires an existing Azure context; authenticate with the intended identity using<br>Connect-AzAccount before running. Reports are saved automatically even when OutputPath is omitted.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `‑Accessible`     | Uses numbered prompts without clearing the screen or repainting menu rows, even in a<br>console that supports them. Stays in the signed-in tenant; sign in separately to change tenants.<br>NonInteractive takes precedence and disables all prompts when both switches are supplied.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

<br>

## Examples

### Example 1

```powershell
Start-FinOpsMultitool
```

Launches the FinOps Multitool TUI. You will be prompted to authenticate and
select the subscriptions and modules to scan.

### Example 2

```powershell
Start-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'
```

Launches the TUI scoped to a single subscription.

### Example 3

```powershell
Start-FinOpsMultitool -NonInteractive -Scans Get-OrphanedResources, Get-IdleVMs
```

Requires an existing authenticated Azure context. Runs two scans without prompting and saves CSV, HTML, and text reports in a new
private run folder under the current user's local application data.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Toolkit.StartMultitool)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
