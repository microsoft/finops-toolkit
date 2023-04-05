// Description: The extract pipeline for cost management data.
//              The pipeline is triggered by a storage event.
//              The extract pipeline queue up the transform pipeline and then exit.
//              The extract pipeline needs to complete asap as there's a hard limit of 100 concurrent executions in ADF.
//              If multiple large, partitioned exports are running concurrently the trigger will fail to execute the transform pipeline if it takes too long to complete. 
//              Queuing up the transform pipeline and exiting immediately greatly reduces the likelihood of this happening.

@description('Required. The name of the parent Azure Data Factory..')
param dataFactoryName string

@description('Required. Export container.')
param exportContainerName string

@allowed([
  'csv'
  'parquet'
])
@description('Required. Output format.')
param outputFormat string = 'parquet'

var pipelineName = replace('${exportContainerName}_extract_${outputFormat}', '-', '_') // Pilepine names in ADF cannot contain a hyphen

var pipelineToExecute = replace('${exportContainerName}_transform_${outputFormat}', '-', '_') // Pilepine names in ADF cannot contain a hyphen

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' =  {
  name: pipelineName
  parent: dataFactoryRef
  properties: {
    activities: [
      {
        name: 'Execute'
        type: 'ExecutePipeline'
        dependsOn: []
        userProperties: []
        typeProperties: {
          pipeline: {
            referenceName: pipelineToExecute
            type: 'PipelineReference'
          }
          waitOnCompletion: false
          parameters: {
            folderName: {
              value: '@pipeline().parameters.folderName'
              type: 'Expression'
            }
            fileName: {
              value: '@pipeline().parameters.fileName'
              type: 'Expression'
            }
          }
        }
      }
    ]
    parameters: {
      folderName: {
        type: 'string'
      }
      fileName: {
        type: 'string'
      }
    }
    annotations: []
  }
}

@description('The name of the linked service.')
output name string = pipeline.name

@description('The resource ID of the linked service.')
output resourceId string = pipeline.id
