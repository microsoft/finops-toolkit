// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubCoreConfig } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

//------------------------------------------------------------------------------
// Google Cloud parameters
//------------------------------------------------------------------------------

@description('Required. The name of the Google Cloud storage bucket.')
param googleCloudStorageBucket string

@description('Required. The folder path to find data in Google Cloud storage. This path supports wildcards.')
param googleCloudStoragePath string

@description('Required. The access key ID used to connect to Google Cloud storage.')
param googleCloudStorageKeyId string

@description('Required. The access key used to connect to Google Cloud storage.')
@secure()
param googleCloudStorageKey string

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

//------------------------------------------------------------------------------
// Temporary parameters that should be removed in the future
//------------------------------------------------------------------------------

// TODO: Pull deployment config from the cloud
@description('Required. FinOps hub coreConfig.')
param coreConfig HubCoreConfig

@description('Required. Name of the Data Factory instance for this publisher.')
param dataFactoryName string

@description('Required. The name of the container where normalized data is ingested.')
param ingestionContainerName string

// TODO: Use a function to reference the schema file path via a reusable function
@description('Required. The name of the config container dataset.')
param configDatasetName string

@description('Required. The name of the container schema files are stored in.')
param schemaContainerName string

@description('Required. The folder path of the schema folder within the schema container.')
param schemaFolderPath string

@description('Required. The name of the managed identity to use for uploading files.')
param blobManagerIdentityName string

@description('Required. The name of the Azure Key Vault instance for this publisher.')
param keyVaultName string


//==============================================================================
// Variables
//==============================================================================

var costSchemaFileName = 'googlecloud-focuscost_1.0' // cSpell:ignore googlecloud
var costSchemaFile = '${costSchemaFileName}.json'

var schemaFiles = {
  '${schemaFolderPath}/${costSchemaFile}': loadTextContent('../schemas/${costSchemaFile}')
}

var accessKeySecretName = 'googlecloud-storage-key'

// TODO: Pull ingestionIdFileNameSeparator from a type file
var ingestionIdFileNameSeparator = '__'


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Register app
//------------------------------------------------------------------------------

module appRegistration 'hub-app.bicep' = {
  name: 'FinOpsToolkit.Contrib.GoogleCloud.Core_Register'
  params: {
    displayName: 'Google Cloud data ingestion'
    publisher: 'FinOps toolkit community for Google Cloud'
    namespace: 'FinOpsToolkit.Contrib.GoogleCloud'
    appName: 'Core'
    appVersion: loadTextContent('ftkver.txt') // cSpell:ignore ftkver
    features: [
      'Storage'
    ]
    enableDefaultTelemetry: enableDefaultTelemetry
    
    coreConfig: coreConfig
  }
}

//------------------------------------------------------------------------------
// Upload schema file to storage
// TODO: Move to the hub-storage module
//------------------------------------------------------------------------------

resource blobManagerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: blobManagerIdentityName
}

module configContainer 'hub-storage.bicep' = {
  name: 'FinOpsToolkit.Contrib.GoogleCloud.Core_SchemaFiles'
  params: {
    container: schemaContainerName
    files: schemaFiles

    // Hub context
    storageAccountName: appRegistration.outputs.config.publisher.storage
    blobManagerIdentityName: blobManagerIdentity.name
    enablePublicAccess: !coreConfig.network.isPrivate
    location: coreConfig.hub.location
    scriptStorageAccountName: coreConfig.deployment.storage
    scriptSubnetId: coreConfig.network.subnets.scripts
    tags: coreConfig.hub.tags
    tagsByResource: coreConfig.deployment.tagsByResource
  }
}

//------------------------------------------------------------------------------
// Store secrets in Key Vault
//------------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

module secret_accessKey 'hub-vault.bicep' = {
  name: 'FinOpsToolkit.Contrib.GoogleCloud.Core_AccessKeySecret'
  params: {
    vaultName: keyVault.name
    secretName: accessKeySecretName
    secretValue: googleCloudStorageKey
    secretExpirationInSeconds: 1702648632
    secretNotBeforeInSeconds: 10000
  }
}

