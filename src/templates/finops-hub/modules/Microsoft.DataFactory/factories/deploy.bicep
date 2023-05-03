//==============================================================================
// Parameters
//==============================================================================

@description('Required. The name of the Azure Factory to create.')
param name string

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = true

@description('Optional. Tags of the resource.')
param tags object = {}

//==============================================================================
// Resources
//==============================================================================

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: systemAssignedIdentity ? { type: 'SystemAssigned' } : null
  properties: {
    // Ignore the unsupported error for globalConfigurations
    globalConfigurations: {
      PipelineBillingEnabled: 'true'
    }
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The Resource ID of the Data factory.')
output resourceId string = dataFactory.id

@description('The Name of the Azure Data Factory instance.')
output name string = dataFactory.name

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity && contains(dataFactory.identity, 'principalId') ? dataFactory.identity.principalId : ''
