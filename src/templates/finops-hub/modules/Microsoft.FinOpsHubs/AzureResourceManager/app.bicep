// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as AzureResourceManagerMetadata } from './metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.AzureResourceManager'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.FinOpsHubs.IngestionQueries'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/AzureResourceManager/metadata.bicep'
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



//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.AzureResourceManager_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'  // ARM dataset and engine pipeline
    ]
  }
}

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Reference the ARM linked service (created by the Core app)
resource linkedService_arm 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' existing = {
  name: core.linkedServices.azurerm
  parent: dataFactory
}

// Azure Resource Manager dataset
resource dataset_azureResourceManager 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'azureResourceManager'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      relativeUrl: {
        type: 'String'
      }
    }
    type: 'RestResource'
    typeProperties: {
      relativeUrl: {
        value: '@dataset().relativeUrl'
        type: 'Expression'
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_arm.name
      type: 'LinkedServiceReference'
    }
  }
}

// Reference existing Parquet dataset from Cost Management Exports
resource dataset_msexports_parquet 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: 'msexports_parquet'
  parent: dataFactory
}

// Reference existing configuration dataset from Core app
resource dataset_config 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: core.datasets.config
  parent: dataFactory
}

//------------------------------------------------------------------------------
// Engine pipeline
//------------------------------------------------------------------------------

resource pipeline_ExecuteQuery 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteQuery'
  parent: dataFactory
  properties: {
    description: 'Execute a GET request against Azure Resource Manager'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'If Configured Scope'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(toLower(pipeline().parameters.queryScope), \'configured\')'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Configured Scopes'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteConfiguredScopes.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
      {
        name: 'If Tenant Scope'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(toLower(pipeline().parameters.queryScope), \'tenant\')'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Tenant'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteTenant.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
      {
        name: 'If Direct Scope'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@and(not(equals(toLower(pipeline().parameters.queryScope), \'configured\')), not(equals(toLower(pipeline().parameters.queryScope), \'tenant\')))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Request'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CopyQuery.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@pipeline().parameters.queryScope'
                    type: 'Expression'
                  }
                  queryLocation: ''
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionPath: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryDataset: {
        type: 'String'
      }
      queryProvider: {
        type: 'String'
      }
      queryEngine: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      querySource: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      translator: {
        type: 'Object'
      }
    }
  }
}

resource pipeline_ExecuteConfiguredScopes 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteConfiguredScopes'
  parent: dataFactory
  properties: {
    description: 'Execute an Azure Resource Manager query for each configured billing scope'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'Get Config'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.00:10:00'
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
                value: '@variables(\'fileName\')'
                type: 'Expression'
              }
              folderPath: {
                value: '@variables(\'folderPath\')'
                type: 'Expression'
              }
            }
          }
          firstRowOnly: true
        }
      }
      {
        name: 'Set Scopes'
        description: 'Normalize one or more configured scope objects into an array.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'scopesArray'
          value: {
            value: '@if(startswith(string(activity(\'Get Config\').output.firstRow.scopes), \'[\'), activity(\'Get Config\').output.firstRow.scopes, createArray(activity(\'Get Config\').output.firstRow.scopes))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Filter Invalid Scopes'
        description: 'Filter out scopes that are not defined or that are not Microsoft.Billing scopes.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Set Scopes'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'scopesArray\')'
            type: 'Expression'
          }
          condition: {
            value: '@and(not(empty(item().scope)), startswith(toLower(item().scope), \'/providers/microsoft.billing/\'))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'ForEach Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Invalid Scopes'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Invalid Scopes\').output.value'
            type: 'Expression'
          }
          isSequential: false
          batchCount: app.hub.options.privateRouting ? 4 : 30
          activities: [
            {
              name: 'Execute Request'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CopyQuery.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@item().scope'
                    type: 'Expression'
                  }
                  queryLocation: ''
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionPath: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      translator: {
        type: 'Object'
      }
    }
    variables: {
      fileName: {
        type: 'String'
        defaultValue: core.settings.file
      }
      folderPath: {
        type: 'String'
        defaultValue: core.settings.container
      }
      scopesArray: {
        type: 'Array'
      }
    }
  }
}

resource pipeline_ExecuteTenant 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteTenant'
  parent: dataFactory
  properties: {
    description: 'Execute an Azure Resource Manager query for each enabled subscription'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'Get Subscriptions'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:02:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          method: 'GET'
          url: '${environment().resourceManager}subscriptions?api-version=2022-12-01'
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      {
        name: 'Filter Enabled Subscriptions'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get Subscriptions'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Get Subscriptions\').output.value'
            type: 'Expression'
          }
          condition: {
            value: '@equals(toLower(item().state), \'enabled\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'ForEach Subscription'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Enabled Subscriptions'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Enabled Subscriptions\').output.value'
            type: 'Expression'
          }
          isSequential: false
          batchCount: app.hub.options.privateRouting ? 4 : 30
          activities: [
            {
              name: 'Execute Subscription Query'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteSubscription.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@item().id'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionPath: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      translator: {
        type: 'Object'
      }
    }
  }
}

