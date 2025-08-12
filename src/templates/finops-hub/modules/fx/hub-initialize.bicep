// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

import { HubAppProperties } from 'hub-types.bicep'


//==============================================================================
// Parameters
//==============================================================================

@description('Required. FinOps hub app getting deployed.')
param app HubAppProperties

@description('Required. List of Azure Data Factory instances to start triggers for. Can be up to 1 per publisher.')
param dataFactoryInstances string[]

@description('Required. Name of the managed identity to use when starting the triggers.')
param identityName string

@description('Optional. Start all triggers for the Data Factory instances. Default: false.')
param startAllTriggers bool = false

@description('Optional. List of pipelines to run. Default: [] (no pipelines).')
param startPipelines string[] = []


//==============================================================================
// Variables
//==============================================================================

// Clean up dataFactoryInstances array - remove empty values and duplicates
var uniqueInstances = union(filter(dataFactoryInstances, adf => !empty(adf)), [])

//==============================================================================
// Resources
//==============================================================================

// Initialize Data Factory instances (start triggers and/or run pipelines)
module initialize 'hub-deploymentScript.bicep' = [
  for adf in uniqueInstances: {
    name: 'Microsoft.FinOpsHubs.Initialize_${adf}'
    params: {
      app: app
      identityName: identityName
      scriptContent: loadTextContent('./scripts/Init-DataFactory.ps1')
      environmentVariables: [
        {
          name: 'DataFactorySubscriptionId'
          value: subscription().id
        }
        {
          name: 'DataFactoryResourceGroup'
          value: resourceGroup().name
        }
        {
          name: 'DataFactoryName'
          value: adf
        }
        {
          name: 'Pipelines'
          value: join(startPipelines, '|')
        }
        {
          name: 'StartAllTriggers'
          value: string(startAllTriggers)
        }
      ]
    }
  }
]

//==============================================================================
// Outputs
//==============================================================================

// None
