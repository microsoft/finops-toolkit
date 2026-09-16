// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as AzureResourceGraphMetadata } from './metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.AzureResourceGraph'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.FinOpsHubs.IngestionQueries'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/AzureResourceGraph/metadata.bicep'
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
  name: 'Microsoft.FinOpsHubs.AzureResourceGraph_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'  // ARG dataset and engine pipeline
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

// Resource Graph dataset - points to the ARG REST API
resource dataset_azureResourceGraph 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'azureResourceGraph'
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

// Reference existing ingestion dataset from Core app
resource dataset_ingestion 'Microsoft.DataFactory/factories/datasets@2018-06-01' existing = {
  name: core.datasets.ingestion
  parent: dataFactory
}

//------------------------------------------------------------------------------
// Engine pipeline
//------------------------------------------------------------------------------

resource pipeline_ExecuteQuery 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'queries_ResourceGraph_ExecuteQuery'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Page Through ARG Results'
        description: 'Azure Resource Graph caps a single response at 1000 rows and returns a $skipToken when more rows are available. Loop until no token comes back, writing each page to its own Parquet file.'
        type: 'Until'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(variables(\'hasMorePages\'), false)'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Build Query Request Body'
              description: 'Compose the ARG request body for the current page. $skipToken is only included once a continuation token is available.'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'requestBody'
                value: {
                  // Query text is from trusted config/queries/*.json files; no escaping needed.
                  value: '@concat(\'{ "query": "\', pipeline().parameters.query, \' | extend x_SourceName=\\"\', pipeline().parameters.querySource, \'\\", x_SourceType=\\"\', pipeline().parameters.queryType, \'\\", x_SourceProvider=\\"\', pipeline().parameters.queryProvider, \'\\", x_SourceVersion=\\"\', pipeline().parameters.queryVersion, \'\\""\', if(equals(variables(\'skipToken\'), \'\'), \'\', concat(\', "options": { "$skipToken": "\', variables(\'skipToken\'), \'" }\')), \' }\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Fetch ARG Page'
              description: 'Run the current page of the query directly (not via the Copy activity) so the response body is available to read $skipToken from. The REST connector\'s paginationRules cannot inject a continuation token into a POST body, so the page is re-run below via Copy to write it.'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Build Query Request Body'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                timeout: '0.00:05:00'
                retry: 1
                retryIntervalInSeconds: 30
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                url: '${environment().resourceManager}providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01'
                method: 'POST'
                headers: {
                  'Content-Type': 'application/json'
                }
                body: {
                  value: '@variables(\'requestBody\')'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: environment().resourceManager
                }
              }
            }
            {
              name: 'Set Has Results'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Fetch ARG Page'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'hasResults'
                value: {
                  value: '@greater(length(activity(\'Fetch ARG Page\').output.data), 0)'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Set Skip Token'
              description: 'Read the continuation token for the next page, if any.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Set Has Results'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'skipToken'
                value: {
                  value: '@if(contains(activity(\'Fetch ARG Page\').output, \'$skipToken\'), activity(\'Fetch ARG Page\').output[\'$skipToken\'], \'\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Set Has More Pages'
              description: 'Stop the loop once a page comes back empty or Resource Graph stops returning a continuation token.'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Set Skip Token'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'hasMorePages'
                value: {
                  value: '@and(variables(\'hasResults\'), not(equals(variables(\'skipToken\'), \'\')))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'If Page Has Results'
              description: 'Only write the page if it returned results, to avoid schema mapping errors on empty result sets.'
              type: 'IfCondition'
              dependsOn: [
                {
                  activity: 'Set Has More Pages'
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@variables(\'hasResults\')'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Write ARG Page'
                    description: 'Re-run the current page and write the result to the ingestion container as Parquet.'
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
                          value: '@variables(\'requestBody\')'
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
                        value: '@pipeline().parameters.translator'
                        type: 'Expression'
                      }
                    }
                    inputs: [
                      {
                        referenceName: dataset_azureResourceGraph.name
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
                            // Insert a "_<page number>" suffix before the ".parquet" extension so each page gets a unique file in the same ingestion folder.
                            value: '@concat(substring(pipeline().parameters.ingestionPath, 0, sub(length(pipeline().parameters.ingestionPath), 8)), \'_\', variables(\'pageNumber\'), \'.parquet\')'
                            type: 'Expression'
                          }
                        }
                      }
                    ]
                  }
                  {
                    name: 'Increment Page Number'
                    type: 'SetVariable'
                    dependsOn: [
                      {
                        activity: 'Write ARG Page'
                        dependencyConditions: ['Succeeded']
                      }
                    ]
                    policy: {
                      secureOutput: false
                      secureInput: false
                    }
                    userProperties: []
                    typeProperties: {
                      variableName: 'pageNumber'
                      value: {
                        value: '@string(add(int(variables(\'pageNumber\')), 1))'
                        type: 'Expression'
                      }
                    }
                  }
                ]
              }
            }
          ]
          timeout: '0.02:00:00'
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
    variables: {
      skipToken: {
        type: 'String'
        defaultValue: ''
      }
      hasMorePages: {
        type: 'Bool'
        defaultValue: true
      }
      hasResults: {
        type: 'Bool'
        defaultValue: false
      }
      pageNumber: {
        type: 'String'
        defaultValue: '1'
      }
      requestBody: {
        type: 'String'
        defaultValue: ''
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

@description('The app properties for the AzureResourceGraph app.')
output app HubAppProperties = app

@description('Metadata describing resources created by the AzureResourceGraph app.')
output metadata AzureResourceGraphMetadata = {
  id: 'Microsoft.FinOpsHubs.AzureResourceGraph'
  version: finOpsToolkitVersion
  datasets: {
    azureResourceGraph: dataset_azureResourceGraph.name
  }
}
