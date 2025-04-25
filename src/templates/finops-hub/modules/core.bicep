// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Types
//==============================================================================

type ScriptInfo = {
  name: string
  db: string
  script: string
  dependsOn: string[]?
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the FinOps hub instance.')
param hubName string

@description('Required. Name of the Data Factory instance.')
param dataFactoryName string

@description('Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).')
param clusterName string = ''

@description('Optional. Azure location to use for the managed identity and deployment script to auto-start triggers. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. Number of days of data to retain in the Data Explorer *_raw tables. Default: 0.')
param rawRetentionInDays int = 0

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

@description('Optional. An short telemetry string to log feature usage. Nothing is identifiable.')
param telemetryString string = ''

@description('Do not change. This is an internal parameter that should not be changed.')
param _databaseScripts ScriptInfo[] = [
  // {
  //   name: 'OpenDataFunctions_resource_type_1'
  //   db: 'Ingestion'
  //   script: loadTextContent('scripts/OpenDataFunctions_resource_type_1.kql')
  // }
  // {
  //   name: 'OpenDataFunctions_resource_type_2'
  //   db: 'Ingestion'
  //   script: loadTextContent('scripts/OpenDataFunctions_resource_type_2.kql')
  // }
  // {
  //   name: 'OpenDataFunctions_resource_type_3'
  //   db: 'Ingestion'
  //   script: loadTextContent('scripts/OpenDataFunctions_resource_type_3.kql')
  // }
  // {
  //   name: 'OpenDataFunctions_resource_type_4'
  //   db: 'Ingestion'
  //   script: loadTextContent('scripts/OpenDataFunctions_resource_type_4.kql')
  // }
  // {
  //   name: 'OpenDataFunctions'
  //   db: 'Ingestion'
  //   dependsOn: [
  //     'OpenDataFunctions_resource_type_1'
  //     'OpenDataFunctions_resource_type_2'
  //     'OpenDataFunctions_resource_type_3'
  //     'OpenDataFunctions_resource_type_4'
  //   ]
  //   script: loadTextContent('scripts/OpenDataFunctions.kql')
  // }
  // {
  //   name: 'IngestionCommon'
  //   db: 'Ingestion'
  //   script: loadTextContent('scripts/Common.kql')
  // }
  // {
  //   name: 'IngestionSetup'
  //   db: 'Ingestion'
  //   dependsOn: [
  //     'OpenDataFunctions'
  //     'IngestionCommon'
  //   ]
  //   script: loadTextContent('scripts/IngestionSetup.kql')
  // }
  // {
  //   name: 'HubCommon'
  //   db: 'Hub'
  //   script: loadTextContent('scripts/Common.kql')
  // }
  // {
  //   name: 'HubSetup'
  //   db: 'Hub'
  //   dependsOn: [
  //     'IngestionSetup'
  //     'HubCommon'
  //   ]
  //   script: loadTextContent('scripts/HubSetup.kql')
  // }
]


//==============================================================================
// Variables
//==============================================================================

var deployDataExplorer = !empty(clusterName)

var dependencyPrefix = '{activity:\'Run '
var dependencySuffix = ' Script\', dependencyConditions:[\'Succeeded\']}'
func adfActivityDependencies(dependsOn string[]) array => json('[${dependencyPrefix}${join(dependsOn, '${dependencySuffix},${dependencyPrefix}')}${dependencySuffix}]')

// cSpell:ignore ftkver
var ftkver = any(loadTextContent('ftkver.txt')) // any() is used to suppress a warning the array size (only happens when version does not contain a dash)
var ftkVersion = contains(ftkver, '-') ? split(ftkver, '-')[0] : ftkver
var ftkBranch = contains(ftkver, '-') ? split(ftkver, '-')[1] : ''

// The last segment of the GUID in the telemetryId (40b) is used to identify this module
// Remaining characters identify settings; must be <= 12 chars -- Example: (guid)_RLXD##x1000P
var telemetryId = '00f120b5-2007-6120-0000-40b000000000'


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// App registration
//------------------------------------------------------------------------------

module appRegistration 'hub-app.bicep' = {
  name: 'pid-${telemetryId}_${telemetryString}_${uniqueString(deployment().name, location)}'
  params: {
    hubName: hubName
    publisher: 'FinOps hubs'
    namespace: 'Microsoft.FinOpsToolkit.Hubs'
    appName: 'Core'
    displayName: 'FinOps hub core'
    appVersion: ftkver
    telemetryString: telemetryString
    enableDefaultTelemetry: enableDefaultTelemetry
  }
}

//------------------------------------------------------------------------------
// Existing resources
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = if (deployDataExplorer) {
  name: dataFactoryName

  resource dataExplorerService 'linkedservices' existing = {
    name: 'hubDataExplorer'
  }
}

resource triggerManagerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (deployDataExplorer) {
  name: '${dataFactory.name}_triggerManager'
}

resource cluster 'Microsoft.Kusto/clusters@2023-08-15' existing = {
  name: clusterName

  resource ingestionDb 'databases' existing = {
    name: 'Ingestion'
  }

  resource hubDb 'databases' existing = {
    name: 'Hub'
  }
}

//------------------------------------------------------------------------------
// dataExplorer_IngestionSetup pipeline
//------------------------------------------------------------------------------

// TODO: Merge with InitializeHub pipeline
resource pipeline_Setup 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = if (deployDataExplorer) {
  name: 'dataExplorer_Setup'
  parent: dataFactory
  properties: {
    activities: [
      { // Until Capacity Is Available
        name: 'Until Capacity Is Available'
        type: 'Until'
        dependsOn: []
        userProperties: []
        typeProperties: {
          expression: {
            value: '@equals(variables(\'tryAgain\'), false)'
            type: 'Expression'
          }
          activities: [
            { // Confirm Ingestion Capacity
              name: 'Confirm Ingestion Capacity'
              type: 'AzureDataExplorerCommand'
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
                // cSpell:ignore Ingestions
                command: '.show capacity | where Resource == "Ingestions" | project Remaining'
                commandTimeout: '00:20:00'
              }
              linkedServiceName: {
                referenceName: dataFactory::dataExplorerService.name
                type: 'LinkedServiceReference'
                parameters: {
                  database: cluster::ingestionDb.name
                }
              }
            }
            { // If Has Capacity
              name: 'If Has Capacity'
              type: 'IfCondition'
              dependsOn: [
                {
                  activity: 'Confirm Ingestion Capacity'
                  dependencyConditions: [
                    'Succeeded'
                  ]
                }
              ]
              userProperties: []
              typeProperties: {
                expression: {
                  value: '@or(equals(activity(\'Confirm Ingestion Capacity\').output.count, 0), greater(activity(\'Confirm Ingestion Capacity\').output.value[0].Remaining, 0))'
                  type: 'Expression'
                }
                ifFalseActivities: [
                  { // Wait for Ingestion
                    name: 'Wait for Ingestion'
                    type: 'Wait'
                    dependsOn: []
                    userProperties: []
                    typeProperties: {
                      waitTimeInSeconds: 15
                    }
                  }
                  { // Try Again
                    name: 'Try Again'
                    type: 'SetVariable'
                    dependsOn: [
                      {
                        activity: 'Wait for Ingestion'
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
                      variableName: 'tryAgain'
                      value: true
                    }
                  }
                ]
                ifTrueActivities: [for item in _databaseScripts: {
                  name: 'Run ${item.name} Script'
                  type: 'AzureDataExplorerCommand'
                  dependsOn: empty(item.?dependsOn) ? [] : adfActivityDependencies(item.?dependsOn!)
                  policy: {
                    timeout: '0.12:00:00'
                    retry: 0
                    retryIntervalInSeconds: 30
                    secureOutput: false
                    secureInput: false
                  }
                  userProperties: []
                  typeProperties: {
                    command: replace(replace(replace(replace(item.script,
                      '$$adfPrincipalId$$', dataFactory.identity.principalId),
                      '$$adfTenantId$$', dataFactory.identity.tenantId),
                      '$$ftkOpenDataFolder$$', empty(ftkBranch) ? 'https://github.com/microsoft/finops-toolkit/releases/download/v${ftkVersion}' : 'https://raw.githubusercontent.com/microsoft/finops-toolkit/${ftkBranch}/src/open-data'),
                      '$$rawRetentionInDays$$', string(rawRetentionInDays))
                    commandTimeout: '00:20:00'
                  }
                  linkedServiceName: {
                    referenceName: dataFactory::dataExplorerService.name
                    type: 'LinkedServiceReference'
                    parameters: {
                      database: item.db
                    }
                  }
                }]
              }
            }
            { // Abort On Error
              name: 'Abort On Error'
              type: 'SetVariable'
              dependsOn: [
                {
                  activity: 'If Has Capacity'
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
                variableName: 'tryAgain'
                value: false
              }
            }
          ]
          timeout: '0.02:00:00'
        }
      }
      { // Timeout Error
        name: 'Timeout Error'
        type: 'Fail'
        dependsOn: [
          {
            activity: 'Until Capacity Is Available'
            dependencyConditions: [
                'Failed'
            ]
          }
        ]
        userProperties: []
        typeProperties: {
          message: 'Data Explorer ingestion timed out after 2 hours while waiting for available capacity. Please re-run this pipeline to re-attempt ingestion. If you continue to see this error, please report an issue at https://aka.ms/ftk/ideas.'
          errorCode: 'DataExplorerIngestionTimeout'
        }
      }
    ]
    concurrency: 1
    variables: {
      tryAgain: {
        type: 'Boolean'
        defaultValue: true
      }
    }
  }
}

resource startDataExplorerSetup 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (deployDataExplorer) {
  name: '${dataFactory.name}_startDataExplorerSetup'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  tags: union(tags, tagsByResource[?'Microsoft.Resources/deploymentScripts'] ?? {})
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${triggerManagerIdentity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
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
        name: 'Pipelines'
        value: join([ pipeline_Setup.name ], '|')
      }
    ]
  }
}


//==============================================================================
// Outputs
//==============================================================================

output dataExplorerSetupPipelineName string = (deployDataExplorer) ? pipeline_Setup.name : ''
