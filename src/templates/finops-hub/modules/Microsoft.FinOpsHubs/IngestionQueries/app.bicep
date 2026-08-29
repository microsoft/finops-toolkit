// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as IngestionQueriesMetadata } from './metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.IngestionQueries'
  version: '$$ftkver$$'
  dependencies: ['Microsoft.FinOpsHubs.Core']
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/IngestionQueries/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. Metadata describing shared resources from the Core app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'Core app version must be 13.0 or higher.')
param core CoreMetadata


//==============================================================================
// Variables
//==============================================================================

var QUERIES = 'queries'


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.IngestionQueries_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
    ]
  }
}

// Get ADF resources
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]

  resource linkedService_storageAccount 'linkedservices@2018-06-01' existing = {
    name: app.storage
  }
  resource dataset_config 'datasets@2018-06-01' existing = {
    name: core.datasets.config
  }
  resource dataset_ingestion 'datasets@2018-06-01' existing = {
    name: core.datasets.ingestion
  }
  resource dataset_ingestion_files 'datasets@2018-06-01' existing = {
    name: core.datasets.ingestionFiles
  }
  resource dataset_manifest 'datasets@2018-06-01' existing = {
    name: core.datasets.ingestionManifest
  }
  resource dataset_msexports_parquet_files 'datasets@2018-06-01' = {
    name: 'msexports_parquet_files'
    properties: {
      linkedServiceName: {
        referenceName: linkedService_storageAccount.name
        type: 'LinkedServiceReference'
      }
      parameters: {
        folderPath: {
          type: 'String'
        }
      }
      type: 'Parquet'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          fileSystem: 'msexports'
          folderPath: {
            value: '@dataset().folderPath'
            type: 'Expression'
          }
        }
      }
    }
  }
}

//------------------------------------------------------------------------------
// Scheduling
//------------------------------------------------------------------------------

module timeZones '../../Microsoft.CostManagement/ManagedExports/timeZones.bicep' = {
  name: 'Microsoft.FinOpsHubs.IngestionQueries_TimeZones'
  params: {
    location: app.hub.location
  }
}

resource trigger_DailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${QUERIES}_DailySchedule'
  parent: dataFactory
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteQueries.name
          type: 'PipelineReference'
        }
        parameters: {}
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Hour'
        interval: 4
        startTime: '2023-01-01T01:01:00'
        timeZone: timeZones.outputs.Timezone
      }
    }
  }
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

