---
title: FinOps best practices for Networking
description: This article outlines proven FinOps practices for networking services, focusing on cost optimization, efficiency improvements, and resource insights.
author: flanakin
ms.author: micflan
ms.date: 04/01/2026
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: arclares
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with networking services.
---

<!-- prettier-ignore-start -->
# FinOps best practices for Networking
<!-- prettier-ignore-end -->

This article outlines proven FinOps practices for networking services. They focus on cost optimization, efficiency improvements, and resource insights.

<br>

## Azure Firewall

The following sections provide Azure Resource Graph (ARG) queries for Azure Firewall. These queries help you gain insights into your Azure firewall resources and ensure they're configured with the appropriate settings. By analyzing usage patterns and surfacing recommendations from Azure Advisor, you can optimize your Azure firewall configurations for cost efficiency.

### Query: Azure firewall and firewall policies analysis

This ARG query analyzes Azure firewalls and their associated firewall policies within your Azure environment. It specifically targets firewalls with a premium SKU tier and verifies that the configurations in their associated firewall policies are utilizing the premium features.

**Category**

Optimization

**Query**

```kusto
resources
| where type =~ 'Microsoft.Network/azureFirewalls' and properties.sku.tier=="Premium"
| project FWID=id, firewallName=name, SkuTier=tostring(properties.sku.tier), resourceGroup, location
| join kind=inner (
    resources
    | where type =~ 'microsoft.network/firewallpolicies'
    | mv-expand properties.firewalls
    | extend intrusionDetection = tostring(properties.intrusionDetection contains "Alert"
        or properties.intrusionDetection contains "Deny")
    | extend transportSecurity = tostring(properties.transportSecurity contains "keyVaultSecretId")
    | extend FWID = tostring(properties_firewalls.id)
    | where intrusionDetection == "False"
        and transportSecurity == "False"
    | project
        PolicyName = name,
        PolicySKU = tostring(properties.sku.tier),
        intrusionDetection,
        transportSecurity,
        FWID
) on FWID
```

### Query: Azure Firewall and associated subnets analysis

This ARG query analyzes Azure firewalls and their associated subnets within your Azure environment. It provides insights into which subnets are associated with each Azure firewall instance. Optimize the use of Azure firewall by having a central instance of Azure firewall in the hub virtual network or Virtual WAN secure hub. Then share the same firewall across many spoke virtual networks that are connected to the same hub from the same region.

**Category**

Optimization

**Query**

```kusto
resources
| where type =~ 'Microsoft.Network/azureFirewalls' and properties.sku.tier=="Premium"
| project
    FWID=id,
    firewallName=name,
    SkuTier=tostring(properties.sku.tier),
    resourceGroup,
    location
| join kind=inner (
    resources
    | where type =~ 'microsoft.network/firewallpolicies'
    | mv-expand properties.firewalls
    | extend intrusionDetection = tostring(properties.intrusionDetection contains "Alert"
        or properties.intrusionDetection contains "Deny")
    | extend transportSecurity = tostring(properties.transportSecurity contains "keyVaultSecretId")
    | extend FWID=tostring(properties_firewalls.id)
    | where intrusionDetection == "False"
        and transportSecurity == "False"
    | project
        PolicyName = name,
        PolicySKU = tostring(properties.sku.tier),
        intrusionDetection,
        transportSecurity,
        FWID
) on FWID
```

<br>

## Application Gateway

Azure Application Gateway is a web traffic load balancer that enables you to manage traffic to your web applications. It provides application-level routing and load balancing services that let you build a scalable and highly available web front end in Azure.

Related resources:

