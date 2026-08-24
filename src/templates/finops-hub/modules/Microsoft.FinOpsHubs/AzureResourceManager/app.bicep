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

// Reference existing JSON dataset from Cost Management Exports
resource dataset_msexports_manifest 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: 'msexports_manifest'
  parent: dataFactory
}

// Reference existing Parquet folder dataset from Ingestion Queries
resource dataset_msexports_parquet_files 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: 'msexports_parquet_files'
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
        name: 'Validate Request'
        description: 'Reject malformed resource IDs and non-relative ARM query paths before authentication.'
        type: 'IfCondition'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@and(if(or(equals(toLower(pipeline().parameters.queryScope), \'configured\'), equals(toLower(pipeline().parameters.queryScope), \'tenant\')), true, if(or(not(startswith(pipeline().parameters.queryScope, \'/\')), contains(pipeline().parameters.queryScope, \'//\'), endswith(pipeline().parameters.queryScope, \'/\'), contains(pipeline().parameters.queryScope, \'?\'), contains(pipeline().parameters.queryScope, \'#\'), contains(pipeline().parameters.queryScope, \'@\'), contains(pipeline().parameters.queryScope, \'\\\'), less(length(split(pipeline().parameters.queryScope, \'/\')), 3)), false, if(equals(toLower(split(pipeline().parameters.queryScope, \'/\')[1]), \'subscriptions\'), and(equals(length(split(pipeline().parameters.queryScope, \'/\')[2]), 36), equals(substring(split(pipeline().parameters.queryScope, \'/\')[2], 8, 1), \'-\'), equals(substring(split(pipeline().parameters.queryScope, \'/\')[2], 13, 1), \'-\'), equals(substring(split(pipeline().parameters.queryScope, \'/\')[2], 18, 1), \'-\'), equals(substring(split(pipeline().parameters.queryScope, \'/\')[2], 23, 1), \'-\'), if(equals(length(split(pipeline().parameters.queryScope, \'/\')), 3), true, if(equals(toLower(split(pipeline().parameters.queryScope, \'/\')[3]), \'providers\'), and(not(less(length(split(pipeline().parameters.queryScope, \'/\')), 7)), equals(mod(length(split(pipeline().parameters.queryScope, \'/\')), 2), 1)), if(equals(toLower(split(pipeline().parameters.queryScope, \'/\')[3]), \'resourcegroups\'), if(equals(length(split(pipeline().parameters.queryScope, \'/\')), 5), true, and(not(less(length(split(pipeline().parameters.queryScope, \'/\')), 9)), equals(toLower(split(pipeline().parameters.queryScope, \'/\')[5]), \'providers\'), equals(mod(length(split(pipeline().parameters.queryScope, \'/\')), 2), 1))), false)))), if(equals(toLower(split(pipeline().parameters.queryScope, \'/\')[1]), \'providers\'), and(not(less(length(split(pipeline().parameters.queryScope, \'/\')), 5)), equals(mod(length(split(pipeline().parameters.queryScope, \'/\')), 2), 1), not(empty(last(split(pipeline().parameters.queryScope, \'/\'))))), false)))), startswith(pipeline().parameters.query, \'/\'), not(contains(pipeline().parameters.query, \'//\')), not(contains(pipeline().parameters.query, \'://\')), not(contains(pipeline().parameters.query, \'#\')), not(contains(pipeline().parameters.query, \'@\')), not(contains(pipeline().parameters.query, \'\\\')), not(contains(pipeline().parameters.query, \'..\')))'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Reject Unsafe Request'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: 'The query scope must be a valid Azure resource ID and the query must be an ARM-relative path.'
                errorCode: 'UnsafeArmRequest'
              }
            }
          ]
        }
      }
      {
        name: 'Validate Subscription ID'
        description: 'Reject subscription resource IDs whose subscription segment is not a hexadecimal GUID.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Validate Request'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@if(or(equals(toLower(pipeline().parameters.queryScope), \'configured\'), equals(toLower(pipeline().parameters.queryScope), \'tenant\'), not(startswith(toLower(pipeline().parameters.queryScope), \'/subscriptions/\'))), true, empty(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(toLower(replace(split(pipeline().parameters.queryScope, \'/\')[2], \'-\', \'\')), \'0\', \'\'), \'1\', \'\'), \'2\', \'\'), \'3\', \'\'), \'4\', \'\'), \'5\', \'\'), \'6\', \'\'), \'7\', \'\'), \'8\', \'\'), \'9\', \'\'), \'a\', \'\'), \'b\', \'\'), \'c\', \'\'), \'d\', \'\'), \'e\', \'\'), \'f\', \'\')))'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Reject Malformed Subscription ID'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: 'The subscription segment in the query scope must be a hexadecimal GUID.'
                errorCode: 'MalformedAzureResourceId'
              }
            }
          ]
        }
      }
      {
        name: 'If Configured Scope'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Validate Subscription ID'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
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
                  queryScopeTypes: {
                    value: '@pipeline().parameters.queryScopeTypes'
                    type: 'Expression'
                  }
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
        dependsOn: [
          {
            activity: 'Validate Subscription ID'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
        dependsOn: [
          {
            activity: 'Validate Subscription ID'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
      queryScopeTypes: {
        type: 'Array'
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
        description: 'Keep valid Microsoft.Billing resource IDs whose resource type is compatible with this query.'
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
            value: '@and(not(empty(item().scope)), startswith(toLower(item().scope), \'/providers/microsoft.billing/\'), not(endswith(item().scope, \'/\')), not(contains(item().scope, \'?\')), not(contains(item().scope, \'#\')), not(contains(item().scope, \'@\')), not(contains(item().scope, \'\\\')), if(equals(length(split(item().scope, \'/\')), 5), and(contains(pipeline().parameters.queryScopeTypes, \'Microsoft.Billing/billingAccounts\'), equals(toLower(split(item().scope, \'/\')[3]), \'billingaccounts\'), not(empty(split(item().scope, \'/\')[4]))), if(equals(length(split(item().scope, \'/\')), 7), and(contains(pipeline().parameters.queryScopeTypes, \'Microsoft.Billing/billingAccounts/billingProfiles\'), equals(toLower(split(item().scope, \'/\')[3]), \'billingaccounts\'), not(empty(split(item().scope, \'/\')[4])), equals(toLower(split(item().scope, \'/\')[5]), \'billingprofiles\'), not(empty(split(item().scope, \'/\')[6]))), false)))'
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
      queryScopeTypes: {
        type: 'Array'
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
      querySource: {
        type: 'String'
      }
      queryProvider: {
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
      querySource: {
        type: 'String'
      }
      queryProvider: {
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
                  querySource: {
                    value: '@pipeline().parameters.querySource'
                    type: 'Expression'
                  }
                  queryProvider: {
                    value: '@pipeline().parameters.queryProvider'
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
      querySource: {
        type: 'String'
      }
      queryProvider: {
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
        name: 'Set Initial Request URL'
        type: 'SetVariable'
        dependsOn: []
        userProperties: []
        typeProperties: {
          variableName: 'requestUrl'
          value: {
            value: '@concat(pipeline().parameters.queryScope, replace(pipeline().parameters.query, \'{location}\', pipeline().parameters.queryLocation))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Read ARM Pages'
        description: 'Validate each request URL before retrieving and copying one ARM response page.'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set Initial Request URL'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@empty(variables(\'requestUrl\'))'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Validate Page URL'
              type: 'IfCondition'
              dependsOn: []
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@and(not(empty(variables(\'requestUrl\'))), not(contains(variables(\'requestUrl\'), \'#\')), not(contains(variables(\'requestUrl\'), \'@\')), not(contains(variables(\'requestUrl\'), \'\\\')), or(and(startswith(variables(\'requestUrl\'), \'/\'), not(startswith(variables(\'requestUrl\'), \'//\')), not(contains(variables(\'requestUrl\'), \'://\')), greater(length(variables(\'requestUrl\')), 1)), and(startswith(toLower(variables(\'requestUrl\')), toLower(\'${environment().resourceManager}\')), greater(length(variables(\'requestUrl\')), length(\'${environment().resourceManager}\')))))'
                  type: 'Expression'
                }
                ifFalseActivities: [
                  {
                    name: 'Reject Unsafe Page URL'
                    type: 'Fail'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      message: 'The ARM continuation URL must use the current Azure Resource Manager authority.'
                      errorCode: 'UnsafeArmContinuation'
                    }
                  }
                ]
              }
            }
            {
              name: 'Set Page Metadata Path'
              description: 'Create a run-unique path for this page continuation record.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Validate Page URL'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'metadataPath'
                value: {
                  value: '@concat(\'_ftk-arm-pagination/\', pipeline().RunId, \'/\', guid(), \'.parquet\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Copy Raw ARM Page'
              description: 'Stream one validated ARM response into a run-unique raw JSON file.'
              type: 'Copy'
              dependsOn: [
                {
                  activity: 'Set Page Metadata Path'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  referenceName: dataset_azureResourceManager.name
                  type: 'DatasetReference'
                  parameters: {
                    relativeUrl: {
                      value: '@if(startswith(toLower(variables(\'requestUrl\')), toLower(\'${environment().resourceManager}\')), concat(\'/\', substring(variables(\'requestUrl\'), length(\'${environment().resourceManager}\'))), variables(\'requestUrl\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
              outputs: [
                {
                  referenceName: dataset_msexports_manifest.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@concat(\'msexports/_ftk-arm-pagination/\', pipeline().RunId)'
                      type: 'Expression'
                    }
                    fileName: {
                      value: '@replace(last(split(variables(\'metadataPath\'), \'/\')), \'.parquet\', \'.json\')'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              name: 'Copy Page Metadata'
              description: 'Map only the root nextLink field from the stored response to a tiny Parquet file.'
              type: 'Copy'
              dependsOn: [
                {
                  activity: 'Copy Raw ARM Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                        path: '$[\'nextLink\']'
                      }
                      sink: {
                        name: 'nextLink'
                        type: 'String'
                      }
                    }
                  ]
                }
              }
              inputs: [
                {
                  referenceName: dataset_msexports_manifest.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@concat(\'msexports/_ftk-arm-pagination/\', pipeline().RunId)'
                      type: 'Expression'
                    }
                    fileName: {
                      value: '@replace(last(split(variables(\'metadataPath\'), \'/\')), \'.parquet\', \'.json\')'
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
                      value: '@variables(\'metadataPath\')'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              name: 'Lookup Page Metadata'
              description: 'Read the tiny continuation record without loading the ARM response into control-flow output.'
              type: 'Lookup'
              dependsOn: [
                {
                  activity: 'Copy Page Metadata'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              policy: {
                timeout: '0.00:02:00'
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
                    recursive: false
                    enablePartitionDiscovery: false
                  }
                  formatSettings: {
                    type: 'ParquetReadSettings'
                  }
                }
                dataset: {
                  referenceName: dataset_msexports_parquet.name
                  type: 'DatasetReference'
                  parameters: {
                    blobPath: {
                      value: '@variables(\'metadataPath\')'
                      type: 'Expression'
                    }
                  }
                }
                firstRowOnly: true
              }
            }
            {
              name: 'Copy ARM Page'
              description: 'Copy one validated ARM response page to Parquet staging.'
              type: 'Copy'
              dependsOn: [
                {
                  activity: 'Copy Raw ARM Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  referenceName: dataset_msexports_manifest.name
                  type: 'DatasetReference'
                  parameters: {
                    folderPath: {
                      value: '@concat(\'msexports/_ftk-arm-pagination/\', pipeline().RunId)'
                      type: 'Expression'
                    }
                    fileName: {
                      value: '@replace(last(split(variables(\'metadataPath\'), \'/\')), \'.parquet\', \'.json\')'
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
                      value: '@concat(\'_ftk-query-staging/\', replace(pipeline().parameters.ingestionPath, concat(pipeline().parameters.queryType, \'.parquet\'), \'\'), \'/SubAccountId=\', last(split(pipeline().parameters.queryScope, \'/\')), if(empty(pipeline().parameters.queryLocation), \'\', concat(\'/location=\', pipeline().parameters.queryLocation)), \'/x_SourceName=\', pipeline().parameters.querySource, \'/x_SourceProvider=\', pipeline().parameters.queryProvider, if(contains(string(pipeline().parameters.translator), \'x_SourceType\'), \'\', concat(\'/x_SourceType=\', pipeline().parameters.queryType)), \'/x_SourceVersion=\', pipeline().parameters.queryVersion, \'/\', pipeline().parameters.queryType, \'--\', pipeline().parameters.queryVersion, \'--\', replace(pipeline().parameters.queryScope, \'/\', \'_\'), \'--\', pipeline().parameters.queryLocation, \'--\', substring(guid(), 0, 8), \'.parquet\')'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              name: 'Set Next Request URL'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Copy ARM Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
                {
                  activity: 'Lookup Page Metadata'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestUrl'
                value: {
                  value: '@if(contains(activity(\'Lookup Page Metadata\').output, \'firstRow\'), if(contains(activity(\'Lookup Page Metadata\').output.firstRow, \'nextLink\'), coalesce(activity(\'Lookup Page Metadata\').output.firstRow.nextLink, \'\'), \'\'), \'\')'
                  type: 'Expression'
                }
              }
            }
          ]
          timeout: '0.00:10:00'
        }
      }
      {
        name: 'Delete Paging Files'
        description: 'Delete this pipeline run\'s raw response and continuation files after paging completes.'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Read ARM Pages'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        policy: {
          timeout: '0.00:02:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: dataset_msexports_parquet_files.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@concat(\'_ftk-arm-pagination/\', pipeline().RunId)'
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
    parameters: {
      query: {
        type: 'String'
      }
      queryScope: {
        type: 'String'
      }
      querySource: {
        type: 'String'
      }
      queryProvider: {
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
    variables: {
      requestUrl: {
        type: 'String'
      }
      metadataPath: {
        type: 'String'
      }
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
