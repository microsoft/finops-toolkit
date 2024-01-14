---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: New-FinOpsCostExport
nav_order: 1
description: 'Creates a new Cost Management export.'
permalink: /powershell/cost/New-FinOpsCostExport
---

<span class="fs-9 d-block mb-4">New-FinOpsCostExport</span>
Creates a new Cost Management export.
{: .fs-6 .fw-300 }

[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧮 Syntax](#-syntax)
- [📥 Parameters](#-parameters)
- [🌟 Examples](#-examples)
- [🧰 Related tools](#-related-tools)

</details>

---

The **New-FinOpsCostExport** command creates a new Cost Management export for the specified scope.

<br>

## 🧮 Syntax

```powershell
# Create a new daily/monthly export
New-FinOpsCostExport `
    [-Name] <string> `
    -Scope <string> `
    [-Dataset <string>] `
    [-Monthly] `
    [-StartDate <DateTime>] `
    [-EndDate <DateTime>] `
    -StorageAccountId <string> `
    [-StorageContainer <string>] `
    [-StoragePath <string>] `
    [-Execute] `
    [-Backfill <int>] `
    [-ApiVersion <string>]

# Create a new one-time export
New-FinOpsCostExport `
    [-Name] <string> `
    -Scope <string> `
    [-Dataset <string>] `
    -StorageAccountId <string> `
    [-StorageContainer <string>] `
    [-StoragePath <string>] `
    -OneTime `
    -StartDate <DateTime> `
    -EndDate <DateTime> `
    [-ApiVersion <string>]
```

<br>

## 📥 Parameters

| Name                | Description                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`             | Required. Name of the export.                                                                                                                                                            |
| `‑Scope`            | Required. Resource ID of the scope to export data for.                                                                                                                                   |
| `‑Dataset`          | Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost". Default = "ActualCost".                                                                                     |
| `‑Monthly`          | Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.                                                                                      |
| `‑OneTime`          | Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option. |
| `‑StartDate`        | Optional. Day to start running exports. If -OneTime is set, this is required (not defaulted) and is used as the first day to query data for. Default = DateTime.Now.                     |
| `‑EndDate`          | Optional. Last day to run the export. If -OneTime is set, this is required (not defaulted) and is used as the last day to query data for. Default = 5 years from -StartDate.             |
| `‑StorageAccountId` | Required. Resource ID of the storage account to export data to.                                                                                                                          |
| `‑StorageContainer` | Optional. Name of the container to export data to. Container is created if it doesn't exist. Default = "cost-management".                                                                |
| `‑StoragePath`      | Optional. Path to export data to within the storage container. Default = (scope ID).                                                                                                     |
| `‑Execute`          | Optional. Indicates that the export should be run immediately after created.                                                                                                             |
| `‑Backfill`         | Optional. Number of months to export the data for. This is only run once at create time. Failed exports are not re-attempted. Not supported when -OneTime is set. Default = 0.           |
| `‑ApiVersion`       | Optional. API version to use when calling the Cost Management Exports API. Default = 2023-03-01.                                                                                         |

<br>

## 🌟 Examples

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

Creates a new daily export called Daily-MTD with StartDate = DateTime.Now and EndDate 5 years from StartDate. Additiionally, export cost data for the previous 4 months and save all results in costreports container of the specified storage account.

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="0" pbi="1" ps="0" %}

<br>
