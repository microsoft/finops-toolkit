---
title: Get-FinOpsCostExport command
description: Get a list of Cost Management exports for a given scope using the Get-FinOpsCostExport command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsCostExport command

The **Get-FinOpsCostExport** command gets a list of Cost Management exports for a given scope.

This command was tested with the following API versions:

- 2023-07-01-preview (default) – Enables FocusCost and other datasets.
- 2023-08-01
- 2023-03-01

<br>

## Syntax

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

## Parameters

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

## Return value

### FinOpsCostExport object

| Property              | Type                         | JSON path                                                                    |
| --------------------- | ---------------------------- | ---------------------------------------------------------------------------- |
| `Name`                | String                       | `name`                                                                       |
| `Id`                  | String                       | `id`                                                                         |
| `Type`                | String                       | `type`                                                                       |
| `eTag`                | String                       | `eTag`                                                                       |
| `Description`         | String                       | `properties.exportDescription`                                               |
| `Dataset`             | String                       | `properties.definition.type`                                                 |
| `DatasetVersion`      | String                       | `properties.definition.configuration.dataVersion`                            |
| `DatasetFilters`      | String                       | `properties.definition.configuration.filter`                                 |
| `DatasetTimeFrame`    | String                       | `properties.definition.timeframe`                                            |
| `DatasetStartDate`    | DateTime                     | `properties.definition.timePeriod.from`                                      |
| `DatasetEndDate`      | DateTime                     | `properties.definition.timePeriod.to`                                        |
| `DatasetGranularity`  | String                       | `properties.definition.dataset.granularity`                                  |
| `ScheduleStatus`      | String                       | `properties.schedule.status`                                                 |
| `ScheduleRecurrence`  | String                       | `properties.schedule.recurrence`                                             |
| `ScheduleStartDate`   | DateTime                     | `properties.schedule.recurrencePeriod.from`                                  |
| `ScheduleEndDate`     | DateTime                     | `properties.schedule.recurrencePeriod.to`                                    |
| `NextRuntimeEstimate` | DateTime                     | `properties.nextRunTimeEstimate`                                             |
| `Format`              | String                       | `properties.format`                                                          |
| `StorageAccountId`    | String                       | `properties.deliveryInfo.destination.resourceId`                             |
| `StorageContainer`    | String                       | `properties.deliveryInfo.destination.container`                              |
| `StoragePath`         | String                       | `properties.deliveryInfo.destination.rootfolderpath`                         |
| `OverwriteData`       | Boolean                      | `properties.deliveryInfo.dataOverwriteBehavior` == "OverwritePreviousReport" |
| `PartitionData`       | Boolean                      | `properties.deliveryInfo.partitionData`                                      |
| `CompressionMode`     | String                       | `properties.deliveryInfo.compressionMode`                                    |
| `RunHistory`          | FinOpsCostExportRunHistory[] | `properties.runHistory.value`                                                |

### FinOpsCostExportRunHistory object

| Property        | Type     | JSON path                                                |
| --------------- | -------- | -------------------------------------------------------- |
| `Id`            | String   | `properties.runHistory.value[].id`                       |
| `ExecutionType` | String   | `properties.runHistory.value[].properties.executionType` |
| `FileName`      | String   | `properties.runHistory.value[].fileName`                 |
| `StartTime`     | DateTime | `properties.runHistory.value[].processingStartTime`      |
| `EndTime`       | DateTime | `properties.runHistory.value[].processingEndTime`        |
| `Status`        | String   | `properties.runHistory.value[].status`                   |
| `SubmittedBy`   | String   | `properties.runHistory.value[].submittedBy`              |
| `SubmittedTime` | DateTime | `properties.runHistory.value[].submittedTime`            |

<br>

## Examples

### Get all cost exports for a subscription

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"
```

Gets all exports for a subscription. Doesn't include exports in nested resource groups.

### Get exports matching a wildcard name

```powershell
Get-FinOpsCostExport `
    -Name mtd* `
    -Scope "providers/Microsoft.Billing/billingAccounts/00000000"
```

Gets export with name matching wildcard mtd\* within the specified billing account scope. Doesn't include exports in nested resource groups.

### Get all amortized cost exports

```powershell
Get-FinOpsCostExport `
    -DataSet "AmortizedCost"
```

Gets all exports within the current context subscription scope and filtered by dataset AmortizedCost.

### Get exports using a specific storage account

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"`
    -StorageAccountId "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/MyResourceGroup/providers/Microsoft.Storage/storageAccounts/MyStorageAccount"
```

Gets all exports within the subscription scope filtered by a specific storage account.

### Get exports using a specific container

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" `
    -StorageContainer "MyContainer*"
```

Gets all exports within the subscription scope for a specific container. Supports wildcard.

### Get exports using a specific API version

```powershell
Get-FinOpsCostExport `
    -Scope "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"
    -StorageContainer "mtd*"
    -ApiVersion "2023-08-01"
    -StorageContainer "MyContainer*"
```

Gets all exports within the subscription scope for a container matching wildcard pattern and using a specific API version.
<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
