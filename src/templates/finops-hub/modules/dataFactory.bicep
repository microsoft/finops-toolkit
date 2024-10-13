// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the FinOps hub instance.')
param hubName string

@description('Required. Name of the Data Factory instance.')
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

@description('Optional. The name of the Azure Data Explorer cluster.')
param dataExplorerCluster string = ''

@description('Optional. The name of the Azure Data Explorer database for data ingestion.')
param dataExplorerIngestionDatabase string = ''

@description('Optional. The location to use for the managed identity and deployment script to auto-start triggers. Default = (resource group location).')
param location string = resourceGroup().location

@description('Optional. Remote storage account for ingestion dataset.')
param remoteHubStorageUri string

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var focusSchemaVersion = '1.0'
var ftkVersion = loadTextContent('ftkver.txt')
var exportApiVersion = '2023-07-01-preview'

// Function to generate the body for a Cost Management export
func getExportBody(
  exportContainerName string,
  datasetType string,
  schemaVersion string,
  isMonthly bool,
  exportFormat string,
  compressionMode string,
  partitionData string,
  dataOverwriteBehavior string
) string =>
  '{ "properties": { "definition": { "dataSet": { "configuration": { "dataVersion": "${schemaVersion}", "filters": [] }, "granularity": "Daily" }, "timeframe": "${isMonthly ? 'TheLastMonth': 'MonthToDate' }", "type": "${datasetType}" }, "deliveryInfo": { "destination": { "container": "${exportContainerName}", "rootFolderPath": "@{if(startswith(item().scope, \'/\'), substring(item().scope, 1, sub(length(item().scope), 1)) ,item().scope)}", "type": "AzureBlob", "resourceId": "@{variables(\'storageAccountId\')}" } }, "schedule": { "recurrence": "${isMonthly ? 'Monthly' : 'Daily'}", "recurrencePeriod": { "from": "2024-01-01T00:00:00.000Z", "to": "2050-02-01T00:00:00.000Z" }, "status": "Inactive" }, "format": "${exportFormat}", "partitionData": "${partitionData}", "dataOverwriteBehavior": "${dataOverwriteBehavior}", "compressionMode": "${compressionMode}" }, "id": "@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}", "name": "@{variables(\'exportName\')}", "type": "Microsoft.CostManagement/reports", "identity": { "type": "systemAssigned" }, "location": "global" }'

var datasetPropsDefault = {
  location: {
    type: 'AzureBlobFSLocation'
    fileName: {
      value: '@{dataset().fileName}'
      type: 'Expression'
    }
    folderPath: {
      value: '@{dataset().folderPath}'
      type: 'Expression'
    }
  }
}

var safeExportContainerName = replace('${exportContainerName}', '-', '_')
var safeIngestionContainerName = replace('${ingestionContainerName}', '-', '_')
var safeConfigContainerName = replace('${configContainerName}', '-', '_')
var recommendationsDataSet = 'recommendations'
var recommendationsScope = 'azure'

// All hub triggers (used to auto-start)
var fileAddedExportTriggerName = '${safeExportContainerName}_FileAdded'
var updateConfigTriggerName = '${safeConfigContainerName}_SettingsUpdated'
var dailyTriggerName = '${safeConfigContainerName}_DailySchedule'
var dailyRecommendationsTriggerName = '${recommendationsDataSet}_DailySchedule'
var monthlyTriggerName = '${safeConfigContainerName}_MonthlySchedule'
var allHubTriggers = [
  fileAddedExportTriggerName
  updateConfigTriggerName
  dailyTriggerName
  dailyRecommendationsTriggerName
  monthlyTriggerName
]

// Roles needed to auto-start triggers
var autoStartRbacRoles = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
  'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59' // Managed Identity Contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-contributor
]

// Storage roles needed for ADF to create CM exports and process the output
// Does not include roles assignments needed against the export scope
var storageRbacRoles = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#reader
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator
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

module azuretimezones 'azuretimezones.bicep' = {
  name: 'azuretimezones'
  params: {
    location: location
  }
}

//------------------------------------------------------------------------------
// Identities and RBAC
//------------------------------------------------------------------------------

// Create managed identity to start/stop triggers
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactory.name}_triggerManager'
  location: location
  tags: union(
    tags,
    contains(tagsByResource, 'Microsoft.ManagedIdentity/userAssignedIdentities')
      ? tagsByResource['Microsoft.ManagedIdentity/userAssignedIdentities']
      : {}
  )
}

resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in autoStartRbacRoles: {
    name: guid(dataFactory.id, role, identity.id)
    scope: dataFactory
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
      principalId: identity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Create managed identity to manage exports in cost management
resource pipelineIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in storageRbacRoles: {
    name: guid(storageAccount.id, role, dataFactory.id)
    scope: storageAccount
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
      principalId: dataFactory.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

//------------------------------------------------------------------------------
// Delete old triggers and pipelines
//------------------------------------------------------------------------------

resource deleteOldResources 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_deleteOldResources'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
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
  tags: union(
    tags,
    contains(tagsByResource, 'Microsoft.Resources/deploymentScripts')
      ? tagsByResource['Microsoft.Resources/deploymentScripts']
      : {}
  )
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('./scripts/Remove-OldResources.ps1')
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
    ]
  }
}

//------------------------------------------------------------------------------
// Stop all triggers before deploying
//------------------------------------------------------------------------------

resource stopTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_stopTriggers'
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
  tags: tags
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

resource linkedService_dataExplorer 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = if (!empty(dataExplorerCluster)) {
  name: dataExplorerCluster
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureDataExplorer'
    typeProperties: {
      endpoint: reference('Microsoft.Kusto/clusters/${dataExplorerCluster}', '2023-08-15').uri
      database: dataExplorerIngestionDatabase
    }
  }
}

var armEndpointPropertyName = 'aadResourceId' // This is a workaround to avoid the warning about "ResourceId" in the property name
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
        // When bicep sees "ResourceId" in the following property name, it raises a warning. The union and variable work around this to avoid the warning.
        '${armEndpointPropertyName}': environment().resourceManager
      }
    )
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
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
      }
    }
    type: 'Json'
    typeProperties: datasetPropsDefault
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_manifest 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'manifest'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
        defaultValue: 'manifest.json'
      }
      folderPath: {
        type: 'String'
        defaultValue: exportContainerName
      }
    }
    type: 'Json'
    typeProperties: datasetPropsDefault
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
      blobPath: {
        type: 'String'
      }
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeExportContainerName
      }
      columnDelimiter: ','
      escapeChar: '"'
      quoteChar: '"'
      firstRowAsHeader: true
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedService_storageAccount.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_msexports_parquet 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${safeExportContainerName}_parquet'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeExportContainerName
      }
    }
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
      blobPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@{dataset().blobPath}'
          type: 'Expression'
        }
        fileSystem: safeIngestionContainerName
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri)
        ? linkedService_storageAccount.name
        : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_ingestion_files 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${safeIngestionContainerName}_files'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      folderPath: {
        type: 'String'
      }
    }
    type: 'Parquet'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: safeIngestionContainerName
        folderPath: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri)
        ? linkedService_storageAccount.name
        : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_resourcegraph 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'resourcegraph'
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

//------------------------------------------------------------------------------
// Triggers
//------------------------------------------------------------------------------

