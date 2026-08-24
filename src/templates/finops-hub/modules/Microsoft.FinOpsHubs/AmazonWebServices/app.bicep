// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, privateRoutingForLinkedServices, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as ExportsMetadata } from '../../Microsoft.CostManagement/Exports/metadata.bicep'
import { AppMetadata as AwsMetadata } from './metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.AmazonWebServices'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.CostManagement.Exports'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/AmazonWebServices/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. Metadata describing shared resources from the Core app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'AWS FOCUS ingestion requires FinOps hubs version 13.0 or higher.')
param core CoreMetadata

@description('Required. Metadata describing shared resources from the Cost Management Exports app. Owns the export container the collected files are staged in.')
param exports ExportsMetadata

@description('Required. Name of the Amazon S3 bucket that contains the FOCUS export.')
@minLength(3)
@maxLength(63)
param bucketName string

@description('Required. Path to the export root folder within the bucket. This is the folder that contains the "data" and "metadata" subfolders, without leading or trailing slashes. Example: "reports/focus-export".')
param bucketPath string

@description('Required. Amazon Web Services account ID that owns the export. Used to isolate the data in the hub data lake. Must be lowercase to avoid duplicate ingestion.')
param accountId string

@description('Optional. Amazon Web Services region of the bucket. Used to build the S3 service URL. Leave empty to use the global endpoint. Default: "" (global).')
param region string = ''

@description('Required. Amazon Web Services access key ID used to read the bucket.')
param accessKeyId string

@description('Required. Amazon Web Services secret access key used to read the bucket. Stored in Key Vault.')
@secure()
param secretAccessKey string

@description('Optional. FOCUS version of the export. Only 1.2 is supported today because it is the only version with a validated AWS schema file. Default: "1.2".')
@allowed([
  '1.2'
])
param focusVersion string = '1.2'

@description('Optional. Hour of the day (UTC) to collect FOCUS files. Default: 4.')
@minValue(0)
@maxValue(23)
param scheduleHour int = 4


//==============================================================================
// Variables
//==============================================================================

var AWS = 'aws'

// Name of the Key Vault secret that holds the AWS secret access key.
var secretAccessKeyName = '${AWS}-secret-access-key'

// Amazon Web Services may restate a closed billing period for up to two weeks, so every run
// collects the current and the previous period. Offsets are in months, relative to today.
var collectionOffsets = [0, -1]

// Lowercase account ID. The ETL lowercases the scope before building the destination path, and the
// Data Explorer drop-by tag is case-sensitive, so a mixed-case value silently duplicates the data.
var accountFolder = toLower(accountId)

// Value written to exportConfig.resourceId in the generated manifest. The ETL splits this into the
// scope segment of the destination path: Costs/<yyyy>/<MM>/aws/<accountId>.
var exportResourceId = '/${AWS}/${accountFolder}'

// Schema file the ETL loads is derived from exportConfig.type and exportConfig.dataVersion, so this
// value must match a published schema file: focuscost_<dataVersion>.json.
var exportDataVersion = '${focusVersion}-${AWS}'


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.AmazonWebServices_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
      'KeyVault'
      'Storage'
    ]
  }
}

// Store the AWS secret access key so it is never exposed in the linked service definition.
module keyVault_secret '../../fx/hub-vault.bicep' = {
  name: 'Microsoft.FinOpsHubs.AmazonWebServices_Vault.SecretAccessKey'
  dependsOn: [appRegistration]  // Wait for the Key Vault to be created
  params: {
    vaultName: app.keyVault
    secretName: secretAccessKeyName
    secretValue: secretAccessKey
  }
}

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]

  resource dataset_config 'datasets@2018-06-01' existing = {
    name: core.datasets.config
  }
}

//------------------------------------------------------------------------------
// Linked services
//------------------------------------------------------------------------------

