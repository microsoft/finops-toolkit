// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubCoreConfig } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Optional. List of scope IDs to monitor and ingest cost for.')
param scopesToMonitor array

// TODO: Move export retention to the CM Exports app?
// cSpell:ignore msexport
@description('Optional. Number of days of data to retain in the msexports container. Default: 0.')
param msexportRetentionInDays int = 0

@description('Optional. Number of months of data to retain in the ingestion container. Default: 13.')
param ingestionRetentionInMonths int = 13

@description('Optional. Number of days of data to retain in the Data Explorer *_raw tables. Default: 0.')
param rawRetentionInDays int = 0

@description('Optional. Number of months of data to retain in the Data Explorer *_final_v* tables. Default: 13.')
param finalRetentionInMonths int = 13


//------------------------------------------------------------------------------
// Temporary parameters that should be removed in the future
//------------------------------------------------------------------------------

// TODO: Pull deployment config from the cloud
@description('Required. FinOps hub coreConfig.')
param coreConfig HubCoreConfig

// TODO: Consider moving telemetryString generation to hub-types.bicep
@description('Optional. Custom string with additional metadata to log. Must an alphanumeric string without spaces or special characters except for underscores and dashes. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param telemetryString string = ''


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration 'hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Register'
  params: {
    publisher: 'Microsoft FinOps hubs'
    namespace: 'Microsoft.FinOpsHubs'
    appName: 'Core'
    displayName: 'FinOps hub core'
    appVersion: loadTextContent('ftkver.txt') // cSpell:ignore ftkver
    features: [
      'DataFactory'
      'Storage'
    ]
    telemetryString: telemetryString

    coreConfig: coreConfig
  }
}

// Create config container
module configContainer 'hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.ConfigContainer'
  params: {
    appConfig: appRegistration.outputs.config
    container: 'config'
    forceCreateBlobManagerIdentity: true
  }
}

// Create ingestion container
module ingestionContainer 'hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.IngestionContainer'
  params: {
    appConfig: appRegistration.outputs.config
    container: 'ingestion'
  }
}

// Create/update Settings.json
module uploadSettings 'hub-deploymentScript.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.UpdateSettings'
  params: {
    identityName: configContainer.outputs.identityName
    scriptName: '${appRegistration.outputs.config.publisher.storage}_uploadSettings'
    location: appRegistration.outputs.config.hub.location
    tags: appRegistration.outputs.config.publisher.tags
    tagsByResource: appRegistration.outputs.config.deployment.tagsByResource
    environmentVariables: [
      {
        // cSpell:ignore ftkver
        name: 'ftkVersion'
        value: loadTextContent('./ftkver.txt')
      }
      {
        name: 'scopes'
        value: join(scopesToMonitor, '|')
      }
      {
        name: 'msexportRetentionInDays'
        value: string(msexportRetentionInDays)
      }
      {
        name: 'ingestionRetentionInMonths'
        value: string(ingestionRetentionInMonths)
      }
      {
        name: 'rawRetentionInDays'
        value: string(rawRetentionInDays)
      }
      {
        name: 'finalRetentionInMonths'
        value: string(finalRetentionInMonths)
      }
      {
        name: 'storageAccountName'
        value: appRegistration.outputs.config.publisher.storage
      }
      {
        name: 'containerName'
        value: 'config'
      }
    ]
    scriptContent: loadTextContent('./scripts/Copy-FileToAzureBlob.ps1')

    enablePublicAccess: !coreConfig.network.isPrivate
    scriptStorageAccountName: coreConfig.deployment.storage
    scriptSubnetId: coreConfig.network.subnets.scripts
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('Name of the Data Factory.')
output dataFactoryName string = appRegistration.outputs.config.publisher.dataFactory

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = appRegistration.outputs.config.publisher.storage

@description('The name of the container used for configuration settings.')
output configContainer string = configContainer.outputs.containerName

@description('The name of the container used for normalized data ingestion.')
output ingestionContainer string = ingestionContainer.outputs.containerName

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = 'https://${appRegistration.outputs.config.publisher.storage}.dfs.${environment().suffixes.storage}/${ingestionContainer.outputs.containerName}'

@description('Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.')
output principalId string = appRegistration.outputs.principalId

// TODO: Remove this output
@description('Tags for the FinOps hub publisher.')
output publisherTags object = appRegistration.outputs.config.publisher.tags
