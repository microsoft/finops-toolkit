---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Register-FinOpsHubProviders
nav_order: 1
description: 'Register Azure resource providers required for FinOps hub.'
permalink: /powershell/hubs/Register-FinOpsHubProviders
---

<span class="fs-9 d-block mb-4">Register-FinOpsHubProviders</span>
Register Azure resource providers required for FinOps hub.
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

The **Register-FinOpsHubProviders** command registers the Azure resource providers required to deploy and operate a FinOps hub instance.

To register a resource provider, you must have Contributor access (or the /register permission for each resource provider) for the entire subscription. Subscription readers can check the status of the resource providers but cannot register them. If you do not have access to register resource providers, please contact a subscription contributor or owner to run the Register-FinOpsHubProviders command.

<br>

## 🧮 Syntax

```powershell
Register-FinOpsHubProviders `
    [-WhatIf <string>] `
```

<br>

## 📥 Parameters

| Name      | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| `‑WhatIf` | Optional. Shows what would happen if the command runs without actually running it. |

|

<br>

## 🌟 Examples

### Test register FinOps hub providers

```powershell
Register-FinOpsHubProviders `
    -WhatIf
```

Shows what would happen if the command runs without actually running it.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
