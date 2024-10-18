---
title: Remove-FinOpsHubScope command
description: Stops monitoring a scope within a FinOps hub instance.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Remove-FinOpsHubScope PowerShell command.
---

<!-- markdownlint-disable-next-line MD025 -->
# Remove-FinOpsHubScope command

The **Remove-FinOpsHubScope** command removes a scope from being monitored by a FinOps hub instance. Data related to that scope is kept by default. To remove the data, use the `-RemoveData` option.

<br>

## Syntax

```powershell
Remove-FinOpsHubScope `
    [-Id] <string> `
    -HubName <string>
    [-HubResourceGroupName <string>]
    [-RemoveData]
```

<br>

## Parameters

| Name                    | Description                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `‑Id`                   | Required resource ID of the scope to remove.                                            |
| `‑HubName`              | Required. Name of the FinOps hub instance.                                              |
| `‑HubResourceGroupName` | Optional. Name of the resource group the FinOps hub was deployed to.                    |
| `‑RemoveData`           | Optional. Indicates whether to remove data for this scope from storage. Default = false |

<br>

## Examples

### Remove billing account and keep data

```powershell
Remove-FinOpsHubScope -Id "/providers/Microsoft.Billing/billingAccounts/123" -HubName "FooHub"
```

Removes the exports configured to use the FooHub hub instance. Existing data is retained in the storage account.

### Remove subscription and historical data

```powershell
Remove-FinOpsHubScope -Id "/subscriptions/##-#-#-#-###" -HubName "FooHub" -RemoveData
```

Removes the exports configured to use the FooHub hub instance and removes data for that scope.

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
