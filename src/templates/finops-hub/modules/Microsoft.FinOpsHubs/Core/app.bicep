// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties } from '../../fx/hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

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


//==============================================================================
// Variables
//==============================================================================

var CONFIG = 'config'
var INGESTION = 'ingestion'


//==============================================================================
// Resources
//==============================================================================

// Networking infrastructure
module infrastructure 'infrastructure.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Infrastructure'
  params: {
    hub: app.hub
  }
}

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Register'
  dependsOn: [
    infrastructure
  ]
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'DataFactory'
      'Storage'
    ]
  }
}

// Create config container
module configContainer '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.ConfigContainer'
  dependsOn: [
    appRegistration
  ]
  params: {
    app: app
    container: CONFIG
    forceCreateBlobManagerIdentity: true
  }
}

// Create ingestion container
module ingestionContainer '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.IngestionContainer'
  dependsOn: [
    appRegistration
  ]
  params: {
    app: app
    container: INGESTION
  }
}

// Create/update Settings.json
module uploadSettings '../../fx/hub-deploymentScript.bicep' = {
  name: 'Microsoft.FinOpsHubs.Core_Storage.UpdateSettings'
  dependsOn: [
    appRegistration
  ]
  params: {
    app: app
    identityName: configContainer.outputs.identityName
    scriptName: '${app.storage}_uploadSettings'
    scriptContent: loadTextContent('Copy-FileToAzureBlob.ps1')
    environmentVariables: [
      {
        // cSpell:ignore ftkver
        name: 'ftkVersion'
        value: finOpsToolkitVersion
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
        value: app.storage
      }
      {
        name: 'containerName'
        value: 'config'
      }
    ]
  }
}

// Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: app.dataFactory
  dependsOn: [
    appRegistration
  ]

  // Config dataset
  resource dataset_config 'datasets' = {
    name: CONFIG
    properties: {
      linkedServiceName: {
        referenceName: app.storage
        type: 'LinkedServiceReference'
      }
      type: 'Json'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          fileName: {
            value: '@{dataset().fileName}'
            type: 'Expression'
          }
          folderPath: {
            value: '@{dataset().folderPath}'
            type: 'Expression'
          }
        }
      }
      parameters: {
        fileName: {
          type: 'String'
          defaultValue: 'settings.json'
        }
        folderPath: {
          type: 'String'
          defaultValue: configContainer.outputs.containerName
        }
      }
    }
  }

  resource dataset_ingestion 'datasets' = {
    name: INGESTION
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
          fileSystem: ingestionContainer.outputs.containerName
        }
      }
      linkedServiceName: {
        parameters: {}
        referenceName: app.storage
        type: 'LinkedServiceReference'
      }
    }
  }

  resource dataset_ingestion_files 'datasets' = {
    name: '${INGESTION}_files'
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
          fileSystem: ingestionContainer.outputs.containerName
          folderPath: {
            value: '@dataset().folderPath'
            type: 'Expression'
          }
        }
      }
      linkedServiceName: {
        parameters: {}
        referenceName: app.storage
        type: 'LinkedServiceReference'
      }
    }
  }
}

//==============================================================================
// Outputs
//==============================================================================

// TODO: Review the use of these outputs and deprecate the ones that aren't needed, remove them in 3 months

@description('Properties of the hub app.')
output app HubAppProperties = app

@description('Name of the Data Factory.')
output dataFactoryName string = app.dataFactory

@description('Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.')
output storageAccountName string = app.storage

@description('URL to use when connecting custom Power BI reports to your data.')
output storageUrlForPowerBI string = 'https://${app.storage}.dfs.${environment().suffixes.storage}/${INGESTION}'

@description('Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.')
output principalId string = dataFactory.identity.principalId

@description('Name of the managed identity used to create and stop ADF triggers.')
output triggerManagerIdentityName string = appRegistration.outputs.triggerManagerIdentityName
