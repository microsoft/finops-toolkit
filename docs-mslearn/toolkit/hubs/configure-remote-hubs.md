---
ms.service: finops
ms.author: flanakin
author: flanakin
ms.date: 11/01/2024
ms.topic: how-to
title: Configure remote hubs
description: Learn how to configure FinOps hubs to collect cost data across multiple Azure tenants and clouds using remote hub functionality.
---

# Configure remote hubs

Remote hubs enable cross-tenant cost data collection scenarios where a central tenant aggregates cost data from multiple tenants or subscriptions. In this setup, "satellite" FinOps hubs in different tenants send their processed data to a central "primary" hub for consolidated reporting and analysis.

Remote hubs work across different Azure clouds, supporting:
- Azure Commercial
- Azure Government 
- Azure operated by 21Vianet

<br>

## When to use remote hubs

Consider remote hubs when you have:

- Multiple Azure tenants with separate billing relationships
- A centralized FinOps team that needs visibility across multiple organizations
- Subsidiaries or business units in separate tenants
- Partners or customers who want to contribute cost data to a shared analysis
- Multi-cloud scenarios where you need cost data from different Azure cloud environments

<br>

## Architecture overview

In a remote hub configuration:

- **Primary hub**: Central FinOps hub that receives and stores aggregated data from all tenants
- **Remote (satellite) hubs**: FinOps hubs in remote tenants that process local cost data and send it to the primary hub

<br>

## Configure the primary hub

1. Deploy a standard FinOps hub in your central tenant using the regular deployment process
2. Note the storage account name (found in the resource group after deployment)
3. Get the Data Lake storage endpoint:
   - Navigate to the storage account in the Azure portal
   - Select **Settings** > **Endpoints**
   - Copy the **Data Lake storage** URL (format: `https://storageaccount.dfs.core.windows.net/`)
4. Get the storage account access key:
   - Navigate to **Security + networking** > **Access keys**
   - Copy **key1** or **key2** value

<br>

## Configure remote hubs

When deploying remote hubs, provide the primary hub's storage details:

### [Azure portal](#tab/azure-portal)

1. When deploying the FinOps hub template, navigate to the **Advanced** tab
2. Expand **Remote hub configuration**
3. Enter the **Remote hub storage URI** from the primary hub (copy from the primary hub's storage account Settings > Endpoints > Data Lake storage)
4. Enter the **Remote hub storage key** from the primary hub (copy from the primary hub's storage account Security + networking > Access keys > key1/2 > Key)
5. Complete the deployment normally

### [PowerShell](#tab/powershell)

```powershell
Deploy-FinOpsHub `
    -Name MyRemoteHub `
    -ResourceGroup MyRemoteHubResourceGroup `
    -Location westus `
    -RemoteHubStorageUri "https://primaryhubstore123.dfs.core.windows.net/" `
    -RemoteHubStorageKey "abc123...xyz789=="
```

---

<br>

## Security considerations

- **Version requirement**: Remote hubs support requires FinOps hub template version 0.4 or later
- **Storage keys**: Treat storage keys as secrets. They provide full access to the storage account
- **Network access**: Consider using private networking for both primary and remote hubs
- **Key rotation**: Regularly rotate storage keys and update remote hub configurations
- **Least privilege**: The storage key provides broad access; consider using Azure AD authentication when available

<br>

## Data flow and processing

Remote hubs process data locally and then send processed (not raw) cost data to the primary hub. This approach:

- Reduces data transfer costs
- Maintains data sovereignty for initial processing
- Centralizes only the final, processed cost data
- Preserves full granularity in the primary hub

<br>

## Next steps

- [Deploy a FinOps hub](deploy.md)
- [Configure private networking](private-networking.md)
- [Upgrade FinOps hubs](upgrade.md)