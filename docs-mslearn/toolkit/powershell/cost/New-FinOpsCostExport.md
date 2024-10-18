---
title: New-FinOpsCostExport command
description: Creates a new Cost Management export.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what New-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# New-FinOpsCostExport command

The **New-FinOpsCostExport** command creates a new Cost Management export for the specified scope.

This command has been tested with the following API versions:

- 2023-07-01-preview (default) – Enables FocusCost and other datasets.
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

| Name                | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`             | Required. Name of the export.                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `‑Scope`            | Required. Resource ID of the scope to export data for.                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑Dataset`          | Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost". Default = "ActualCost".                                                                                                                                                                                                                                                                                                                                                             |
| `‑DatasetVersion`   | Optional. Schema version of the dataset to export. Default = (latest version as of June 2024; e.g., "1.0" for FocusCost).                                                                                                                                                                                                                                                                                                                                        |
| `‑DatasetFilters`   | Optional. Dictionary of key/value pairs to filter the dataset with. Only applies to ReservationRecommendations dataset in 2023-07-01-preview. Valid filters are reservationScope (Shared or Single), resourceType (e.g., VirtualMachines), lookBackPeriod (Last7Days, Last30Days, Last60Days).                                                                                                                                                                   |
| `‑Monthly`          | Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.                                                                                                                                                                                                                                                                                                                                                              |
| `‑OneTime`          | Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.                                                                                                                                                                                                                                                                         |
| `‑StartDate`        | Optional. Day to start running exports. Default = First day of the previous month if -OneTime is set; otherwise, tomorrow (DateTime.Now.AddDays(1)).                                                                                                                                                                                                                                                                                                             |
| `‑EndDate`          | Optional. Last day to run the export. Default = Last day of the month identified in -StartDate if -OneTime is set; otherwise, 5 years from -StartDate.                                                                                                                                                                                                                                                                                                           |
| `‑StorageAccountId` | Required. Resource ID of the storage account to export data to.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `‑StorageContainer` | Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".                                                                                                                                                                                                                                                                                                                                        |
| `‑StoragePath`      | Optional. Path to export data to within the storage container. Default = (scope ID).                                                                                                                                                                                                                                                                                                                                                                             |
| `‑Location`         | Optional. Indicates the Azure location to use for the managed identity used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (e.g., Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty). |
| `‑DoNotPartition`   | Optional. Indicates whether to partition the exported data into multiple files. Partitioning is recommended for reliability so this option is to disable partitioning. Default = false.                                                                                                                                                                                                                                                                          |
| `‑DoNotOverwrite`   | Optional. Indicates whether to overwrite previously exported data for the current month. Overwriting is recommended to keep storage size and costs down so this option is to disable overwriting. Default = false.                                                                                                                                                                                                                                               |
| `‑Execute`          | Optional. Indicates that the export should be run immediately after created.                                                                                                                                                                                                                                                                                                                                                                                     |
| `‑Backfill`         | Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.                                                                                                                                                                                                                                                                                   |
| `‑Execute`          | Optional. Indicates that the export should be run immediately after created.                                                                                                                                                                                                                                                                                                                                                                                     |
| `‑Backfill`         | Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.                                                                                                                                                                                                                                                                                   |
| `‑ApiVersion`       | Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview.                                                                                                                                                                                                                                                                                                                                                         |

<br>

## Examples

### Create one time export

```powershell
New-FinopsCostExport -Name 'July2023OneTime' `
    -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet ActualCost `
    -OneTime `
    -StartDate "2023-07-01" `
    -EndDate "2023-07-31"
```

Creates a new one time export called 'July2023OneTime' from 2023-07-01 to 2023-07-31 with Dataset = Actual and execute it once.

### Create and run a daily export

```powershell
New-FinopsCostExport -Name 'DailyMTD' `
    -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet AmortizedCost `
    -EndDate "2024-12-31" `
    -Execute
```

Creates a new scheduled export called Daily-MTD with StartDate = DateTime.Now and EndDate = 2024-12-31. Export is run immediately after creation.

### Creates monthly export

```powershell
New-FinopsCostExport -Name 'Monthly-Report' `
    -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet AmortizedCost `
    -StartDate $(Get-Date).AddDays(5) `
    -EndDate "2024-08-15" `
    -Monthly `
    -Execute
```

Creates a new monthly export called Monthly-Report with StartDate = 1 day from DateTime.Now and EndDate 2024-08-15. Export is run immediately after creation.

### Create daily export and backfill 4 months

```powershell
New-FinopsCostExport -Name 'Daily--MTD' `
    -Scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -StorageAccountId "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/SharedStorage/providers/Microsoft.Storage/storageAccounts/ddsharedstorage" `
    -DataSet ActualCost `
    -StorageContainer "costreports" `
    -Backfill 4 `
    -Execute
```

Creates a new daily export called Daily-MTD with StartDate = DateTime.Now and EndDate 5 years from StartDate. Additionally, export cost data for the previous 4 months and save all results in "costreports" container of the specified storage account.

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
