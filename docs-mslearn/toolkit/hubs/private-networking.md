---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: bandersmsft
ms.author: banders
ms.date: 02/13/2025
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps toolkit user, I want to learn about how to configure private access to my data so that I can secure it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure private networking in FinOps hubs

As organizations increasingly adopt cloud services, ensuring secure and efficient access to these resources becomes paramount. FinOps hubs offer flexible options to support public or private access to data networking, depending on your needs. This guide explains how each data access option works and how to configure private networking to securely access data in FinOps hubs.

<br>

## How public access works

Public access in FinOps hubs has the following traits:

- Access is controlled via RBAC and communications encrypted via TLS.
- Storage is accessible via public IP addresses (firewall set to public).
- Data Explorer (if deployed) is accessible via public IP addresses (firewall set to public).
- Key Vault is accessible via public IP addresses (firewall set to public).
- Azure Data Factory is configured to use the public integration runtime.

:::image type="content" source="./media/private-networking/finops-hubs-public-network.png" border="false" alt-text="Screenshot of publicly accessible deployments." lightbox="./media/private-networking/finops-hubs-public-network.png" :::

<br>

## How private access works

Private access is a more secure option that places FinOps hubs resources on an isolated network and limits access via private networking:

- Public network access is disabled by default.
- Storage is accessible via private IP address and trusted Azure services - firewall is set to default deny with bypass for services on trusted list.
- Data Explorer (if deployed) is accessible via private IP address - firewall is set to default deny with no exceptions.
- Key vault is accessible via private IP address and trusted azure services - firewall is set to default deny with bypass for services on trusted list.
- Azure Data Factory is configured to use the public integration runtime, which helps reduce costs.
- A virtual network is deployed to ensure communication between all components during deployment and at runtime remains private.

:::image type="content" source="./media/private-networking/finops-hubs-private-network.png" border="false" alt-text="Screenshot of privately accessible deployments." lightbox="./media/private-networking/finops-hubs-private-network.png" :::

Please note that private networking incurs additional cost for networking resources, connectivity, and dedicated compute in Azure Data Factory. The following table portrays the additional cost when private networking is enabled:

| Service category | Service             | Description                            | Estimated monthly cost |
| ---------------- | ------------------- | -------------------------------------- | ---------------------- |
| Analytics        | Azure Data Explorer | ADF Pipeline execution & data movement | $444.13                |
| Networking       | Azure private link  | Private endpoint costs                 | $38.50                 |

These estimates are based on list prices without discounts based on the following monthly usage patterns:

- Azure Data Factory V2, Data Pipeline Service Type, Azure Integration Runtime
  - 0 activity run(s)
  - 0 data movement unit(s)
  - 100 pipeline activities
  - 100 pipeline activities – External
- Azure vNet integration runtime
  - 0 activity run(s)
  - 100 data movement unit(s)
  - 100 pipeline activities
  - 100 pipeline activities – External
- Data Flow
  - 1 x 8 general purpose vCores x 100 hours
  - 0 x 8 memory optimized vCores x 730 hours
- Azure Private Link
  - 5 endpoints x 730 hours
  - 100 GB Outbound data processed
  - 100 GB Inbound data processed

<br>

## Comparing network access options

The following table compares the network access options available in FinOps hubs:

| Component           | Public                        | Private                                                                                                         | Benefit                                                        |
| ------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Storage             | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (e.g., corporate vNet), and trusted Azure services | Data only accessible when at work or on the corporate VPN      |
| Azure Data Explorer | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (e.g., corporate vNet), and trusted Azure services | Data only accessible when at work or on the corporate VPN      |
| Key vault           | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (e.g., corporate vNet), and trusted Azure services | Keys and secrets are never accessible via to the open internet |
| Azure Data Factory  | Uses public compute pool      | Managed integration runtime in a private network with Data Explorer, storage, and key vault                     | All data processing happens inside the network                 |
| Virtual Network     | Not used                      | FinOps hub traffic happens within an isolated vNet                                                              | Everything remains private; ideal for regulated environments   |

_¹ While resources are accessible over the internet, access is still protected by role-based access control (RBAC)._

<br>

## Enabling private networking

When deploying a new FinOps hub instance, you'll see a few new options in the deployment form (or template parameters, if deploying programmatically). You'll find networking options on the **Advanced** tab where you can set **Access** to either **Public** or **Private**, depending on your needs.

:::image type="content" source="./media/private-networking/finops-hubs-private-deployment.png" border="false" alt-text="Screenshot of secure private deployments." lightbox="./media/private-networking/finops-hubs-private-deployment.png" :::

