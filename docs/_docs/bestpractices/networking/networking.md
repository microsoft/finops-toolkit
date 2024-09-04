---
layout: default
parent: Best practices
permalink: /bestpractices/networking
nav_order: 2
title: Networking
author: arclares
ms.date: 08/16/2024
ms.service: finops
description: 'Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure resources.'

---

<span class="fs-9 d-block mb-4">Networking</span>
Discover essential FinOps best practices to optimize cost efficiency and governance for your Azure networking resources.
{: .fs-6 .fw-300 }

[Share feedback](#️-looking-for-more){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🛡️ Azure Firewall](#azure-firewall)
- [🔗  Load Balancer](#load-balancer)
- [🌐 Public IP Address](#public-ip-address)
- [🖧 Virtual Network Gateway](#virtual-network-gateway)
- [📡 Express Route](express-route)
- [📶  Private DNS](#private-dns)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)
- [🧰 Related tools](#-related-tools)

</details>

---


## Azure Firewall 

### Query: Azure Firewall and Firewall Policies Analysis

This Azure Resource Graph (ARG) query analyzes Azure Firewalls and their associated Firewall Policies within your Azure environment. It specifically targets Firewalls with a Premium SKU tier and verifies that the configurations in their associated Firewall policies are utilizing the premium features.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
  | where type =~ 'Microsoft.Network/azureFirewalls' and properties.sku.tier=="Premium"
  | project FWID=id, firewallName=name, SkuTier=tostring(properties.sku.tier), resourceGroup, location
  | join kind=inner (
      resources
      | where type =~ 'microsoft.network/firewallpolicies'
      | mv-expand properties.firewalls
      | extend intrusionDetection=tostring(properties.intrusionDetection contains "Alert" or properties.intrusionDetection contains "Deny"), transportSecurity=tostring(properties.transportSecurity contains "keyVaultSecretId")
      | extend FWID=tostring(properties_firewalls.id)
      | where intrusionDetection == "False" and transportSecurity == "False"
      | project PolicyName=name, PolicySKU=tostring(properties.sku.tier), intrusionDetection, transportSecurity, FWID
  ) on FWID</code></pre>
  </div>
</details>


### Query: Azure Firewall and Associated Subnets Analysis

This Azure Resource Graph (ARG) query analyzes Azure Firewalls and their associated subnets within your Azure environment. It provides insights into which subnets are associated with each Azure Firewall instance. Optimize the use of Azure Firewall by having a central instance of Azure Firewall in the hub virtual network or Virtual WAN secure hub and share the same firewall across many spoke virtual networks that are connected to the same hub from the same region.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
  | where type =~ 'Microsoft.Network/azureFirewalls' and properties.sku.tier=="Premium"
  | project FWID=id, firewallName=name, SkuTier=tostring(properties.sku.tier), resourceGroup, location
  | join kind=inner (
      resources
      | where type =~ 'microsoft.network/firewallpolicies'
      | mv-expand properties.firewalls
      | extend intrusionDetection=tostring(properties.intrusionDetection contains "Alert" or properties.intrusionDetection contains "Deny"), transportSecurity=tostring(properties.transportSecurity contains "keyVaultSecretId")
      | extend FWID=tostring(properties_firewalls.id)
      | where intrusionDetection == "False" and transportSecurity == "False"
      | project PolicyName=name, PolicySKU=tostring(properties.sku.tier), intrusionDetection, transportSecurity, FWID
  ) on FWID</code></pre>
  </div>
</details>

## Application Gateway

### Query: Idle Application Gateways

This Azure Resource Graph (ARG) query analyzes Application Gateways and their associated backend pools within your Azure environment. It provides insights into which Application Gateways have empty backend pools, indicating they may be idle and potentially unnecessary.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type =~ 'Microsoft.Network/applicationGateways'
| extend backendPoolsCount = array_length(properties.backendAddressPools),SKUName= tostring(properties.sku.name), SKUTier= tostring(properties.sku.tier),SKUCapacity=properties.sku.capacity,backendPools=properties.backendAddressPools,resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project id, name, SKUName, SKUTier, SKUCapacity,resourceGroup,subscriptionId
| join (
    resources
    | where type =~ 'Microsoft.Network/applicationGateways'
    | mvexpand backendPools = properties.backendAddressPools
    | extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)
    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)
    | extend backendPoolName  = backendPools.properties.backendAddressPools.name
    | summarize backendIPCount = sum(backendIPCount) ,backendAddressesCount=sum(backendAddressesCount) by id
) on id
| project-away id1
| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))
| order by id asc
</code></pre>
  </div>
</details>

## Load Balancer

### Query: Idle Load Balancers

This Azure Resource Graph (ARG) query analyzes Azure load balancers and their associated backend pools within your Azure environment. It provides insights into which load balancers have empty backend pools, indicating they may be idle and potentially unnecessary.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
    | extend resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
    | extend SKUName=tostring(sku.name)
    | extend SKUTier=tostring(sku.tier)
    | extend location,backendAddressPools = properties.backendAddressPools
    | where type =~ 'microsoft.network/loadbalancers' and array_length(backendAddressPools) == 0 and sku.name!='Basic'
    | order by id asc
| project id,name, SKUName,SKUTier,backendAddressPools, location,resourceGroup, subscriptionId
</code></pre>
  </div>
</details>

## Public IP Address

## Query: Idle Public IP Addresses

This Azure Resource Graph (ARG) query analyzes Azure public ip adresses. It provides insights into which public IPs are idle and potentially unnecessary.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
| where type =~ 'Microsoft.Network/publicIPAddresses' and isempty(properties.ipConfiguration) and isempty(properties.natGateway) and properties.publicIPAllocationMethod =~ 'Static'
| extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location ,resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId
| union (
    Resources 
    | where type =~ 'microsoft.network/networkinterfaces' and isempty(properties.virtualMachine) and isnull(properties.privateEndpoint) and isnotempty(properties.ipConfigurations) 
    | extend IPconfig = properties.ipConfigurations 
    | mv-expand IPconfig 
    | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id)
    | project PublicIpId
        | join ( 
            resources 
            | where type =~ 'Microsoft.Network/publicIPAddresses'
            | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, resourceGroup, Location=location 
        ) on PublicIpId
 | project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId
)
</code></pre>
  </div>
</details>


### Query: Identify the Routing Method of Your Public IP Addresses

This Azure Resource Graph (ARG) query analyzes public IP addresses and identifies the routing method, allocation method, SKU, and other details of public IP addresses that are associated with an IP configuration

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type =~ 'Microsoft.Network/publicIPAddresses' and isnotempty(properties.ipConfiguration)
| where tostring(properties.ipTags)== "[]"
| extend PublicIpId=id, RoutingMethod=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location ,resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project PublicIpId,IPName, RoutingMethod,SKUName, resourceGroup, Location, AllocationMethod, subscriptionId
</code></pre>
  </div>
</details>

### Query: Check Public IP Addresses' DDoS Protection Policy

If you need to protect fewer than 15 public IP resources, the IP Protection tier is the more cost-effective option. However, if you have more than 15 public IP resources to protect, then the Network Protection tier becomes more cost-effective.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/publicipaddresses"
| project ddosProtection=tostring(properties.ddosSettings), name
| where ddosProtection has "Enabled"
| count
| project TotalIpsProtected = Count
| extend CheckIpsProtected = iff(TotalIpsProtected >= 15,"Enable Network Protection tier", "Enable PIP DDoS Protection")
</code></pre>
  </div>
</details>

## Virtual Network Gateway

### Query: Check for Idle Virtual Network Gateway

This Azure Resource Graph (ARG) query analyzes Virtual Network Gateways within your Azure environment to identify those that are idle.


#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/virtualnetworkgateways"
| extend resourceGroup =strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)
| project id, GWName=name,resourceGroup,location,subscriptionId
| join kind = leftouter(
    resources
    | where type == "microsoft.network/connections"
    | extend id = tostring(properties.virtualNetworkGateway1.id)
    | project id
) on id
| where isempty(id1)
| project id, GWName,resourceGroup,location,subscriptionId,status=id
</code></pre>
  </div>
