// Parameters

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

// Generate unique storage account name
var storageAccountSuffix = 'store'
var storageAccountName = '${substring(replace(toLower(hubName), '-', ''), 0, 24 - length(storageAccountSuffix))}${storageAccountSuffix}'

// Data factory naming requirements: Min 3, Max 63, can only contain letters, numbers and non-repeating dashes 
var dataFactorySuffix = '-engine'
var dataFactoryName = '${take(hubName, 63 - length(dataFactorySuffix))}${dataFactorySuffix}'

// Generate unique KeyVault name
var keyVaultSuffixSuffix = 'vault'
var keyVaultName = '${substring(replace(toLower(hubName), '-', ''), 0, 24 - length(keyVaultSuffixSuffix))}${keyVaultSuffixSuffix}'
var keyVaultUri = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage account SKU. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}
var resourceTags = union(tags, {
    'cm-resource-parent': '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
  })

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

@description('Optional. List of scope IDs to create exports for.')
param exportScopes array

// The last segment of the telemetryId is used to identify this module
var telemetryId = '00f120b5-2007-6120-0000-40b000000000'
var finOpsToolkitVersion = '0.0.1'

// Resources

// Telemetry used anonymously to count the number of times the template has been deployed.
// No information about you or your cost data is collected.
resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FinOps toolkit'
          version: finOpsToolkitVersion
        }
      }
      resources: []
    }
  }
}

// ADLSv2 storage account for staging and archive

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'BlockBlobStorage'
  properties: {
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: storageAccount
  name: 'default'
}

resource configContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' =  {
  parent: blobService
  name: 'config'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource exportContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' =  {
  parent: blobService
  name: 'msexports'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource ingestionContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' =  {
  parent: blobService
  name: 'ingestion'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

resource uploadSettingsJson 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'updateSettingsJson'
  kind: 'AzurePowerShell'
  location: location
  dependsOn: [
    configContainer
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'exportScopes'
        value: join(exportScopes, '|')
      }
      {
        name: 'storageAccountKey'
        value: storageAccount.listKeys().keys[0].value
      }
      {
        name: 'storageAccountName'
        value: storageAccountName
      }
      {
        name: 'containerName'
        value: 'config'
      }
    ]
    scriptContent: loadTextContent('./scripts/Copy-FileToAzureBlob.ps1')
  }
}

// Key Vault for storing secrets

