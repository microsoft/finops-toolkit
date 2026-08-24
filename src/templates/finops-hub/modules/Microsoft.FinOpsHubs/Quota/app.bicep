// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { finOpsToolkitVersion, HubAppProperties, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as IngestionQueriesMetadata } from '../IngestionQueries/metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.Quota'
  version: '$$ftkver$$'
  dependencies: [
    'Microsoft.FinOpsHubs.Core'
    'Microsoft.FinOpsHubs.IngestionQueries'
    'Microsoft.FinOpsHubs.AzureResourceManager'
  ]
  metadata: 'https://microsoft.github.io/finops-toolkit/deploy/finops-hub/$$ftkver$$/Microsoft.FinOpsHubs/Quota/metadata.bicep'
}


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

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
// Load query files -- quota queries are always included
var coreQueryFiles = {
  'Quota-Microsoft-AppServiceUsage': loadTextContent('queries/Quota-Microsoft-AppServiceUsage.json')
  'Quota-Microsoft-CapacityReservation': loadTextContent('queries/Quota-Microsoft-CapacityReservation.json')
  'Quota-Microsoft-CognitiveServicesUsage': loadTextContent('queries/Quota-Microsoft-CognitiveServicesUsage.json')
  'Quota-Microsoft-ComputeUsage': loadTextContent('queries/Quota-Microsoft-ComputeUsage.json')
  'Quota-Microsoft-PremiumSSDv2Disk': loadTextContent('queries/Quota-Microsoft-PremiumSSDv2Disk.json')
  'Quota-Microsoft-SqlSubscriptionUsage': loadTextContent('queries/Quota-Microsoft-SqlSubscriptionUsage.json')
  'Quota-Microsoft-StorageUsage': loadTextContent('queries/Quota-Microsoft-StorageUsage.json')
}

var queryFiles = coreQueryFiles
// </generated-query-files>

// Load schema files
var schemaFiles = {
  'quota_1.0-capacity-reservation': loadTextContent('schemas/quota_1.0-capacity-reservation.json')
  'quota_1.0-disk': loadTextContent('schemas/quota_1.0-disk.json')
  'quota_1.0-sql': loadTextContent('schemas/quota_1.0-sql.json')
  'quota_1.0-usage': loadTextContent('schemas/quota_1.0-usage.json')
}


//==============================================================================
// Resources
//==============================================================================

// Register app
module appRegistration '../../fx/hub-app.bicep' = {
  name: 'Microsoft.FinOpsHubs.Quota_Register'
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
  name: 'Microsoft.FinOpsHubs.Quota_UploadQueries'
  dependsOn: [appRegistration]
  params: {
    app: app
    container: ingestionQueries.queries.container
    files: reduce(items(queryFiles), {}, (acc, item) => union(acc, { '${ingestionQueries.queries.folder}/${item.key}.json': item.value }))
  }
}

// Upload schema files to storage
module uploadSchemas '../../fx/hub-storage.bicep' = {
  name: 'Microsoft.FinOpsHubs.Quota_UploadSchemas'
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

@description('The app properties for the Quota app.')
output app HubAppProperties = app
