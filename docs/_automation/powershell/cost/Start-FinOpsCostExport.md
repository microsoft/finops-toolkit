---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: Start-FinOpsCostExport
nav_order: 1
description: 'Initiates a Cost Management export run for the most recent period.'
permalink: /powershell/cost/Start-FinOpsCostExport
---

<span class="fs-9 d-block mb-4">Start-FinOpsCostExport</span>
Initiates a Cost Management export run for the most recent period.
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

The **Start-FinOpsCostExport** command runs a Cost Management export for the most recent period using the Run API.

This command has been tested with the following API versions:

- 2023-07-01-preview (default) – Enables FocusCost and other datasets.
- 2023-08-01

<br>

## 🧮 Syntax

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

## 📥 Parameters

| Name          | Description                                                                                                                                                                                                                  |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`       | Required. Name of the export.                                                                                                                                                                                                |
| `‑Scope`      | Optional. Resource ID of the scope to export data for. If empty, defaults to current subscription context.                                                                                                                   |
| `‑StartDate`  | Optional. Day to start pulling the data for. If not set, the export will use the dates defined in the export configuration.                                                                                                  |
| `‑EndDate`    | Optional. Last day to pull data for. If not set and -StartDate is set, -EndDate will use the last day of the month. If not set and -StartDate is not set, the export will use the dates defined in the export configuration. |
| `‑Backfill`   | Optional. Number of months to export the data for. Make note of throttling (429) errors. This is only run once. Failed exports are not re-attempted. Default = 0.                                                            |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview.                                                                                                                     |

<br>

## 🌟 Examples

### Export configured period

```powershell
Start-FinopsCostExport -Name 'CostExport'
```

Runs an export called 'CostExport' for the configured period.

### Export specific dates

```powershell
Start-FinopsCostExport -Name 'CostExport' -StartDate '2023-01-01' -EndDate '2023-12-31'
```

Runs an export called 'CostExport' for a specific date range.

### Backfill export

```powershell
Start-FinopsCostExport -Name 'CostExport' -Backfill 12
```

Runs an export called 'CostExport' for the previous 12 months.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" %}

<br>
