---
title: Deploy-FinOpsHub command
description: Deploy a new or update an existing FinOps hub instance using the Deploy-FinOpsHub command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the what Deploy-FinOpsHub command in the FinOpsToolkit module.
---

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
    [-RemoteHubStorageUri <string>] `
    [-RemoteHubStorageKey <string>] `
    [-Tags <object>] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name                     | Description                                                                                                                                                                         |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`                  | Required. Name of the FinOps hub instance.                                                                                                                                          |
| `‑ResourceGroup`         | Required. Name of the resource group to deploy to. It gets created if it doesn't exist.                                                                                             |
| `‑Location`              | Required. Azure location to execute the deployment from.                                                                                                                            |
| `‑Version`               | Optional. Version of the FinOps hub template to use. Default = "latest".                                                                                                            |
| `‑Preview`               | Optional. Indicates that preview releases should also be included. Default = false.                                                                                                 |
| `‑StorageSku`            | Optional. Storage account SKU. Premium_LRS = Lowest cost, Premium_ZRS = High availability. Note Standard SKUs aren't available for Data Lake gen2 storage. Default = "Premium_LRS". |
| `‑RemoteHubStorageUri`   | Optional. Data Lake storage endpoint from the remote hub storage account. Used for cross-tenant cost data collection scenarios. Example: `https://primaryhub.dfs.core.windows.net/` |
| `‑RemoteHubStorageKey`   | Optional. Storage account access key for the remote hub. Used for cross-tenant cost data collection scenarios. Must be kept secure as it provides full storage access. |
| `‑Tags`                  | Optional. Tags for all resources.                                                                                                                                                   |

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

Deploys a FinOps hub instance named MyHub to the MyExistingResourceGroup resource group using version 0.1.1 of the template. This version is required for Microsoft Online Services Agreement (MOSA) subscriptions since FOCUS exports aren't available from Cost Management. If the resource group doesn't exist, it gets created. If the hub already exists, it gets updated to version 0.1.1.

### Deploy with remote hub configuration

```powershell
Deploy-FinOpsHub `
    -Name MyRemoteHub `
    -ResourceGroup MyRemoteHubResourceGroup `
    -Location westus `
    -RemoteHubStorageUri "https://centralfinooshub123.dfs.core.windows.net/" `
    -RemoteHubStorageKey "abc123...xyz789=="
```

Deploys a FinOps hub instance named MyRemoteHub configured to send data to a remote (central) hub. The remote hub storage URI and key enable cross-tenant data collection scenarios where a central tenant aggregates cost data from multiple tenants. The RemoteHubStorageUri should be copied from the central hub's storage account Settings > Endpoints > Data Lake storage, and the RemoteHubStorageKey should be copied from Security + networking > Access keys. Remote hubs require template version 0.4 or later.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20the%20FinOps%20toolkit%20PowerShell%20module%3F/cvaQuestion/How%20valuable%20are%20the%20FinOps%20toolkit%20PowerShell%20module%3F/surveyId/FTK/bladeName/PowerShell/featureName/Hubs.DeployHub)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20PowerShell%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../../power-bi/reports.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)


<br>
