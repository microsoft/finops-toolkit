//==============================================================================
// Parameters
//==============================================================================
@description('Required. Name of the FinOps Hub')
param hubName string

@description('Required. Name of the data factory')
param dataFactoryName string

@description('Required. The name of the Azure Key Vault instance.')
param keyVaultName string

@description('Required. The name of the Azure storage account instance.')
param storageAccountName string

@description('Required. The name of the container where Cost Management data is exported.')
param exportContainerName string

@description('Required. The name of the container where normalized data is ingested.')
param ingestionContainerName string

@description('Required. The name of the container where normalized data is ingested.')
param configContainerName string

@description('Optional. Indicates whether ingested data should be converted to Parquet. Default: true.')
param convertToParquet bool = true

@description('Optional. The location to use for the managed identity and deployment script to auto-start triggers. Default = (resource group location).')
param location string = resourceGroup().location

@description('Optional. Remote storage account for ingestion dataset.')
param remoteHubStorageUri string

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var datasetPropsDelimitedText = {
  columnDelimiter: ','
  compressionLevel: 'Optimal'
  escapeChar: '"'
  firstRowAsHeader: true
  quoteChar: '"'
}
var datasetPropsParquet = {}
var datasetPropsCommon = {
  location: {
    type: 'AzureBlobFSLocation'
    fileName: {
      value: '@{dataset().fileName}'
      type: 'Expression'
    }
    folderPath: {
      value: '@{dataset().folderName}'
      type: 'Expression'
    }
  }
}

var safeExportContainerName = replace('${exportContainerName}', '-', '_')
var safeIngestionContainerName = replace('${ingestionContainerName}', '-', '_')
var safeConfigContainerName = replace('${configContainerName}', '-', '_')

// All hub triggers (used to auto-start)
var extractExportTriggerName = '${safeExportContainerName}_extract'
var updateConfigTriggerName = '${safeExportContainerName}_setup'
var dailyTriggerName = '${safeExportContainerName}_daily'
var monthlyTriggerName = '${safeExportContainerName}_monthly'
var allHubTriggers = [
  extractExportTriggerName
  updateConfigTriggerName
  dailyTriggerName
  monthlyTriggerName
]

// Roles needed to auto-start triggers
var autoStartRbacRoles = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
]

// Storage roles needed for ADF to create CM exports and process the output
// Does not include roles assignments needed against the export scope
var storageRbacRoles = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader
]

//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

// Get keyvault instance
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

//------------------------------------------------------------------------------
// Identities and RBAC
//------------------------------------------------------------------------------

// Create managed identity to start/stop triggers
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactory.name}_${exportContainerName}_extract_triggerManager'
  location: location
}

resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in autoStartRbacRoles: {
  name: guid(dataFactory.id, role, identity.id)
  scope: dataFactory
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Create managed identity to manage exports in cost management
resource pipelineIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in storageRbacRoles: {
  name: guid(storageAccount.id, role, dataFactory.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

//------------------------------------------------------------------------------
// Stop all triggers before deploying
//------------------------------------------------------------------------------

// Stop hub triggers if they're already running
resource stopHubTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_stopHubTriggers'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    identityRoleAssignments
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Start-Triggers.ps1')
    arguments: '-Stop'
    environmentVariables: [
      {
        name: 'DataFactorySubscriptionId'
        value: subscription().id
      }
      {
        name: 'DataFactoryResourceGroup'
        value: resourceGroup().name
      }
      {
        name: 'DataFactoryName'
        value: dataFactory.name
      }
      {
        name: 'Triggers'
        value: join(allHubTriggers, '|')
      }
    ]
  }
}

//------------------------------------------------------------------------------
// Linked services
//------------------------------------------------------------------------------

resource linkedService_keyVault 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: keyVault.name
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: reference('Microsoft.KeyVault/vaults/${keyVault.name}', '2023-02-01').vaultUri
    }
  }
}