// Amazon S3 connection. The secret access key is resolved from Key Vault at runtime, matching the
// pattern used by the RemoteHub app.
resource linkedService_amazonS3 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${AWS}_s3'
  parent: dataFactory
  dependsOn: [keyVault_secret]
  properties: {
    annotations: []
    parameters: {}
    type: 'AmazonS3'
    typeProperties: union(
      {
        authenticationType: 'AccessKey'
        accessKeyId: accessKeyId
        secretAccessKey: {
          type: 'AzureKeyVaultSecret'
          store: {
            referenceName: app.keyVault
            type: 'LinkedServiceReference'
          }
          secretName: secretAccessKeyName
        }
      },
      empty(region) ? {} : { serviceUrl: 'https://s3.${region}.amazonaws.com' }
    )
    // Required for the linked service to use the managed virtual network when private routing is enabled.
    ...privateRoutingForLinkedServices(app.hub)
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Folder in Amazon S3 used to discover the export manifest. Only used by Get Metadata.
resource dataset_focusManifestFolder 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${AWS}_focus_manifest_folder'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'Binary'
    parameters: {
      folderPath: {
        type: 'String'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_amazonS3.name
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AmazonS3Location'
        bucketName: bucketName
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
      }
    }
  }
}

// Export manifest published by Amazon Web Services. This file is read in place and is never copied
// into the export container: its schema is incompatible with the manifest contract the ETL expects.
resource dataset_focusManifest 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${AWS}_focus_manifest'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'Json'
    parameters: {
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_amazonS3.name
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AmazonS3Location'
        bucketName: bucketName
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
      }
    }
  }
}

// FOCUS data file in Amazon S3. Copied as-is so the file keeps its original format and compression.
resource dataset_focusSource 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${AWS}_focus_source'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'Binary'
    parameters: {
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_amazonS3.name
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AmazonS3Location'
        bucketName: bucketName
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
      }
    }
  }
}

// FOCUS data file staged in the export container, where the existing ETL picks it up.
resource dataset_focusLanding 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${AWS}_focus_landing'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'Binary'
    parameters: {
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: app.storage
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: exports.containers.msexports
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
      }
    }
  }
}

// Writes the generated manifest as raw text. Data Factory cannot build an arbitrary nested JSON
// document with a JSON sink, and a Web activity cannot reach the storage account when private
// routing is enabled, so the manifest is assembled as a string and written verbatim through a
// single-column text sink. Quoting is disabled so the file contains exactly the JSON that was built.
resource dataset_focusManifestLanding 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${AWS}_focus_manifest_landing'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'DelimitedText'
    parameters: {
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: app.storage
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: exports.containers.msexports
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
      }
      // A single column is written, so the delimiter is never emitted. It is set to a character that
      // does not occur in the generated manifest so the value is never quoted.
      columnDelimiter: '~'
      quoteChar: ''
      escapeChar: ''
      firstRowAsHeader: false
      encodingName: 'UTF-8'
    }
    schema: [
      {
        name: 'manifest'
        type: 'String'
      }
    ]
  }
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