resource pipeline_ExecuteQueries 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${QUERIES}_ExecuteETL'
  parent: dataFactory
  properties: {
    concurrency: 1
    activities: [
      { // Load Queries
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
            referenceName: dataFactory::dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: '*.json'
              folderPath: '${core.containers.config}/${QUERIES}'
            }
          }
          firstRowOnly: false
        }
      }
      { // Set Ingestion Id
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
            value: '@concat(utcNow(\'yyyyMMdd-HHmmss\'), \'_\', substring(guid(), 0, 8))'
            type: 'Expression'
          }
        }
      }
      { // Loop Thru Queries
        name: 'Loop Thru Queries'
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
          batchCount: 50
          isSequential: false
          activities: [
            {  // Execute File Queries
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
                  queryEngine: {
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
                  queryScopeTypes: {
                    value: '@if(contains(item(), \'scopeTypes\'), item().scopeTypes, json(\'[]\'))'
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
          ]
        }
      }
    ]
    parameters: {}
    variables: {
      ingestionId: {
        type: 'String'
      }
    }
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

resource pipeline_ExecuteQueries_query 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${QUERIES}_ETL_${core.containers.ingestion}'
  parent: dataFactory
  properties: {
    activities: [
      { // Normalize Query Scope
        name: 'Normalize Query Scope'
        description: 'Replace "Tenant" with "tenants/{tenantId}" to ensure unique paths across Remote Hubs.'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'queryScope'
          value: {
            value: '@if(equals(toLower(pipeline().parameters.queryScope), \'tenant\'), \'tenants/${tenant().tenantId}\', if(startsWith(pipeline().parameters.queryScope, \'/\'), substring(pipeline().parameters.queryScope, 1), pipeline().parameters.queryScope))'
            type: 'Expression'
          }
        }
      }
      { // Set Ingestion Path
        name: 'Set Ingestion Path'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Normalize Query Scope'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'ingestionPath'
          value: {
            value: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'queryScope\'), \'/\', pipeline().parameters.queryType, \'/\', pipeline().parameters.ingestionId, \'${core.ingestionIdFileNameSeparator}\')'
            type: 'Expression'
          }
        }
      }
      { // Get Existing Parquet Files
        name: 'Get Existing Parquet Files'
        description: 'Get the previously ingested files so we can remove any older data.'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Normalize Query Scope'
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
            referenceName: dataFactory::dataset_ingestion_files.name
            type: 'DatasetReference'
            parameters: {
              folderPath: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'queryScope\'), \'/\', pipeline().parameters.queryType)'
            }
          }
          fieldList: [
            'exists'
            'childItems'
          ]
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'ParquetReadSettings'
          }
        }
      }
      { // Filter Out Current Exports
        name: 'Filter Out Current Exports'
        description: 'Remove existing files from the current export so those files do not get deleted.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get Existing Parquet Files'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@if(and(activity(\'Get Existing Parquet Files\').output.exists, contains(activity(\'Get Existing Parquet Files\').output, \'childItems\')), activity(\'Get Existing Parquet Files\').output.childItems, json(\'[]\'))'
            type: 'Expression'
          }
          condition: {
            value: '@not(startswith(item().name, concat(pipeline().parameters.ingestionId, \'${core.ingestionIdFileNameSeparator}\')))'
            type: 'Expression'
          }
        }
      }
      { // Delete Old Files Loop
        name: 'Delete Old Files Loop'
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
          batchCount: 50
          isSequential: false
          activities: [
            {  // Delete Old Ingested File
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
                  referenceName: dataFactory::dataset_ingestion.name
                  type: 'DatasetReference'
                  parameters: {
                    blobPath: {
                      value: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'queryScope\'), \'/\', pipeline().parameters.queryType, \'/\', item().name)'
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
      { // Load Schema Mappings
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
            referenceName: dataFactory::dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: {
                value: '@pipeline().parameters.schemaFile'
                type: 'Expression'
              }
              folderPath: '${core.containers.config}/schemas'
            }
          }
        }
      }
      { // Run Query Engine Pipeline
        name: 'Run Query Engine Pipeline'
        description: 'Run Azure Resource Manager queries as owned child pipelines; retain REST dispatch for other engines.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Set Ingestion Path'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Delete Old Files Loop'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(toLower(pipeline().parameters.queryEngine), \'azureresourcemanager\')'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Azure Resource Manager Query'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: 'queries_AzureResourceManager_ExecuteQuery'
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryDataset: {
                    value: '@pipeline().parameters.outputDataset'
                    type: 'Expression'
                  }
                  queryEngine: {
                    value: '@pipeline().parameters.queryEngine'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@pipeline().parameters.queryScope'
                    type: 'Expression'
                  }
                  queryScopeTypes: {
                    value: '@pipeline().parameters.queryScopeTypes'
                    type: 'Expression'
                  }
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@concat(variables(\'ingestionPath\'), pipeline().parameters.queryType, \'.parquet\')'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@activity(\'Load Schema Mappings\').output.firstRow.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
          ifFalseActivities: [
            {
              name: 'Start Other Query Engine Pipeline'
              type: 'WebActivity'
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
                url: {
                  value: '@concat(\'${environment().resourceManager}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DataFactory/factories/\', pipeline().DataFactory, \'/pipelines/queries_\', pipeline().parameters.queryEngine, \'_ExecuteQuery/createRun?api-version=2018-06-01\')'
                  type: 'Expression'
                }
                method: 'POST'
                headers: {
                  'Content-Type': 'application/json'
                }
                body: {
                  value: '@json(concat(\'{"query":"\', pipeline().parameters.query, \'","queryScope":"\', pipeline().parameters.queryScope, \'","queryScopeTypes":\', string(pipeline().parameters.queryScopeTypes), \',"querySource":"\', pipeline().parameters.querySource, \'","queryType":"\', pipeline().parameters.queryType, \'","queryProvider":"\', pipeline().parameters.queryProvider, \'","queryVersion":"\', pipeline().parameters.queryVersion, \'","ingestionPath":"\', concat(variables(\'ingestionPath\'), pipeline().parameters.queryType, \'.parquet\'), \'","translator":\', string(activity(\'Load Schema Mappings\').output.firstRow.translator), \'}\'))'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: environment().resourceManager
                }
              }
            }
            {
              name: 'Wait For Other Query Engine Pipeline'
              description: 'Poll for non-ARM engine completion using the runId from createRun.'
              type: 'Until'
              dependsOn: [
                {
                  activity: 'Start Other Query Engine Pipeline'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@or(equals(variables(\'engineRunStatus\'), \'Succeeded\'), equals(variables(\'engineRunStatus\'), \'Failed\'), equals(variables(\'engineRunStatus\'), \'Cancelled\'))'
                  type: 'Expression'
                }
                activities: [
                  {
                    name: 'Check Other Query Engine Pipeline Status'
                    type: 'WebActivity'
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
                      url: {
                        value: '@concat(\'${environment().resourceManager}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DataFactory/factories/\', pipeline().DataFactory, \'/pipelineruns/\', activity(\'Start Other Query Engine Pipeline\').output.runId, \'?api-version=2018-06-01\')'
                        type: 'Expression'
                      }
                      method: 'GET'
                      authentication: {
                        type: 'MSI'
                        resource: environment().resourceManager
                      }
                    }
                  }
                  {
                    name: 'Set Other Engine Run Status'
                    type: 'SetVariable'
                    dependsOn: [
                      {
                        activity: 'Check Other Query Engine Pipeline Status'
                        dependencyConditions: ['Succeeded']
                      }
                    ]
                    userProperties: []
                    typeProperties: {
                      variableName: 'engineRunStatus'
                      value: {
                        value: '@activity(\'Check Other Query Engine Pipeline Status\').output.status'
                        type: 'Expression'
                      }
                    }
                  }
                  {
                    name: 'Wait Before Other Engine Status Check'
                    type: 'Wait'
                    dependsOn: [
                      {
                        activity: 'Set Other Engine Run Status'
                        dependencyConditions: ['Succeeded']
                      }
                    ]
                    userProperties: []
                    typeProperties: {
                      waitTimeInSeconds: 15
                    }
                  }
                ]
                timeout: '0.00:30:00'
              }
            }
            {
              name: 'Verify Other Query Engine Pipeline Succeeded'
              description: 'Fail the pipeline if the non-ARM query engine run did not succeed.'
              type: 'IfCondition'
              dependsOn: [
                {
                  activity: 'Wait For Other Query Engine Pipeline'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@not(equals(variables(\'engineRunStatus\'), \'Succeeded\'))'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Other Query Engine Pipeline Failed'
                    type: 'Fail'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      message: {
                        value: '@concat(\'Query engine pipeline finished with status: \', variables(\'engineRunStatus\'))'
                        type: 'Expression'
                      }
                      errorCode: 'QueryEnginePipelineFailed'
                    }
                  }
                ]
              }
            }
          ]
        }
      }
      { // Check If Data Was Written
        name: 'Check If Data Was Written'
        description: 'Check if the query engine actually wrote output files before creating a manifest.'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Finalize ARM Query'
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
            referenceName: dataFactory::dataset_ingestion_files.name
            type: 'DatasetReference'
            parameters: {
              folderPath: '@concat(pipeline().parameters.outputDataset, \'/\', variables(\'queryScope\'), \'/\', pipeline().parameters.queryType)'
            }
          }
          fieldList: [
            'exists'
            'childItems'
          ]
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'ParquetReadSettings'
          }
        }
      }
      { // Check ARM Query Staging
        name: 'Check ARM Query Staging'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Run Query Engine Pipeline'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.00:10:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: dataFactory::dataset_msexports_parquet_files.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@concat(\'_ftk-query-staging/\', variables(\'ingestionPath\'))'
                type: 'Expression'
              }
            }
          }
          fieldList: ['exists']
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            recursive: true
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'ParquetReadSettings'
          }
        }
      }
      { // Finalize ARM Query
        name: 'Finalize ARM Query'
        description: 'Consolidate staged ARM results into one ingestion file before manifest creation.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Check ARM Query Staging'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@and(equals(toLower(pipeline().parameters.queryEngine), \'azureresourcemanager\'), activity(\'Check ARM Query Staging\').output.exists)'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Consolidate ARM Query'
              type: 'Copy'
              dependsOn: []
              policy: {
                timeout: '0.00:30:00'
                retry: 0
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                source: {
                  type: 'ParquetSource'
                  storeSettings: {
                    type: 'AzureBlobFSReadSettings'
                    recursive: true
                    wildcardFileName: '*.parquet'
                    enablePartitionDiscovery: true
                  }
                  formatSettings: {
                    type: 'ParquetReadSettings'
                  }
                }
                sink: {
                  type: 'ParquetSink'
                  storeSettings: {
                    type: 'AzureBlobFSWriteSettings'
                    copyBehavior: 'MergeFiles'
                  }
                  formatSettings: {
                    type: 'ParquetWriteSettings'
                  }
                }
                enableStaging: false
              }
              inputs: [
                {
                  referenceName: dataFactory::dataset_msexports_parquet_files.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@concat(\'_ftk-query-staging/\', variables(\'ingestionPath\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
              outputs: [
                {
                  referenceName: dataFactory::dataset_ingestion.name
                  type: 'DatasetReference'
                  parameters: {
                    blobPath: {
                      value: '@concat(variables(\'ingestionPath\'), pipeline().parameters.queryType, \'.parquet\')'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              name: 'Delete ARM Query Staging'
              type: 'Delete'
              dependsOn: [
                {
                  activity: 'Consolidate ARM Query'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                timeout: '0.00:10:00'
                retry: 0
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                dataset: {
                  referenceName: dataFactory::dataset_msexports_parquet_files.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@concat(\'_ftk-query-staging/\', variables(\'ingestionPath\'))'
                      type: 'Expression'
                    }
                  }
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
      { // Create Manifest If Data Exists
        name: 'Create Manifest If Data Exists'
        description: 'Only create a manifest file when query results were written, to avoid triggering ADX ingestion on empty folders.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Check If Data Was Written'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@and(pipeline().parameters.publishManifest, activity(\'Check If Data Was Written\').output.exists, contains(string(activity(\'Check If Data Was Written\').output.childItems), concat(pipeline().parameters.ingestionId, \'${core.ingestionIdFileNameSeparator}\', pipeline().parameters.queryType, \'.parquet\')))'
            type: 'Expression'
          }
          ifTrueActivities: [
            { // Create Manifest
              name: 'Create Manifest'
              description: 'Copy the settings file as manifest.json to the ingestion folder to trigger ADX ingestion.'
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
                  referenceName: dataFactory::dataset_manifest.name
                  type: 'DatasetReference'
                  parameters: {
                    fileName: 'manifest.json'
                    folderPath: {
                      value: '@concat(\'${core.containers.ingestion}/\', pipeline().parameters.outputDataset, \'/\', variables(\'queryScope\'), \'/\', pipeline().parameters.queryType)'
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
      queryEngine: {
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
      queryScopeTypes: {
        type: 'Array'
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
      publishManifest: {
        type: 'Bool'
        defaultValue: true
      }
    }
    variables: {
      queryScope: {
        type: 'String'
      }
      ingestionPath: {
        type: 'String'
      }
      engineRunStatus: {
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

@description('The app properties for the IngestionQueries app.')
output app HubAppProperties = app

@description('Metadata describing resources created by the IngestionQueries app.')
output metadata IngestionQueriesMetadata = {
  id: 'Microsoft.FinOpsHubs.IngestionQueries'
  version: finOpsToolkitVersion
  queries: {
    container: core.containers.config
    folder: QUERIES
  }
}
