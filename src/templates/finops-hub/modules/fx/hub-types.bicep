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
    dataExplorer: 'Resource ID of the subnet for the Data Explorer instance.'
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
    dataExplorer: string
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
  customNames: {
    storageAccount: 'Custom name for the storage account. If empty, a default name will be generated.'
    dataFactory: 'Custom name for the Data Factory. If empty, a default name will be generated.'
    keyVault: 'Custom name for the Key Vault. If empty, a default name will be generated.'
    virtualNetwork: 'Custom name for the Virtual Network. If empty, a default name will be generated.'
    managedIdentity: 'Custom name for the Managed Identity. If empty, a default name will be generated.'
    dataExplorerCluster: 'Custom name for the Data Explorer Cluster. If empty, a default name will be generated.'
    privateEndpointPrefix: 'Custom name prefix for Private Endpoints. If empty, default names will be generated.'
  }
  existingDnsZones: {
    blob: 'Resource ID of an existing Private DNS Zone for Blob storage, if provided.'
    dfs: 'Resource ID of an existing Private DNS Zone for Data Lake Storage (DFS), if provided.'
    queue: 'Resource ID of an existing Private DNS Zone for Queue storage, if provided.'
    table: 'Resource ID of an existing Private DNS Zone for Table storage, if provided.'
    vault: 'Resource ID of an existing Private DNS Zone for Key Vault, if provided.'
    dataExplorer: 'Resource ID of an existing Private DNS Zone for Data Explorer, if provided.'
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
  customNames: {
    storageAccount: string
    dataFactory: string
    keyVault: string
    virtualNetwork: string
    managedIdentity: string
    dataExplorerCluster: string
    privateEndpointPrefix: string
  }
  existingDnsZones: {
    blob: string
    dfs: string
    queue: string
    table: string
    vault: string
    dataExplorer: string
  }
  routing: HubRoutingProperties
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
  id: 'Fully-qualified name of the publisher and app, separated by a dot.'
  name: 'Short name of the FinOps hub app. Last segment of the app ID.'
  publisher: 'Fully-qualified namespace of the FinOps hub app publisher.'
  suffix: 'Unique suffix used for publisher resources.'
  tags: 'Tags to apply to all FinOps hub resources for this FinOps hub app publisher. Tags are not specific to the app since resources are shared.'
  dataFactory: 'Name of the Data Factory instance for this publisher.'
  keyVault: 'Name of the KeyVault instance for this publisher.'
  storage: 'Name of the storage account for this publisher.'
  hub: 'FinOps hub instance the app is deployed to.'
})
type HubAppProperties = {
  id: string
  name: string
  publisher: string
  suffix: string
  tags: object
  dataFactory: string
  keyVault: string
  storage: string
  hub: HubProperties
}

@export()
@description('FinOps hub app features.')
type HubAppFeature = 'DataFactory' | 'KeyVault' | 'Storage'


//==============================================================================
// Variables
//==============================================================================

@export()
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
  customStorageAccountName string,
  customDataFactoryName string,
  customKeyVaultName string,
  customVirtualNetworkName string,
  customManagedIdentityName string,
  customDataExplorerClusterName string,
  customPrivateEndpointPrefix string,
  existingBlobDnsZoneId string,
  existingDfsDnsZoneId string,
  existingQueueDnsZoneId string,
  existingTableDnsZoneId string,
  existingVaultDnsZoneId string,
  existingDataExplorerDnsZoneId string
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
  customNames: {
    storageAccount: customStorageAccountName
    dataFactory: customDataFactoryName
    keyVault: customKeyVaultName
    virtualNetwork: customVirtualNetworkName
    managedIdentity: customManagedIdentityName
    dataExplorerCluster: customDataExplorerClusterName
    privateEndpointPrefix: customPrivateEndpointPrefix
  }
  existingDnsZones: {
    blob: existingBlobDnsZoneId
    dfs: existingDfsDnsZoneId
    queue: existingQueueDnsZoneId
    table: existingTableDnsZoneId
    vault: existingVaultDnsZoneId
    dataExplorer: existingDataExplorerDnsZoneId
  }
  routing: {
    networkId: enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName)
    networkName: enablePublicAccess ? '' : (!empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName)
    scriptStorage: enablePublicAccess ? '' : '${take(safeStorageName(name), 16 - length(suffix))}script${suffix}'
    dnsZones: {
      blob:  enablePublicAccess ? { id:'', name:'' } : dnsZoneIdName('blob')
      dfs:   enablePublicAccess ? { id:'', name:'' } : dnsZoneIdName('dfs')
      queue: enablePublicAccess ? { id:'', name:'' } : dnsZoneIdName('queue')
      table: enablePublicAccess ? { id:'', name:'' } : dnsZoneIdName('table')
    }
    subnets: {
      dataExplorer: enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks/subnets', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName, 'dataExplorer-subnet')!
      dataFactory:  enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks/subnets', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName, 'private-endpoint-subnet')!
      keyVault:     enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks/subnets', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName, 'private-endpoint-subnet')!
      scripts:      enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks/subnets', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName, 'script-subnet')!
      storage:      enablePublicAccess ? '' : resourceId('Microsoft.Network/virtualNetworks/subnets', !empty(customVirtualNetworkName) ? customVirtualNetworkName : networkName, 'private-endpoint-subnet')!
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
  customStorageAccountName string,
  customDataFactoryName string,
  customKeyVaultName string,
  customVirtualNetworkName string,
  customManagedIdentityName string,
  customDataExplorerClusterName string,
  customPrivateEndpointPrefix string,
  existingBlobDnsZoneId string,
  existingDfsDnsZoneId string,
  existingQueueDnsZoneId string,
  existingTableDnsZoneId string,
  existingVaultDnsZoneId string,
  existingDataExplorerDnsZoneId string
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
  isTelemetryEnabled ?? true,
  customStorageAccountName,
  customDataFactoryName,
  customKeyVaultName,
  customVirtualNetworkName,
  customManagedIdentityName,
  customDataExplorerClusterName,
  customPrivateEndpointPrefix,
  existingBlobDnsZoneId,
  existingDfsDnsZoneId,
  existingQueueDnsZoneId,
  existingTableDnsZoneId,
  existingVaultDnsZoneId,
  existingDataExplorerDnsZoneId
)

