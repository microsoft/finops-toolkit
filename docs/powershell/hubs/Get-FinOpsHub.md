---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Get-FinOpsHub
nav_order: 2
description: 'Gets details about a FinOps hub instance.'
permalink: /powershell/hubs/Get-FinOpsHub
---

<span class="fs-9 d-block mb-4">Get-FinOpsHub</span>
Gets details about a FinOps hub instance.
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

The Get-FinOpsHubs command calls GitHub to retrieve all toolkit releases, then filters the list based on the specified options.

<br>

## 🧮 Syntax

```powershell
Get-FinOpsHub `
    [[-Name] <string>] `
    [-ResourceGroupName <string>] `
    [<CommonParameters>]
```

<br>

## 📥 Parameters

| Name                 | Description                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------- |
| '‑Name'              | Optional. Name of the FinOps hub instance. Supports wildcards.                           |
| '‑ResourceGroupName' | Optional. Name of the resource group the FinOps hub was deployed to. Supports wildcards. |

<br>

## 🌟 Examples

### Get all hubs

```powershell
Get-FinOpsHub
```

Returns all FinOps hubs for the selected subscription.

### Get named hubs

```powershell
Get-FinOpsHub -Name foo*
```

Returns all FinOps hubs that start with 'foo'.

### Get hubs in a resource group

```powershell
Get-FinOpsHub -ResourceGroupName foo
```

Returns all hubs in the 'foo' resource group.

### Get named hubs in a resource group

```powershell
Get-FinOpsHub -Name foo -ResourceGroupName bar
```

Returns all FinOps hubs named 'foo' in the 'bar' resource group.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
