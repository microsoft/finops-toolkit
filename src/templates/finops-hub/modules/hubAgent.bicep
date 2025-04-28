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

@description('The location into which the resources should be deployed.')
param location string 

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
var name = toLower('${hubName}')

// Dependent resources for the Azure Machine Learning workspace
module aiDependencies 'aiDependencies.bicep' = {
  name: 'finley-dependencies'
  params: {
    location: location
    hubName: name
    uniqueSuffix: uniqueSuffix
    enablePublicAccess: enablePublicAccess
    virtualNetworkId: virtualNetworkId
    privateEndpointSubnetId: privateEndpointSubnetId
    tagsByResource: tagsByResource
    tags: tags
  }
}

/*
module aiHub './aiHub.bicep' = {
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiHubName: 'aih-${name}-${uniqueSuffix}'
    aiHubFriendlyName: aiHubFriendlyName
    aiHubDescription: aiHubDescription
    location: location
    tags: tags

    //metadata
    uniqueSuffix: uniqueSuffix

    //network related
    vnetResourceId: vnetResourceId
    subnetResourceId: subnetResourceId

    // dependent resources
    aiServicesId: aiDependencies.outputs.aiservicesID
    aiServicesTarget: aiDependencies.outputs.aiservicesTarget
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
    containerRegistryId: aiDependencies.outputs.containerRegistryId
    keyVaultId: aiDependencies.outputs.keyvaultId
    storageAccountId: aiDependencies.outputs.storageId
    searchId: aiDependencies.outputs.searchServiceId
    searchTarget: aiDependencies.outputs.searchServiceTarget

    //configuration settings
    systemDatastoresAuthMode: systemDatastoresAuthMode
    connectionAuthMode: connectionAuthMode

  }
}

// Assignment of roles necessary for template usage
module roleAssignments 'aiRoleAssignments.bicep' = {
  name: 'role-assignments-${name}-${uniqueSuffix}-deployment'
  params: {
    aiHubName: aiHub.outputs.aiHubName
    aiHubPrincipalId: aiHub.outputs.aiHubPrincipalId
    aiServicesPrincipalId: aiDependencies.outputs.aiServicesPrincipalId
    aiServicesName: aiDependencies.outputs.aiservicesName
    searchServicePrincipalId: aiDependencies.outputs.searchServicePrincipalId
    searchServiceName: aiDependencies.outputs.searchServiceName
    storageName: aiDependencies.outputs.storageName
  }
}
*/
