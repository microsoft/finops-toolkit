//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the data factory')
param dataFactoryName string

@description('Required. The name of the Azure Key Vault instance.')
param keyVaultName string

@description('Required. The name of the Azure storage account instance.')
param storageAccountName string

@description('Required. The resource Id of the Azure storage account instance.')
param storageAccountId string

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
var extractExportTriggerName = exportContainerName
var updateConfigTriggerName = configContainerName
var allHubTriggers = [
  extractExportTriggerName
  updateConfigTriggerName
]

// Roles needed to auto-start triggers
var autoStartRbacRoles = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
]

//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

//------------------------------------------------------------------------------
// Stop all triggers before deploying
//------------------------------------------------------------------------------

// Create managed identity to start/stop triggers
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactoryName}_${exportContainerName}_extract_triggerManager'
  location: location
}

// Assign access to the identity
resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in autoStartRbacRoles: {
  name: guid(dataFactory.id, role, identity.id)
  scope: dataFactory
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Stop hub triggers if they're already running
resource stopHubTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactoryName}_stopHubTriggers'
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
        value: dataFactoryName
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
  name: keyVaultName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
    }
  }
}

resource linkedService_storageAccount 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: storageAccountName
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: reference('Microsoft.Storage/storageAccounts/${storageAccountName}', '2021-08-01').primaryEndpoints.dfs
      accountKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: linkedService_keyVault.name
          type: 'LinkedServiceReference'
        }
        secretName: storageAccountName
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
  dependsOn: [
    linkedService_keyVault
  ]
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
  dependsOn: [
    linkedService_keyVault
  ]
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
  dependsOn: [
    linkedService_keyVault
  ]
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
      referenceName: linkedService_storageAccount.name
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

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

