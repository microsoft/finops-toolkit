//==============================================================================
// Parameters
//==============================================================================

@description('Required. The name of the parent Azure Data Factory.')
param dataFactoryName string

@description('Required. The ID of the storage account.')
param storageAccountId string

@description('Required. The name of the pipeline to execute.')
param pipelineName string

@description('Required. Container to monitor.')
param blobContainerName string

@description('Required. Trigger name.')
param triggerName string

@description('Optional. The description for the trigger.')
param triggerDesc string

@description('Optional. Indicates whether the trigger should be started on creation. Default = false.')
param autoStart bool = false

@description('Optional. The location to use for the managed identity and deployment script to auto-start the trigger, if autoStart is enabled. Default = (resource group location).')
param autoStartLocation string = resourceGroup().location

// Only define roles if autoStart is enabled
var rbacRolesNeeded = [
  '673868aa-7521-48a0-acc6-0f60742d39f5' // Data Factory contributor - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor
]

//==============================================================================
// Resources
//==============================================================================

// Get data factory instance
resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

// Create managed identity to start/stop the trigger
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${dataFactoryName}_${triggerName}_starter'
  location: autoStartLocation
}

// Assign access to the identity
resource rbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in rbacRolesNeeded: {
  name: guid(dataFactoryRef.id, role, identity.id)
  scope: dataFactoryRef
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Stop the trigger if it's already running
// Start the trigger
resource stopTrigger 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${dataFactoryName}_${triggerName}_stop'
  location: autoStartLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    rbac
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('../scripts/Start-Triggers.ps1')
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
        value: join([ triggerName ], '|')
      }
    ]
  }
}

// Create trigger
resource trigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: triggerName
  parent: dataFactoryRef
  properties: {
    description: triggerDesc
    annotations: []
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipelineName
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
      blobPathBeginsWith: '/${blobContainerName}/'
      blobPathEndsWith: '.csv'
      ignoreEmptyBlobs: true
      scope: storageAccountId
      events: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

// Start the trigger
resource startTrigger 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (autoStart) {
  name: '${dataFactoryName}_${triggerName}_start'
  location: autoStartLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  dependsOn: [
    rbac
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    scriptContent: loadTextContent('../scripts/Start-Triggers.ps1')
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
        value: join([ triggerName ], '|')
      }
    ]
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The name of the linked service.')
output name string = trigger.name

@description('The resource ID of the linked service.')
output resourceId string = trigger.id
