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
          batchCount: 50
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

resource pipeline_ExecuteSubscriptionPage 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteSubscriptionPage'
  parent: dataFactory
  properties: {
    description: 'Execute an Azure Resource Manager query for one page of enabled subscriptions'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'ForEach Subscription'
        type: 'ForEach'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.subscriptions'
            type: 'Expression'
          }
          isSequential: false
          batchCount: 50
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
      subscriptions: {
        type: 'Array'
      }
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
        name: 'Set Initial Subscription Page URL'
        type: 'SetVariable'
        dependsOn: []
        userProperties: []
        typeProperties: {
          variableName: 'subscriptionPageUrl'
          value: '${environment().resourceManager}subscriptions?api-version=2022-12-01'
        }
      }
      {
        name: 'Read Subscription Pages'
        description: 'Process every ARM subscription page before following its nextLink.'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set Initial Subscription Page URL'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@empty(variables(\'subscriptionPageUrl\'))'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Validate Subscription Page URL'
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageFailure'
                value: {
                  value: '@if(and(not(empty(variables(\'subscriptionPageUrl\'))), startswith(toLower(variables(\'subscriptionPageUrl\')), toLower(\'${environment().resourceManager}\')), greater(length(variables(\'subscriptionPageUrl\')), length(\'${environment().resourceManager}\')), not(contains(variables(\'subscriptionPageUrl\'), \'#\')), not(contains(variables(\'subscriptionPageUrl\'), \'@\')), not(contains(variables(\'subscriptionPageUrl\'), \'\\\'))), \'\', \'The subscription continuation URL must use the current Azure Resource Manager authority.\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Get Subscription Page'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Validate Subscription Page URL'
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
                method: 'GET'
                url: {
                  value: '@if(empty(variables(\'subscriptionPageFailure\')), variables(\'subscriptionPageUrl\'), concat(\'${environment().resourceManager}\', \'providers/Microsoft.FinOpsValidation/unsafe-continuation?api-version=2021-04-01\'))'
                  type: 'Expression'
                }
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
                  activity: 'Get Subscription Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                items: {
                  value: '@activity(\'Get Subscription Page\').output.value'
                  type: 'Expression'
                }
                condition: {
                  value: '@equals(toLower(item().state), \'enabled\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Execute Subscription Page'
              type: 'ExecutePipeline'
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
                pipeline: {
                  referenceName: pipeline_ExecuteSubscriptionPage.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  subscriptions: {
                    value: '@activity(\'Filter Enabled Subscriptions\').output.value'
                    type: 'Expression'
                  }
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
            {
              name: 'Set Next Subscription Page URL'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Execute Subscription Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageUrl'
                value: {
                  value: '@if(contains(activity(\'Get Subscription Page\').output, \'nextLink\'), coalesce(activity(\'Get Subscription Page\').output.nextLink, \'\'), \'\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture Subscription Page Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Get Subscription Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageFailure'
                value: {
                  value: '@if(not(empty(variables(\'subscriptionPageFailure\'))), variables(\'subscriptionPageFailure\'), activity(\'Get Subscription Page\').error.message)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Subscription Page Loop After Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Subscription Page Request Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageUrl'
                value: ''
              }
            }
            {
              name: 'Capture Subscription Filter Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Filter Enabled Subscriptions'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageFailure'
                value: {
                  value: '@activity(\'Filter Enabled Subscriptions\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Subscription Page Loop After Filter Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Subscription Filter Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageUrl'
                value: ''
              }
            }
            {
              name: 'Capture Subscription Dispatch Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Execute Subscription Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageFailure'
                value: {
                  value: '@activity(\'Execute Subscription Page\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Subscription Page Loop After Dispatch Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Subscription Dispatch Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionPageUrl'
                value: ''
              }
            }
          ]
          timeout: '7.00:00:00'
        }
      }
      {
        name: 'Rethrow Subscription Page Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Read Subscription Pages'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@not(empty(variables(\'subscriptionPageFailure\')))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Subscription Page Failed'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: '@variables(\'subscriptionPageFailure\')'
                  type: 'Expression'
                }
                errorCode: 'SubscriptionPageFailed'
              }
            }
          ]
        }
      }
      {
        name: 'Rethrow Subscription Page Loop Failure'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Read Subscription Pages'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@activity(\'Read Subscription Pages\').error.message'
            type: 'Expression'
          }
          errorCode: 'SubscriptionPageLoopFailed'
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
    variables: {
      subscriptionPageUrl: {
        type: 'String'
      }
      subscriptionPageFailure: {
        type: 'String'
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

resource pipeline_ExecuteLocationPage 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_ExecuteLocationPage'
  parent: dataFactory
  properties: {
    description: 'Execute an Azure Resource Manager query for one page of physical locations'
    folder: {
      name: 'FinOps hub'
    }
    activities: [
      {
        name: 'Filter Physical Locations'
        type: 'Filter'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.locations'
            type: 'Expression'
          }
          condition: {
            value: '@and(equals(toLower(item().metadata.regionType), \'physical\'), contains(pipeline().parameters.supportedLocations, item().displayName))'
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
          batchCount: 50
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
      locations: {
        type: 'Array'
      }
      supportedLocations: {
        type: 'Array'
      }
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
        name: 'Set Initial Location Page URL'
        type: 'SetVariable'
        dependsOn: []
        userProperties: []
        typeProperties: {
          variableName: 'locationPageUrl'
          value: {
            value: '@concat(\'${environment().resourceManager}\', pipeline().parameters.queryScope, \'/locations?api-version=2022-12-01\')'
            type: 'Expression'
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
        name: 'Read Location Pages'
        description: 'Process every ARM location page before following its nextLink.'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set Initial Location Page URL'
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
          expression: {
            value: '@empty(variables(\'locationPageUrl\'))'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Validate Location Page URL'
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'locationPageFailure'
                value: {
                  value: '@if(and(not(empty(variables(\'locationPageUrl\'))), startswith(toLower(variables(\'locationPageUrl\')), toLower(\'${environment().resourceManager}\')), greater(length(variables(\'locationPageUrl\')), length(\'${environment().resourceManager}\')), not(contains(variables(\'locationPageUrl\'), \'#\')), not(contains(variables(\'locationPageUrl\'), \'@\')), not(contains(variables(\'locationPageUrl\'), \'\\\'))), \'\', \'The location continuation URL must use the current Azure Resource Manager authority.\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Get Location Page'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Validate Location Page URL'
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
                method: 'GET'
                url: {
                  value: '@if(empty(variables(\'locationPageFailure\')), variables(\'locationPageUrl\'), concat(\'${environment().resourceManager}\', \'providers/Microsoft.FinOpsValidation/unsafe-continuation?api-version=2021-04-01\'))'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: environment().resourceManager
                }
              }
            }
            {
              name: 'Execute Location Page'
              type: 'ExecutePipeline'
              dependsOn: [
                {
                  activity: 'Get Location Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteLocationPage.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  locations: {
                    value: '@activity(\'Get Location Page\').output.value'
                    type: 'Expression'
                  }
                  supportedLocations: {
                    value: '@activity(\'Filter Provider Resource Type\').output.value[0].locations'
                    type: 'Expression'
                  }
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
            {
              name: 'Set Next Location Page URL'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Execute Location Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'locationPageUrl'
                value: {
                  value: '@if(contains(activity(\'Get Location Page\').output, \'nextLink\'), coalesce(activity(\'Get Location Page\').output.nextLink, \'\'), \'\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture Location Page Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Get Location Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'locationPageFailure'
                value: {
                  value: '@if(not(empty(variables(\'locationPageFailure\'))), variables(\'locationPageFailure\'), activity(\'Get Location Page\').error.message)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Location Page Loop After Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Location Page Request Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'locationPageUrl'
                value: ''
              }
            }
            {
              name: 'Capture Location Dispatch Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Execute Location Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'locationPageFailure'
                value: {
                  value: '@activity(\'Execute Location Page\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Location Page Loop After Dispatch Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Location Dispatch Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'locationPageUrl'
                value: ''
              }
            }
          ]
          timeout: '7.00:00:00'
        }
      }
      {
        name: 'Rethrow Location Page Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Read Location Pages'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@not(empty(variables(\'locationPageFailure\')))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Location Page Failed'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: '@variables(\'locationPageFailure\')'
                  type: 'Expression'
                }
                errorCode: 'LocationPageFailed'
              }
            }
          ]
        }
      }
      {
        name: 'Rethrow Location Page Loop Failure'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Read Location Pages'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@activity(\'Read Location Pages\').error.message'
            type: 'Expression'
          }
          errorCode: 'LocationPageLoopFailed'
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
    variables: {
      locationPageUrl: {
        type: 'String'
      }
      locationPageFailure: {
        type: 'String'
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
    concurrency: app.hub.options.privateRouting ? 4 : 30
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
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'rawRequestFailure'
                value: {
                  value: '@if(and(not(empty(variables(\'requestUrl\'))), not(contains(variables(\'requestUrl\'), \'#\')), not(contains(variables(\'requestUrl\'), \'@\')), not(contains(variables(\'requestUrl\'), \'\\\')), or(and(startswith(variables(\'requestUrl\'), \'/\'), not(startswith(variables(\'requestUrl\'), \'//\')), not(contains(variables(\'requestUrl\'), \'://\')), greater(length(variables(\'requestUrl\')), 1)), and(startswith(toLower(variables(\'requestUrl\')), toLower(\'${environment().resourceManager}\')), greater(length(variables(\'requestUrl\')), length(\'${environment().resourceManager}\'))))), \'\', \'The ARM continuation URL must use the current Azure Resource Manager authority.\')'
                  type: 'Expression'
                }
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
                timeout: '0.00:02:30'
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
                      value: '@if(empty(variables(\'rawRequestFailure\')), if(startswith(toLower(variables(\'requestUrl\')), toLower(\'${environment().resourceManager}\')), concat(\'/\', substring(variables(\'requestUrl\'), length(\'${environment().resourceManager}\'))), variables(\'requestUrl\')), \'/providers/Microsoft.FinOpsValidation/unsafe-continuation?api-version=2021-04-01\')'
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
              name: 'Clear ARM Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Copy Raw ARM Page'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailure'
                value: ''
              }
            }
            {
              name: 'Clear ARM Request Error Code'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Clear ARM Request Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureCode'
                value: ''
              }
            }
            {
              name: 'Reset ARM Request Attempts'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Clear ARM Request Error Code'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestAttempts'
                value: {
                  value: '@json(\'[]\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture ARM Request Failure'
              description: 'Capture the raw ARM failure before classifying expected no-data and transient responses.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Copy Raw ARM Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'rawRequestFailure'
                value: {
                  value: '@if(not(empty(variables(\'rawRequestFailure\'))), variables(\'rawRequestFailure\'), activity(\'Copy Raw ARM Page\').error.message)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture ARM Request Error Code'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture ARM Request Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureCode'
                value: {
                  value: '@if(equals(variables(\'rawRequestFailure\'), \'The ARM continuation URL must use the current Azure Resource Manager authority.\'), \'UnsafeArmContinuation\', coalesce(activity(\'Copy Raw ARM Page\').error.errorCode, \'ArmRequestFailed\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture ARM Request Failure Type'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture ARM Request Error Code'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureType'
                value: {
                  value: '@if(equals(variables(\'rawRequestFailure\'), \'The ARM continuation URL must use the current Azure Resource Manager authority.\'), \'\', coalesce(activity(\'Copy Raw ARM Page\').error.failureType, \'\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Record ARM Request Attempt'
              type: 'AppendVariable'
              dependsOn: [
                {
                  activity: 'Capture ARM Request Failure Type'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestAttempts'
                value: {
                  value: '@variables(\'rawRequestFailure\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Classify Expected Empty ARM Response'
              description: 'Treat only the established Network and Machine Learning no-data contracts as successful empty responses.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Record ARM Request Attempt'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'isExpectedEmptyResponse'
                value: {
                  value: '@or(and(contains(pipeline().parameters.query, \'/providers/Microsoft.Network/locations/\'), contains(variables(\'rawRequestFailure\'), \'status code 409 Conflict\'), contains(variables(\'rawRequestFailure\'), \'"code":"SubscriptionHasNoUsages"\')), and(equals(toLower(pipeline().parameters.queryType), \'machinelearningusage\'), contains(toLower(variables(\'rawRequestFailure\')), \'status code 400 badrequest\'), contains(toLower(variables(\'rawRequestFailure\')), \'subscriptionnotfounderror\'), contains(toLower(variables(\'rawRequestFailure\')), \'is not found in quota service\'), contains(toLower(variables(\'rawRequestFailure\')), \'statuscode\'), contains(toLower(variables(\'rawRequestFailure\')), \'404\')))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Classify Transient ARM Response'
              description: 'Retry only throttling, server, timeout, and connection failures.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Classify Expected Empty ARM Response'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'isTransientResponse'
                value: {
                  value: '@or(contains(toLower(variables(\'rawRequestFailure\')), \'status code 429\'), contains(toLower(variables(\'rawRequestFailure\')), \'status code 5\'), equals(toLower(variables(\'requestFailureType\')), \'systemerror\'), contains(toLower(variables(\'rawRequestFailure\')), \'timed out\'), contains(toLower(variables(\'rawRequestFailure\')), \'timeout\'), contains(toLower(variables(\'rawRequestFailure\')), \'connection reset\'), contains(toLower(variables(\'rawRequestFailure\')), \'connection was closed\'), contains(toLower(variables(\'rawRequestFailure\')), \'connection refused\'), contains(toLower(variables(\'rawRequestFailure\')), \'remote name could not be resolved\'), contains(toLower(variables(\'rawRequestFailure\')), \'name resolution\'), contains(toLower(variables(\'rawRequestFailure\')), \'temporarily unavailable\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Normalize ARM Request Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Classify Transient ARM Response'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailure'
                value: {
                  value: '@if(variables(\'isExpectedEmptyResponse\'), \'\', variables(\'rawRequestFailure\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Select ARM Retry URL'
              description: 'Retain the same page URL only while a transient failure has retry budget remaining.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Normalize ARM Request Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'retryRequestUrl'
                value: {
                  value: '@if(and(not(variables(\'isExpectedEmptyResponse\')), variables(\'isTransientResponse\'), less(length(variables(\'requestAttempts\')), 3)), variables(\'requestUrl\'), \'\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Apply ARM Retry URL'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Select ARM Retry URL'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestUrl'
                value: {
                  value: '@variables(\'retryRequestUrl\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Wait Before Transient ARM Retry'
              type: 'Wait'
              dependsOn: [
                {
                  activity: 'Apply ARM Retry URL'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                waitTimeInSeconds: {
                  value: '@if(empty(variables(\'requestUrl\')), 0, 60)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Copy Page Metadata'
              description: 'Map only the root nextLink field from the stored response to a tiny Parquet file.'
              type: 'Copy'
              dependsOn: [
                {
                  activity: 'Reset ARM Request Attempts'
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
              name: 'Capture Page Metadata Copy Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Copy Page Metadata'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailure'
                value: {
                  value: '@activity(\'Copy Page Metadata\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture Page Metadata Copy Error Code'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Page Metadata Copy Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureCode'
                value: {
                  value: '@coalesce(activity(\'Copy Page Metadata\').error.errorCode, \'ArmPageMetadataCopyFailed\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Paging After Page Metadata Copy Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Page Metadata Copy Error Code'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestUrl'
                value: ''
              }
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
              name: 'Capture Page Metadata Lookup Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Lookup Page Metadata'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailure'
                value: {
                  value: '@activity(\'Lookup Page Metadata\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture Page Metadata Lookup Error Code'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Page Metadata Lookup Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureCode'
                value: {
                  value: '@coalesce(activity(\'Lookup Page Metadata\').error.errorCode, \'ArmPageMetadataLookupFailed\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Paging After Page Metadata Lookup Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture Page Metadata Lookup Error Code'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestUrl'
                value: ''
              }
            }
            {
              name: 'Copy ARM Page'
              description: 'Copy one validated ARM response page to Parquet staging.'
              type: 'Copy'
              dependsOn: [
                {
                  activity: 'Lookup Page Metadata'
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
              name: 'Capture ARM Page Copy Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Copy ARM Page'
                  dependencyConditions: [
                    'Failed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailure'
                value: {
                  value: '@activity(\'Copy ARM Page\').error.message'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Capture ARM Page Copy Error Code'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture ARM Page Copy Failure'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestFailureCode'
                value: {
                  value: '@coalesce(activity(\'Copy ARM Page\').error.errorCode, \'ArmPageCopyFailed\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Stop Paging After ARM Page Copy Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Capture ARM Page Copy Error Code'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'requestUrl'
                value: ''
              }
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
            {
              name: 'Complete Failed ARM Page Processing'
              description: 'Complete the handled failure branch when the page-success leaf was skipped.'
              type: 'Wait'
              dependsOn: [
                {
                  activity: 'Set Next Request URL'
                  dependencyConditions: [
                    'Skipped'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                waitTimeInSeconds: 0
              }
            }
          ]
          timeout: '0.00:10:00'
        }
      }
      {
        name: 'Rethrow ARM Request Failure'
        description: 'Fail for every unhandled ARM request or page-processing error and never convert a page-loop timeout into success.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Read ARM Pages'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@or(not(empty(variables(\'requestFailure\'))), not(equals(activity(\'Read ARM Pages\').Status, \'Succeeded\')))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'ARM Request Failed'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: '@if(not(empty(variables(\'requestFailure\'))), variables(\'requestFailure\'), activity(\'Read ARM Pages\').error.message)'
                  type: 'Expression'
                }
                errorCode: {
                  value: '@if(not(empty(variables(\'requestFailureCode\'))), variables(\'requestFailureCode\'), \'ArmPageLoopFailed\')'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      {
        name: 'Delete Paging Files'
        description: 'Delete this pipeline run\'s raw response and continuation files after paging completes.'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Rethrow ARM Request Failure'
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
      requestFailure: {
        type: 'String'
      }
      requestFailureCode: {
        type: 'String'
      }
      rawRequestFailure: {
        type: 'String'
      }
      requestFailureType: {
        type: 'String'
      }
      requestAttempts: {
        type: 'Array'
        defaultValue: []
      }
      isExpectedEmptyResponse: {
        type: 'Bool'
        defaultValue: false
      }
      isTransientResponse: {
        type: 'Bool'
        defaultValue: false
      }
      retryRequestUrl: {
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
