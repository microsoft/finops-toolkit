// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Types
//==============================================================================

//------------------------------------------------------------------------------
// General
//------------------------------------------------------------------------------

@description('Resource ID and name.')
@metadata({
  id: 'Fully-qualified resource ID.'
  name: 'Resource name.'
})
type IdNameObject = { id: string, name: string }

//------------------------------------------------------------------------------
// Hub config
//------------------------------------------------------------------------------

@description('FinOps hub private network routing properties.')
@metadata({
  networkId: 'Resource ID of the FinOps hub isolated virtual network, if private network routing is enabled.'
  networkName: 'Name of the FinOps hub isolated virtual network, if private network routing is enabled.'
  scriptStorage: 'Name of the storage account used for deployment scripts.'
  dnsZones: {
    blob: 'Resource ID and name for the blob storage DNS zone.'
    dfs: 'Resource ID and name for the DFS storage DNS zone.'
    queue: 'Resource ID and name for the queue storage DNS zone.'
    table: 'Resource ID and name for the table storage DNS zone.'
  }
  subnets: {
    dataFactory: 'Resource ID of the subnet for Data Factory instances.'
    keyVault: 'Resource ID of the subnet for Key Vault instances.'
    scripts: 'Resource ID of the subnet for deployment script storage.'
    storage: 'Resource ID of the subnet for storage accounts.'
  }
})
type HubRoutingProperties = {
  networkId: string
  networkName: string
  scriptStorage: string
  dnsZones: {
    blob: IdNameObject
    dfs: IdNameObject
    queue: IdNameObject
    table: IdNameObject
  }
  subnets: {
    dataFactory: string
    keyVault: string
    scripts: string
    storage: string
  }
}

@export()
@description('FinOps hub instance properties.')
@metadata({
  id: 'FinOps hub resource ID.'
  name: 'FinOps hub instance name.'
  location: 'Azure resource location of the FinOps hub instance.'
  tags: 'Tags to apply to all FinOps hub resources.'
  tagsByResource: 'Tags to apply to resources based on their resource type.'
  version: 'FinOps hub version number.'
  options: {
    enableTelemetry: 'Indicates whether telemetry should be enabled for deployments.'
    keyVaultSku: 'KeyVault SKU. Allowed values: "standard", "premium".'
    networkAddressPrefix: 'Address prefix for the FinOps hub isolated virtual network, if private network routing is enabled.'
    privateRouting: 'Indicates whether private network routing is enabled.'
    publisherIsolation: 'Indicates whether FinOps hub resources should be separated by publisher for advanced security.'
    storageInfrastructureEncryption: 'Indicates whether infrastructure encryption is enabled for the storage account.'
    storageSku: 'Storage account SKU. Allowed values: "Premium_LRS", "Premium_ZRS".'
  }
  routing: 'FinOps hub private network routing properties, if enabled.'
  core: {
    suffix: 'Unique suffix used for shared resources.'
  }
  apps: {
  }
})
type HubProperties = {
  id: string
  name: string
  location: string
  tags: object
  tagsByResource: object
  version: string
  options: {
    enableTelemetry: bool
    keyVaultSku: string
    networkAddressPrefix: string
    privateRouting: bool
    publisherIsolation: bool
    storageInfrastructureEncryption: bool
    storageSku: string
  }
  routing: HubRoutingProperties?
  core: {
    suffix: string
  }
}

//------------------------------------------------------------------------------
// App config
//------------------------------------------------------------------------------

