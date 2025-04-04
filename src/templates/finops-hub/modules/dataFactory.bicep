// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the FinOps hub instance.')
param hubName string

@description('Required. Name of the Data Factory instance.')
param dataFactoryName string

@description('Required. The name of the Azure Key Vault instance.')
param keyVaultName string

@description('Required. The name of the Azure storage account instance.')
param storageAccountName string

@description('Required. The name of the container where Cost Management data is exported.')
param exportContainerName string

@description('Required. The name of the container where normalized data is ingested.')
param ingestionContainerName string

@description('Required. The name of the container where normalized data is ingested.')
param configContainerName string

@description('Optional. Name of the Azure Data Explorer cluster to use for advanced analytics, if applicable.')
param dataExplorerName string = ''

@description('Optional. Resource ID of the Azure Data Explorer cluster to use for advanced analytics, if applicable.')
param dataExplorerId string = ''

@description('Optional. ID of the Azure Data Explorer cluster system assigned managed identity, if applicable.')
param dataExplorerPrincipalId string = ''

@description('Optional. URI of the Azure Data Explorer cluster to use for advanced analytics, if applicable.')
param dataExplorerUri string = ''

@description('Optional. Name of the Azure Data Explorer ingestion database. Default: "ingestion".')
param dataExplorerIngestionDatabase string = 'Ingestion'

@description('Optional. Azure Data Explorer ingestion capacity.  Increase for non-dev SKUs. Default: 1')
param dataExplorerIngestionCapacity int = 1

@description('Optional. The location to use for the managed identity and deployment script to auto-start triggers. Default = (resource group location).')
param location string = resourceGroup().location

@description('Optional. Remote storage account for ingestion dataset.')
param remoteHubStorageUri string

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. Enable public access.')
param enablePublicAccess bool

@description('The wildcard folder path for the GCP billing data.')
param gcpBillingWildcardFolderPath string

@description('Required. The secret key for accessing the GCP storage account.')
param gcpSecretKey string

@description('Required. The secret id for accessing the GCP storage account.')
param gcpSecretId string

@description('Required. The name of the GCS bucket for billing data.')
param gcsBucketName string

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var focusSchemaVersion = '1.0'
// cSpell:ignore ftkver
var ftkVersion = loadTextContent('ftkver.txt')
var exportApiVersion = '2023-07-01-preview'
var hubDataExplorerName = 'hubDataExplorer'

// cSpell:ignore timeframe
// Function to generate the body for a Cost Management export
func getExportBody(exportContainerName string, datasetType string, schemaVersion string, isMonthly bool, exportFormat string, compressionMode string, partitionData string, dataOverwriteBehavior string) string => '{ "properties": { "definition": { "dataSet": { "configuration": { "dataVersion": "${schemaVersion}", "filters": [] }, "granularity": "Daily" }, "timeframe": "${isMonthly ? 'TheLastMonth': 'MonthToDate' }", "type": "${datasetType}" }, "deliveryInfo": { "destination": { "container": "${exportContainerName}", "rootFolderPath": "@{if(startswith(item().scope, \'/\'), substring(item().scope, 1, sub(length(item().scope), 1)) ,item().scope)}", "type": "AzureBlob", "resourceId": "@{variables(\'storageAccountId\')}" } }, "schedule": { "recurrence": "${ isMonthly ? 'Monthly' : 'Daily'}", "recurrencePeriod": { "from": "2024-01-01T00:00:00.000Z", "to": "2050-02-01T00:00:00.000Z" }, "status": "Inactive" }, "format": "${exportFormat}", "partitionData": "${partitionData}", "dataOverwriteBehavior": "${dataOverwriteBehavior}", "compressionMode": "${compressionMode}" }, "id": "@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}", "name": "@{variables(\'exportName\')}", "type": "Microsoft.CostManagement/reports", "identity": { "type": "systemAssigned" }, "location": "global" }'

var deployDataExplorer = !empty(dataExplorerId)

var datasetPropsDefault = {
    location: {
      type: 'AzureBlobFSLocation'
      fileName: {
        value: '@{dataset().fileName}'
        type: 'Expression'
      }
      folderPath: {
        value: '@{dataset().folderPath}'
        type: 'Expression'
      }
    }
}

var safeExportContainerName = replace('${exportContainerName}', '-', '_')
var safeIngestionContainerName = replace('${ingestionContainerName}', '-', '_')
var safeConfigContainerName = replace('${configContainerName}', '-', '_')
// cSpell:ignore vnet
var managedVnetName = 'default'

