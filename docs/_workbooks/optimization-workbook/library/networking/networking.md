---
layout: default
grand_parent: Cost optimization workbook resource library
parent: Networking
permalink: /optimization-workbook/library/networking
nav_order: 3
title: Networking
author: arclares
ms.date: 06/27/2024
ms.service: finops
description: 'Learn more about the Azure Resource Graph (ARG) queries used in the cost optimization workbook.'
---

# Azure Firewall 

## Query: Azure Firewall and Firewall Policies Analysis

This Azure Resource Graph (ARG) query analyzes Azure Firewalls and their associated Firewall Policies within your Azure environment. It focuses on Firewalls with a Premium SKU tier and checks for specific configurations in their associated Firewall Policies.

## Description

This query identifies Azure Firewalls with a Premium SKU tier and examines their associated Firewall Policies. It specifically looks for Firewalls where intrusion detection is not configured to alert or deny actions, and where transport security does not utilize Key Vault secret IDs.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies Firewall with Premium SKU that are not using premium features. If these premium features are not needed, this firewall can moved to a standard tier. 

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


## Query: Azure Firewall and Associated Subnets Analysis

This Azure Resource Graph (ARG) query analyzes Azure Firewalls and their associated subnets within your Azure environment. It provides insights into which subnets are associated with each Azure Firewall instance.

### Description
This query identifies Azure Firewalls and their associated subnets in your Azure environment. It links each firewall to its corresponding subnet based on subnet IDs containing 'AzureFirewallSubnet'.

### Category

Optimization

### Potential Benefits
 - **Cost Optimization:** Optimize the use of Azure Firewall by having a central instance of Azure Firewall in the hub virtual network or Virtual WAN secure hub and share the same firewall across many spoke virtual networks that are connected to the same hub from the same region. Ensure there's no unexpected cross-region traffic as part of the hub-spoke topology nor multiple Azure firewall instances deployed to the same region. 

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


## Query: Idle Application Gateways

This Azure Resource Graph (ARG) query analyzes Application Gateways and their associated backend pools within your Azure environment. It provides insights into which Application Gateways have empty backend pools, indicating they may be idle and potentially unnecessary.

### Description

This query identifies Application Gateways that have no backend IP configurations or backend addresses in their backend pools. It helps determine which Application Gateways are idle and can be considered for deletion to optimize costs.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Optimizes your costs by identifying and allowing the deletion of idle Application Gateways that are not actively routing traffic.


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

## Query: Idle Load Balancers

This Azure Resource Graph (ARG) query analyzes Azure load balancers and their associated backend pools within your Azure environment. It provides insights into which load balancers have empty backend pools, indicating they may be idle and potentially unnecessary.

### Description

This query identifies Azure load balancers that have no backend address pools and are not using the Basic SKU. It helps determine which load balancers are idle and can be considered for deletion to optimize costs.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Optimize your costs by identifying and allowing the deletion of idle load balancers that are not actively routing traffic.


<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources 
| extend resourceGroup=strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup), SKUName=tostring(sku.name),SKUTier=tostring(sku.tier),location,backendAddressPools = properties.backendAddressPools
| where type =~ 'microsoft.network/loadbalancers' and array_length(backendAddressPools) == 0 and sku.name!='Basic'
| order by id asc
| project id,name, SKUName,SKUTier,backendAddressPools, location,resourceGroup, subscriptionId
</code></pre>
  </div>
</details>

## Query: Idle Public IP Addresses

xxxx

### Description
xxxx

### Category

Optimization

### Potential Benefits
 - **Cost Optimization:** Opitmize your cost by deleting load balancers that are idle.

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


## Query: Identify the Routing Method of Your Public IP Addresses

This Azure Resource Graph (ARG) query analyzes public IP addresses within your Azure environment to determine their routing methods.

### Description

This query identifies the routing method, allocation method, SKU, and other details of public IP addresses that are associated with an IP configuration and do not have IP tags. It provides insights into the configuration and utilization of public IP addresses in your environment.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Helps optimize costs by identifying public IP addresses with specific routing and allocation methods, potentially revealing opportunities to consolidate or reconfigure IP addresses for cost savings.
- **Resource Management:** Provides visibility into the routing methods of public IP addresses, aiding in efficient resource management and ensuring optimal usage of public IP resources.

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