@export()
@description('FinOps hub app configuration settings.')
@metadata({
  name: 'Short name of the FinOps hub app (not including the publisher namespace).'
  displayName: 'Display name of the FinOps hub app.'
  tags: 'Tags to apply to all FinOps hub resources for this FinOps hub app.'
  publisher: {
    name: 'Fully-qualified namespace of the FinOps hub app publisher.'
    displayName: 'Display name of the FinOps hub app publisher.'
    suffix: 'Unique suffix used for publisher resources.'
    tags: 'Tags to apply to all FinOps hub resources for this FinOps hub app publisher.'
  }
  hub: 'FinOps hub instance the app is deployed to.'
  dataFactory: 'Name of the Data Factory instance for this publisher.'
  keyVault: 'Name of the KeyVault instance for this publisher.'
  storage: 'Name of the storage account for this publisher.'
})
type HubAppProperties = {
  name: string
  displayName: string
  tags: object
  publisher: {
    name: string
    displayName: string
    suffix: string
    tags: object
  }
  hub: HubProperties
  dataFactory: string
  keyVault: string
  storage: string
}

@export()
@description('FinOps hub app features.')
type HubAppFeature = 'DataFactory' | 'KeyVault' | 'Storage'


//==============================================================================
// Variables
//==============================================================================

@description('Version of the FinOps toolkit.')
var finOpsToolkitVersion = loadTextContent('ftkver.txt')  // cSpell:ignore ftkver


//==============================================================================
// Functions
//==============================================================================

//------------------------------------------------------------------------------
// Shared
//------------------------------------------------------------------------------

func safeStorageName(name string) string => replace(replace(toLower(name), '-', ''), '_', '')

func idName(name string, resourceType string) IdNameObject => {
  id: resourceId(resourceType, name)
  name: name
}

// cSpell:ignore privatelink
func dnsZoneIdName(type string) IdNameObject => idName('privatelink.${type}.${environment().suffixes.storage}', 'Microsoft.Network/privateDnsZones')

//------------------------------------------------------------------------------
// Hub config
//------------------------------------------------------------------------------

// Internal function to create a new FinOps hub configuration object that includes extra parameters that are reused within the function.
func newHubInternal(
  id string,
  name string,
  suffix string,
  location string,
  tags object,
  tagsByResource object,
  storageSku string,
  keyVaultSku string,
  enableInfrastructureEncryption bool,
  enablePublicAccess bool,
  networkName string,
  networkAddressPrefix string,
  isTelemetryEnabled bool,
) HubProperties => {
  id: id
  name: name
  location: location ?? resourceGroup().location
  tags: union(tags, {
    'cm-resource-parent': id  // cm-resource-parent tag groups resources in Cost Management
    'ftk-tool': 'FinOps hubs'
    'ftk-version': finOpsToolkitVersion
  })
  tagsByResource: tagsByResource
  version: finOpsToolkitVersion
  options: {
    enableTelemetry: isTelemetryEnabled ?? true
    keyVaultSku: keyVaultSku
    networkAddressPrefix: networkAddressPrefix
    privateRouting: !enablePublicAccess
    publisherIsolation: false  // TODO: Expose publisher isolation option
    storageInfrastructureEncryption: enableInfrastructureEncryption
    storageSku: storageSku
  }
  routing: enablePublicAccess ? null : {
    networkId: resourceId('Microsoft.Network/virtualNetworks', networkName)
    networkName: networkName
    scriptStorage: '${take(safeStorageName(name), 16 - length(suffix))}script${suffix}'
    dnsZones: {
      blob: dnsZoneIdName('blob')
      dfs: dnsZoneIdName('dfs')
      queue: dnsZoneIdName('queue')
      table: dnsZoneIdName('table')
    }
    subnets: {
      dataFactory: resourceId('Microsoft.Network/virtualNetworks/subnets', networkName, 'private-endpoint-subnet')!
      keyVault: resourceId('Microsoft.Network/virtualNetworks/subnets', networkName, 'private-endpoint-subnet')!
      scripts: resourceId('Microsoft.Network/virtualNetworks/subnets', networkName, 'script-subnet')!
      storage: resourceId('Microsoft.Network/virtualNetworks/subnets', networkName, 'private-endpoint-subnet')!
    }
  }
  core: {
    suffix: suffix
  }
}