// Separator used to separate ingestion ID from file name for ingested files
var ingestionIdFileNameSeparator = '__'

// All hub triggers (used to auto-start)
var exportManifestAddedTriggerName = '${safeExportContainerName}_ManifestAdded'
var ingestionManifestAddedTriggerName = '${safeIngestionContainerName}_ManifestAdded'
var updateConfigTriggerName = '${safeConfigContainerName}_SettingsUpdated'
var dailyTriggerName = '${safeConfigContainerName}_DailySchedule'
var monthlyTriggerName = '${safeConfigContainerName}_MonthlySchedule'
var allHubTriggers = [
  exportManifestAddedTriggerName
  ingestionManifestAddedTriggerName
  updateConfigTriggerName
  dailyTriggerName
  monthlyTriggerName
]

// Roles needed to auto-start triggers
var autoStartRbacRoles = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
]

// Roles for ADF to manage data in storage
// Does not include roles assignments needed against the export scope
var storageRbacRoles = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#reader
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator
]

//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

// Get keyvault instance
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// cSpell:ignore azuretimezones
module azuretimezones 'azuretimezones.bicep' = {
  name: 'azuretimezones'
  params: {
    location: location
  }
}

resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = if (!enablePublicAccess) {
  name: managedVnetName
  parent: dataFactory
  properties: {}
}

resource managedIntegrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = if (!enablePublicAccess) {
  name: 'ManagedIntegrationRuntime'
  parent: dataFactory
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      referenceName: managedVnetName
      type: 'ManagedVirtualNetworkReference'
    }
    typeProperties: {
      computeProperties: {
        location: location
        dataFlowProperties: {
            computeType: 'General'
            coreCount: 8
            timeToLive: 10
            cleanup: false
            customProperties: []
        }
        copyComputeScaleProperties: {
            dataIntegrationUnit: 16
            timeToLive: 30
        }
        pipelineExternalComputeScaleProperties: {
            timeToLive: 30
            numberOfPipelineNodes: 1
            numberOfExternalNodes: 1
        }
      }
    }
  }
  dependsOn: [
    managedVirtualNetwork
  ]
}

resource storageManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = if (!enablePublicAccess) {
  name: storageAccount.name
  parent: managedVirtualNetwork
  properties: {
    name: storageAccount.name
    groupId: 'dfs'
    privateLinkResourceId: storageAccount.id
    fqdns: [
      storageAccount.properties.primaryEndpoints.dfs
    ]
  }
}

module getStoragePrivateEndpointConnections 'storageEndpoints.bicep' = if (!enablePublicAccess) {
  name: 'GetStoragePrivateEndpointConnections'
  dependsOn: [
    storageManagedPrivateEndpoint
  ]
  params: {
    storageAccountName: storageAccount.name
  }
}

module approveStoragePrivateEndpointConnections 'storageEndpoints.bicep' = if (!enablePublicAccess) {
  name: 'ApproveStoragePrivateEndpointConnections'
  params: {
    storageAccountName: storageAccount.name
    privateEndpointConnections: getStoragePrivateEndpointConnections.outputs.privateEndpointConnections
  }
}

resource keyVaultManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = if (!enablePublicAccess) {
  name: keyVault.name
  parent: managedVirtualNetwork
  properties: {
    name: keyVault.name
    groupId: 'vault'
    privateLinkResourceId: keyVault.id
    fqdns: [
      keyVault.properties.vaultUri
    ]
  }
}

module getKeyVaultPrivateEndpointConnections 'keyVaultEndpoints.bicep' = if (!enablePublicAccess) {
  name: 'GetKeyVaultPrivateEndpointConnections'
  dependsOn: [
    keyVaultManagedPrivateEndpoint
  ]
  params: {
    keyVaultName: keyVault.name
  }
}

module approveKeyVaultPrivateEndpointConnections 'keyVaultEndpoints.bicep' = if (!enablePublicAccess) {
  name: 'ApproveKeyVaultPrivateEndpointConnections'
  params: {
    keyVaultName: keyVault.name
    privateEndpointConnections: getKeyVaultPrivateEndpointConnections.outputs.privateEndpointConnections
  }
}

resource dataExplorerManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = if (deployDataExplorer && !enablePublicAccess) {
  name: hubDataExplorerName
  parent: managedVirtualNetwork
  properties: {
    name: hubDataExplorerName
    groupId: 'cluster'
    privateLinkResourceId: dataExplorerId
    fqdns: [
      dataExplorerUri
    ]
  }
}

