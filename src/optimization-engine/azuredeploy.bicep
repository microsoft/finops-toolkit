targetScope = 'subscription'
param rgName string
param readerRoleAssignmentGuid string = guid(subscription().subscriptionId, rgName)
param contributorRoleAssignmentGuid string = guid(rgName)
param projectLocation string

@description('The base URI where artifacts required by this template are located')
param templateLocation string

param storageAccountName string
param automationAccountName string
param sqlServerName string
param sqlDatabaseName string = 'azureoptimization'
param logAnalyticsReuse bool
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param logAnalyticsRetentionDays int = 120
param sqlBackupRetentionDays int = 7
param sqlAdminLogin string

@secure()
param sqlAdminPassword string
param cloudEnvironment string = 'AzureCloud'
param authenticationOption string = 'ManagedIdentity'

@description('Base time for all automation runbook schedules.')
param baseTime string = utcNow('u')
param resourceTags object

param roleReader string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

var telemetryId = '00f120b5-2007-6120-0000-0041004f0045'
var finOpsToolkitVersion = loadTextContent('ftkver.txt')

//------------------------------------------------------------------------------
// Telemetry
// Used to anonymously count the number of times the template has been deployed
// and to track and fix deployment bugs to ensure the highest quality.
// No information about you or your cost data is collected.
//------------------------------------------------------------------------------

resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, projectLocation)}'
  location: projectLocation
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FinOps toolkit'
          version: finOpsToolkitVersion
        }
      }
      resources: []
    }
  }
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: projectLocation
  tags: resourceTags
  dependsOn: []
}

module resourcesDeployment './azuredeploy-nested.bicep' = {
  name: 'resourcesDeployment'
  scope: resourceGroup(rgName)
  params: {
    projectLocation: projectLocation
    templateLocation: templateLocation
    storageAccountName: storageAccountName
    automationAccountName: automationAccountName
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    logAnalyticsReuse: logAnalyticsReuse
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRG: logAnalyticsWorkspaceRG
    logAnalyticsRetentionDays: logAnalyticsRetentionDays
    sqlBackupRetentionDays: sqlBackupRetentionDays
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    cloudEnvironment: cloudEnvironment
    authenticationOption: authenticationOption
    baseTime: baseTime
    contributorRoleAssignmentGuid: contributorRoleAssignmentGuid
    resourceTags: resourceTags
  }
  dependsOn: [
    rg
  ]
}

resource readerRoleAssignmentGuid_resource 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: readerRoleAssignmentGuid
  properties: {
    roleDefinitionId: roleReader
    principalId: resourcesDeployment.outputs.automationPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output automationPrincipalId string = resourcesDeployment.outputs.automationPrincipalId
