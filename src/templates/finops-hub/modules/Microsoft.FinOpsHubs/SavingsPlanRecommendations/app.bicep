// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as IngestionQueriesMetadata } from '../IngestionQueries/metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.SavingsPlanRecommendations'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.FinOpsHubs.IngestionQueries'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/SavingsPlanRecommendations/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. Metadata describing shared resources from the Core app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'Core app version must be 13.0 or higher.')
param core CoreMetadata

@description('Required. Metadata describing resources from the Ingestion Queries app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'IngestionQueries app version must be 13.0 or higher.')
param ingestionQueries IngestionQueriesMetadata


//==============================================================================
// Variables
//==============================================================================

var PREFIX = 'savingsPlanRecommendations'

// Query engine name; must match the queries_{engine}_ExecuteQuery pipeline contract of the IngestionQueries app
var QUERY_ENGINE = 'CostManagement'

// Ingestion queries ETL pipeline that cleans up old files, runs the engine, and creates the ingestion manifest
var INGESTION_QUERIES_ETL_PIPELINE = '${ingestionQueries.queries.folder}_ETL_${core.containers.ingestion}'

var API_VERSION = '2025-03-01'
var DATASET = 'Recommendations'
var SCHEMA_FILE = 'recommendations_savingsplans_${API_VERSION}'

// Default lookback periods and terms when settings.json doesn't specify them
var DEFAULT_LOOKBACK_PERIODS = ['Last7Days', 'Last30Days', 'Last60Days']
var DEFAULT_TERMS = ['P1Y', 'P3Y']

// All supported lookback period and term combinations; the pipeline filters them by settings.json
var ALL_COMBINATIONS = flatten(map(DEFAULT_LOOKBACK_PERIODS, lookbackPeriod => map(DEFAULT_TERMS, term => {
  lookbackPeriod: lookbackPeriod
  term: term
})))

// settings.json value, or the default when the property isn't set
// NOTE: ADF evaluates if() lazily, so nested contains() checks guard missing properties
var settingsRow = 'activity(\'Load Settings\').output.firstRow'
var settingsSavingsPlans = '${settingsRow}.recommendations.savingsPlans'
var lookbackPeriodsExpression = 'if(contains(${settingsRow}, \'recommendations\'), if(contains(${settingsRow}.recommendations, \'savingsPlans\'), if(contains(${settingsSavingsPlans}, \'lookbackPeriods\'), ${settingsSavingsPlans}.lookbackPeriods, json(\'${string(DEFAULT_LOOKBACK_PERIODS)}\')), json(\'${string(DEFAULT_LOOKBACK_PERIODS)}\')), json(\'${string(DEFAULT_LOOKBACK_PERIODS)}\'))'
var termsExpression = 'if(contains(${settingsRow}, \'recommendations\'), if(contains(${settingsRow}.recommendations, \'savingsPlans\'), if(contains(${settingsSavingsPlans}, \'terms\'), ${settingsSavingsPlans}.terms, json(\'${string(DEFAULT_TERMS)}\')), json(\'${string(DEFAULT_TERMS)}\')), json(\'${string(DEFAULT_TERMS)}\'))'

// Supported billing scopes for the Benefit Recommendations API:
// - EA billing account:  providers/Microsoft.Billing/billingAccounts/{id} (MCA billing account IDs include ':' and aren't supported)
// - MCA billing profile: providers/Microsoft.Billing/billingAccounts/{id}/billingProfiles/{id}
// - Subscription:        subscriptions/{id}
// - Resource group:      subscriptions/{id}/resourceGroups/{name}
// NOTE: ADF and()/or() don't short-circuit, so only string checks are used (no array indexing)
var normalizedScope = 'toLower(if(startsWith(item().scope, \'/\'), substring(item().scope, 1, sub(length(item().scope), 1)), item().scope))'
var scopeSegments = 'length(split(${normalizedScope}, \'/\'))'
var isSubscription = 'and(startsWith(${normalizedScope}, \'subscriptions/\'), equals(${scopeSegments}, 2))'
var isResourceGroup = 'and(startsWith(${normalizedScope}, \'subscriptions/\'), and(equals(${scopeSegments}, 4), contains(${normalizedScope}, \'/resourcegroups/\')))'
var isEaBillingAccount = 'and(startsWith(${normalizedScope}, \'providers/microsoft.billing/billingaccounts/\'), and(equals(${scopeSegments}, 4), not(contains(${normalizedScope}, \':\'))))'
var isMcaBillingProfile = 'and(startsWith(${normalizedScope}, \'providers/microsoft.billing/billingaccounts/\'), and(equals(${scopeSegments}, 6), contains(${normalizedScope}, \'/billingprofiles/\')))'

// Load schema files
var schemaFiles = {
  '${SCHEMA_FILE}': loadTextContent('schemas/recommendations_savingsplans_2025-03-01.json')
}


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.SavingsPlanRecommendations_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'  // Cost Management dataset, engine, and orchestration pipelines
      'Storage'      // Storing schemas
    ]
  }
}