module keyVault 'Microsoft.KeyVault/vaults/deploy.bicep' = {
  name: 'keyVault'
  dependsOn: [
    dataFactory
  ]
  params: {
    name: keyVaultName
    location: location
    tags: resourceTags
    enablePurgeProtection: false
    accessPolicies: [
      {
        objectId: dataFactory.outputs.systemAssignedPrincipalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

module keyVaultSecret 'secrets/storageaccountsecret.bicep' = {
  name: 'keyVaultSecret'
  dependsOn: [
    storageAccount
    keyVault
  ]
  params: {
    keyVaultName: keyVaultName
    storageAccountName: storageAccountName
    secretName: storageAccountName
  }
}

// Azure Data Factory and Pipelines
module dataFactory 'Microsoft.DataFactory/factories/deploy.bicep' = {
  name: 'dataFactory'
  params: {
    name: dataFactoryName
    location: location
    tags: resourceTags
    systemAssignedIdentity: true
  }
}

module linkedService_keyVault 'linkedservices/linkedservice.bicep' = {
  name: 'linkedService_keyVault'
  dependsOn: [
    dataFactory
    keyVaultSecret
  ]
  params: {
    dataFactoryName: dataFactoryName
    linkedServiceName: keyVaultName
    linkedServiceType: 'AzureKeyVault'
    linkedServiceTypeProperties:  {
      baseUrl: keyVaultUri
    }
  }
}

module linkedService_storageAccount 'linkedservices/linkedservice.bicep' = {
  name: 'linkedService_storageAccount'
  dependsOn: [
    dataFactory
    linkedService_keyVault
  ]
  params: {
    dataFactoryName: dataFactoryName
    linkedServiceName: storageAccountName
    linkedServiceType: 'AzureBlobFS'
    linkedServiceTypeProperties: {
      url: reference('Microsoft.Storage/storageAccounts/${storageAccountName}', '2019-04-01').primaryEndpoints.dfs
      accountKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: keyVaultName
          type: 'LinkedServiceReference'
        }
        secretName: storageAccountName
      }
    }
  }
}

module dataset_msexports 'datasets/adlsv2.bicep' = {
  name: 'msexports'
  dependsOn: [
    linkedService_storageAccount
    linkedService_keyVault
  ]
  params: {
    dataFactoryName: dataFactoryName
    linkedServiceName: storageAccountName
    compressionCodec: 'none'
    datasetType: 'DelimitedText'
    containerName: exportContainer.name
  }
}

module dataset_ingestion_csv 'datasets/adlsv2.bicep' = {
  name: 'ingestion_csv'
  dependsOn: [
    linkedService_storageAccount
    linkedService_keyVault
  ]
  params: {
    dataFactoryName: dataFactoryName
    linkedServiceName: storageAccountName
    datasetType: 'DelimitedText'
    containerName: ingestionContainer.name
  }
}

module dataset_ingestion_parquet 'datasets/adlsv2.bicep' = {
  name: 'ingestion_parquet'
  dependsOn: [
    linkedService_storageAccount
    linkedService_keyVault
  ]
  params: {
    dataFactoryName: dataFactoryName
    linkedServiceName: storageAccountName
    datasetType: 'Parquet'
    containerName: ingestionContainer.name
  }
}


module extract_parquet 'pipelines/msexports_extract.bicep' = {
  name: 'msexports_extract_parquet'
  dependsOn: [
    transform_parquet
  ]
  params: {
    dataFactoryName: dataFactoryName
    exportContainerName: exportContainer.name
    outputFormat: 'parquet'
  }
}

module extract_csv 'pipelines/msexports_extract.bicep' = {
  name: 'msexports_extract_csv'
  dependsOn: [
    transform_csv
  ]
  params: {
    dataFactoryName: dataFactoryName
    exportContainerName: exportContainer.name
    outputFormat: 'csv'
  }
}

module transform_parquet 'pipelines/msexports_transform.bicep' = {
  name: 'msexports_transform_parquet'
  dependsOn: [
    dataset_msexports
    dataset_ingestion_parquet
  ]
  params: {
    dataFactoryName: dataFactoryName
    sinkDataset:  replace('${ingestionContainer.name}_Parquet', '-', '_')
    sourceDataset:  replace('${exportContainer.name}_DelimitedText', '-', '_')
    ingestionContainerName: ingestionContainer.name
    exportContainerName: exportContainer.name
  }
}

module transform_csv 'pipelines/msexports_transform.bicep' = {
  name: 'msexports_transform_csv'
  dependsOn: [
    dataset_msexports
    dataset_ingestion_csv
  ]
  params: {
    dataFactoryName: dataFactoryName
    sinkDataset:  replace('${ingestionContainer.name}_DelimitedText', '-', '_')
    sourceDataset:  replace('${exportContainer.name}_DelimitedText', '-', '_')
    ingestionContainerName: ingestionContainer.name
    exportContainerName: exportContainer.name
  }
}

module trigger_msexports 'triggers/adlsv2.bicep' = {
  name: 'trigger_msexports'
  dependsOn: [
    extract_parquet
    extract_csv
  ]
  params: {
    dataFactoryName: dataFactoryName
    storageAccountId: storageAccount.id
    BlobContainerName: exportContainer.name
    PipelineName: 'msexports_extract_parquet'
    triggerName: 'msexports_trigger'
  }
}

// Outputs

@description('Name of the deployed hub instance.')
output name string = hubName

@description('Azure resource location resources were deployed to.')
output location string = location

@description('Name of the Data Factory.')
output dataFactorytName string = dataFactoryName

@description('Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.')
output storageAccountId string = storageAccount.id

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = storageAccountName

@description('Resource name of the storage account trigger.')
output storageAccountTriggerName string = trigger_msexports.outputs.name

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = 'https://${storageAccountName}.dfs.${environment().suffixes.storage}/${ingestionContainer.name}'
