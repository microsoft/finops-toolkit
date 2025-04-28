// Creates Azure dependent resources for Azure AI Foundry
@description('Required. Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Required. Suffix to add to the KeyVault instance name to ensure uniqueness.')
param uniqueSuffix string

@description('Azure region of the deployment')
param location string

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Required. Resource ID of the virtual network for private endpoints.')
param virtualNetworkId string

@description('Required. Resource ID of the subnet for private endpoints.')
param privateEndpointSubnetId string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool = true

// Variables

/*
module applicationInsights './applicationinsights.bicep' = {
  name: 'appi-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    applicationInsightsName: 'appi-${name}-${uniqueSuffix}'
    logAnalyticsWorkspaceName: 'ws-${name}-${uniqueSuffix}'
    tags: tags
  }
}
*/

// Dependent resources for the Azure Machine Learning workspace
module keyvault 'keyvault.bicep' = {
  name: 'finley-keyvault'
  params: {
    location: location
    enablePublicAccess: enablePublicAccess
    privateEndpointSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    hubName: hubName
    uniqueSuffix: uniqueSuffix
    tags: tags
    tagsByResource: tagsByResource
    storageAccountKey: '' // This is not used in this module, but is required for the keyvault module
  }
}
/*
module containerRegistry 'containerregistry.bicep' = {
  name: 'cr${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    containerRegistryName: 'cr${name}${uniqueSuffix}'
    containerRegistryPleName: 'ple-${name}-${uniqueSuffix}-cr'
    subnetId: subnetResourceId
    virtualNetworkId: vnetResourceId
    tags: tags
  }
}

module aiServices 'aiservices.bicep' = {
  name: 'ai${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    aiServiceName: 'ai${name}${uniqueSuffix}'
    aiServicesPleName: 'ple-${name}-${uniqueSuffix}-ais'
    subnetId: subnetResourceId
    virtualNetworkId: vnetResourceId
    tags: tags
  }
}

module storage 'storage.bicep' = {
  name: 'st${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    storageName: 'st${name}${uniqueSuffix}'
    storagePleBlobName: 'ple-${name}-${uniqueSuffix}-st-blob'
    storagePleFileName: 'ple-${name}-${uniqueSuffix}-st-file'
    storageSkuName: 'Standard_LRS'
    subnetId: subnetResourceId
    virtualNetworkId: vnetResourceId
    tags: tags
  }
}

module searchService 'aisearch.bicep' = {
  name: 'search${name}${uniqueSuffix}-deployment'
  params: {
    location: location
    searchServiceName: 'search${name}${uniqueSuffix}'
    searchPrivateLinkName: 'ple-${name}-${uniqueSuffix}-search'
    subnetId: subnetResourceId
    virtualNetworkId: vnetResourceId
    tags: tags
  }
}

output aiservicesID string = aiServices.outputs.aiServicesId
output aiservicesTarget string = aiServices.outputs.aiServicesEndpoint
output storageId string = storage.outputs.storageId
output keyvaultId string = keyvault.outputs.keyvaultId
output containerRegistryId string = containerRegistry.outputs.containerRegistryId
output applicationInsightsId string = applicationInsights.outputs.applicationInsightsId
output searchServiceId string = searchService.outputs.searchServiceId
output searchServiceTarget string = searchService.outputs.searchServiceEndpoint

output aiServicesPrincipalId string = aiServices.outputs.aiServicesPrincipalId
output searchServicePrincipalId string = searchService.outputs.searchServicePrincipalId

output aiservicesName string = aiServices.outputs.aiServicesName
output searchServiceName string = searchService.outputs.searchServiceName
output storageName string = storage.outputs.storageName
*/
