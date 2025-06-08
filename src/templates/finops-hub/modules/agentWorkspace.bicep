// Creates an Azure AI resource with proxied endpoints for the Azure AI services provider

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('AI hub name')
param aiHubName string

@description('AI hub display name')
param aiHubFriendlyName string = aiHubName

@description('AI hub description')
param aiHubDescription string

@description('Resource ID of the application insights resource for storing diagnostics logs')
param applicationInsightsId string

@description('Resource ID of the container registry resource for storing docker images')
param containerRegistryId string

@description('Resource ID of the key vault resource for storing connection strings')
param keyVaultId string

@description('Resource ID of the storage account resource for storing experimentation outputs')
param storageAccountId string

@description('Resource ID of the AI Services resource')
param aiServicesId string

@description('Resource ID of the AI Services endpoint')
param aiServicesTarget string

@description('Resource ID of the AI Search resource')
param searchId string

@description('Resource ID of the AI Search endpoint')
param searchTarget string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool

@description('Resource Id of the virtual network to deploy the resource into.')
param virtualNetworkId string

@description('Resource ID of the subnet')
param privateEndpointSubnetId string

@description('Unique Suffix used for name generation')
param uniqueSuffix string

@description('SystemDatastoresAuthMode')
@allowed([
  'identity'
  'accesskey'
])
param systemDatastoresAuthMode string

@description('AI Service Connection Auth Mode')
@allowed([
  'ApiKey'
  'AAD'
])
param connectionAuthMode string
var projectName = take('${aiHubName}-prj', 30)
var privateEndpointName = '${aiHubName}-AIHub-PE'
var targetSubResource = [
    'amlworkspace'
]

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' = {
  name: aiHubName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.MachineLearningServices/workspaces'] ?? {})
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // organization
    friendlyName: aiHubFriendlyName
    description: aiHubDescription

    // dependent resources
    keyVault: keyVaultId
    storageAccount: storageAccountId
    applicationInsights: applicationInsightsId
    containerRegistry: containerRegistryId

    // network settings
    provisionNetworkNow: true
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutBound'
    }
    systemDatastoresAuthMode: systemDatastoresAuthMode
    imageBuildCompute: '${aiHubFriendlyName}img'
  }
  kind: 'hub'

  
  // Azure Search connection
  resource searchServiceConnection 'connections@2024-10-01' = {
    name: '${aiHubName}-connection-Search'
    properties: {
      category: 'CognitiveSearch'
      target: searchTarget
      #disable-next-line BCP225
      authType: connectionAuthMode 
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      sharedUserList: []

      credentials: connectionAuthMode == 'ApiKey'
      ? {
          key: '${listAdminKeys(searchId, '2023-11-01')}'
        }
      : null

      metadata: {
        ApiType: 'Azure'
        ResourceId: searchId
      }
    }
  }

  // AI Services connection
  resource aiServicesConnection 'connections@2024-10-01' = {
    name: '${aiHubName}-connection-AIServices'
    properties: {
      category: 'AIServices'
      target: aiServicesTarget
      #disable-next-line BCP225
      authType: connectionAuthMode 
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      
      credentials: connectionAuthMode == 'ApiKey'
        ? {
            key: '${listKeys(aiServicesId, '2021-10-01')}'
          }
        : null

      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServicesId
      }
    }
  }

}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' = {
  name: projectName
  kind: 'Project'
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.MachineLearningServices/workspaces'] ?? {})
  identity: {
    type: 'systemAssigned'
  }
  sku: {
    tier: 'Standard'
    name: 'standard'
  }
  properties: {
    description: '${aiHubFriendlyName} project'
    friendlyName: '${aiHubFriendlyName} project'
    hbiWorkspace: false
    hubResourceId: aiHub.id
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (!enablePublicAccess) {
  name: privateEndpointName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    customNetworkInterfaceName: '${aiHubName}-nic-${uniqueSuffix}'
    privateLinkServiceConnections: [
      {
        name: aiHubName
        properties: {
          privateLinkServiceId: aiHub.id
          groupIds: targetSubResource
        }
      }
    ]
  }

}

resource privateLinkApi 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!enablePublicAccess) {
  name: 'privatelink.api.azureml.ms'
  location: 'global'
  tags: union(tags, tagsByResource[?'Microsoft.KeyVault/privateDnsZones'] ?? {})
  properties: {}
}

resource privateLinkNotebooks 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!enablePublicAccess) {
  name: 'privatelink.notebooks.azure.net'
  location: 'global'
  tags: union(tags, tagsByResource[?'Microsoft.KeyVault/privateDnsZones'] ?? {})
  properties: {}
}

resource vnetLinkApi 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!enablePublicAccess) {
  parent: privateLinkApi
  name: '${uniqueString(virtualNetworkId)}-api'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource vnetLinkNotebooks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!enablePublicAccess) {
  parent: privateLinkNotebooks
  name: '${uniqueString(virtualNetworkId)}-notebooks'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource dnsZoneGroupAiHub 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!enablePublicAccess) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-api-azureml-ms'
        properties: {
            privateDnsZoneId: privateLinkApi.id
        }
      }
      {
        name: 'privatelink-notebooks-azure-net'
        properties: {
            privateDnsZoneId: privateLinkNotebooks.id
        }
      }
    ]
  }
  dependsOn: [
    vnetLinkApi
    vnetLinkNotebooks
  ]
}

output aiHubID string = aiHub.id
output aiHubName string = aiHub.name
output aiHubPrincipalId string = aiHub.identity.principalId

output projectID string = project.id
output projectPrincipalId string = project.identity.principalId
