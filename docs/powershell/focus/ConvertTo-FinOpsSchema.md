---
layout: default
grand_parent: PowerShell
parent: FOCUS
title: ConvertTo-FinOpsSchema
nav_order: 1
description: 'Converts Cost Management cost data to FOCUS'
permalink: /powershell/focus/ConvertTo-FinOpsSchema
---

<span class="fs-9 d-block mb-4">ConvertTo-FinOpsSchema</span>
Converts Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema.
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

<blockquote class="warning" markdown="1">
    _The ConvertTo-FinOpsSchema command was implemented before Microsoft Cost Management supported a native FOCUS export. Going forward, we recommend using the native export. The ConvertTo-FinOpsSchema command will remain available but will not be updated to support FOCUS 1.0-preview. If you have a scenario where you need a PowerShell converter, please leave feedback at [aka.ms/ftk](https://aka.ms/ftk)._
</blockquote>

The **ConvertTo-FinOpsSchema** command returns an object that adheres to the [FinOps Open Cost and Usage Specification (FOCUS)](https://focus.finops.org) schema.

ConvertTo-FinOpsSchema currently understands how to convert Cost Management cost data using the latest schemas as of September 2023. Older schemas may not be fully supported. Please review output and report any issues to [aka.ms/ftk](https://aka.ms/ftk).

You can pipe objects to ConvertTo-FinOpsSchema from an exported or downloaded CSV file using Import-Csv or ConvertFrom-Csv and pipe to Export-Csv to save as a CSV file. Or use the [Invoke-FinOpsSchemaTransform](./Invoke-FinOpsSchema.md) command to simplify the process.

<br>

## 🧮 Syntax

```powershell
ConvertTo-FinOpsSchema `
    [-ActualCost <object>] `
    [-AmortizedCost <object>]
```

<br>

## 📥 Parameters

| Name          | Description                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------------------------------------------- |
| ActualCost    | Required. Specifies the actual cost data to be converted. Object must be a supported Microsoft Cost Management schema.    |
| AmortizedCost | Required. Specifies the amortized cost data to be converted. Object must be a supported Microsoft Cost Management schema. |

<br>

## 🌟 Examples

### Get all hubs

```powershell
ConvertTo-FinOpsSchema `
    -ActualCost (Import-Csv my-actual-cost-details.csv) `
    -AmortizedCost (Import-Csv my-amortized-cost-details.csv) `
| Export-Csv my-cost-details-in-focus.csv
```

Converts previously downloaded actual and amortized cost details to FOCUS 0.5 and saves it as a CSV file.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" data="1" %}

<br>
