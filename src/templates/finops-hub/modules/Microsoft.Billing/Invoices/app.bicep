// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../../Microsoft.FinOpsHubs/Core/metadata.bicep'
import { AppMetadata as InvoicesMetadata } from './metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.Billing.Invoices'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.Billing/Invoices/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. Metadata describing shared resources from the Core app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'Core app version must be 13.0 or higher.')
param core CoreMetadata

@description('Optional. Day of the month to download invoices from the previous month. Invoices are generally available within the first few days of the month. Default: 10.')
@minValue(1)
@maxValue(28)
param scheduleDay int = 10


//==============================================================================
// Variables
//==============================================================================

var INVOICES = 'invoices'

// API version used for all Microsoft.Billing invoice operations.
var billingApiVersion = '2024-04-01'


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.Billing.Invoices_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
    ]
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

// Generic HTTP linked service used to download the short-lived SAS URL returned by the Billing API.
resource linkedService_invoiceDownload 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${INVOICES}_download'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'HttpServer'
    parameters: {
      baseUrl: {
        type: 'String'
      }
    }
    typeProperties: {
      url: {
        value: '@linkedService().baseUrl'
        type: 'Expression'
      }
      enableServerCertificateValidation: true
      authenticationType: 'Anonymous'
    }
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------

// Binary source pointing at the short-lived SAS URL returned by the Billing API.
resource dataset_invoiceDownload 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${INVOICES}_download'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'Binary'
    parameters: {
      downloadUrl: {
        type: 'String'
      }
    }
    linkedServiceName: {
      referenceName: linkedService_invoiceDownload.name
      type: 'LinkedServiceReference'
      parameters: {
        baseUrl: {
          value: '@dataset().downloadUrl'
          type: 'Expression'
        }
      }
    }
    typeProperties: {
      location: {
        type: 'HttpServerLocation'
        relativeUrl: ''
      }
    }
  }
}

// Binary sink in the hub data lake. Files are saved in the ingestion container.
resource dataset_invoiceFile 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${INVOICES}_file'
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
        fileSystem: core.containers.ingestion
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

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

