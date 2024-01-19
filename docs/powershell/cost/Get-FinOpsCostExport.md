---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: Get-FinOpsCostExport
nav_order: 1
description: 'Get a list of Cost Management exports.'
permalink: /powershell/cost/Get-FinOpsCostExport
---

<span class="fs-9 d-block mb-4">Get-FinOpsCostExport</span>
Get a list of Cost Management exports.
{: .fs-6 .fw-300 }

[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧮 Syntax](#-syntax)
- [📥 Parameters](#-parameters)
- [📤 Return value](#-return-value)
- [🌟 Examples](#-examples)
- [🧰 Related tools](#-related-tools)

</details>

---

The **Get-FinOpsCostExport** command gets a list of Cost Management exports for a given scope.

This command has been tested with the following API versions:

- 2023-07-01-preview (default) – Enables FocusCost and other datasets.
- 2023-08-01
- 2023-03-01

<br>

## 🧮 Syntax

```powershell
Get-FinOpsCostExport `
    [-Name <string>] `
    [-Scope <string>] `
    [-DataSet <string>] `
    [-StorageAccountId <string>] `
    [-StorageContainer <string>] `
    [-RunHistory] `
    [-ApiVersion <string>]
```

<br>

## 📥 Parameters

| Name                | Description                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `‑Name`             | Optional. Name of the export. Supports wildcards.                                                                   |
| `‑Scope`            | Optional. Resource ID of the scope the export was created for. If empty, defaults to current subscription context.  |
| `‑DataSet`          | Optional. Dataset to get exports for. Allowed values = "ActualCost", "AmortizedCost". Default = null (all exports). |
| `‑StorageAccountId` | Optional. Resource ID of the storage account to get exports for. Default = null (all exports).                      |
| `‑StorageContainer` | Optional. Name of the container to get exports for. Supports wildcards. Default = null (all exports).               |
| `‑RunHistory`       | Optional. Indicates whether the run history should be expanded. Default = false.                                    |
| `‑ApiVersion`       | Optional. API version to use when calling the Cost Management exports API. Default = 2023-07-01-preview.            |

<br>

## 📤 Return value

### FinOpsCostExport object

| Property                                      | JSON path                                                                    |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `Name`                                        | `name`                                                                       |
| `Id`                                          | `id`                                                                         |
| `Type`                                        | `type`                                                                       |
| `eTag`                                        | `eTag`                                                                       |
| `Description`                                 | `properties.exportDescription`                                               |
| `Dataset`                                     | `properties.definition.type`                                                 |
| `DatasetVersion`                              | `properties.definition.configuration.dataVersion`                            |
| `DatasetFilters`                              | `properties.definition.configuration.filter`                                 |
| `DatasetTimeFrame`                            | `properties.definition.timeframe`                                            |
| `DatasetStartDate`                            | `properties.definition.timePeriod.from`                                      |
| `DatasetEndDate`                              | `properties.definition.timePeriod.to`                                        |
| `DatasetGranularity`                          | `properties.definition.dataset.granularity`                                  |
| `ScheduleStatus`                              | `properties.schedule.status`                                                 |
| `ScheduleRecurrence`                          | `properties.schedule.recurrence`                                             |
| `ScheduleStartDate`                           | `properties.schedule.recurrencePeriod.from`                                  |
| `ScheduleEndDate`                             | `properties.schedule.recurrencePeriod.to`                                    |
| `NextRuntimeEstimate`                         | `properties.nextRunTimeEstimate`                                             |
| `Format`                                      | `properties.format`                                                          |
| `StorageAccountId`                            | `properties.deliveryInfo.destination.resourceId`                             |
| `StorageContainer`                            | `properties.deliveryInfo.destination.container`                              |
| `StoragePath`                                 | `properties.deliveryInfo.destination.rootfolderpath`                         |
| `OverwriteData`                               | `properties.deliveryInfo.dataOverwriteBehavior` == "OverwritePreviousReport" |
| `PartitionData`                               | `properties.deliveryInfo.partitionData`                                      |
| `CompressionMode`                             | `properties.deliveryInfo.compressionMode`                                    |
| `RunHistory` (see FinOpsCostExportRunHistory) | `properties.runHistory.value`                                                |

### FinOpsCostExportRunHistory object

| Property        | JSON path                                                |
| --------------- | -------------------------------------------------------- |
| `Id`            | `properties.runHistory.value[].id`                       |
| `ExecutionType` | `properties.runHistory.value[].properties.executionType` |
| `FileName`      | `properties.runHistory.value[].fileName`                 |
| `StartTime`     | `properties.runHistory.value[].processingStartTime`      |
| `EndTime`       | `properties.runHistory.value[].processingEndTime`        |
| `Status`        | `properties.runHistory.value[].status`                   |
| `SubmittedBy`   | `properties.runHistory.value[].submittedBy`              |
| `SubmittedTime` | `properties.runHistory.value[].submittedTime`            |

<br>

## 🌟 Examples

### Get all cost exports for a subscription

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"
```

Gets all exports for a subscription. Does not include exports in nested resource groups.

### Get exports matching a wildcard name

```powershell
Get-FinOpsCostExport `
    -Name mtd* `
    -Scope "providers/Microsoft.Billing/billingAccounts/00000000"
```

Gets export with name matching wildcard mtd\* within the specified billing account scope. Does not include exports in nested resource groups.

### Get all amortized cost exports

```powershell
Get-FinOpsCostExport `
    -DataSet "AmortizedCost"
```

Gets all exports within the current context subscription scope and filtered by dataset AmortizedCost.

### Get exports using a specific storage account

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"`
    -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"
```

Gets all exports within the subscription scope filtered by a specific storage account.

### Get exports using a specific container

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" `
    -StorageContainer "MyContainer*"
```

Gets all exports within the subscription scope for a specific container. Supports wildcard.

### Get exports using a specific API version

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"
    -StorageContainer "mtd*"
    -ApiVersion "2023-08-01"
    -StorageContainer "MyContainer*"
```

Gets all exports within the subscription scope for a container matching wildcard pattern and using a specific API version.
<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" %}

<br>
