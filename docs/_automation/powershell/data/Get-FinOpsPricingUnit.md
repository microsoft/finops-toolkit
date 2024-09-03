---
layout: default
grand_parent: PowerShell
parent: Open data
title: Get-FinOpsPricingUnit
nav_order: 10
description: Gets a pricing unit with its corresponding distinct unit and block size.
permalink: /powershell/data/Get-FinOpsPricingUnit
---

<span class="fs-9 d-block mb-4">Get-FinOpsPricingUnit</span>
Gets a pricing unit with its corresponding distinct unit and block size.
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

The **Get-FinOpsPricingUnit** command returns a pricing unit (aka unit of measure) with the singular, distinct unit based on applicable block pricing rules, and the pricing block size.

Block pricing is when a service is measured in groups of units (e.g., 100 hours).

<br>

## 🧮 Syntax

```powershell
Get-FinOpsPricingUnit `
    [[‑UnitOfMeasure] <String>] `
    [‑DistinctUnits <String>] `
    [‑BlockSize <Double>]
```

<br>

## 📥 Parameters

| Name | Description |
| ---- | ----------- |
| `‑UnitOfMeasure` | Optional. Unit of measure (aka pricing unit) value from a Cost Management cost/usage details or price sheet dataset. Accepts wildcards. Default = * (all). |
| `‑DistinctUnits` | Optional. The distinct unit for the pricing unit without block pricing. Accepts wildcards. Default = * (all). |
| `‑BlockSize` | Optional. The number of units for block pricing (e.g., 100 for "100 Hours"). Default = null (all). |

<br>

## 🌟 Examples

### Get based on unit of measure

```powershell
Get-FinOpsPricingUnit -UnitOfMeasure "*hours*"
```

Returns all pricing units with "hours" in the name.

### Get based on distinct units

```powershell
Get-FinOpsPricingUnit -DistinctUnits "GB"
```

Returns all pricing units measured in gigabytes.

<br>

---

## 🧰 Related tools

{% include tools.md aoe="0" bicep="0" data="1" hubs="1" pbi="1" ps="0" %}

<br>

