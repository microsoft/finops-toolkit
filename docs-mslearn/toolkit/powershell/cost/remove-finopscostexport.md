---
title: Remove-FinOpsCostExport command
description: Delete a Cost Management export and optionally data associated with the export using the Remove-FinOpsCostExport command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 08/27/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Remove-FinOpsCostExport command in the FinOpsToolkit module.
---

# Remove-FinOpsCostExport command

The **Remove-FinOpsCostExport** command deletes a Cost Management export and optionally deletes all data associated with the export from the related storage account.

This command was tested with the following API versions:

- 2025-03-01 (default) – GA version for FocusCost and other datasets.
- 2023-07-01-preview
- 2023-08-01
- 2023-03-01

<br>

## Syntax

```powershell
Remove-FinOpsCostExport `
    [‑Name] <string> `
    [‑Scope] <string> `
    [‑RemoveData] `
    [[‑ApiVersion] <string>] `
    [‑WhatIf] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name          | Description                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `‑Name`       | Required. Name of the Cost Management export to delete.                                          |
| `‑Scope`      | Required. Resource ID of the scope to export data for.                                           |
| `‑RemoveData` | Optional. Indicates that all cost data associated with the Export scope should be deleted.       |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01. |
| `‑WhatIf`     | Optional. Shows what would happen if the command runs without actually running it.               |

<br>

## Examples

### Delete a Cost Management export

```powershell
Remove-FinOpsCostExport -Name MyExport -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" -RemoveData
```

Deletes a Cost Management export and removes the exported data from the linked storage account.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/CostManagement.RemoveExport)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
