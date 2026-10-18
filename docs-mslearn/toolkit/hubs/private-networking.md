---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: flanakin
ms.author: micflan
ms.date: 08/23/2026
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps toolkit user, I want to learn about how to configure private access to my data so that I can secure it.
---

# Configure private networking in FinOps hubs

As organizations increasingly adopt cloud services, ensuring secure and efficient access to these resources becomes paramount. FinOps hubs offer flexible options to support public or private access to data networking, depending on your needs. This guide explains how each data access option works and how to configure private networking to securely access data in FinOps hubs.

<br>

## How public access works

Public access in FinOps hubs has the following traits:

- Access is controlled via role-based access control (RBAC) and communications encrypted via transport layer security (TLS).
- Storage is accessible via public IP addresses (firewall set to public).
- Data Explorer (if deployed) is accessible via public IP addresses (firewall set to public).
- Key Vault is accessible via public IP addresses (firewall set to public).
- Azure Data Factory uses the default Azure integration runtime.

The default Azure integration runtime calls Cost Management APIs to create and run exports. Cost Management writes export files to Storage. Data Factory pipelines then process the files and, if deployed, load Data Explorer. Remote hubs use Key Vault for secrets.

:::image type="content" source="./media/private-networking/finops-hubs-public-network.png" border="false" alt-text="Diagram of public routing between Cost Management, Data Factory, Storage, Data Explorer, and Key Vault." lightbox="./media/private-networking/finops-hubs-public-network.png" :::

<br>

## How private access works

Private routing uses service-specific network controls and private endpoints for data access:

- Storage is accessible through a private IP address. Its public endpoint remains enabled, but the firewall denies access by default and allows trusted Azure services.
- Data Explorer (if deployed) disables public network access and is accessible through a private IP address.
- Key Vault (remote hubs only) is accessible through a private IP address. Its firewall denies access by default and allows trusted Azure services.
- Azure Data Factory uses a managed integration runtime in a separate Data Factory managed virtual network for data-store traffic. The default Azure integration runtime runs Cost Management API activities.
- The FinOps hub virtual network contains Toolkit-managed private endpoints and deployment and runtime subnets.

:::image type="content" source="./media/private-networking/finops-hubs-private-network.png" border="false" alt-text="Diagram of private routing through FinOps hub and Data Factory managed virtual networks to hub services." lightbox="./media/private-networking/finops-hubs-private-network.png" :::

### Security posture

Private routing separates data-plane traffic from trusted-service and management-plane traffic. Customer access to Storage and Data Explorer uses private endpoints. Data Factory moves pipeline data through managed private endpoints and calls Cost Management APIs through the default Azure integration runtime. The Storage firewall allows trusted Azure services so Cost Management exports can write cost data. Data Factory management remains available in the Azure portal, so operators can author and monitor pipelines without connecting to the FinOps hub virtual network.

These paths don't provide general internet access to data. Role-based access control, service authentication, and default-deny firewall rules continue to protect access.

The FinOps toolkit exclusively owns and manages the FinOps hub virtual network, its three subnets, private endpoints, private DNS, routing, and related resources. This network supports FinOps hub deployment and operation; it isn't a shared network for customer resources.

Don't add customer workloads, subnets, gateways, endpoints, DNS, route tables, or other configuration inside the Toolkit-managed virtual network. The Toolkit doesn't preserve customer additions during deployment or upgrade operations.

Private networking adds costs for networking resources, connectivity, and dedicated compute in Azure Data Factory. For a detailed estimate, see the Azure pricing calculator.

<br>

## Preferred option: customer-managed private endpoints

For private access from your network, create and manage private endpoints and DNS in your own virtual network for the FinOps hub Storage and Azure Data Explorer resources. This topology is preferred because it keeps customer networking separate from the Toolkit-managed virtual network. The Toolkit doesn't deploy or manage resources in your network.

Create the following private endpoints:

| Resource | Target subresources | DNS configuration |
| --- | --- | --- |
| FinOps hub Storage | `blob` and `dfs` | Link private DNS zones for both subresources |
| Azure Data Explorer (if deployed) | `cluster` | Use the `requiredZoneNames` returned by the cluster's `privateLinkResources` API |

