---
title: Configure private networking in FinOps hubs
description: Learn about data access options with FinOps hubs and how to configure secure access to your data with private endpoints.
author: MSBrett
ms.author: brettwil
ms.date: 08/03/2026
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

Private access places FinOps hub resources on an isolated Toolkit network. In private mode, Storage keeps public network access enabled but uses a default-deny firewall with Azure services bypass; Kusto public network access is disabled. The FinOps Toolkit exclusively owns the hub virtual network and DNS that support Toolkit resources. The diagram shows Toolkit-internal connectivity, not a customer private-access topology.

:::image type="content" source="./media/private-networking/finops-hubs-private-network.png" border="false" alt-text="Diagram of Toolkit-internal connectivity for a privately accessible deployment." lightbox="./media/private-networking/finops-hubs-private-network.png" :::

Don't add customer workloads, subnets, gateways, endpoints, or DNS resources to the hub virtual network. The Toolkit can't preserve what you add through upgrades. Bring-your-own hub virtual networks and bring-your-own DNS for Toolkit resources aren't supported.

<br>

## Preferred option: customer-managed private endpoints

Unlike the hub virtual network described above, your own network is entirely customer-managed. The preferred private-access model is for you to create and manage private endpoints and DNS in your own network for the relevant hub Storage and Kusto resources. The Toolkit doesn't deploy or manage your endpoint, virtual network, or DNS resources, and it doesn't initiate connectivity into your network. For the canonical guidance, see [Private Endpoint overview](https://learn.microsoft.com/azure/private-link/private-endpoint-overview) and [Private Endpoint DNS integration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns-integration).

:::image type="content" source="./media/private-networking/finops-hubs-customer-endpoints.png" border="false" alt-text="Diagram showing customer-managed private endpoints and DNS in your own network reaching FinOps hub Storage and Azure Data Explorer, which are standalone PaaS resources reachable without entering the still-deployed, Toolkit-owned FinOps hub virtual network." lightbox="./media/private-networking/finops-hubs-customer-endpoints.png" :::

This diagram shows the preferred model. Private endpoints and DNS that you create and manage in your own network reach FinOps hub Storage and Azure Data Explorer directly through Azure Private Link, without VNet peering. The Toolkit's hub virtual network from the previous diagram still exists and continues to handle Toolkit-internal connectivity; this model doesn't remove it or require it to reach Storage or Azure Data Explorer. In private mode, Key Vault and Azure Data Factory stay Toolkit-internal and aren't reachable through customer-managed endpoints.

Note that private networking incurs extra cost for networking resources, connectivity, and dedicated compute in Azure Data Factory. For a detailed cost estimate, please refer to the Azure pricing calculator.

<br>

## Power BI connectivity for Kusto reports

Kusto-connected Power BI reports have two supported private connectivity models:

1. **Customer-managed private endpoint model** – Power BI reaches Kusto through customer-managed private endpoints and networking.
2. **Customer-managed peering model** – When using the [secondary peering option](#secondary-option-customer-managed-peering), Power BI reaches hub endpoints directly.

If you need a Power BI gateway, place it in your own network. Never place a Power BI gateway in the FinOps hub virtual network. For canonical guidance, see [Virtual network data gateways](https://learn.microsoft.com/data-integration/vnet/overview), [Use data gateways with Power BI sources](https://learn.microsoft.com/data-integration/vnet/use-data-gateways-sources-power-bi), and [On-premises data gateway](https://learn.microsoft.com/data-integration/gateway/service-gateway-onprem).

<br>

## Secondary option: customer-managed peering

Peering is a supported, customer-managed secondary option for private access. The supported topology connects your own network to the Toolkit-owned hub virtual network. It doesn't place customer workloads, subnets, gateways, endpoints, or DNS resources in the hub virtual network. Peering isn't required when you use private endpoints in your own network. For canonical guidance, see [Virtual network peering](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview).

:::image type="content" source="./media/private-networking/finops-hubs-network-peering.png" border="false" alt-text="Diagram showing the Toolkit-owned FinOps hub virtual network peered with a network hub in your own network, and a separate Azure DNS Resolver VNet in that network peered with the same network hub." lightbox="./media/private-networking/finops-hubs-network-peering.png" :::

This diagram shows the Toolkit-owned FinOps hub virtual network peered with a separate network hub in your own network. The Azure DNS Resolver VNet there separately peers with that network hub; it doesn't peer directly with the hub virtual network. Here, **network hub** means the separate network-topology hub in your environment, not the FinOps hub virtual network. Neither network is a component of the FinOps hub virtual network.

<br>

## Comparing network access options

The following table compares the network access options available in FinOps hubs:

| Component           | Public                        | Private                                                                                                                           | Benefit                                                        |
| ------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Storage             | Accessible over the internet¹ | Customer-managed private endpoints and DNS in your own network; customer-managed peering is a secondary option            | Data access can remain private to your network    |
| Azure Data Explorer | Accessible over the internet¹ | Customer-managed private endpoints and DNS in your own network; customer-managed peering is a secondary option            | Data access can remain private to your network    |
| Key Vault           | Accessible over the internet¹ | Toolkit-internal private connectivity                                                                                             | Keys and secrets aren't accessible from the open internet      |
| Azure Data Factory  | Uses public compute pool      | Toolkit-managed runtime and connections                                                                                           | Toolkit processing remains private                             |
| Virtual Network     | Not used                      | Toolkit-owned isolated virtual network; customer workloads and network resources aren't supported in this network                | Toolkit resources remain isolated from your network assets |

_¹ While resources are accessible over the internet, access is still protected by role-based access control (RBAC)._

<br>

## Enabling private networking

To enable private networking when deploying a new or updating an existing FinOps hub instance, set **Access** to **Private** on the **Advanced** tab.

:::image type="content" source="./media/private-networking/finops-hubs-private-deployment.png" alt-text="Screenshot of secure private deployments." lightbox="./media/private-networking/finops-hubs-private-deployment.png" :::

Before enabling private access, coordinate with the teams that own your network. Review the ownership boundary and customer-managed access models in this article.

<br>

## Removing private networking

To switch a hub to public access, redeploy it with **Access** set to **Public**. This change affects Toolkit-owned private networking. Endpoints, virtual networks, and DNS resources that you create are outside the Toolkit's management and must not be deleted as part of the hub change.

> [!WARNING]
> Removing private networking is a significant change that affects data access. Ensure all stakeholders understand the security implications before proceeding.

<br>

## FinOps hub virtual network and DNS

When private access is selected, the Toolkit deploys and exclusively owns the hub virtual network, its subnets, and DNS for Toolkit resources. These resources are internal to the Toolkit and support deployment, processing, and upgrades. Additions you make to this network aren't supported because the Toolkit can't preserve them through upgrades.

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
