---
title: Start-FinOpsMultitool command
description: Launch the FinOps multitool interactive terminal UI to scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 09/18/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Start-FinOpsMultitool command in the FinOpsToolkit module.
---

<!-- markdownlint-disable -->

# Start-FinOpsMultitool command

The **Start-FinOpsMultitool** command launches the FinOps multitool interactive terminal UI (TUI). The tool authenticates to Azure, discovers accessible subscriptions, and runs the scan modules you select. Scans cover cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

Results are rendered in the terminal. When you choose to export, the tool writes a CSV file per scan module, a `FinOpsReport.html` summary, and a `ScanSummary.txt` file. The scan modules are read-only.

The command requires PowerShell 7 or later on Windows, macOS, and Linux. It requires the `Az.Accounts`, `Az.ResourceGraph`, and `Az.Storage` modules. Most scans need Reader or Cost Management Reader access on the target scope. Account scans (billing structure, contract info, and MACC commitment) also need Billing Reader, or Enterprise Administrator (reader) on an Enterprise Agreement. Commitment utilization reads at billing account or billing profile scope, so it needs that same billing access. The carbon scan needs Reader or Carbon Optimization Reader assigned at the subscription. Carbon emissions permissions don't apply at resource group or resource scope.

The tool prompts for each choice by default. To run it from a pipeline or a scheduled job, use `-NonInteractive` and supply the choices as parameters.

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
| `‑OutputPath`     | Optional. Directory for exported result files. Defaults to a `FinOpsResults` folder in your home directory.                                                                                                                                                                                                                                            |
| `‑Scans`          | Optional. Runs the specified scans instead of the default selection. Accepts a scan command name, such as `Get-OrphanedResources`, or its menu label, such as `Orphaned Resources`. Use `All` to select every scan. An unrecognized name returns an error.                                                                                             |
| `‑DataSource`     | Optional. Sets the data source and skips the data source prompt. Valid values are `Hub`, `API`, and `GraphOnly`. `API` and `GraphOnly` take precedence over `FINOPS_HUB_KUSTO_URI` and don't preload hub data. An explicit `Hub` selection fails if no configured Kusto endpoint or hub storage is available. Select `API` separately for a live scan. |
| `‑NonInteractive` | Optional. Runs without prompting. Every choice comes from the parameters or their defaults, and results are exported only when you set `-OutputPath`.                                                                                                                                                                                                  |

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

### Set an output path for exports

```powershell
Start-FinOpsMultitool -OutputPath './finops-results'
```

Launches the terminal UI and writes exported result files to the specified directory.

### Run specific scans without prompting

```powershell
Start-FinOpsMultitool `
    -NonInteractive `
    -SubscriptionId '00000000-0000-0000-0000-000000000000' `
    -Scans Get-OrphanedResources, Get-IdleVMs `
    -DataSource API `
    -OutputPath './finops-results'
```

Runs two scans against one subscription without prompting and writes the results to the specified directory. Use this form from a pipeline or a scheduled job.

<br>

## Terminal support

The tool uses arrow-key menus when the console supports them. Consoles that can't drive those menus, such as PowerShell remoting sessions and some editor terminals, automatically fall back to numbered prompts that read one line at a time. Both paths run the same scans and produce the same results.

Use `-NonInteractive` when nothing can answer a prompt, such as a build agent.

<br>

## FinOps hub data paths

When you select [FinOps Hub](../../hubs/finops-hubs-overview.md), the tool prefers the configured or discovered Kusto database. Kusto aggregates the data and returns summaries without loading raw cost records into PowerShell. To query a local hub, set `FINOPS_HUB_KUSTO_URI` to its endpoint. A configured endpoint doesn't require a discovered storage account. When no Kusto endpoint is configured or discovered, the tool reads hub storage exports, which is intended for smaller datasets. A failed query remains an error; it doesn't silently switch sources. For more information, see [FinOps multitool commands](finops-multitool-commands.md).

Reading Parquet exports installs a reader the first time you read one, using NuGet on Windows and .NET SDK 8 or later on macOS and Linux. An unreadable export is reported as an error instead of being treated as zero cost.

<br>

## Related content

Related solutions:

- [FinOps multitool commands](finops-multitool-commands.md)
- [FinOps toolkit PowerShell module](../powershell-commands.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
