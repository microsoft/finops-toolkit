---
title: Start-FinOpsMultitool command
description: Launch the FinOps multitool interactive terminal UI to scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 09/20/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Start-FinOpsMultitool command in the FinOpsToolkit module.
---

<!-- markdownlint-disable -->

# Start-FinOpsMultitool command

The **Start-FinOpsMultitool** command launches the FinOps multitool interactive terminal UI (TUI). The tool authenticates to Azure, discovers accessible subscriptions, and runs the scan modules you select. Scans cover cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

Results appear in the terminal and are saved automatically on the machine running the command. Each run creates a private folder with one CSV file per selected scan, a `FinOpsReport.html` summary, and a `ScanSummary.txt` file. Failed or empty scans have a CSV status record. The scans don't change Azure resources.

The command requires PowerShell 7 or later and the `Az.Accounts`, `Az.ResourceGraph`, and `Az.Storage` modules. Validation for this change was performed on Windows; native macOS/Linux behavior and the `dotnet restore` path haven't been exercised.

Most scans need Reader or Cost Management Reader access on the target scope. Account scans (billing structure, contract info, and MACC commitment) also need agreement-specific billing access: [Billing account reader or Billing profile reader for a Microsoft Customer Agreement](/azure/cost-management-billing/manage/understand-mca-roles), or [Enterprise Administrator (read only) for an Enterprise Agreement](/azure/cost-management-billing/manage/understand-ea-roles). Grant access at the scope the scan reads. Commitment utilization reads at billing account or billing profile scope, so it needs that same billing access. The carbon scan needs Reader or Carbon Optimization Reader assigned at the subscription. Carbon emissions permissions don't apply at resource group or resource scope.

The tool prompts for each choice by default. To run it from a pipeline or a scheduled job, use `-NonInteractive` and supply the choices as parameters.

`-NonInteractive` requires an existing Azure context. Authenticate with the intended identity using `Connect-AzAccount` before launching the scan. Without a context, the command fails before scanning instead of starting interactive sign-in.

<br>

## Syntax

```powershell
Start-FinOpsMultitool `
    [-SubscriptionId <string>] `
    [-OutputPath <string>] `
    [-Scans <string[]>] `
    [-DataSource <string>] `
    [-NonInteractive] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name              | Description                                                                                                                                                                                                                                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `‑SubscriptionId` | Optional. Scopes the scan to a single subscription. When omitted, all accessible subscriptions are discovered. If the subscription can't be resolved and nothing can answer a prompt, the command returns an error rather than scanning every subscription.                                                                                            |
| `‑OutputPath`     | Optional. Local parent folder for reports. Defaults to `FinOpsToolkit/Multitool/Reports` under the current user's local application data. Each run creates a new timestamped subfolder. Git repositories, UNC paths, mapped Windows network drives, symbolic links, and junctions aren't accepted. Unix network mounts aren't detected.                |
| `‑Scans`          | Optional. Runs the specified scans instead of the default selection. Accepts a scan command name, such as `Get-OrphanedResources`, or its menu label, such as `Orphaned Resources`. Use `All` on its own to select every menu scan, including Billing Structure. An unrecognized name returns an error.                                                |
| `‑DataSource`     | Optional. Sets the data source and skips the data source prompt. Valid values are `Hub`, `API`, and `GraphOnly`. `API` and `GraphOnly` take precedence over `FINOPS_HUB_KUSTO_URI` and don't preload hub data. An explicit `Hub` selection fails if no configured Kusto endpoint or hub storage is available. Select `API` separately for a live scan. |
| `‑NonInteractive` | Optional. Runs without prompting and requires an existing authenticated Azure context. Every choice comes from the parameters or their defaults. Reports are saved automatically, even when `-OutputPath` is omitted.                                                                                                                                  |

<br>

## Examples

The following examples demonstrate how to use the Start-FinOpsMultitool command.

### Launch the multitool

```powershell
Start-FinOpsMultitool
```

