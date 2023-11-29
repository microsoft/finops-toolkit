---
layout: default
grand_parent: PowerShell
parent: FinOps hubs
title: Deploy-FinOpsHub
nav_order: 1
description: 'Deploys a FinOps hub instance.'
permalink: /powershell/hubs/Deploy-FinOpsHub
---

<span class="fs-9 d-block mb-4">Deploy-FinOpsHub</span>
Deploys a FinOps hub instance.
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

The **Deploy-FinOpsHub** command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub. To learn more about the template, see the [FinOps hub template](../../finops-hub/template.md).

Deploy-FinOpsHub calls [Initialize-FinOpsHubDeployment](Initialize-FinOpsHubDeployment.md) before deploying the template.

<br>

## 🧮 Syntax

```powershell
Deploy-FinOpsHub `
    -Name <string> `
    -ResourceGroup <string> `
    -Location <string> `
    [-Version <string>] `
    [-Preview] `
    [-StorageSku <string>] `
    [-Tags <object>] `
    [<CommonParameters>]
```

<br>

## 📥 Parameters

| Name          | Description                                                                                                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Name          | Required. Name of the FinOps hub instance.                                                                                                                                           |
| ResourceGroup | Required. Name of the resource group to deploy to. Will be created if it doesn't exist.                                                                                              |
| Location      | Required. Azure location to execute the deployment from.                                                                                                                             |
| Version       | Optional. Version of the FinOps hub template to use. Default = "latest".                                                                                                             |
| Preview       | Optional. Indicates that preview releases should also be included. Default = false.                                                                                                  |
| StorageSku    | Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default = "Premium_LRS". |
| Tags          | Optional. Tags for all resources.                                                                                                                                                    |

<br>

## 🌟 Examples

### Deploy latest version

```powershell
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyNewResourceGroup `
    -Location westus
```

Deploys a new FinOps hub instance named MyHub to a new resource group named MyNewResourceGroup.

### Deploy specific version

```powershell
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyExistingResourceGroup `
    -Location westus `
    -Version {% include version.txt %}
```

Deploys a new FinOps hub instance named MyHub to a new resource group named MyNewResourceGroup using version {% include version.txt %} of the template.

<br>

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