//------------------------------------------------------------------------------
// Triggers
//------------------------------------------------------------------------------
resource trigger_exportContainer 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: safeExportContainerName
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
    pipeline_extractExport
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: '${exportContainerName}_extract'
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
  name: safeConfigContainerName
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
        parameters: {
          FolderName: '@triggerBody().folderPath'
          FileName: '@triggerBody().fileName'
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

//------------------------------------------------------------------------------
// Pipelines
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Azure Cost Management add export pipeline
// Triggered when settings.json is updated.
// Creates an export in Azure Cost Management.
//------------------------------------------------------------------------------
resource pipeline_setup 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_setup'
  parent: dataFactory
  dependsOn: [
    dataset_config
  ]
  properties: {
    concurrency: 1
    activities: [
      {
        name: 'Get Config'
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
            referenceName: 'config'
            type: 'DatasetReference'
            parameters: {
              fileName: {
                value: '@pipeline().parameters.fileName'
                type: 'Expression'
              }
              folderName: {
                value: '@pipeline().parameters.folderName'
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
              name: 'If Azure Commercial'
              type: 'IfCondition'
              dependsOn: []
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@equals(toLower(item().cloud), \'azurecloud\')'
                  type: 'Expression'
                }
                ifTrueActivities: [
                  {
                    name: 'Set Resource Management URI Suffix'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'resourceManagementUri'
                      value: 'management.azure.com'
                    }
                  }
                  {
                    name: 'Set KeyVault URI Suffix'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'keyVaultUriSuffix'
                      value: 'vault.azure.net'
                    }
                  }
                  {
                    name: 'Set Azure AD URI'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'azureADUri'
                      value: 'login.microsoftonline.com'
                    }
                  }
                  {
                    name: 'Set Storage Account URI Suffix'
                    type: 'SetVariable'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      variableName: 'storageAccountUriSuffix'
                      value: 'dfs.core.usgovcloudapi.net'
                    }
                  }
                ]
              }
            }
            {
              name: 'Get Client ID'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'If Azure Commercial'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: '@concat(\'https://\', pipeline().parameters.KeyVaultName, \'.\', variables(\'keyVaultUriSuffix\'), \'/secrets/ClientId\', item().tenantId, \'?api-version=7.0\')'
                  type: 'Expression'
                }
                method: 'GET'
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@concat(\'https://\', variables(\'keyVaultUriSuffix\'))'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Get Client Secret'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'If Azure Commercial'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: '@concat(\'https://\', pipeline().parameters.KeyVaultName, \'.\', variables(\'keyVaultUriSuffix\'), \'/secrets/Secret\', item().tenantId, \'?api-version=7.0\')'
                  type: 'Expression'
                }
                method: 'GET'
                authentication: {
                  type: 'MSI'
                  resource: {
                    value: '@concat(\'https://\', variables(\'keyVaultUriSuffix\'))'
                    type: 'Expression'
                  }
                }
              }
            }
            {
              name: 'Get Token'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Get Client Secret'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
                {
                  activity: 'Get Client ID'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: '@concat(\'https://\', variables(\'azureADUri\'), \'/\' ,item().tenantId, \'/oauth2/v2.0/token\')'
                  type: 'Expression'
                }
                method: 'POST'
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded'
                }
                body: {
                  value: 'client_id=@{activity(\'Get Client ID\').output.value}&scope=https%3A%2F%2F@{variables(\'resourceManagementUri\')}%2F.default&client_secret=@{activity(\'Get Client Secret\').output.value}&grant_type=client_credentials'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Create or Update Open Month Export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Get Token'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
                {
                  activity: 'Set Open Month Export Name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: 'https://@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                headers: {
                  authorization: {
                    value: 'Bearer @{activity(\'Get Token\').output.access_token}'
                    type: 'Expression'
                  }
                }
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Active",\n      "recurrence": "Daily",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{pipeline().parameters.StorageAccountId}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "amortizedcost",\n      "timeframe": "BillingMonthToDate",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Set Open Month Export Name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'If Azure Commercial'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@if(greater(length(replace(tolower(concat(pipeline().parameters.StorageAccountName,\'oamortized\', last(split(item().scope, \'/\')))), \'-\', \'\')), 64), substring(replace(tolower(concat(pipeline().parameters.StorageAccountName,\'oamortized\', last(split(item().scope, \'/\')))), \'-\', \'\'), 0, 63), replace(tolower(concat(pipeline().parameters.StorageAccountName,\'oamortized\', last(split(item().scope, \'/\')))), \'-\', \'\'))'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Create or Update Closed Month Export'
              type: 'WebActivity'
              dependsOn: [
                {
                  activity: 'Set Closed Month Export Name'
                  dependencyConditions: [
                    'Succeeded'
                  ]
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
                url: {
                  value: 'https://@{variables(\'resourceManagementUri\')}@{item().scope}/providers/Microsoft.CostManagement/exports/@{variables(\'exportName\')}?api-version=2021-10-01'
                  type: 'Expression'
                }
                method: 'PUT'
                headers: {
                  authorization: {
                    value: 'Bearer @{activity(\'Get Token\').output.access_token}'
                    type: 'Expression'
                  }
                }
                body: {
                  value: '{\n  "properties": {\n    "schedule": {\n      "status": "Active",\n      "recurrence": "Monthly",\n      "recurrencePeriod": {\n        "from": "@{utcNow()}",\n        "to": "2099-12-31T00:00:00Z"\n      }\n    },\n    "partitionData": "True",\n    "format": "Csv",\n    "deliveryInfo": {\n      "destination": {\n        "resourceId": "@{pipeline().parameters.StorageAccountId}",\n        "container": "msexports",\n        "rootFolderPath": "@{item().scope}"\n      }\n    },\n    "definition": {\n      "type": "amortizedcost",\n      "timeframe": "TheLastBillingMonth",\n      "dataSet": {\n        "granularity": "Daily"\n      }\n    }\n  }\n}'
                  type: 'Expression'
                }
              }
            }
            {
              name: 'Set Closed Month Export Name'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'Create or Update Open Month Export'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                variableName: 'exportName'
                value: {
                  value: '@if(greater(length(replace(tolower(concat(pipeline().parameters.StorageAccountName,\'camortized\', last(split(item().scope, \'/\')))), \'-\', \'\')), 64), substring(replace(tolower(concat(pipeline().parameters.StorageAccountName,\'camortized\', last(split(item().scope, \'/\')))), \'-\', \'\'), 0, 63), replace(tolower(concat(pipeline().parameters.StorageAccountName,\'camortized\', last(split(item().scope, \'/\')))), \'-\', \'\'))'
                  type: 'Expression'
                }
              }
            }
          ]
        }
      }
    ]
    parameters: {
      FileName: {
        type: 'string'
        defaultValue: 'settings.json'
      }
      FolderName: {
        type: 'string'
        defaultValue: 'config'
      }
      StorageAccountId: {
        type: 'string'
        defaultValue: storageAccountId
      }
      StorageAccountName: {
        type: 'String'
        defaultValue: storageAccountName
      }
      KeyVaultName: {
        type: 'String'
        defaultValue: keyVaultName
      }
    }
    variables: {
      resourceManagementUri: {
        type: 'String'
      }
      keyVaultUriSuffix: {
        type: 'String'
      }
      azureADUri: {
        type: 'String'
      }
      exportName: {
        type: 'String'
      }
      storageAccountUriSuffix: {
        type: 'String'
      }
      exportScope: {
        type: 'String'
      }
      cloud: {
        type: 'String'
      }
      tenantId: {
        type: 'String'
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
  dependsOn: [
    pipeline_transformExport
  ]
  properties: {
    activities: [
      {
        name: 'Execute'
        type: 'ExecutePipeline'
        dependsOn: []
        userProperties: []
        typeProperties: {
          pipeline: {
            referenceName: '${safeExportContainerName}_transform'
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
  dependsOn: [
    dataset_msexports
    dataset_ingestion
  ]
  properties: {
    activities: [
      // (start) -> Wait -> Scope -> Metric -> Date -> File -> Folder -> Delete Target -> Convert CSV -> Delete CSV -> (end)
      // Wait
      {
        name: 'Wait'
        type: 'Wait'
        dependsOn: []
        userProperties: []
        typeProperties: {
          waitTimeInSeconds: 60
        }
      }
      // Set Scope
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
            value: '@replace(split(pipeline().parameters.folderName,split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 4)])[0],\'${exportContainerName}\',\'${ingestionContainerName}\')'
            type: 'Expression'
          }
        }
      }
      // Set Metric
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
            // TODO: Parse metric out of the export path with self-managed exports -- value: '@first(split(split(pipeline().parameters.folderName, \'/\')[sub(length(split(pipeline().parameters.folderName, \'/\')), 4)], \'-\'))'
            value: 'amortizedcost'
            type: 'Expression'
          }
        }
      }
      // Set Date
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
      // Set Destination File Name
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
            value: '@replace(pipeline().parameters.fileName, \'.csv\', \'${convertToParquet ? '.parquet' : '.csv.gz'}\')'
            type: 'Expression'
          }
        }
      }
      // Set Destination Folder Name
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
      // Delete Target
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
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: safeIngestionContainerName
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
      // Convert CSV
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
            formatSettings: convertToParquet ? {
              type: 'ParquetWriteSettings'
              fileExtension: '.parquet'
            } : {
              type: 'DelimitedTextWriteSettings'
              quoteAllText: true
              fileExtension: '.csv.gz'
            }
          }
          enableStaging: false
          parallelCopies: 1
          validateDataConsistency: false
        }
        inputs: [
          {
            referenceName: safeExportContainerName
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
            referenceName: safeIngestionContainerName
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
      // Delete CSV
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
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataset: {
            referenceName: safeExportContainerName
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
    annotations: []
  }
}

//------------------------------------------------------------------------------
// Start all triggers
//------------------------------------------------------------------------------

// Start hub triggers
resource startHubTriggers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactoryName}_startHubTriggers'
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
        value: dataFactoryName
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
