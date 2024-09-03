False
---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: Remove-FinOpsCostExport
nav_order: 10
description: Delete a Cost Management export and optionally data associated with the export.
permalink: /powershell/cost/Remove-FinOpsCostExport
---

<span class="fs-9 d-block mb-4">Remove-FinOpsCostExport</span>
Delete a Cost Management export and optionally data associated with the export.
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

The **Remove-FinOpsCostExport** command deletes a Cost Management export and optionally deletes all data associated with the export from the related storage account.

This command has been tested with the following API versions:
- 2023-07-01-preview (default) – Enables FocusCost and other datasets.
- 2023-08-01
- 2023-03-01

<br>

## 🧮 Syntax

```powershell
Remove-FinOpsCostExport `
    [‑Name] <String> `
    [‑Scope] <String> `
    [‑RemoveData] `
    [[‑ApiVersion] <String>] `
    [‑WhatIf]
```

<br>

## 📥 Parameters

| Name | Description |
| ---- | ----------- |
| `‑Name` | Required. Name of the Cost Management export to delete. |
| `‑Scope` | Required. Resource ID of the scope to export data for. |
| `‑RemoveData` | Optional. Indicates that all cost data associated with the Export scope should be deleted. |
| `‑ApiVersion` | Optional. API version to use when calling the Cost Management Exports API. Default = 2023-07-01-preview. |
| `‑WhatIf` | Optional. Shows what would happen if the command runs without actually running the command. Default = false. |

<br>

## 🌟 Examples

### Delete a Cost Management export

```powershell
Remove-FinOpsCostExport `
    -Name MyExport `
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000" `
    -RemoveData
```

Deletes a Cost Management export and deletes all exported data from the related storage account.

<br>

---

## 🧰 Related tools

{% include tools.md aoe="1" bicep="0" data="0" hubs="1" pbi="1" ps="0" %}

<br>

