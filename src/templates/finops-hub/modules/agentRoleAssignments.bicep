@description('AI Hub Name')
param aiHubName string

@description('AI Hub Id')
param aiHubPrincipalId string

@description('AI Services Name')
param aiServicesName string

@description('AI Services Id')
param aiServicesPrincipalId string

@description('AI Project Principal Id (managed identity)')
param aiProjectPrincipalId string

@description('Search Service Name')
param searchServiceName string

@description('Container Registry Name')
param containerRegistryName string

@description('Search Service Id')
param searchServicePrincipalId string

@description('Storage Name')
param storageName string

@description('Key Vault Name')
param keyVaultName string

var role = {
  SearchIndexDataContributor : '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  SearchServiceContributor : '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  StorageBlobDataReader : '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDataContributor : 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' 
  CognitiveServicesOpenAiContributor : 'a001fd3d-188f-4b5d-821b-7da978bf7442'
  CognitiveServicesOpenAIUser : '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  CognitiveServicesUser : 'a97b65f3-24c7-4388-baec-2e87135dc908'
  acrPull : '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AzureAIDeveloper : '64702f94-c441-49e6-a78b-ef80e0188fee'
  AzureAIUser : '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  AzureAIAdministrator : 'fecbff3f-2bbb-4c05-a32b-77c654b1c8e5'
  KeyVaultSecretsUser : '4633458b-17de-408a-b874-0445c86b69e6'
  Contributor : 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchServiceName
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiServicesName
}



resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: containerRegistryName
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiServicesPrincipalId, 'acrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.acrPull)
    principalId: aiServicesPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageName
}

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' existing = {
  name: aiHubName
}

resource searchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiServicesPrincipalId, 'SearchIndexDataContributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.SearchIndexDataContributor)
    principalId: aiServicesPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource searchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiServicesPrincipalId, 'SearchServiceContributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.SearchServiceContributor)
    principalId: aiServicesPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobDataContributorAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiServicesPrincipalId, 'StorageBlobDataContributorAI')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.StorageBlobDataContributor)
    principalId: aiServicesPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesOpenAiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, searchServicePrincipalId, 'CognitiveServicesOpenAiContributor')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.CognitiveServicesOpenAiContributor)
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobDataContributorSearch 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, searchServicePrincipalId, 'StorageBlobDataContributorSearch')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.StorageBlobDataContributor)
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Commented out - AI Hub already has this role assignment automatically
// resource aiHubReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, aiHubPrincipalId, 'StorageBlobDataReaderAIHub')
//   scope: storage
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.StorageBlobDataReader)
//     principalId: aiHubPrincipalId
//     principalType: 'ServicePrincipal'
//   }
// }

// Azure AI Agents role assignments for project managed identity
resource azureAIDeveloperRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'AzureAIDeveloper', aiProjectPrincipalId)
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.AzureAIDeveloper)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource azureAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'AzureAIUser', aiProjectPrincipalId)
  scope: aiHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.AzureAIUser)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Additional role assignments for AAD authentication
resource cognitiveServicesOpenAIUserHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'CognitiveServicesOpenAIUserHub')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.CognitiveServicesOpenAIUser)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesOpenAIUserProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiProjectPrincipalId, 'CognitiveServicesOpenAIUserProject')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.CognitiveServicesOpenAIUser)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource searchIndexDataContributorHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'SearchIndexDataContributorHub')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.SearchIndexDataContributor)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Commented out - AI Hub already has this role assignment automatically
// resource storageBlobDataContributorHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceGroup().id, aiHubPrincipalId, 'StorageBlobDataContributorHub')
//   scope: storage
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.StorageBlobDataContributor)
//     principalId: aiHubPrincipalId
//     principalType: 'ServicePrincipal'
//   }
// }

// Key Vault permissions for AI Hub to access secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecretsUserHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'KeyVaultSecretsUserHub')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.KeyVaultSecretsUser)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultSecretsUserProject 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiProjectPrincipalId, 'KeyVaultSecretsUserProject')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.KeyVaultSecretsUser)
    principalId: aiProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services User role for AI Hub to use AI Services
resource cognitiveServicesUserHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'CognitiveServicesUserHub')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.CognitiveServicesUser)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Contributor role for AI Hub on AI Services (required for connections)
resource cognitiveServicesContributorHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'CognitiveServicesContributorHub')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.Contributor)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Contributor role for AI Hub on Search Service (required for connections)
resource searchServiceContributorHub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aiHubPrincipalId, 'SearchServiceContributorHub')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.Contributor)
    principalId: aiHubPrincipalId
    principalType: 'ServicePrincipal'
  }
}

