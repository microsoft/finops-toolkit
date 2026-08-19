---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: flanakin
ms.author: micflan
ms.date: 08/19/2026
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

The FinOps Toolkit exclusively owns and manages the FinOps hub virtual network, its three subnets, private endpoints, private DNS, routing, and related resources. This network supports FinOps hub deployment and operation; it isn't a shared network for customer resources.

Don't add customer workloads, subnets, gateways, endpoints, DNS, route tables, or other configuration inside the Toolkit-managed virtual network. The Toolkit doesn't preserve customer additions during deployment or upgrade operations.

Note that private networking incurs extra cost for networking resources, connectivity, and dedicated compute in Azure Data Factory. For a detailed cost estimate, please refer to the Azure pricing calculator.

<br>

## Preferred option: customer-managed private endpoints

For private access from your network, create and manage private endpoints and DNS in your own virtual network for the FinOps hub Storage and Azure Data Explorer resources. This topology is preferred because it keeps customer networking separate from the Toolkit-managed virtual network. The Toolkit doesn't deploy or manage resources in your network.

:::image type="content" source="./media/private-networking/finops-hubs-customer-endpoints.png" border="false" alt-text="Diagram of customer-managed private endpoints and DNS reaching FinOps hub Storage and Azure Data Explorer through Private Link." lightbox="./media/private-networking/finops-hubs-customer-endpoints.png" :::

Azure Private Link connects your private endpoints directly to Storage and Azure Data Explorer without entering or peering with the FinOps hub virtual network. The Toolkit-managed virtual network remains deployed for internal connectivity. For configuration guidance, see [Private Endpoint overview](/azure/private-link/private-endpoint-overview) and [Private Endpoint DNS integration](/azure/private-link/private-endpoint-dns-integration).

If you use a Power BI virtual network data gateway, deploy it in your own virtual network and plan enough subnet address space for the gateway. Don't deploy the gateway in the FinOps hub virtual network. When you connect to Azure Data Explorer, use the fully qualified domain name (FQDN), such as `clustername.region.kusto.windows.net`, to ensure private endpoint name resolution works correctly.

<br>

## Comparing network access options

The following table compares the network access options available in FinOps hubs:

| Component           | Public                        | Private                                                                                                                 | Benefit                                                        |
| ------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Storage             | Accessible over the internet¹ | Customer-managed private endpoints in your virtual network (preferred) or customer-managed peering (secondary)          | Data access can remain private to your network                 |
| Azure Data Explorer | Accessible over the internet¹ | Customer-managed private endpoints in your virtual network (preferred) or customer-managed peering (secondary)          | Data access can remain private to your network                 |
| Key Vault           | Accessible over the internet¹ | Access restricted to the Toolkit-managed FinOps hub virtual network and trusted Azure services                          | Keys and secrets aren't accessible from the open internet      |
| Azure Data Factory  | Uses public compute pool      | Managed integration runtime in the Toolkit-managed FinOps hub virtual network                                           | All data processing happens inside the network                 |
| Virtual Network     | Not used                      | Toolkit-owned and managed isolated virtual network; customer resources aren't supported in this network                 | Toolkit resources remain isolated from customer resources      |

_¹ While resources are accessible over the internet, access is still protected by role-based access control (RBAC)._

<br>

## Enabling private networking

To enable private networking when deploying a new or updating an existing FinOps hub instance, set **Access** to **Private** on the **Advanced** tab.

:::image type="content" source="./media/private-networking/finops-hubs-private-deployment.png" alt-text="Screenshot of secure private deployments." lightbox="./media/private-networking/finops-hubs-private-deployment.png" :::

Before enabling private access, review the networking details on this page and coordinate with your network admins. Configure customer-managed private endpoints and DNS in your own network (preferred), or use the secondary peering option, before users and systems connect to the hub.

<br>

## Removing private networking

