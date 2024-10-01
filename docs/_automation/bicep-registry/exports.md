---
layout: default
parent: Bicep Registry
title: Exports
nav_order: 10
description: 'Publish Cost Management datasets to a storage account ad-hoc or on a recurring schedule'
permalink: /bicep/exports
nav_exclude: true
---

<span class="fs-9 d-block mb-4">Exports</span>
Publish Cost Management datasets to a storage account ad-hoc or on a recurring schedule.
{: .fs-6 .fw-300 }

[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧮 Syntax](#-syntax)
- [📥 Parameters](#-parameters)
- [🌟 Examples](#-examples)
- [🧐 See also](#-see-also)
- [🧰 Related tools](#-related-tools)

</details>

---

<!--
## Exports
<small>Version: **Unreleased**</small>
{: .label .label-yellow .pt-0 .pl-3 .pr-3 .m-0 }
<small>Scopes: **Resource group, Subscription**</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>[Issue: **#221**](https://github.com/microsoft/finops-toolkit/issues/221)</small>
{: .label .label-yellow .pt-0 .pl-3 .pr-3 .m-0 }
Creates an [export](https://learn.microsoft.com/rest/api/cost-management/exports) to push cost data to a storage account on a daily or monthly schedule.
-->

Cost Mangaement exports publish cost-related datasets to a storage account on a recurring basis. Cost details are available in native actual or amortized cost datasets or in a FOCUS dataset, which includes both actual and amortized cost in a single, smaller dataset that is aligned to the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, see [About FOCUS](https://aka.ms/ftk/focus).

Additional datasets are available for billing account and billing profile scopes directly via API, including prices, reservation details, reservation transactions, and reservation recommendations.

[About exports](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-improved-exports){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 🧮 Syntax

<small>Version: **1.0**</small>
{: .label .label-green .pt-0 .pl-3 .pr-3 .m-0 }
<small>Scopes: **Subscription, Resource group**</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module <string> 'br/public:cost/<scope>-export:1.0' = {
  name: <string>
  params: {
    description: <string>
    location: <string>
    dataset: 'ActualCost' | 'AmortizedCost' | 'FocusCost'
    datasetVersion: <string>
    monthly: <bool>
    oneTime: <bool>
    startDate: 'yyyy-MM-dd'
    endDate: 'yyyy-MM-dd'
    storageAccountId: <string>
    storageContainer: <string>
    storagePath: <string>
    doNotOverwrite: <bool>
    doNotPartition: <bool>
  }
}
```

<br>

## 📥 Parameters

| Name               |   Type   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------ | :------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`             | `string` | Required. Name of the export.                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `description`      | `string` | Optional. Additional text to save about the export for context.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `dataset`          | `string` | Optional. Dataset to export. Allowed values = "ActualCost", "AmortizedCost", "FocusCost". Note there are other datasets available at other scopes. Default = "FocusCost".                                                                                                                                                                                                                                                                                        |
| `datasetVersion`   | `string` | Optional. Schema version of the dataset to export. Default = "1.0" (applies to FocusCost only).                                                                                                                                                                                                                                                                                                                                                                  |
| `monthly`          |  `bool`  | Optional. Indicates that the export should be executed monthly (instead of daily). Default = false.                                                                                                                                                                                                                                                                                                                                                              |
| `oneTime`          |  `bool`  | Optional. Indicates that the export should only be executed once. When set, the start/end dates are the dates to query data for. Cannot be used in conjunction with the -Monthly option.                                                                                                                                                                                                                                                                         |
| `startDate`        | `string` | Optional. Day to start running exports. Must be in the format yyyy-MM-ddTHH:miZ. Default = First day of the previous month if oneTime is set; otherwise, tomorrow.                                                                                                                                                                                                                                                                                               |
| `endDate`          | `string` | Optional. Last day to run the export. Must be in the format yyyy-MM-ddTHH:miZ. Default = Last day of the month identified in startDate if oneTime is set; otherwise, 5 years from startDate.                                                                                                                                                                                                                                                                     |
| `storageAccountId` | `string` | Required. Resource ID of the storage account to export data to.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `storageContainer` | `string` | Optional. Name of the container to export data to. Container is created if it doesn\'t exist. Default = "cost-management".                                                                                                                                                                                                                                                                                                                                       |
| `storagePath`      | `string` | Optional. Path to export data to within the storage container. Default = (scope ID).                                                                                                                                                                                                                                                                                                                                                                             |
| `doNotPartition`   |  `bool`  | Optional. Indicates whether to partition the exported data into multiple files. Partitioning is recommended for reliability so this option is to disable partitioning. Default = false.                                                                                                                                                                                                                                                                          |
| `doNotOverwrite`   |  `bool`  | Optional. Indicates whether to overwrite previously exported data for the current month. Overwriting is recommended to keep storage size and costs down so this option is to disable overwriting. If creating an export for FinOps hubs, we recommend you specify the doNotOverwrite option to improve troubleshooting. Default = false.                                                                                                                         |
| `location`         | `string` | Optional. Indicates the Azure location to use for the managed identity used to push data to the storage account. Managed identity is required in order to work with storage accounts behind a firewall but require access to grant permissions (e.g., Owner). If specified, managed identity will be used; otherwise, managed identity will not be used and your export will not be able to push data to a storage account behind a firewall. Default = (empty). |

<br>

## 🌟 Examples

### Creates an export with defaults

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module defaultDailyExport '../main.bicep' = {
  name: '__test_defaultDaily'
  params: {
    storageAccountId: storage.id
  }
}
```

Creates an export with all the defaults.

### Monthly export with defaults

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module defaultMonthlyExport '../main.bicep' = {
  name: '__test_defaultMonthly'
  params: {
    monthly: true
    storageAccountId: storage.id
  }
}
```

Creates a monthly export with all the defaults.

### One-time export with defaults

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module defaultOneTimeExport '../main.bicep' = {
  name: '__test_defaultOneTime'
  params: {
    oneTime: true
    storageAccountId: storage.id
  }
}
```

Creates a one-time export with all the defaults.

### One-time actual cost export

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module actualExport '../main.bicep' = {
  name: '__test_actual'
  params: {
    dataset: 'ActualCost'
    oneTime: true
    startDate: '2024-07-01'
    endDate: '2024-07-31'
    storageAccountId: storage.id
  }
}
```

Creates a one-time actual cost export from 2024-07-01 to 2024-07-31.

### Daily amortized cost export

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module amortizedExport '../main.bicep' = {
  name: '__test_amortized'
  params: {
    dataset: 'AmortizedCost'
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P10D')
    storageAccountId: storage.id
  }
}
```

Creates a daily amortized cost export that runs the next 5-10 days.

### Daily export with all options

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module dailyAllOptionsExport '../main.bicep' = {
  name: '__test_dailyAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'AmortizedCost'
    datasetVersion: '2021-10-01'
    monthly: false
    oneTime: false
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P7D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}
```

Creates a daily export with all options.

### Monthly export with all options

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module monthlyAllOptionsExport '../main.bicep' = {
  name: '__test_monthlyAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'FocusCost'
    datasetVersion: '1.0-preview(v1)'
    monthly: true
    oneTime: false
    startDate: dateTimeAdd(timestamp, 'P5D')
    endDate: dateTimeAdd(timestamp, 'P7D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}
```

Creates a monthly export with all options.

### One-time export with all options

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module oneTimeAllOptionsExport '../main.bicep' = {
  name: '__test_oneTimeAllOptions'
  params: {
    description: 'Some description about this export'
    location: 'West US2'    
    dataset: 'FocusCost'
    datasetVersion: '1.0'
    monthly: false
    oneTime: true
    startDate: dateTimeAdd(timestamp, 'P-2D')
    endDate: dateTimeAdd(timestamp, 'P-1D')
    storageAccountId: storage.id
    storageContainer: 'cm-exports'
    storagePath: 'path/to/export'
    doNotOverwrite: true
    doNotPartition: true
  }
}
```

Creates a one-time export with all options.

<br>

## 🧐 See also

- Bicep Registry: [Exports for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-export/README.md)
- Bicep Registry: [Exports for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-export/README.md)
- [Exports API reference](https://learn.microsoft.com/rest/api/cost-management/exports/create-or-update)

<br>

---

## 🧰 Related tools

{% include tools.md ps="1" %}

<br>