module getDataExplorerPrivateEndpointConnections 'dataExplorerEndpoints.bicep' = if (deployDataExplorer && !enablePublicAccess) {
  name: 'GetDataExplorerPrivateEndpointConnections'
  dependsOn: [
    dataExplorerManagedPrivateEndpoint
  ]
  params: {
    dataExplorerName: dataExplorerName
  }
}

module approveDataExplorerPrivateEndpointConnections 'dataExplorerEndpoints.bicep' = if (deployDataExplorer && !enablePublicAccess) {
  name: 'ApproveDataExplorerPrivateEndpointConnections'
  params: {
    dataExplorerName: dataExplorerName
    privateEndpointConnections: getDataExplorerPrivateEndpointConnections.outputs.privateEndpointConnections
  }
}

//------------------------------------------------------------------------------
// Identities and RBAC
//------------------------------------------------------------------------------

// Create managed identity to start/stop triggers
resource triggerManagerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactory.name}_triggerManager'
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
}

resource triggerManagerRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in autoStartRbacRoles: {
  name: guid(dataFactory.id, role, triggerManagerIdentity.id)
  scope: dataFactory
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: triggerManagerIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Grant ADF identity access to manage data in storage
resource factoryIdentityStorageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in storageRbacRoles: {
  name: guid(storageAccount.id, role, dataFactory.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

//------------------------------------------------------------------------------
// Delete old triggers and pipelines
//------------------------------------------------------------------------------

resource deleteOldResources 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_deleteOldResources'
  // cSpell:ignore chinaeast2
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${triggerManagerIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    triggerManagerRoleAssignments
  ]
  tags: union(tags, tagsByResource[?'Microsoft.Resources/deploymentScripts'] ?? {})
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Remove-OldResources.ps1')
    environmentVariables: [
      {
        name: 'DataFactorySubscriptionId'
        value: subscription().id
      }
      {
        name: 'DataFactoryResourceGroup'
        value: resourceGroup().name
      }
      {
        name: 'DataFactoryName'
        value: dataFactory.name
      }
    ]
  }
}

//------------------------------------------------------------------------------
// Stop all triggers before deploying
//------------------------------------------------------------------------------

resource stopTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_stopTriggers'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${triggerManagerIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    triggerManagerRoleAssignments
  ]
  tags: tags
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Start-Triggers.ps1')
    arguments: '-Stop'
    environmentVariables: [
      {
        name: 'DataFactorySubscriptionId'
        value: subscription().id
      }
      {
        name: 'DataFactoryResourceGroup'
        value: resourceGroup().name
      }
      {
        name: 'DataFactoryName'
        value: dataFactory.name
      }
      {
        name: 'Triggers'
        value: join(allHubTriggers, '|')
      }
    ]
  }
}

//------------------------------------------------------------------------------
// Linked services
//------------------------------------------------------------------------------