If you need to reduce costs or simplify your FinOps hub deployment, you can switch back to public access. Redeploying with **Access** set to **Public** configures Storage, Data Explorer, and Key Vault to use public access and switches Azure Data Factory back to the public integration runtime.

The incremental deployment doesn't delete the Toolkit-created virtual network, private endpoints, private DNS zones, or managed integration runtime. These resources continue to incur costs until you remove them. Customer-managed endpoints, DNS, and other resources in your network are also outside the Toolkit deployment and aren't removed.

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

   - Once you've confirmed the hub is working correctly with public access, delete only the Toolkit-created networking resources that are no longer needed to stop incurring networking costs
   - Delete resources in the following order to avoid dependency conflicts:
     1. Private endpoints
     2. Private DNS zones
     3. Virtual network and network security groups (NSGs)
   - Don't delete customer-managed networking resources as part of the FinOps hub cleanup

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

When private access is selected, the Toolkit creates and exclusively manages the FinOps hub virtual network, its three subnets, private endpoints, private DNS, routing, and related resources. The network ensures communication between hub components remains private.

- The virtual network address range can be any size from **/8** through **/26**, with a minimum address space of **/26** (64 IP addresses). The default is **/26** to conserve IP addresses while providing the minimum required subnet sizes for Container Services (used during deployments for running scripts) and Data Explorer.
- The IP range can be set at the time of deployment and defaults to **10.20.30.0/26**. The Toolkit divides the range into three subnets with the following service delegations:
  - **private-endpoint-subnet** (**/28**) – no service delegations configured; hosts private endpoints for storage and key vault.
  - **script-subnet** (**/28**) – delegated to container services for running scripts during deployment.
  - **dataExplorer-subnet** (**/27**) – delegated to Azure Data Explorer.
- If you use Power BI VNet Data Gateway, plan additional subnet address space in your own virtual network, not in the FinOps hub virtual network.

Don't precreate, extend, or modify the FinOps hub virtual network or its subnets. Don't place customer workloads, subnets, gateways, endpoints, DNS, route tables, or other configuration in this network.

<br>

## Private endpoints and DNS

Communication between the various FinOps hub components is encrypted using TLS. For TLS certificate validation to succeed when using private networking, reliable domain name system (DNS) name resolution is required. The Toolkit creates and manages DNS zones, private endpoints, and DNS entries that guarantee name resolution between FinOps hub components.

<!-- cSpell:ignore privatelink, vaultcore -->

- **privatelink.blob.core.windows.net** – for Data Explorer and storage used by deployment scripts
- **privatelink.dfs.core.windows.net** – for Data Explorer and the data lake hosting the FinOps data and pipeline configuration
- **privatelink.table.core.windows.net** – for Data Explorer
- **privatelink.queue.core.windows.net** – for Data Explorer
- **privatelink.vaultcore.azure.net** – for Azure Key Vault
- **privatelink.{location}.kusto.windows.net** – for Data Explorer

> [!IMPORTANT]
> Don't alter the DNS configuration of the FinOps hub virtual network. FinOps hub components require reliable name resolution for deployments and upgrades to succeed. Data Factory pipelines also require reliable name resolution between components.

<br>

## Network peering, routing, and name resolution

Customer-managed private endpoints in your own virtual network are the preferred private-access topology. As a secondary option, you can use VNet peering to connect your network to the isolated FinOps hub virtual network. Peering doesn't make the FinOps hub virtual network a shared network: don't place customer workloads or networking resources inside it.

Secondary connectivity options include:

- Peering the FinOps hub network with another Azure vNet.
- Peering the FinOps hub network with an Azure vWAN hub.
- Allowing one's corporate firewall and VPN IP ranges access over the public internet via the storage and Data Explorer firewalls.

To access FinOps hub data from a peered virtual network, configure **A** records in customer-managed DNS to access Storage or Data Explorer. **CNAME** records may also be required depending on your DNS solution. The Toolkit-managed private DNS zones are linked only to the FinOps hub virtual network and don't provide name resolution to peered networks.

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
