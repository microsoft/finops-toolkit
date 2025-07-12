---
title: Get-FinOpsCostExport command
description: Get a list of Cost Management exports for a given scope using the Get-FinOpsCostExport command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 06/21/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Get-FinOpsCostExport command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Get-FinOpsCostExport command

The **Get-FinOpsCostExport** command gets a list of Cost Management exports for a given scope.

This command was tested with the following API versions:

- 2025-03-01 (default) – GA version for FocusCost and other datasets.
- 2023-07-01-preview
- 2023-08-01
- 2023-03-01

<br>

## Syntax

```powershell
Get-FinOpsCostExport `
    [-Name <string>] `
    [-Scope <string>] `
    [-DataSet <string>] `
    [-DataSetVersion <string>] `
    [-StorageAccountId <string>] `
    [-StorageContainer <string>] `
    [-RunHistory] `
    [-ApiVersion <string>]
```

<br>

## Parameters

| Name                | Description                                                                                                                                                                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`             | Optional. Name of the export. Supports wildcards.                                                                                                                                                                             |
| `‑Scope`            | Optional. Resource ID of the scope the export was created for. If empty, defaults to current subscription context.                                                                                                            |
| `‑DataSet`          | Optional. Dataset to get exports for. Allowed values = "ActualCost", "AmortizedCost", "FocusCost", "PriceSheet", "ReservationDetails", "ReservationTransactions", "ReservationRecommendations". Default = null (all exports). |
| `‑DataSetVersion`   | Optional. Schema version of the dataset to export. Default = null (all exports).                                                                                                                                              |
| `‑StorageAccountId` | Optional. Resource ID of the storage account to get exports for. Default = null (all exports).                                                                                                                                |
| `‑StorageContainer` | Optional. Name of the container to get exports for. Supports wildcards. Default = null (all exports).                                                                                                                         |
| `‑RunHistory`       | Optional. Indicates whether the run history should be expanded. Default = false.                                                                                                                                              |
| `‑ApiVersion`       | Optional. API version to use when calling the Cost Management exports API. Default = 2025-03-01.                                                                                                                              |

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK0.11/bladeName/PowerShell/featureName/CostManagement.GetExport)

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