// Stages the files listed in a single export manifest and publishes the generated manifest that
// starts the existing ETL. Split into its own pipeline because Data Factory does not allow a
// container activity (ForEach) inside another container activity, and because a child pipeline
// gives each manifest its own variable scope.
resource pipeline_CollectFocusExportManifest 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${AWS}_CollectFocusExportManifest'
  parent: dataFactory
  properties: {
    description: 'Copies the FOCUS files listed in an Amazon Web Services export manifest into the export container and writes the manifest that starts the ingestion pipeline.'
    parameters: {
      billingPeriod: {
        type: 'String'
      }
      manifestFolder: {
        type: 'String'
      }
      manifestFile: {
        type: 'String'
      }
    }
    variables: {
      runId: {
        type: 'String'
      }
      dataFiles: {
        type: 'Array'
      }
      blobs: {
        type: 'Array'
      }
      destinationFolder: {
        type: 'String'
      }
      manifestJson: {
        type: 'String'
      }
    }
    activities: [
      { // Set Run Id
        name: 'Set Run Id'
        description: 'Generate the ingestion ID for this run. Data Explorer replaces all data tagged with a previous ingestion ID, which is what makes a daily refresh idempotent.'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'runId'
          value: {
            value: '@guid()'
            type: 'Expression'
          }
        }
      }
      { // Load Settings
        name: 'Load Settings'
        description: 'Read hub settings to determine how long staged export files are retained.'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.00:05:00'
          retry: 2
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
              recursive: false
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'JsonReadSettings'
            }
          }
          dataset: {
            referenceName: dataFactory::dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: core.settings.file
              folderPath: core.settings.container
            }
          }
          firstRowOnly: true
        }
      }
      { // Read Source Manifest
        name: 'Read Source Manifest'
        description: 'Read the Amazon Web Services export manifest. Only the files it lists are copied: the source folder accumulates one subfolder per refresh, so copying everything would duplicate the period.'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.00:30:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'JsonSource'
            storeSettings: {
              type: 'AmazonS3ReadSettings'
              recursive: false
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'JsonReadSettings'
            }
          }
          dataset: {
            referenceName: dataset_focusManifest.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@pipeline().parameters.manifestFolder'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.manifestFile'
                type: 'Expression'
              }
            }
          }
          firstRowOnly: true
        }
      }
      { // Set Data Files
        name: 'Set Data Files'
        description: 'Save the list of files to copy. The manifest field is dataFiles and each item is a full s3:// URI.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Read Source Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'dataFiles'
          value: {
            value: '@coalesce(activity(\'Read Source Manifest\').output.firstRow.dataFiles, json(\'[]\'))'
            type: 'Expression'
          }
        }
      }
      { // Set Destination Folder
        name: 'Set Destination Folder'
        description: 'Build the staging folder for this run. The run ID keeps repeated or concurrent runs of the same period from overwriting each other mid-copy.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Run Id'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'destinationFolder'
          value: {
            value: '@toLower(concat(\'${AWS}/${accountFolder}/\', pipeline().parameters.billingPeriod, \'/\', variables(\'runId\')))'
            type: 'Expression'
          }
        }
      }
      { // Copy FOCUS Files
        name: 'Copy FOCUS Files'
        description: 'Copy each file listed in the manifest into the export container without changing its format.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Set Data Files'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Destination Folder'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'dataFiles\')'
            type: 'Expression'
          }
          isSequential: false
          batchCount: 4
          activities: [
            {
              name: 'Copy FOCUS File'
              type: 'Copy'
              dependsOn: []
              policy: {
                timeout: '0.12:00:00'
                retry: 2
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                source: {
                  type: 'BinarySource'
                  storeSettings: {
                    type: 'AmazonS3ReadSettings'
                    recursive: false
                  }
                  formatSettings: {
                    type: 'BinaryReadSettings'
                  }
                }
                sink: {
                  type: 'BinarySink'
                  storeSettings: {
                    type: 'AzureBlobFSWriteSettings'
                  }
                }
                enableStaging: false
              }
              inputs: [
                {
                  referenceName: dataset_focusSource.name
                  type: 'DatasetReference'
                  parameters: {
                    // Strip the s3://<bucket>/ prefix to get the object key, then split it into the
                    // folder and file name the dataset expects.
                    folderPath: {
                      value: '@join(take(split(replace(item(), \'s3://${bucketName}/\', \'\'), \'/\'), sub(length(split(replace(item(), \'s3://${bucketName}/\', \'\'), \'/\')), 1)), \'/\')'
                      type: 'Expression'
                    }
                    fileName: {
                      value: '@last(split(item(), \'/\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
              outputs: [
                {
                  referenceName: dataset_focusLanding.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@variables(\'destinationFolder\')'
                      type: 'Expression'
                    }
                    fileName: {
                      value: '@last(split(item(), \'/\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
          ]
        }
      }
      { // Build Blob List
        name: 'Build Blob List'
        description: 'Build the blobs array for the generated manifest. Sequential because AppendVariable is not safe inside a parallel loop.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Copy FOCUS Files'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'dataFiles\')'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Append Blob'
              type: 'AppendVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'blobs'
                value: {
                  // blobName is the path within the export container, which is how the ETL passes it
                  // to the parquet dataset.
                  value: '@json(concat(\'{"blobName":"\', variables(\'destinationFolder\'), \'/\', last(split(item(), \'/\')), \'"}\'))'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Build Manifest
        name: 'Build Manifest'
        description: 'Assemble the manifest the ingestion pipeline expects. dataRowCount is intentionally omitted: the source manifest carries no row count, and writing zero would make the ETL treat the export as empty.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Build Blob List'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Load Settings'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'manifestJson'
          value: {
            value: '@concat(\'{"exportConfig":{"type":"FocusCost","dataVersion":"${exportDataVersion}","exportName":"${AWS}-focus","resourceId":"${exportResourceId}"},"runInfo":{"runId":"\', variables(\'runId\'), \'","startDate":"\', pipeline().parameters.billingPeriod, \'-01T00:00:00Z"},"blobCount":\', string(length(variables(\'blobs\'))), \',"blobs":\', string(variables(\'blobs\')), \',"retention":{"msexports":{"days":\', string(coalesce(activity(\'Load Settings\').output.firstRow.retention.msexports.days, 0)), \'}}}\')'
            type: 'Expression'
          }
        }
      }
      { // Write Manifest
        name: 'Write Manifest'
        description: 'Publish the manifest, which starts the ingestion pipeline. Depends on a successful copy so a manifest is never published over a partial set of files.'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Build Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.00:30:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            // The settings file is only used to produce a single row. Its columns are dropped by the
            // translator below and replaced with the generated manifest.
            type: 'JsonSource'
            storeSettings: {
              type: 'AzureBlobFSReadSettings'
              recursive: false
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'JsonReadSettings'
            }
            additionalColumns: [
              {
                name: 'manifest'
                value: {
                  value: '@variables(\'manifestJson\')'
                  type: 'Expression'
                }
              }
            ]
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'DelimitedTextWriteSettings'
              quoteAllText: false
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  name: 'manifest'
                  type: 'String'
                }
                sink: {
                  name: 'manifest'
                  type: 'String'
                }
              }
            ]
          }
        }
        inputs: [
          {
            referenceName: dataFactory::dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: core.settings.file
              folderPath: core.settings.container
            }
          }
        ]
        outputs: [
          {
            referenceName: dataset_focusManifestLanding.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@variables(\'destinationFolder\')'
                type: 'Expression'
              }
              fileName: 'manifest.json'
            }
          }
        ]
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