DNS zone names vary by Azure cloud. Use the values for your cloud in [Azure Private Endpoint private DNS zone values](/azure/private-link/private-endpoint-dns). For more information about the Data Explorer endpoint, see [Create a private endpoint for Azure Data Explorer](/azure/data-explorer/security-network-private-endpoint-create).

:::image type="content" source="./media/private-networking/finops-hubs-customer-endpoints.png" border="false" alt-text="Diagram of customer-managed Storage and Data Explorer private endpoints, with separate FinOps hub and Data Factory networks." lightbox="./media/private-networking/finops-hubs-customer-endpoints.png" :::

The endpoint and DNS symbols in the diagram represent the complete set required for each resource. Azure Private Link connects these endpoints directly to Storage and Azure Data Explorer without entering or peering with the FinOps hub virtual network. The Toolkit-managed virtual network remains deployed for internal connectivity. For configuration guidance, see [Private Endpoint overview](/azure/private-link/private-endpoint-overview) and [Private Endpoint DNS integration](/azure/private-link/private-endpoint-dns-integration).

If you use a Power BI virtual network data gateway, deploy it in your own virtual network and plan enough subnet address space for the gateway. Don't deploy the gateway in the FinOps hub virtual network. When you connect to Azure Data Explorer, use the fully qualified domain name (FQDN) shown for the cluster in Azure. Don't use an abbreviated cluster name.

<br>

## Comparing network access options

The following table compares the network access options available in FinOps hubs:

| Component           | Public                        | Private                                                                                                                 | Benefit                                                        |
| ------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Storage             | Accessible over the internet¹ | Customer-managed private endpoints in your virtual network (preferred) or customer-managed peering (secondary)          | Data access can remain private to your network                 |
| Azure Data Explorer | Accessible over the internet¹ | Customer-managed private endpoints in your virtual network (preferred) or customer-managed peering (secondary)          | Data access can remain private to your network                 |
| Key Vault (remote hubs only) | Accessible over the internet¹ | Access through Toolkit-managed private endpoints and trusted Azure services                                     | Keys and secrets aren't accessible from the open internet      |
| Azure Data Factory  | Uses the default Azure integration runtime | Uses the managed integration runtime for data-store traffic and the default Azure integration runtime for management-plane activities | Data-store traffic uses managed private endpoints |
| Virtual Network     | Not used                      | Toolkit-owned FinOps hub virtual network for private endpoints and deployment and runtime subnets                        | Toolkit networking remains separate from customer resources    |

_¹ While resources are accessible over the internet, access is still protected by role-based access control (RBAC)._

<br>

## Enabling private networking

To enable private networking when deploying a new or updating an existing FinOps hub instance, set **Access** to **Private** on the **Advanced** tab.

:::image type="content" source="./media/private-networking/finops-hubs-private-deployment.png" alt-text="Screenshot of secure private deployments." lightbox="./media/private-networking/finops-hubs-private-deployment.png" :::

Before enabling private access, review the networking details on this page and coordinate with your network admins. Configure customer-managed private endpoints and DNS in your own network (preferred), or use the secondary peering option, before users and systems connect to the hub.

<br>

## Removing private networking

If you need to reduce costs or simplify your FinOps hub deployment, you can switch back to public access. Redeploying with **Access** set to **Public** configures Storage, Data Explorer (if deployed), and Key Vault to use public access and switches Azure Data Factory back to the default Azure integration runtime.

The incremental deployment retains the Toolkit-created virtual network, network security groups, private endpoints, private DNS zones, deployment-script Storage account, Data Factory managed virtual network and private endpoints, managed integration runtime, and optional NAT Gateway and static public IP address. Customer-managed resources in your network are also outside the Toolkit deployment and aren't removed.

Retained resources don't all have standing charges. Private endpoints, private DNS zones, NAT Gateway, public IP address, and data in the deployment-script Storage account can continue to accrue charges. The managed integration runtime can also continue to incur compute charges during its configured time to live (TTL) after an activity completes: 10 minutes for data flows and 30 minutes for copy, pipeline, and external compute.

> [!WARNING]
> Removing private networking is a significant change that will affect how you access your FinOps hub. Ensure all stakeholders understand the security implications before proceeding.

### Steps to remove private networking

1. **Plan the transition**:

   - Identify all users and systems that access the hub through private networking.
   - Coordinate the change with your network administrators.
   - Schedule a maintenance window because the hub is temporarily unavailable during the transition.

