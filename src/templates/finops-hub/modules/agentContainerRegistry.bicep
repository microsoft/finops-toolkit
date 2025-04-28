// Creates an Azure Container Registry with Azure Private Link endpoint
@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Container registry name')
param containerRegistryName string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool = true

@description('Container registry private link endpoint name')
param containerRegistryPleName string

@description('Resource ID of the subnet')
param privateEndpointSubnetId string

@description('Resource ID of the virtual network')
param virtualNetworkId string

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

var privateDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'

var groupName = 'registry' 

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryNameCleaned
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.ContainerRegistry/registries'] ?? {})
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: enablePublicAccess ? 'Allow' : 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'enabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}

resource containerRegistryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (!enablePublicAccess) {
  name: containerRegistryPleName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: containerRegistryPleName
        properties: {
          groupIds: [
            groupName
          ]
          privateLinkServiceId: containerRegistry.id
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!enablePublicAccess) {
  name: privateDnsZoneName
  location: 'global'
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (!enablePublicAccess) {
  parent: containerRegistryPrivateEndpoint
  name: '${groupName}-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties:{
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

resource acrPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!enablePublicAccess) {
  parent: acrPrivateDnsZone
  name: uniqueString(containerRegistry.id)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

output containerRegistryId string = containerRegistry.id
