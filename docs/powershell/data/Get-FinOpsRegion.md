---
layout: default
grand_parent: PowerShell
parent: Open data
title: Get-FinOpsRegion
nav_order: 20
description: 'Gets an Azure region ID and name'
permalink: /powershell/data/Get-FinOpsRegion
---

<span class="fs-9 d-block mb-4">Get-FinOpsRegion</span>
Gets an Azure region ID and name to clean up Cost Management cost data during ingestion.
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

The **Get-FinOpsRegion** command returns an Azure region ID and name based on the specified resource location.

<br>

## 🧮 Syntax

```powershell
Get-FinOpsRegion `
    [[-ResourceLocation] <string>] `
    [-RegionId <string>] `
    [-RegionName <string>]
```

<br>

## 📥 Parameters

| Name            | Description                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| ResouceLocation | Optional. Resource location value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = \* (all).      |
| RegionId        | Optional. Azure region ID (lowercase English name without spaces). Accepts wildcards. Default = \* (all).                        |
| RegionName      | Optional. Azure region name (title case English name with spaces). Accepts wildcards. Default = \* (all).IncludeResourceLocation | Optional. Indicates whether to include the ResourceLocation property in the output. Default = false. |

<br>

## 🌟 Examples

### Get a specific region

```powershell
Get-FinOpsRegion -ResourceLocation "US East"
```

Returns the region ID and name for the East US region.

### Get many regions with the original Cost Management value

```powershell
Get-FinOpsRegion -RegionId "*asia*" -IncludeResourceLocation
```

Returns all Asia regions with the original Cost Management ResourceLocation value.

<br>

---

## 🧰 Related tools

{% include tools.md data="1" %}

<br>
