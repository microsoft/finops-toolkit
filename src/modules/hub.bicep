/**
 * Parameters
 */

@description('Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Specifies the location for resources. See https://aka.ms/azureregions.')
param location string = resourceGroup().location

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

var telemetryId = '00f120b5-40b5-0000-0000-000000000000'
var storageAccountName = '${replace(toLower(hubName), '-', '')}store'
var resourceTags = union(tags, {
    'cm-resource-parent': '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
  })

/**
 * Resources
 */

// Telemetry used anonymously to count the number of times the template has been deployed.
// No information about you or your cost data is collected.
resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
  location: location
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
  name: 'pid-${telemetryId}-${uniqueString(deployment().name, location)}'
  params: {
    name: storageAccountName
    location: location
    storageAccountSku: 'Standard_LRS'
    tags: resourceTags
    enableHierarchicalNamespace: true
  }
}

/**
 * Outputs
 */

@description('The name of the deployed storage account.')
output name string = hubName

@description('The location the resource was deployed into.')
output location string = location

@description('The resource group of the deployed storage account.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the deployed storage account.')
output storageAccountId string = storageAccount.outputs.resourceId

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