// Downloads a single invoice file. Split out from the per-billing-account pipeline because
// Data Factory does not support an Until activity nested inside a ForEach activity, and because
// a child pipeline gives each invoice its own variable scope, which keeps the parent ForEach parallel.
resource pipeline_DownloadInvoiceFile 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${INVOICES}_DownloadInvoiceFile'
  parent: dataFactory
  properties: {
    description: 'Requests a download URL for a single invoice and saves the file in the hub data lake.'
    parameters: {
      invoiceId: {
        type: 'String'
      }
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    variables: {
      downloadUrl: {
        type: 'String'
      }
      pollUrl: {
        type: 'String'
      }
    }
    activities: [
      { // Request Download URL
        name: 'Request Download URL'
        description: 'Request a short-lived SAS URL for the invoice file. This is a long-running operation: the API may return 200 with the URL or 202 with a Location header to poll.'
        type: 'WebActivity'
        dependsOn: []
        policy: {
          timeout: '0.00:05:00'
          retry: 3
          retryIntervalInSeconds: 30
          secureOutput: true
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          // invoiceId starts with a slash, so strip it before appending to the ARM endpoint.
          url: {
            value: '@concat(\'${environment().resourceManager}\', substring(pipeline().parameters.invoiceId, 1, sub(length(pipeline().parameters.invoiceId), 1)), \'/download?api-version=${billingApiVersion}\')'
            type: 'Expression'
          }
          method: 'POST'
          body: '{}'
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      { // Set Download URL
        name: 'Set Download URL'
        description: 'Capture the download URL when the API completed synchronously.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Request Download URL'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: true
          secureInput: true
        }
        userProperties: []
        typeProperties: {
          variableName: 'downloadUrl'
          value: {
            value: '@if(contains(activity(\'Request Download URL\').output, \'url\'), activity(\'Request Download URL\').output.url, \'\')'
            type: 'Expression'
          }
        }
      }
      { // Set Poll URL
        name: 'Set Poll URL'
        description: 'Capture the async operation URL when the API returned 202 Accepted. Data Factory does not follow long-running operations automatically.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Download URL'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: true
          secureInput: true
        }
        userProperties: []
        typeProperties: {
          variableName: 'pollUrl'
          value: {
            value: '@if(contains(activity(\'Request Download URL\').output, \'ADFWebActivityResponseHeaders\'), if(contains(activity(\'Request Download URL\').output.ADFWebActivityResponseHeaders, \'Location\'), activity(\'Request Download URL\').output.ADFWebActivityResponseHeaders.Location, if(contains(activity(\'Request Download URL\').output.ADFWebActivityResponseHeaders, \'Azure-AsyncOperation\'), activity(\'Request Download URL\').output.ADFWebActivityResponseHeaders[\'Azure-AsyncOperation\'], \'\')), \'\')'
            type: 'Expression'
          }
        }
      }
      { // Until Download URL Is Ready
        name: 'Until Download URL Is Ready'
        description: 'Poll the async operation until it returns the download URL. Exits immediately when the URL is already known or there is nothing to poll.'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set Poll URL'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@or(not(empty(variables(\'downloadUrl\'))), empty(variables(\'pollUrl\')))'
            type: 'Expression'
          }
          timeout: '0.00:30:00'
          activities: [
            { // If Download Is Pending
              name: 'If Download Is Pending'
              type: 'IfCondition'
              dependsOn: []
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@and(empty(variables(\'downloadUrl\')), not(empty(variables(\'pollUrl\'))))'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  { // Wait For Download
                    name: 'Wait For Download'
                    type: 'Wait'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      waitTimeInSeconds: 15
                    }
                  }
                  { // Check Download Status
                    name: 'Check Download Status'
                    description: 'Check whether the invoice document is ready. Returns 202 while running and 200 with the download URL when complete.'
                    type: 'WebActivity'
                    dependsOn: [
                      {
                        activity: 'Wait For Download'
                        dependencyConditions: ['Succeeded']
                      }
                    ]
                    policy: {
                      timeout: '0.00:05:00'
                      retry: 3
                      retryIntervalInSeconds: 30
                      secureOutput: true
                      secureInput: true
                    }
                    userProperties: []
                    typeProperties: {
                      url: {
                        value: '@variables(\'pollUrl\')'
                        type: 'Expression'
                      }
                      method: 'GET'
                      authentication: {
                        type: 'MSI'
                        resource: environment().resourceManager
                      }
                    }
                  }
                  { // Update Download URL
                    name: 'Update Download URL'
                    type: 'SetVariable'
                    dependsOn: [
                      {
                        activity: 'Check Download Status'
                        dependencyConditions: ['Succeeded']
                      }
                    ]
                    policy: {
                      secureOutput: true
                      secureInput: true
                    }
                    userProperties: []
                    typeProperties: {
                      variableName: 'downloadUrl'
                      value: {
                        value: '@if(contains(activity(\'Check Download Status\').output, \'url\'), activity(\'Check Download Status\').output.url, \'\')'
                        type: 'Expression'
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
      { // Verify Download URL
        name: 'Verify Download URL'
        description: 'Fail with a clear error when the download URL was never returned, instead of letting the copy fail on an empty URL.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Until Download URL Is Ready'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@empty(variables(\'downloadUrl\'))'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Missing Download URL'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: '@concat(\'The Billing API did not return a download URL for invoice \', pipeline().parameters.fileName, \'. The request may still be in progress or the invoice may not be available for download.\')'
                  type: 'Expression'
                }
                errorCode: 'InvoiceDownloadUrlNotAvailable'
              }
            }
          ]
        }
      }
      { // Save Invoice File
        name: 'Save Invoice File'
        description: 'Copy the invoice file from the SAS URL into the hub data lake.'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Verify Download URL'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.00:15:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: true
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'BinarySource'
            storeSettings: {
              type: 'HttpReadSettings'
              requestMethod: 'GET'
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
            referenceName: dataset_invoiceDownload.name
            type: 'DatasetReference'
            parameters: {
              downloadUrl: {
                value: '@variables(\'downloadUrl\')'
                type: 'Expression'
              }
            }
          }
        ]
        outputs: [
          {
            referenceName: dataset_invoiceFile.name
            type: 'DatasetReference'
            parameters: {
              folderPath: {
                value: '@pipeline().parameters.folderPath'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
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

// Downloads all invoices for a single billing account. Split out from the orchestrator
// pipeline because Data Factory does not support nested ForEach activities.
resource pipeline_DownloadBillingAccountInvoices 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${INVOICES}_DownloadBillingAccountInvoices'
  parent: dataFactory
  properties: {
    description: 'Downloads invoice files for a single billing account and saves them in the hub data lake.'
    parameters: {
      billingAccountId: {
        type: 'String'
      }
      periodOffsetMonths: {
        type: 'Int'
        defaultValue: -1
      }
    }
    variables: {
      periodStart: {
        type: 'String'
      }
      periodEnd: {
        type: 'String'
      }
    }
    activities: [
      { // Set Period Start
        name: 'Set Period Start'
        description: 'First day of the month being downloaded.'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'periodStart'
          value: {
            value: '@formatDateTime(startOfMonth(addToTime(utcNow(), pipeline().parameters.periodOffsetMonths, \'Month\')), \'yyyy-MM-dd\')'
            type: 'Expression'
          }
        }
      }
      { // Set Period End
        name: 'Set Period End'
        description: 'Last day of the month being downloaded.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Period Start'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'periodEnd'
          value: {
            value: '@formatDateTime(addDays(addToTime(startOfMonth(addToTime(utcNow(), pipeline().parameters.periodOffsetMonths, \'Month\')), 1, \'Month\'), -1), \'yyyy-MM-dd\')'
            type: 'Expression'
          }
        }
      }
      { // List Invoices
        name: 'List Invoices'
        description: 'List all invoices for the billing account within the requested period. Returns an empty list for billing accounts that do not support invoice downloads (for example, legacy Enterprise Agreement accounts).'
        type: 'WebActivity'
        dependsOn: [
          {
            activity: 'Set Period End'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          timeout: '0.00:10:00'
          retry: 3
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          url: {
            value: '@concat(\'${environment().resourceManager}providers/Microsoft.Billing/billingAccounts/\', pipeline().parameters.billingAccountId, \'/invoices?api-version=${billingApiVersion}&periodStartDate=\', variables(\'periodStart\'), \'&periodEndDate=\', variables(\'periodEnd\'))'
            type: 'Expression'
          }
          method: 'GET'
          authentication: {
            type: 'MSI'
            resource: environment().resourceManager
          }
        }
      }
      { // Download Invoices
        name: 'Download Invoices'
        description: 'Download each invoice file. The download URL is a short-lived SAS URL, so keep concurrency low to avoid expiration.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'List Invoices'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@coalesce(activity(\'List Invoices\').output.value, json(\'[]\'))'
            type: 'Expression'
          }
          isSequential: false
          batchCount: 3
          activities: [
            { // Download Invoice File
              name: 'Download Invoice File'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_DownloadInvoiceFile.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  invoiceId: {
                    value: '@item().id'
                    type: 'Expression'
                  }
                  folderPath: {
                    // invoices/<yyyy-MM>/<billingProfileId>/<purchaseOrderNumber>
                    // billingProfileId and purchaseOrderNumber are optional. Referencing a property that
                    // is missing from the response fails to evaluate, so guard each one with contains().
                    value: '@concat(\'${INVOICES}/\', formatDateTime(item().properties.invoicePeriodStartDate, \'yyyy-MM\'), \'/\', if(contains(item().properties, \'billingProfileId\'), last(split(item().properties.billingProfileId, \'/\')), \'unknown\'), \'/\', if(and(contains(item().properties, \'purchaseOrderNumber\'), not(empty(item().properties.purchaseOrderNumber))), item().properties.purchaseOrderNumber, \'no-po\'))'
                    type: 'Expression'
                  }
                  fileName: {
                    value: '@concat(item().name, \'.pdf\')'
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

// Resolves the billing accounts to download invoices for and runs the download pipeline for each one.
resource pipeline_DownloadInvoices 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${INVOICES}_DownloadInvoices'
  parent: dataFactory
  properties: {
    description: 'Downloads Microsoft invoice files for all configured billing accounts and saves them in the hub data lake.'
    parameters: {
      periodOffsetMonths: {
        type: 'Int'
        defaultValue: -1
      }
    }
    variables: {
      billingAccounts: {
        type: 'Array'
      }
    }
    activities: [
      { // Load Settings
        name: 'Load Settings'
        description: 'Read hub settings to determine which billing accounts to download invoices for.'
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
      { // Find Monitored Billing Accounts
        name: 'Find Monitored Billing Accounts'
        description: 'Fall back to the billing account scopes monitored by this hub when no billing accounts are explicitly configured.'
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
            value: '@coalesce(activity(\'Load Settings\').output.firstRow.scopes, json(\'[]\'))'
            type: 'Expression'
          }
          condition: {
            // Billing account scopes only: /providers/Microsoft.Billing/billingAccounts/<id>
            value: '@and(startswith(toLower(item().scope), \'/providers/microsoft.billing/billingaccounts/\'), equals(length(split(item().scope, \'/\')), 5))'
            type: 'Expression'
          }
        }
      }
      { // Resolve Billing Accounts
        name: 'Resolve Billing Accounts'
        description: 'Use the explicitly configured billing accounts when available; otherwise use the monitored billing account scopes.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Find Monitored Billing Accounts'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@greater(length(coalesce(activity(\'Load Settings\').output.firstRow.invoices.billingAccounts, json(\'[]\'))), 0)'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Set Configured Billing Accounts'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'billingAccounts'
                value: {
                  value: '@activity(\'Load Settings\').output.firstRow.invoices.billingAccounts'
                  type: 'Expression'
                }
              }
            }
          ]
          ifFalseActivities: [
            {
              name: 'Set Monitored Billing Accounts'
              description: 'Extract the billing account ID from each monitored billing account scope.'
              type: 'ForEach'
              dependsOn: []
              userProperties: []
              typeProperties: {
                items: {
                  value: '@activity(\'Find Monitored Billing Accounts\').output.Value'
                  type: 'Expression'
                }
                isSequential: true
                activities: [
                  {
                    name: 'Append Billing Account'
                    type: 'AppendVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'billingAccounts'
                      value: {
                        value: '@last(split(item().scope, \'/\'))'
                        type: 'Expression'
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
      { // Download Invoices Per Billing Account
        name: 'Download Invoices Per Billing Account'
        description: 'Run the download pipeline for each billing account. Executed sequentially to keep the number of concurrent Billing API calls low.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Resolve Billing Accounts'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'billingAccounts\')'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Download Billing Account Invoices'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_DownloadBillingAccountInvoices.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  billingAccountId: {
                    value: '@item()'
                    type: 'Expression'
                  }
                  periodOffsetMonths: {
                    value: '@pipeline().parameters.periodOffsetMonths'
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

module timeZones '../../Microsoft.CostManagement/ManagedExports/timeZones.bicep' = {
  name: 'Microsoft.Billing.Invoices_TimeZones'
  params: {
    location: app.hub.location
  }
}

resource trigger_MonthlySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${INVOICES}_MonthlySchedule'
  parent: dataFactory
  properties: {
    description: 'Downloads invoices from the previous month.'
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_DownloadInvoices.name
          type: 'PipelineReference'
        }
        parameters: {
          periodOffsetMonths: -1
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Month'
        interval: 1
        startTime: '2023-01-10T06:00:00'
        timeZone: timeZones.outputs.Timezone
        schedule: {
          monthDays: [
            scheduleDay
          ]
          hours: [
            6
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

@description('The app properties for the Invoices app.')
output app HubAppProperties = app

@description('Metadata describing resources created by the Invoices app.')
output metadata InvoicesMetadata = {
  id: 'Microsoft.Billing.Invoices'
  version: finOpsToolkitVersion
  storage: {
    container: core.containers.ingestion
    folder: INVOICES
  }
  datasets: {
    invoiceDownload: dataset_invoiceDownload.name
    invoiceFile: dataset_invoiceFile.name
  }
  linkedServices: {
    invoiceDownload: linkedService_invoiceDownload.name
  }
  pipelines: {
    downloadInvoices: pipeline_DownloadInvoices.name
  }
}
