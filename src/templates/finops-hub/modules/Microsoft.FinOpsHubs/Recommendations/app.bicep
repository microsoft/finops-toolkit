// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as IngestionQueriesMetadata } from '../IngestionQueries/metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.Recommendations'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.FinOpsHubs.IngestionQueries'
    'Microsoft.FinOpsHubs.AzureResourceGraph'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/$$ftkver$$/Microsoft.FinOpsHubs/Recommendations/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Optional. Indicates whether to enable Azure Hybrid Benefit recommendations. These recommendations flag VMs and SQL VMs without Azure Hybrid Benefit enabled, which may generate noise if your organization does not have on-premises licenses. Default: false.')
param enableAHBRecommendations bool = false

@description('Optional. Indicates whether to enable non-Spot AKS cluster recommendations. These recommendations flag AKS clusters that use autoscaling without Spot VMs, which may generate noise since Spot VMs are only appropriate for interruptible workloads. Default: false.')
param enableSpotRecommendations bool = false

@description('Required. Metadata describing shared resources from the Core app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'Core app version must be 13.0 or higher.')
param core CoreMetadata

@description('Required. Metadata describing resources from the Ingestion Queries app. Must be v13 or higher.')
@validate(x => isSupportedVersion(x.version, '13.0', ''), 'IngestionQueries app version must be 13.0 or higher.')
param ingestionQueries IngestionQueriesMetadata

//==============================================================================
// Variables
//==============================================================================

// <generated-query-files>
// Query file entries are generated during build by Build-HubIngestionQueries.ps1.
// Do not edit this section manually. The build script scans the queries/ folder and
// generates loadTextContent entries grouped by the optional "group" field in each JSON file.
var queryFiles = {}
// </generated-query-files>

// Load schema files
var schemaFiles = {
  'recommendations_1.0': loadTextContent('schemas/recommendations_1.0.json')
}


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_Register'
  params: {
    app: app
    version: finOpsToolkitVersion
    features: [
      'Storage'      // Storing queries and schemas
    ]
  }
}

//------------------------------------------------------------------------------
// Storage
//------------------------------------------------------------------------------

// Upload query files to storage
module uploadQueries '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_UploadQueries'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: ingestionQueries.queries.container
    files: reduce(items(queryFiles), {}, (acc, item) => union(acc, { '${ingestionQueries.queries.folder}/${item.key}.json': item.value }))
  }
}

// Upload schema files to storage
module uploadSchemas '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Recommendations_UploadSchemas'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: core.containers.config
    files: reduce(items(schemaFiles), {}, (acc, item) => union(acc, { 'schemas/${item.key}.json': item.value }))
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('The app properties for the Recommendations app.')
output app HubAppProperties = app
