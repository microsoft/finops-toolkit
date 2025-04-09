// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the publisher-specific storage account to create or update.')
param storageAccountName string

@description('Required. Name of the storage container to create or update.')
param container string


//==============================================================================
// Resources
//==============================================================================

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
  
  resource blobService 'blobServices@2022-09-01' = {
    name: 'default'

    resource configContainer 'containers@2022-09-01' = {
      name: container
      properties: {
        publicAccess: 'None'
        metadata: {}
      }
    }
  }
}

// TODO: Upload files
// TODO: Enforce retention

//==============================================================================
// Outputs
//==============================================================================

output containerName string = storageAccount::blobService::configContainer.name
