// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubCoreConfig } from 'hub-types.bicep'


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
@description('Required. FinOps hub coreConfig.')
param coreConfig HubCoreConfig


//==============================================================================
// Variables
//==============================================================================

// None


//==============================================================================
// Resources
//==============================================================================

//------------------------------------------------------------------------------
// App registration
//------------------------------------------------------------------------------

module appRegistration 'hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.RemoteHub_Register'
  params: {
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

    coreConfig: coreConfig
  }
}

//------------------------------------------------------------------------------
// Key Vault secret
//------------------------------------------------------------------------------

module keyVault_secret 'hub-vault.bicep' = {
  name: 'keyVault_secret'
  params: {
    vaultName: appRegistration.outputs.config.publisher.keyVault
    secretName: '${toLower(appRegistration.outputs.config.hub.name)}-storage-key'
    secretValue: remoteStorageKey
    secretExpirationInSeconds: 1702648632
    secretNotBeforeInSeconds: 10000
  }
}


//==============================================================================
// Outputs
//==============================================================================

// None