resource linkedService_keyVault 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: keyVault.name
  parent: dataFactory
  dependsOn: enablePublicAccess ? [] : [managedIntegrationRuntime]
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: reference('Microsoft.KeyVault/vaults/${keyVault.name}', '2023-02-01').vaultUri
    }
    connectVia: enablePublicAccess ? null : { 
      referenceName: managedIntegrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

resource linkedService_storageAccount 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: storageAccount.name
  parent: dataFactory
  dependsOn: enablePublicAccess ? [] : [managedIntegrationRuntime]
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2021-08-01').primaryEndpoints.dfs
    }
    connectVia: enablePublicAccess ? null : { 
      referenceName: managedIntegrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

resource linkedService_dataExplorer 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = if (deployDataExplorer) {
  name: hubDataExplorerName
  parent: dataFactory
  dependsOn: enablePublicAccess ? [] : [managedIntegrationRuntime]
  properties: {
    type: 'AzureDataExplorer'
    parameters: {
      database: {
        type: 'String'
        defaultValue: dataExplorerIngestionDatabase
      }
    }
    typeProperties: {
      endpoint: dataExplorerUri
      database: '@{linkedService().database}'
      tenant: dataFactory.identity.tenantId
      servicePrincipalId: dataFactory.identity.principalId
    }
    connectVia: enablePublicAccess ? null : { 
      referenceName: managedIntegrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

resource linkedService_remoteHubStorage 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = if (!empty(remoteHubStorageUri)) {
  name: 'remoteHubStorage'
  parent: dataFactory
  dependsOn: enablePublicAccess ? [] : [managedIntegrationRuntime]
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: remoteHubStorageUri
      accountKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: linkedService_keyVault.name
          type: 'LinkedServiceReference'
        }
        secretName: '${toLower(hubName)}-storage-key'
      }
    }
    connectVia: enablePublicAccess ? null : { 
      referenceName: managedIntegrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

resource linkedService_ftkRepo 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'ftkRepo'
  parent: dataFactory
  dependsOn: enablePublicAccess ? [] : [managedIntegrationRuntime]
  properties: {
    parameters: {
      filePath: {
        type: 'string'
      }
    }
    annotations: []
    type: 'HttpServer'
    typeProperties: {
      url: '@concat(\'https://github.com/microsoft/finops-toolkit/\', linkedService().filePath)'
      enableServerCertificateValidation: true
      authenticationType: 'Anonymous'
    }
    connectVia: enablePublicAccess ? null : { 
      referenceName: managedIntegrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Existing datasets ...

resource dataset_config 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeConfigContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
      }
    }
    type: 'Json'
    typeProperties: datasetPropsDefault
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_manifest 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'manifest'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
        defaultValue: 'manifest.json'
      }
      folderPath: {
        type: 'String'
        defaultValue: exportContainerName
      }
    }
    type: 'Json'
    typeProperties: datasetPropsDefault
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeExportContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeExportContainerName
      }
      columnDelimiter: ','
      escapeChar: '"'
      quoteChar: '"'
      firstRowAsHeader: true
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports_gzip 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${safeExportContainerName}_gzip'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeExportContainerName
      }
      columnDelimiter: ','
      escapeChar: '"'
      quoteChar: '"'
      firstRowAsHeader: true
      compressionCodec: 'Gzip'
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports_parquet 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${safeExportContainerName}_parquet'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeExportContainerName
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_ingestion 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeIngestionContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeIngestionContainerName
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

//------------------------------------------------------------------------------
// New Dataset: GCS Billing Export Bucket
// This dataset reads from GCS using GoogleCloudStorageReadSettings and uses the new parameters.
//------------------------------------------------------------------------------
resource dataset_GCSbillingexportBucket 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'GCSbillingexportBucket'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      filePath: {
        type: 'String'
      }
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'GoogleCloudStorageLocation'
        bucket: gcsBucketName
        folderPath: '' // Optionally, you can parameterize this if needed.
      }
      columnDelimiter: ','
      escapeChar: '"'
      quoteChar: '"'
      firstRowAsHeader: true
    }
    linkedServiceName: {
      referenceName: 'LinkedService_GCS'
      type: 'LinkedServiceReference'
    }
  }
}

//------------------------------------------------------------------------------
// New Dataset: GCP Ingestion Dataset
// This dataset uses the same ingestion container but writes files into a "GCP" folder.
//------------------------------------------------------------------------------
resource dataset_gcpIngestion 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'gcp_ingestion'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: safeIngestionContainerName
        folderPath: 'GCP'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports_files 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${safeIngestionContainerName}_files'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      folderPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: safeIngestionContainerName
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_dataExplorer 'Microsoft.DataFactory/factories/datasets@2018-06-01' = if (deployDataExplorer) {
  name: hubDataExplorerName
  parent: dataFactory
  properties: {
    type: 'AzureDataExplorerTable'
    linkedServiceName: {
      parameters: {
        database: '@dataset().database'
      }
      referenceName: linkedService_dataExplorer.name
      type: 'LinkedServiceReference'
    }
    parameters: {
      database: {
        type: 'String'
        defaultValue: dataExplorerIngestionDatabase
      }
      table: { type: 'String' }
    }
    typeProperties: {
      table: {
        value: '@dataset().table'
        type: 'Expression'
      }
    }
  }
}

resource dataset_ftkReleaseFile 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'ftkReleaseFile'
  parent: dataFactory
  properties: {
    linkedServiceName: {
      referenceName: linkedService_ftkRepo.name
      type: 'LinkedServiceReference'
    }
    parameters: {
      fileName: {
        type: 'string'
      }
      version: {
        type: 'string'
        defaultValue: ftkVersion
      }
    }
    annotations: []
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'HttpServerLocation'
        relativeUrl: {
          value: '@concat(\'releases/download/v\', dataset().version, \'/\', dataset().fileName)'
          type: 'Expression'
        }
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: []
  }
}

//------------------------------------------------------------------------------
// Triggers
//------------------------------------------------------------------------------

