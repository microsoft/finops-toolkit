// Description: An Azure Data Factory Linked Service.

@description('Required. The name of the parent Azure Data Factory.')
param dataFactoryName string

@description('Required. The name of the linked service.')
param linkedServiceName string

@allowed([
  'AzureBlobFS'
  'AzureKeyVault'
])
@description('Required. The type of the linked service.')
param linkedServiceType string

@description('Required. The type properties object for the linked service.')
param linkedServiceTypeProperties object

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource linkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: linkedServiceName
  parent: dataFactoryRef
  properties: {
    annotations: []
    parameters: {}
#disable-next-line BCP225 // Suppress the compiler warning because the type is dynamic.
    type: linkedServiceType
    typeProperties: linkedServiceTypeProperties
  }
}

@description('The name of the linked service.')
output name string = linkedService.name

@description('The resource ID of the linked service.')
output resourceId string = linkedService.id
