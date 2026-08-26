---
title: Deploy-FinOpsHub command
description: Deploy a new or update an existing FinOps hub instance using the Deploy-FinOpsHub command in the FinOpsToolkit module.
author: flanakin
ms.author: micflan
ms.date: 06/03/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to use the Deploy-FinOpsHub command in the FinOpsToolkit module.
---

# Deploy-FinOpsHub command

The **Deploy-FinOpsHub** command either creates a new or updates an existing FinOps hub instance by deploying an Azure Resource Manager deployment template. The FinOps hub template is downloaded from GitHub. To learn more about the template, see the [FinOps hub template](../../hubs/template.md).

Deploy-FinOpsHub calls [Initialize-FinOpsHubDeployment](Initialize-FinOpsHubDeployment.md) before deploying the template.

<br>

## Syntax

```powershell
Deploy-FinOpsHub `
    [‑Name] <string> `
    [‑ResourceGroupName] <string> `
    [‑Location] <string> `
    [[‑Version] <string>] `
    [‑Preview] `
    [[‑StorageSku] <string>] `
    [‑EnableInfrastructureEncryption] `
    [‑EnablePurgeProtection] `
    [[‑RemoteHubStorageUri] <string>] `
    [[‑RemoteHubStorageKey] <string>] `
    [‑EnableManagedExports] `
    [[‑DataExplorerName] <string>] `
    [[‑DataExplorerSku] <string>] `
    [[‑DataExplorerCapacity] <int>] `
    [[‑FabricQueryUri] <string>] `
    [[‑FabricCapacityUnits] <int>] `
    [[‑DataExplorerRawRetentionInDays] <int>] `
    [[‑DataExplorerFinalRetentionInMonths] <int>] `
    [[‑NetworkMode] <string>] `
    [‑DisablePublicAccess] `
    [[‑VirtualNetworkAddressPrefix] <string>] `
    [[‑Tags] <hashtable>] `
    [[‑TagsByResource] <hashtable>] `
    [[‑ScopesToMonitor] <String[]>] `
    [[‑ExportRetentionInDays] <int>] `
    [[‑IngestionRetentionInMonths] <int>] `
    [‑WhatIf] `
    [<CommonParameters>]
```

<br>

## Parameters