// Create trigger
resource trigger_FileAdded 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: fileAddedExportTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteETL.name
          type: 'PipelineReference'
        }
        parameters: {
          folderPath: '@triggerBody().folderPath'
          fileName: '@triggerBody().fileName'
        }
      }
    ]
    type: 'BlobEventsTrigger'
    typeProperties: {
      blobPathBeginsWith: '/${exportContainerName}/blobs/'
      blobPathEndsWith: 'manifest.json'
      ignoreEmptyBlobs: true
      scope: storageAccount.id
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource trigger_SettingsUpdated 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: updateConfigTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ConfigureExports.name
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

resource trigger_DailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: dailyTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExportData.name
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
        timeZone: azuretimezones.outputs.Timezone
      }
    }
  }
}

resource trigger_MonthlySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: monthlyTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExportData.name
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
        timeZone: azuretimezones.outputs.Timezone
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

resource trigger_RecommendationsDailySchedule 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: dailyRecommendationsTriggerName
  parent: dataFactory
  dependsOn: [
    stopTriggers
  ]
  properties: {
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipeline_ExecuteRecommendations.name
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
        frequency: 'Day'
        interval: 1
        startTime: '2023-01-01T21:30:00'
        timeZone: azuretimezones.outputs.Timezone
      }
    }
  }
}

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// config_BackfillData pipeline
//------------------------------------------------------------------------------
@description('Runs the backfill job for each month based on retention settings.')
resource pipeline_BackfillData 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeConfigContainerName}_BackfillData'
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
              folderPath: {
                value: '@variables(\'folderPath\')'
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
            dependencyConditions: ['Succeeded']
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
            dependencyConditions: ['Succeeded']
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
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'thisMonth'
          value: {
            value: '@startOfMonth(variables(\'endDate\'))'
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
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'nextMonth'
          value: {
            value: '@startOfMonth(subtractFromTime(variables(\'thisMonth\'), 1, \'Month\'))'
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
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set backfill end date'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@less(variables(\'thisMonth\'), variables(\'startDate\'))'
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
                    'Completed'
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
                    'Completed'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'nextMonth'
                value: {
                  value: '@subtractFromTime(variables(\'thisMonth\'), 1, \'Month\')'
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
                  referenceName: pipeline_RunBackfill.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  StartDate: {
                    value: '@variables(\'thisMonth\')'
                    type: 'Expression'
                  }
                  EndDate: {
                    value: '@addDays(addToTime(variables(\'thisMonth\'), 1, \'Month\'), -1)'
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
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
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
// config_RunBackfill pipeline
// Triggered by config_BackfillData pipeline
//------------------------------------------------------------------------------
@description('Creates and triggers exports for all defined scopes for the specified date range.')
resource pipeline_RunBackfill 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeConfigContainerName}_RunBackfill'
  parent: dataFactory
  properties: {
    activities: [
      {
        // Load config file to get scopes
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
              folderPath: {
                value: '@variables(\'folderPath\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        // Set Scopes
        name: 'Set Scopes'
        description: 'Save scopes to test if it is an array'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopesArray'
          value: {
            value: '@activity(\'Get Config\').output.firstRow.scopes'
            type: 'Expression'
          }
        }
      }
      {
        // Set scopes as array to work around PowerShell bug
        name: 'Set Scopes as Array'
        description: 'Wraps a single scope object into an array to work around the PowerShell bug where single-item arrays are sometimes written as a single object instead of an array.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Scopes'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopesArray'
          value: {
            value: '@createArray(activity(\'Get Config\').output.firstRow.scopes)'
            type: 'Expression'
          }
        }
      }
      {
        // Filter Invalid Scopes
        name: 'Filter Invalid Scopes'
        description: 'Remove any invalid scopes to avoid errors.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Filter Invalid Scopes'
            dependencyConditions: ['Completed']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'scopesArray\')'
            type: 'Expression'
          }
          condition: {
            value: '@and(not(empty(item().scope)), not(equals(item().scope, \'/\')))'
            type: 'Expression'
          }
        }
      }
      {
        // Loop thru scopes
        name: 'ForEach Export Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Filter Invalid Scopes'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Invalid Scopes\').output.Value'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              name: 'Set backfill export name'
              type: 'SetVariable'
              dependsOn: []
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'finOpsHub\'), \'-monthly-costdetails\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Trigger backfill export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set backfill export name'
                  dependencyConditions: [
                    'Completed'
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}/run?api-version=${exportApiVersion}'
                  type: 'Expression'
                }
                method: 'POST'
                headers: {
                  'x-ms-command-name': 'FinOpsToolkit.Hubs.config_RunBackfill@${ftkVersion}'
                  'Content-Type': 'application/json'
                  ClientType: 'FinOpsToolkit.Hubs@${ftkVersion}'
                }
                body: '{"timePeriod" : { "from" : "@{pipeline().parameters.StartDate}", "to" : "@{pipeline().parameters.EndDate}" }}'
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
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
      }
      scopesArray: {
        type: 'Array'
      }
    }
  }
}

//------------------------------------------------------------------------------
// config_ExportData pipeline
// Triggered by config_DailySchedule/MonthlySchedule triggers
//------------------------------------------------------------------------------
@description('Gets a list of all Cost Management exports configured for this hub based on the scopes defined in settings.json, then runs each export using the config_RunExports pipeline.')
resource pipeline_ExportData 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeConfigContainerName}_ExportData'
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
              folderPath: {
                value: '@variables(\'folderPath\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        // Set Scopes
        name: 'Set Scopes'
        description: 'Save scopes to test if it is an array'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopesArray'
          value: {
            value: '@activity(\'Get Config\').output.firstRow.scopes'
            type: 'Expression'
          }
        }
      }
      {
        // Set scopes as array to work around PowerShell bug
        name: 'Set Scopes as Array'
        description: 'Wraps a single scope object into an array to work around the PowerShell bug where single-item arrays are sometimes written as a single object instead of an array.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Scopes'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopesArray'
          value: {
            value: '@createArray(activity(\'Get Config\').output.firstRow.scopes)'
            type: 'Expression'
          }
        }
      }
      {
        // Filter Invalid Scopes
        name: 'Filter Invalid Scopes'
        description: 'Remove any invalid scopes to avoid errors.'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Filter Invalid Scopes'
            dependencyConditions: ['Completed']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'scopesArray\')'
            type: 'Expression'
          }
          condition: {
            value: '@and(not(empty(item().scope)), not(equals(item().scope, \'/\')))'
            type: 'Expression'
          }
        }
      }
      {
        // Loop thru scopes
        name: 'ForEach Export Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Scopes'
            dependencyConditions: ['Completed']
          }
          {
            activity: 'Set Scopes as Array'
            dependencyConditions: ['Succeeded', 'Skipped']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Filter Invalid Scopes\').output.Value'
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports?api-version=${exportApiVersion}'
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
                  dependencyConditions: ['Succeeded']
                }
              ]
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_RunExports.name
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
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
      }
      scopesArray: {
        type: 'Array'
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
// config_RunExports pipeline
// Triggered by pipeline_ExportData pipeline
//------------------------------------------------------------------------------
@description('Runs the specified Cost Management exports.')
resource pipeline_RunExports 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeConfigContainerName}_RunExports'
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
                  value: '@and(equals(toLower(item().properties.schedule.recurrence), toLower(pipeline().parameters.Recurrence)),startswith(toLower(item().name), toLower(variables(\'hubName\'))))'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Trigger export'
                    type: 'WebActivity'
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
                      url: {
                        value: '@{replace(toLower(concat(variables(\'resourceManagementUri\'),item().id)), \'com//\', \'com/\')}/run?api-version=${exportApiVersion}'
                        type: 'Expression'
                      }
                      method: 'POST'
                      headers: {
                        'x-ms-command-name': 'FinOpsToolkit.Hubs.config_RunExports@${ftkVersion}'
                        ClientType: 'FinOpsToolkit.Hubs@${ftkVersion}'
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
      hubName: {
        type: 'String'
        defaultValue: hubName
      }
    }
  }
}

