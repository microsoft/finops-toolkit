---
title: Deploy-FinOpsHub command
description: Deploy a new or update an existing FinOps hub instance using the Deploy-FinOpsHub command in the FinOpsToolkit module.
author: bandersmsft
ms.author: banders
ms.date: 11/01/2024
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Deploy-FinOpsHub command in the FinOpsToolkit module.
---

<!-- markdownlint-disable-next-line MD025 -->
# Deploy-FinOpsHub command

The **Deploy-FinOpsHub** command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub. To learn more about the template, see the [FinOps hub template](../../hubs/template.md).

Deploy-FinOpsHub calls [Initialize-FinOpsHubDeployment](Initialize-FinOpsHubDeployment.md) before deploying the template.

<br>

## Syntax

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

## Parameters

| Name             | Description                                                                                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `‑Name`          | Required. Name of the FinOps hub instance.                                                                                                                                           |
| `‑ResourceGroup` | Required. Name of the resource group to deploy to. It gets created if it doesn't exist.                                                                                              |
| `‑Location`      | Required. Azure location to execute the deployment from.                                                                                                                             |
| `‑Version`       | Optional. Version of the FinOps hub template to use. Default = "latest".                                                                                                             |
| `‑Preview`       | Optional. Indicates that preview releases should also be included. Default = false.                                                                                                  |
| `‑StorageSku`    | Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs aren't available for Data Lake gen2 storage. Default = "Premium_LRS". |
| `‑Tags`          | Optional. Tags for all resources.                                                                                                                                                    |

<br>

## Examples

The following examples demonstrate how to use the Deploy-FinOpsHub command to deploy or update a FinOps hub instance.

### Deploy latest version

```powershell
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyNewResourceGroup `
    -Location westus
```

Deploys a FinOps hub instance named MyHub to the MyNewResourceGroup resource group. If the resource group doesn't exist, it gets created. If the hub already exists, it gets updated to the latest version.

### Deploy specific version

```powershell
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroup MyExistingResourceGroup `
    -Location westus `
    -Version 0.1.1
```

Deploys a FinOps hub instance named MyHub to the MyExistingResourceGroup resource group using version 0.1.1 of the template. This version is required in order to deploy to Azure Gov or Azure China as of February 2024 since FOCUS exports aren't available from Cost Management in those environments. If the resource group doesn't exist, it gets created. If the hub already exists, it gets updated to version 0.1.1.

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
