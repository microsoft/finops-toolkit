---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: Remove-FinOpsCostExport
nav_order: 1
description: 'Delete a Cost Management export and optionally data associated with the export'
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

The Remove-FinOpsCostExport command  deletes a Cost Management export and optionally data associated with the export.

<br>

## 🧮 Syntax

```powershell
Deploy-FinOpsHub `
    -Name <string> `
    -Scope <string> `
    [-RemoveData <switch>] `
    [-ApiVersion <string>] `
```

<br>

## 📥 Parameters

| Name          | Description                                                                                                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Name          | Required. Name of the Cost Management export.                                                                                                                   |
| Scope | Required. Resource ID of the scope to export data for.context.                                                                      |
| RemoveData      | Optional. Optional. Indicates that all cost data associated with the Export scope should be deleted.                                                                      |
| ApiVersion    | Optional. API version to use when calling the Cost Management exports API. Default = 2023-03-01. |
|

<br>

## 🌟 Examples

Remove-FinOpsCostExport 


### Delete a Cost Management export

```powershell
Remove-FinOpsCostExport `
    -Name MyExport`
    -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"`
    -RemoveData
 
```

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
