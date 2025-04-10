// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the publisher-specific Data Factory instance.')
param dataFactoryName string

@description('Required. Name of the Data Factory pipeline to create or update.')
param pipelineName string
@description('Required. Properties for the Data Factory pipeline.')
param pipelineProperties object

// @description('Optional. Fully-qualified identifier of the event that should trigger this pipeline.')
// param event string


//==============================================================================
// Resources
//==============================================================================

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName

  resource pipeline 'pipelines' = {
    name: pipelineName
    properties: pipelineProperties
  }
}


//==============================================================================
// Outputs
//==============================================================================

@description('Name of the Data Factory pipeline.')
output pipelineName string = dataFactory::pipeline.name
