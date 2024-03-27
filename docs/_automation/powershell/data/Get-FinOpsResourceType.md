---
layout: default
grand_parent: PowerShell
parent: Open data
title: Get-FinOpsResourceType
nav_order: 30
description: 'Gets an Azure resource type and readable display names'
permalink: /powershell/data/Get-FinOpsResourceType
---

<span class="fs-9 d-block mb-4">Get-FinOpsResourceType</span>
Gets details about an Azure resource type.
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

The **Get-FinOpsResourceType** command returns an Azure resource type with readable display names, a flag to indicate if the resource provider identified this as a preview resource type, a description, an icon, and help and support links.

<br>

## 🧮 Syntax

```powershell
Get-FinOpsResourceType `
    [[-ResourceType] <string>] `
    [-IsPreview <bool>]
```

<br>

## 📥 Parameters

| Name            | Description                                                                                                                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑ResourceType` | Optional. Azure resource type value. Accepts wildcards. Default = \* (all).                                                                                                                                                 |
| `‑IsPreview`    | Optional. Indicates whether to include or exclude resource types that are in preview. Note: Not all resource types self-identify as being in preview, so this may not be completely accurate. Default = null (include all). |

<br>

## 🌟 Examples

### Get resource type details

```powershell
Get-FinOpsResourceType -ResourceType "microsoft.compute/virtualmachines"
```

Returns the resource type details for virtual machines.

### Get non-preview resource types

```powershell
Get-FinOpsResourceType -Preview $false
```

Returns all resource types that are not in preview.

<br>

---

## 🧰 Related tools

{% include tools.md data="1" hubs="1" %}

<br>