| Name                                  | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `‑Name`                               | Required. Name of the hub. Used to ensure unique resource names.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `‑ResourceGroupName`                  | Required. Name of the resource group to deploy to. Will be created if it doesn't exist.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `‑Location`                           | Required. Azure location where all resources should be created. See https://aka.ms/azureregions.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `‑Version`                            | Optional. Version of the FinOps hub template to use. Default = "latest".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `‑Preview`                            | Optional. Indicates that preview releases should also be included. Default = false.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `‑StorageSku`                         | Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: Premium_LRS, Premium_ZRS. Default: Premium_LRS.                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `‑EnableInfrastructureEncryption`     | Optional. Enable infrastructure encryption on the storage account. Default = false.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `‑EnablePurgeProtection`              | Optional. Enable purge protection for the Key Vault. Default = false.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑RemoteHubStorageUri`                | Optional. Storage account to push data to for ingestion into a remote hub.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `‑RemoteHubStorageKey`                | Optional. Storage account key to use when pushing data to a remote hub.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `‑EnableManagedExports`               | Optional. Enable managed exports where your FinOps hub instance creates and runs Cost Management exports on your behalf. Not supported for Microsoft Customer Agreement (MCA) billing profiles. Default = false.                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `‑DataExplorerName`                   | Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑DataExplorerSku`                    | Optional. Name of the Azure Data Explorer SKU. Default: "Dev(No SLA)_Standard_E2a_v4".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `‑DataExplorerCapacity`               | Optional. Number of nodes to use in the cluster. Allowed values: 1 for the Basic SKU tier and 2-1000 for Standard. Default: 1 for dev/test SKUs, 2 for standard SKUs.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑FabricQueryUri`                     | Optional. Microsoft Fabric eventhouse query URI. Default: "" (do not use).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `‑FabricCapacityUnits`                | Optional. Number of capacity units for the Microsoft Fabric capacity. This is the number in your Fabric SKU (e.g., Trial = 1, F2 = 2, F64 = 64). Allowed values: 1-2048. Default: 2.                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `‑DataExplorerRawRetentionInDays`     | Optional. Number of days of data to retain in the Data Explorer *_raw tables. Default: 0.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `‑DataExplorerFinalRetentionInMonths` | Optional. Number of months of data to retain in the Data Explorer *_final_v* tables. Default: 13.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `‑NetworkMode`                        | Optional. Network mode for the hub: 'public' (default), 'vnet' (private endpoints, default outbound), or 'private' (private endpoints + NAT Gateway for controlled outbound access - required when the 'Subnets should be private' policy is enforced).                                                                                                                                                                                                                                                                                                                                                                                                         |
| `‑DisablePublicAccess`                | Optional. Deprecated. Use -NetworkMode 'vnet' or -NetworkMode 'private' instead. When set without -NetworkMode, behaves as -NetworkMode 'vnet'. Ignored when -NetworkMode is supplied.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `‑VirtualNetworkAddressPrefix`        | Optional. Address space for the workload. A /26 is required for the workload. Default: "10.20.30.0/26".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `‑Tags`                               | Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `‑TagsByResource`                     | Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `‑ScopesToMonitor`                    | Optional. Array of scope IDs to monitor and ingest cost for. Used with managed exports to automatically create Cost Management exports. Scope ID formats:<br>- EA billing account: /providers/Microsoft.Billing/billingAccounts/{enrollment-number}<br>- MCA billing profile: /providers/Microsoft.Billing/billingAccounts/{billing-account-id}/billingProfiles/{billing-profile-id}<br>- Subscription: /subscriptions/{subscription-id}<br>- Resource group: /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}<br>Example: @('/subscriptions/00000000-0000-0000-0000-000000000000', '/subscriptions/11111111-1111-1111-1111-111111111111') |
| `‑ExportRetentionInDays`              | Optional. Number of days of data to retain in the msexports container. Default: 0.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `‑IngestionRetentionInMonths`         | Optional. Number of months of data to retain in the ingestion container. Default: 13.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `‑WhatIf`                             | Optional. Shows what would happen if the command runs without actually running it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |

> [!NOTE]
> Not all Data Explorer SKUs are available in every region. If deployment fails with a SKU error, see [common errors](../../help/errors.md#the-sku-skuname-is-not-supported-in-region).

<br>

## Examples

The following examples demonstrate how to use the Deploy-FinOpsHub command to deploy or update a FinOps hub instance.

### Deploy latest version

```powershell
Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyNewResourceGroup -Location westus -DataExplorerName MyFinOpsHubCluster
```

Deploys a FinOps hub instance named MyHub to the MyNewResourceGroup resource group with a new MyFinOpsHubCluster Data Explorer cluster. If the resource group does not exist, it will be created. If the hub already exists, it will be updated to the latest version.

### Deploy specific version

```powershell
Deploy-FinOpsHub -Name MyHub -ResourceGroupName MyExistingResourceGroup -Location westus -Version 0.1.1
```

Deploys a FinOps hub instance named MyHub to the MyExistingResourceGroup resource group using version 0.1.1 of the template. This version is required for Microsoft Online Services Agreement (MOSA) subscriptions since FOCUS exports aren't available from Cost Management. If the resource group does not exist, it will be created. If the hub already exists, it will be updated to version 0.1.1.

### Deploy with remote hub configuration

```powershell
Deploy-FinOpsHub -Name MyRemoteHub -ResourceGroupName MyRemoteHubResourceGroup -Location westus -RemoteHubStorageUri "https://centralfinopshub123.dfs.core.windows.net/" -RemoteHubStorageKey "abc123...xyz789=="
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
