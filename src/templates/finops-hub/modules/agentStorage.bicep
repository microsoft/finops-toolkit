// Creates a storage account, private endpoints and DNS zones
@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool

@description('Name of the storage account')
param storageName string

@description('Name of the storage blob private link endpoint')
param storagePleBlobName string

@description('Name of the storage file private link endpoint')
param storagePleFileName string

@description('Resource ID of the subnet')
param privateEndpointSubnetId string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])

@description('Storage SKU')
param storageSkuName string = 'Standard_LRS'

var storageNameCleaned = replace(storageName, '-', '')

var blobPrivateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'

var filePrivateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageNameCleaned
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Storage/storageAccounts'] ?? {})
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePublicAccess ? 'Allow' : 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource storagePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2024-05-01' = if (!enablePublicAccess) {
  name: storagePleBlobName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      { 
        name: storagePleBlobName
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: storage.id
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

resource storagePrivateEndpointFile 'Microsoft.Network/privateEndpoints@2024-05-01' = if (!enablePublicAccess) {
  name: storagePleFileName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      {
        name: storagePleFileName
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: storage.id
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enablePublicAccess) {
  name: blobPrivateDnsZoneName
  //location: 'global'
}

resource blobPrivateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!enablePublicAccess) {
  parent: storagePrivateEndpointBlob
  name: 'blob-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: blobPrivateDnsZoneName
        properties:{
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enablePublicAccess) {
  name: filePrivateDnsZoneName
  //location: 'global'
}

resource filePrivateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!enablePublicAccess) {
  parent: storagePrivateEndpointFile
  name: 'file-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: filePrivateDnsZoneName
        properties:{
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

output storageId string = storage.id
output storageName string = storage.name
