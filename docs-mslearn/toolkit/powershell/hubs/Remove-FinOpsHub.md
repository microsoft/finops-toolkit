---
title: Remove-FinOpsHub command
description: Remove a FinOps hub instance.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what New-FinOpsHub command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Remove-FinOpsHub command

The **Remove-FinOpsHub** command removes a FinOps hub instance and optionally keep the storage account hosting cost data.

The comamnd returns a boolean value indicating whether all resources were successfully deleted.

<br>

## Syntax

```powershell
Remove-FinOpsHub `
    [-Name] <string> `
    [-ResourceGroup <string>] `
    [-KeepStorageAccount]
```

```powershell
Remove-FinOpsHub `
    [-InputObject] <PSObject> `
    [-KeepStorageAccount]
```

<br>

## Parameters

| Name                  | Description                                                                                     |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `‑Name`               | Required. Name of the FinOps hub instance.                                                      |
| `‑InputObject`        | Required when specifying InputObject. Expected object is the output of Get-FinOpsHub.           |
| `‑ResourceGroup`      | Optional when specifying Name. Resource Group Name for the FinOps Hub.                          |
| `‑KeepStorageAccount` | Optional. Indicates that the storage account associated with the FinOps Hub should be retained. |

<br>

## Examples

### Remove a FinOps hub instance

```powershell
Remove-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyRG `
    -KeepStorageAccount
```

Deletes a FinOps Hub named MyHub and deletes all associated resource except the storage account.

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
