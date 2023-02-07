/**
 * Parameters
 */

@description('Optional. Name of the hub. Used to ensure unique resource names. Default: "finops-hub".')
param hubName string

// Generate unique storage account name
var storageAccountSuffix = 'store'
var dataFactorySuffix = 'factory'
var storageAccountName = '${substring(replace(toLower(hubName), '-', ''), 0, 24 - length(storageAccountSuffix))}${storageAccountSuffix}'
var dataFactoryName = '${substring(replace(toLower(hubName), '-', ''), 0, 24 - length(dataFactorySuffix))}${dataFactorySuffix}'

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
])
@description('Optional. Storage account SKU. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Default: Premium_LRS.')
param storageSku string = 'Premium_LRS'

@description('Optional. Tags to apply to all resources. We will also add the cm-resource-parent tag for improved cost roll-ups in Cost Management.')
param tags object = {}
var resourceTags = union(tags, {
    'cm-resource-parent': '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
  })

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
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

module dataFactory 'Microsoft.DataFactory/factories/deploy.bicep' = {
  name: 'factory'
  params: {
    name: dataFactoryName
    location: location
    tags: resourceTags
  }
}

/**
 * Outputs
 */

@description('Name of the deployed hub instance.')
output name string = hubName

@description('Azure resource location resources were deployed to.')
output location string = location

@description('Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.')
output storageAccountId string = storageAccount.outputs.resourceId

@description('The Resource ID of the Data factory.')
output dataFactoryId string = dataFactory.outputs.resourceId