//------------------------------------------------------------------------------
// Pipeline
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName

  // cSpell:ignore linkedservices
  resource linkedService_keyVault 'linkedservices' existing = {
    name: keyVault.name
}

  resource dataset_ingestion 'datasets' existing = {
    name: ingestionContainerName
  }
}

resource linkedService_googleCloudStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: 'googleCloudStorage'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'GoogleCloudStorage'
    typeProperties: {
      serviceUrl: 'https://storage.googleapis.com'
      accessKeyId: googleCloudStorageKeyId
      secretAccessKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: dataFactory::linkedService_keyVault.name
          type: 'LinkedServiceReference'
        }
        secretName: accessKeySecretName
      }
    }
  }
  dependsOn: []
}

resource dataset_googleCloudStorage 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'googleCloudStorage'
  parent: dataFactory
  properties: {
    linkedServiceName: {
      referenceName: linkedService_googleCloudStorage.name
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'GoogleCloudStorageLocation'
        bucketName: googleCloudStorageBucket
        folderPath: googleCloudStoragePath
      }
      columnDelimiter: ';'
      escapeChar: '"'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: [
      {
        name: 'BilledCost;BillingAccountId;BillingAccountName;BillingAccountType;BillingCurrency;BillingPeriodEnd;BillingPeriodStart;ChargeCategory;ChargeClass;ChargeDescription;ChargeFrequency;ChargePeriodEnd;ChargePeriodStart;CommitmentDiscountCategory;CommitmentDiscountId;CommitmentDiscountName;CommitmentDiscountStatus;CommitmentDiscountType;ConsumedQuantity;ConsumedUnit;ContractedCost;ContractedUnitPrice;EffectiveCost;InvoiceIssuerName;ListCost;ListUnitPrice;PricingCategory;PricingQuantity;PricingUnit;ProviderName;PublisherName;RegionId;RegionName;ResourceId;ResourceName;ResourceType;ServiceCategory;ServiceName;SkuId;SkuPriceId;SubAccountId;SubAccountName;SubAccountType;Tags;x_Credits;x_CostType;x_CurrencyConversionRate;x_ExportTime;x_Location;x_Project;x_ServiceId'
        type: 'String'
      }
    ]
  }
}

resource pipeline_ToIngestion 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'googleCloud_ETL_${ingestionContainerName}'
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
              fileName: {
                value: 'pipeline().parameters.schemaFile'
                type: 'Expression'
              }
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
            value: '@concat(\'Unable to load the \', pipeline().parameters.schemaFile, \' schema file. Please confirm the schema and version are supported for FinOps hubs ingestion.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaLoadFailed'
        }
      }
      { // Set Destination Path
        name: 'Set Destination Path'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'destinationPath'
          value: {
            // TODO: How do we pass in destinationFolder, ingestionId, and destinationFile in to pipeline parameters? What's the trigger? Do we need ExecuteETL?
            value: '@concat(pipeline().parameters.destinationFolder, \'/\', pipeline().parameters.ingestionId, \'${ingestionIdFileNameSeparator}\', pipeline().parameters.destinationFile)'
            type: 'Expression'
          }
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
              wildcardFolderPath: googleCloudStoragePath
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
            referenceName: dataset_googleCloudStorage.name
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: dataFactory::dataset_ingestion.name
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@variables(\'destinationPath\')'
                type: 'Expression'
          }
            }
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
    parameters: {
      destinationFile: {
        type: 'string'
  }
      destinationFolder: {
        type: 'string'
}
      ingestionId: {
        type: 'string'
      }
      schemaFile: {
        type: 'string'
        defaultValue: costSchemaFile
      }
      exportDatasetType: {
        type: 'string'
        defaultValue: 'GoogleCloud-FocusCost'
      }
      exportDatasetVersion: {
        type: 'string'
        defaultValue: '1.0'
      }
    }
    variables: {
      destinationPath: {
        type: 'String'
      }
    }
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('The name of the data ingestion pipeline.')
output pipelineName string = pipeline_ToIngestion.name