// (Triggers remain unchanged)

resource trigger_ExportManifestAdded 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: exportManifestAddedTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteExportsETL.name
          type: 'PipelineReference'
        }
        parameters: {
          folderPath: '@triggerBody().folderPath'
          fileName: '@triggerBody().fileName'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${exportContainerName}/blobs/'
      blobPathEndsWith: 'manifest.json'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_IngestionManifestAdded 'Microsoft.DataFactory/factories/triggers@2018-06-01' = if (deployDataExplorer) {
  name: ingestionManifestAddedTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteIngestionETL.name
          type: 'PipelineReference'
        }
        parameters: {
          folderPath: '@triggerBody().folderPath'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${ingestionContainerName}/blobs/'
      blobPathEndsWith: 'manifest.json'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_SettingsUpdated 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: updateConfigTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ConfigureExports.name
          type: 'PipelineReference'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${configContainerName}/blobs/'
      blobPathEndsWith: 'settings.json'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_DailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: dailyTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_StartExportProcess.name
          type: 'PipelineReference'
        }
        parameters: {
          Recurrence: 'Daily'
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Hour'
        interval: 24
        startTime: '2023-01-01T01:01:00'
        timeZone: azuretimezones.outputs.Timezone
      }
    }
  }
}

resource trigger_MonthlySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: monthlyTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_StartExportProcess.name
          type: 'PipelineReference'
        }
        parameters: {
          Recurrence: 'Monthly'
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Month'
        interval: 1
        startTime: '2023-01-05T01:11:00'
        timeZone: azuretimezones.outputs.Timezone
        schedule: {
          monthDays: [
            5
            19
          ]
        }
      }
    }
  }
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

// (Pipelines remain unchanged; please refer to your original file for the full definitions)
// For brevity, the pipelines section is as in your original file, including the new import_gcp_billing_data pipeline below.


//------------------------------------------------------------------------------
// import_gcp_billing_data pipeline
//------------------------------------------------------------------------------
resource importGCPBillingDataPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'import_gcp_billing_data'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'convert gcp csv'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Delete Target'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'GoogleCloudStorageReadSettings'
              recursive: true
              wildcardFolderPath: gcpBillingWildcardFolderPath // Parameterized value
              wildcardFileName: '*'
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'DelimitedTextReadSettings'
            }
          }
          sink: {
            type: 'ParquetSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'ParquetWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  name: 'BillingAccountId'
                  type: 'String'
                  physicalType: 'String'
                }
                sink: {
                  name: 'BillingAccountId'
                  type: 'String'
                  physicalType: 'String'
                }
              }
              // Add all other mappings here as per your JSON
            ]
            typeConversion: true
            typeConversionSettings: {
              allowDataTruncation: true
              treatBooleanAsNumber: false
            }
          }
        }
        inputs: [
          {
            referenceName: 'GCSbillingexportBucket'
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: 'gcp_ingestion'
            type: 'DatasetReference'
          }
        ]
      }
      {
        name: 'Delete Target'
        type: 'Delete'
        dependsOn: []
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          dataset: {
            referenceName: 'gcp_ingestion'
            type: 'DatasetReference'
          }
          enableLogging: false
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            recursive: true
            enablePartitionDiscovery: false
          }
        }
      }
    ]
  }
}

//------------------------------------------------------------------------------
// Start all triggers
//------------------------------------------------------------------------------

resource startTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_startTriggers'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  tags: union(tags, tagsByResource[?'Microsoft.Resources/deploymentScripts'] ?? {})
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${triggerManagerIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    triggerManagerRoleAssignments
    trigger_ExportManifestAdded
    trigger_IngestionManifestAdded
    trigger_SettingsUpdated
    trigger_DailySchedule
    trigger_MonthlySchedule
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Start-Triggers.ps1')
    environmentVariables: [
      {
        name: 'DataFactorySubscriptionId'
        value: subscription().id
      }
      {
        name: 'DataFactoryResourceGroup'
        value: resourceGroup().name
      }
      {
        name: 'DataFactoryName'
        value: dataFactory.name
      }
      {
        name: 'Triggers'
        value: join(allHubTriggers, '|')
      }
      {
        name: 'Pipelines'
        value: join([ pipeline_InitializeHub.name ], '|')
      }
    ]
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The Resource ID of the Data factory.')
output resourceId string = dataFactory.id

@description('The Name of the Azure Data Factory instance.')
output name string = dataFactory.name