@export()
@description('Creates a new FinOps hub configuration object.')
func newHub(
  name string,
  location string,
  tags object,
  tagsByResource object,
  storageSku string,
  keyVaultSku string,
  enableInfrastructureEncryption bool,
  enablePublicAccess bool,
  networkAddressPrefix string,
  isTelemetryEnabled bool,
) HubProperties => newHubInternal(
  '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${name}',  // id
  name,
  uniqueString(name, resourceGroup().id),  // suffix
  location,
  tags,
  tagsByResource,
  storageSku,
  keyVaultSku,
  enableInfrastructureEncryption,
  enablePublicAccess,
  '${safeStorageName(name)}-vnet-${location}',    // networkName, cSpell:ignore vnet
  networkAddressPrefix,
  isTelemetryEnabled ?? true
)

//------------------------------------------------------------------------------
// App config
//------------------------------------------------------------------------------

// Internal function to create a new FinOps hub configuration object that includes extra parameters that are reused within the function.
func newAppInternal(
  hub HubProperties,
  publisherName string,
  publisherDisplayName string,
  publisherSuffix string,
  publisherTags object,
  appName string,
  appDisplayName string,
  version string,
) HubAppProperties => {
  name: appName
  displayName: appDisplayName
  tags: union(hub.tags, publisherTags, {
    'ftk-hubapp': appName  // cSpell:ignore hubapp
    'ftk-hubapp-version': version
  })
  publisher: {
    name: publisherName
    displayName: publisherDisplayName
    suffix: publisherSuffix
    tags: union(hub.tags, publisherTags)
  }
  hub: hub

  // Globally unique Data Factory name: 3-63 chars; letters, numbers, non-repeating dashes
  dataFactory: replace('${take('${replace(hub.name, '_', '-')}-engine', 63 - length(publisherSuffix) - 1)}-${publisherSuffix}', '--', '-')

  // Globally unique KeyVault name: 3-24 chars; letters, numbers, dashes
  keyVault: replace('${take('${replace(hub.name, '_', '-')}-vault', 24 - length(publisherSuffix) - 1)}-${publisherSuffix}', '--', '-')

  // Globally unique storage account name: 3-24 chars; lowercase letters/numbers only
  storage: '${take(safeStorageName(hub.name), 24 - length(publisherSuffix))}${publisherSuffix}'
}

@export()
@description('Creates a new FinOps hub app configuration object.')
func newApp(
  hub HubProperties,
  publisherDisplayName string,
  publisherName string,
  appPartialName string,
  appDisplayName string,
  version string,
) HubAppProperties => newAppInternal(
  hub,
  publisherName,
  publisherDisplayName,
  !hub.options.publisherIsolation || publisherName == 'Microsoft.FinOpsHubs' ? hub.core.suffix : uniqueString(publisherName),  // publisherSuffix
  { 'ftk-hubapp-publisher': publisherName },  // publisherTags
  '${publisherName}.${appPartialName}',  // appName
  appDisplayName,
  version
)

@export()
@description('Returns a tags dictionary that includes tags for the FinOps hub instance.')
func getHubTags(hub HubProperties, resourceType string) object => union(
  hub.tags,
  hub.tagsByResource[?resourceType] ?? {}
)

@export()
@description('Returns a tags dictionary that includes tags for the FinOps hub app publisher.')
func getPublisherTags(app HubAppProperties, resourceType string) object => union(
  app.hub.options.publisherIsolation ? app.publisher.tags : app.hub.tags,
  app.hub.tagsByResource[?resourceType] ?? {}
)

@export()
@description('Returns a tags dictionary that includes tags for the FinOps hub app.')
func getAppTags(app HubAppProperties, resourceType string, forceAppTags bool?) object => union(
  app.hub.options.publisherIsolation || (forceAppTags ?? false) ? app.tags : app.hub.tags,
  app.hub.tagsByResource[?resourceType] ?? {}
)