</details>


### Query: Check for Idle NAT Gateway

This Azure Resource Graph (ARG) query analyzes NAT Gateways within your Azure environment to identify those that are idle.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/natgateways" and isnull(properties.subnets)
| project id, GWName=name, SKUName=tostring(sku.name), SKUTier=tostring(sku.tier), Location=location ,resourceGroup=tostring(strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)),subnet=tostring(properties.subnet), subscriptionId
</code></pre>
  </div>
</details>

## Express Route

### Query: Idle Express Route

This Azure Resource Graph (ARG) query analyzes Express Route circuits within your Azure environment to identify those without a completed circuit.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type =~ 'Microsoft.Network/expressRouteCircuits' and properties.serviceProviderProvisioningState == "NotProvisioned"
| extend ServiceLocation=tostring(properties.serviceProviderProperties.peeringLocation), ServiceProvider=tostring(properties.serviceProviderProperties.serviceProviderName), BandwidthInMbps=tostring(properties.serviceProviderProperties.bandwidthInMbps)
| project   ERId=id,ERName = name, ERRG = resourceGroup, SKUName=tostring(sku.name), SKUTier=tostring(sku.tier), SKUFamily=tostring(sku.family), ERLocation = location, ServiceLocation, ServiceProvider, BandwidthInMbps

</code></pre>
  </div>
</details>

## Private DNS

### Query: Private DNS

This Azure Resource Graph (ARG) query analyzes Private DNS zones within your Azure environment to identify those without Virtual Network Links.

#### Category

Optimization

#### Query

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/privatednszones" and properties.numberOfVirtualNetworkLinks == 0
| project id, PrivateDNSName=name, NumberOfRecordSets=tostring(properties.numberOfRecordSets),resourceGroup=tostring(strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)),vNets=tostring(properties.properties.numberOfVirtualNetworkLinks), subscriptionId
</code></pre>
  </div>
</details>

## 🙋‍♀️ Looking for more?

We'd love to hear about any datasets you're looking for. Create a new issue with the details that you'd like to see either included in existing or new best practices.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
