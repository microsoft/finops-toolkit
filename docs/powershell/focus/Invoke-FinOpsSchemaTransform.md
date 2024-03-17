---
layout: default
grand_parent: PowerShell
parent: FOCUS
title: Invoke-FinOpsSchemaTransform
nav_order: 2
description: 'Loads a Cost Management CSV file, converts it to FOCUS, and saves it to a new file'
permalink: /powershell/focus/Invoke-FinOpsSchemaTransform
---

<span class="fs-9 d-block mb-4">Invoke-FinOpsSchemaTransform</span>
Loads a Cost Management CSV file, converts it to the FinOps Open Cost and Usage Specification (FOCUS) schema, and saves it to a new file.
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
    _The Invoke-FinOpsSchemaTransform command was implemented before Microsoft Cost Management supported a native FOCUS export. Going forward, we recommend using the native export. The Invoke-FinOpsSchemaTransform command will remain available but will not be updated to support FOCUS 1.0-preview. If you have a scenario where you need a PowerShell converter, please leave feedback at [aka.ms/ftk](https://aka.ms/ftk)._
</blockquote>

The **Invoke-FinOpsSchemaTransform** command reads actual and amortized cost data from files via Import-Csv, converts them to the FinOps Open Cost and Usage Specification (FOCUS) schema via [ConvertTo-FinOpsSchema](./ConvertTo-FinOpsSchema.md), and then saves the result to a CSV file using Export-Csv.

This command is a simple helper to simplify chaining these commands together. If you do not want to read from a CSV file or write to a CSV file, use the ConvertTo-FinOpsSchema command.

Invoke-FinOpsSchemaTransform inherits the same schema constraints as ConvertTo-FinOpsSchema. Refer to that documentation for details.

<br>

## 🧮 Syntax

```powershell
Invoke-FinOpsSchemaTransform `
    [-ActualCostPath <string>] `
    [-AmortizedCostPath <string>] `
    [-OutputFile <string>] `
    [-Delimiter <string>] `
    [-Encoding <string>] `
    [-NoClobber] `
    [-Force]
```

<br>

## 📥 Parameters

| Name              | Description                                                                                                                                                                               |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ActualCostPath    | Required. Specifies the path to the actual cost data file. File must be a supported Microsoft Cost Management schema.                                                                     |
| AmortizedCostPath | Required. Specifies the path to the amortized cost data file. File must be a supported Microsoft Cost Management schema.                                                                  |
| OutputFile        | Required. Specifies the path to save the FOCUS cost data to.                                                                                                                              |
| Delimiter         | Optional. Specifies a delimiter to separate the property values. Enter a character, such as a colon (:). To specify a semicolon (;), enclose it in quotation marks. Default: "," (comma). |
| Encoding          | Optional. Specifies the encoding for the exported file. This value is passed to Export-Csv. Please refer to the Export-Csv documentation for the default and allowed values.              |
| NoClobber         | Optional. Use this parameter to not overwrite an existing file. By default, if the file exists in the specified path, it will be overwritten without warning.                             |
| Force             | Optional. This parameter allows overwriting files with the Read Only attribute.                                                                                                           |

<br>

## 🌟 Examples

### Get all hubs

```powershell
Invoke-FinOpsSchemaTransform `
    -ActualCostPath ActualCost.csv `
    -AmortizedCostPath AmortizedCost.csv `
    -OutputFile FOCUS.csv
```

Converts previously downloaded ActualCost.csv and AmortizedCost.csv files to FOCUS and saves the combined data to a FOCUS.csv file.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" pbi="1" data="1" %}

<br>
