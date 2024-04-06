---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Initialize-FinOpsHubDeployment
nav_order: 1
description: 'Initialize a FinOps hub deployment.'
permalink: /powershell/hubs/Initialize-FinOpsHubDeployment
---

<span class="fs-9 d-block mb-4">Initialize-FinOpsHubDeployment</span>
Initialize a FinOps hub deployment in order to enable resource group owners to deployment hubs via the portal.
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

The **Initialize-FinOpsHubDeployment** command performs any initialization tasks required for a resource group contributor to be able to deploy a FinOps hub instance in Azure, like registering resource providers. To view the full list of tasks performed, run the command with the -WhatIf option.

<br>

## 🧮 Syntax

```powershell
Initialize-FinOpsHubDeployment `
    [-WhatIf <string>]
```

<br>

## 📥 Parameters

| Name      | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| '‑WhatIf' | Optional. Shows what would happen if the command runs without actually running it. |

|

<br>

## 🌟 Examples

### Test initialize FinOps hub deployment

```powershell
Initialize-FinOpsHubDeployment `
    -WhatIf
```

Shows what would happen if the command runs without actually running it.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
