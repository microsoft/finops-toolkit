// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: Premium_LRS, Premium_ZRS. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).')
param dataExplorerName string = ''

@description('Optional. Name of the Azure Data Explorer SKU. Default: "Standard_E2ads_v5".')
param dataExplorerSkuName string = 'Standard_E2ads_v5'

@description('Optional. SKU tier for the Azure Data Explorer cluster. Allowed values: Basic, Standard. Default: "Standard".')
@allowed(['Basic', 'Standard'])
param dataExplorerSkuTier string = 'Standard'

@description('Optional. Number of nodes to use in the cluster. Allowed values: 2-1000. Default: 2.')
@minValue(2)
@maxValue(1000)
param dataExplorerSkuCapacity int = 2

@description('Optional. Azure location to use for Event Grid topics used for Azure Data Explorer ingestion if the primary location is not supported. Default: "" (same as location).')
param eventGridLocation string = ''

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

@description('Optional. Storage account key for remote storage account.')
@secure()
param remoteHubStorageKey string = ''

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

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
  }
}

//------------------------------------------------------------------------------
// Data Explorer for analytics
//------------------------------------------------------------------------------

module dataExplorer 'dataExplorer.bicep' = if (!empty(dataExplorerName)) {
  name: 'dataExplorer'
  params: {
    hubName: hubName
    uniqueSuffix: uniqueSuffix
    clusterName: dataExplorerName
    location: location
    clusterSkuName: dataExplorerSkuName
    clusterSkuTier: dataExplorerSkuTier
    clusterSkuCapacity: dataExplorerSkuCapacity
    eventGridLocation: finalEventGridLocation
    storageAccountName: storage.outputs.name
    storageContainerName: storage.outputs.ingestionContainer
    tags: resourceTags
    tagsByResource: tagsByResource
  }
}

//------------------------------------------------------------------------------
// Data Factory and pipelines
//------------------------------------------------------------------------------

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  tags: union(
    resourceTags,
    contains(tagsByResource, 'Microsoft.DataFactory/factories') ? tagsByResource['Microsoft.DataFactory/factories'] : {}
  )
  identity: { type: 'SystemAssigned' }
  properties: any({ // Using any() to hide the error that gets surfaced because globalConfigurations is not in the ADF schema yet
      globalConfigurations: {
        PipelineBillingEnabled: 'true'
      }
  })
}

module dataFactoryResources 'dataFactory.bicep' = {
  name: 'dataFactoryResources'
  params: {
    hubName: hubName
    dataFactoryName: dataFactory.name
    location: location
    tags: resourceTags
    tagsByResource: tagsByResource
    storageAccountName: storage.outputs.name
    exportContainerName: storage.outputs.exportContainer
    configContainerName: storage.outputs.configContainer
    ingestionContainerName: storage.outputs.ingestionContainer
    dataExplorerCluster: dataExplorer.outputs.clusterName
    dataExplorerIngestionDatabase: dataExplorer.outputs.ingestionDbName
    keyVaultName: keyVault.outputs.name
    remoteHubStorageUri: remoteHubStorageUri
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
    storageAccountKey: remoteHubStorageKey
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
  }
}

//------------------------------------------------------------------------------
// Delete old resources
//------------------------------------------------------------------------------

// TODO: Clean up old resources
// TODO: Merge with ADF cleanup script
// var oldResourceIds = [
//   resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', '${uniqueSuffix}_cleanup')
//   resourceId('Microsoft.Authorization/roleAssignments', guid(eventGridContributorRoleId, cleanupIdentity.id))
// ]
// resource deleteOldResources 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: '${hubName}_deleteOldResources'
//   // chinaeast2 is the only region in China that supports deployment scripts
//   location: startsWith(location, 'china') ? 'chinaeast2' : location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${identity.id}': {}
//     }
//   }
//   kind: 'AzurePowerShell'
//   dependsOn: [
//     identityRoleAssignments
//   ]
//   tags: union(tags, contains(tagsByResource, 'Microsoft.Resources/deploymentScripts') ? tagsByResource['Microsoft.Resources/deploymentScripts'] : {})
//   properties: {
//     azPowerShellVersion: '8.0'
//     retentionInterval: 'PT1H'
//     cleanupPreference: 'OnSuccess'
//     scriptContent: loadTextContent('./scripts/Remove-OldResources.ps1')
//     environmentVariables: [
//       {
//         name: 'DataFactorySubscriptionId'
//         value: subscription().id
//       }
//       {
//         name: 'DataFactoryResourceGroup'
//         value: resourceGroup().name
//       }
//       {
//         name: 'DataFactoryName'
//         value: dataFactory.name
//       }
//     ]
//   }
// }

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
output storageAccountId string = storage.outputs.resourceId

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = storage.outputs.name

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = 'https://${storage.outputs.name}.dfs.${environment().suffixes.storage}/${storage.outputs.ingestionContainer}'

@description('The resource ID of the Data Explorer cluster.')
output clusterId string = dataExplorer.outputs.clusterId

@description('The URI of the Data Explorer cluster.')
output clusterUri string = dataExplorer.outputs.clusterUri

@description('The name of the Data Explorer ingestion database.')
output ingestionDbName string = dataExplorer.outputs.ingestionDbName

@description('The name of the Data Explorer hub database.')
output hubDbName string = dataExplorer.outputs.hubDbName

@description('Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.')
output managedIdentityId string = dataFactory.identity.principalId

@description('Azure AD tenant ID. This will be needed when configuring managed exports.')
output managedIdentityTenantId string = tenant().tenantId
