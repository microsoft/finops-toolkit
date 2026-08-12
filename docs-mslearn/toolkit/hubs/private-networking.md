---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: flanakin
ms.author: micflan
ms.date: 08/12/2026
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
- Azure Data Factory is configured to use the public integration runtime.

:::image type="content" source="./media/private-networking/finops-hubs-public-network.png" border="false" alt-text="Screenshot of publicly accessible deployments." lightbox="./media/private-networking/finops-hubs-public-network.png" :::

<br>

## How private access works

Private access is a more secure option that places FinOps hubs resources on an isolated network and limits access via private networking:

- Public network access is disabled by default.
- Storage is accessible via private IP address and trusted Azure services - firewall is set to default deny with bypass for services on trusted list.
- Data Explorer (if deployed) is accessible via private IP address - firewall is set to default deny with no exceptions.
- Key vault is accessible via private IP address and trusted Azure services - firewall is set to default deny with bypass for services on trusted list.
- Azure Data Factory is configured to use the public integration runtime, which helps reduce costs.
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

## Removing private networking

If you need to reduce costs or simplify your FinOps hub deployment, you can remove private networking and switch back to public access. This change will:

- Remove the virtual network and associated networking costs
- Disable private endpoints and DNS zones
- Configure storage, Data Explorer, and Key Vault to use public access
- Switch Azure Data Factory back to the public integration runtime

> [!WARNING]
> Removing private networking is a significant change that will affect how you access your FinOps hub. Ensure all stakeholders understand the security implications before proceeding.

### Steps to remove private networking

1. **Plan the transition**:
   - Identify all users and systems currently accessing the hub via private networking
   - Coordinate with your network administrators about the change
   - Schedule maintenance window as the hub will be temporarily inaccessible during the transition

2. **Update the FinOps hub deployment**:

   You have two options to redeploy your FinOps hub with public access:

   **Option 1: Redeploy from existing deployment**
   - Navigate to your FinOps hub resource group in the Azure portal
   - Go to the **Deployments** tab on the resource group
   - Find and open the original FinOps hub deployment
   - Click **Redeploy**
   - On the **Advanced** tab, set **Access** to **Public**
   - Review all other settings to ensure they remain as desired
   - Deploy the updated configuration

   **Option 2: Deploy latest toolkit version**
   - Install the latest current version of the FinOps toolkit
   - Use the same resource group name, hub name, and Data Explorer cluster name as your existing deployment
   - These values can be obtained from the original deployment template or the config.json file in your hub storage account
   - On the **Advanced** tab, set **Access** to **Public**
   - Deploy with the same configuration to update your existing hub

3. **Verify the changes**:
   - Confirm that storage accounts, Data Explorer, and Key Vault are accessible via public endpoints
   - Test data access from Power BI and other connected systems
   - Verify that Azure Data Factory pipelines continue to run successfully

4. **Clean up networking resources** (optional):
   - Once you've confirmed the hub is working correctly with public access, you can delete the networking resources to stop incurring networking costs
   - Delete resources in the following order to avoid dependency conflicts:
     1. Private endpoints
     2. Private DNS zones
     3. Virtual network and network security groups (NSGs)
   - Be cautious when deleting resources manually - ensure they're not being used by other systems

5. **Remove Azure Data Factory managed integration runtime** (optional):
   - When private networking was enabled, Azure Data Factory may have created a managed integration runtime for secure data processing
   - While leaving the managed integration runtime won't break functionality, it does carry ongoing costs
   - To remove the managed integration runtime:
     1. Navigate to your Azure Data Factory instance in the Azure portal
     2. Go to **Manage** > **Integration runtimes**
     3. Identify any managed integration runtimes that were created for private networking (typically named with your hub instance)
     4. Stop and delete the managed integration runtime if it's no longer needed
     5. Verify that your data pipelines continue to work with the public integration runtime
   - Only remove managed integration runtimes that were specifically created for the FinOps hub private networking setup

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

When private access is selected, choose your mode using **virtualNetworkMode**:

- Set **virtualNetworkMode** to `new` to create a new virtual network and subnets.
- Set **virtualNetworkMode** to `existing` to use your existing virtual network. In this mode, set **existingVirtualNetworkResourceId**.

### Virtual network mode and parameter usage

The following table shows which network parameters are used in each mode when private access is enabled (**enablePublicAccess** = `false`).

| Parameter                            | `new` mode | `existing` mode | Notes                                                                                                                                                                                                            |
| ------------------------------------ | ---------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **virtualNetworkMode**               | Used       | Used            | Selects whether FinOps hubs creates a VNet or reuses one.                                                                                                                                                        |
| **privateEndpointSubnetName**        | Used       | Used            | Subnet name used for storage, Key Vault, and script storage private endpoints.                                                                                                                                   |
| **scriptSubnetName**                 | Used       | Used            | Subnet name used for deployment script container groups.                                                                                                                                                         |
| **dataExplorerSubnetName**           | Used       | Used            | Subnet name used for Azure Data Explorer private endpoint.                                                                                                                                                       |
| **createPrivateDnsZones**            | Always on  | Used            | In `new` mode, FinOps hubs always creates private DNS zones and links them to the created virtual network. In `existing` mode, set to `false` to skip private DNS zones, zone groups, and virtual network links. |
| **virtualNetworkAddressPrefix**      | Used       | Ignored         | Used only when creating a new VNet.                                                                                                                                                                              |
| **enableNatGateway**                 | Used       | Ignored         | NAT Gateway is only created/attached when mode is `new`.                                                                                                                                                         |
| **existingVirtualNetworkResourceId** | Ignored    | Used            | Required in `existing` mode to target your VNet.                                                                                                                                                                 |