resource linkedService_storageAccount 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: storageAccount.name
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2021-08-01').primaryEndpoints.dfs
    }
  }
}

resource linkedService_remoteHubStorage 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = if (!empty(remoteHubStorageUri)) {
  name: 'remoteHubStorage'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: remoteHubStorageUri
      accountKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: linkedService_keyVault.name
          type: 'LinkedServiceReference'
        }
        secretName: '${toLower(hubName)}-storage-key'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Datasets
//------------------------------------------------------------------------------
resource dataset_config 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeConfigContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderName: {
        type: 'String'
        defaultValue: configContainerName
      }
    }
    type: 'Json'
    typeProperties: datasetPropsCommon
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeExportContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
      }
      folderName: {
        type: 'String'
      }
    }
    type: 'DelimitedText'
    typeProperties: union(datasetPropsCommon, datasetPropsDelimitedText, { compressionCodec: 'none' })
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_ingestion 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: safeIngestionContainerName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
      }
      folderName: {
        type: 'String'
      }
    }
    type: any(convertToParquet ? 'Parquet' : 'DelimitedText')
    typeProperties: union(
      datasetPropsCommon,
      convertToParquet ? datasetPropsParquet : datasetPropsDelimitedText,
      { compressionCodec: 'gzip' }
    )
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

//------------------------------------------------------------------------------
// Export container extract pipeline + trigger
// Trigger: New CSV files in exportContainer
//
// Queues the transform pipeline.
// This pipeline must complete ASAP due to ADF's hard limit of 100 concurrent executions per pipeline.
// If multiple large, partitioned exports run concurrently and this pipeline doesn't finish quickly, the transform pipeline won't get triggered.
// Queuing up the transform pipeline and exiting immediately greatly reduces the likelihood of this happening.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Triggers
//------------------------------------------------------------------------------
resource trigger_exportContainer 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: extractExportTriggerName
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_extractExport.name
          type: 'PipelineReference'
        }
        parameters: {
          folderName: '@triggerBody().folderPath'
          fileName: '@triggerBody().fileName'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${exportContainerName}/blobs/'
      blobPathEndsWith: '.csv'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_configContainer 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: updateConfigTriggerName
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_setup.name
          type: 'PipelineReference'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${configContainerName}/blobs/'
      blobPathEndsWith: 'settings.json'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_daily 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: dailyTriggerName
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_get.name
          type: 'PipelineReference'
        }
        parameters: {
          Recurrence: 'Daily'
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Hour'
        interval: 24
        startTime: '2023-01-01T01:01:00'
        timeZone: 'Pacific Standard Time'
      }
    }
  }
}