// Get ADF resources
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]

  resource dataset_config 'datasets@2018-06-01' existing = {
    name: core.datasets.config
  }
  resource dataset_ingestion 'datasets@2018-06-01' existing = {
    name: core.datasets.ingestion
  }
  resource linkedService_arm 'linkedservices@2018-06-01' existing = {
    name: core.linkedServices.azurerm
  }
}

//------------------------------------------------------------------------------
// Storage
//------------------------------------------------------------------------------

// Upload schema files to storage
module uploadSchemas '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.SavingsPlanRecs_UploadSchemas'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: core.containers.config
    files: reduce(items(schemaFiles), {}, (acc, item) => union(acc, { 'schemas/${item.key}.json': item.value }))
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Cost Management dataset - points to an ARM REST API relative URL
resource dataset_costManagement 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'costManagement'
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
      referenceName: dataFactory::linkedService_arm.name
      type: 'LinkedServiceReference'
    }
  }
}

//------------------------------------------------------------------------------
// Scheduling
//------------------------------------------------------------------------------

module timeZones '../../Microsoft.CostManagement/ManagedExports/timeZones.bicep' = {
  name: 'Microsoft.FinOpsHubs.SavingsPlanRecommendations_TimeZones'
  params: {
    location: app.hub.location
  }
}

resource trigger_DailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${PREFIX}_DailySchedule'
  parent: dataFactory
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteETL.name
          type: 'PipelineReference'
        }
        parameters: {}
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Hour'
        interval: 24
        // See trigger_DailySchedule in the IngestionQueries app for why the 'Z' suffix is conditional on the UTC fallback
        startTime: timeZones.outputs.Timezone == 'UTC' ? '2023-01-01T01:31:00Z' : '2023-01-01T01:31:00'
        timeZone: timeZones.outputs.Timezone
      }
    }
  }
}

//------------------------------------------------------------------------------
// Engine pipeline
//------------------------------------------------------------------------------