//------------------------------------------------------------------------------
// App config
//------------------------------------------------------------------------------

// Internal function to create a new FinOps hub configuration object that includes extra parameters that are reused within the function.
func newAppInternal(
  hub HubProperties,
  id string,
  name string,
  publisher string,
  suffix string,
) HubAppProperties => {
  id: id
  name: name
  publisher: publisher
  suffix: suffix
  tags: union(
    hub.tags,
    { 'ftk-hubapp-publisher': publisher }  // publisherTags
    // TODO: How do we want to handle app-specific tags?
    // {
    //   'ftk-hubapp': appName  // cSpell:ignore hubapp
    //   'ftk-hubapp-version': version
    // }
  )
  hub: hub

  // Globally unique Data Factory name: 3-63 chars; letters, numbers, non-repeating dashes
  dataFactory: !empty(hub.customNames.dataFactory) 
    ? hub.customNames.dataFactory 
    : replace('${take('${replace(hub.name, '_', '-')}-engine', 63 - length(suffix) - 1)}-${suffix}', '--', '-')

  // Globally unique KeyVault name: 3-24 chars; letters, numbers, dashes
  keyVault: !empty(hub.customNames.keyVault) 
    ? hub.customNames.keyVault 
    : replace('${take('${replace(hub.name, '_', '-')}-vault', 24 - length(suffix) - 1)}-${suffix}', '--', '-')

  // Globally unique storage account name: 3-24 chars; lowercase letters/numbers only
  storage: !empty(hub.customNames.storageAccount) 
    ? hub.customNames.storageAccount 
    : '${take(safeStorageName(hub.name), 24 - length(suffix))}${suffix}'
}

@export()
@description('Creates a new FinOps hub app configuration object.')
func newApp(
  hub HubProperties,
  publisher string,
  app string,
) HubAppProperties => newAppInternal(
  hub,
  '${publisher}.${app}',  // id
  app,
  publisher,
  !hub.options.publisherIsolation || publisher == 'Microsoft.FinOpsHubs' ? hub.core.suffix : uniqueString(publisher)  // publisher suffix
)

@export()
@description('Returns a tags dictionary that includes tags for the FinOps hub instance.')
func getHubTags(hub HubProperties, resourceType string) object => union(
  hub.tags,
  hub.tagsByResource[?resourceType] ?? {}
)

@export()
@description('Returns a tags dictionary that includes tags for the FinOps hub app publisher.')
func getAppPublisherTags(app HubAppProperties, resourceType string) object => union(
  app.hub.options.publisherIsolation ? app.tags : app.hub.tags,
  app.hub.tagsByResource[?resourceType] ?? {}
)

@export()
@description('Returns the name for a private endpoint based on the resource name and service type.')
func getPrivateEndpointName(hub HubProperties, resourceName string, serviceType string) string => 
  !empty(hub.customNames.privateEndpointPrefix) 
    ? '${hub.customNames.privateEndpointPrefix}-${serviceType}-ep' 
    : '${resourceName}-${serviceType}-ep'


//------------------------------------------------------------------------------
// Private routing
//------------------------------------------------------------------------------

@export()
@description('Returns an object that represents the properties needed to enable private routing for linked services. Use property expansion (`...value`) to apply to a linkedServices resource.')
func privateRoutingForLinkedServices(hub HubProperties) object => hub.options.privateRouting ? {
  connectVia: {
    referenceName: 'ManagedIntegrationRuntime'
    type: 'IntegrationRuntimeReference'
  }
} : {}
