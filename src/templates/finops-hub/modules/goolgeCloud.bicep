// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the Data Factory instance.')
param dataFactoryName string

@description('The wildcard folder path for the GCP billing data.')
param gcpBillingWildcardFolderPath string


//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

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


//==============================================================================
// Outputs
//==============================================================================

@description('The name of the data ingestion pipeline.')
output pipelineName string = importGCPBillingDataPipeline.name
