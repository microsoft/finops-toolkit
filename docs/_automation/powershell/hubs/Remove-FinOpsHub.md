---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Remove-FinOpsHub
nav_order: 1
description: 'Remove a FinOps hub instance.'
permalink: /powershell/hubs/Remove-FinOpsHub
---

<span class="fs-9 d-block mb-4">Remove-FinOpsHub</span>
Delete a FinOps hub instance, including all dependent resources.
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

The **Remove-FinOpsHub** command removes a FinOps hub instance and optionally keep the storage account hosting cost data.

The comamnd returns a boolean value indicating whether all resources were successfully deleted.

<br>

## 🧮 Syntax

```powershell
Remove-FinOpsHub `
    [-Name] <string> `
    [-ResourceGroup <string>] `
    [-KeepStorageAccount]
```

```powershell
Remove-FinOpsHub `
    [-InputObject] <PSObject> `
    [-KeepStorageAccount]
```

<br>

## 📥 Parameters

| Name                  | Description                                                                                     |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `‑Name`               | Required. Name of the FinOps hub instance.                                                      |
| `‑InputObject`        | Required when specifying InputObject. Expected object is the output of Get-FinOpsHub.           |
| `‑ResourceGroup`      | Optional when specifying Name. Resource Group Name for the FinOps Hub.                          |
| `‑KeepStorageAccount` | Optional. Indicates that the storage account associated with the FinOps Hub should be retained. |

<br>

## 🌟 Examples

### Remove a FinOps hub instance

```powershell
Remove-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyRG `
    -KeepStorageAccount
```

Deletes a FinOps Hub named MyHub and deletes all associated resource except the storage account.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
