// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param dataFactoryName string

@description('Required. The name of the Azure Key Vault instance.')
param keyVaultName string

@description('Required. The name of the Azure storage account instance.')
param storageAccountName string

@description('Required. The name of the container where Cost Management data is exported.')
param exportContainerName string

@description('Required. The name of the container where normalized data is ingested.')
param ingestionContainerName string

@description('Optional. Indicates whether ingested data should be converted to Parquet. Default: true.')
param convertToParquet bool = true

@description('Optional. The location to use for the managed identity and deployment script to auto-start triggers. Default = (resource group location).')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

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

// All hub triggers (used to auto-start)
var extractExportTriggerName = exportContainerName
var allHubTriggers = [
  extractExportTriggerName
]

// Roles needed to auto-start triggers
var autoStartRbacRoles = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
  'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59' // Managed Identity Contributor - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-contributor
]

// FocusCost 1.0-preview (v1) columns
var focusCostColumns = [
  { name: 'AvailabilityZone', type: 'string' }
  { name: 'BilledCost', type: 'decimal' }
  { name: 'BillingAccountId', type: 'string' }
  { name: 'BillingAccountName', type: 'string' }
  { name: 'BillingAccountType', type: 'string' }
  { name: 'BillingCurrency', type: 'string' }
  { name: 'BillingPeriodEnd', type: 'datetime' }
  { name: 'BillingPeriodStart', type: 'datetime' }
  { name: 'ChargeCategory', type: 'string' }
  { name: 'ChargeDescription', type: 'string' }
  { name: 'ChargeFrequency', type: 'string' }
  { name: 'ChargePeriodEnd', type: 'datetime' }
  { name: 'ChargePeriodStart', type: 'datetime' }
  { name: 'ChargeSubcategory', type: 'string' }
  { name: 'CommitmentDiscountCategory', type: 'string' }
  { name: 'CommitmentDiscountId', type: 'string' }
  { name: 'CommitmentDiscountName', type: 'string' }
  { name: 'CommitmentDiscountType', type: 'string' }
  { name: 'EffectiveCost', type: 'decimal' }
  { name: 'InvoiceIssuerName', type: 'string' }
  { name: 'ListCost', type: 'decimal' }
  { name: 'ListUnitPrice', type: 'decimal' }
  { name: 'PricingCategory', type: 'string' }
  { name: 'PricingQuantity', type: 'decimal' }
  { name: 'PricingUnit', type: 'string' }
  { name: 'ProviderName', type: 'string' }
  { name: 'PublisherName', type: 'string' }
  { name: 'Region', type: 'string' }
  { name: 'ResourceId', type: 'string' }
  { name: 'ResourceName', type: 'string' }
  { name: 'ResourceType', type: 'string' }
  { name: 'ServiceCategory', type: 'string' }
  { name: 'ServiceName', type: 'string' }
  { name: 'SkuId', type: 'string' }
  { name: 'SkuPriceId', type: 'string' }
  { name: 'SubAccountId', type: 'string' }
  { name: 'SubAccountName', type: 'string' }
  { name: 'SubAccountType', type: 'string' }
  { name: 'Tags', type: 'string' }
  { name: 'UsageQuantity', type: 'decimal' }
  { name: 'UsageUnit', type: 'string' }
  { name: 'x_AccountName', type: 'string' }
  { name: 'x_AccountOwnerId', type: 'string' }
  { name: 'x_BilledCostInUsd', type: 'decimal' }
  { name: 'x_BilledUnitPrice', type: 'decimal' }
  { name: 'x_BillingAccountId', type: 'string' }
  { name: 'x_BillingAccountName', type: 'string' }
  { name: 'x_BillingExchangeRate', type: 'decimal' }
  { name: 'x_BillingExchangeRateDate', type: 'datetime' }
  { name: 'x_BillingProfileId', type: 'string' }
  { name: 'x_BillingProfileName', type: 'string' }
  { name: 'x_ChargeId', type: 'string' }
  { name: 'x_CostAllocationRuleName', type: 'string' }
  { name: 'x_CostCenter', type: 'string' }
  { name: 'x_CustomerId', type: 'string' }
  { name: 'x_CustomerName', type: 'string' }
  { name: 'x_EffectiveCostInUsd', type: 'decimal' }
  { name: 'x_EffectiveUnitPrice', type: 'decimal' }
  { name: 'x_InvoiceId', type: 'string' }
  { name: 'x_InvoiceIssuerId', type: 'string' }
  { name: 'x_InvoiceSectionId', type: 'string' }
  { name: 'x_InvoiceSectionName', type: 'string' }
  { name: 'x_OnDemandCost', type: 'decimal' }
  { name: 'x_OnDemandCostInUsd', type: 'decimal' }
  { name: 'x_OnDemandUnitPrice', type: 'decimal' }
  { name: 'x_PartnerCreditApplied', type: 'boolean' }
  { name: 'x_PartnerCreditRate', type: 'datetime' }
  { name: 'x_PricingBlockSize', type: 'datetime' }
  { name: 'x_PricingCurrency', type: 'string' }
  { name: 'x_PricingSubcategory', type: 'string' }
  { name: 'x_PricingUnitDescription', type: 'string' }
  { name: 'x_PublisherCategory', type: 'string' }
  { name: 'x_PublisherId', type: 'string' }
  { name: 'x_ResellerId', type: 'string' }
  { name: 'x_ResellerName', type: 'string' }
  { name: 'x_ResourceGroupName', type: 'string' }
  { name: 'x_ResourceType', type: 'string' }
  { name: 'x_ServicePeriodEnd', type: 'datetime' }
  { name: 'x_ServicePeriodStart', type: 'datetime' }
  { name: 'x_SkuDescription', type: 'string' }
  { name: 'x_SkuDetails', type: 'string' }
  { name: 'x_SkuIsCreditEligible', type: 'boolean' }
  { name: 'x_SkuMeterCategory', type: 'string' }
  { name: 'x_SkuMeterId', type: 'string' }
  { name: 'x_SkuMeterName', type: 'string' }
  { name: 'x_SkuMeterSubcategory', type: 'string' }
  { name: 'x_SkuOfferId', type: 'string' }
  { name: 'x_SkuOrderId', type: 'string' }
  { name: 'x_SkuOrderName', type: 'string' }
  { name: 'x_SkuPartNumber', type: 'string' }
  { name: 'x_SkuRegion', type: 'string' }
  { name: 'x_SkuServiceFamily', type: 'string' }
  { name: 'x_SkuTerm', type: 'string' }
  { name: 'x_SkuTier', type: 'string' }
]
var focusCostMappings = [for i in range(0, length(focusCostColumns)): {
  source: { name: focusCostColumns[i].name, type: 'string' }
  sink: { name: focusCostColumns[i].name, type: focusCostColumns[i].type }
}]