2. **Update the FinOps hub deployment**:

   You have two options to redeploy your FinOps hub with public access:

   **Option 1: Redeploy from existing deployment**

   - In the Azure portal, open the FinOps hub resource group.
   - In the resource group menu, select **Deployments**.
   - Open the original FinOps hub deployment.
   - Select **Redeploy**.
   - On the **Advanced** tab, set **Access** to **Public**.
   - Review the other settings.
   - Deploy the updated configuration.

   **Option 2: Deploy latest toolkit version**

   - Install the latest version of the FinOps toolkit.
   - Use the same resource group name, hub name, and Data Explorer cluster name as the existing deployment.
   - Get these values from the original deployment template or the `config.json` file in the hub storage account.
   - On the **Advanced** tab, set **Access** to **Public**.
   - Deploy the same configuration to update the existing hub.

3. **Verify the changes**:

   - Confirm that Storage, Data Explorer, and Key Vault are accessible through public endpoints.
   - Test data access from Power BI and other connected systems.
   - Verify that Azure Data Factory pipelines continue to run successfully.

4. **Clean up private networking resources** (optional):

   - After you confirm the hub works with public access, delete only Toolkit-created resources that you no longer need.
   - Delete resources in the following order to avoid dependency conflicts:
     1. Delete the Data Factory managed private endpoints, managed integration runtime, and managed virtual network.
     2. Delete the Toolkit-created private endpoints.
     3. Delete the private DNS zones.
     4. Delete the virtual network and network security groups (NSGs).
     5. Delete the NAT Gateway and static public IP address, if deployed.
     6. Delete the deployment-script Storage account.
   - Don't delete customer-managed networking resources as part of the FinOps hub cleanup.

> [!NOTE]
> After removing private networking, your FinOps hub data will be accessible over the internet, though still protected by role-based access control (RBAC) and transport layer security (TLS). Review your organization's security policies to ensure this meets your requirements.
>
> **Security recommendations:**
>
> - Check the security settings on storage accounts and Azure Data Explorer clusters to ensure they align with your security requirements
> - Consider using network security groups (NSGs) or firewall rules to restrict access to well-known IP addresses such as your corporate firewall, VPN endpoints, or specific office locations
> - Review and configure storage account network access rules to limit access from trusted networks if needed
> - Verify that Azure Data Explorer cluster network settings are properly configured for your access requirements

<br>

## FinOps hub virtual network

When private access is selected, the Toolkit creates and exclusively manages the FinOps hub virtual network, its three subnets, private endpoints, private DNS, routing, and related resources. The network supports private communication between hub components.

- The virtual network address range can be any size from **/8** through **/26**, with a minimum address space of **/26** (64 IP addresses). The default is **/26** to conserve IP addresses while providing the minimum required subnet sizes for Azure Container Instances deployment scripts and Data Explorer.
- The IP range can be set at the time of deployment and defaults to **10.20.30.0/26**. The Toolkit divides the range into three subnets:
  - **private-endpoint-subnet** (**/28**) – hosts private endpoints for Storage, deployment-script Storage, and Key Vault (remote hubs only).
  - **script-subnet** (**/28**) – delegated to Azure Container Instances for running deployment scripts.
  - **dataExplorer-subnet** (**/27**) – hosts the private endpoint for Data Explorer.
- If you use a Power BI virtual network data gateway, plan additional subnet address space in your own virtual network, not in the FinOps hub virtual network.

Don't precreate, extend, or modify the FinOps hub virtual network or its subnets. Don't place customer workloads, subnets, gateways, endpoints, DNS, route tables, or other configuration in this network.

<br>

## Private endpoints and DNS

Communication between the various FinOps hub components is encrypted using TLS. For TLS certificate validation to succeed when using private networking, reliable Domain Name System (DNS) name resolution is required. The Toolkit creates and manages DNS zones, private endpoints, and DNS entries that guarantee name resolution between FinOps hub components.

The following names apply to Azure Commercial. For other supported clouds, the Toolkit uses the corresponding cloud-specific suffixes. See [Azure Private Endpoint private DNS zone values](/azure/private-link/private-endpoint-dns).

<!-- cSpell:ignore privatelink, vaultcore -->

