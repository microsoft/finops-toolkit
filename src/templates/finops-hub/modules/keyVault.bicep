// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Required. Suffix to add to the KeyVault instance name to ensure uniqueness.')
param uniqueSuffix string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Array of access policies object.')
param accessPolicies array = []

@description('Required. Name of the storage account to store access keys for.')
param storageAccountName string

@description('Optional. Specifies the SKU for the vault.')
@allowed([
  'premium'
  'standard'
])
param sku string = 'premium'

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. To use Private Endpoints, add target subnet resource Id.')
param subnetResourceId string = ''

@description('Optional. To create networking resources.')
@allowed([
  'Public'
  'Private'
  'PrivateWithExistingNetwork'
])
param networkingOption string = 'Public'

@description('Optional. Id of the created subnet for private endpoints.')
param newsubnetResourceId string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target KeyVault private DNS zone resource Id.')
param keyVaultPrivateDNSZoneName string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target private DNS zones resource group name.')
param privateDNSZonesResourceGroupName string = ''

@description('Optional. Name of the virtual network.')
param virtualNetworkName string = ''

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

// Generate globally unique KeyVault name: 3-24 chars; letters, numbers, dashes
var keyVaultPrefix = '${replace(hubName, '_', '-')}-vault'
var keyVaultSuffix = '-${uniqueSuffix}'
var keyVaultName = replace('${take(keyVaultPrefix, 24 - length(keyVaultSuffix))}${keyVaultSuffix}', '--', '-')

//==============================================================================
// Resources
//==============================================================================
module keyVault 'br/public:avm/res/key-vault/vault:0.7.0' = {
  name: keyVaultName
  params: {
    name: keyVaultName
    location: location
    tags: union(tags, tagsByResource[?'Microsoft.KeyVault/vaults'] ?? {})
    enableVaultForDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: false //TODO: Change to true
    enableRbacAuthorization: false
    createMode: 'default'
    publicNetworkAccess: (networkingOption != 'Public') ? 'Disabled' : 'Enabled'
    sku: startsWith(location, 'china') ? 'standard' : sku
    accessPolicies: accessPolicies
    secrets: [
      {
        name: storageRef.name
        attributes: {
          enabled: true
          exp: 1702648632
          nbf: 10000
        }
        value: storageRef.listKeys().keys[0].value
      }
    ]
    privateEndpoints: (networkingOption == 'Public') ? null : [
      {
        service: 'vault'
        name: 'pve-kv'
        subnetResourceId: (networkingOption == 'PrivateWithExistingNetwork') ? subnetResourceId : newsubnetResourceId
        privateDnsZoneResourceIds: (networkingOption == 'Private') ? [
          privateDNSZoneKeyVault.outputs.resourceId
        ]
        : (networkingOption == 'PrivateWithExistingNetwork') ? [keyVaultPrivateDNSZone.id]
        :[]
        privateDnsZoneGroupName: (networkingOption == 'Private') ? keyVaultPrivateDNSZone.name : (networkingOption == 'PrivateWithExistingNetwork') ? keyVaultPrivateDNSZone.name : null
      }
    ]
  }
}

resource keyVaultPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(networkingOption == 'PrivateWithExistingNetwork') {
  name: keyVaultPrivateDNSZoneName
  scope: resourceGroup(privateDNSZonesResourceGroupName)
}

module privateDNSZoneKeyVault 'br/public:avm/res/network/private-dns-zone:0.5.0' = if(networkingOption == 'Private'){
  name: 'keyVaultDnsZone'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: resourceId('Microsoft.Network/virtualNetworks', virtualNetworkName )
        registrationEnabled: false
      }
    ]
  }
}

resource storageRef 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

//==============================================================================
// Outputs
//==============================================================================

@description('The resource ID of the key vault.')
output resourceId string = keyVault.outputs.resourceId

@description('The name of the key vault.')
output name string = keyVault.name

@description('The URI of the key vault.')
output uri string = keyVault.outputs.uri