Before enabling private access, please review the details below to understand the additional configuration required in order to connect to your hub instance. Once enabled, you will not be able to connect to FinOps hubs until network access is configured outside of the FinOps hub instance.

<br>

## FinOps hub virtual network

When private access is selected, your FinOps hub instance will include a virtual network to ensure communication between its various components remain private.

- The virtual network should be a **/26** (64 IP addresses) in size. This is to accommodate the minimum required subnet sizes for Container Services (used during deployments for running scripts) and Data Explorer.
- The IP range can be set at the time of deployment and defaults to **10.20.30.0/26**.

If required, you can pre-create the virtual network and subnets (and optionally peer it with your hub network) provided you follow these requirements:

- The virtual network should be a **/26** (64 IP addresses in size).
- The name should be `<HubName>-vNet`.
- The virtual network must be divided into 3 subnets with the service delegations as specified:
  - **private-endpoint-subnet** (**/28**) – no service delegations configured; hosts private endpoints for storage and key vault.
  - **script-subnet** (**/28**) – delegated to container services for running scripts during deployment.
  - **dataExplorer-subnet** (**/27**) – delegated to Azure Data Explorer.

<br>

## Private endpoints and DNS

Communication between the various FinOps hub components is encrypted using TLS.  For TLS certificate validation to succeed when using private IP addressing reliable DNS name resolution is required. During private deployments DNS zones will be created and bound to the VNet, and the necessary private endpoints and DNS entries for the hub components will be created to guarantee name resolution between them.

<!-- cSpell:ignore privatelink, vaultcore -->
- **privatelink.blob.core.windows.net** – for Data Explorer and storage used by deployment scripts
- **privatelink.dfs.core.windows.net** – for Data Explorer and the data lake hosting the FinOps data and pipeline configuration
- **privatelink.table.core.windows.net** – for Data Explorer
- **privatelink.queue.core.windows.net** – for Data Explorer
- **privatelink.vaultcore.azure.net** – for Azure Key Vault
- **privatelink.{location}.kusto.windows.net** – for Data Explorer

> [!IMPORTANT]
> Altering the DNS configuration of the FinOps hub virtual network is not recommended. FinOps hub components require reliable name resolution for deployments and upgrades to succeed. ETL pipelines in Azure Data Factory also require reliable name resolution between components.

<br>

## Network peering, routing, and name resolution

When private access is selected the FinOps hub workload is deployed to an isolated spoke virtual network. Multiple options exist to enable private connectivity to the FinOps hub virtual network including:

1. Peering the FinOps hub network with another Azure vNet.
1. Peering the FinOps hub network with an Azure vWAN hub.
1. Extending the FinOps hub network address space and deploying a VPN gateway.
1. Extending the FinOps hub network address space and deploying a Power BI data gateway.
1. Allowing one's corporate firewall and VPN IP ranges access over the public internet via the storage and Data Explorer firewalls.

To enable private access to FinOps hub data from outside the virtual network (when peering to another virtual network) only the private IP address of Data Explorer and storage need to be resolved to a DNS name.

The **A** records are required. The **CNAME** records may also be required depending on your DNS solution:

| Required     | Name                                                                | Description                      |
| ------------ | ------------------------------------------------------------------- | -------------------------------- |
| **Required** | <storage_account_name>.privatelink.dfs.core.windows.net             | A record for Azure Data Lake     |
| **Optional** | <storage_account_name>.dfs.core.windows.net                         | CNAME to A record                |
| **Required** | <data_explorer_name>.privatelink.<azure_location>.kusto.windows.net | A record for Azure Data Explorer |
| **Optional** | <data_explorer_name>.<azure_location>.kusto.windows.net             | CNAME to A record                |

<br>

## Network peering example

In this example:

- The FinOps hub virtual network is peered to a network hub.
- Azure firewall acts as core the router.
- DNS entries for storage and Data Explorer have been added to Azure DNS Resolver to ensure reliable name resolution.
- A route table has been attached to the network gateway subnet to ensure traffic from on-premise can route to the peered vNet.

:::image type="content" source="./media/private-networking/finops-hubs-network-peering.png" border="false" alt-text="Screenshot of privately accessible deployments." lightbox="./media/private-networking/finops-hubs-network-peering.png" :::

This network topology follows the Hub-Spoke network architecture guidance outlined in the [Cloud Adoption Framework](/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) for Azure and the [Azure Architecture Center](/azure/architecture/networking/architecture/hub-spoke).

<br>

## Related content

- [Configure scopes](configure-scopes.md)
- [Connect to Power BI](../power-bi/setup.md)
- [Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>
