---
title: Remove-FinOpsCostExport command
description: Delete a Cost Management export and optionally data associated with the export using the Remove-FinOpsCostExport command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Remove-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Remove-FinOpsCostExport command

The **Remove-FinOpsCostExport** command deletes a Cost Management export and optionally data associated with the export.

This command was tested with the following API versions:

- **2023-07-01-preview (default)** – Enables FocusCost and other datasets.
- **2023-08-01**
- **2023-03-01**

<br>

## Syntax

```powershell
Remove-FinOpsCostExport `
    -Name <string> `
    -Scope <string> `
    [-RemoveData <switch>] `
    [-ApiVersion <string>] `
```

<br>

## Parameters

| Name          | Description                                                                                          |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| `‑Name`       | Required. Name of the Cost Management export.                                                        |
| `‑Scope`      | Required. Resource ID of the scope to export data for context.                                       |
| `‑RemoveData` | Optional. Optional. Indicates that all cost data associated with the Export scope should be deleted. |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management exports API. Default = 2023-03-01.     |

<br>

## Examples

### Delete a Cost Management export

```powershell
Remove-FinOpsCostExport `
    -Name MyExport`
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"`
    -RemoveData
```

Deletes a Cost Management export and removes the exported data from the linked storage account.

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