resource trigger_monthly 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: monthlyTriggerName
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_get.name
          type: 'PipelineReference'
        }
        parameters: {
          Recurrence: 'Monthly'
        }
      }
    ]
    type: 'ScheduleTrigger'
    typeProperties: {
      recurrence: {
        frequency: 'Month'
        interval: 1
        startTime: '2023-01-05T01:11:00'
        timeZone: 'Pacific Standard Time'
        schedule: {
          monthDays: [
            5
            19
          ]
        }
      }
    }
  }
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Microsoft Cost Management backfill exports
// Triggered by ???.
// Creates and triggers cost management exports against all defined scopes for the specified date ranges.
//------------------------------------------------------------------------------
resource pipeline_backfill 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_backfill'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Get Config'
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
              folderName: {
                value: '@variables(\'folderName\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        name: 'Set backfill end date'
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
          variableName: 'endDate'
          value: {
            value: '@addDays(startOfMonth(utcNow()), -1)'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set backfill start date'
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
          variableName: 'startDate'
          value: {
            value: '@subtractFromTime(startOfMonth(utcNow()), activity(\'Get Config\').output.firstRow.retention.ingestion.months, \'Month\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set export start date'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set backfill start date'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'thisMonth'
          value: {
            value: '@variables(\'startDate\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set export end date'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set export start date'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'nextMonth'
          value: {
            value: '@startOfMonth(addToTime(variables(\'thisMonth\'), 1, \'Month\'))'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Every Month'
        type: 'Until'
        dependsOn: [
          {
            activity: 'Set export end date'
            dependencyConditions: [
              'Succeeded'
            ]
          }
          {
            activity: 'Set backfill end date'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@greater(variables(\'thisMonth\'), variables(\'endDate\'))'
            type: 'Expression'
          }
          activities: [
            {
              name: 'Update export start date'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Backfill data'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'thisMonth'
                value: {
                  value: '@variables(\'nextMonth\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Update export end date'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Update export start date'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'nextMonth'
                value: {
                  value: '@addToTime(variables(\'thisMonth\'), 1, \'month\')'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Backfill data'
              type: 'ExecutePipeline'
              dependsOn: []
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_fill.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  StartDate: {
                    value: '@variables(\'thisMonth\')'
                    type: 'Expression'
                  }
                  EndDate: {
                    value: '@addDays(variables(\'nextMonth\'), -1)'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
          timeout: '0.12:00:00'
        }
      }
    ]
    concurrency: 1
    variables: {
      exportName: {
        type: 'String'
      }
      storageAccountId: {
        type: 'String'
        defaultValue: storageAccount.id
      }
      finOpsHub: {
        type: 'String'
        defaultValue: hubName
      }
      resourceManagementUri: {
        type: 'String'
        defaultValue: environment().resourceManager
      }
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderName: {
        type: 'String'
        defaultValue: 'config'
      }
      endDate: {
        type: 'String'
      }
      startDate: {
        type: 'String'
      }
      thisMonth: {
        type: 'String'
      }
      nextMonth: {
        type: 'String'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Microsoft Cost Management backfill exports
// Triggered by pipeline_backfill.
// Creates and triggers cost management exports against all defined scopes for the specified date range.
//------------------------------------------------------------------------------
resource pipeline_fill 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_fill'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Get Config'
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
              folderName: {
                value: '@variables(\'folderName\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        name: 'ForEach Export Scope'
        type: 'ForEach'
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
          items: {
            value: '@activity(\'Get Config\').output.firstRow.exportScopes'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Create or or update backfill amortized export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set backfill amortized export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n      "properties": {\n        "schedule": {\n          "status": "Inactive",\n          "recurrence": "daily",\n          "recurrencePeriod": {\n            "from": "2099-06-01T00:00:00Z",\n            "to": "2099-10-31T00:00:00Z"\n          }\n        },\n        "partitionData": "true",\n        "format": "Csv",\n        "deliveryInfo": {\n          "destination": {\n            "resourceId": "@{variables(\'storageAccountId\')}",\n            "container": "msexports",\n            "rootFolderPath": "@{item().scope}"\n          }\n        },\n        "definition": {\n          "type": "amortizedcost",\n          "timeframe": "Custom",\n          "timePeriod" : {\n            "from" : "@{pipeline().parameters.StartDate}",\n            "to" : "@{pipeline().parameters.EndDate}"\n          },\n          "dataSet": {\n            "granularity": "Daily"\n          }\n        }\n      }\n    }'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'resourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set backfill amortized export name'
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'finOpsHub\'), \'-custom-amortizedcost\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Trigger backfill amortized export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Create or or update backfill amortized export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}/run?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'POST'
                body: '{}'
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'resourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Create or or update backfill actual export_copy1'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set backfill actual export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n      "properties": {\n        "schedule": {\n          "status": "Inactive",\n          "recurrence": "daily",\n          "recurrencePeriod": {\n            "from": "2099-06-01T00:00:00Z",\n            "to": "2099-10-31T00:00:00Z"\n          }\n        },\n        "partitionData": "true",\n        "format": "Csv",\n        "deliveryInfo": {\n          "destination": {\n            "resourceId": "@{variables(\'storageAccountId\')}",\n            "container": "msexports",\n            "rootFolderPath": "@{item().scope}"\n          }\n        },\n        "definition": {\n          "type": "actualcost",\n          "timeframe": "Custom",\n          "timePeriod" : {\n            "from" : "@{pipeline().parameters.StartDate}",\n            "to" : "@{pipeline().parameters.EndDate}"\n          },\n          "dataSet": {\n            "granularity": "Daily"\n          }\n        }\n      }\n    }'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'resourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set backfill actual export name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Trigger backfill amortized export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'finOpsHub\'), \'-custom-actualcost\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Trigger backfill actual export_copy1'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Create or or update backfill actual export_copy1'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}/run?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'POST'
                body: '{}'
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'resourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    concurrency: 1
    parameters: {
      StartDate: {
        type: 'string'
      }
      EndDate: {
        type: 'string'
      }
    }
    variables: {
      exportName: {
        type: 'String'
      }
      storageAccountId: {
        type: 'String'
        defaultValue: storageAccount.id
      }
      finOpsHub: {
        type: 'String'
        defaultValue: hubName
      }
      resourceManagementUri: {
        type: 'String'
        defaultValue: environment().resourceManager
      }
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderName: {
        type: 'String'
        defaultValue: 'config'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Microsoft Cost Management scheduled exports
// Triggered by daily/monthly trigger.
// Enumerates all exports configured for the export scopes stored in settings.json.
//------------------------------------------------------------------------------
resource pipeline_get 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_get'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Get Config'
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
              folderName: {
                value: '@variables(\'folderName\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        name: 'ForEach Export Scope'
        type: 'ForEach'
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
          items: {
            value: '@activity(\'Get Config\').output.firstRow.exportScopes'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Get exports for scope'
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports?api-version=2023-03-01'
                  type: 'Expression'
                }
                method: 'GET'
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'resourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Run exports for scope'
              type: 'ExecutePipeline'
              dependsOn: [
                {
                  activity: 'Get exports for scope'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_run.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  ExportScopes: {
                    value: '@activity(\'Get exports for scope\').output.value'
                    type: 'Expression'
                  }
                  Recurrence: {
                    value: '@pipeline().parameters.Recurrence'
                    type: 'Expression'
                  }
                }
              }
            }
          ]
        }
      }
    ]
    concurrency: 1
    parameters: {
      Recurrence: {
        type: 'string'
        defaultValue: 'Daily'
      }
    }
    variables: {
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderName: {
        type: 'String'
        defaultValue: 'config'
      }
      finOpsHub: {
        type: 'String'
        defaultValue: hubName
      }
      resourceManagementUri: {
        type: 'String'
        defaultValue: environment().resourceManager
      }
    }
  }
}

//------------------------------------------------------------------------------
// Microsoft Cost Management scheduled exports
// Triggered by pipeline_get.
// Triggers scheduled exports for the specified scopes which meet the schedule conditions.
//------------------------------------------------------------------------------
resource pipeline_run 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_run'
  parent: dataFactory
  dependsOn: [
    dataset_config
  ]
  properties: {
    activities: [
      {
        name: 'ForEach export scope'
        type: 'ForEach'
        dependsOn: []
        userProperties: []
        typeProperties: {
          items: {
            value: '@pipeline().parameters.exportScopes'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'If scheduled'
              type: 'IfCondition'
              dependsOn: []
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@equals(tolower(item().properties.schedule.recurrence), toLower(pipeline().parameters.Recurrence))'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Trigger export'
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
                        value: '@{variables(\'resourceManagementUri\')}/@{item().id}/run?api-version=2023-03-01'
                        type: 'Expression'
                      }
                      method: 'POST'
                      body: '{}'
                      authentication: {
                        type: 'MSI'
                        resource: {
                          value: '@variables(\'resourceManagementUri\')'
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
    concurrency: 1
    parameters: {
      ExportScopes: {
        type: 'array'
      }
      Recurrence: {
        type: 'string'
        defaultValue: 'Daily'
      }
    }
    variables: {
      resourceManagementUri: {
        type: 'String'
        defaultValue: environment().resourceManager
      }
    }
  }
}

//------------------------------------------------------------------------------
// Microsoft Cost Management add export pipeline
// Triggered when settings.json is updated.
// Creates an export in Cost Management.
//------------------------------------------------------------------------------
resource pipeline_setup 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_setup'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Get Config'
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
              folderName: {
                value: '@variables(\'folderName\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        name: 'ForEach Export Scope'
        type: 'ForEach'
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
          items: {
            value: '@activity(\'Get Config\').output.firstRow.exportScopes'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Create or or update open month amortized export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set open month amortized export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Inactive",\n      "recurrence": "Daily",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{variables(\'StorageAccountId\')}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "amortizedcost",\n      "timeframe": "BillingMonthToDate",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'ResourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set open month amortized export name'
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'FinOpsHub\'), \'-daily-amortizedcost\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Create or update closed month amortized export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set closed month amortized export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'ResourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Inactive",\n      "recurrence": "Monthly",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{variables(\'StorageAccountId\')}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "amortizedcost",\n      "timeframe": "TheLastBillingMonth",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'ResourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set closed month amortized export name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Create or or update open month amortized export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'FinOpsHub\'), \'-monthly-amortizedcost\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Create or or update open month actuals export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set open month actuals export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'ResourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Inactive",\n      "recurrence": "Daily",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{variables(\'StorageAccountId\')}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "actualcost",\n      "timeframe": "BillingMonthToDate",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'ResourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set open month actuals export name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Create or update closed month amortized export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'FinOpsHub\'), \'-daily-actualcost\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Create or update closed month actuals export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set closed month actuals export name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
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
                  value: '@{variables(\'ResourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Inactive",\n      "recurrence": "Monthly",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{variables(\'StorageAccountId\')}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "actualcost",\n      "timeframe": "TheLastBillingMonth",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@variables(\'ResourceManagementUri\')'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Set closed month actuals export name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Create or or update open month actuals export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'FinOpsHub\'), \'-monthly-actualcost\'))'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
    ]
    concurrency: 1
    variables: {
      exportName: {
        type: 'String'
      }
      exportScope: {
        type: 'String'
      }
      storageAccountId: {
        type: 'String'
        defaultValue: storageAccount.id
      }
      finOpsHub: {
        type: 'String'
        defaultValue: hubName
      }
      resourceManagementUri: {
        type: 'String'
        defaultValue: environment().resourceManager
      }
      fileName: {
        type: 'String'
        defaultValue: 'settings.json'
      }
      folderName: {
        type: 'String'
        defaultValue: 'config'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Export container extract pipeline
// Triggered when an export is runs in Azure Cost Management.
// Queues up the pipeline_transformExport pipeline.
//------------------------------------------------------------------------------
resource pipeline_extractExport 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_extract'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Execute'
        type: 'ExecutePipeline'
        dependsOn: []
        userProperties: []
        typeProperties: {
          pipeline: {
            referenceName: pipeline_transformExport.name
            type: 'PipelineReference'
          }
          waitOnCompletion: false
          parameters: {
            folderName: {
              value: '@pipeline().parameters.folderName'
              type: 'Expression'
            }
            fileName: {
              value: '@pipeline().parameters.fileName'
              type: 'Expression'
            }
          }
        }
      }
    ]
    parameters: {
      folderName: {
        type: 'string'
      }
      fileName: {
        type: 'string'
      }
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Export container transform pipeline
// Converts CSV files to Parquet or .CSV.GZ files.
//------------------------------------------------------------------------------
resource pipeline_transformExport 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_transform'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Wait'
        type: 'Wait'
        dependsOn: []
        userProperties: []
        typeProperties: {
          waitTimeInSeconds: 60
        }
      }
      {
        name: 'Set Scope'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Wait'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'scope'
          value: {
            value: '@replace(split(pipeline().parameters.folderName,split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 4)])[0],\'msexports\',\'ingestion\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Metric'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Scope'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'metric'
          value: {
            value: '@if(contains(toLower(pipeline().parameters.folderName), \'amortizedcost\'), \'amortizedcost\', \'actualcost\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Date'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Metric'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'date'
          value: {
            value: '@split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 3)]'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Destination File Name'
        description: ''
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Date'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'destinationFile'
          value: {
            value: '@replace(pipeline().parameters.fileName, \'.csv\', \'.parquet\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Set Destination Folder Name'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Destination File Name'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'destinationFolder'
          value: {
            value: '@replace(concat(variables(\'scope\'),variables(\'date\'),\'/\',variables(\'metric\')),\'//\',\'/\')'
            type: 'Expression'
          }
        }
      }
      {
        name: 'Delete Target'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Set Destination Folder Name'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        policy: {
          timeout: '0.00:05:00'
          retry: 2
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
              folderName: {
                value: '@variables(\'destinationFolder\')'
                type: 'Expression'
              }
              fileName: {
                value: '@variables(\'destinationFile\')'
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
      {
        name: 'Convert CSV'
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
          timeout: '0.00:05:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'AzureBlobFSReadSettings'
              recursive: true
              enablePartitionDiscovery: false
            }
            formatSettings: {
              type: 'DelimitedTextReadSettings'
            }
          }
          sink: {
            type: 'DelimitedTextSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'ParquetWriteSettings'
              fileExtension: '.parquet'
            }
          }
          enableStaging: false
          parallelCopies: 1
          validateDataConsistency: false
        }
        inputs: [
          {
            referenceName: dataset_msexports.name
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@pipeline().parameters.folderName'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
            }
          }
        ]
        outputs: [
          {
            referenceName: dataset_ingestion.name
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@variables(\'destinationFolder\')'
                type: 'Expression'
              }
              fileName: {
                value: '@variables(\'destinationFile\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      {
        name: 'Delete CSV'
        type: 'Delete'
        dependsOn: [
          {
            activity: 'Convert CSV'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        policy: {
          timeout: '0.00:05:00'
          retry: 2
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: dataset_msexports.name
            type: 'DatasetReference'
            parameters: {
              folderName: {
                value: '@pipeline().parameters.folderName'
                type: 'Expression'
              }
              fileName: {
                value: '@pipeline().parameters.fileName'
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
      fileName: {
        type: 'string'
      }
      folderName: {
        type: 'string'
      }
    }
    variables: {
      destinationFile: {
        type: 'String'
      }
      destinationFolder: {
        type: 'String'
      }
      scope: {
        type: 'String'
      }
      date: {
        type: 'String'
      }
      metric: {
        type: 'String'
      }
    }
  }
}

//------------------------------------------------------------------------------
// Start all triggers
//------------------------------------------------------------------------------

// Start hub triggers
resource startHubTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_startHubTriggers'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    identityRoleAssignments
    trigger_exportContainer
    trigger_configContainer
    trigger_daily
    trigger_monthly
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Start-Triggers.ps1')
    environmentVariables: [
      {
        name: 'DataFactorySubscriptionId'
        value: subscription().id
      }
      {
        name: 'DataFactoryResourceGroup'
        value: resourceGroup().name
      }
      {
        name: 'DataFactoryName'
        value: dataFactory.name
      }
      {
        name: 'Triggers'
        value: join(allHubTriggers, '|')
      }
    ]
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The Resource ID of the Data factory.')
output resourceId string = dataFactory.id

@description('The Name of the Azure Data Factory instance.')
output name string = dataFactory.name