- [Application Gateway product page](https://azure.microsoft.com/products/application-gateway)
- [Application Gateway pricing](https://azure.microsoft.com/pricing/details/application-gateway)
- [Application Gateway documentation](/azure/application-gateway)

### Remove idle application gateways

Recommendation: Remove application gateways that don't have any backend pools to avoid unnecessary costs.

#### About idle application gateways

Application gateways without any backend pool targets aren't actively routing traffic and may represent unused resources. These idle gateways continue to incur costs even though they serve no function.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify idle application gateways. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify idle application gateways

Use the following ARG query to identify application gateways with empty backend pools.

```kusto
resources
| where type =~ 'Microsoft.Network/applicationGateways'
| extend
    backendPoolsCount = array_length(properties.backendAddressPools),
    SKUName = tostring(properties.sku.name),
    SKUTier = tostring(properties.sku.tier),
    SKUCapacity = properties.sku.capacity,
    backendPools = properties.backendAddressPools,
    resourceGroup = strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project id, name, SKUName, SKUTier, SKUCapacity, resourceGroup, subscriptionId
| join (
    resources
    | where type =~ 'Microsoft.Network/applicationGateways'
    | mvexpand backendPools = properties.backendAddressPools
    | extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)
    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)
    | extend backendPoolName = backendPools.properties.backendAddressPools.name
    | summarize
        backendIPCount = sum(backendIPCount),
        backendAddressesCount = sum(backendAddressesCount)
        by id
) on id
| project-away id1
| where (backendIPCount == 0 or isempty(backendIPCount))
    and (backendAddressesCount==0 or isempty(backendAddressesCount))
| order by id asc
```

### Upgrade classic application gateways

Recommendation: Upgrade Application Gateway v1 SKU to v2 before the v1 retirement date to maintain support and access improved features.

#### About classic application gateways

Application Gateway v1 SKU (Standard and WAF) is being retired. The v2 SKU offers autoscaling, zone redundancy, and improved performance. Migrating to v2 ensures continued support and may reduce costs through autoscaling, which automatically adjusts the number of instances based on traffic.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify classic application gateways using v1 SKU. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify classic application gateways

Use the following ARG query to identify application gateways still using the v1 SKU.

```kusto
resources
| where type =~ 'microsoft.network/applicationgateways'
| where properties.sku.tier in ('Standard', 'WAF')
| project
    ResourceId = tolower(id),
    ResourceName = name,
    SKUTier = tostring(properties.sku.tier),
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

<br>

## DDoS Protection

Azure DDoS Protection provides countermeasures against the most sophisticated DDoS threats. It provides enhanced DDoS mitigation capabilities for your application and resources deployed in your virtual networks.

Related resources:

- [Azure DDoS Protection product page](https://azure.microsoft.com/products/ddos-protection)
- [Azure DDoS Protection pricing](https://azure.microsoft.com/pricing/details/ddos-protection)
- [Azure DDoS Protection documentation](/azure/ddos-protection)

### Remove unassociated DDoS protection plans

Recommendation: Remove DDoS protection plans that aren't associated with any virtual network to avoid unnecessary costs.

#### About unassociated DDoS protection plans

DDoS protection plans incur a fixed monthly charge. Plans that aren't associated with any virtual network provide no protection but still generate costs. Removing unused plans eliminates unnecessary spending.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify unassociated DDoS protection plans. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify unassociated DDoS protection plans

Use the following ARG query to identify DDoS protection plans that aren't associated with any virtual network.

```kusto
resources
| where type =~ 'microsoft.network/ddosprotectionplans'
| where isnull(properties.virtualNetworks) or array_length(properties.virtualNetworks) == 0
| project
    ResourceId = tolower(id),
    ResourceName = name,
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

<br>

## ExpressRoute

Azure ExpressRoute lets you extend your on-premises networks into the Microsoft cloud over a private connection. ExpressRoute circuits incur monthly charges based on the SKU and bandwidth provisioned.

Related resources:

- [ExpressRoute product page](https://azure.microsoft.com/products/expressroute)
- [ExpressRoute pricing](https://azure.microsoft.com/pricing/details/expressroute)
- [ExpressRoute documentation](/azure/expressroute)

### Remove unprovisioned ExpressRoute circuits

Recommendation: Delete or provision ExpressRoute circuits that are in a not-provisioned state to avoid unnecessary charges.

#### About unprovisioned ExpressRoute circuits

ExpressRoute circuits that remain in a "NotProvisioned" state aren't actively carrying traffic but still incur monthly charges. These circuits may have been created but never completed with the service provider. Identifying and removing them eliminates unnecessary costs.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify unprovisioned ExpressRoute circuits. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify unprovisioned ExpressRoute circuits

Use the following ARG query to identify ExpressRoute circuits in a not-provisioned state.

```kusto
resources
| where type =~ 'Microsoft.Network/expressRouteCircuits'
    and properties.serviceProviderProvisioningState == "NotProvisioned"
| extend
    ServiceLocation = tostring(properties.serviceProviderProperties.peeringLocation),
    ServiceProvider = tostring(properties.serviceProviderProperties.serviceProviderName),
    BandwidthInMbps = tostring(properties.serviceProviderProperties.bandwidthInMbps)
| project
    ERId = id,
    ERName = name,
    ERRG = resourceGroup,
    SKUName = tostring(sku.name),
    SKUTier = tostring(sku.tier),
    SKUFamily = tostring(sku.family),
    ERLocation = location,
    ServiceLocation,
    ServiceProvider,
    BandwidthInMbps
```

<br>

## Load Balancer

Azure Load Balancer operates at layer 4 of the OSI model and distributes inbound traffic across healthy backend pool instances. It provides high availability by monitoring the health of backend instances and automatically rerouting traffic away from unhealthy ones.

Related resources:

- [Load Balancer product page](https://azure.microsoft.com/products/load-balancer)
- [Load Balancer pricing](https://azure.microsoft.com/pricing/details/load-balancer)
- [Load Balancer documentation](/azure/load-balancer)

### Remove idle load balancers

Recommendation: Remove load balancers that don't have any backend pools to avoid unnecessary costs.

#### About idle load balancers

Load balancers without backend pool targets aren't actively distributing traffic and may represent unused resources. Standard SKU load balancers incur costs even when idle, so removing unused instances can reduce unnecessary spending.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify idle load balancers. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify idle load balancers

Use the following ARG query to identify Standard SKU load balancers with empty backend pools.

```kusto
resources
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| extend SKUName = tostring(sku.name)
| extend SKUTier = tostring(sku.tier)
| extend location,backendAddressPools = properties.backendAddressPools
| where type =~ 'microsoft.network/loadbalancers'
    and array_length(backendAddressPools) == 0
    and sku.name!='Basic'
| order by id asc
| project
    id,
    name,
    SKUName,
    SKUTier,
    backendAddressPools,
    location,
    resourceGroup,
    subscriptionId
```

### Upgrade Basic load balancers

Recommendation: Upgrade load balancers using the retired Basic SKU to Standard for better performance, security, and continued support.

#### About Basic load balancers

The Basic SKU for Azure Load Balancer was retired on September 30, 2025. Basic load balancers don't provide an SLA, lack availability zone support, and have limited diagnostic capabilities. Upgrading to Standard SKU provides improved reliability, performance, and security features.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify Basic load balancers. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify Basic load balancers

Use the following ARG query to identify load balancers using the Basic SKU.

```kusto
resources
| where type =~ 'microsoft.network/loadbalancers'
| where sku.name =~ 'Basic'
| project
    ResourceId = tolower(id),
    ResourceName = name,
    SKUName = tostring(sku.name),
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

<br>

## NAT Gateway

Azure NAT Gateway provides outbound internet connectivity for virtual networks. NAT gateways simplify outbound-only internet connectivity by providing a managed, highly available SNAT service.

Related resources:

- [NAT Gateway product page](https://azure.microsoft.com/products/azure-nat-gateway)
- [NAT Gateway pricing](https://azure.microsoft.com/pricing/details/azure-nat-gateway)
- [NAT Gateway documentation](/azure/nat-gateway)

### Remove orphaned NAT gateways

Recommendation: Remove NAT gateways that aren't associated with any subnet to avoid unnecessary charges.

#### About orphaned NAT gateways

NAT gateways incur hourly charges and data processing costs. Gateways that aren't associated with any subnet aren't providing outbound connectivity and represent wasted spend. These orphaned gateways may remain after a subnet or virtual network is reconfigured.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify orphaned NAT gateways. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify orphaned NAT gateways

Use the following ARG query to identify NAT gateways not associated with any subnet.

```kusto
resources
| where type == "microsoft.network/natgateways"
| where isnull(properties.subnets) or array_length(properties.subnets) == 0
| project
    id,
    GWName = name,
    SKUName = tostring(sku.name),
    SKUTier = tostring(sku.tier),
    Location = location,
    resourceGroup = tostring(strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)),
    subnets = properties.subnets,
    subscriptionId
```

<br>

## Network Interface

Azure network interfaces (NICs) enable Azure VMs to communicate with internet, Azure, and on-premises resources. NICs don't incur direct charges, but orphaned NICs can indicate missed cleanup opportunities and complicate resource management.

### Remove unattached network interfaces

Recommendation: Remove network interfaces that aren't attached to any virtual machine or private endpoint to keep your environment clean and reduce management overhead.

#### About unattached network interfaces

When a VM is deleted, its associated network interfaces may not be cleaned up automatically. These orphaned NICs can accumulate over time, cluttering your environment and potentially retaining associated resources like public IPs. While NICs don't incur direct charges, cleaning them up simplifies resource management and may reveal other orphaned resources.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify unattached network interfaces. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify unattached network interfaces

Use the following ARG query to identify network interfaces not attached to any VM or private endpoint.

```kusto
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine) and isnull(properties.privateEndpoint)
| project
    ResourceId = tolower(id),
    ResourceName = name,
    PrivateIP = tostring(properties.ipConfigurations[0].properties.privateIPAddress),
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

<br>

## Network Security Group

Network security groups (NSGs) filter network traffic to and from Azure resources in a virtual network. NSGs contain security rules that allow or deny inbound and outbound network traffic.

### Remove empty network security groups

Recommendation: Remove network security groups that aren't associated with any network interface or subnet to simplify your environment and reduce management overhead.

#### About empty network security groups

NSGs that aren't associated with any network interface or subnet aren't actively filtering traffic. These unused resources can accumulate during infrastructure changes, adding clutter and complicating security audits. Removing them simplifies network management and helps maintain a clean environment.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify empty network security groups. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify empty network security groups

Use the following ARG query to identify NSGs not associated with any network interface or subnet.

```kusto
resources
| where type =~ 'microsoft.network/networksecuritygroups'
| where isnull(properties.networkInterfaces) and isnull(properties.subnets)
| project
    ResourceId = tolower(id),
    ResourceName = name,
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

<br>

## Private DNS

The following section provides an ARG query for Private DNS. It helps you gain insights into your Private DNS resources and ensure they're configured with the appropriate settings.

### Query: Private DNS

This ARG query analyzes Private DNS zones within your Azure environment to identify any without Virtual Network Links.

**Category**

Optimization

**Query**

```kusto
resources
| where type == "microsoft.network/privatednszones"
    and properties.numberOfVirtualNetworkLinks == 0
| project id, PrivateDNSName=name,
    NumberOfRecordSets = tostring(properties.numberOfRecordSets),
    resourceGroup = tostring(strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)),
    vNets = tostring(properties.properties.numberOfVirtualNetworkLinks),
    subscriptionId
```

<br>

## Public IP address

Azure public IP addresses enable Azure resources to communicate with the internet and other public-facing Azure services. Public IP addresses are assigned to resources such as virtual machines, load balancers, and application gateways. Static public IP addresses incur costs whether or not they're associated with a resource.

Related resources:

- [Public IP addresses pricing](https://azure.microsoft.com/pricing/details/ip-addresses)
- [Public IP addresses documentation](/azure/virtual-network/ip-services/public-ip-addresses)

### Upgrade Basic public IPs

Recommendation: Upgrade public IP addresses using the retired Basic SKU to Standard for better security and continued support.

#### About Basic public IPs

The Basic SKU for Azure public IP addresses was retired on September 30, 2025. Basic public IPs lack zone redundancy, don't support routing preference, and are open to inbound traffic by default. Upgrading to Standard SKU provides zone redundancy, secure-by-default behavior (closed to inbound traffic), and support for routing preferences.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify Basic public IPs. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify Basic public IPs

Use the following ARG query to identify public IP addresses using the Basic SKU.

```kusto
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where sku.name =~ 'Basic'
| project
    ResourceId = tolower(id),
    ResourceName = name,
    SKUName = tostring(sku.name),
    AllocationMethod = tostring(properties.publicIPAllocationMethod),
    Region = location,
    ResourceGroupName = resourceGroup,
    SubscriptionId = subscriptionId
```

### Remove idle public IP addresses

Recommendation: Remove unattached static public IP addresses to avoid unnecessary networking costs.

#### About idle public IP addresses

Static public IP addresses incur costs regardless of whether they're associated with a resource. Unattached public IPs can accumulate over time as resources are deleted but their associated public IPs are left behind. Identifying and removing these orphaned resources can reduce unnecessary costs.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify unattached public IP addresses. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify idle public IP addresses

Use the following ARG query to identify unattached static public IP addresses, including those associated with unattached network interfaces.

```kusto
resources
| where type =~ 'Microsoft.Network/publicIPAddresses'
    and isempty(properties.ipConfiguration)
    and isempty(properties.natGateway)
    and properties.publicIPAllocationMethod =~ 'Static'
| extend
    PublicIpId = id,
    IPName = name,
    AllocationMethod = tostring(properties.publicIPAllocationMethod),
    SKUName = sku.name,
    Location = location,
    resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| project PublicIpId, IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId
| union (
    Resources
    | where type =~ 'microsoft.network/networkinterfaces'
        and isempty(properties.virtualMachine)
        and isnull(properties.privateEndpoint)
        and isnotempty(properties.ipConfigurations)
    | extend IPconfig = properties.ipConfigurations
    | mv-expand IPconfig
    | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id)
    | project PublicIpId
    | join (
        resource
        | where type =~ 'Microsoft.Network/publicIPAddresses'
        | extend
            PublicIpId = id,
            IPName = name,
            AllocationMethod = tostring(properties.publicIPAllocationMethod),
            SKUName = sku.name,
            resourceGroup,
            Location = location
    ) on PublicIpId
    | project
        PublicIpId,
        IPName,
        SKUName,
        resourceGroup,
        Location,
        AllocationMethod,
        subscriptionId
)
```

### Query: Identify public IP addresses routing method

This ARG query analyzes public IP addresses and identifies the routing method, allocation method, and SKU. It also analyzes other details of public IP addresses that are associated with an IP configuration.

**Category**

Optimization

**Query**

```kusto
resources
| where type =~ 'Microsoft.Network/publicIPAddresses'
    and isnotempty(properties.ipConfiguration)
| where tostring(properties.ipTags) == "[]"
| extend
    PublicIpId = id,
    RoutingMethod = id,
    IPName = name,
    AllocationMethod = tostring(properties.publicIPAllocationMethod),
    SKUName = sku.name,
    Location = location,
    resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| project
    PublicIpId,
    IPName,
    RoutingMethod,SKUName,
    resourceGroup,
    Location,
    AllocationMethod,
    subscriptionId
```

### Query: Check public IP addresses' DDoS protection policy

If you need to protect fewer than 15 public IP resources, the IP protection tier is the more cost-effective option. However, if you have more than 15 public IP resources to protect, then the network protection tier becomes more cost-effective.

**Category**

Optimization

**Query**

```kusto
resources
| where type == "microsoft.network/publicipaddresses"
| project ddosProtection = tostring(properties.ddosSettings), name
| where ddosProtection has "Enabled"
| count
| project TotalIpsProtected = Count
| extend CheckIpsProtected = iff(TotalIpsProtected >= 15, "Enable Network Protection tier", "Enable PIP DDoS Protection")
```

<br>

## Virtual Network Gateway

Azure Virtual Network Gateways provide cross-premises connectivity between your Azure virtual networks and on-premises infrastructure. Gateways incur hourly charges based on their SKU.

Related resources:

- [VPN Gateway pricing](https://azure.microsoft.com/pricing/details/vpn-gateway)
- [VPN Gateway documentation](/azure/vpn-gateway)

### Remove idle VNet gateways

Recommendation: Remove virtual network gateways that don't have any active connections to avoid unnecessary charges.

#### About idle VNet gateways

Virtual network gateways incur hourly costs based on their SKU tier, regardless of whether they're actively used. Gateways without any connections aren't providing cross-premises connectivity and represent wasted spend. These idle gateways may remain after a migration or when connectivity requirements change.

<!-- prettier-ignore-start -->
> [!NOTE]
> [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md) can automatically identify idle VNet gateways. [Learn more](../toolkit/hubs/configure-recommendations.md).
<!-- prettier-ignore-end -->

#### Identify idle VNet gateways

Use the following ARG query to identify virtual network gateways without any active connections.

```kusto
resources
| where type == "microsoft.network/virtualnetworkgateways"
| extend resourceGroup = strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)
| project id, GWName=name, resourceGroup, location, subscriptionId
| join kind = leftouter(
    resources
    | where type == "microsoft.network/connections"
    | extend id = tostring(properties.virtualNetworkGateway1.id)
    | project id
) on id
| where isempty(id1)
| project
    id,
    GWName,
    resourceGroup,
    location,
    subscriptionId,
    status=id
```

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.BestPractices/featureName/Networking)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related resources:

- [FinOps Framework](../framework/finops-framework.md)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../toolkit/workbooks/finops-workbooks-overview.md)
- [Optimization engine](../toolkit/optimization-engine/overview.md)

<br>