## Query: Check Public IP Addresses' DDoS Protection Policy

If you need to protect fewer than 15 public IP resources, the IP Protection tier is the more cost-effective option. However, if you have more than 15 public IP resources to protect, then the Network Protection tier becomes more cost-effective.

### Description

This query identifies all Public IP (PIP) addresses with DDoS Protection enabled. If there are more than 15 Public IP Addresses with DDoS protection in the same virtual network, then it is more economical to enable DDoS Network protection.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies the number of Public IP addresses with DDoS protection enabled and recommends the most cost-effective DDoS protection tier, ensuring cost efficiency in your Azure environment.

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


## Query: Check for Idle Virtual Network Gateway

This Azure Resource Graph (ARG) query analyzes Virtual Network Gateways within your Azure environment to identify those that are idle.

### Description

This query identifies Virtual Network Gateways that are not associated with any connections, indicating they may be idle and potentially unnecessary. By checking for unutilized gateways, you can ensure that resources are optimally used and avoid unnecessary costs.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies idle Virtual Network Gateways that can be decommissioned, thereby reducing costs associated with unused resources.
- **Resource Management:** Helps in efficiently managing network resources by identifying gateways that are not actively in use.


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


## Query: Check for Idle NAT Gateway

This Azure Resource Graph (ARG) query analyzes NAT Gateways within your Azure environment to identify those that are idle.

### Description

This query identifies NAT Gateways that have no subnets defined. Such gateways may represent unnecessary costs as they are not actively routing traffic.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies idle NAT Gateways that can be decommissioned to reduce costs associated with unused resources.
- **Resource Management:** Ensures efficient use of network resources by identifying NAT Gateways that are not linked to any subnets.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/natgateways" and isnull(properties.subnets)
| project id, GWName=name, SKUName=tostring(sku.name), SKUTier=tostring(sku.tier), Location=location ,resourceGroup=tostring(strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)),subnet=tostring(properties.subnet), subscriptionId
</code></pre>
  </div>
</details>

## Query: Idle Express Route

This Azure Resource Graph (ARG) query analyzes Express Route circuits within your Azure environment to identify those without a completed circuit.

### Description

This query identifies Express Route Gateways that are in a "NotProvisioned" state. Reviewing these gateways helps ensure that resources are not allocated to incomplete circuits, optimizing cost and resource allocation.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies incomplete Express Route circuits that can be reviewed and potentially decommissioned to avoid unnecessary costs.
- **Resource Management:** Ensures efficient use of network resources by identifying and managing Express Route circuits that are not fully provisioned.


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


## Query: Private DNS

This Azure Resource Graph (ARG) query analyzes Private DNS zones within your Azure environment to identify those without Virtual Network Links.

### Description

This query identifies Private DNS zones that do not have any associated Virtual Network Links. Reviewing these DNS zones helps ensure that resources are optimally used and avoid unnecessary costs associated with unused DNS zones.

### Category

Optimization

### Potential Benefits

- **Cost Optimization:** Identifies Private DNS zones without Virtual Network Links that can be reviewed and potentially decommissioned, thereby reducing costs associated with unused resources.
- **Resource Management:** Ensures efficient use of DNS resources by identifying and managing DNS zones that are not actively linked to any virtual networks.

<details>
  <summary>Click to view the code</summary>
  <div class="code-block">
    <pre><code> resources
| where type == "microsoft.network/privatednszones" and properties.numberOfVirtualNetworkLinks == 0
| project id, PrivateDNSName=name, NumberOfRecordSets=tostring(properties.numberOfRecordSets),resourceGroup=tostring(strcat('/subscriptions/',subscriptionId,'/resourceGroups/',resourceGroup)),vNets=tostring(properties.properties.numberOfVirtualNetworkLinks), subscriptionId
</code></pre>
  </div>
</details>
