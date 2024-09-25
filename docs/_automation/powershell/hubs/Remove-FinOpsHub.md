---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Remove-FinOpsHub
nav_order: 10
description: Delete a FinOps hub instance and optionally keep the storage account hosting cost data.
permalink: /powershell/hubs/Remove-FinOpsHub
---

<span class="fs-9 d-block mb-4">Remove-FinOpsHub</span>
Delete a FinOps hub instance and optionally keep the storage account hosting cost data.
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

The **Remove-FinOpsHub** command deletes a FinOps Hub instance and optionally deletes the storage account hosting cost data.

The comamnd returns a boolean value indicating whether all resources were successfully deleted.

<br>

## 🧮 Syntax

```powershell
# Delete by name
Remove-FinOpsHub `
    ‑Name <String> `
    [‑ResourceGroupName <String>] `
    [‑KeepStorageAccount] `
    [‑Force] `
    [‑WhatIf]
```

```powershell
# Delete by reference
Remove-FinOpsHub `
    ‑InputObject <PSObject> `
    [‑KeepStorageAccount] `
    [‑Force] `
    [‑WhatIf]
```

<br>

## 📥 Parameters

| Name | Description |
| ---- | ----------- |
| `‑Name` | Required if not specifying InputObject. Name of the FinOps hub instance. |
| `‑ResourceGroupName` | Optional when specifying Name. Resource group name for the FinOps Hub. |
| `‑InputObject` | Required if not specifying Name. Expected object is the output of Get-FinOpsHub. |
| `‑KeepStorageAccount` | Optional. Indicates that the storage account associated with the FinOps Hub should be retained. Default = false. |
| `‑Force` | Optional. Indicates that the hub instance should be deleted without an additional confirmation. Default = false. |
| `‑WhatIf` | Optional. Shows what would happen if the command runs without actually running the command. Default = false. |

<br>

## 🌟 Examples

### Remove a FinOps hub instance

```powershell
Remove-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyRG `
    -KeepStorageAccount
```

Deletes a FinOps Hub named MyHub and deletes all associated resource except the storage account.

<br>

---

## 🧰 Related tools

{% include tools.md aoe="1" bicep="0" data="0" hubs="1" pbi="1" ps="0" %}

<br>

