// Creates Azure dependent resources for Azure AI Foundry

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Tags to add to the resources')
param tags object = {}

@description('AI services name')
param aiServicesName string

@description('Application Insights resource name')
param applicationInsightsName string

@description('Container registry name')
param containerRegistryName string

@description('The name of the Key Vault')
param keyvaultName string

@description('Cognitive Services SKU. Defaults to S0.')
param sku object = {
  name: 'S0'
}
@description('Cognitive Services Kind. Defaults to AIServices.')
@allowed([
  'AIServices'
  'Bing.Speech'
  'SpeechTranslation'
  'TextTranslation'
  'Bing.Search.v7'
  'Bing.Autosuggest.v7'
  'Bing.CustomSearch'
  'Bing.SpellCheck.v7'
  'Bing.EntitySearch'
  'Face'
  'ComputerVision'
  'ContentModerator'
  'TextAnalytics'
  'LUIS'
  'SpeakerRecognition'
  'CustomSpeech'
  'CustomVision.Training'
  'CustomVision.Prediction'
  'OpenAI'
])
param kind string = 'AIServices'

@description('List of deployments for Cognitive Services.')
param deployments array = []

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: false
    DisableLocalAuth: false
    Flow_Type: 'Bluefield'
    ForceCustomerStorageForProfiler: false
    ImmediatePurgeDataOn30Days: true
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Disabled'
    Request_Source: 'rest'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryNameCleaned
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    enableRbacAuthorization: true
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

@description('Name of the storage account')
param storageName string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Storage SKU')
param storageSkuName string = 'Standard_LRS'

var storageNameCleaned = replace(storageName, '-', '')
var policyName = '${aiServicesName}-policy'

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  sku: sku
  kind: kind
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageNameCleaned
  location: location
  tags: tags
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource raiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01' = {
  parent: aiServices
  name: policyName
  properties: {
    basePolicyName: 'Microsoft.Default'
    contentFilters:[
      {
          name: 'Hate'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Hate'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Sexual'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Sexual'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Violence'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Violence'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Selfharm'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Selfharm'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
        name: 'jailbreak'
        blocking: true
        enabled: true
        source: 'Prompt'
      }
      {
          name: 'protected_material_text'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'protected_material_code'
          blocking: true
          enabled: true
          source: 'Completion'
      }
    ]
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: aiServices
  name: deployment.name
  properties: {
    model: deployment.?model ?? null
    raiPolicyName: deployment.?raiPolicyName ?? raiPolicy.name
  }
  sku: deployment.?sku ?? null
}]

output aiservicesID string = aiServices.id
output aiservicesTarget string = aiServices.properties.endpoint
output storageId string = storage.id
output keyvaultId string = keyVault.id
output containerRegistryId string = containerRegistry.id
output applicationInsightsId string = applicationInsights.id
