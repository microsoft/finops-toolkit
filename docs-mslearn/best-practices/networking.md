---
title: FinOps best practices for Networking
description: This article outlines proven FinOps practices for networking services, focusing on cost optimization, efficiency improvements, and resource insights.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
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

<br>

## ExpressRoute

The following section provides an ARG query for ExpressRoute. It helps you gain insights into your ExpressRoute circuits and ensure they're configured with the appropriate settings.

### Query: Idle ExpressRoute circuits

This ARG query analyzes ExpressRoute circuits within your Azure environment to identify any without a completed circuit.

**Category**

Optimization

**Query**

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

The following sections provide ARG queries for Virtual Network Gateways. They help you gain insights into your Virtual Network Gateway resources and ensure they're configured with the appropriate settings.

### Query: Check for idle Virtual Network Gateway

This ARG query analyzes Virtual Network Gateways within your Azure environment to identify any that are idle.

**Category**

Optimization

**Query**

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

### Query: Check for idle NAT gateway

This ARG query analyzes NAT gateways within your Azure environment to identify any that are idle.

**Category**

Optimization

**Query**

```kusto
resources
| where type == "microsoft.network/natgateways" and isnull(properties.subnets)
| project
    id,
    GWName = name,
    SKUName = tostring(sku.name),
    SKUTier = tostring(sku.tier),
    Location = location,
    resourceGroup = tostring(strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup)),
    subnet = tostring(properties.subnet),
    subscriptionId
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
