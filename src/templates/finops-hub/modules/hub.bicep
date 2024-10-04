// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Indicates whether the Event Grid resource provider has already been registered (e.g., in a previous hub deployment). Event Grid RP registration is required. If not set, a temporary Event Grid namespace will be created to auto-register the resource provider. Default: false (register RP).')
param skipEventGridRegistration bool = false

@description('Optional. Azure location to use for a temporary Event Grid namespace to register the Microsoft.EventGrid resource provider if the primary location is not supported. The namespace will be deleted and is not used for hub operation. Default: "" (same as location).')
param eventGridLocation string = ''


@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: Premium_LRS, Premium_ZRS. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. List of scope IDs to monitor and ingest cost for.')
param scopesToMonitor array

@description('Optional. Number of days of cost data to retain in the ms-cm-exports container. Default: 0.')
param exportRetentionInDays int = 0

@description('Optional. Number of months of cost data to retain in the ingestion container. Default: 13.')
param ingestionRetentionInMonths int = 13

@description('Optional. Remote storage account for ingestion dataset.')
param remoteHubStorageUri string = ''

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

@description('Optional. Name of the FinOpsHub virtual network.')
param networkName string = 'vnet-finops-hub'

@description('Optional. To use Private Endpoints in an existing virtual network, add target subnet resource Id.')
param subnetResourceId string = ''

param uniqueSuffixSA string = take(uniqueString(resourceGroup().id), 12)

@description('Optional. Name of the Storage account for deployment scripts.')
param dsStorageAccountName string = '${take(uniqueSuffixSA, 12)}stgdsscripts'

@description('Optional. To use Private Endpoints  in an existing virtual network, add target subnet resource Id for the deployment scripts')
param scriptsSubnetResourceId string = ''

@description('Optional. To create networking resources.')
@allowed([
  'Public'
  'Private'
  'PrivateWithExistingNetwork'
])
param networkingOption string = 'Public'

@description('Optional. Address prefix for the FinOpsHub virtual network.')
param networkAddressPrefix string = '10.0.0.0/24'

@description('Optional. Name of the FinOpsHub subnet.')
param networkSubnetName string = 'subnet-finops-hub'

@description('Optional. Address prefix for the created FinOpsHub subnet.')
param networkSubnetPrefix string = cidrSubnet(networkAddressPrefix,24,0)

@description('Optional. Name of the FinOpsHub scripts created subnet.')
param scriptsSubnetName string = 'subnet-finops-hub-scripts'

@description('Optional. Address prefix for the created scripts subnet.')
param scriptsSubnetPrefix string = cidrSubnet(networkAddressPrefix,24,1)

@description('Optional. To use Private Endpoints in an existing virtual network, add target blob storage account private DNS zone resource Id.')
param blobPrivateDNSZoneName string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target ADF private DNS zone resource Id.')
param ADFprivateDNSZoneName string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target ADF Poral private DNS zone resource Id.')
param ADFPoralPrivateDNSZoneName string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target KeyVault private DNS zone resource Id.')
param keyVaultPrivateDNSZoneName string = ''

@description('Optional. To use Private Endpoints in an existing virtual network, add target private DNS zones resource group name.')
param privateDNSZonesResourceGroupName string = ''

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

// Add cm-resource-parent to group resources in Cost Management
var finOpsToolkitVersion = loadTextContent('ftkver.txt')
var resourceTags = union(tags, {
  'cm-resource-parent': '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
  'ftk-version': finOpsToolkitVersion
  'ftk-tool': 'FinOps hubs'
})

// Generate globally unique Data Factory name: 3-63 chars; letters, numbers, non-repeating dashes
var uniqueSuffix = uniqueString(hubName, resourceGroup().id)
var dataFactoryPrefix = '${replace(hubName, '_', '-')}-engine'
var dataFactorySuffix = '-${uniqueSuffix}'
var dataFactoryName = replace(
  '${take(dataFactoryPrefix, 63 - length(dataFactorySuffix))}${dataFactorySuffix}',
  '--',
  '-'
)

var safeHubName = replace(replace(toLower(hubName), '-', ''), '_', '')
var storageAccountSuffix = uniqueSuffix
var storageAccountName = '${take(safeHubName, 24 - length(storageAccountSuffix))}${storageAccountSuffix}'
//var scriptstorageAccountSuffix = uniqueSuffix
//var scriptStorageAccountName='${take(safeHubName, 24 - length(scriptstorageAccountSuffix))}${scriptstorageAccountSuffix}'
var uniqueValue = uniqueString(resourceGroup().id)
var safeString = replace(replace(toLower(uniqueValue), '-', ''), '_', '')
var scriptStorageAccountName = '${take(safeString, 12)}stgdsscripts'

