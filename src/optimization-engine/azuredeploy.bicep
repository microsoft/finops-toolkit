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
param sqlServerAlreadyExists bool = false
param sqlDatabaseName string = 'azureoptimization'
param logAnalyticsReuse bool
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceRG string
param logAnalyticsRetentionDays int = 120
param sqlBackupRetentionDays int = 7
param userPrincipalName string
param userObjectId string
param sqlAdminPrincipalType string = 'User'
param cloudEnvironment string = 'AzureCloud'
param authenticationOption string = 'ManagedIdentity'

@description('Base time for all automation runbook schedules.')
param baseTime string = utcNow('u')
param resourceTags object

param roleReader string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

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
    sqlServerAlreadyExists: sqlServerAlreadyExists
    sqlDatabaseName: sqlDatabaseName
    logAnalyticsReuse: logAnalyticsReuse
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRG: logAnalyticsWorkspaceRG
    logAnalyticsRetentionDays: logAnalyticsRetentionDays
    sqlBackupRetentionDays: sqlBackupRetentionDays
    cloudEnvironment: cloudEnvironment
    authenticationOption: authenticationOption
    baseTime: baseTime
    contributorRoleAssignmentGuid: contributorRoleAssignmentGuid
    resourceTags: resourceTags
    userPrincipalName: userPrincipalName
    userObjectId: userObjectId
    sqlAdminPrincipalType: sqlAdminPrincipalType
    enableDefaultTelemetry: enableDefaultTelemetry
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
