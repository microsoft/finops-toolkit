---
title: Remove-FinOpsHub command
description: Remove a FinOps hub instance using the Remove-FinOpsHub command in the FinOpsToolkit module, with an option to keep the storage account hosting cost data.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what New-FinOpsHub command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Remove-FinOpsHub command

The **Remove-FinOpsHub** command removes a FinOps hub instance and optionally keep the storage account hosting cost data.

The command returns a boolean value indicating whether all resources were successfully deleted.

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
| `‑ResourceGroup`      | Optional when specifying Name. Resource Group Name for the FinOps hub.                          |
| `‑KeepStorageAccount` | Optional. Indicates that the storage account associated with the FinOps hub should be retained. |

<br>

## Examples

The following example demonstrates how to use the Remove-FinOpsHub command to delete a FinOps hub instance.

### Remove a FinOps hub instance

```powershell
Remove-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyRG `
    -KeepStorageAccount
```

Deletes a FinOps hub named MyHub and deletes all associated resource except the storage account.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.12/bladeName/PowerShell/featureName/Hubs.RemoveHub)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
