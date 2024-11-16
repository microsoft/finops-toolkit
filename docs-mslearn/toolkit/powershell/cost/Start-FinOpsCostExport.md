---
title: Start-FinOpsCostExport command
description: Initiate a Cost Management export run for the most recent period using the Start-FinOpsCostExport command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Start-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Start-FinOpsCostExport command

The **Start-FinOpsCostExport** command runs a Cost Management export for the most recent period using the Run API.

This command was tested with the following API versions:

- **2023-07-01-preview (default)** – Enables FocusCost and other datasets.
- **2023-08-01**

<br>

## Syntax

```powershell
Start-FinOpsCostExport `
    [-Name] <string> `
    [-Scope <string>] `
    [-StartDate <datetime>] `
    [-EndDate <datetime>] `
    [-Backfill <number>] `
    [-ApiVersion <string>]
```

<br>

## Parameters

| Name          | Description                                                                                                                                                                                                                  |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`       | Required. Name of the export.                                                                                                                                                                                                |
| `‑Scope`      | Optional. Resource ID of the scope to export data for. If empty, defaults to current subscription context.                                                                                                                   |
| `‑StartDate`  | Optional. Day to start pulling the data for. If not set, the export uses the dates defined in the export configuration.                                                                                                  |
| `‑EndDate`    | Optional. Last day to pull data for. If not set and -StartDate is set, -EndDate uses the last day of the month. If not set and -StartDate isn't set, the export uses the dates defined in the export configuration. |
| `‑Backfill`   | Optional. Number of months to export the data for. Make note of throttling (429) errors. It only runs once. Failed exports aren't reattempted. Default = 0.                                                            |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview.                                                                                                                     |

<br>

## Examples

The following examples demonstrate typical usage of this command.

### Export configured period

```powershell
Start-FinopsCostExport -Name 'CostExport'
```

Runs an export called 'CostExport' for the configured period.

### Export specific dates

```powershell
Start-FinopsCostExport -Name 'CostExport' -StartDate '2023-01-01' -EndDate '2023-12-31'
```

Runs an export called 'CostExport' for a specific date range.

### Backfill export

```powershell
Start-FinopsCostExport -Name 'CostExport' -Backfill 12
```

Runs an export called 'CostExport' for the previous 12 months.

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
