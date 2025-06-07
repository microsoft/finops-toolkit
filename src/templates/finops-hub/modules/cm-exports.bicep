// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubCoreConfig } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

//------------------------------------------------------------------------------
// Temporary parameters that should be removed in the future
//------------------------------------------------------------------------------

// TODO: Pull deployment config from the cloud
@description('Required. FinOps hub coreConfig.')
param coreConfig HubCoreConfig


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration 'hub-app.bicep' = {
  name: 'Microsoft.CostManagement.Exports_Register'
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

    coreConfig: coreConfig
  }
}

// Upload schema files
module schemaFiles 'hub-storage.bicep' = {
  name: 'Microsoft.CostManagement.Exports_Storage.SchemaFiles'
  params: {
    appConfig: appRegistration.outputs.config
    container: 'config'
    files: {
      // cSpell:ignore actualcost, amortizedcost, focuscost, pricesheet, reservationdetails, reservationrecommendations, reservationtransactions
      'schemas/actualcost_c360-2025-04.json': loadTextContent('../schemas/actualcost_c360-2025-04.json')
      'schemas/amortizedcost_c360-2025-04.json': loadTextContent('../schemas/amortizedcost_c360-2025-04.json')
      'schemas/focuscost_1.2.json': loadTextContent('../schemas/focuscost_1.2.json')
      'schemas/focuscost_1.2-preview.json': loadTextContent('../schemas/focuscost_1.2-preview.json')
      'schemas/focuscost_1.0r2.json': loadTextContent('../schemas/focuscost_1.0r2.json')
      'schemas/focuscost_1.0.json': loadTextContent('../schemas/focuscost_1.0.json')
      'schemas/focuscost_1.0-preview(v1).json': loadTextContent('../schemas/focuscost_1.0-preview(v1).json')
      'schemas/pricesheet_2023-05-01_ea.json': loadTextContent('../schemas/pricesheet_2023-05-01_ea.json')
      'schemas/pricesheet_2023-05-01_mca.json': loadTextContent('../schemas/pricesheet_2023-05-01_mca.json')
      'schemas/reservationdetails_2023-03-01.json': loadTextContent('../schemas/reservationdetails_2023-03-01.json')
      'schemas/reservationrecommendations_2023-05-01_ea.json': loadTextContent('../schemas/reservationrecommendations_2023-05-01_ea.json')
      'schemas/reservationrecommendations_2023-05-01_mca.json': loadTextContent('../schemas/reservationrecommendations_2023-05-01_mca.json')
      'schemas/reservationtransactions_2023-05-01_ea.json': loadTextContent('../schemas/reservationtransactions_2023-05-01_ea.json')
      'schemas/reservationtransactions_2023-05-01_mca.json': loadTextContent('../schemas/reservationtransactions_2023-05-01_mca.json')
    }
  }
}

// Create msexports container
module exportContainer 'hub-storage.bicep' = {
  name: 'Microsoft.CostManagement.Exports_Storage.ExportContainer'
  params: {
    appConfig: appRegistration.outputs.config
    container: 'msexports'
  }
}

// TODO: Add export handling pipelines


//==============================================================================
// Outputs
//==============================================================================

@description('Name of the container used for Cost Management exports.')
output exportContainer string = exportContainer.outputs.containerName

@description('Number of schema files uploaded.')
output schemaFilesUploaded int = schemaFiles.outputs.filesUploaded
