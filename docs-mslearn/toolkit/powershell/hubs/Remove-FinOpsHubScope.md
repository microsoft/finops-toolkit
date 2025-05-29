---
title: Remove-FinOpsHubScope command
description: Stops monitoring a scope within a FinOps hub instance and optionally remove the data using the Remove-FinOpsHubScope command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
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

The following examples demonstrate how to use the Remove-FinOpsHubScope command to stop monitoring a scope and optionally remove data.

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.10/bladeName/PowerShell/featureName/Hubs.RemoveScope)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
