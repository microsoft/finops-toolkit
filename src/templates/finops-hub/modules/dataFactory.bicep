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

@description('Optional. Azure Resource Manager base URL.')
param azureResourceManagerUri string = 'https://management.azure.com'

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var focusSchemaVersion = '1.0'
var ftkVersion = loadTextContent('ftkver.txt')
var exportApiVersion = '2023-07-01-preview'

// Function to generate the body for a Cost Management export
func getExportBody(exportContainerName string, datasetType string, schemaVersion string, isMonthly bool, exportFormat string, compressionMode string, partitionData string, dataOverwriteBehavior string) string => '{ "properties": { "definition": { "dataSet": { "configuration": { "dataVersion": "${schemaVersion}", "filters": [] }, "granularity": "Daily" }, "timeframe": "${isMonthly ? 'TheLastMonth': 'MonthToDate' }", "type": "${datasetType}" }, "deliveryInfo": { "destination": { "container": "${exportContainerName}", "rootFolderPath": "@{if(startswith(item().scope, \'/\'), substring(item().scope, 1, sub(length(item().scope), 1)) ,item().scope)}", "type": "AzureBlob", "resourceId": "@{variables(\'storageAccountId\')}" } }, "schedule": { "recurrence": "${ isMonthly ? 'Monthly' : 'Daily'}", "recurrencePeriod": { "from": "2024-01-01T00:00:00.000Z", "to": "2050-02-01T00:00:00.000Z" }, "status": "Inactive" }, "format": "${exportFormat}", "partitionData": "${partitionData}", "dataOverwriteBehavior": "${dataOverwriteBehavior}", "compressionMode": "${compressionMode}" }, "id": "@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}", "name": "@{variables(\'exportName\')}", "type": "Microsoft.CostManagement/reports", "identity": { "type": "systemAssigned" }, "location": "global" }'

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
var recommendationsName = 'recommendations'

// All hub triggers (used to auto-start)
var fileAddedExportTriggerName = '${safeExportContainerName}_FileAdded'
var updateConfigTriggerName = '${safeConfigContainerName}_SettingsUpdated'
var dailyTriggerName = '${safeConfigContainerName}_DailySchedule'
var dailyRecommendationsTriggerName = '${recommendationsName}_DailySchedule'
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
  tags: union(tags, contains(tagsByResource, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tagsByResource['Microsoft.ManagedIdentity/userAssignedIdentities'] : {})
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
  tags: union(tags, contains(tagsByResource, 'Microsoft.Resources/deploymentScripts') ? tagsByResource['Microsoft.Resources/deploymentScripts'] : {})
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

resource linkedService_arm 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'azurerm'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'RestService'
    typeProperties: {
      url: azureResourceManagerUri
      authenticationType: 'ManagedServiceIdentity'
      enableServerCertificateValidation: true
      aadResourceId: azureResourceManagerUri
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
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
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
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
      type: 'LinkedServiceReference'
    }
  }
}

