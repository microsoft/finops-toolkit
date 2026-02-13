// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, privateRoutingForLinkedServices } from '../../fx/hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Optional. Name of the config container. Default: config.')
param configContainerName string = 'config'

@description('Optional. Name of the ingestion container. Default: ingestion.')
param ingestionContainerName string = 'ingestion'


//==============================================================================
// Variables
//==============================================================================

var QUERIES = 'queries'

// Separator used to separate ingestion ID from file name for ingested files
var ingestionIdFileNameSeparator = '__'

// Load query files
var queryFiles = {
  'HubsRecommendations-AdvisorCost': loadTextContent('queries/HubsRecommendations-AdvisorCost.json')
  'HubsRecommendations-BackendlessAppGateways': loadTextContent('queries/HubsRecommendations-BackendlessAppGateways.json')
  'HubsRecommendations-BackendlessLoadBalancers': loadTextContent('queries/HubsRecommendations-BackendlessLoadBalancers.json')
  'HubsRecommendations-EmptySQLElasticPools': loadTextContent('queries/HubsRecommendations-EmptySQLElasticPools.json')
  'HubsRecommendations-NonSpotAKSClusters': loadTextContent('queries/HubsRecommendations-NonSpotAKSClusters.json')
  'HubsRecommendations-SQLVMsWithoutAHB': loadTextContent('queries/HubsRecommendations-SQLVMsWithoutAHB.json')
  'HubsRecommendations-StoppedVMs': loadTextContent('queries/HubsRecommendations-StoppedVMs.json')
  'HubsRecommendations-UnattachedDisks': loadTextContent('queries/HubsRecommendations-UnattachedDisks.json')
  'HubsRecommendations-UnattachedPublicIPs': loadTextContent('queries/HubsRecommendations-UnattachedPublicIPs.json')
  'HubsRecommendations-VMsWithoutAHB': loadTextContent('queries/HubsRecommendations-VMsWithoutAHB.json')
}

// Load schema files
var schemaFiles = {
  'recommendations_1.0': loadTextContent('schemas/recommendations_1.0.json')
}

// Workaround for Bicep warning when using "ResourceId" in property names
var armEndpointPropertyName = 'aadResourceId'


//==============================================================================
// Resources
//==============================================================================

// App registration
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
      'Storage'
    ]
  }
}

// Upload query files to storage
module uploadQueries '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_UploadQueries'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: configContainerName
    files: reduce(items(queryFiles), {}, (acc, item) => union(acc, { '${QUERIES}/${item.key}.json': item.value }))
  }
}

// Upload schema files to storage
module uploadSchemas '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_UploadSchemas'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: configContainerName
    files: reduce(items(schemaFiles), {}, (acc, item) => union(acc, { 'schemas/${item.key}.json': item.value }))
  }
}

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]
}

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: app.storage
  dependsOn: [appRegistration]
}

//------------------------------------------------------------------------------
// Linked Services
//------------------------------------------------------------------------------

// ARM linked service for Azure Resource Graph
resource linkedService_arm 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'azurerm'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'RestService'
    typeProperties: union(
      {
        url: environment().resourceManager
        authenticationType: 'ManagedServiceIdentity'
        enableServerCertificateValidation: true
      },
      {
        // Workaround: When bicep sees "ResourceId" in the property name, it raises a warning
        '${armEndpointPropertyName}': environment().resourceManager
      }
    )
    ...privateRoutingForLinkedServices(app.hub)
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Resource Graph dataset
resource dataset_resourcegraph 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'resourceGraph'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'RestResource'
    typeProperties: {
      relativeUrl: '/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01'
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_arm.name
      type: 'LinkedServiceReference'
    }
  }
}

// Reference existing datasets from Core app
resource dataset_config 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: 'config'
  parent: dataFactory
}

resource dataset_ingestion 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: ingestionContainerName
  parent: dataFactory
}

resource dataset_ingestion_files 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: '${ingestionContainerName}_files'
  parent: dataFactory
}

resource dataset_manifest 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: '${ingestionContainerName}_manifest'
  parent: dataFactory
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

