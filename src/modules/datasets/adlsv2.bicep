// Description: An Azure Data Factory dataset for parquet or delimited text files in Azure Blob Storage

@description('Required. The name of the parent Azure Data Factory.')
param dataFactoryName string

@description('Required. The storage account where the data resides.')
param linkedServiceName string

@description('Required. The container where the data resides.')
param containerName string

@allowed([
  'DelimitedText'
  'Parquet'
])
@description('Required. Type of the dataset.')
param datasetType string

@allowed([
  'none'
  'gzip'
])
@description('Required. Compression codec to use.')
param compressionCodec string

@description('Required. Name of the dataset.')
var datasetName = replace('${containerName}_${datasetType}', '-', '_') // ADLS Gen2 object names can't have hyphens

var csvProps = {       
                  columnDelimiter: ','
                  compressionCodec: compressionCodec
                  compressionLevel: 'Optimal'
                  escapeChar: '"'
                  firstRowAsHeader: true
                  quoteChar: '"' 
                }
var parquetProps = { 
                      compressionCodec: compressionCodec
                    }
var commonProps =  {
                      location: {
                        type: 'AzureBlobFSLocation'
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

var typeProperties = union(commonProps, datasetType == 'Parquet' ? parquetProps : csvProps)


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
    typeProperties: typeProperties
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
