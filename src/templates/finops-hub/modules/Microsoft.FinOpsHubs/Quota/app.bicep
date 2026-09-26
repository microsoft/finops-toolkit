// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { getAppPublisherTags, HubAppProperties } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'

param app HubAppProperties
param coreApp HubAppProperties
param core CoreMetadata
param coreStorageAccountName string
param exportStorageAccountName string

var functionName = take(replace('${app.hub.name}-quota-${app.suffix}', '_', '-'), 60)
var hostStorageName = 'ftkq${uniqueString(resourceGroup().id, app.storage)}'
var packageFiles = {
  'host.json': loadTextContent('host.json')
  'CollectQuota/function.json': loadTextContent('CollectQuota/function.json')
  'CollectQuota/run.ps1': loadTextContent('CollectQuota/run.ps1')
  'AzVMQuotaUsage/AzVMQuotaUsage.psm1': loadTextContent('AzVMQuotaUsage/AzVMQuotaUsage.psm1')
  'AzVMQuotaUsage/Private/Get-ArmCollection.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-ArmCollection.ps1')
  'AzVMQuotaUsage/Private/Get-ArmResponses.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-ArmResponses.ps1')
  'AzVMQuotaUsage/Private/Get-Locations.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-Locations.ps1')
  'AzVMQuotaUsage/Private/Get-QuotaDetails.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-QuotaDetails.ps1')
  'AzVMQuotaUsage/Private/Get-ResourceDetails.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-ResourceDetails.ps1')
  'AzVMQuotaUsage/Private/Get-SnapshotHash.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-SnapshotHash.ps1')
  'AzVMQuotaUsage/Private/Get-Subscriptions.ps1': loadTextContent('AzVMQuotaUsage/Private/Get-Subscriptions.ps1')
  'AzVMQuotaUsage/Public/Get-AzVMQuotaUsage.ps1': loadTextContent('AzVMQuotaUsage/Public/Get-AzVMQuotaUsage.ps1')
  'AzVMQuotaUsage/Public/Get-SavingsPlanRecommendations.ps1': loadTextContent('AzVMQuotaUsage/Public/Get-SavingsPlanRecommendations.ps1')
}
var packageBlob = 'quota/${uniqueString(string(packageFiles))}/released-package.zip'
var deploymentContainer = 'quota${app.suffix}'
var hostStorageRoles = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
]

resource hostStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: hostStorageName
  location: app.hub.location
  tags: getAppPublisherTags(app, 'Microsoft.Storage/storageAccounts')
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }

  resource blobService 'blobServices' = {
    name: 'default'
    resource packageContainer 'containers' = {
      name: deploymentContainer
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource hostStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in hostStorageRoles: {
  name: guid(hostStorage.id, core.recommendationsIdentity.id, role)
  scope: hostStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: core.recommendationsIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource coreStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: coreStorageAccountName
}

resource coreStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(coreStorage.id, core.recommendationsIdentity.id, '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  scope: coreStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: core.recommendationsIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource exportStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: exportStorageAccountName
}

resource exportStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(exportStorage.id, core.recommendationsIdentity.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: exportStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: core.recommendationsIdentity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${functionName}-plan'
  location: app.hub.location
  tags: getAppPublisherTags(app, 'Microsoft.Web/serverfarms')
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionName
  location: app.hub.location
  tags: getAppPublisherTags(app, 'Microsoft.Web/sites')
  kind: 'functionapp,linux'
  dependsOn: [
    coreStorageRole
    exportStorageRole
    hostStorageRole
    hostStorage::blobService::packageContainer
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${core.recommendationsIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${hostStorage.name}.blob.${environment().suffixes.storage}/${deploymentContainer}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: core.recommendationsIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 1
      }
      runtime: {
        name: 'powershell'
        version: '7.4'
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'AzureWebJobsStorage__blobServiceUri', value: 'https://${hostStorage.name}.blob.${environment().suffixes.storage}' }
        { name: 'AzureWebJobsStorage__queueServiceUri', value: 'https://${hostStorage.name}.queue.${environment().suffixes.storage}' }
        { name: 'AzureWebJobsStorage__tableServiceUri', value: 'https://${hostStorage.name}.table.${environment().suffixes.storage}' }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: reference(core.recommendationsIdentity.id, '2023-01-31').clientId }
        { name: 'AZURE_CLIENT_ID', value: reference(core.recommendationsIdentity.id, '2023-01-31').clientId }
        { name: 'AZURE_TENANT_ID', value: subscription().tenantId }
        { name: 'HUB_STORAGE_ACCOUNT', value: coreStorageAccountName }
        { name: 'EXPORT_STORAGE_ACCOUNT', value: exportStorageAccountName }
        { name: 'HUB_SETTINGS_CONTAINER', value: core.settings.container }
        { name: 'HUB_SETTINGS_FILE', value: core.settings.file }
      ]
    }
  }
}

module upload '../../fx/hub-deploymentScript.bicep' = {
  name: 'Microsoft.FinOpsHubs.Quota_Upload'
  params: {
    app: coreApp
    identityName: '${coreStorageAccountName}_blobManager'
    scriptName: '${coreStorageAccountName}_uploadQuotaPackage'
    scriptContent: loadTextContent('Upload-FunctionPackage.ps1')
    environmentVariables: [
      { name: 'storageAccountName', value: coreStorageAccountName }
      { name: 'containerName', value: core.settings.container }
      { name: 'blobName', value: packageBlob }
      { name: 'files', value: string(packageFiles) }
    ]
  }
}

resource packageDeployment 'Microsoft.Web/sites/extensions@2022-09-01' = {
  parent: functionApp
  name: 'onedeploy'
  location: app.hub.location
  properties: {
    packageUri: upload.outputs.scriptOutputs.packageUri
    remoteBuild: false
  }
}
