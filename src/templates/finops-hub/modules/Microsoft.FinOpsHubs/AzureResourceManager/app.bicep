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
//
// Scope expansion is split across four pipelines rather than nested loops:
//
//   ExecuteQuery              entry point, validates and routes by scope
//   ├── ExecuteConfiguredScopes   fans out configured billing scopes
//   └── ExecuteTenant             fans out enabled subscriptions, then routes
//       │                         each one direct or regional inline (no loop,
//       │                         so it stays in this pipeline)
//       └── ExecuteRegional       fans out physical locations
//           └── CopyQuery         executes one ARM request
//
// ADF does not allow control-flow containers to nest. A ForEach cannot contain
// another ForEach, and neither can contain a Switch or IfCondition that itself
// contains a loop. Expanding scopes and locations in a single pipeline is
// therefore not expressible, and chaining ExecutePipeline with
// waitOnCompletion is the only shape ADF accepts for each additional loop.
//
// A direct/regional IfCondition router has no loop of its own, so it belongs
// inline in the caller rather than as its own pipeline (see ExecuteTenant's
// "ForEach Subscription" activities). Adding a new expansion axis that itself
// needs to loop means adding a new pipeline; adding branching logic that
// doesn't loop does not.
//
// CopyQuery has no pipeline-level concurrency cap (see pipeline_CopyQuery). It's
// invoked from three independent fan-out points (ForEach Scope, ForEach
// Subscription's direct-query branch, ForEach Location); a shared cap makes
// their batchCounts multiply against one budget rather than scale
// independently. Each ForEach's own batchCount is the real throughput lever.
//
// ExecuteTenant's subscription list is paginated (Set Subscriptions Url / Get
// All Subscription Pages / ...), not a single WebActivity call, because the
// Subscriptions - List API paginates via nextLink once a tenant has enough
// subscriptions; a single call would silently under-count at scale. Two ADF
// expression-language constraints shaped this loop and are easy to
// reintroduce if it's ever "simplified":
//   - A SetVariable cannot read the same variable it writes ("self reference
//     is not supported"), so the array is merged into a scratch variable
//     (subscriptionsArrayNext) and copied back in a second, non-self-
//     referencing SetVariable rather than unioned in place.
//   - ARM omits the nextLink property entirely on the last page rather than
//     returning it as null, and ADF throws evaluating a property path that
//     doesn't exist at all - coalesce() does not protect against that. The
//     next-page URL is set via an IfCondition gated on contains(activity(...)
//     .output, 'nextLink') so the possibly-absent property is only read once
//     its presence is confirmed, not via a single eagerly-evaluated
//     expression. Both were proven live against Trey (single-subscription
//     tenant, so the loop terminates after one page: contains() correctly
//     returns false and the false branch runs).
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
          // Kept conservative: this repo has no configured billing scopes to load-test
          // against on a live hub, so unlike ForEach Location this value hasn't been
          // proven at a higher batchCount. CopyQuery no longer has a shared concurrency
          // cap (see pipeline_CopyQuery), so raising this is safe to try once there's
          // real scope data to validate against.
          batchCount: 1
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
        name: 'Set Subscriptions Url'
        description: 'Seed the paging URL with the first page of the tenant subscription list.'
        type: 'SetVariable'
        dependsOn: []
        userProperties: []
        typeProperties: {
          variableName: 'nextUrl'
          value: '${environment().resourceManager}subscriptions?api-version=2022-12-01'
        }
      }
      { // Get All Subscription Pages
        name: 'Get All Subscription Pages'
        description: 'The subscriptions list API paginates via nextLink once a tenant has enough subscriptions; a single WebActivity call only returns the first page and would silently under-count subscriptions at scale. Loop until the response stops returning a nextLink.'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set Subscriptions Url'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(variables(\'nextUrl\'), \'\')'
            type: 'Expression'
          }
          timeout: '0.01:00:00'
          activities: [
            {
              name: 'Get Subscriptions Page'
              type: 'WebActivity'
              dependsOn: []
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
                  value: '@variables(\'nextUrl\')'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: environment().resourceManager
                }
              }
            }
            { // ADF rejects a SetVariable expression that reads the same variable it writes ("self reference is not
              // supported"), so accumulate into a scratch variable first, then copy the scratch value across in a
              // second, non-self-referencing SetVariable.
              name: 'Merge Subscriptions Page'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Get Subscriptions Page'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionsArrayNext'
                value: {
                  value: '@union(variables(\'subscriptionsArray\'), activity(\'Get Subscriptions Page\').output.value)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Append Subscriptions Page'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Merge Subscriptions Page'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'subscriptionsArray'
                value: {
                  value: '@variables(\'subscriptionsArrayNext\')'
                  type: 'Expression'
                }
              }
            }
            { // The ARM subscriptions list response omits the nextLink property entirely on the final page (it isn't
              // present-but-null), and ADF's expression evaluator throws when a property path doesn't exist at all -
              // coalesce() does not protect against that. Guard the read behind an IfCondition (real control-flow
              // branching) so activity('...').output.nextLink is only evaluated once contains() has already proven
              // the key exists.
              name: 'Set Next Subscriptions Url'
              description: 'ARM returns nextLink only while another page remains; the property is absent (not null) on the last page, so branch on contains() before reading it.'
              type: 'IfCondition'
              dependsOn: [
                {
                  activity: 'Get Subscriptions Page'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@contains(activity(\'Get Subscriptions Page\').output, \'nextLink\')'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Set Next Subscriptions Url From NextLink'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'nextUrl'
                      value: {
                        value: '@activity(\'Get Subscriptions Page\').output.nextLink'
                        type: 'Expression'
                      }
                    }
                  }
                ]
                ifFalseActivities: [
                  {
                    name: 'Clear Next Subscriptions Url'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'nextUrl'
                      value: ''
                    }
                  }
                ]
              }
            }
          ]
        }
      }
      {
        name: 'Filter Enabled Subscriptions'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Get All Subscription Pages'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'subscriptionsArray\')'
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
          batchCount: app.hub.options.privateRouting ? 4 : 30 // so we don't overload the managed runtime
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
      nextUrl: {
        type: 'String'
      }
      subscriptionsArray: {
        type: 'Array'
      }
      subscriptionsArrayNext: {
        type: 'Array'
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
            value: '@if(equals(toLower(activity(\'Get Provider\').output.registrationState), \'registered\'), activity(\'Get Provider\').output.resourceTypes, json(\'[]\'))'
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
            value: '@if(empty(activity(\'Filter Provider Resource Type\').output.value), json(\'[]\'), activity(\'Get Locations\').output.value)'
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
          // Proven live against Trey, a single-subscription tenant (30-100+
          // physical regions depending on provider): CopyQuery's old shared
          // concurrency cap forced this to 1. With that cap removed, 8
          // (matching ccm_datafactory's proven ForEach batchCount) ran cleanly
          // with zero throttling across 100+ concurrent CopyQuery calls in one
          // subscription's regional fan-out.
          //
          // CAVEAT: Trey has exactly one subscription, so this proves intra-
          // subscription (region) concurrency only. ForEach Subscription's
          // batchCount of 30 (in ExecuteTenant) has never been exercised
          // concurrently against this batchCount of 8 - a tenant with 30
          // subscriptions running at once, each fanning out to 8 regions,
          // would produce up to 240 simultaneous CopyQuery calls, more than
          // double what has been proven safe here. Multi-subscription-scale
          // ARM throttling behavior at that concurrency remains unverified.
          batchCount: 8
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
//
// This is the only pipeline that calls ARM or writes a file. Everything above it
// exists to expand one query definition into concrete (scope, location) pairs.
//
// Empty-result handling follows the AzureResourceGraph app: check whether the query
// returns results before running the Copy, so an empty result set never produces a
// file. See 'Check Query Has Results' and 'If Query Has Results' below.
//------------------------------------------------------------------------------

resource pipeline_CopyQuery 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_AzureResourceManager_CopyQuery'
  parent: dataFactory
  properties: {
    // No pipeline-level concurrency cap, matching AzureResourceGraph's proven
    // pattern. CopyQuery is invoked from three independent fan-out points
    // (ForEach Scope, the direct-query branch of ForEach Subscription, and
    // ForEach Location); a shared cap here makes their batchCounts multiply
    // against one budget instead of scaling independently (batchCount * batchCount
    // <= cap forces the innermost loop toward 1). ADF's own default admission
    // ceiling (~10,000 concurrent pipeline runs) and real ARM/IR throughput are
    // the actual constraints; each ForEach's own batchCount is what should be
    // tuned per loop.
    activities: [
      {
        name: 'Check Query Has Results'
        description: 'Run the query to check if there are any results before attempting the full copy.'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:05:00'
          retry: 1
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          url: {
            value: '@concat(\'${environment().resourceManager}\', substring(pipeline().parameters.queryScope, 1, sub(length(pipeline().parameters.queryScope), 1)), replace(pipeline().parameters.query, \'{location}\', pipeline().parameters.queryLocation))'
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
        name: 'If Query Has Results'
        description: 'Only run the copy if the query returned results to avoid schema mapping errors on empty result sets.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Check Query Has Results'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@greater(length(activity(\'Check Query Has Results\').output.value), 0)'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Execute ARM Query'
              description: 'Execute one paginated ARM request and write Parquet to msexports staging for pre-manifest consolidation.'
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
                  // Native ADF pagination. This replaced a manual paging loop that used a
                  // second Copy to extract nextLink into a metadata Parquet file, a Lookup
                  // to read it, and a run-scoped _ftk-arm-pagination/{runId} folder. That
                  // design could not nest inside the scope-expansion loops, because ADF
                  // does not allow control-flow containers to nest. Do not reintroduce it.
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
                      value: '@concat(\'_ftk-query-staging/\', replace(pipeline().parameters.ingestionPath, concat(pipeline().parameters.queryType, \'.parquet\'), \'\'), \'/SubAccountId=\', last(split(pipeline().parameters.queryScope, \'/\')), if(empty(pipeline().parameters.queryLocation), \'\', concat(\'/location=\', pipeline().parameters.queryLocation)), \'/x_SourceName=\', pipeline().parameters.querySource, \'/x_SourceProvider=\', pipeline().parameters.queryProvider, if(contains(string(pipeline().parameters.translator), \'x_SourceType\'), \'\', concat(\'/x_SourceType=\', pipeline().parameters.queryType)), \'/x_SourceVersion=\', pipeline().parameters.queryVersion, \'/\', pipeline().parameters.queryType, \'--\', pipeline().parameters.queryVersion, \'--\', replace(pipeline().parameters.queryScope, \'/\', \'_\'), \'--\', pipeline().parameters.queryLocation, \'.parquet\')'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              name: 'Handle Query Copy Failure'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Execute ARM Query'
                  dependencyConditions: ['Failed']
                }
              ]
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'copyFailureHandled'
                value: true
              }
            }
            {
              // Propagate the failure. Without this, the SetVariable above is the only
              // leaf activity on this branch, so ADF reports the pipeline as Succeeded
              // even though the ARM copy failed and no data was written for this scope.
              name: 'Fail Query Copy'
              type: 'Fail'
              dependsOn: [
                {
                  activity: 'Handle Query Copy Failure'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                message: {
                  value: 'ARM query copy failed for scope @{pipeline().parameters.queryScope}, location @{pipeline().parameters.queryLocation}, query @{pipeline().parameters.query}.'
                  type: 'Expression'
                }
                errorCode: 'ArmQueryCopyFailed'
              }
            }
          ]
        }
      }
      {
        name: 'Handle Query Probe Failure'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Check Query Has Results'
            dependencyConditions: ['Failed']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'probeFailureHandled'
          value: true
        }
      }
      {
        // Propagate the failure. Without this, the SetVariable above is the only leaf
        // activity on this branch, so ADF reports the pipeline as Succeeded even though
        // the results probe failed (auth error, throttling, malformed response, etc.).
        name: 'Fail Query Probe'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Handle Query Probe Failure'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: 'ARM query results probe failed for scope @{pipeline().parameters.queryScope}, location @{pipeline().parameters.queryLocation}, query @{pipeline().parameters.query}.'
            type: 'Expression'
          }
          errorCode: 'ArmQueryProbeFailed'
        }
      }
      {
        name: 'Complete Skipped Query Path'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'If Query Has Results'
            dependencyConditions: ['Skipped']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'skippedQueryPathCompleted'
          value: true
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
    variables: {
      copyFailureHandled: {
        type: 'Boolean'
        defaultValue: false
      }
      probeFailureHandled: {
        type: 'Boolean'
        defaultValue: false
      }
      skippedQueryPathCompleted: {
        type: 'Boolean'
        defaultValue: false
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
