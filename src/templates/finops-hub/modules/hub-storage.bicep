// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the storage container to create or update.')
param container string

@description('Optional. Dictionary of key/value pairs for the files to upload to the specified container. The key is the target path under the container and the value is the contents of the file. Default: {} (no files to upload).')
param files object = {}

//------------------------------------------------------------------------------
// Hub context
//------------------------------------------------------------------------------

@description('Required. Name of the publisher-specific storage account to create or update.')
param storageAccountName string

@description('Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).')
param location string = resourceGroup().location

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Optional. The name of the managed identity to use for uploading files.')
param blobManagerIdentityName string = ''

@description('Required. Indicates whether public access should be enabled.')
param enablePublicAccess bool

@description('Optional. The name of the storage account used for deployment scripts.')
param scriptStorageAccountName string = ''

@description('Optional. Resource ID of the virtual network for running deployment scripts.')
param scriptSubnetId string = ''


//==============================================================================
// Variables
//==============================================================================

var fileCount = length(items(files))
var hasFiles = fileCount > 0

var deploymentName = '${deployment().name}.Upload'


//==============================================================================
// Resources
//==============================================================================

// Get storage account instance
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
  
  resource blobService 'blobServices@2022-09-01' = {
    name: 'default'

    resource targetContainer 'containers@2022-09-01' = {
      name: container
      properties: {
        publicAccess: 'None'
        metadata: {}
      }
    }
  }
}

// TODO: Enforce retention

//------------------------------------------------------------------------------
// Upload schema file to storage
//------------------------------------------------------------------------------

module uploadFiles 'hub-deploymentScript.bicep' = if (hasFiles) {
  name: deploymentName
  params: {
    location: location
    tags: tags
    tagsByResource: tagsByResource

    identityName: blobManagerIdentityName
    enablePublicAccess: enablePublicAccess
    scriptStorageAccountName: scriptStorageAccountName
    scriptSubnetId: scriptSubnetId
    environmentVariables: [
      {
        name: 'storageAccountName'
        value: storageAccount.name
      }
      {
        name: 'containerName'
        value: container
      }
      {
        name: 'files'
        value: string(files)
      }
    ]
    scriptContent: loadTextContent('./scripts/Upload-StorageFile.ps1')
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('The name of the storage container.')
output containerName string = storageAccount::blobService::targetContainer.name

@description('The number of files uploaded to the storage container.')
output filesUploaded int = fileCount
