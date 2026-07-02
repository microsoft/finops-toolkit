---
title: Start-FinOpsMultitool command
description: Launch the FinOps Multitool interactive terminal UI to scan an Azure environment for cost optimization, governance, and FinOps insights.
author: z-larsen
ms.author: zlarsen
ms.date: 07/02/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Start-FinOpsMultitool command in the FinOpsToolkit module.
---

# Start-FinOpsMultitool command

The **Start-FinOpsMultitool** command launches the FinOps Multitool interactive terminal UI (TUI). The tool authenticates to Azure, discovers accessible subscriptions, and runs the scan modules you select—covering cost trends, orphaned resources, idle VMs, tag hygiene, reservation and savings plan utilization, Azure Hybrid Benefit opportunities, budgets, anomaly alerts, and policy compliance.

Results are rendered in the terminal with export options for Excel, CSV, JSON, and Power BI. The scan modules are read-only.

The command runs on PowerShell 7+ (cross-platform) and requires the `Az.Accounts`, `Az.ResourceGraph`, and `Az.Storage` modules with at least Reader access on the target scope.

<br>

## Syntax

```powershell
Start-FinOpsMultitool `
    [-SubscriptionId <string>] `
    [-OutputPath <string>] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name              | Description                                                                                                    |
| ----------------- | -------------------------------------------------------------------------------------------------------------- |
| `‑SubscriptionId` | Optional. Scopes the scan to a single subscription. When omitted, all accessible subscriptions are discovered. |
| `‑OutputPath`     | Optional. Directory for exported result files. Defaults to the tool's working folder.                          |

<br>

## Examples

The following examples demonstrate how to use the Start-FinOpsMultitool command.

### Launch the Multitool

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

<br>

## FinOps Hub data paths

When a [FinOps hub](../../hubs/finops-hubs-overview.md) is present, choosing the **FinOps Hub** data source prefers the hub's Azure Data Explorer or Microsoft Fabric Kusto database—aggregation is pushed into the engine and only summarized results are returned, so large hubs are never loaded into PowerShell. To query a local hub on your own hardware, set `FINOPS_HUB_KUSTO_URI` to a local Kusto endpoint. When no Kusto cluster is reachable, the Multitool falls back to reading the hub storage export, which is intended for smaller datasets. For more information, see [FinOps Multitool commands](finops-multitool-commands.md).

<br>

## Related content

Related solutions:

- [FinOps Multitool commands](finops-multitool-commands.md)
- [FinOps toolkit PowerShell module](../powershell-commands.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