// queries_ExecuteETL pipeline - Orchestrates execution of all ARG query files
resource pipeline_ExecuteQueries 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_ExecuteETL'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Load Queries'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.00:10:00'
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
              wildcardFileName: '*.json'
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'JsonReadSettings'
            }
          }
          dataset: {
            referenceName: dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: 'settings.json'
              folderPath: '${configContainerName}/${QUERIES}'
            }
          }
          firstRowOnly: false
        }
      }
      {
        name: 'Set Ingestion Id'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'ingestionId'
          value: {
            value: '@guid()'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Iterate Files'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Load Queries'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Ingestion Id'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Load Queries\').output.value'
            type: 'Expression'
          }
          batchCount: 2
          isSequential: false
          activities: [
            {
              name: 'Execute File Queries'
              description: 'Execute the queries declared in the queries file.'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteQueries_query.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  ingestionId: {
                    value: '@variables(\'ingestionId\')'
                    type: 'Expression'
                  }
                  inputDataset: {
                    value: '@item().queryEngine'
                    type: 'Expression'
                  }
                  outputDataset: {
                    value: '@item().dataset'
                    type: 'Expression'
                  }
                  schemaFile: {
                    value: '@concat(toLower(item().dataset), \'_\', item().version, \'.json\')'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@item().scope'
                    type: 'Expression'
                  }
                  query: {
                    value: '@item().query'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@item().version'
                    type: 'Expression'
                  }
                  querySource: {
                    value: '@item().source'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@item().provider'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@item().type'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Append Manifest Data'
              type: 'AppendVariable'
              dependsOn: [
                {
                  activity: 'Execute File Queries'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'manifestPaths'
                value: {
                  value: '@concat(item().dataset, \'/\', item().scope)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      {
        name: 'Distinct Manifest Data'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Iterate Files'
            dependencyConditions: ['Completed']
          }
        ]
        policy: {
          secureInput: false
          secureOutput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'uniqueManifestPaths'
          value: {
            value: '@union(variables(\'manifestPaths\'), variables(\'manifestPaths\'))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Generate Manifest Blobs'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Distinct Manifest Data'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'uniqueManifestPaths\')'
            type: 'Expression'
          }
          batchCount: 2
          isSequential: false
          activities: [
            {
              name: 'Create Manifest'
              description: 'Create a manifest file in the ingestion container to trigger ADX ingestion'
              type: 'Copy'
              dependsOn: []
              policy: {
                timeout: '0.12:00:00'
                retry: 0
                retryIntervalInSeconds: 30
                secureInput: false
                secureOutput: false
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
                sink: {
                  type: 'JsonSink'
                  storeSettings: {
                    type: 'AzureBlobFSWriteSettings'
                  }
                  formatSettings: {
                    type: 'JsonWriteSettings'
                  }
                }
                enableStaging: false
              }
              inputs: [
                {
                  referenceName: dataset_config.name
                  type: 'DatasetReference'
                  parameters: {
                    fileName: 'manifest.json'
                    folderPath: configContainerName
                  }
                }
              ]
              outputs: [
                {
                  referenceName: dataset_manifest.name
                  type: 'DatasetReference'
                  parameters: {
                    fileName: 'manifest.json'
                    folderPath: {
                      value: '@concat(\'${ingestionContainerName}/\', split(item(),\'/\')[0], \'/\', utcNow(\'yyyy/MM/dd\'), \'/\', split(item(),\'/\')[1])'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    ]
    variables: {
      ingestionId: {
        type: 'String'
      }
      manifestPaths: {
        type: 'Array'
      }
      uniqueManifestPaths: {
        type: 'Array'
      }
    }
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

// queries_ETL_ingestion pipeline - Executes individual queries
resource pipeline_ExecuteQueries_query 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_ETL_ingestion'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Set Blob Timestamp'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'blobExportTimestamp'
          value: {
            value: '@concat(utcNow(\'yyyy\'),\'/\',utcNow(\'MM\'),\'/\',utcNow(\'dd\'),\'/\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Query Error Value'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'queryError'
          value: {
            value: '@string(\'\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Blob Base Path'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Blob Timestamp'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'blobBasePath'
          value: {
            value: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'blobExportTimestamp\'), pipeline().parameters.queryScope, \'/\', pipeline().parameters.ingestionId, \'${ingestionIdFileNameSeparator}\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Get Existing Parquet Files'
        description: 'Get the previously ingested files so we can remove any older data.'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Set Blob Timestamp'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: dataset_ingestion_files.name
            type: 'DatasetReference'
            parameters: {
              folderPath: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'blobExportTimestamp\'), pipeline().parameters.queryScope)'
            }
          }
          fieldList: ['childItems']
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'ParquetReadSettings'
          }
        }
      }
      {
        name: 'Filter Out Current Exports'
        description: 'Remove existing files from the current export so those files do not get deleted.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get Existing Parquet Files'
            dependencyConditions: ['Completed']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@if(contains(activity(\'Get Existing Parquet Files\').output, \'childItems\'), activity(\'Get Existing Parquet Files\').output.childItems, json(\'[]\'))'
            type: 'Expression'
          }
          condition: {
            value: '@and(endswith(item().name, concat(pipeline().parameters.queryType, \'.parquet\')), not(startswith(item().name, concat(pipeline().parameters.ingestionId, \'${ingestionIdFileNameSeparator}\'))))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'For Each Old File'
        description: 'Loop thru each of the existing files from previous exports.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Out Current Exports'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Out Current Exports\').output.Value'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Delete Old Ingested File'
              description: 'Delete the previously ingested files from older exports.'
              type: 'Delete'
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
                dataset: {
                  referenceName: dataset_ingestion.name
                  type: 'DatasetReference'
                  parameters: {
                    blobPath: {
                      value: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'blobExportTimestamp\'), pipeline().parameters.queryScope, \'/\', item().name)'
                      type: 'Expression'
                    }
                  }
                }
                enableLogging: false
                storeSettings: {
                  type: 'AzureBlobFSReadSettings'
                  recursive: false
                  enablePartitionDiscovery: false
                }
              }
            }
          ]
        }
      }
      {
        name: 'Load Schema Mappings'
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
            referenceName: dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: {
                value: '@pipeline().parameters.schemaFile'
                type: 'Expression'
              }
              folderPath: '${configContainerName}/schemas'
            }
          }
        }
      }
      {
        name: 'Switch Query Engine'
        type: 'Switch'
        dependsOn: [
          {
            activity: 'Set Blob Base Path'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'For Each Old File'
            dependencyConditions: ['Completed']
          }
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          on: {
            value: '@pipeline().parameters.inputDataset'
            type: 'Expression'
          }
          cases: [
            {
              value: dataset_resourcegraph.name
              activities: [
                {
                  name: 'Execute ARG Query'
                  type: 'Copy'
                  dependsOn: []
                  policy: {
                    timeout: '0.00:10:00'
                    retry: 0
                    retryIntervalInSeconds: 60
                    secureOutput: false
                    secureInput: false
                  }
                  userProperties: []
                  typeProperties: {
                    source: {
                      type: 'RestSource'
                      httpRequestTimeout: '00:02:00'
                      requestInterval: '00.00:00:00.050'
                      requestMethod: 'POST'
                      requestBody: {
                        value: '@concat(\'{ "query": "\', pipeline().parameters.query, \' | extend x_SourceName=\\"\', pipeline().parameters.querySource, \'\\", x_SourceType=\\"\', pipeline().parameters.queryType, \'\\", x_SourceProvider=\\"\', pipeline().parameters.queryProvider, \'\\", x_SourceVersion=\\"\', pipeline().parameters.queryVersion, \'\\"" }\')'
                        type: 'Expression'
                      }
                      additionalHeaders: {
                        'Content-Type': 'application/json'
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
                      referenceName: dataset_resourcegraph.name
                      type: 'DatasetReference'
                      parameters: {}
                    }
                  ]
                  outputs: [
                    {
                      referenceName: dataset_ingestion.name
                      type: 'DatasetReference'
                      parameters: {
                        blobPath: {
                          value: '@concat(variables(\'blobBasePath\'), pipeline().parameters.queryType, \'.parquet\')'
                          type: 'Expression'
                        }
                      }
                    }
                  ]
                }
                {
                  name: 'Set ARG Query Error'
                  type: 'SetVariable'
                  dependsOn: [
                    {
                      activity: 'Execute ARG Query'
                      dependencyConditions: ['Failed']
                    }
                  ]
                  policy: {
                    secureOutput: false
                    secureInput: false
                  }
                  userProperties: []
                  typeProperties: {
                    variableName: 'queryError'
                    value: {
                      value: '@string(activity(\'Execute ARG Query\').output.errors)'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionId: {
        type: 'String'
      }
      inputDataset: {
        type: 'String'
      }
      outputDataset: {
        type: 'String'
      }
      schemaFile: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      querySource: {
        type: 'String'
      }
      queryProvider: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
    }
    variables: {
      blobExportTimestamp: {
        type: 'String'
      }
      blobBasePath: {
        type: 'String'
      }
      queryError: {
        type: 'String'
      }
    }
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('The app properties for the Recommendations app.')
output app HubAppProperties = app

@description('Name of the queries_ExecuteETL pipeline.')
output pipelineName string = pipeline_ExecuteQueries.name