var eventGridPrefix = '${replace(hubName, '_', '-')}-ns'
var eventGridSuffix = '-${uniqueSuffix}'
var eventGridName = replace(
  '${take(eventGridPrefix, 50 - length(eventGridSuffix))}${eventGridSuffix}',
  '--',
  '-'
)

// EventGrid Contributor role
var eventGridContributorRoleId = '1e241071-0855-49ea-94dc-649edcd759de'

// Find a fallback region for EventGrid
var eventGridLocationFallback = {
  israelcentral: 'uaenorth'
  italynorth: 'switzerlandnorth'
  mexicocentral: 'southcentralus'
  polandcentral: 'swedencentral'
  spaincentral: 'francecentral'
  usdodeast: 'usdodcentral'
}
var finalEventGridLocation = eventGridLocation != null && !empty(eventGridLocation) ? eventGridLocation : (eventGridLocationFallback[?location] ?? location)

// The last segment of the telemetryId is used to identify this module
var telemetryId = '00f120b5-2007-6120-0000-40b000000000'

// Private Endpoints for ADF
var adfPrivateEndpoints = [
  {
    name: 'adf'
    groupIds: [
      'dataFactory'
    ]
  }
  {
    name: 'adf-portal'
    groupIds: [
      'portal'
    ]
  }
]

//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// Telemetry
// Used to anonymously count the number of times the template has been deployed
// and to track and fix deployment bugs to ensure the highest quality.
// No information about you or your cost data is collected.
//------------------------------------------------------------------------------

resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
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

//------------------------------------------------------------------------------
// RP registration
// Create and delete a temporary EventGrid namespace so ARM will auto-register
// the Microsoft.EventGrid RP. This is needed because we cannot register RPs in
// a resource group template.
//------------------------------------------------------------------------------
// Temporary resource
resource tempEventGridNamespace 'Microsoft.EventGrid/namespaces@2023-12-15-preview' = if (!skipEventGridRegistration) {
  name: eventGridName
  location: finalEventGridLocation
  sku: {
    capacity: 1
    name: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

// Managed identity to run script
resource cleanupIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (!skipEventGridRegistration) {
  name: '${uniqueSuffix}_cleanup'
  location: finalEventGridLocation
}

// Assign access to the identity
resource cleanupIdentityRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!skipEventGridRegistration) {
  name: guid(eventGridContributorRoleId, cleanupIdentity.id)
  scope: tempEventGridNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventGridContributorRoleId)
    principalId: cleanupIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
// Cleanup script
module cleanupTempEventGridNamespace 'br/public:avm/res/resources/deployment-script:0.2.4' = {
  name: '${uniqueSuffix}_deleteEventGrid'
  dependsOn: [
    cleanupIdentityRole
  ]
  params: {
    name: '${uniqueSuffix}_deleteEventGrid'
    kind: 'AzurePowerShell'
    // chinaeast2 is the only region in China that supports deployment scripts
    location: startsWith(location, 'china') ? 'chinaeast2' : location
    managedIdentities: {
      userAssignedResourcesIds: [
        cleanupIdentity.id
      ]
    }
    azPowerShellVersion: '12.0'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: {
      secureList: [
        {
          name: 'resourceId'
          value: tempEventGridNamespace.id
        }
      ]
    }
    scriptContent: 'Remove-AzResource -Id $env:resourceId -Force'
    subnetResourceIds: (networkingOption == 'Public') ? [] : (networkingOption == 'Private') ? [vnet.outputs.subnetResourceIds[1]] : [scriptsSubnetResourceId]
    storageAccountResourceId: (networkingOption == 'Public') ? null : dsStorageAccount.outputs.resourceId

  }
}
//------------------------------------------------------------------------------
// ADLSv2 storage account for staging and archive
//------------------------------------------------------------------------------

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    hubName: hubName
    uniqueSuffix: uniqueSuffix
    sku: storageSku
    location: location
    tags: resourceTags
    tagsByResource: tagsByResource
    scopesToMonitor: scopesToMonitor
    msexportRetentionInDays: exportRetentionInDays
    ingestionRetentionInMonths: ingestionRetentionInMonths
    subnetResourceId: subnetResourceId
    scriptsSubnetResourceId: scriptsSubnetResourceId
    userAssignedManagedIdentityResourceId: uploadFilesIdentity.id
    userAssignedManagedIdentityPrincipalId: uploadFilesIdentity.properties.principalId
    dsStorageAccountResourceId : (networkingOption == 'Public') ? '' : dsStorageAccount.outputs.resourceId
    networkingOption: networkingOption
    newsubnetResourceId: (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[0] : null
    newScriptsSubnetResourceId: (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[1] : null
    virtualNetworkName: (networkingOption == 'Private') ? vnet.name : null
    blobPrivateDNSZoneName: blobPrivateDNSZoneName
    privateDNSZonesResourceGroupName: privateDNSZonesResourceGroupName
  }
}


//------------------------------------------------------------------------------
// Storage account for deployment scripts
//------------------------------------------------------------------------------

// Create managed identity to upload files
resource uploadFilesIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${storageAccountName}_blobManager'
  tags: union(tags, tagsByResource[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
  location: location
}

module dsStorageAccount 'br/public:avm/res/storage/storage-account:0.11.0' = if(networkingOption != 'Public') {
  name: dsStorageAccountName
  params: {
    name: dsStorageAccountName
    skuName: 'Standard_LRS'
    tags: union(tags, tagsByResource[?'Microsoft.Storage/storageAccounts'] ?? {})
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
        principalId: uploadFilesIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59'
        principalId: uploadFilesIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
        principalId: uploadFilesIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
        principalId: cleanupIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59'
        principalId: cleanupIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
        principalId: cleanupIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
        principalId: dataFactoryScriptsIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[1] : scriptsSubnetResourceId
          action: 'Allow'
          state: 'Succeeded'
        }
      ]
    }
  }
}

