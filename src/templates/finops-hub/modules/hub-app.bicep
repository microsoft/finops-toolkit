// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the FinOps hub instance.')
param hubName string

// @description('Required. Minimum version number supported by the FinOps hub app.')
// param hubMinVersion string

// @description('Required. Maximum version number supported by the FinOps hub app.')
// param hubMaxVersion string

@description('Required. Display name of the FinOps hub app publisher.')
param publisher string

@description('Required. Namespace to use for the FinOps hub app publisher. Must be an alphanumeric string without spaces or special characters except for periods. This value should never change and will be used to uniquely identify the publisher. A change would require migrating content to the new publisher.')
param namespace string

@description('Required. Unique identifier of the FinOps hub app. Must be an alphanumeric string without spaces or special characters. This name  should never change and will be used with the namespace to fully qualify the app. A change would require migrating content to the new app.')
param appId string

@description('Required. Display name of the FinOps hub app.')
param appName string

@description('Optional. Version number of the FinOps hub app.')
param appVersion string = ''

@description('Optional. Custom string with additional metadata to log. Must an alphanumeric string without spaces or special characters except for underscores and dashes. Must be be 50 characters or less when combined with the namespace and appId. Additional characters will be trimmed.')
param telemetryString string = ''

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var hubResourceId = '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
// var publisherResourceId = '${hubResourceId}/publishers/${namespace}'
// var appResourceId = '${publisherResourceId}/apps/${appId}'

// var publisherUniqueId = uniqueString(publisherResourceId)
// var appUniqueId = uniqueString(appResourceId)

// cSpell:ignore hubapp
var telemetryId = 'ftk-hubapp-${namespace}.${appId}${empty(telemetryString) ? '' : '_'}${telemetryString}'

//==============================================================================
// Resources
//==============================================================================

// TODO: Get hub instance to verify version compatibility

//------------------------------------------------------------------------------
// Telemetry
// Used to anonymously count the number of times the template has been deployed
// and to track and fix deployment bugs to ensure the highest quality.
// No information about you or your cost data is collected.
//------------------------------------------------------------------------------

resource appTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: length(telemetryId) <= 64 ? telemetryId : substring(telemetryId, 0, 64)
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FTK: ${publisher} - ${appName}'
          version: appVersion
        }
        // TODO: Add hubVersion
      }
      resources: []
    }
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('Name of the deployed hub instance.')
output hubId string = hubResourceId
