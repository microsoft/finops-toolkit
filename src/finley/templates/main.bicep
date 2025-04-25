
// Execute this main file to depoy Azure AI Foundry resources in the basic security configuraiton

// Parameters
@minLength(2)
@maxLength(12)
@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string = 'finops-hub'

@description('Friendly name for your Azure AI resource')
param aiHubFriendlyName string = 'FinOps hubs'

@description('Azure region used for the deployment of all resources.')
param location string = resourceGroup().location

@description('Set of tags to apply to all resources.')
param tags object = {}

param cognitiveServicesSku string = 'S0'
param aoaisku string = 'Standard'
param aoaiskuCapacity int = 30
param aoaiversion string = '2024-11-20'
param textEmbeddingSku string = 'Standard'
param textEmbeddingSkuCapacity int = 30
param textEmbeddingVersion string = '1'
param deepSeekVersion string = '1'
param deepseekSku string = 'GlobalStandard'
param deepseekSkuCapacity int = 1

// Variables
var name = toLower('${hubName}')
var uniqueSuffix = substring(uniqueString(name, subscription().subscriptionId , resourceGroup().id), 0, 4)

// Dependent resources for the Azure Machine Learning workspace
module aiDependencies 'modules/ai-resources.bicep' = {
  name: 'dependencies-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    storageName: 'st${name}${uniqueSuffix}'
    keyvaultName: 'kv-${name}-${uniqueSuffix}'
    applicationInsightsName: 'appi-${name}-${uniqueSuffix}'
    containerRegistryName: 'cr${name}${uniqueSuffix}'
    aiServicesName: 'ais${name}${uniqueSuffix}'
    tags: tags
    sku: {
      name: cognitiveServicesSku
    }
    kind: 'AIServices'
    deployments: [
      {
        name: 'gpt-4o'
        model: {
          format: 'OpenAI'
          name: 'gpt-4o'
          version: aoaiversion
        }
        sku: {
          name: aoaisku
          capacity: aoaiskuCapacity
        }
      }
      {
        name: 'text-embedding-3-large'
        model: {
          format: 'OpenAI'
          name: 'text-embedding-3-large'
          version: textEmbeddingVersion
        }
        sku: {
          name: textEmbeddingSku
          capacity: textEmbeddingSkuCapacity
        }
      }
      {
        name: 'DeepSeek-R1'
        model: {
          format: 'DeepSeek'
          name: 'DeepSeek-R1'
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


module aiHub 'modules/ai-hub.bicep' = {
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiHubName: 'aih-${name}-${uniqueSuffix}'
    aiHubFriendlyName: aiHubFriendlyName
    location: location
    tags: tags

    // dependent resources
    aiServicesId: aiDependencies.outputs.aiservicesID
    aiServicesTarget: aiDependencies.outputs.aiservicesTarget
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
    containerRegistryId: aiDependencies.outputs.containerRegistryId
    keyVaultId: aiDependencies.outputs.keyvaultId
    storageAccountId: aiDependencies.outputs.storageId
  }
}
