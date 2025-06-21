// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubProperties } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. Create and store a key for a remote storage account.')
@secure()
param remoteStorageKey string

//------------------------------------------------------------------------------
// Temporary parameters that should be removed in the future
//------------------------------------------------------------------------------

// TODO: Pull deployment config from the cloud
@description('Required. FinOps hub instance properties.')
param hub HubProperties


//==============================================================================
// Resources
//==============================================================================

// App registration
module appRegistration 'hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.RemoteHub_Register'
  params: {
    hub: hub
    publisher: 'Microsoft FinOps hubs'
    namespace: 'Microsoft.FinOpsHubs'
    appName: 'RemoteHub'
    displayName: 'FinOps hub remote relay'
    appVersion: loadTextContent('ftkver.txt') // cSpell:ignore ftkver
    features: [
      // TODO: Add pipeline -- 'DataFactory'
      'KeyVault'
      'Storage'
    ]
  }
}

// Key Vault secret
module keyVault_secret 'hub-vault.bicep' = {
  name: 'keyVault_secret'
  params: {
    vaultName: appRegistration.outputs.config.keyVault
    secretName: '${toLower(appRegistration.outputs.config.hub.name)}-storage-key'
    secretValue: remoteStorageKey
    secretExpirationInSeconds: 1702648632
    secretNotBeforeInSeconds: 10000
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('Name of the Key Vault instance.')
output keyVaultName string = appRegistration.outputs.config.publisher.keyVault
