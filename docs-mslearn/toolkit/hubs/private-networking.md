---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
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

- Access is controlled via role-based access control (RBAC) and communications encrypted via transport layer security (TLS).
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
- Key vault is accessible via private IP address and trusted Azure services - firewall is set to default deny with bypass for services on trusted list.
- Azure  Data Factory is configured to use the public integration runtime, which helps reduce costs.
- A virtual network is deployed to ensure communication between all components during deployment and at runtime remains private.

:::image type="content" source="./media/private-networking/finops-hubs-private-network.png" border="false" alt-text="Screenshot of privately accessible deployments." lightbox="./media/private-networking/finops-hubs-private-network.png" :::

Note that private networking incurs extra cost for networking resources, connectivity, and dedicated compute in Azure Data Factory. For a detailed cost estimate, please refer to the Azure pricing calculator.

<br>

## Comparing network access options

The following table compares the network access options available in FinOps hubs:

| Component           | Public                        | Private                                                                                                                | Benefit                                                        |
| ------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Storage             | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (for example, corporate vNet), and trusted Azure services | Data only accessible when at work or on the corporate VPN      |
| Azure Data Explorer | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (for example, corporate vNet), and trusted Azure services | Data only accessible when at work or on the corporate VPN      |
| Key vault           | Accessible over the internet¹ | Access restricted to the FinOps hub network, peered networks (for example, corporate vNet), and trusted Azure services | Keys and secrets are never accessible via to the open internet |
| Azure Data Factory  | Uses public compute pool      | Managed integration runtime in a private network with Data Explorer, storage, and key vault                            | All data processing happens inside the network                 |
| Virtual Network     | Not used                      | FinOps hub traffic happens within an isolated vNet                                                                     | Everything remains private; ideal for regulated environments   |

_¹ While resources are accessible over the internet, access is still protected by role-based access control (RBAC)._

<br>

## Enabling private networking

To enable private networking when deploying a new or updating an existing FinOps hub instance, set **Access** to **Private** on the **Advanced** tab.

:::image type="content" source="./media/private-networking/finops-hubs-private-deployment.png" alt-text="Screenshot of secure private deployments." lightbox="./media/private-networking/finops-hubs-private-deployment.png" :::

Before enabling private access, review the networking details on this page to understand the extra configuration required in order to connect to your hub instance. Once enabled, your FinOps hub instance is inaccessible until network access is configured outside of the FinOps hub instance. We recommend sharing this with your network admins to ensure the IP range meets network standards and they understand how to connect your hub instance to the existing network.

<br>

## FinOps hub virtual network

When private access is selected, your FinOps hub instance includes a virtual network to ensure communication between its various components remain private.

- The virtual network should be a **/26** (64 IP addresses) in size. This setting enables the minimum required subnet sizes for Container Services (used during deployments for running scripts) and Data Explorer.
- The IP range can be set at the time of deployment and defaults to **10.20.30.0/26**.

If necessary, you can create the virtual network, subnets, and optionally peer it with your hub network before deploying FinOps hubs if you follow these requirements:

- The virtual network should be a **/26** (64 IP addresses in size).
- The name should be `<HubName>-vNet`.
- The virtual network must be divided into three subnets with the service delegations as specified:
  - **private-endpoint-subnet** (**/28**) – no service delegations configured; hosts private endpoints for storage and key vault.
  - **script-subnet** (**/28**) – delegated to container services for running scripts during deployment.
  - **dataExplorer-subnet** (**/27**) – delegated to Azure Data Explorer.

<br>

## Private endpoints and DNS

Communication between the various FinOps hub components is encrypted using TLS. For TLS certificate validation to succeed when using private networking, reliable domain name system (DNS) name resolution is required. DNS zones, private endpoints, and DNS entries guarantee name resolution between FinOps hub components.

<!-- cSpell:ignore privatelink, vaultcore -->
- **privatelink.blob.core.windows.net** – for Data Explorer and storage used by deployment scripts
- **privatelink.dfs.core.windows.net** – for Data Explorer and the data lake hosting the FinOps data and pipeline configuration
- **privatelink.table.core.windows.net** – for Data Explorer
- **privatelink.queue.core.windows.net** – for Data Explorer
- **privatelink.vaultcore.azure.net** – for Azure Key Vault
- **privatelink.{location}.kusto.windows.net** – for Data Explorer

> [!IMPORTANT]
> Altering the DNS configuration of the FinOps hub virtual network isn't recommended. FinOps hub components require reliable name resolution for deployments and upgrades to succeed. Data Factory pipelines also require reliable name resolution between components.

<br>

## Network peering, routing, and name resolution

When private access is selected, the FinOps hub instance is deployed to an isolated spoke virtual network. Multiple options exist to enable private connectivity to the FinOps hub virtual network including:

- Peering the FinOps hub network with another Azure vNet.
- Peering the FinOps hub network with an Azure vWAN hub.
- Extending the FinOps hub network address space and deploying a VPN gateway.
- Extending the FinOps hub network address space and deploying a Power BI data gateway.
- Allowing one's corporate firewall and VPN IP ranges access over the public internet via the storage and Data Explorer firewalls.

To access FinOps hub data from an existing virtual network, configure **A** records in your existing virtual network to access storage or Data Explorer. **CNAME** records may also be required depending on your DNS solution.

| Required     | Name                                                                | Description                         |
| ------------ | ------------------------------------------------------------------- | ----------------------------------- |
| **Required** | <storage_account_name>.privatelink.dfs.core.windows.net             | A record to access storage          |
| **Optional** | <storage_account_name>.dfs.core.windows.net                         | CNAME to the storage A record       |
| **Required** | <data_explorer_name>.privatelink.<azure_location>.kusto.windows.net | A record to access Data Explorer    |
| **Optional** | <data_explorer_name>.<azure_location>.kusto.windows.net             | CNAME to the Data Explorer A record |

> [!IMPORTANT]
> When using private endpoints in conjunction with a Power BI data gateway, make sure to use the fully qualified domain name (FQDN) of the Azure Data Explorer cluster (like `clustername.region.kusto.windows.net`) rather than the abbreviated version (like `clustername.region`). This ensures proper name resolution for the private endpoint functions as expected.

<br>

## Network peering example

In this example:

- The FinOps hub virtual network is peered to a network hub.
- Azure firewall acts as core the router.
- DNS entries for storage and Data Explorer are added to Azure DNS Resolver to ensure reliable name resolution.
- A route table is attached to the network gateway subnet to ensure traffic from on-premises can route to the peered vNet.

:::image type="content" source="./media/private-networking/finops-hubs-network-peering.png" border="false" alt-text="Screenshot of network peering configuration." lightbox="./media/private-networking/finops-hubs-network-peering.png" :::

This network topology follows the Hub-Spoke network architecture guidance outlined in the [Cloud Adoption Framework](/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) for Azure and the [Azure Architecture Center](/azure/architecture/networking/architecture/hub-spoke).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.11/bladeName/Hubs/featureName/PrivateNetworking)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

- [Configure scopes](configure-scopes.md)
- [Connect to Power BI](../power-bi/setup.md)
- [Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>
