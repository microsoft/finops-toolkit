// Description: An Azure Data Factory dataset for delimited text files in Azure Blob Storage

@description('Required. The name of the parent Azure Data Factory.')
param dataFactoryName string

@description('Required. The storage account where the data resides.')
param linkedServiceName string

@description('Required. Name.')
param datasetName string

var datasetType = 'DelimitedText'
var locationType = 'AzureBlobFSLocation'
var compressionCodec = 'none'

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource dataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' =  {
  name: datasetName
  parent: dataFactoryRef
  properties: {
    annotations: []
    parameters: {
      fileName: {
        type: 'String'
      }
      folderName: {
        type: 'String'
      }
    }
    type: datasetType
    typeProperties: {
      columnDelimiter: ','
      compressionCodec: compressionCodec
      compressionLevel: 'Optimal'
      escapeChar: '"'
      firstRowAsHeader: true
      quoteChar: '"'
      location: {
        type: locationType
        fileName: {
          value: '@{dataset().fileName}'
          type: 'Expression'
        }
        folderPath: {
          value: '@{dataset().folderName}'
          type: 'Expression'
        }
      }
    }
    linkedServiceName: {
      parameters: {}
      referenceName: linkedServiceName
      type: 'LinkedServiceReference'
    }
  }
}

@description('The name of the linked service.')
output name string = dataset.name

@description('The resource ID of the linked service.')
output resourceId string = dataset.id
