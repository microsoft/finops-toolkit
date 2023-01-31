// Source: https://github.com/Azure/ResourceModules/blob/main/modules/Microsoft.Storage/storageAccounts/deploy.bicep
// Date: 2023-02-01
// Version: 0.9

@maxLength(24)
@description('Required. Name of the Storage Account.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Optional. Storage Account Sku Name.')
param storageAccountSku string = 'Standard_GRS'

@allowed([
  'Hot'
  'Cool'
])
@description('Optional. Storage Account Access Tier.')
param storageAccountAccessTier string = 'Hot'

@allowed([
  'Disabled'
  'Enabled'
])
@description('Optional. Allow large file shares if sets to \'Enabled\'. It cannot be disabled once it is enabled. Only supported on locally redundant and zone redundant file shares. It cannot be set on FileStorage storage accounts (storage accounts for premium file shares).')
param largeFileSharesState string = 'Disabled'

@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpoints array = []

@description('Optional. Networks ACLs, this value contains IPs to whitelist and/or Subnet information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. A Boolean indicating whether or not the service applies a secondary layer of encryption with platform managed keys for data at rest. For security reasons, it is recommended to set it to true.')
param requireInfrastructureEncryption bool = true

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

@description('Conditional. If true, enables Hierarchical Namespace for the storage account. Required if enableSftp or enableNfsV3 is set to true.')
param enableHierarchicalNamespace bool = false

@description('Optional. If true, enables Secure File Transfer Protocol for the storage account. Requires enableHierarchicalNamespace to be true.')
param enableSftp bool = false

@description('Optional. If true, enables NFS 3.0 support for the storage account. Requires enableHierarchicalNamespace to be true.')
param enableNfsV3 bool = false

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
@minValue(0)
@maxValue(365)
param diagnosticLogsRetentionInDays int = 365

@description('Optional. Resource ID of the diagnostic storage account.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace.')
param diagnosticWorkspaceId string = ''

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category.')
param diagnosticEventHubName string = ''

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

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'Transaction'
])
param diagnosticMetricsToEnable array = [
  'Transaction'
]

@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${name}-diagnosticSettings'

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

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

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: name
  location: location
  kind: 'BlockBlobStorage'
  sku: {
    name: storageAccountSku
  }
  tags: tags
  properties: {
    encryption: {
      services: {
        blob: { enabled: true }
        file: null
        table: {
          enabled: true
        }
        queue: {
          enabled: true
        }
      }
      requireInfrastructureEncryption: requireInfrastructureEncryption
    }
    accessTier: storageAccountAccessTier
    supportsHttpsTrafficOnly: supportsHttpsTrafficOnly
    isHnsEnabled: enableHierarchicalNamespace ? enableHierarchicalNamespace : null
    isSftpEnabled: enableSftp
    isNfsV3Enabled: enableNfsV3
    largeFileSharesState: (storageAccountSku == 'Standard_LRS') || (storageAccountSku == 'Standard_ZRS') ? largeFileSharesState : null
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

resource storageAccount_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(diagnosticEventHubAuthorizationRuleId)) || (!empty(diagnosticEventHubName))) {
  name: diagnosticSettingsName
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    metrics: diagnosticsMetrics
  }
  scope: storageAccount
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
