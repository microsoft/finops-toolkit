/**
 * Parameters
 */

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

// Generate unique storage account name
var storageAccountSuffix = 'store'
var storageAccountName = '${substring(replace(toLower(hubName), '-', ''), 0, 24 - length(storageAccountSuffix))}${storageAccountSuffix}'

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage account SKU. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Tags for all resources.')
param tags object = {}
var resourceTags = union(tags, {
    'cm-resource-parent': '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
  })

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true
var telemetryId = '00f120b5-40b5-0000-0000-000000000000'

/**
 * Resources
 */

// Telemetry used anonymously to count the number of times the template has been deployed.
// No information about you or your cost data is collected.
resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

// ADLSv2 storage account for staging and archive
module storageAccount 'Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    storageAccountSku: storageSku
    tags: resourceTags
  }
}

/**
 * Outputs
 */

@description('The name of the deployed hub instance.')
output name string = hubName

@description('The location the resource was deployed into.')
output location string = location

@description('The resource ID of the deployed storage account.')
output storageAccountId string = storageAccount.outputs.resourceId

@description('Primary blob endpoint reference for the storage account.')
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
