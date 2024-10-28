// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Optional. Array of private endpoint connections. Pending ones will be approved.')
param privateEndpointConnections array = []

@description('Required. Name of the storage account.')
param storageAccountName string

//==============================================================================
// Resources
//==============================================================================

resource privateEndpointConnection 'Microsoft.Storage/storageAccounts/privateEndpointConnections@2023-04-01' =  [ for privateEndpointConnection in privateEndpointConnections : if (privateEndpointConnection.properties.privateLinkServiceConnectionState.status == 'Pending') {
  name: privateEndpointConnection.name
  parent: storageAccount
  properties: {
    privateLinkServiceConnectionState: {
      status: 'Approved'
      description: 'Approved-by-pipeline'
      actionRequired: 'None'
    }
  }
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  name: storageAccountName
}

//==============================================================================
// Outputs
//==============================================================================

output privateEndpointConnections array = storageAccount.properties.privateEndpointConnections