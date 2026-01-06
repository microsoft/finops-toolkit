// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, privateRoutingForLinkedServices } from '../../fx/hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. Create and store a key for a remote storage account.')
@secure()
param remoteStorageKey string

@description('Required. Remote storage account for ingestion dataset.')
param remoteHubStorageUri string

@description('Optional. Name of the ingestion container. Default: ingestion.')
param ingestionContainerName string = 'ingestion'


//==============================================================================
// Variables
//==============================================================================

var storageKeySecretName = '${toLower(app.hub.name)}-storage-key'


//==============================================================================
// Resources
//==============================================================================

// App registration
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.RemoteHub_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
      'KeyVault'
      'Storage'
    ]
  }
}

// Key Vault secret
module keyVault_secret '../../fx/hub-vault.bicep' = {
  name: 'keyVault_secret'
  dependsOn: [appRegistration]  // Wait for Key Vault to be created
  params: {
    vaultName: app.keyVault
    secretName: storageKeySecretName
    secretValue: remoteStorageKey
    secretExpirationInSeconds: 1702648632
    secretNotBeforeInSeconds: 10000
  }
}

// Get key vault instance
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: app.keyVault
  dependsOn: [appRegistration]  // Wait for Key Vault to be created
}

// Get data factory instance
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [appRegistration]  // Wait for Key Vault to be created

  // cSpell:ignore linkedservices
  resource linkedService_remoteHubStorage 'linkedservices' = {
    name: 'remoteHubStorage'
    properties: {
      annotations: []
      parameters: {}
      type: 'AzureBlobFS'
      typeProperties: {
        url: remoteHubStorageUri
        accountKey: {
          type: 'AzureKeyVaultSecret'
          store: {
            // TODO: Should the key vault linked service name/reference be part of hub settings?
            referenceName: keyVault.name
            type: 'LinkedServiceReference'
          }
          secretName: storageKeySecretName
        }
      }
      ...privateRoutingForLinkedServices(app.hub)
    }
  }

  // Replace the ingestion dataset
  resource dataset_ingestion 'datasets' = {
    name: ingestionContainerName
    properties: {
      annotations: []
      parameters: {
        blobPath: {
          type: 'String'
        }
      }
      type: 'Parquet'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          fileName: {
            value: '@{dataset().blobPath}'
            type: 'Expression'
          }
          fileSystem: ingestionContainerName
        }
      }
      linkedServiceName: {
        parameters: {}
        referenceName: linkedService_remoteHubStorage.name
        type: 'LinkedServiceReference'
      }
    }
  }

  // Replace the ingestion_files dataset
  resource dataset_ingestion_files 'datasets' = {
    name: '${ingestionContainerName}_files'
    properties: {
      annotations: []
      parameters: {
        folderPath: {
          type: 'String'
        }
      }
      type: 'Parquet'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          fileSystem: ingestionContainerName
          folderPath: {
            value: '@dataset().folderPath'
            type: 'Expression'
          }
        }
      }
      linkedServiceName: {
        parameters: {}
        referenceName: linkedService_remoteHubStorage.name
        type: 'LinkedServiceReference'
      }
    }
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('Name of the Key Vault instance.')
output keyVaultName string = app.keyVault
