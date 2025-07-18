// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { getAppTags, getPublisherTags, HubAppProperties, HubAppFeature, HubProperties, newApp } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub instance properties.')
param hub HubProperties

@description('Required. Display name of the FinOps hub app publisher.')
param publisher string

@description('Required. Namespace to use for the FinOps hub app publisher. Will be combined with appName to form a fully-qualified identifier. Must be an alphanumeric string without spaces or special characters except for periods. This value should never change and will be used to uniquely identify the publisher. A change would require migrating content to the new publisher. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param namespace string

@description('Required. Unique identifier of the FinOps hub app within the publisher namespace. Must be an alphanumeric string without spaces or special characters. This name should never change and will be used with the namespace to fully qualify the app. A change would require migrating content to the new app. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param appName string

@description('Required. Display name of the FinOps hub app.')
param displayName string

@description('Optional. Version number of the FinOps hub app.')
param appVersion string = ''

// @description('Required. Minimum version number supported by the FinOps hub app.')
// param hubMinVersion string

// @description('Required. Maximum version number supported by the FinOps hub app.')
// param hubMaxVersion string

@description('Optional. Indicate which features the app requires. Allowed values: "Storage". Default: [] (none).')
param features HubAppFeature[] = []

@description('Optional. Custom string with additional metadata to log. Must an alphanumeric string without spaces or special characters except for underscores and dashes. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param telemetryString string = ''


//==============================================================================
// Variables
//==============================================================================

var app = newApp(hub, publisher, namespace, appName, displayName, appVersion)

// Features
var usesDataFactory = contains(features, 'DataFactory')
var usesKeyVault = contains(features, 'KeyVault')
var usesStorage = contains(features, 'Storage')

// App telemetry
var telemetryId = 'ftk-hubapp-${app.name}${empty(telemetryString) ? '' : '_'}${telemetryString}'  // cSpell:ignore hubapp
var telemetryProps = {
  mode: 'Incremental'
  template: {
    '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
    contentVersion: '1.0.0.0'
    metadata: {
      _generator: {
        name: 'FTK: ${publisher} - ${displayName} ${telemetryId}'
        version: appVersion
      }
    }
    resources: []
  }
}

// Storage infrastructure encryption
var storageInfrastructureEncryptionProperties = !hub.options.storageInfrastructureEncryption ? {} : {
  encryption: {
    keySource: 'Microsoft.Storage'
    requireInfrastructureEncryption: hub.options.storageInfrastructureEncryption
  }
}

// KeyVault access policies
var keyVaultAccessPolicies = [
  {
    objectId: dataFactory.identity.principalId
    tenantId: subscription().tenantId
    permissions: { secrets: ['get'] }
  }
]


//==============================================================================
// Resources
//==============================================================================

// TODO: Get hub instance to verify version compatibility

//------------------------------------------------------------------------------
// Telemetry
// Used to anonymously count the number of times the template has been deployed
// and to track and fix deployment bugs to ensure the highest quality.
// No information about you or your cost data is collected.
//------------------------------------------------------------------------------

resource appTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (hub.options.enableTelemetry) {
  name: length(telemetryId) <= 64 ? telemetryId : substring(telemetryId, 0, 64)
  tags: getAppTags(app, 'Microsoft.Resources/deployments', true)
  properties: telemetryProps
}

//------------------------------------------------------------------------------
// TODO: Get hub details
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Data Factory
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = if (usesDataFactory) {
  name: app.dataFactory
  location: app.hub.location
  tags: getPublisherTags(app, 'Microsoft.DataFactory/factories')
  identity: { type: 'SystemAssigned' }
  properties: any({ // Using any() to hide the error that gets surfaced because globalConfigurations is not in the ADF schema yet
      globalConfigurations: {
        PipelineBillingEnabled: 'true'
      }
  })
}

//------------------------------------------------------------------------------
// Storage account
//------------------------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = if (usesStorage) {
  name: app.storage
  location: hub.location
  sku: {
    name: hub.options.storageSku
  }
  kind: 'BlockBlobStorage'
  tags: getPublisherTags(app, 'Microsoft.Storage/storageAccounts')
  properties: {
    ...storageInfrastructureEncryptionProperties
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: hub.options.privateRouting ? 'Deny' : 'Allow'
    }
  }

  resource blobService 'blobServices' = {
    name: 'default'
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (usesStorage && hub.options.privateRouting) {
  name: 'privatelink.blob.${environment().suffixes.storage}'  // cSpell:ignore privatelink
}

resource blobEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (usesStorage && hub.options.privateRouting) {
  name: '${storageAccount.name}-blob-ep'
  location: hub.location
  tags: getPublisherTags(app, 'Microsoft.Network/privateEndpoints')
  properties: {
    subnet: {
      id: hub.routing.subnets.storage
    }
    privateLinkServiceConnections: [
      {
        name: 'blobLink'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }

  resource blobPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'storage-endpoint-zone'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: blobPrivateDnsZone.name
          properties: {
            privateDnsZoneId: blobPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource dfsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (usesStorage && hub.options.privateRouting) {
  name: 'privatelink.dfs.${environment().suffixes.storage}'  // cSpell:ignore privatelink
}

resource dfsEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (usesStorage && hub.options.privateRouting) {
  name: '${storageAccount.name}-dfs-ep'
  location: hub.location
  tags: getPublisherTags(app, 'Microsoft.Network/privateEndpoints')
  properties: {
    subnet: {
      id: hub.routing.subnets.storage
    }
    privateLinkServiceConnections: [
      {
        name: 'dfsLink'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['dfs']
        }
      }
    ]
  }

  resource dfsPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'dfs-endpoint-zone'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: dfsPrivateDnsZone.name
          properties: {
            privateDnsZoneId: dfsPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

//------------------------------------------------------------------------------
// KeyVault for secrets
//------------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = if (usesKeyVault) {
  name: app.keyVault
  location: hub.location
  tags: getPublisherTags(app, 'Microsoft.KeyVault/vaults')
  properties: {
    sku: any({
      name: hub.options.keyVaultSku
      family: 'A'
    })
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    createMode: 'default'
    tenantId: subscription().tenantId
    accessPolicies: keyVaultAccessPolicies
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: hub.options.privateRouting ? 'Deny' : 'Allow'
    }
  }
  
  resource keyVault_accessPolicies 'accessPolicies' = {
    name: 'add'
    properties: {
      accessPolicies: keyVaultAccessPolicies
    }
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (usesKeyVault && hub.options.privateRouting) {
  name: 'privatelink${replace(environment().suffixes.keyvaultDns, 'vault', 'vaultcore')}'  // cSpell:ignore privatelink, vaultcore
  location: 'global'
  tags: getPublisherTags(app, 'Microsoft.Network/privateDnsZones')
  properties: {}
  
  resource keyVaultPrivateDnsZoneLink 'virtualNetworkLinks@2024-06-01' = {
    name: '${replace(keyVaultPrivateDnsZone.name, '.', '-')}-link'
    location: 'global'
    tags: getPublisherTags(app, 'Microsoft.Network/privateDnsZones/virtualNetworkLinks')
    properties: {
      virtualNetwork: {
        id: hub.routing.networkId
      }
      registrationEnabled: false
    }
  }
}

resource keyVaultEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (usesKeyVault && hub.options.privateRouting) {
  name: '${keyVault.name}-ep'
  location: hub.location
  tags: getPublisherTags(app, 'Microsoft.Network/privateEndpoints')
  properties: {
    subnet: {
      id: hub.routing.subnets.keyVault
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultLink'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }

  resource keyVaultPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'keyvault-endpoint-zone'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: keyVaultPrivateDnsZone.name
          properties: {
            privateDnsZoneId: keyVaultPrivateDnsZone.id
          }
        }
      ]
	  }
	}
}


//==============================================================================
// Outputs
//==============================================================================

@description('FinOps hub app configuration.')
output app HubAppProperties = app

@description('Principal ID for the managed identity used by Data Factory.')
output principalId string = dataFactory.identity.principalId