//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

//------------------------------------------------------------------------------
// Delete old triggers and pipelines
//------------------------------------------------------------------------------

resource deleteOldResources 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactory.name}_deleteOldResources'
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

// Create managed identity to start/stop triggers
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactoryName}_triggerManager'
  location: location
  tags: union(tags, contains(tagsByResource, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tagsByResource['Microsoft.ManagedIdentity/userAssignedIdentities'] : {})
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

resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' existing = {
  name: keyVaultName
}

resource linkedService_keyVault 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'keyVault'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: keyVault.properties.vaultUri
    }
  }
}

resource linkedService_storageAccount 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'storage'
  parent: dataFactory
  properties: {
    annotations: []
    parameters: {}
    type: 'AzureBlobFS'
    typeProperties: {
      url: storageAccount.properties.primaryEndpoints.dfs
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
      convertToParquet ? {} : datasetPropsDelimitedText,
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

// Create trigger
resource trigger_msexports_FileAdded 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${safeExportContainerName}_FileAdded'
  parent: dataFactory
  dependsOn: [
    stopHubTriggers
    pipeline_ExecuteETL
  ]
  properties: {
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: '${exportContainerName}_ExecuteETL'
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

resource pipeline_ExecuteETL 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_ExecuteETL'
  parent: dataFactory
  dependsOn: [
    pipeline_msexports_ETL_ingestion
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
            referenceName: '${safeExportContainerName}_ETL_${safeIngestionContainerName}'
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
// Export container transform pipeline
// Trigger: pipeline_ExecuteETL
//
// Converts CSV files to Parquet or .CSV.GZ files.
//------------------------------------------------------------------------------

resource pipeline_msexports_ETL_ingestion 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${safeExportContainerName}_ETL_${safeIngestionContainerName}'
  parent: dataFactory
  dependsOn: [
    dataset_msexports
    dataset_ingestion
  ]
  properties: {
    activities: [
      // (start) -> Wait -> FolderArray -> Scope -> Metric -> Date -> File -> Folder -> Delete Target -> Convert CSV -> Delete CSV -> (end)
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
      // Set FolderArray
      {
        name: 'Set FolderArray'
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
          variableName: 'folderArray'
          value: {
            value: '@split(pipeline().parameters.folderName, \'/\')'
            type: 'Expression'
          }
        }
      }
      // Set Scope
      {
        name: 'Set Scope'
        type: 'SetVariable'
        dependsOn: [
          {
            activity: 'Set FolderArray'
            dependencyConditions: [
              'Completed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          variableName: 'scope'
          value: {
            value: '@replace(split(pipeline().parameters.folderName,variables(\'folderArray\')[sub(length(variables(\'folderArray\')), 3)])[0],\'${exportContainerName}\',\'${ingestionContainerName}\')'
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
            // TODO: Parse metric out of the export path with self-managed exports -- value: '@first(split(variables(\'folderArray\')[sub(length(variables(\'folderArray\')), 4)], \'-\'))'
            value: 'focuscost'
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
            value: '@substring(variables(\'folderArray\')[sub(length(variables(\'folderArray\')), 2)], 0, 6)'
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
          translator: {
            type: 'TabularTranslator'
            mappings: focusCostMappings
          }
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
      folderArray: {
        type: 'Array'
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
    trigger_msexports_FileAdded
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

// resource removeManagedIdentity_triggerManager 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'removeManagedIdentity_triggerManager'
//   kind: 'AzurePowerShell'
//   location: location
//   tags: tags
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${identity.id}': {}
//     }
//   }
//   dependsOn: [
//     identityRoleAssignments
//     trigger_msexports_FileAdded
//     startHubTriggers
//   ]
//   properties: {
//     azPowerShellVersion: '8.0'
//     retentionInterval: 'PT1H'
//     environmentVariables: [
//       {
//         name: 'managedIdentityName'
//         value: identity.name
//       }
//       {
//         name: 'resourceGroupName'
//         value: resourceGroup().name
//       }
//       {
//         name: 'dataFactoryName'
//         value: dataFactoryName
//       }
//     ]
//     scriptContent: loadTextContent('./scripts/Remove-ManagedIdentity.ps1')
//     arguments: '-dataFactory'
//   }
// }

//==============================================================================
// Outputs
//==============================================================================

@description('The Resource ID of the Data factory.')
output resourceId string = dataFactory.id

@description('The Name of the Azure Data Factory instance.')
output name string = dataFactory.name
