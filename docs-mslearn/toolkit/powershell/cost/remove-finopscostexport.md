---
title: Remove-FinOpsCostExport command
description: Delete a Cost Management export and optionally data associated with the export using the Remove-FinOpsCostExport command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 06/21/2025
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

- 2025-03-01 (default) – GA version for FocusCost and other datasets.
- 2023-07-01-preview
- 2023-08-01
- 2023-03-01

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
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management exports API. Default = 2025-03-01.     |

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/CostManagement.RemoveExport)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
