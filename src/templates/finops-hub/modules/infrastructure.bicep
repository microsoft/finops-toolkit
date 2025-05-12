// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { getHubTags, HubCoreConfig } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

// @description('Required. Name of the FinOps hub instance.')
// param hubName string

@description('Required. FinOps hub configuration settings.')
param coreConfig HubCoreConfig


//==============================================================================
// Variables
//==============================================================================

var safeHubName = replace(replace(toLower(coreConfig.hub.name), '-', ''), '_', '')
// cSpell:ignore vnet
var vNetName = '${safeHubName}-vnet-${coreConfig.hub.location}'
var nsgName = '${coreConfig.network.name}-nsg'

// Workaround https://github.com/Azure/bicep/issues/1853
var finopsHubSubnetName = 'private-endpoint-subnet'
var scriptSubnetName = 'script-subnet'
var dataExplorerSubnetName = 'dataExplorer-subnet'

var subnets = !coreConfig.network.isPrivate ? [] : [
  {
    name: finopsHubSubnetName
    properties: {
      addressPrefix: cidrSubnet(coreConfig.network.addressPrefix, 28, 0)
      networkSecurityGroup: {
        id: nsg.id
      }
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
      ]
    }
  }
  {
    name: scriptSubnetName
    properties: {
      addressPrefix: cidrSubnet(coreConfig.network.addressPrefix, 28, 1)
      networkSecurityGroup: {
        id: nsg.id
      }
      delegations: [
        {
          name: 'Microsoft.ContainerInstance/containerGroups'
          properties: {
            serviceName: 'Microsoft.ContainerInstance/containerGroups'
          }
        }
      ]
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
      ]
    }
  }
  {
    name: dataExplorerSubnetName
    properties: {
      addressPrefix: cidrSubnet(coreConfig.network.addressPrefix, 27, 1)
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Network
//------------------------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (coreConfig.network.isPrivate) {
  name: nsgName
  location: coreConfig.hub.location
  tags: getHubTags(coreConfig, 'Microsoft.Storage/networkSecurityGroups')
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInBound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInBound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVnetOutBound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowInternetOutBound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2023-11-01' = if (coreConfig.network.isPrivate) {
  name: vNetName
  location: coreConfig.hub.location
  tags: getHubTags(coreConfig, 'Microsoft.Storage/virtualNetworks')
  properties: {
    addressSpace: {
      addressPrefixes: [coreConfig.network.addressPrefix]
    }
    subnets: subnets
  }

  resource finopsHubSubnet 'subnets' existing = {
    name: finopsHubSubnetName
  }

  resource scriptSubnet 'subnets' existing = {
    name: scriptSubnetName
  }

  resource dataExplorerSubnet 'subnets' existing = {
    name: dataExplorerSubnetName
  }
}

//------------------------------------------------------------------------------
// Storage DNS zones
//------------------------------------------------------------------------------

// Required for the Azure portal and Storage Explorer
resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (coreConfig.network.isPrivate) {
  name: coreConfig.network.dnsZones.blob.name
  location: 'global'
  tags: getHubTags(coreConfig, 'Microsoft.Storage/privateDnsZones')
  properties: {}

  resource blobPrivateDnsZoneLink 'virtualNetworkLinks' = {
    name: '${replace(blobPrivateDnsZone.name, '.', '-')}-link'
    location: 'global'
    tags: getHubTags(coreConfig, 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: coreConfig.network.id
      }
    }
  }
}

// Required for Power BI
resource dfsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (coreConfig.network.isPrivate) {
  name: coreConfig.network.dnsZones.dfs.name
  location: 'global'
  tags: getHubTags(coreConfig, 'Microsoft.Storage/privateDnsZones')
  properties: {}

  resource dfsPrivateDnsZoneLink 'virtualNetworkLinks' = {
    name: '${replace(dfsPrivateDnsZone.name, '.', '-')}-link'
    location: 'global'
    tags: getHubTags(coreConfig, 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: coreConfig.network.id
      }
    }
  }
}

// Required for Azure Data Explorer
resource queuePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (coreConfig.network.isPrivate) {
  name: coreConfig.network.dnsZones.queue.name
  location: 'global'
  tags: getHubTags(coreConfig, 'Microsoft.Storage/privateDnsZones')
  properties: {}
  
  resource queuePrivateDnsZoneLink 'virtualNetworkLinks' = {
    name: '${replace(queuePrivateDnsZone.name, '.', '-')}-link'
    location: 'global'
    tags: getHubTags(coreConfig, 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: coreConfig.network.id
      }
    }
  }
}

// Required for Azure Data Explorer
resource tablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (coreConfig.network.isPrivate) {
  name: coreConfig.network.dnsZones.table.name
  location: 'global'
  tags: getHubTags(coreConfig, 'Microsoft.Storage/privateDnsZones')
  properties: {}
  
  resource tablePrivateDnsZoneLink 'virtualNetworkLinks' = {
    name: '${replace(tablePrivateDnsZone.name, '.', '-')}-link'
    location: 'global'
    tags: getHubTags(coreConfig, 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: coreConfig.network.id
      }
    }
  }
}

//------------------------------------------------------------------------------
// Script storage
//------------------------------------------------------------------------------

resource scriptStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = if (coreConfig.network.isPrivate) {
  name: coreConfig.deployment.storage
  location: coreConfig.hub.location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: getHubTags(coreConfig, 'Microsoft.Storage/storageAccounts')
  properties: {
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: coreConfig.network.subnets.scripts
          action: 'Allow'
        }
      ]
    }
  }
}

resource scriptEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (coreConfig.network.isPrivate) {
  name: '${scriptStorageAccount.name}-blob-ep'
  location: coreConfig.hub.location
  tags: getHubTags(coreConfig, 'Microsoft.Network/privateEndpoints')
  properties: {
    subnet: {
      id: coreConfig.network.subnets.storage
    }
    privateLinkServiceConnections: [
      {
        name: 'scriptLink'
        properties: {
          privateLinkServiceId: scriptStorageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
  
  resource scriptPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'blob-endpoint-zone'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: blobPrivateDnsZone.name
          properties: {
            privateDnsZoneId: blobPrivateDnsZone.id
          }
        }
      ]
    }
  }
}


//==============================================================================
// Output
//==============================================================================

@description('FinOps hub configuration settings.')
output config HubCoreConfig = coreConfig

@description('Resource ID of the virtual network.')
output vNetId string = !coreConfig.network.isPrivate ? '' : vNet.id

@description('Virtual network address prefixes.')
output vNetAddressSpace array = !coreConfig.network.isPrivate ? [] : vNet.properties.addressSpace.addressPrefixes

@description('Virtual network subnets.')
output vNetSubnets array = !coreConfig.network.isPrivate ? [] : vNet.properties.subnets

@description('Resource ID of the FinOps hub network subnet.')
output finopsHubSubnetId string = !coreConfig.network.isPrivate ? '' : vNet::finopsHubSubnet.id

@description('Resource ID of the script storage account network subnet.')
output scriptSubnetId string = !coreConfig.network.isPrivate ? '' : vNet::scriptSubnet.id

@description('Resource ID of the Data Explorer network subnet.')
output dataExplorerSubnetId string = !coreConfig.network.isPrivate ? '' : vNet::dataExplorerSubnet.id
