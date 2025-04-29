// Execute this main file to deploy Azure AI Foundry resources in the basic security configuration

// Parameters
@description('Required. Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Required. Suffix to add to the KeyVault instance name to ensure uniqueness.')
param uniqueSuffix string

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool = true

@description('Required. Id of the virtual network for private endpoints.')
param virtualNetworkId string

@description('Required. Id of the subnet for private endpoints.')
param privateEndpointSubnetId string

@description('Required. Id of the subnet for private endpoints.')
param dataExplorerSubnetId string

@description('The location into which the resources should be deployed.')
param location string 

param cognitiveServicesSku string = 'S0'

param aoamodel string = 'gpt-4o'
param aoaiformat string = 'OpenAI'
param aoaisku string = 'Standard'
param aoaiskuCapacity int = 30
param aoaiversion string = '2024-11-20'

param textEmbeddingModel string = 'text-embedding-3-large'
param textEmbeddingFormat string = 'OpenAI'
param textEmbeddingSku string = 'Standard'
param textEmbeddingSkuCapacity int = 30
param textEmbeddingVersion string = '1'

param deepSeekModel string = 'DeepSeek-R1'
param deepSeekFormat string = 'DeepSeek'
param deepSeekVersion string = '1'
param deepseekSku string = 'GlobalStandard'
param deepseekSkuCapacity int = 1

@description('Determines whether or not to use credentials for the system datastores of the workspace workspaceblobstore and workspacefilestore. The default value is accessKey, in which case, the workspace will create the system datastores with credentials. If set to identity, the workspace will create the system datastores with no credentials.')
@allowed([
  'identity'
  'accesskey'
])
param systemDatastoresAuthMode string = 'identity'

@description('Determines whether to use an API key or Azure Active Directory (AAD) for the AI service connection authentication. The default value is apiKey.')
@allowed([
  'ApiKey'
  'AAD'
])
param connectionAuthMode string = 'ApiKey'

// Variables
var agentName = toLower('ai${hubName}')

// Dependent resources for the Azure Machine Learning workspace

module agentKeyvault 'keyvault.bicep' = {
  name: 'agent-keyvault'
  params: {
    location: location
    enablePublicAccess: enablePublicAccess
    privateEndpointSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    hubName: agentName
    uniqueSuffix: uniqueSuffix
    tags: tags
    tagsByResource: tagsByResource
    storageAccountKey: '' // This is not used in this module, but is required for the keyvault module
  }
}

module agentContainerRegistry 'agentContainerRegistry.bicep' = {
  name: 'agent-container-registry'
  params: {
    location: location
    containerRegistryName: '${agentName}${uniqueSuffix}'
    containerRegistryPleName: 'ple-${agentName}-${uniqueSuffix}-cr'
    privateEndpointSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

module agentSearchService 'agentSearch.bicep' = {
  name: 'agent-search-service'
  params: {
    location: location
    searchServiceName: '${agentName}${uniqueSuffix}search'
    searchPrivateLinkName: 'ple-${agentName}-${uniqueSuffix}-search'
    enablePublicAccess: enablePublicAccess
    privateEndpointSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    tags: tags
    tagsByResource: tagsByResource
  }
}

module agentStorage 'agentStorage.bicep' = {
  name: 'agent-storage'
  params: {
    storageName: '${take(agentName, 24 - length(uniqueSuffix))}${uniqueSuffix}'
    storagePleBlobName: 'ple-${agentName}-${uniqueSuffix}-blob'
    storagePleFileName: 'ple-${agentName}-${uniqueSuffix}-file'
    storageSkuName: 'Standard_LRS'
    location: location
    enablePublicAccess: enablePublicAccess
    privateEndpointSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    tags: tags
    tagsByResource: tagsByResource
  }
}

module agentcognitiveservices 'agentCognitiveServices.bicep'  = {
  name: 'agent-cognitive-services'
  params: {
    location: location
    enablePublicAccess: enablePublicAccess
    virtualNetworkId: virtualNetworkId
    privateEndpointSubnetId: dataExplorerSubnetId // Because we're running out of IPs on the private endpoint subnet - use the data explorer subnet for the cognitive services private endpoint
    aiServiceName: '${agentName}${uniqueSuffix}'
    aiServicesPleName: 'ple-${agentName}-${uniqueSuffix}-cog'
    aiServiceSkuName: cognitiveServicesSku
    tags: tags
    tagsByResource: tagsByResource
    deployments: [
      {
        name: aoamodel
        model: {
          format: aoaiformat
          name: aoamodel
          version: aoaiversion
        }
        sku: {
          name: aoaisku
          capacity: aoaiskuCapacity
        }
      }
      {
        name: textEmbeddingModel
        model: {
          format: textEmbeddingFormat
          name: textEmbeddingModel
          version: textEmbeddingVersion
        }
        sku: {
          name: textEmbeddingSku
          capacity: textEmbeddingSkuCapacity
        }
      }
      {
        name: deepSeekModel
        model: {
          format: deepSeekFormat
          name: deepSeekModel
          version: deepSeekVersion
        }
        sku: {
          name: deepseekSku
          capacity: deepseekSkuCapacity
        }
      }
    ]
  }  
}

module agentworkspace 'agentWorkspace.bicep' = {
  name: 'agent-ml-workspace'
  params: {
    // workspace organization
    aiHubName: '${agentName}${uniqueSuffix}hub'
    aiHubFriendlyName: '${hubName} AI Hub'
    aiHubDescription: 'AI Hub for ${hubName}'
    location: location
    tags: tags

    //metadata
    uniqueSuffix: uniqueSuffix

    //network related
    enablePublicAccess: enablePublicAccess
    virtualNetworkId: virtualNetworkId
    privateEndpointSubnetId: dataExplorerSubnetId // We're running out of IPs on the private endpoint subnet - use the data explorer subnet for the cognitive services private endpoint

    // dependent resources
    aiServicesId: agentcognitiveservices.outputs.aiServicesId
    aiServicesTarget: agentcognitiveservices.outputs.aiServicesEndpoint
    //applicationInsightsId: aiDependencies.outputs.applicationInsightsId
    containerRegistryId: agentContainerRegistry.outputs.containerRegistryId
    keyVaultId: agentKeyvault.outputs.resourceId
    storageAccountId: agentStorage.outputs.storageId
    searchId: agentSearchService.outputs.searchServiceId
    searchTarget: agentSearchService.outputs.searchServiceEndpoint

    //configuration settings
    systemDatastoresAuthMode: systemDatastoresAuthMode
    connectionAuthMode: connectionAuthMode

  }
}

// Assignment of roles necessary for template usage
module agentroleassignments 'agentRoleAssignments.bicep' = {
  name: 'agent-role-assignments'
  params: {
    aiHubName: agentworkspace.outputs.aiHubName
    aiHubPrincipalId: agentworkspace.outputs.aiHubPrincipalId
    aiServicesPrincipalId: agentcognitiveservices.outputs.aiServicesPrincipalId
    aiServicesName: agentcognitiveservices.outputs.aiServicesName
    searchServicePrincipalId: agentSearchService.outputs.searchServicePrincipalId
    searchServiceName: agentSearchService.outputs.searchServiceName
    storageName: agentStorage.outputs.storageName
  }
}

