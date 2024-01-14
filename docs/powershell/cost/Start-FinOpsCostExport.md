---
layout: default
grand_parent: PowerShell
parent: Cost Management
title: Start-FinOpsCostExport
nav_order: 1
description: 'Initiates a Cost Management export run for the most recent period.'
permalink: /powershell/cost/Start-FinOpsCostExport
---

<span class="fs-9 d-block mb-4">Start-FinOpsCostExport</span>
Initiates a Cost Management export run for the most recent period.
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

The **Start-FinOpsCostExport** command runs a Cost Management export for the most recent period using the Run API.

<br>

## 🧮 Syntax

```powershell
Start-FinOpsCostExport `
    [-Name] <string> `
    [-Scope <string>] `
    [-ApiVersion <string>]
```

<br>

## 📥 Parameters

| Name                | Description                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `‑Name`             | Optional. Name of the export. Supports wildcards.                                                                   |
| `‑Scope`            | Optional. Resource ID of the scope the export was created for. If empty, defaults to current subscription context.  |
| `‑ApiVersion`       | Optional. API version to use when calling the Cost Management exports API. Default = 2023-03-01.                    |

<br>

## 🌟 Examples

### Run export

```powershell
Start-FinopsCostExport -Name 'July2023OneTime'
```

Runs an export called 'July2023OneTime'.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" ps="1" %}

<br>
