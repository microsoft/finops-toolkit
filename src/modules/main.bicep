/**
 * Parameters
 */

targetScope = 'subscription'

@description('Name of the hub. Used for the resource group and to guarrantee globally unique resource names.')
param hubName string

@description('Optional. Location of the resources. Default: Same as deployment. See https://aka.ms/azureregions.')
param location string = deployment().location

@description('Optional. Tags for all resources.')
param tags object = {}

var resourceTags = union(tags, {
    'cm-resource-parent': '${resourceGroup(subscription().id, hubName)}/providers/Microsoft.Cloud/hubs/${hubName}'
  })

/**
* Resources
*/

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubName
  location: location
  tags: resourceTags
  properties: {}
}

module hub 'hub.bicep' = {
  name: 'hub'
  scope: rg
  params: {
    hubName: hubName
    location: location
    tags: resourceTags
  }
}

/**
 * Outputs
 */

@description('The name of the resource group.')
output name string = hubName

@description('The location the resources wer deployed to.')
output location string = location

@description('The resource ID of the resource group.')
output resourceGroupId string = rg.id

@description('The resource ID of the deployed storage account.')
output storageAccountId string = hub.outputs.storageAccountId

@description('The primary blob endpoint reference if blob services are deployed.')
output primaryBlobEndpoint string = hub.outputs.primaryBlobEndpoint
