// Creates Azure dependent resources for Azure AI Foundry

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Tags to add to the resources')
param tags object = {}

@description('AI services name')
param aiServicesName string

@description('AI hub name')
param aiHubName string

@description('AI friendly name')
param aiHubFriendlyName string

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

@description('AI Service Connection Auth Mode')
@allowed([
  'ApiKey'
  'AAD'
])
param connectionAuthMode string

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

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: aiServicesName
  location: location
  tags: tags
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
    publicNetworkAccess: 'Enabled'
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

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2025-01-01-preview' = {
  name: aiHubName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // organization
    friendlyName: '${aiHubFriendlyName} resources'
    description: '${aiHubFriendlyName} resources'

    // dependent resources
    keyVault: keyVault.id
    storageAccount: storage.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
  }
  kind: 'hub'

  resource aiServicesConnection 'connections@2024-01-01-preview' = {
    name: '${aiHubName}-connection-AzureOpenAI'
    properties: {
      category: 'AzureOpenAI'
      target: aiServices.properties.endpoint
      authType: 'ApiKey'
      isSharedToAll: true
      credentials: {
        key: '${listKeys(aiServices.id, '2021-10-01').key1}'
      }
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServices.id
      }
    }
  }

  resource searchServiceConnection 'connections@2024-01-01-preview' = {
    name: '${aiHubName}-connection-Search'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${searchService.name}.search.windows.net'
      #disable-next-line BCP225
      authType: connectionAuthMode 
      isSharedToAll: true
      useWorkspaceManagedIdentity: false
      sharedUserList: []

      credentials: connectionAuthMode == 'ApiKey'
      ? {
          key: '${listAdminKeys(searchService.id, '2023-11-01')}'
        }
      : null

      metadata: {
        ApiType: 'Azure'
        ResourceId: searchService.id
      }
    }
  }
}

resource project 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: '${aiHubName}-project'
  kind: 'Project'
  location: location
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

output aiservicesID string = aiServices.id
output aiservicesTarget string = aiServices.properties.endpoint
output storageId string = storage.id
output keyvaultId string = keyVault.id
output containerRegistryId string = containerRegistry.id
output applicationInsightsId string = applicationInsights.id