//------------------------------------------------------------------------------
// config_ConfigureExports pipeline
// Triggered by config_SettingsUpdated trigger
//------------------------------------------------------------------------------
@description('Creates Cost Management exports for all scopes.')
resource pipeline_ConfigureExports 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeConfigContainerName}_ConfigureExports'
  parent: dataFactory
  properties: {
    activities: [
      {
        // 'Get Config'
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
              folderPath: {
                value: '@variables(\'folderPath\')'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        // 'ForEach Export Scope'
        name: 'ForEach Export Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Remove empty scopes'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Remove empty scopes\').output.value'
            type: 'Expression'
          }
          isSequential: true
          activities: [
            {
              // 'Create or update open month focus export'
              name: 'Create or update open month focus export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set open month focus export name'
                  dependencyConditions: ['Succeeded']
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
                  value: '@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=${exportApiVersion}'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: getExportBody(
                    exportContainerName,
                    'FocusCost',
                    focusSchemaVersion,
                    false,
                    'Parquet',
                    'Snappy',
                    'true',
                    'CreateNewReport'
                  )
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
              // 'Set open month focus export name'
              name: 'Set open month focus export name'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'finOpsHub\'), \'-daily-costdetails\'))'
                  type: 'Expression'
                }
              }
            }
            {
              // 'Create or update closed month focus export'
              name: 'Create or update closed month focus export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set closed month focus export name'
                  dependencyConditions: ['Succeeded']
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
                  value: '@{variables(\'ResourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=${exportApiVersion}'
                  type: 'Expression'
                }
                method: 'PUT'
                body: {
                  value: getExportBody(
                    exportContainerName,
                    'FocusCost',
                    focusSchemaVersion,
                    true,
                    'Parquet',
                    'Snappy',
                    'true',
                    'CreateNewReport'
                  )
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
              // 'Set closed month focus export name'
              name: 'Set closed month focus export name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Create or update open month focus export'
                  dependencyConditions: ['Succeeded']
                }
              ]
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@toLower(concat(variables(\'finOpsHub\'), \'-monthly-costdetails\'))'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      {
        // 'Save scopes as array'
        name: 'Save scopes as array'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Save scopes'
            dependencyConditions: ['Failed']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopes'
          value: {
            value: '@array(activity(\'Get Config\').output.firstRow.scopes)'
            type: 'Expression'
          }
        }
      }
      {
        // 'Save scopes'
        name: 'Save scopes'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scopes'
          value: {
            value: '@activity(\'Get Config\').output.firstRow.scopes'
            type: 'Expression'
          }
        }
      }
      {
        // 'Remove empty scopes'
        name: 'Remove empty scopes'
        type: 'Filter'
        dependsOn: [
          {
            activity: 'Save scopes as array'
            dependencyConditions: [
              'Succeeded'
              'Skipped'
            ]
          }
          {
            activity: 'Save scopes'
            dependencyConditions: ['Completed']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@variables(\'scopes\')'
            type: 'Expression'
          }
          condition: {
            value: '@greater(length(item().scope), 0)'
            type: 'Expression'
          }
        }
      }
    ]
    concurrency: 1
    variables: {
      scopes: {
        type: 'Array'
      }
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
      folderPath: {
        type: 'String'
        defaultValue: configContainerName
      }
    }
  }
}

