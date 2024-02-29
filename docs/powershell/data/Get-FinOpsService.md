---
layout: default
grand_parent: PowerShell
parent: Open data
title: Get-FinOpsService
nav_order: 40
description: 'Gets the name and category for a service, publisher, and cloud provider'
permalink: /powershell/data/Get-FinOpsService
---

<span class="fs-9 d-block mb-4">Get-FinOpsService</span>
Gets the name and category for a service, publisher, and cloud provider to support FinOps Open Cost and Usage Specification (FOCUS).
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

The **Get-FinOpsService** command returns service details based on the specified filters. This command is designed to help map Cost Management cost data to the FinOps Open Cost and Usage Specification (FOCUS) schema but can also be useful for general data cleansing.

<blockquote class="important" markdown="1">
  _Both `ConsumedService` and `ResourceType` are required to find a unique service in many cases._
</blockquote>

<br>

## 🧮 Syntax

```powershell
Get-FinOpsService `
    [[-ConsumedService] <string>] `
    [[-ResourceId] <string>] `
    [[-ResourceType] <string>] `
    [-ServiceName <string>] `
    [-ServiceCategory <string>] `
    [-ServiceModel <string>] `
    [-Environment <string>] `
    [-PublisherName <string>] `
    [-PublisherCategory <string>]
```

<br>

## 📥 Parameters

| Name                 | Description                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `‑ConsumedService`   | Optional. ConsumedService value from a Cost Management cost/usage details dataset. Accepts wildcards. Default = \* (all). |
| `‑ResourceId`        | Optional. The Azure resource ID for resource you want to look up. Accepts wildcards. Default = \* (all).                  |
| `‑ResourceType`      | Optional. The Azure resource type for the resource you want to find the service for. Default = null (all).                |
| `‑ServiceName`       | Optional. The service name to find. Default = null (all).                                                                 |
| `‑ServiceCategory`   | Optional. The service category to find services for. Default = null (all).                                                |
| `‑Servicemodel`      | Optional. The service model the service aligns to. Expected values: IaaS, PaaS, SaaS. Default = null (all).               |
| `‑Environment`       | Optional. The environment the service runs in. Expected values: Cloud, Hybrid. Default = null (all).                      |
| `‑PublisherName`     | Optional. The publisher name to find services for. Default = null (all).                                                  |
| `‑PublisherCategory` | Optional. The publisher category to find services for. Default = null (all).                                              |

<br>

## 🌟 Examples

### Get a specific region

```powershell
Get-FinOpsService `
    -ConsumedService "Microsoft.C*" `
    -ResourceType "Microsoft.Compute/virtualMachines"
```

Returns all services with a resource provider that starts with "Microsoft.C".

<br>

---

## 🧰 Related tools

{% include tools.md data="1" pbi="1" hubs="1" %}

<br>