//------------------------------------------------------------------------------
// Data Factory and pipelines
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  dependsOn: [
    tempEventGridNamespace
  ]
  location: location
  tags: union(resourceTags, tagsByResource[?'Microsoft.DataFactory/factories'] ?? {})
  identity: { type: 'SystemAssigned' }
  properties: union(
    // Using union() to hide the error that gets surfaced because globalConfigurations is not in the ADF schema yet.
    {
    },
    {
      globalConfigurations: {
        PipelineBillingEnabled: 'true'
      }
      publicNetworkAccess: (networkingOption != 'Public') ? 'Disabled' : 'Enabled'
    })
}


// Create managed identity for data factory operations
resource dataFactoryScriptsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${storageAccountName}_triggerManager'
  tags: union(tags, tagsByResource[?'Microsoft.ManagedIdentity/userAssignedIdentities'] ?? {})
  location: location
}


module dataFactoryResources 'dataFactory.bicep' = {
  name: 'dataFactoryResources'
  params: {
    dataFactoryName: dataFactoryName
    storageAccountName: storage.outputs.name
    exportContainerName: storage.outputs.exportContainer
    configContainerName: storage.outputs.configContainer
    ingestionContainerName: storage.outputs.ingestionContainer
    keyVaultName: keyVault.outputs.name
    location: location
    hubName: hubName
    remoteHubStorageUri: remoteHubStorageUri
    tags: resourceTags
    tagsByResource: tagsByResource
    scriptsSubnetResourceId: scriptsSubnetResourceId
    dsStorageAccountResourceId : (networkingOption == 'Public') ? '' : dsStorageAccount.outputs.resourceId
    userAssignedManagedIdentityResourceId: dataFactoryScriptsIdentity.id
    userAssignedManagedIdentityPrincipalId: dataFactoryScriptsIdentity.properties.principalId
    networkingOption: networkingOption
    newScriptsSubnetResourceId: (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[1] : null
  }
}

//------------------------------------------------------------------------------
// Key Vault for storing secrets
//------------------------------------------------------------------------------

module keyVault 'keyVault.bicep' = {
  name: 'keyVault'
  params: {
    hubName: hubName
    uniqueSuffix: uniqueSuffix
    location: location
    tags: resourceTags
    tagsByResource: tagsByResource
    storageAccountName: storage.outputs.name
    subnetResourceId: (networkingOption == 'PrivateWithExistingNetwork') ? subnetResourceId : (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[0] : ''
    accessPolicies: [
      {
        objectId: dataFactory.identity.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    networkingOption: networkingOption
    newsubnetResourceId: (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[0] : null
    keyVaultPrivateDNSZoneName: keyVaultPrivateDNSZoneName
    privateDNSZonesResourceGroupName: privateDNSZonesResourceGroupName
    virtualNetworkName: (networkingOption == 'Private') ? vnet.name : null
    }
}

//------------------------------------------------------------------------------
// Virtual network for private access
//------------------------------------------------------------------------------

module vnet 'br/public:avm/res/network/virtual-network:0.1.8' = if (networkingOption == 'Private') {
  name: networkName
  params: {
    name: networkName
    addressPrefixes: [
      networkAddressPrefix
    ]
    location: location
    tags: union(tags, tagsByResource[?'Microsoft.Network/virtualNetworks'] ?? {})
    subnets: [
      {
        name: networkSubnetName
        addressPrefix: networkSubnetPrefix
      }
      {
        name: scriptsSubnetName
        addressPrefix: scriptsSubnetPrefix
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
        delegations: [
          {
            name: 'Microsoft.ContainerInstance.containerGroups'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
      }
    ]
  }
}



//------------------------------------------------------------------------------
// Private Endpoints for ADF
//------------------------------------------------------------------------------

resource ADFprivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(networkingOption == 'PrivateWithExistingNetwork') {
  name: ADFprivateDNSZoneName
  scope: resourceGroup(privateDNSZonesResourceGroupName)
}

resource ADFPoralPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if(networkingOption == 'PrivateWithExistingNetwork') {
  name: ADFPoralPrivateDNSZoneName
  scope: resourceGroup(privateDNSZonesResourceGroupName)
}

resource privateEndpointADF 'Microsoft.Network/privateEndpoints@2022-05-01' = [for (privateEndpoint,index) in adfPrivateEndpoints: if(networkingOption != 'Public')  {
  name: 'pve-${privateEndpoint.name}-${dataFactory.name}'
  location: location
  properties: {
    customNetworkInterfaceName: 'nic-${privateEndpoint.name}-${dataFactory.name}'
    privateLinkServiceConnections: [
      {
        name: 'pve-${privateEndpoint.name}-${dataFactory.name}'
        properties: {
          privateLinkServiceId: dataFactory.id
          groupIds: privateEndpoint.groupIds
        }
      }
    ]
    subnet: {
      id: (networkingOption == 'PrivateWithExistingNetwork') ? subnetResourceId : (networkingOption == 'Private') ? vnet.outputs.subnetResourceIds[0] : null
      properties: {
        privateEndpointNetworkPolicies: 'Enabled'
      }
    }
  }
}]

resource ADFDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = [for (privateEndpoint,index) in adfPrivateEndpoints: if(networkingOption != 'Public')  {
  name: '${privateEndpointADF[index].name}/${privateEndpoint.name}dnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      privateEndpoint.name == 'adf' ?{
        name: privateDNSZoneDataFactory.name
        properties: {
          privateDnsZoneId: (networkingOption == 'Private') ? privateDNSZoneDataFactory.outputs.resourceId : ADFprivateDNSZone.id
        }
      } : {
        name: privateDNSZoneDataFactoryPortal.name
        properties: {
          privateDnsZoneId: (networkingOption == 'Private') ? privateDNSZoneDataFactoryPortal.outputs.resourceId : ADFPoralPrivateDNSZone.id
        }
      }
    ]
  }
}]

//------------------------------------------------------------------------------
// Private DNS zones for ADF
//------------------------------------------------------------------------------

module privateDNSZoneDataFactory 'br/public:avm/res/network/private-dns-zone:0.5.0' = if(networkingOption == 'Private'){
  name: 'dataFactoryDnsZone'
  params: {
    name: 'privatelink.datafactory.azure.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: resourceId('Microsoft.Network/virtualNetworks', networkName)
        registrationEnabled: false
      }
    ]
  }
}

module privateDNSZoneDataFactoryPortal 'br/public:avm/res/network/private-dns-zone:0.5.0' = if(networkingOption == 'Private'){
  name: 'dataFactoryPortalDnsZone'
  params: {
    name: 'privatelink.adf.azure.com'
    location: 'global'
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: resourceId('Microsoft.Network/virtualNetworks', networkName)
        registrationEnabled: false
      }
    ]
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('Name of the deployed hub instance.')
output name string = hubName

@description('Azure resource location resources were deployed to.')
output location string = location

@description('Name of the Data Factory.')
output dataFactorytName string = dataFactory.name

@description('Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.')
output storageAccountId string = storage.outputs.storageAccountId

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = storage.outputs.name

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = 'https://${storage.outputs.name}.dfs.${environment().suffixes.storage}/${storage.outputs.ingestionContainer}'

@description('Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.')
output managedIdentityId string = dataFactory.identity.principalId

@description('Azure AD tenant ID. This will be needed when configuring managed exports.')
output managedIdentityTenantId string = tenant().tenantId