//------------------------------------------------------------------------------
// msexports_ExecuteETL pipeline
// Triggered by msexports_FileAdded trigger
//------------------------------------------------------------------------------
@description('Queues the msexports_ETL_ingestion pipeline.')
resource pipeline_ExecuteETL 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_ExecuteETL'
  parent: dataFactory
  properties: {
    activities: [
      {
        // Wait
        name: 'Wait'
        type: 'Wait'
        dependsOn: []
        userProperties: []
        typeProperties: {
          waitTimeInSeconds: 60
        }
      }
      {
        // Read Manifest
        name: 'Read Manifest'
        description: 'Load the export manifest to determine the scope, dataset, and date range.'
        type: 'Lookup'
        dependsOn: [
          {
            activity: 'Wait'
            dependencyConditions: ['Completed']
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
            referenceName: dataset_manifest.name
            type: 'DatasetReference'
            parameters: {
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
              folderPath: {
                value: '@pipeline().parameters.folderPath'
                type: 'Expression'
              }
            }
          }
        }
      }
      {
        // Set Dataset Type
        name: 'Set Dataset Type'
        description: 'Save the dataset type from the export manifest.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Read Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'datasetType'
          value: {
            value: '@toLower(activity(\'Read Manifest\').output.firstRow.exportConfig.type)'
            type: 'Expression'
          }
        }
      }
      {
        // Set MCA Column
        name: 'Set MCA Column'
        description: 'Determines if the dataset schema has channel-specific columns and saves the column name that only exists in MCA to determine if it is an MCA dataset.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Dataset Type'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'mcaColumnToCheck'
          value: {
            value: '@if(contains(createArray(\'pricesheet\', \'reservationtransactions\'), variables(\'datasetType\')), \'BillingProfileId\', if(equals(variables(\'datasetType\'), \'reservationrecommendations\'), \'Net Savings\', null))'
            type: 'Expression'
          }
        }
      }
      {
        // Set Dataset Version
        name: 'Set Dataset Version'
        description: 'Save the dataset version from the export manifest.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Read Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'datasetVersion'
          value: {
            value: '@activity(\'Read Manifest\').output.firstRow.exportConfig.dataVersion'
            type: 'Expression'
          }
        }
      }
      {
        // Detect Channel
        name: 'Detect Channel'
        description: 'Determines what channel this dataset is from. Switch statement handles the different file types if the mcaColumnToCheck variable is set.'
        type: 'Switch'
        dependsOn: [
          {
            activity: 'Set MCA Column'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Dataset Version'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          on: {
            value: '@if(empty(variables(\'mcaColumnToCheck\')), \'ignore\', last(array(split(replace(activity(\'Read Manifest\').output.firstRow.blobs[0].blobName, \'.csv.gz\', \'.csv\'), \'.\'))))'
            type: 'Expression'
          }
          cases: [
            {
              value: 'csv'
              activities: [
                {
                  name: 'Check for MCA Column in CSV'
                  description: 'Checks the dataset to determine if the applicable MCA-specific column exists.'
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
                      type: 'DelimitedTextSource'
                      storeSettings: {
                        type: 'AzureBlobFSReadSettings'
                        recursive: false
                        enablePartitionDiscovery: false
                      }
                      formatSettings: {
                        type: 'DelimitedTextReadSettings'
                      }
                    }
                    dataset: {
                      referenceName: 'msexports'
                      type: 'DatasetReference'
                      parameters: {
                        blobPath: {
                          value: '@activity(\'Read Manifest\').output.firstRow.blobs[0].blobName'
                          type: 'Expression'
                        }
                      }
                    }
                  }
                }
                {
                  name: 'Set Schema File with Channel in CSV'
                  type: 'SetVariable'
                  dependsOn: [
                    {
                      activity: 'Check for MCA Column in CSV'
                      dependencyConditions: [
                        'Succeeded'
                      ]
                    }
                  ]
                  policy: {
                    secureOutput: false
                    secureInput: false
                  }
                  userProperties: []
                  typeProperties: {
                    variableName: 'schemaFile'
                    value: {
                      value: '@toLower(concat(variables(\'datasetType\'), \'_\', variables(\'datasetVersion\'), if(contains(activity(\'Check for MCA Column in CSV\').output.firstRow, variables(\'mcaColumnToCheck\')), \'_mca\', \'_ea\'), \'.json\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
            {
              value: 'parquet'
              activities: [
                {
                  name: 'Check for MCA Column in Parquet'
                  description: 'Checks the dataset to determine if the applicable MCA-specific column exists.'
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
                      referenceName: 'msexports_parquet'
                      type: 'DatasetReference'
                      parameters: {
                        blobPath: {
                          value: '@activity(\'Read Manifest\').output.firstRow.blobs[0].blobName'
                          type: 'Expression'
                        }
                      }
                    }
                  }
                }
                {
                  name: 'Set Schema File with Channel for Parquet'
                  type: 'SetVariable'
                  dependsOn: [
                    {
                      activity: 'Check for MCA Column in Parquet'
                      dependencyConditions: ['Succeeded']
                    }
                  ]
                  policy: {
                    secureOutput: false
                    secureInput: false
                  }
                  userProperties: []
                  typeProperties: {
                    variableName: 'schemaFile'
                    value: {
                      value: '@toLower(concat(variables(\'datasetType\'), \'_\', variables(\'datasetVersion\'), if(contains(activity(\'Check for MCA Column in Parquet\').output.firstRow, variables(\'mcaColumnToCheck\')), \'_mca\', \'_ea\'), \'.json\'))'
                      type: 'Expression'
                    }
                  }
                }
              ]
            }
          ]
          defaultActivities: [
            {
              name: 'Set Schema File'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'schemaFile'
                value: {
                  value: '@toLower(concat(variables(\'datasetType\'), \'_\', variables(\'datasetVersion\'), \'.json\'))'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      {
        // Set Scope
        name: 'Set Scope'
        description: 'Save the scope from the export manifest.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Read Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'scope'
          value: {
            value: '@split(toLower(activity(\'Read Manifest\').output.firstRow.exportConfig.resourceId), \'/providers/microsoft.costmanagement/exports/\')[0]'
            type: 'Expression'
          }
        }
      }
      {
        // Set Date
        name: 'Set Date'
        description: 'Save the exported month from the export manifest.'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Read Manifest'
            dependencyConditions: ['Succeeded']
          }
        ]
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'date'
          value: {
            value: '@replace(substring(activity(\'Read Manifest\').output.firstRow.runInfo.startDate, 0, 7), \'-\', \'\')'
            type: 'Expression'
          }
        }
      }
      {
        // Error: ManifestReadFailed
        name: 'Failed to Read Manifest'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Set Date'
            dependencyConditions: ['Failed']
          }
          {
            activity: 'Set Dataset Type'
            dependencyConditions: ['Failed']
          }
          {
            activity: 'Set Scope'
            dependencyConditions: ['Failed']
          }
          {
            activity: 'Read Manifest'
            dependencyConditions: ['Failed']
          }
          {
            activity: 'Set Dataset Version'
            dependencyConditions: ['Failed']
          }
          {
            activity: 'Detect Channel'
            dependencyConditions: ['Failed']
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@concat(\'Failed to read the manifest file for this export run. Manifest path: \', pipeline().parameters.folderPath)'
            type: 'Expression'
          }
          errorCode: 'ManifestReadFailed'
        }
      }
      {
        // Check Schema
        name: 'Check Schema'
        description: 'Verify that the schema file exists in storage.'
        type: 'GetMetadata'
        dependsOn: [
          {
            activity: 'Set Scope'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Date'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Detect Channel'
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
            referenceName: dataset_config.name
            type: 'DatasetReference'
            parameters: {
              fileName: {
                value: '@variables(\'schemaFile\')'
                type: 'Expression'
              }
              folderPath: '${configContainerName}/schemas'
            }
          }
          fieldList: ['exists']
          storeSettings: {
            type: 'AzureBlobFSReadSettings'
            recursive: true
            enablePartitionDiscovery: false
          }
          formatSettings: {
            type: 'JsonReadSettings'
          }
        }
      }
      {
        // Error: SchemaNotFound
        name: 'Schema Not Found'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Check Schema'
            dependencyConditions: ['Failed']
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@concat(\'The \', variables(\'schemaFile\'), \' schema mapping file was not found. Please confirm version \', variables(\'datasetVersion\'), \' of the \', variables(\'datasetType\'), \' dataset is supported by this version of FinOps hubs. You may need to upgrade to a newer release. To add support for another dataset, you can create a custom mapping file.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaNotFound'
        }
      }
      {
        // For Each Blob
        name: 'For Each Blob'
        description: 'Loop thru each exported file listed in the manifest.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Check Schema'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Read Manifest\').output.firstRow.blobs'
            type: 'Expression'
          }
          isSequential: false
          activities: [
            {
              // Execute
              name: 'Execute'
              description: 'Run the ETL pipeline.'
              type: 'ExecutePipeline'
              dependsOn: []
              policy: {
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                pipeline: {
                  referenceName: pipeline_ToIngestion.name
                  type: 'PipelineReference'
                }
                waitOnCompletion: true
                parameters: {
                  blobPath: {
                    value: '@item().blobName'
                    type: 'Expression'
                  }
                  destinationFolder: {
                    value: '@toLower(replace(concat(variables(\'datasetType\'),\'/\',substring(variables(\'date\'), 0, 4),\'/\',substring(variables(\'date\'), 4, 2),\'/\',variables(\'scope\')),\'//\',\'/\'))'
                    type: 'Expression'
                  }
                  destinationFile: {
                    value: '@concat(activity(\'Read Manifest\').output.firstRow.runInfo.runId, \'_\', last(array(split(replace(replace(item().blobName, \'.gz\', \'\'), \'.csv\', \'.parquet\'), \'/\'))))'
                    type: 'Expression'
                  }
                  keepFilePrefix: {
                    value: '@concat(activity(\'Read Manifest\').output.firstRow.runInfo.runId, \'_\')'
                    type: 'Expression'
                  }
                  schemaFile: {
                    value: '@variables(\'schemaFile\')'
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
      folderPath: {
        type: 'string'
      }
      fileName: {
        type: 'string'
      }
    }
    variables: {
      datasetType: {
        type: 'String'
      }
      datasetVersion: {
        type: 'String'
      }
      date: {
        type: 'String'
      }
      mcaColumnToCheck: {
        type: 'String'
      }
      schemaFile: {
        type: 'String'
      }
      scope: {
        type: 'String'
      }
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
// msexports_ETL_ingestion pipeline
// Triggered by msexports_ExecuteETL
//------------------------------------------------------------------------------
@description('Transforms CSV data to a standard schema and converts to Parquet.')
resource pipeline_ToIngestion 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_ETL_${safeIngestionContainerName}'
  parent: dataFactory
  properties: {
    activities: [
      {
        // Load Schema Mappings
        name: 'Load Schema Mappings'
        description: 'Get schema mapping file to use for the CSV to parquet conversion.'
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
                value: '@toLower(pipeline().parameters.schemaFile)'
                type: 'Expression'
              }
              folderPath: '${configContainerName}/schemas'
            }
          }
        }
      }
      {
        // Error: SchemaLoadFailed
        name: 'Failed to Load Schema'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Failed']
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@concat(\'Unable to load the \', pipeline().parameters.schemaFile, \' schema file. Please confirm the schema and version are supported for FinOps hubs ingestion. Unsupported files will remain in the msexports container.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaLoadFailed'
        }
      }
      {
        // Get Existing Parquet Files
        name: 'Get Existing Parquet Files'
        description: 'Get the previously ingested files so we can remove any older data. This is necessary to avoid data duplication in reports.'
        type: 'GetMetadata'
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
            referenceName: 'ingestion_files'
            type: 'DatasetReference'
            parameters: {
              folderPath: '@pipeline().parameters.destinationFolder'
            }
          }
          fieldList: [
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
      {
        // Filter Out Current Exports
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
            value: '@and(endswith(item().name, \'.parquet\'), not(startswith(item().name, pipeline().parameters.keepFilePrefix)))'
            type: 'Expression'
          }
        }
      }
      {
        // For Each Old File
        name: 'For Each Old File'
        description: 'Loop thru each of the existing files from previous exports.'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Succeeded']
          }
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
              // Delete Old Ingested File
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
                      value: '@item()'
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
        // Read Hub Config
        name: 'Read Hub Config'
        description: 'Read the hub config to determine if the export should be retained.'
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
              recursive: false
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
              folderPath: configContainerName
            }
          }
        }
      }
      {
        // If Not Retaining Exports
        name: 'If Not Retaining Exports'
        description: 'If the msexports retention period <= 0, delete the source file. The main reason to keep the source file is to allow for troubleshooting and reprocessing in the future.'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Convert to Parquet'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Read Hub Config'
            dependencyConditions: ['Completed']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@lessOrEquals(coalesce(activity(\'Read Hub Config\').output.firstRow.retention.msexports.days, 0), 0)'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              // Delete Source File
              name: 'Delete Source File'
              description: 'Delete the exported data file to keep storage costs down. This file is not referenced by any reporting systems.'
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
                  referenceName: dataset_msexports_parquet.name
                  type: 'DatasetReference'
                  parameters: {
                    blobPath: {
                      value: '@pipeline().parameters.blobPath'
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
      {
        // Convert to Parquet
        name: 'Convert to Parquet'
        description: 'Convert CSV to parquet and move the file to the ${ingestionContainerName} container.'
        type: 'Switch'
        dependsOn: [
          {
            activity: 'For Each Old File'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          on: {
            value: '@last(array(split(replace(pipeline().parameters.blobPath, \'.csv.gz\', \'.csv_gz\'), \'.\')))'
            type: 'Expression'
          }
          cases: [
            {
              value: 'csv'
              activities: [
                {
                  name: 'Convert CSV File'
                  type: 'Copy'
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
                      type: 'DelimitedTextSource'
                      additionalColumns: {
                        type: 'Expression'
                        value: '@activity(\'Load Schema Mappings\').output.firstRow.additionalColumns'
                      }
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
                      type: 'ParquetSink'
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
                    translator: {
                      value: '@activity(\'Load Schema Mappings\').output.firstRow.translator'
                      type: 'Expression'
                    }
                  }
                  inputs: [
                    {
                      referenceName: dataset_msexports.name
                      type: 'DatasetReference'
                      parameters: {
                        blobPath: {
                          value: '@pipeline().parameters.blobPath'
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
                        blobPath: {
                          value: '@concat(pipeline().parameters.destinationFolder, \'/\', pipeline().parameters.destinationFile)'
                          type: 'Expression'
                        }
                      }
                    }
                  ]
                }
              ]
            }
            {
              value: 'parquet'
              activities: [
                {
                  name: 'Move Parquet File'
                  type: 'Copy'
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
                      type: 'ParquetSource'
                      storeSettings: {
                        type: 'AzureBlobFSReadSettings'
                        recursive: true
                        enablePartitionDiscovery: false
                      }
                      formatSettings: {
                        type: 'ParquetReadSettings'
                      }
                    }
                    sink: {
                      type: 'ParquetSink'
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
                      referenceName: dataset_msexports_parquet.name
                      type: 'DatasetReference'
                      parameters: {
                        blobPath: {
                          value: '@pipeline().parameters.blobPath'
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
                        blobPath: {
                          value: '@concat(pipeline().parameters.destinationFolder, \'/\', pipeline().parameters.destinationFile)'
                          type: 'Expression'
                        }
                      }
                    }
                  ]
                }
              ]
            }
          ]
          defaultActivities: [
            {
              name: 'Unsupported File Type'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: '@concat(\'Unable to ingest the specified export file because the file type is not supported. File: \', pipeline().parameters.blobPath)'
                  type: 'Expression'
                }
                errorCode: 'UnsupportedExportFileType'
              }
            }
          ]
        }
      }
    ]
    parameters: {
      blobPath: {
        type: 'String'
      }
      destinationFolder: {
        type: 'string'
      }
      destinationFile: {
        type: 'string'
      }
      keepFilePrefix: {
        type: 'string'
      }
      schemaFile: {
        type: 'string'
      }
    }
    variables: {
      destinationFile: {
        type: 'String'
      }
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
// recommendations export pipeline
// Triggered by dailyRecommendations trigger
//------------------------------------------------------------------------------
@description('Extracts Azure Advisor and custom recommendations from the Resource Graph API.')
resource pipeline_ExecuteRecommendations 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${recommendationsDataSet}_Execute'
  parent: dataFactory
  properties: {
    activities: [
      { // Set blob timestamp
        name: 'set_BlobExportTimestamp'
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
      { // Set schema filename        
        name: 'Set Schema Filename'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'schemaFile'
          value: 'recommendations_1.0.json'
        }
      }
      { // Set error counter
        name: 'Set Error Counter'
        type: 'SetVariable'
        dependsOn: []
        policy: {
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          variableName: 'pipelineFailed'
          value: {
            value: '@bool(false)'
            type: 'Expression'
          }
        }
      }
      { // Load Schema Mappings
        name: 'Load Schema Mappings'
        type: 'Lookup'
        dependsOn: [
          {
            activity: 'Set Schema Filename'
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
                value: '@variables(\'schemaFile\')'
                type: 'Expression'
              }
              folderPath: '${configContainerName}/schemas'
            }
          }
        }
      }
      { // Error: SchemaLoadFailed
        name: 'Failed to Load Schema'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Failed']
          }
        ]
        userProperties: []
        typeProperties: {
          message: {
            value: '@concat(\'Unable to load the \', variables(\'schemaFile\'), \' recommendations schema file. Please confirm the schema and version are supported for FinOps hubs ingestion. Unsupported files will remain in the ingestion container.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaLoadFailed'
        }
      }
      { // Get Advisor recommendations from ARG
        name: 'Export Advisor Cost Recommendations'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Set Blob Timestamp'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Load Schema Mappings'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Error Counter'
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{\n  "query": "advisorresources \n| where type == \'microsoft.advisor/recommendations\' \n| where properties.category == \'Cost\' \n| project \n    x_RecommendationId=id, \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=tostring(properties.category), \n    x_RecommendationProvider=\'Microsoft.Advisor\', \n    x_RecommendationImpact=tostring(properties.impact), \n    x_RecommendationTypeId= tostring(properties.recommendationTypeId), \n    x_RecommendationControl=tostring(properties.extendedProperties.recommendationControl), \n    x_RecommendationMaturityLevel=tostring(properties.extendedProperties.maturityLevel), \n    x_RecommendationDescription=tostring(properties.shortDescription.problem), \n    x_RecommendationSolution=tostring(properties.shortDescription.solution), \n    ResourceId=tolower(properties.resourceMetadata.resourceId), \n    x_ResourceType=tolower(properties.impactedField), \n    ResourceName=tolower(properties.impactedValue), \n    x_RecommendationDetails=tostring(properties.extendedProperties), \n    x_RecommendationDate=tostring(properties.lastUpdated) \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1" \n}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
            }
          }
          sink: {
            type: 'ParquetSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'ParquetWriteSettings'
              fileExtension: '.parquet'
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
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-advisor.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Advisor recommendations
        name: 'Catch Advisor Cost Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Advisor Cost Recommendations'
            dependencyConditions: ['Failed']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Advisor Cost Recommendations\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Advisor Cost Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Unattached Disks       
        name: 'Export Unattached Disks'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Advisor Cost Recommendations'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources \n| where type =~ \'microsoft.compute/disks\' and isempty(managedBy) \n| extend diskState = tostring(properties.diskState) \n| where diskState != \'ActiveSAS\' and tags !contains \'ASR-ReplicaDisk\' and tags !contains \'asrseeddisk\' \n| extend DiskId=id, DiskIDfull=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated), SubId=subscriptionId | order by DiskId asc | project DiskId, DiskIDfull, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId, type\n| project \n    x_RecommendationId=strcat(tolower(DiskId),\'-unattached\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'High\', \n    x_RecommendationTypeId=\'e0c02939-ce02-4f9d-881f-8067ae7ec90f\', \n    x_RecommendationControl=\'UsageOptimization/OrphanedResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Unattached (orphaned) disk is incurring in storage costs\', \n    x_RecommendationSolution=\'Remove or downgrade the unattached disk\', \n    ResourceId = tolower(DiskId), \n    x_ResourceType=type, \n    ResourceName=tolower(DiskName), \n    x_RecommendationDetails= strcat(\'{\\"DiskSizeGB\\": \', DiskSizeGB, \', \\"SKUName\\": \\"\', SKUName, \'\\", \\"SKUTier\\": \\"\', SKUTier, \'\\", \\"Location\\": \\"\', Location, \'\\", \\"TimeCreated\\": \\"\', TimeCreated, \'\\" }\'), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
            }
          }
          sink: {
            type: 'ParquetSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
            }
            formatSettings: {
              type: 'ParquetWriteSettings'
              fileExtension: '.parquet'
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
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-storage-unattacheddisks.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Unattached Disks
        name: 'Catch Unattached Disks Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Unattached Disks'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Unattached Disks\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Unattached Disks Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Non-Spot AKS Pools
        name: 'Export Non-Spot AKS Pools'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Unattached Disks'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources \n| where type == \'microsoft.containerservice/managedclusters\' \n| mvexpand AgentPoolProfiles = properties.agentPoolProfiles\n| project id, type, ProfileName = tostring(AgentPoolProfiles.name), Sku = tostring(sku.name), Tier = tostring(sku.tier), mode = AgentPoolProfiles.mode, AutoScaleEnabled = AgentPoolProfiles.enableAutoScaling, SpotVM = AgentPoolProfiles.scaleSetPriority, VMSize = tostring(AgentPoolProfiles.vmSize), NodeCount = tostring(AgentPoolProfiles.[\'count\']), minCount = tostring(AgentPoolProfiles.minCount), maxCount = tostring(AgentPoolProfiles.maxCount), Location=location, resourceGroup, subscriptionId, AKSname = name\n| where AutoScaleEnabled == \'true\' and isnull(SpotVM)\n| project \n    x_RecommendationId=strcat(tolower(id),\'-notSpot\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'Medium\', \n    x_RecommendationTypeId=\'c26abcc2-d5e6-4654-be4a-7d338e5c1e5f\', \n    x_RecommendationControl=\'UsageOptimization/OptimizeResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'The AKS cluster agent pool scale set is not utilizing Spot VMs\', \n    x_RecommendationSolution=\'Consider enabling Spot VMs for this AKS cluster to optimize costs, as Spot VMs offer significantly lower pricing compared to regular VMs\', \n    ResourceId = tolower(id), \n    x_ResourceType=type, \n    ResourceName=tolower(AKSname), \n    x_RecommendationDetails= strcat(\'{\\"AutoScaleEnabled\\": \', AutoScaleEnabled, \', \\"SpotVM\\": \\"\', SpotVM, \'\\", \\"VMSize\\": \\"\', VMSize, \'\\", \\"Location\\": \\"\', Location, \'\\", \\"NodeCount\\": \\"\', NodeCount, \'\\", \\"minCount\\": \\"\', minCount, \'\\", \\"maxCount\\": \\"\', maxCount, \'\\" }\'), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-compute-aksnonspot.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Non-Spot AKS Pools
        name: 'Catch Non-Spot AKS Pools Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Non-Spot AKS Pools'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Non-Spot AKS Pools\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Non-Spot AKS Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Non-Deallocated VMs
        name: 'Export Non-Deallocated VMs'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Non-Spot AKS Pools'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources\n| where type =~ \'microsoft.compute/virtualmachines\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM deallocated\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM running\' \n| extend PowerState=tostring(properties.extended.instanceView.powerState.displayStatus) \n| extend Location=location, type\n| project id, PowerState, Location, resourceGroup, subscriptionId, VMName=name, type\n| project \n    x_RecommendationId=strcat(tolower(id),\'-notDeallocated\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'Medium\', \n    x_RecommendationTypeId=\'ab2ff882-e927-4093-9d11-631be0219975\', \n    x_RecommendationControl=\'UsageOptimization/OptimizeResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Virtual machine is powered off but not deallocated\', \n    x_RecommendationSolution=\'Deallocate the virtual machine to ensure it does not incur in compute costs\', \n    ResourceId = tolower(id), \n    x_ResourceType=type, \n    ResourceName=tolower(VMName), \n    x_RecommendationDetails= strcat(\'{\\"PowerState\\": \', PowerState, \',\\"Location\\": \\"\', Location),\n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-compute-vmsnotdeallocated.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Non-Deallocated VMs
        name: 'Catch Non-Deallocated VMs Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Non-Deallocated VMs'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Non-Deallocated VMs\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Non-Deallocated VMs Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get AppGWs Without Backend
        name: 'Export AppGWs Without Backend'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Non-Deallocated VMs'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources\n| where type =~ \'Microsoft.Network/applicationGateways\' \n| extend backendPoolsCount = array_length(properties.backendAddressPools),SKUName= tostring(properties.sku.name), SKUTier= tostring(properties.sku.tier),SKUCapacity=properties.sku.capacity,backendPools=properties.backendAddressPools,resourceGroup=strcat(\'/subscriptions/\',subscriptionId,\'/resourceGroups/\',resourceGroup)\n| project id, name, SKUName, SKUTier, SKUCapacity,resourceGroup,subscriptionId, AppGWName=name, type, Location=location\n| join (\n    resources\n    | where type =~ \'Microsoft.Network/applicationGateways\'\n    | mvexpand backendPools = properties.backendAddressPools\n    | extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)\n    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)\n    | extend backendPoolName  = backendPools.properties.backendAddressPools.name\n    | summarize backendIPCount = sum(backendIPCount) ,backendAddressesCount=sum(backendAddressesCount) by id\n) on id\n| project-away id1\n| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))\n| project \n    x_RecommendationId=strcat(tolower(id),\'-idle\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'High\', \n    x_RecommendationTypeId=\'4f69df93-5972-44e0-97cf-4343c2bcf4b8\', \n    x_RecommendationControl=\'UsageOptimization/OrphanedResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Application Gateway without any backend pool\', \n    x_RecommendationSolution=\'Review and remove this resource if not needed\', \n    ResourceId = tolower(id), \n    x_ResourceType=type, \n    ResourceName=tolower(AppGWName), \n    x_RecommendationDetails= strcat(\'{\\"backendIPCount\\": \', backendIPCount, \',\\"Location\\": \\"\', Location), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-network-appgwnobackend.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get AppGWs Without Backend
        name: 'Catch AppGWs Without Backend Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export AppGWs Without Backend'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export AppGWs Without Backend\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Idle AppGWs Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get LBs Without Backend
        name: 'Export LBs Without Backend'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export AppGWs Without Backend'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources\n| extend SKUName=tostring(sku.name) \n| extend SKUTier=tostring(sku.tier), Location=location \n| extend backendAddressPools = properties.backendAddressPools\n| where type =~ \'microsoft.network/loadbalancers\' and array_length(backendAddressPools) == 0 and sku.name!=\'Basic\' \n| extend id,name, SKUName,SKUTier,backendAddressPools, location,resourceGroup, subscriptionId, type\n| project \n    x_RecommendationId=strcat(tolower(id),\'-idle\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'High\', \n    x_RecommendationTypeId=\'ab703887-fa23-4915-abdc-3defbea89f7a\', \n    x_RecommendationControl=\'UsageOptimization/OrphanedResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Load balancer without a backend pool\', \n    x_RecommendationSolution=\'Review and remove this resource if not needed\', \n    ResourceId = tolower(id), \n    x_ResourceType=type, \n    ResourceName=tolower(name), \n    x_RecommendationDetails= strcat(\'{\\"SKUName\\": \', SKUName, \',\\"SKUTier\\": \\"\', SKUTier, \',\\"Location\\": \\"\', Location), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-network-lbnobackend.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get LBs Without Backend
        name: 'Catch LBs Without Backend Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export LBs Without Backend'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export LBs Without Backend\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Idle LBs Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Unattached Public IPs
        name: 'Export Unattached Public IPs'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export LBs Without Backend'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources \n| where type =~ \'Microsoft.Network/publicIPAddresses\' and isempty(properties.ipConfiguration) and isempty(properties.natGateway) and properties.publicIPAllocationMethod =~ \'Static\' \n| extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location \n| project PublicIpId, IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, type, name \n| union ( resources | where type =~ \'microsoft.network/networkinterfaces\' and isempty(properties.virtualMachine) and isnull(properties.privateEndpoint) and isnotempty(properties.ipConfigurations) \n| extend IPconfig = properties.ipConfigurations | mv-expand IPconfig | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id) \n| project PublicIpId, name | join ( resources | where type =~ \'Microsoft.Network/publicIPAddresses\'\n| extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, resourceGroup, Location=location, name, id ) on PublicIpId \n| extend PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod,name, subscriptionId )\n| project \n    x_RecommendationId=strcat(tolower(PublicIpId),\'-idle\'), \n    x_ResourceGroupName=tolower(resourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'Low\', \n    x_RecommendationTypeId=\'3ecbf770-9404-4504-a450-cc198e8b2a7d\', \n    x_RecommendationControl=\'UsageOptimization/OrphanedResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Unattached (orphaned) public IP is incurring in networking costs\', \n    x_RecommendationSolution=\'Review and remove this resource if not needed\', \n    ResourceId = tolower(PublicIpId), \n    x_ResourceType=type, \n    ResourceName=tolower(name), \n    x_RecommendationDetails= strcat(\'{\\"SKUName\\": \', SKUName, \',\\"AllocationMethod\\": \\"\', AllocationMethod,\',\\"Location\\": \\"\', Location), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-network-pipunattached.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Unattached Public IPs
        name: 'Catch Unattached Public IPs Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Unattached Public IPs'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Unattached Public IPs\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Orphan PIPs Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Empty SQL Elastic Pools
        name: 'Export Empty SQL Elastic Pools'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Unattached Public IPs'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resources \n| where type == \'microsoft.sql/servers/elasticpools\'\n| extend elasticPoolId = tolower(tostring(id)), elasticPoolName = name, elasticPoolRG = resourceGroup,skuName=tostring(sku.name),skuTier=tostring(sku.tier),skuCapacity=tostring(sku.capacity), Location=location, type\n| join kind=leftouter ( resources | where type == \'microsoft.sql/servers/databases\'\n| extend elasticPoolId = tolower(tostring(properties.elasticPoolId)) ) on elasticPoolId\n| summarize databaseCount = countif(isnotempty(elasticPoolId1)) by elasticPoolId, elasticPoolName,serverResourceGroup=resourceGroup,name,skuName,skuTier,skuCapacity,elasticPoolRG,Location, type, subscriptionId\n| where databaseCount == 0 \n| project elasticPoolId, elasticPoolName, databaseCount, elasticPoolRG ,skuName,skuTier ,skuCapacity, Location, type, subscriptionId\n| project \n    x_RecommendationId=strcat(tolower(elasticPoolId),\'-idle\'), \n    x_ResourceGroupName=tolower(elasticPoolRG), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'High\', \n    x_RecommendationTypeId=\'50987aae-a46d-49ae-bd41-a670a4dd18bd\', \n    x_RecommendationControl=\'UsageOptimization/OrphanedResources\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'SQL Database elastic pool has no associated databases\', \n    x_RecommendationSolution=\'Review and remove this resource if not needed\', \n    ResourceId = tolower(elasticPoolId), \n    x_ResourceType=type, \n    ResourceName=tolower(elasticPoolName), \n    x_RecommendationDetails= strcat(\'{\\"skuName\\": \', skuName, \',\\"skuTier\\": \\"\', skuTier,\',\\"skuCapacity\\": \\"\', skuCapacity,\',\\"Location\\": \\"\', Location), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-database-emptyelasticpool.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Empty SQL Elastic Pools
        name: 'Catch Empty SQL Elastic Pools Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Empty SQL Elastic Pools'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Empty SQL Elastic Pools\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Empty SQL Elastic Pools Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get Windows Without AHB
        name: 'Export Windows Without AHB'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Empty SQL Elastic Pools'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resourcecontainers \n| where type =~ \'Microsoft.Resources/subscriptions\' \n| where tostring (properties.subscriptionPolicies.quotaId) !has \'MSDNDevTest_2014-09-01\' \n| extend SubscriptionName=name \n| join (\n    resources \n    | where type =~ \'microsoft.compute/virtualmachines\' or type =~ \'microsoft.compute/virtualMachineScaleSets\'\n    | where tostring(properties.storageProfile.imageReference.publisher ) == \'MicrosoftWindowsServer\' or tostring(properties.virtualMachineProfile.storageProfile.osDisk.osType) == \'Windows\' or tostring(properties.storageProfile.imageReference.publisher ) == \'microsoftsqlserver\'\n    | where tostring(properties.[\'licenseType\']) !has \'Windows\' and tostring(properties.virtualMachineProfile.[\'licenseType\']) == \'Windows_Server\'\n    | extend WindowsId=id, VMSku=tostring(properties.hardwareProfile.vmSize), vmResourceGroup=resourceGroup, vmType=type, Location=location,LicenseType = tostring(properties.[\'licenseType\'])\n    | extend ActualCores = toint(extract(\'.[A-Z]([0-9]+)\', 1, tostring(properties.hardwareProfile.vmSize)))\n    | extend CheckAHBWindows = case(\n        type == \'microsoft.compute/virtualmachines\' or type =~ \'microsoft.compute/virtualMachineScaleSets\', iif((properties.[\'licenseType\'])\n        !has \'Windows\' and (properties.virtualMachineProfile.[\'licenseType\']) !has \'Windows\' , \'AHB-disabled\', \'AHB-enabled\'),\n        \'Not Windows\'\n    )\n) on subscriptionId \n| project \n    x_RecommendationId=strcat(tolower(WindowsId),\'-CheckAHBWindows\'), \n    x_ResourceGroupName=tolower(vmResourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'Medium\', \n    x_RecommendationTypeId=\'f326c065-b9f7-4a0e-a0f1-5a1c060bc25d\', \n    x_RecommendationControl=\'RateOptimization/Licensing\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'Windows virtual machine is not leveraging Azure Hybrid Benefit\', \n    x_RecommendationSolution=\'Review the virtual machine licensing option\', \n    ResourceId = tolower(WindowsId), \n    x_ResourceType=vmType, \n    ResourceName=tolower(split(WindowsId,\'/\')[-1]), \n    x_RecommendationDetails= strcat(\'{\\"VMSku\\": \', VMSku, \',\\"CheckAHBWindows\\": \\"\', CheckAHBWindows,\',\\"ActualCores\\": \\"\', ActualCores,\',\\"Location\\": \\"\', Location), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-compute-windowsnoahb.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get Windows Without AHB
        name: 'Catch Windows Without AHB Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export Windows Without AHB'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export Windows Without AHB\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set Windows No AHB Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Get SQL VMs Without AHB
        name: 'Export SQL VMs Without AHB'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'Export Windows Without AHB'
            dependencyConditions: [
              'Completed'
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
            requestMethod: 'POST'
            requestBody: '{\n  "query": "resourcecontainers \n| where type =~ \'Microsoft.Resources/subscriptions\' \n| where tostring (properties.subscriptionPolicies.quotaId) !has \'MSDNDevTest_2014-09-01\' \n| extend SubscriptionName=name \n| join (\n     resources | where type =~ \'Microsoft.SqlVirtualMachine/SqlVirtualMachines\' and tostring(properties.[\'sqlServerLicenseType\']) != \'AHUB\' \n    | extend SQLID=id, VMName = name, resourceGroup, Location = location, LicenseType = tostring(properties.[\'sqlServerLicenseType\']), OSType=tostring(properties.storageProfile.imageReference.offer), SQLAgentType = tostring(properties.[\'sqlManagement\']), SQLVersion = tostring(properties.[\'sqlImageOffer\']), SQLSKU=tostring(properties.[\'sqlImageSku\'])\n) on subscriptionId \n| join (\n    resources\n    | where type =~ \'Microsoft.Compute/virtualmachines\'\n    | extend ActualCores = toint(extract(\'.[A-Z]([0-9]+)\', 1, tostring(properties.hardwareProfile.vmSize)))\n    | project VMName = tolower(name), VMSize = tostring(properties.hardwareProfile.vmSize),ActualCores, subscriptionId, vmType=type, vmResourceGroup=resourceGroup\n) on VMName\n| order by id asc    \n| where SQLSKU != \'Developer\' and SQLSKU != \'Express\'\n| extend CheckAHBSQLVM= case(\n    type == \'Microsoft.SqlVirtualMachine/SqlVirtualMachines\', iif((properties.[\'sqlServerLicenseType\']) != \'AHUB\', \'AHB-disabled\', \'AHB-enabled\'),\n    \'Not Windows\'\n)\n| project SQLID,VMName,resourceGroup, Location, VMSize, SQLVersion, SQLSKU, SQLAgentType, LicenseType, SubscriptionName,type,CheckAHBSQLVM, subscriptionId,ActualCores, vmType, vmResourceGroup\n| project \n    x_RecommendationId=strcat(tolower(SQLID),\'-CheckAHBSQLVM\'), \n    x_ResourceGroupName=tolower(vmResourceGroup), \n    SubAccountId=subscriptionId, \n    x_RecommendationCategory=\'Cost\', \n    x_RecommendationProvider=\'Microsoft.FinOpsToolkit\', \n    x_RecommendationImpact=\'High\', \n    x_RecommendationTypeId=\'01decd62-f91b-4434-abe5-9a09e13e018f\', \n    x_RecommendationControl=\'RateOptimization/Licensing\', \n    x_RecommendationMaturityLevel=\'Preview\', \n    x_RecommendationDescription=\'SQL virtual machine is not leveraging Azure Hybrid Benefit\', \n    x_RecommendationSolution=\'Review the SQL licensing option\', \n    ResourceId = tolower(SQLID), \n    x_ResourceType=vmType, \n    ResourceName=tolower(VMName), \n    x_RecommendationDetails= strcat(\'{\\"VMSize\\": \\"\', VMSize, \'\\", \\"CheckAHBSQLVM\\": \\"\', CheckAHBSQLVM, \'\\", \\"ActualCores\\": \\"\', ActualCores, \'\\", \\"SQLVersion\\": \\"\', SQLVersion, \'\\", \\"SQLSKU\\": \\"\', SQLSKU, \'\\", \\"SQLAgentType\\": \\"\', SQLAgentType, \'\\", \\"LicenseType\\": \\"\', LicenseType, \'\\", \\"Location\\": \\"\', Location, \'\\"}\'), \n    x_RecommendationDate = now() \n| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project SubAccountName=name, SubAccountId=subscriptionId ) on SubAccountId \n| project-away SubAccountId1"\n}'
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
              fileExtension: '.parquet'
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
            referenceName: 'resourcegraph'
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: 'ingestion'
            type: 'DatasetReference'
            parameters: {
              blobPath: {
                value: '@concat(\'${recommendationsDataSet}/\', variables(\'blobExportTimestamp\'), \'${recommendationsScope}/\', \'cost-custom-database-sqlnoahb.parquet\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Error: Get SQL VMs Without AHB
        name: 'Catch SQL VMs Without AHB Failure'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export SQL VMs Without AHB'
            dependencyConditions: [
              'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@contains(activity(\'Export SQL VMs Without AHB\').output.errors[0].Message, \'Sequence contains no elements\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'Set SQL VMs No AHB Error Counter'
              type: 'SetVariable'
              dependsOn: []
              policy: {
                secureOutput: false
                secureInput: false
              }
              userProperties: []
              typeProperties: {
                variableName: 'pipelineFailed'
                value: {
                  value: '@bool(true)'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
      { // Overall Exports Check
        name: 'Overall Exports Check'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'Export SQL VMs Without AHB'
            dependencyConditions: [
              'Completed'
            ]
          }
          {
            activity: 'Catch SQL VMs Without AHB Failure'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(variables(\'pipelineFailed\'), true)'
            type: 'Expression'
          }
          ifTrueActivities: [
            {
              name: 'Fail Pipeline'
              type: 'Fail'
              dependsOn: []
              userProperties: []
              typeProperties: {
                message: {
                  value: 'Pipeline failed'
                  type: 'Expression'
                }
                errorCode: 'ARGQueriesFailed'
              }
            }
          ]
        }
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    variables: {
      schemaFile: {
        type: 'String'
      }
      blobExportTimestamp: {
        type: 'String'
      }
      pipelineFailed: {
        type: 'Boolean'
      }
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
// Start all triggers
//------------------------------------------------------------------------------

resource startTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_startTriggers'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  tags: union(
    tags,
    contains(tagsByResource, 'Microsoft.Resources/deploymentScripts')
      ? tagsByResource['Microsoft.Resources/deploymentScripts']
      : {}
  )
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    identityRoleAssignments
    trigger_FileAdded
    trigger_SettingsUpdated
    trigger_DailySchedule
    trigger_MonthlySchedule
    trigger_RecommendationsDailySchedule
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
