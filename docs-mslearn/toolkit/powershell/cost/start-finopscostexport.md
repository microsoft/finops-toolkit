---
title: Start-FinOpsCostExport command
description: Initiate a Cost Management export run for the most recent period using the Start-FinOpsCostExport command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 06/21/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Start-FinOpsCostExport command in the FinOpsToolkit module.
---

# Start-FinOpsCostExport command

The **Start-FinOpsCostExport** command runs a Cost Management export for the most recent period using the Run API.

This command was tested with the following API versions:

- 2025-03-01 (default) – GA version for FocusCost and other datasets.
- 2023-07-01-preview
- 2023-08-01

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

| Name          | Description                                                                                                                                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`       | Required. Name of the export.                                                                                                                                                                                       |
| `‑Scope`      | Optional. Resource ID of the scope to export data for. If empty, defaults to current subscription context.                                                                                                          |
| `‑StartDate`  | Optional. Day to start pulling the data for. If not set, the export uses the dates defined in the export configuration.                                                                                             |
| `‑EndDate`    | Optional. Last day to pull data for. If not set and -StartDate is set, -EndDate uses the last day of the month. If not set and -StartDate isn't set, the export uses the dates defined in the export configuration. |
| `‑Backfill`   | Optional. Number of months to export the data for. Make note of throttling (429) errors. It only runs once. Failed exports aren't reattempted. Default = 0.                                                         |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01.                                                                                                                    |

<br>

## Examples

The following examples demonstrate typical usage of this command.

### Export configured period

```powershell
Start-FinopsCostExport -Name 'CostExport'
```

Runs an export called 'CostExport' for the configured period on the subscription configured in Get-AzContext.

### Export specific dates

```powershell
Start-FinopsCostExport -Scope '/providers/Microsoft.Billing/billingAccounts/1234' -Name 'CostExport' -StartDate '2023-01-01' -EndDate '2023-12-31'
```

Runs an export called 'CostExport' for a specific date range on the 1234 billing account.

### Backfill export

```powershell
Start-FinopsCostExport -Scope '/providers/Microsoft.Billing/billingAccounts/1234/billingProfiles/5678' -Name 'CostExport' -Backfill 12
```

Runs an export called 'CostExport' for the previous 12 months on the 5678 billing profile.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/CostManagement.StartExport)
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