resource dataset_recommendations 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: recommendationsName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {
      blobPrefix: {
        type: 'String'
      }
      blobExportTimestamp: {
        type: 'String'
      }
    }
    type: 'Json'
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: safeIngestionContainerName
        fileName: {
          value: '@concat(dataset().blobPrefix,\'-\', dataset().blobExportTimestamp, \'.json\')'
          type: 'Expression'
        }
        folderPath: recommendationsName
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: empty(remoteHubStorageUri) ? linkedService_storageAccount.name : linkedService_remoteHubStorage.name
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
          referenceName: pipeline_ExportRecommendationsAdvisor.name
          type: 'PipelineReference'
        }
        parameters: {
          Recurrence: 'Daily'
        }
      }
      {
        pipelineReference: {
          referenceName: pipeline_ExportRecommendationsCustom.name
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
        name: 'ForEach Export Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Get Config\').output.firstRow.scopes'
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
        name: 'ForEach Export Scope'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Get Config'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          items: {
            value: '@activity(\'Get Config\').output.firstRow.scopes'
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
      { // 'Get Config'
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
      { // 'ForEach Export Scope'
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
            { // 'Create or update open month focus export'
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
                  value: getExportBody(exportContainerName, 'FocusCost', focusSchemaVersion, false, 'Parquet', 'Snappy', 'true', 'CreateNewReport')
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
            { // 'Set open month focus export name'
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
            { // 'Create or update closed month focus export'
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
                  value: getExportBody(exportContainerName, 'FocusCost', focusSchemaVersion, true, 'Parquet', 'Snappy', 'true', 'CreateNewReport')
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
            { // 'Set closed month focus export name'
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
      { // 'Save scopes as array'
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
      { // 'Save scopes'
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
      { // 'Remove empty scopes'
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
      { // Wait
        name: 'Wait'
        type: 'Wait'
        dependsOn: []
        userProperties: []
        typeProperties: {
          waitTimeInSeconds: 60
        }
      }
      { // Read manifest
        name: 'Read Manifest'
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
      { // Set dataset type from manifest
        name: 'Set Dataset Type'
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
            value: '@activity(\'Read Manifest\').output.firstRow.exportConfig.type'
            type: 'Expression'
          }
        }
      }
      { // Set dataset version from manifest
        name: 'Set Dataset Version'
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
      { // Set schema file based on type/version
        name: 'Set Schema File'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set Dataset Type'
            dependencyConditions: ['Succeeded']
          }
          {
            activity: 'Set Dataset Version'
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
            value: '@toLower(concat(variables(\'datasetType\'), \'_\', variables(\'datasetVersion\'), \'.json\'))'
            type: 'Expression'
          }
        }
      }
      { // Set scope from manifest
        name: 'Set Scope'
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
      { // Set date from manifest
        name: 'Set Date'
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
      { // Error: ManifestReadFailed
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
            activity: 'Set Schema File'
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
      { // Validate schema
        name: 'Check Schema'
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
            activity: 'Set Schema File'
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
      { // Error: SchemaNotFound
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
      { // Loop thru blobs
        name: 'For Each Blob'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Check Schema'
            dependencyConditions: ['Completed']
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
            { // Execute ingestion pipeline
              name: 'Execute'
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
                  schemaFile: {
                    value: '@variables(\'schemaFile\')'
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
    // Flow = Destination File / Load Schema -> Delete Target -> Convert CSV -> Read Config -> Delete CSV
    activities: [
      { // Read hub config to get dataset type/version
        name: 'Read Hub Config'
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
      { // Load schema mappings
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
            value: '@concat(\'Unable to load the \', pipeline().parameters.schemaFile, \' schema file. Please confirm the schema and version are supported for FinOps hubs ingestion. Unsupported files will remain in the msexports container.\')'
            type: 'Expression'
          }
          errorCode: 'SchemaLoadFailed'
        }
      }
      { // Get previously ingested parquet files
        name: 'Get Existing Parquet Files'
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
      { // Filter out files from the current export run
        name: 'Filter Out Current Exports'
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
      { // Delete old ingested files
        name: 'For Each Old File'
        type: 'ForEach'
        dependsOn: [
          {
            activity: 'Read Hub Config'
            dependencyConditions: ['Completed']
          }
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
              name: 'Delete Old Ingested File'
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
      { // If export retention <= 0d, delete the source export file; otherwise, do nothing
        name: 'If Retaining Exports'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'If Parquet'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@lessOrEquals(coalesce(activity(\'Read Hub Config\').output.firstRow.retention.msexports.days, 0), 0)'
            type: 'Expression'
          }
          ifTrueActivities: [
            { // Delete the source export file
              name: 'Delete Source File'
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
      { // If parquet, move parquet file; otherwise, convert CSV to parquet
        name: 'If Parquet'
        type: 'IfCondition'
        dependsOn: [
          {
            activity: 'For Each Old File'
            dependencyConditions: ['Succeeded']
          }
        ]
        userProperties: []
        typeProperties: {
          expression: {
            value: '@endswith(pipeline().parameters.blobPath, \'.parquet\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            { // Convert CSV file to parquet
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
          ifTrueActivities: [
            { // Move parquet file
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
// msexports_Recommendations_Advisor_ingestion pipeline
// Triggered by dailyRecommendations trigger
//------------------------------------------------------------------------------
@description('Extracts Azure Advisor recommendations from the Resource Graph API.')
resource pipeline_ExportRecommendationsAdvisor 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_Recommendations_Advisor'
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
            value: '@utcNow(\'yyyyMMddHHmmss\')'
            type: 'Expression'
          }
        }
      }
      { // Get Advisor recommendations from ARG
        name: 'get_ARGAdvisorRecommendations'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{ "query": "advisorresources | where type == \'microsoft.advisor/recommendations\' | project id, resourceGroup=tolower(resourceGroup), subscriptionId, category = tostring(properties.category), provider=\'Microsoft.Advisor\', impact = tostring(properties.impact), recommendationTypeId = tostring(properties.recommendationTypeId), recommendationControl = tostring(properties.extendedProperties.recommendationControl), maturityLevel = tostring(properties.extendedProperties.maturityLevel), descriptionProblem = tostring(properties.shortDescription.problem), descriptionSolution = tostring(properties.shortDescription.solution), resourceId = tolower(properties.resourceMetadata.resourceId), resourceType = tolower(properties.impactedField), resourceName = tolower(properties.impactedValue), extendedProperties = properties.extendedProperties, lastUpdated = tostring(properties.lastUpdated) | where category in (\'Cost\') | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1" }'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator:
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-advisor'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
    ]
    parameters: {}
    policy: {
      elapsedTimeMetric: {}
    }
    variables: {
      blobExportTimestamp: {
        type: 'String'
      }
    }
    annotations: []
  }
}

//------------------------------------------------------------------------------
// msexports_Recommendations_Custom_ingestion pipeline
// Triggered by dailyRecommendations trigger
//------------------------------------------------------------------------------
@description('Extracts custom recommendations from the Resource Graph API.')
resource pipeline_ExportRecommendationsCustom 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_Recommendations_Custom'
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
            value: '@utcNow(\'yyyyMMddHHmmss\')'
            type: 'Expression'
          }
        }
      }
      { // Get unattached disks
        name: 'get_Storage_UnattachedDisks'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "resources | where type =~ \'microsoft.compute/disks\'  | extend diskState = tostring(properties.diskState)  | where isempty(managedBy) and diskState != \'ActiveSAS\' or diskState == \'Unattached\' and diskState != \'ActiveSAS\' and tags !contains \'ASR-ReplicaDisk\' and tags !contains \'asrseeddisk\'  | extend DiskId=id, DiskIDfull=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated), SubId=subscriptionId | order by DiskId asc | project DiskId, DiskIDfull, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId, type | project id=strcat(tolower(DiskId),\'-unattached\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'High\', recommendationTypeId = \'e0c02939-ce02-4f9d-881f-8067ae7ec90f\', recommendationControl = \'UsageOptimization/OrphanedResources\', maturityLevel = \'Preview\', descriptionProblem = \'Unattached disk\', descriptionSolution = \'Remove or downgrade disk\', resourceId = tolower(DiskId), resourceType = type, resourceName = tolower(DiskName), extendedProperties = todynamic(strcat(\'{\\"DiskSizeGB\\": \', DiskSizeGB, \', \\"SKUName\\": \\"\', SKUName, \'\\", \\"SKUTier\\": \\"\', SKUTier, \'\\", \\"Location\\": \\"\', Location, \'\\", \\"TimeCreated\\": \\"\', TimeCreated, \'\\" }\')), lastUpdated = now(), recommendationProvider=\'Custom\'  | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-unattacheddisks'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get AKS clusters without Spot pools
        name: 'get_Compute_AKS'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{"query": "resources | where type == \'microsoft.containerservice/managedclusters\' | extend AgentPoolProfiles = properties.agentPoolProfiles | mvexpand AgentPoolProfiles | project id, type, ProfileName = tostring(AgentPoolProfiles.name), Sku = tostring(sku.name), Tier = tostring(sku.tier), mode = AgentPoolProfiles.mode, AutoScaleEnabled = AgentPoolProfiles.enableAutoScaling, SpotVM = AgentPoolProfiles.scaleSetPriority, VMSize = tostring(AgentPoolProfiles.vmSize), NodeCount = tostring(AgentPoolProfiles.[\'count\']), minCount = tostring(AgentPoolProfiles.minCount), maxCount = tostring(AgentPoolProfiles.maxCount), Location=location, resourceGroup, subscriptionId, AKSname = name| where AutoScaleEnabled == \'true\' and isnull( SpotVM)| project  id=strcat(tolower(id),\'-notSpot\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'Medium\',recommendationTypeId=\'c26abcc2-d5e6-4654-be4a-7d338e5c1e5f\',recommendationControl = \'UsageOptimization/OptimizeResources\', maturityLevel = \'Preview\', descriptionProblem = \'The AKS cluster is configured with a scale set but is not utilizing Spot VMs.\', descriptionSolution = \'Consider enabling Spot VMs for this AKS cluster to optimize costs, as Spot VMs offer significantly lower pricing compared to regular virtual machines.\',resourceId = tolower(id), resourceType = type, resourceName = tolower(AKSname), extendedProperties = todynamic(strcat(\'{\\"AutoScaleEnabled\\": \', AutoScaleEnabled, \', \\"SpotVM\\": \\"\', SpotVM, \'\\", \\"VMSize\\": \\"\', VMSize, \'\\", \\"Location\\": \\"\', Location, \'\\", \\"NodeCount\\": \\"\', NodeCount, \'\\", \\"minCount\\": \\"\', minCount, \'\\", \\"maxCount\\": \\"\', maxCount, \'\\" }\')), lastUpdated = now(), recommendationProvider=\'Custom\'  | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-computeaks'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get deallocated VMs
        name: 'get_Compute_VM_Deallocated'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{"query":"resources| where type =~ \'microsoft.compute/virtualmachines\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM deallocated\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM running\' | extend PowerState=tostring(properties.extended.instanceView.powerState.displayStatus) | extend Location=location, type| extend resourceGroup=strcat(\'/subscriptions/\',subscriptionId,\'/resourceGroups/\',resourceGroup)| project id, PowerState, Location, resourceGroup, subscriptionId, VMName=name, type| project  id=strcat(tolower(id),\'-notDeallocated\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'Medium\',recommendationTypeId=\'ab2ff882-e927-4093-9d11-631be0219975\',recommendationControl = \'UsageOptimization/OptimizeResources\', maturityLevel = \'Preview\', descriptionProblem = \'This VM is powered off but not deallocated\', descriptionSolution = \'Deallocate the VM through the Azure portal to ensure it is fully stopped.\',resourceId = tolower(id), resourceType = type, resourceName = tolower(VMName), extendedProperties = todynamic(strcat(\'{\\"PowerState\\": \', PowerState, \',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'  | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-computevmdeallocated'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get APP Gateways without backend pool
        name: 'get_Network_AppGateway'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{"query":"resources| where type =~ \'Microsoft.Network/applicationGateways\' | extend backendPoolsCount = array_length(properties.backendAddressPools),SKUName= tostring(properties.sku.name), SKUTier= tostring(properties.sku.tier),SKUCapacity=properties.sku.capacity,backendPools=properties.backendAddressPools,resourceGroup=strcat(\'/subscriptions/\',subscriptionId,\'/resourceGroups/\',resourceGroup)| project id, name, SKUName, SKUTier, SKUCapacity,resourceGroup,subscriptionId, AppGWName=name, type, Location=location| join (    resources    | where type =~ \'Microsoft.Network/applicationGateways\'    | mvexpand backendPools = properties.backendAddressPools    | extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)    | extend backendPoolName  = backendPools.properties.backendAddressPools.name    | summarize backendIPCount = sum(backendIPCount) ,backendAddressesCount=sum(backendAddressesCount) by id) on id| project-away id1| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))| project  id=strcat(tolower(id),\'-idle\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'High\',recommendationTypeId=\'4f69df93-5972-44e0-97cf-4343c2bcf4b9\',recommendationControl = \'UsageOptimization/OrphanedResources\', maturityLevel = \'Preview\', descriptionProblem = \'Application Gateway without any backend pool.\', descriptionSolution = \'Review and remove this resource if not needed.\',resourceId = tolower(id), resourceType = type, resourceName = tolower(AppGWName), extendedProperties = todynamic(strcat(\'{\\"backendIPCount\\": \', backendIPCount, \',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'  | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-networkappgw'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get Load Balancers without backend pool
        name: 'get_Network_LoadBalancer'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "resources   | extend resourceGroup=strcat(\'/subscriptions/\',subscriptionId,\'/resourceGroups/\',resourceGroup)    | extend SKUName=tostring(sku.name)    | extend SKUTier=tostring(sku.tier), Location=location    | extend backendAddressPools = properties.backendAddressPools    | where type =~ \'microsoft.network/loadbalancers\' and array_length(backendAddressPools) == 0 and sku.name!=\'Basic\'     | order by id asc     | extend id,name, SKUName,SKUTier,backendAddressPools, location,resourceGroup, subscriptionId, type    | project  id=strcat(tolower(id),\'-idle\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'High\',recommendationTypeId=\'d7e71ff3-8db9-4a5d-b403-70642f6c6995\',recommendationControl = \'UsageOptimization/OrphanedResources\', maturityLevel = \'Preview\', descriptionProblem = \'Load balancer without a backend pool.\', descriptionSolution = \'Review and remove this resource if not needed.\',resourceId = tolower(id), resourceType = type, resourceName = tolower(name), extendedProperties = todynamic(strcat(\'{\\"SKUName\\": \', SKUName, \',\\"SKUTier\\": \\"\', SKUTier, \',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-networklb'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get unattached Public IPs
        name: 'get_Network_PublicIP'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "resources   | where type =~ \'Microsoft.Network/publicIPAddresses\' and isempty(properties.ipConfiguration) and isempty(properties.natGateway) and properties.publicIPAllocationMethod =~ \'Static\'   | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location, resourceGroup=strcat(\'/subscriptions/\',subscriptionId,\'/resourceGroups/\',resourceGroup)   | project PublicIpId, IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, type, name   | union ( resources | where type =~ \'microsoft.network/networkinterfaces\' and isempty(properties.virtualMachine) and isnull(properties.privateEndpoint) and isnotempty(properties.ipConfigurations)   | extend IPconfig = properties.ipConfigurations | mv-expand IPconfig | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id)   | project PublicIpId, name | join ( resources | where type =~ \'Microsoft.Network/publicIPAddresses\'   | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, resourceGroup, Location=location, name, id ) on PublicIpId    | extend PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod,name, subscriptionId )     | project  id=strcat(tolower(PublicIpId),\'-idle\'), resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'High\',recommendationTypeId=\'3ecbf770-9404-4504-a450-cc198e8b2a7d\',recommendationControl = \'UsageOptimization/OrphanedResources\', maturityLevel = \'Preview\', descriptionProblem = \'Idle public ip adress\', descriptionSolution = \'Review and remove this resource if not needed.\',resourceId = tolower(PublicIpId), resourceType = type, resourceName = tolower(name), extendedProperties = todynamic(strcat(\'{\\"SKUName\\": \', SKUName, \',\\"AllocationMethod\\": \\"\', AllocationMethod,\',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-networkpip'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get idle SQL Database elastic pools
        name: 'get_Database_SQLServer'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "resources   | where type == \'microsoft.sql/servers/elasticpools\'  | extend elasticPoolId = tolower(tostring(id)), elasticPoolName = name, elasticPoolRG = resourceGroup,skuName=tostring(sku.name),skuTier=tostring(sku.tier),skuCapacity=tostring(sku.capacity), Location=location, type  | join kind=leftouter ( resources | where type == \'microsoft.sql/servers/databases\'  | extend elasticPoolId = tolower(tostring(properties.elasticPoolId)) ) on elasticPoolId  | summarize databaseCount = countif(isnotempty(elasticPoolId1)) by elasticPoolId, elasticPoolName,serverResourceGroup=resourceGroup,name,skuName,skuTier,skuCapacity,elasticPoolRG,Location, type, subscriptionId  | where databaseCount == 0   | project elasticPoolId, elasticPoolName, databaseCount, elasticPoolRG ,skuName,skuTier ,skuCapacity, Location, type, subscriptionId    | project  id=strcat(tolower(elasticPoolId),\'-idle\'), resourceGroup=elasticPoolRG, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'Medium\',recommendationTypeId=\'50987aae-a46d-49ae-bd41-a670a4dd18bd\',recommendationControl = \'UsageOptimization/OrphanedResources\', maturityLevel = \'Preview\', descriptionProblem = \'Idle Elastic Pools in Azure SQL database \', descriptionSolution = \'Review and remove this resource if not needed.\',resourceId = tolower(elasticPoolId), resourceType = type, resourceName = tolower(elasticPoolName), extendedProperties = todynamic(strcat(\'{\\"skuName\\": \', skuName, \',\\"skuTier\\": \\"\', skuTier,\',\\"skuCapacity\\": \\"\', skuCapacity,\',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'  | join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-databasesqlidlepool'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get Windows VMs without AHB
        name: 'get_AHB_Windows'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "ResourceContainers | where type =~ \'Microsoft.Resources/subscriptions\' | where tostring (properties.subscriptionPolicies.quotaId) !has \'MSDNDevTest_2014-09-01\'  | extend SubscriptionName=name | join (  resources | where type =~ \'microsoft.compute/virtualmachines\'| where tostring(properties.storageProfile.osDisk.osType) == \'Windows\'| extend WindowsId=id, VMSku=tostring(properties.hardwareProfile.vmSize), resourceGroup, type, Location=location,LicenseType = tostring(properties.[\'licenseType\'])| extend ActualCores = toint(extract(\'.[A-Z]([0-9]+)\', 1, tostring(properties.hardwareProfile.vmSize)))| extend CheckAHBWindows = case(     type == \'microsoft.compute/virtualmachines\' or type =~ \'microsoft.compute/virtualMachineScaleSets\', iif((properties.[\'licenseType\'])     !has \'Windows\' and (properties.virtualMachineProfile.[\'licenseType\']) !has \'Windows\' , \'AHB-disabled\', \'AHB-enabled\'),     \'Not Windows\'     )) on subscriptionId | project id = strcat(tolower(WindowsId), \'-\', CheckAHBWindows),resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'Medium\',recommendationTypeId=\'f326c065-b9f7-4a0e-a0f1-5a1c060bc25d\',recommendationControl = \'RateOptimization/Licensing\', maturityLevel = \'Preview\', descriptionProblem = \'Check Windows AHB status\', descriptionSolution = \'Check Windows AHB status\',resourceId = tolower(WindowsId), resourceType = type, resourceName = tolower(name), extendedProperties = todynamic(strcat(\'{\\"VMSku\\": \', VMSku, \',\\"CheckAHBWindows\\": \\"\', CheckAHBWindows,\',\\"ActualCores\\": \\"\', ActualCores,\',\\"Location\\": \\"\', Location)), lastUpdated = now(), recommendationProvider=\'Custom\'| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-ahbwindows'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
      { // Get SQL VMs without AHB
        name: 'get_AHB_SQL'
        type: 'Copy'
        dependsOn: [
          {
            activity: 'set_BlobExportTimestamp'
            dependencyConditions: ['Completed']
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
          source: {
            type: 'RestSource'
            httpRequestTimeout: '00:02:00'
            requestInterval: '00:00:01'
            requestMethod: 'POST'
            requestBody: '{  "query": "resourcecontainers | where type =~ \'Microsoft.Resources/subscriptions\' | where tostring (properties.subscriptionPolicies.quotaId) !has \'MSDNDevTest_2014-09-01\' | extend SubscriptionName=name | join (     resources | where type =~ \'Microsoft.SqlVirtualMachine/SqlVirtualMachines\'    | extend SQLID=id, VMName = name, resourceGroup, Location = location, LicenseType = tostring(properties.[\'sqlServerLicenseType\']), OSType=tostring(properties.storageProfile.imageReference.offer), SQLAgentType = tostring(properties.[\'sqlManagement\']), SQLVersion = tostring(properties.[\'sqlImageOffer\']), SQLSKU=tostring(properties.[\'sqlImageSku\'])    ) on subscriptionId | join (    resources    | where type =~ \'Microsoft.Compute/virtualmachines\'    | extend ActualCores = toint(extract(\'.[A-Z]([0-9]+)\', 1, tostring(properties.hardwareProfile.vmSize)))    | project VMName = tolower(name), VMSize = tostring(properties.hardwareProfile.vmSize),ActualCores, subscriptionId    ) on VMName| order by id asc    | where SQLSKU != \'Developer\' and SQLSKU != \'Express\'    | extend CheckAHBSQLVM= case(     type == \'Microsoft.SqlVirtualMachine/SqlVirtualMachines\', iif((properties.[\'sqlServerLicenseType\']) != \'AHUB\', \'AHB-disabled\', \'AHB-enabled\'),     \'Not Windows\'     )| project SQLID,VMName,resourceGroup, Location, VMSize, SQLVersion, SQLSKU, SQLAgentType, LicenseType, SubscriptionName,type,CheckAHBSQLVM, subscriptionId,ActualCores| project id = strcat(tolower(SQLID), \'-\', CheckAHBSQLVM),resourceGroup, subscriptionId, category=\'Cost\', provider=\'Microsoft.FinOpsToolkit\', impact=\'High\',recommendationTypeId=\'01decd62-f91b-4434-abe5-9a09e13e018f\',recommendationControl = \'RateOptimization/Licensing\', maturityLevel = \'Preview\', descriptionProblem = \'Check SQL VM AHB status\', descriptionSolution = \'Check SQL VM AHB status.\',resourceId = tolower(SQLID), resourceType = type, resourceName = tolower(VMName), extendedProperties = todynamic(strcat(\'{\\"VMSize\\": \\"\', VMSize, \'\\", \\"CheckAHBSQLVM\\": \\"\', CheckAHBSQLVM, \'\\", \\"ActualCores\\": \\"\', ActualCores, \'\\", \\"SQLVersion\\": \\"\', SQLVersion, \'\\", \\"SQLSKU\\": \\"\', SQLSKU, \'\\", \\"SQLAgentType\\": \\"\', SQLAgentType, \'\\", \\"LicenseType\\": \\"\', LicenseType, \'\\", \\"Location\\": \\"\', Location, \'\\"}\')),lastUpdated = now(), recommendationProvider=\'Custom\'| join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionName = name, subscriptionId ) on subscriptionId | project-away subscriptionId1"}'
            additionalHeaders: {
              value: {
                'Content-Type': 'application/json'
              }
              type: 'Object'
            }
          }
          sink: {
            type: 'JsonSink'
            storeSettings: {
              type: 'AzureBlobFSWriteSettings'
              copyBehavior: 'FlattenHierarchy'
            }
            formatSettings: {
              type: 'JsonWriteSettings'
            }
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            mappings: [
              {
                source: {
                  path: '[\'id\']'
                }
                sink: {
                  path: '_RecommendationId'
                }
              }  
              {
                source: {
                  path: '[\'subscriptionId\']'
                }
                sink: {
                  path: 'SubAccountId'
                }
              }
              {
                source: {
                  path: '[\'subscriptionName\']'
                }
                sink: {
                  path: 'SubAccountName'
                }
              }
              {
                source: {
                  path: '[\'resourceGroup\']'
                }
                sink: {
                  path: 'x_ResourceGroupName'
                }
              }
              {
                source: {
                  path: '[\'resourceId\']'
                }
                sink: {
                  path: 'ResourceId'
                }
              }
              {
                source: {
                  path: '[\'resourceName\']'
                }
                sink: {
                  path: 'ResourceName'
                }
              }
              {
                source: {
                  path: '[\'resourceType\']'
                }
                sink: {
                  path: '_ResourceType'
                }
              }
              {
                source: {
                  path: '[\'category\']'
                }
                sink: {
                  path: '_RecommendationCategory'
                }
              }
              {
                source: {
                  path: '[\'provider\']'
                }
                sink: {
                  path: '_RecommendationProvider'
                }
              }
              {
                source: {
                  path: '[\'recommendationTypeId\']'
                }
                sink: {
                  path: '_RecommendationTypeId'
                }
              }
              {
                source: {
                  path: '[\'descriptionProblem\']'
                }
                sink: {
                  path: '_RecommendationDescription'
                }
              }
              {
                source: {
                  path: '[\'descriptionSolution\']'
                }
                sink: {
                  path: '_RecommendationSolution'
                }
              }
              {
                source: {
                  path: '[\'impact\']'
                }
                sink: {
                  path: 'x_RecommendationImpact'
                }
              }
              {
                source: {
                  path: '[\'recommendationControl\']'
                }
                sink: {
                  path: 'x_RecommendationControl'
                }
              }
              {
                source: {
                  path: '[\'maturityLevel\']'
                }
                sink: {
                  path: 'x_RecommendationMaturityLevel'
                }
              }
              {
                source: {
                  path: '[\'extendedProperties\']'
                }
                sink: {
                  path: 'x_RecommendationDetails'
                }
              }
              {
                source: {
                  path: '[\'lastUpdated\']'
                }
                sink: {
                  path: 'x_RecommendationDate'
                }
              }            
            ]
            collectionReference: '$[\'data\']'
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
            referenceName: dataset_recommendations.name
            type: 'DatasetReference'
            parameters: {
              blobPrefix: 'cost-custom-ahbsql'
              blobExportTimestamp: {
                value: '@variables(\'blobExportTimestamp\')'
                type: 'Expression'
              }
            }
          }
        ]
      }
    ]
    parameters: {}
    policy: {
      elapsedTimeMetric: {}
    }
    variables: {
      blobExportTimestamp: {
        type: 'String'
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
  tags: union(tags, contains(tagsByResource, 'Microsoft.Resources/deploymentScripts') ? tagsByResource['Microsoft.Resources/deploymentScripts'] : {})
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
