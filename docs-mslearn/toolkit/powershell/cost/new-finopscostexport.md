---
title: New-FinOpsCostExport command
description: Create a new Cost Management export for the specified scope using the New-FinOpsCostExport command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 06/21/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what New-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# New-FinOpsCostExport command

The **New-FinOpsCostExport** command creates a new Cost Management export for the specified scope.

This command was tested with the following API versions:

- 2025-03-01 (default) – GA version for FocusCost and other datasets.
- 2023-07-01-preview
- 2023-08-01

<br>

## Syntax

```powershell
# Create a new daily/monthly export
New-FinOpsCostExport `
    [-Name] <string> `
    -Scope <string> `
    [-Dataset <string>] `
    [-DatasetVersion <string>] `
    [-DatasetFilters <hashtable>] `
    [-Monthly] `
    [-StartDate <DateTime>] `
    [-EndDate <DateTime>] `
    -StorageAccountId <string> `
    [-StorageContainer <string>] `
    [-StoragePath <string>] `
    [-Location] `
    [-DoNotPartition] `
    [-DoNotOverwrite] `
    [-Execute] `
    [-Backfill <int>] `
    [-ApiVersion <string>]
```

```powershell
# Create a new one-time export
New-FinOpsCostExport `
    [-Name] <string> `
    -Scope <string> `
    [-Dataset <string>] `
    [-DatasetVersion <string>] `
    [-DatasetFilters <hashtable>] `
    -OneTime `
    -StartDate <DateTime> `
    -EndDate <DateTime> `
    -StorageAccountId <string> `
    [-StorageContainer <string>] `
    [-StoragePath <string>] `
    [-Location] `
    [-DoNotPartition] `
    [-ApiVersion <string>]
```

<br>

## Parameters

| Name                              | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`                           | Required. Name of the export.                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑Scope`                          | Required. Resource ID of the scope to export data for.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `‑Dataset`                        | Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationRecommendations", "ReservationTransactions". Default = "FocusCost".                                                                                                                                                                                                                                                           |
| `‑DatasetVersion`                 | Optional. Schema version of the dataset to export. Default = "1.2-preview" (applies to FocusCost only).                                                                                                                                                                                                                                                                                                                                                                 |
| `‑DatasetFilters`                 | Optional. Dictionary of key/value pairs to filter the dataset with. Only applies to ReservationRecommendations dataset in 2023-07-01-preview or newer. Valid filters are reservationScope (Shared or Single), resourceType (for example, VirtualMachines), lookBackPeriod (Last7Days, Last30Days, Last60Days).                                                                                                                                                          |
| `‑CommitmentDiscountScope`        | Optional. Reservation scope filter to use when exporting reservation recommendations. Ignored for other export types. Allowed values: Shared, Single. Default: Shared.                                                                                                                                                                                                                                                                                                  |
| `‑CommitmentDiscountResourceType` | Optional. Reservation resource type filter to use when exporting reservation recommendations. Ignored for other export types. Default: VirtualMachines.                                                                                                                                                                                                                                                                                                                 |
| `‑CommitmentDiscountLookback`     | Optional. Reservation resource type filter to use when exporting reservation recommendations. Ignored for other export types. Allowed values: 7, 30, 60. Default: 30.                                                                                                                                                                                                                                                                                                   |
| `‑Monthly`                        | Optional. Indicates that the export should be executed monthly (instead of daily). Ignored for prices, reservation recommendations, and reservation transactions. Default = false.                                                                                                                                                                                                                                                                                      |
| `‑OneTime`                        | Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.                                                                                                                                                                                                                                                                                |
| `‑StartDate`                      | Optional. Day to start running exports. Default = First day of the previous month if -OneTime is set; otherwise, tomorrow (DateTime.Now.AddDays(1)).                                                                                                                                                                                                                                                                                                                    |
| `‑EndDate`                        | Optional. Last day to run the export. Default = Last day of the month identified in -StartDate if -OneTime is set; otherwise, 5 years from -StartDate.                                                                                                                                                                                                                                                                                                                  |
| `‑StorageAccountId`               | Required. Resource ID of the storage account to export data to.                                                                                                                                                                                                                                                                                                                                                                                                         |
| `‑StorageContainer`               | Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".                                                                                                                                                                                                                                                                                                                                               |
| `‑StoragePath`                    | Optional. Path to export data to within the storage container. Default = (scope ID).                                                                                                                                                                                                                                                                                                                                                                                    |
| `‑DoNotPartition`                 | Optional. Indicates whether to partition the exported data into multiple files. Partitioning is recommended for reliability so this option is to disable partitioning. Default = false.                                                                                                                                                                                                                                                                                 |
| `‑DoNotOverwrite`                 | Optional. Indicates whether to overwrite previously exported data for the current month. Overwriting is recommended to keep storage size and costs down so this option is to disable overwriting. If creating an export for FinOps hubs, we recommend you specify the -DoNotOverwrite option to improve troubleshooting. Default = false.                                                                                                                               |
| `‑SystemAssignedIdentity`         | Optional. Indicates that managed identity should be used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (for example, Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty).                    |
| `‑Location`                       | Optional. Indicates the Azure location to use for the managed identity used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (for example, Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty). |
| `‑Execute`                        | Optional. Indicates that the export should be run immediately after created.                                                                                                                                                                                                                                                                                                                                                                                            |
| `‑Backfill`                       | Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.                                                                                                                                                                                                                                                                                          |
| `‑ApiVersion`                     | Optional. API version to use when calling the Cost Management Exports API. Default = 2025-03-01.                                                                                                                                                                                                                                                                                                                                                                        |

<br>

## Examples

### Create one time export

```powershell
New-FinopsCostExport -Name 'July2023OneTime' `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" `
    -StorageAccountId "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet ActualCost `
    -OneTime `
    -StartDate "2023-07-01" `
    -EndDate "2023-07-31"
```

Creates a new one time export called 'July2023OneTime' from **2023-07-01** to **2023-07-31** with Dataset = Actual and execute it once.

### Create and run a daily export

```powershell
New-FinopsCostExport -Name 'DailyMTD' `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" `
    -StorageAccountId "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet AmortizedCost `
    -EndDate "2024-12-31" `
    -Execute
```

Creates a new scheduled export called **Daily-MTD** with StartDate = DateTime.Now and EndDate = 2024-12-31. Export is run immediately after creation.

### Create a monthly export

```powershell
New-FinopsCostExport -Name 'Monthly-Report' `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" `
    -StorageAccountId "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet AmortizedCost `
    -StartDate $(Get-Date).AddDays(5) `
    -EndDate "2024-08-15" `
    -Monthly `
    -Execute
```

Creates a new monthly export called **Monthly-Report** with StartDate = 1 day from DateTime.Now and EndDate **2024-08-15**. Export is run immediately after creation.

### Create daily export and backfill four months

```powershell
New-FinopsCostExport -Name 'Daily--MTD' `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" `
    -StorageAccountId "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet ActualCost `
    -StorageContainer "costreports" `
    -Backfill 4 `
    -Execute
```

Creates a new daily export called **Daily-MTD** with StartDate = DateTime.Now and EndDate 5 years from StartDate. Additionally, export cost data for the previous four months and save all results in `costreports` container of the specified storage account.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.12/bladeName/PowerShell/featureName/CostManagement.NewExport)

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