Launches the terminal UI. You're prompted to authenticate, select a tenant if needed, and choose the subscriptions and modules to scan.

### Scope to a single subscription

```powershell
Start-FinOpsMultitool -SubscriptionId '00000000-0000-0000-0000-000000000000'
```

Launches the terminal UI scoped to a single subscription.

### Choose a local report folder

```powershell
Start-FinOpsMultitool -OutputPath (Join-Path $HOME 'FinOpsReports')
```

Launches the terminal UI and saves reports in a new run subfolder under the specified local folder. Choose a location outside Git repositories and synced folders.

### Run specific scans without prompting

Authenticate with the intended identity first. Then run:

```powershell
Start-FinOpsMultitool `
    -NonInteractive `
    -SubscriptionId '00000000-0000-0000-0000-000000000000' `
    -Scans Get-OrphanedResources, Get-IdleVMs `
    -DataSource API
```

Runs two scans against one subscription without prompting and saves all report formats in the default local folder. Use this form from a pipeline or a scheduled job.

<br>

## Report storage

The default parent folder is `FinOpsToolkit/Multitool/Reports` under `[Environment]::GetFolderPath('LocalApplicationData')`. On Windows, that's usually `%LOCALAPPDATA%\FinOpsToolkit\Multitool\Reports`. The command prints the full path for each run. Reports never overwrite an earlier run.

The tool creates the run folder with permissions restricted to the current user. It rejects Git repositories, UNC paths, mapped Windows network drives, symbolic links, and junctions, and includes an ignore-all `.gitignore` to reduce accidental staging. Unix network mounts aren't detected, so choose a path on a local filesystem. If saving fails, the command reports the error and retains results in `$FinOpsResults`. It doesn't silently use the current directory instead.

Reports are plaintext, not encrypted, and can contain sensitive cost and resource details. The tool doesn't upload them. Keep custom folders outside cloud-sync locations, protect access to your account, and follow your organization's retention policy. Administrators and processes running as your account can still access the files. Moving or force-adding reports to Git bypasses these safeguards.

<br>

## Terminal support

The tool uses arrow-key menus when the console supports them. Consoles that can't drive those menus, such as PowerShell remoting sessions and some editor terminals, automatically fall back to numbered prompts that read one line at a time. Both paths run the same scans and produce the same results.

Use `-NonInteractive` when nothing can answer a prompt, such as a build agent.

## Resource Graph only

`-DataSource GraphOnly` removes scans that require cost data, including budget history, AI workload metrics, unit economics, and MACC. Dependencies can't re-enable those scans, and orphan cost enrichment is skipped. The remaining scans can still call Azure Monitor metrics, Advisor, policy, and carbon APIs; the option doesn't restrict every request to Azure Resource Graph.

<br>

## FinOps hub data paths

When you select [FinOps Hub](../../hubs/finops-hubs-overview.md), the tool prefers the configured or discovered Kusto database. Kusto aggregates the data and returns summaries without loading raw cost records into PowerShell. To query a local hub, set `FINOPS_HUB_KUSTO_URI` to its endpoint. A configured endpoint doesn't require a discovered storage account. When no Kusto endpoint is configured or discovered, the tool reads hub storage exports, which is intended for smaller datasets. A failed query remains an error; it doesn't silently switch sources. For more information, see [FinOps multitool commands](finops-multitool-commands.md).

Reading Parquet exports prepares a pinned reader using NuGet on Windows and .NET SDK 8 or later on macOS and Linux. Package signatures and hashes are checked before loading cached assemblies. An unavailable verifier leaves the cache unloaded but intact. If the reader can't be prepared, the tool warns you with the reason and attempts the hub's `msexports` CSV instead of normalized Parquet data. A failed export read remains an error, not zero cost.

<br>

## Related content

Related solutions:

- [FinOps multitool commands](finops-multitool-commands.md)
- [FinOps toolkit PowerShell module](../powershell-commands.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