resource pipeline_ExecuteSubscription 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteSubscription'
  parent: dataFactory
  properties: {
    description: 'Execute a direct or regional Azure Resource Manager query for one subscription'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'If Direct Query'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@not(contains(pipeline().parameters.query, \'{location}\'))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Request'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CopyQuery.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@pipeline().parameters.queryScope'
                    type: 'Expression'
                  }
                  queryLocation: ''
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
      {
        name: 'If Regional Query'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(pipeline().parameters.query, \'{location}\')'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute Regional Query'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteRegional.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@pipeline().parameters.queryScope'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionPath: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      translator: {
        type: 'Object'
      }
    }
  }
}

resource pipeline_ExecuteRegional 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteRegional'
  parent: dataFactory
  properties: {
    description: 'Execute an Azure Resource Manager query for each physical region in one subscription'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'Get Locations'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:02:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          method: 'GET'
          url: {
            value: '@concat(\'${environment().resourceManager}\', pipeline().parameters.queryScope, \'/locations?api-version=2022-12-01\')'
            type: 'Expression'
          }
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      {
        name: 'Get Provider'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:02:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          method: 'GET'
          url: {
            value: '@concat(\'${environment().resourceManager}\', pipeline().parameters.queryScope, \'/providers/\', split(pipeline().parameters.query, \'/\')[2], \'?api-version=2021-04-01\')'
            type: 'Expression'
          }
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      {
        name: 'Filter Provider Resource Type'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get Provider'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Get Provider\').output.resourceTypes'
            type: 'Expression'
          }
          condition: {
            value: '@equals(toLower(item().resourceType), \'locations/usages\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Filter Physical Locations'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get Locations'
            dependencyConditions: [
              'Succeeded'
            ]
          }
          {
            activity: 'Filter Provider Resource Type'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Get Locations\').output.value'
            type: 'Expression'
          }
          condition: {
            value: '@and(equals(toLower(item().metadata.regionType), \'physical\'), contains(activity(\'Filter Provider Resource Type\').output.value[0].locations, item().displayName))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'ForEach Location'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Physical Locations'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Physical Locations\').output.value'
            type: 'Expression'
          }
          isSequential: false
          batchCount: app.hub.options.privateRouting ? 4 : 30
          activities: [
            {
              name: 'Execute Request'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_CopyQuery.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  query: {
                    value: '@pipeline().parameters.query'
                    type: 'Expression'
                  }
                  queryScope: {
                    value: '@pipeline().parameters.queryScope'
                    type: 'Expression'
                  }
                  queryLocation: {
                    value: '@item().name'
                    type: 'Expression'
                  }
                  queryType: {
                    value: '@pipeline().parameters.queryType'
                    type: 'Expression'
                  }
                  queryVersion: {
                    value: '@pipeline().parameters.queryVersion'
                    type: 'Expression'
                  }
                  ingestionPath: {
                    value: '@pipeline().parameters.ingestionPath'
                    type: 'Expression'
                  }
                  translator: {
                    value: '@pipeline().parameters.translator'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      ingestionPath: {
        type: 'String'
      }
      query: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      translator: {
        type: 'Object'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Request Copy pipeline
//------------------------------------------------------------------------------

resource pipeline_CopyQuery 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_CopyQuery'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Execute ARM Query'
        description: 'Execute one ARM request and write Parquet to msexports staging for pre-manifest consolidation.'
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
            requestMethod: 'GET'
            paginationRules: {
              AbsoluteUrl: '$.nextLink'
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
            value: '@pipeline().parameters.translator'
            type: 'Expression'
          }
        }
        inputs: [
          {
            referenceName: dataset_azureResourceManager.name
            type: 'DatasetReference'
            parameters: {
              relativeUrl: {
                value: '@concat(pipeline().parameters.queryScope, replace(pipeline().parameters.query, \'{location}\', pipeline().parameters.queryLocation))'
                type: 'Expression'
              }
            }
          }
        ]
        outputs: [
          {
            referenceName: dataset_msexports_parquet.name
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'_ftk-query-staging/\', replace(pipeline().parameters.ingestionPath, concat(pipeline().parameters.queryType, \'.parquet\'), \'\'), \'/SubAccountId=\', last(split(pipeline().parameters.queryScope, \'/\')), if(empty(pipeline().parameters.queryLocation), \'\', concat(\'/location=\', pipeline().parameters.queryLocation)), \'/x_SourceName=Azure Resource Manager/x_SourceProvider=Microsoft\', if(contains(string(pipeline().parameters.translator), \'x_SourceType\'), \'\', concat(\'/x_SourceType=\', pipeline().parameters.queryType)), \'/x_SourceVersion=\', pipeline().parameters.queryVersion, \'/\', pipeline().parameters.queryType, \'--\', pipeline().parameters.queryVersion, \'--\', replace(pipeline().parameters.queryScope, \'/\', \'_\'), \'--\', pipeline().parameters.queryLocation, \'.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
    ]
    parameters: {
      query: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      queryLocation: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryVersion: {
        type: 'String'
      }
      ingestionPath: {
        type: 'String'
      }
      translator: {
        type: 'Object'
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

@description('The app properties for the AzureResourceManager app.')
output app HubAppProperties = app

@description('Metadata describing resources created by the AzureResourceManager app.')
output metadata AzureResourceManagerMetadata = {
  id: 'Microsoft.FinOpsHubs.AzureResourceManager'
  version: finOpsToolkitVersion
  datasets: {
    azureResourceManager: dataset_azureResourceManager.name
  }
}
