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

@description('Required. Namespace to use for the FinOps hub app publisher. Will be combined with appName to form a fully-qualified identifier. Must be an alphanumeric string without spaces or special characters except for periods. This value should never change and will be used to uniquely identify the publisher. A change would require migrating content to the new publisher. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param namespace string

@description('Required. Unique identifier of the FinOps hub app within the publisher namespace. Must be an alphanumeric string without spaces or special characters. This name should never change and will be used with the namespace to fully qualify the app. A change would require migrating content to the new app. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param appName string

@description('Required. Display name of the FinOps hub app.')
param displayName string

@description('Optional. Version number of the FinOps hub app.')
param appVersion string = ''

@description('Optional. Custom string with additional metadata to log. Must an alphanumeric string without spaces or special characters except for underscores and dashes. Namespace + appName + telemetryString must be 50 characters or less - additional characters will be trimmed.')
param telemetryString string = ''

@description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

var hubResourceId = '${resourceGroup().id}/providers/Microsoft.Cloud/hubs/${hubName}'
// var publisherResourceId = '${hubResourceId}/publishers/${namespace}'
// var appResourceId = '${publisherResourceId}/apps/${appName}'

// var publisherUniqueId = uniqueString(publisherResourceId)
// var appUniqueId = uniqueString(appResourceId)

// cSpell:ignore hubapp
var appNamespace = '${namespace}.${appName}'
var telemetryId = 'ftk-hubapp-${appNamespace}${empty(telemetryString) ? '' : '_'}${telemetryString}'

// cSpell:ignore ftkver
// Add cm-resource-parent to group resources in Cost Management
var finOpsToolkitVersion = loadTextContent('ftkver.txt')
var tags = {
  'cm-resource-parent': hubResourceId
  'ftk-tool': 'FinOps hubs'
  'ftk-version': finOpsToolkitVersion
  'ftk-hubapp': appNamespace
  'ftk-hubapp-version': appVersion
}


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
  tags: tags
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FTK: ${publisher} - ${displayName}'
          version: appVersion
        }
      }
      resources: []
    }
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('Resource ID of the deployed FinOps hub instance.')
output hubId string = hubResourceId

@description('Resource ID of the deployed FinOps hub instance.')
output appNamespace string = '${appNamespace}'
