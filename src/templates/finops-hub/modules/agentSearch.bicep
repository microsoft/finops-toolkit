@description('Azure region of the deployment')
param location string

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Name of the Azure Cognitive Search service')
param searchServiceName string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool

@description('Name of the private link endpoint for the search service')
param searchPrivateLinkName string

@description('Resource ID of the subnet')
param privateEndpointSubnetId string

@description('Resource ID of the virtual network')
param virtualNetworkId string

@description('Search SKU')
@allowed([
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
param searchSkuName string = 'standard'

var searchPrivateDnsZoneName = 'privatelink.search.windows.net'

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchServiceName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Search/searchServices'] ?? {})
  sku: {
    name: searchSkuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: { 
      aadOrApiKey: { 
        aadAuthFailureMode: 'http403'
      }
    }
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    networkRuleSet: {
      ipRules: []
      bypass: 'AzureServices'
    }
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
  }
}

resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (!enablePublicAccess) {
  name: searchPrivateLinkName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: searchPrivateLinkName
        properties: {
          groupIds: [
            'searchService'
          ]
          privateLinkServiceId: searchService.id
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

resource searchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!enablePublicAccess) {
  name: searchPrivateDnsZoneName
  location: 'global'
}

resource searchPrivateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (!enablePublicAccess) {
  parent: searchPrivateEndpoint
  name: 'search-PrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: searchPrivateDnsZoneName
        properties: {
          privateDnsZoneId: searchPrivateDnsZone.id
        }
      }
    ]
  }
}

resource searchPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!enablePublicAccess) {
  parent: searchPrivateDnsZone
  name: uniqueString(searchService.id)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

output searchServiceId string = searchService.id
output searchServicePrincipalId string = searchService.identity.principalId
output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchServiceName}.search.windows.net'