In `new` mode:

- Set **virtualNetworkAddressPrefix** to define the VNet address space.
- FinOps hubs always creates the required private DNS zones and links them to the new virtual network.
- The virtual network can be any subnet size from **/8** to **/26**, with a minimum of **/26** (64 IP addresses) required.
- The default IP range is **10.20.30.0/26**.
- FinOps hubs creates three subnets from this range: **/28** for private endpoints, **/28** for deployment scripts, and **/27** reserved for Azure Data Explorer private endpoints.
- Choose a larger range (for example, **/24**) if you need more private address space for adjacent services like Power BI VNet Data Gateway.

In `existing` mode:

### Existing mode: bring your own virtual network subnet requirements and mapping

If you're using an existing virtual network, configure these settings before deploying FinOps hubs:

- Set **existingVirtualNetworkResourceId** to your VNet resource ID.
- Set **createPrivateDnsZones** to `true` to let FinOps hubs create the required private DNS zones, link them to your existing virtual network, and attach private endpoints to those zones.
- Set **createPrivateDnsZones** to `false` if your organization manages private DNS separately. In this case, FinOps hubs still creates private endpoints, but doesn't create private DNS zones, private DNS zone groups, or virtual network links.
- **virtualNetworkAddressPrefix** is ignored.
- FinOps hubs uses your existing VNet address space and the subnet names you provide.

When **enablePublicAccess** is set to `false`, FinOps hubs uses the following requirements and subnet mapping:

| Subnet parameter              | Default subnet name         | Minimum size | Required configuration                                                                                                                                                                      | Contains                                                                                                                              |
| ----------------------------- | --------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **privateEndpointSubnetName** | **private-endpoint-subnet** | **/28**      | Service endpoint recommended: **Microsoft.Storage**                                                                                                                                         | Azure Resource Manager private endpoints for hub storage (`blob`, `dfs`), Key Vault (`vault`), and deployment script storage (`blob`) |
| **scriptSubnetName**          | **script-subnet**           | **/28**      | Subnet delegation required: **Microsoft.ContainerInstance/containerGroups**. Service endpoint recommended: **Microsoft.Storage**. Outbound routing required if default outbound is blocked. | Deployment script container groups (Azure Container Instances)                                                                        |
| **dataExplorerSubnetName**    | **dataExplorer-subnet**     | **/27**      | Outbound routing required if default outbound is blocked.                                                                                                                                   | Azure Data Explorer cluster private endpoint (`cluster`)                                                                              |

Virtual network requirement: minimum **/26** address space.

> [!NOTE]
> Data Factory managed private endpoints (for storage, Key Vault, and Data Explorer) are created in the Data Factory managed virtual network, not as Azure Resource Manager private endpoints in your bring-your-own virtual network subnets.

> [!NOTE]
> Azure Data Explorer private endpoints commonly consume 8 private IPs in the subnet baseline (engine endpoint, data management endpoint, and transient storage endpoints). This baseline doesn't scale linearly with **dataExplorerSkuCapacity** (node count). Additional private IP usage is primarily tied to high-ingestion scenarios that scale transient storage endpoints. The **/27** minimum in bring-your-own virtual network mode is kept to provide operational headroom.

### Bring your own virtual network NSG settings

If your existing subnets have NSGs attached, configure rules that allow the same baseline traffic pattern FinOps hubs configures when it creates a new virtual network.

| Direction | Priority | Rule                          | Source            | Destination    | Port/Protocol | Access |
| --------- | -------- | ----------------------------- | ----------------- | -------------- | ------------- | ------ |
| Inbound   | 100      | AllowVnetInBound              | VirtualNetwork    | VirtualNetwork | Any / Any     | Allow  |
| Inbound   | 200      | AllowAzureLoadBalancerInBound | AzureLoadBalancer | Any            | Any / Any     | Allow  |
| Inbound   | 4096     | DenyAllInBound                | Any               | Any            | Any / Any     | Deny   |
| Outbound  | 100      | AllowVnetOutBound             | VirtualNetwork    | VirtualNetwork | Any / Any     | Allow  |
| Outbound  | 200      | AllowInternetOutBound         | Any               | Internet       | Any / Any     | Allow  |
| Outbound  | 4096     | DenyAllOutBound               | Any               | Any            | Any / Any     | Deny   |

Apply these rules to the NSGs used by the private endpoint, script, and Data Explorer subnets, or configure equivalent rules in your central firewall/segmentation architecture.

> [!NOTE]
> FinOps hubs only creates/attaches NAT Gateway when it creates a new virtual network. In bring-your-own virtual network mode, configure outbound routing in your own network architecture.

You can override all subnet names at deployment time. FinOps hubs uses the configured names for both new and existing virtual network modes.

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
