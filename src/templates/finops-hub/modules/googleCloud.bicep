// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the Data Factory instance.')
param dataFactoryName string

@description('Required. The name of the Azure storage account instance.')
param storageAccountName string

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Required. The wildcard folder path for the GCP billing data.')
param gcpBillingWildcardFolderPath string

// TODO: Use a function to reference the schema file path via a reusable function
@description('Required. The name of the config container dataset.')
param configDatasetName string

@description('Required. The name of the container schema files are stored in.')
param schemaContainerName string

@description('Required. The folder path of the schema folder within the schema container.')
param schemaFolderPath string

@description('Required. The name of the managed identity to use for uploading files.')
param blobManagerIdentityName string

@description('Required. Indicates whether public access should be enabled.')
param enablePublicAccess bool

@description('The name of the storage account used for deployment scripts.')
param scriptStorageAccountName string

@description('Required. Resource ID of the virtual network for running deployment scripts.')
param scriptSubnetId string


//==============================================================================
// Variables
//==============================================================================

var costSchemaFileName = 'googlecloud-focuscost_1.0' // cSpell:ignore googlecloud
var costSchemaFile = '${costSchemaFileName}.json'

var schemaFiles = {
  '${schemaFolderPath}/${costSchemaFile}': loadTextContent('../schemas/${costSchemaFile}')
}


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Upload schema file to storage
// TODO: Move to the hub-storage module
//------------------------------------------------------------------------------

resource scriptStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing =  if (!enablePublicAccess){
  name: scriptStorageAccountName
}

resource blobManagerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: blobManagerIdentityName
}

resource uploadFiles 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${storageAccountName}_uploadFiles'
  kind: 'AzurePowerShell'
  // cSpell:ignore chinaeast
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  tags: union(tags, tagsByResource[?'Microsoft.Resources/deploymentScripts'] ?? {})
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${blobManagerIdentity.id}': {}
    }
  }
  dependsOn: []
  properties: union(enablePublicAccess ? {} : {
    storageAccountSettings: {
      storageAccountName: scriptStorageAccount.name
    }
    containerSettings: {
      containerGroupName: '${scriptStorageAccount.name}cg'
      subnetIds: [
        {
          id: scriptSubnetId
        }
      ]
    }
  }, {
    azPowerShellVersion: '9.0'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'containerName'
        value: schemaContainerName
      }
      {
        name: 'files'
        value: string(schemaFiles)
      }
    ]
    scriptContent: loadTextContent('./scripts/Upload-StorageFile.ps1')
  })
}

//------------------------------------------------------------------------------
// Pipeline
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource importGCPBillingDataPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'import_gcp_billing_data'
  parent: dataFactory
  properties: {
    activities: [
      { // Load Schema Mappings
        name: 'Load Schema Mappings'
        description: 'Get schema mapping file to use for the CSV to parquet conversion.'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'JsonSource'
            storeSettings: {
              type: 'AzureBlobFSReadSettings'
              recursive: true
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'JsonReadSettings'
            }
          }
          dataset: {
            referenceName: configDatasetName
            type: 'DatasetReference'
            parameters: {
              fileName: costSchemaFile
              folderPath: schemaFolderPath
            }
          }
        }
      }
      { // Error: SchemaLoadFailed
        name: 'Failed to Load Schema'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@concat(\'Unable to load the \', costSchemaFile, \' schema file. Please confirm the schema and version are supported for FinOps hubs ingestion.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaLoadFailed'
        }
      }
      { // convert gcp csv
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
            value: '@activity(\'Load Schema Mappings\').output.firstRow.translator'
            type: 'Expression'
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
      { // Delete Target
        name: 'Delete Target'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: [
              'Succeeded'
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


//==============================================================================
// Outputs
//==============================================================================

@description('The name of the data ingestion pipeline.')
output pipelineName string = importGCPBillingDataPipeline.name