- **privatelink.blob.core.windows.net** – for Data Explorer and the data lake
- **privatelink.dfs.core.windows.net** – for the data lake hosting the FinOps data and pipeline configuration
- **privatelink.file.core.windows.net** – for storage used by deployment scripts
- **privatelink.table.core.windows.net** – for Data Explorer
- **privatelink.queue.core.windows.net** – for Data Explorer
- **privatelink.vaultcore.azure.net** – for Azure Key Vault (remote hubs only)
- **privatelink.{location}.kusto.windows.net** – for Data Explorer

> [!IMPORTANT]
> Don't alter the DNS configuration of the FinOps hub virtual network. FinOps hub components require reliable name resolution for deployments and upgrades to succeed. Data Factory pipelines also require reliable name resolution between components.

<br>

## Network peering, routing, and name resolution

Customer-managed private endpoints in your own virtual network are the preferred private-access topology. As a secondary option, you can use virtual network peering to connect your network to the isolated FinOps hub virtual network. Peering doesn't make the FinOps hub virtual network a shared network: don't place customer workloads or networking resources inside it.

Secondary connectivity options include:

- Peering the FinOps hub virtual network with another Azure virtual network.
- Connecting the FinOps hub virtual network to an Azure Virtual WAN hub.
- Allowing approved IP ranges through the Storage firewall. Data Explorer's public endpoint remains disabled in private mode.

To access FinOps hub data from a peered virtual network, configure your DNS solution to resolve each private endpoint FQDN to its private IP address. The Toolkit-managed private DNS zones are linked only to the FinOps hub virtual network and don't resolve names for peered networks. Use the private endpoint's **DNS configuration** page or network interface to get the FQDNs and private IP addresses.

| Resource | Required DNS records |
| --- | --- |
| FinOps hub Storage | Create **A** records for both the `blob` and `dfs` private endpoint FQDNs. |
| Azure Data Explorer (if deployed) | Create **A** records for every FQDN in the private endpoint's DNS configuration. Use every zone returned in the cluster's `requiredZoneNames`. |

Your DNS solution might also require **CNAME** records from service FQDNs to private-link FQDNs. DNS suffixes vary by Azure cloud, so use the values from the deployed private endpoints instead of hardcoding Azure Commercial suffixes.

> [!IMPORTANT]
> When you use private endpoints with a Power BI data gateway, use the fully qualified domain name (FQDN) shown for the Data Explorer cluster in Azure. Don't use an abbreviated cluster name.

<br>

## Network peering example

In this example:

- The FinOps hub virtual network and DNS resolver virtual network are each peered to the connectivity hub virtual network.
- The connectivity hub peering allows gateway transit. The FinOps hub and DNS resolver peerings use the remote virtual network gateway.
- On-premises traffic uses the connectivity hub VPN or ExpressRoute gateway to reach the peered virtual networks.
- Customer-managed private DNS zones contain the Storage and Data Explorer records and are linked to the DNS resolver virtual network.
- On-premises DNS forwards Azure service queries to the resolver's inbound endpoint.

This example uses [gateway transit](/azure/virtual-network/virtual-network-peering-overview#gateways-and-on-premises-connectivity) and doesn't require a user-defined route (UDR) in the FinOps hub virtual network. Don't attach route tables to Toolkit-managed subnets. The Toolkit doesn't enable [private endpoint network policies](/azure/private-link/disable-private-endpoint-network-policy), so UDRs can't override private endpoint routes. Storage [service endpoint routes](/azure/virtual-network/virtual-network-service-endpoints-overview#logging-and-troubleshooting) also override matching UDRs and Border Gateway Protocol (BGP) routes.

:::image type="content" source="./media/private-networking/finops-hubs-network-peering.png" border="false" alt-text="Diagram of FinOps hub and DNS resolver networks using gateway transit through a connectivity hub to an on-premises network." lightbox="./media/private-networking/finops-hubs-network-peering.png" :::

This network topology follows the Hub-Spoke network architecture guidance outlined in the [Cloud Adoption Framework](/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) for Azure and the [Azure Architecture Center](/azure/architecture/networking/architecture/hub-spoke).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/PrivateNetworking)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3A"reactions-%2B1-desc")
<!-- prettier-ignore-end -->

<br>

## Related content

- [Configure scopes](configure-scopes.md)
- [Connect to Power BI](../power-bi/setup.md)
- [Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>