// Finds the export manifest for a single billing period. The manifest is published by Amazon Web
// Services only after every data file has landed, so it doubles as the completeness signal.
resource pipeline_CollectFocusExportPeriod 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${AWS}_CollectFocusExportPeriod'
  parent: dataFactory
  properties: {
    description: 'Locates the Amazon Web Services export manifest for one billing period and stages the files it lists.'
    parameters: {
      periodOffsetMonths: {
        type: 'Int'
        defaultValue: 0
      }
    }
    variables: {
      billingPeriod: {
        type: 'String'
      }
      manifestFolder: {
        type: 'String'
      }
    }
    activities: [
      { // Set Billing Period
        name: 'Set Billing Period'
        description: 'Resolve the billing period to collect, formatted the way the source path partitions it.'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'billingPeriod'
          value: {
            value: '@formatDateTime(addToTime(utcNow(), pipeline().parameters.periodOffsetMonths, \'Month\'), \'yyyy-MM\')'
            type: 'Expression'
          }
        }
      }
      { // Set Manifest Folder
        name: 'Set Manifest Folder'
        description: 'Build the path to the metadata partition for the billing period. The partition key is lowercase in the delivered export.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Billing Period'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'manifestFolder'
          value: {
            value: '@concat(\'${bucketPath}/metadata/billing_period=\', variables(\'billingPeriod\'))'
            type: 'Expression'
          }
        }
      }
      { // Find Manifest
        name: 'Find Manifest'
        description: 'List the metadata partition. Requesting the exists field keeps the activity from failing when the period has not been exported yet.'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Set Manifest Folder'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.00:30:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: dataset_focusManifestFolder.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@variables(\'manifestFolder\')'
                type: 'Expression'
              }
            }
          }
          fieldList: [
            'exists'
            'childItems'
          ]
          storeSettings: {
            type: 'AmazonS3ReadSettings'
            recursive: false
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'BinaryReadSettings'
          }
        }
      }
      { // Filter Manifest Files
        name: 'Filter Manifest Files'
        description: 'Keep only the export manifest. The partition may also contain other metadata files.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Find Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@if(activity(\'Find Manifest\').output.exists, activity(\'Find Manifest\').output.childItems, json(\'[]\'))'
            type: 'Expression'
          }
          condition: {
            value: '@and(equals(item().type, \'File\'), endswith(toLower(item().name), \'manifest.json\'))'
            type: 'Expression'
          }
        }
      }
      { // Collect Manifest
        name: 'Collect Manifest'
        description: 'Stage the files listed in the manifest. The loop body does not run when the period has not been exported yet.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Manifest Files'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Manifest Files\').output.Value'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Collect Manifest Files'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CollectFocusExportManifest.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  billingPeriod: {
                    value: '@variables(\'billingPeriod\')'
                    type: 'Expression'
                  }
                  manifestFolder: {
                    value: '@variables(\'manifestFolder\')'
                    type: 'Expression'
                  }
                  manifestFile: {
                    value: '@item().name'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

// Entry point. Amazon Web Services may restate a closed period for up to two weeks, so each run
// collects the current and the previous billing period.
resource pipeline_CollectFocusExport 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${AWS}_CollectFocusExport'
  parent: dataFactory
  properties: {
    description: 'Collects FOCUS cost data exported from Amazon Web Services for the current and previous billing periods.'
    parameters: {
      periodOffsetMonths: {
        type: 'Array'
        defaultValue: collectionOffsets
      }
    }
    activities: [
      { // Collect Billing Periods
        name: 'Collect Billing Periods'
        description: 'Collect each billing period in turn. Sequential to keep the number of concurrent requests to Amazon S3 low.'
        type: 'ForEach'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.periodOffsetMonths'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Collect Billing Period'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CollectFocusExportPeriod.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  periodOffsetMonths: {
                    value: '@item()'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
// Scheduling
//------------------------------------------------------------------------------

resource trigger_DailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${AWS}_DailySchedule'
  parent: dataFactory
  properties: {
    description: 'Collects FOCUS cost data exported from Amazon Web Services once a day.'
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_CollectFocusExport.name
          type: 'PipelineReference'
        }
        parameters: {
          periodOffsetMonths: collectionOffsets
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Day'
        interval: 1
        startTime: '2023-01-01T00:00:00'
        timeZone: 'UTC'
        schedule: {
          hours: [
            scheduleHour
          ]
          minutes: [
            0
          ]
        }
      }
    }
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('The app properties for the Amazon Web Services app.')
output app HubAppProperties = app

@description('Metadata describing resources created by the Amazon Web Services app.')
output metadata AwsMetadata = {
  id: 'Microsoft.FinOpsHubs.AmazonWebServices'
  version: finOpsToolkitVersion
  storage: {
    container: exports.containers.msexports
    folder: '${AWS}/${accountFolder}'
  }
  datasets: {
    focusManifestFolder: dataset_focusManifestFolder.name
    focusManifest: dataset_focusManifest.name
    focusSource: dataset_focusSource.name
    focusLanding: dataset_focusLanding.name
    focusManifestLanding: dataset_focusManifestLanding.name
  }
  linkedServices: {
    amazonS3: linkedService_amazonS3.name
  }
  pipelines: {
    collectFocusExport: pipeline_CollectFocusExport.name
    collectFocusExportPeriod: pipeline_CollectFocusExportPeriod.name
    collectFocusExportManifest: pipeline_CollectFocusExportManifest.name
  }
}
