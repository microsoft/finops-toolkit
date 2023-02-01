// Source: https://github.com/Azure/ResourceModules/blob/main/modules/Microsoft.Storage/storageAccounts/deploy.bicep
// Date: 2023-02-01
// Version: 0.9

@maxLength(24)
@description('Required. Name of the Storage Account.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage Account Sku Name.')
param storageAccountSku string = 'Premium_LRS'

@allowed([
  'Hot'
  'Cool'
])
@description('Optional. Storage Account Access Tier.')
param storageAccountAccessTier string = 'Hot'

@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpoints array = []

@description('Optional. Networks ACLs, this value contains IPs to whitelist and/or Subnet information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. Blob service and containers to deploy.')
param blobServices object = {}

@description('Optional. Indicates whether public access is enabled for all blobs or containers in the storage account. For security reasons, it is recommended to set it to false.')
param allowBlobPublicAccess bool = false

@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
@description('Optional. Set the minimum TLS version on request to storage.')
param minimumTlsVersion string = 'TLS1_2'

@description('Optional. If true, enables Secure File Transfer Protocol for the storage account. Requires enableHierarchicalNamespace to be true.')
param enableSftp bool = false

@description('Optional. If true, enables NFS 3.0 support for the storage account. Requires enableHierarchicalNamespace to be true.')
param enableNfsV3 bool = false

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

@description('Optional. Whether or not public network access is allowed for this resource. For security reasons it should be disabled. If not specified, it will be disabled by default if private endpoints are set and networkAcls are not set.')
@allowed([
  ''
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = ''

@description('Optional. Allows HTTPS traffic only to storage service if sets to true.')
param supportsHttpsTrafficOnly bool = true

var enableReferencedModulesTelemetry = false

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  kind: 'BlockBlobStorage'
  sku: {
    name: storageAccountSku
  }
  tags: tags
  properties: {
    accessTier: storageAccountAccessTier
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    isHnsEnabled: true
    isSftpEnabled: enableSftp
    isNfsV3Enabled: enableNfsV3
    minimumTlsVersion: minimumTlsVersion
    networkAcls: !empty(networkAcls) ? {
      bypass: contains(networkAcls, 'bypass') ? networkAcls.bypass : null
      defaultAction: contains(networkAcls, 'defaultAction') ? networkAcls.defaultAction : null
      virtualNetworkRules: contains(networkAcls, 'virtualNetworkRules') ? networkAcls.virtualNetworkRules : []
      ipRules: contains(networkAcls, 'ipRules') ? networkAcls.ipRules : []
    } : null
    allowBlobPublicAccess: allowBlobPublicAccess
    publicNetworkAccess: !empty(publicNetworkAccess) ? any(publicNetworkAccess) : (!empty(privateEndpoints) && empty(networkAcls) ? 'Disabled' : null)
  }
}

// Containers
module storageAccount_blobServices 'blobServices/deploy.bicep' = if (!empty(blobServices)) {
  name: '${uniqueString(deployment().name, location)}-Storage-BlobServices'
  params: {
    storageAccountName: storageAccount.name
    containers: contains(blobServices, 'containers') ? blobServices.containers : []
    automaticSnapshotPolicyEnabled: contains(blobServices, 'automaticSnapshotPolicyEnabled') ? blobServices.automaticSnapshotPolicyEnabled : false
    deleteRetentionPolicy: contains(blobServices, 'deleteRetentionPolicy') ? blobServices.deleteRetentionPolicy : true
    deleteRetentionPolicyDays: contains(blobServices, 'deleteRetentionPolicyDays') ? blobServices.deleteRetentionPolicyDays : 7
    diagnosticLogsRetentionInDays: contains(blobServices, 'diagnosticLogsRetentionInDays') ? blobServices.diagnosticLogsRetentionInDays : 365
    diagnosticStorageAccountId: contains(blobServices, 'diagnosticStorageAccountId') ? blobServices.diagnosticStorageAccountId : ''
    diagnosticEventHubAuthorizationRuleId: contains(blobServices, 'diagnosticEventHubAuthorizationRuleId') ? blobServices.diagnosticEventHubAuthorizationRuleId : ''
    diagnosticEventHubName: contains(blobServices, 'diagnosticEventHubName') ? blobServices.diagnosticEventHubName : ''
    diagnosticLogCategoriesToEnable: contains(blobServices, 'diagnosticLogCategoriesToEnable') ? blobServices.diagnosticLogCategoriesToEnable : []
    diagnosticMetricsToEnable: contains(blobServices, 'diagnosticMetricsToEnable') ? blobServices.diagnosticMetricsToEnable : []
    diagnosticWorkspaceId: contains(blobServices, 'diagnosticWorkspaceId') ? blobServices.diagnosticWorkspaceId : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}

@description('The resource ID of the deployed storage account.')
output resourceId string = storageAccount.id

@description('The name of the deployed storage account.')
output name string = storageAccount.name

@description('The resource group of the deployed storage account.')
output resourceGroupName string = resourceGroup().name

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryBlobEndpoint string = !empty(blobServices) && contains(blobServices, 'containers') ? reference('Microsoft.Storage/storageAccounts/${storageAccount.name}', '2019-04-01').primaryEndpoints.blob : ''

@description('The location the resource was deployed into.')
output location string = storageAccount.location