// Runs a Cost Management GET request (relative ARM URL passed as the query) and writes the "value" array as Parquet
resource pipeline_ExecuteQuery 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${ingestionQueries.queries.folder}_${QUERY_ENGINE}_ExecuteQuery'
  parent: dataFactory
  properties: {
    activities: [
      { // Check For Results
        name: 'Check For Results'
        description: 'Request the first page to find out whether Cost Management returned any results. An empty "value" array is a valid response (for example, no savings plan purchase would save money) and must not fail the run.'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:05:00'
          retry: 2
          retryIntervalInSeconds: 60
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          url: {
            value: '@concat(\'${environment().resourceManager}\', pipeline().parameters.query)'
            type: 'Expression'
          }
          method: 'GET'
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      { // If Results Returned
        name: 'If Results Returned'
        description: 'Only write results when the response has rows, to avoid schema mapping errors on empty result sets. When no rows are written, the previous result for this folder stays in Data Explorer.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Check For Results'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@greater(length(if(contains(activity(\'Check For Results\').output, \'value\'), activity(\'Check For Results\').output.value, json(\'[]\'))), 0)'
            type: 'Expression'
          }
          ifTrueActivities: [
            { // Write Results
              name: 'Write Results'
              description: 'Request all pages (following nextLink) and write the results to the ingestion container as Parquet.'
              type: 'Copy'
              dependsOn: []
              policy: {
                timeout: '0.00:30:00'
                retry: 2
                retryIntervalInSeconds: 60
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                source: {
                  type: 'RestSource'
                  httpRequestTimeout: '00:02:00'
                  requestInterval: '00.00:00:00.010'
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
                  referenceName: dataset_costManagement.name
                  type: 'DatasetReference'
                  parameters: {
                    relativeUrl: {
                      value: '@pipeline().parameters.query'
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
                      value: '@pipeline().parameters.ingestionPath'
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
      query: {
        type: 'String'
      }
      querySource: {
        type: 'String'
      }
      queryType: {
        type: 'String'
      }
      queryProvider: {
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

//------------------------------------------------------------------------------
// Orchestration pipelines
//------------------------------------------------------------------------------

// Runs every lookback period and term combination for one billing scope
resource pipeline_ExecuteScope 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${PREFIX}_ExecuteScope'
  parent: dataFactory
  properties: {
    activities: [
      { // Loop Thru Combinations
        name: 'Loop Thru Combinations'
        type: 'ForEach'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.combinations'
            type: 'Expression'
          }
          batchCount: 2
          isSequential: false
          activities: [
            { // Execute Recommendations Query
              name: 'Execute Recommendations Query'
              description: 'Each lookback period and term combination is written to its own folder without a date, so each run replaces the previous result for the same billing scope, term, and lookback period.'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: INGESTION_QUERIES_ETL_PIPELINE
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  ingestionId: {
                    value: '@pipeline().parameters.ingestionId'
                    type: 'Expression'
                  }
                  queryEngine: QUERY_ENGINE
                  outputDataset: DATASET
                  schemaFile: '${SCHEMA_FILE}.json'
                  queryScope: {
                    value: '@pipeline().parameters.scope'
                    type: 'Expression'
                  }
                  query: {
                    // The API accepts one lookback period, term, and benefit scope per request. Benefit scope follows from the billing scope: Shared for billing accounts and billing profiles, Single for subscriptions and resource groups.
                    value: '@concat(if(startsWith(pipeline().parameters.scope, \'/\'), substring(pipeline().parameters.scope, 1, sub(length(pipeline().parameters.scope), 1)), pipeline().parameters.scope), \'/providers/Microsoft.CostManagement/benefitRecommendations?api-version=${API_VERSION}&$filter=\', encodeUriComponent(concat(\'properties/lookBackPeriod eq \'\'\', item().lookbackPeriod, \'\'\' AND properties/term eq \'\'\', item().term, \'\'\' AND properties/scope eq \'\'\', if(contains(toLower(pipeline().parameters.scope), \'/providers/microsoft.billing/\'), \'Shared\', \'Single\'), \'\'\'\')), \'&$expand=properties/usage,properties/allRecommendationDetails\')'
                    type: 'Expression'
                  }
                  queryVersion: API_VERSION
                  querySource: 'Cost Management'
                  queryProvider: 'Microsoft'
                  queryType: {
                    value: '@concat(\'Microsoft-SavingsPlans-\', item().term, \'-\', item().lookbackPeriod)'
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
      ingestionId: {
        type: 'String'
      }
      scope: {
        type: 'String'
      }
      combinations: {
        type: 'Array'
      }
    }
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

// Reads settings.json and runs the savings plan recommendations query for each supported billing scope
resource pipeline_ExecuteETL 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${PREFIX}_ExecuteETL'
  parent: dataFactory
  properties: {
    activities: [
      { // Load Settings
        name: 'Load Settings'
        type: 'Lookup'
        dependsOn: []
        policy: {
          timeout: '0.00:05:00'
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
              fileName: core.settings.file
              folderPath: core.settings.container
            }
          }
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
      { // Filter Supported Scopes
        name: 'Filter Supported Scopes'
        description: 'Keep EA billing accounts, MCA billing profiles, subscriptions, and resource groups. Other scopes in settings.json aren\'t supported by the Benefit Recommendations API.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Load Settings'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@if(contains(${settingsRow}, \'scopes\'), ${settingsRow}.scopes, json(\'[]\'))'
            type: 'Expression'
          }
          condition: {
            value: '@or(or(${isEaBillingAccount}, ${isMcaBillingProfile}), or(${isSubscription}, ${isResourceGroup}))'
            type: 'Expression'
          }
        }
      }
      { // Filter Combinations
        name: 'Filter Combinations'
        description: 'Keep the lookback period and term combinations configured in settings.json (recommendations.savingsPlans). Defaults to all lookback periods and terms.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Load Settings'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@json(\'${string(ALL_COMBINATIONS)}\')'
            type: 'Expression'
          }
          condition: {
            value: '@and(contains(${lookbackPeriodsExpression}, item().lookbackPeriod), contains(${termsExpression}, item().term))'
            type: 'Expression'
          }
        }
      }
      { // Loop Thru Scopes
        name: 'Loop Thru Scopes'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Set Ingestion Id'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Filter Supported Scopes'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Filter Combinations'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Supported Scopes\').output.Value'
            type: 'Expression'
          }
          batchCount: 2
          isSequential: false
          activities: [
            { // Execute Scope
              name: 'Execute Scope'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ExecuteScope.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  ingestionId: {
                    value: '@variables(\'ingestionId\')'
                    type: 'Expression'
                  }
                  scope: {
                    value: '@item().scope'
                    type: 'Expression'
                  }
                  combinations: {
                    value: '@activity(\'Filter Combinations\').output.Value'
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


//==============================================================================
// Outputs
//==============================================================================

@description('The app properties for the SavingsPlanRecommendations app.')
output app HubAppProperties = app
