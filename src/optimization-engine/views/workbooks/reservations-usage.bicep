@description('The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group.')
param workbookDisplayName string = 'Reservations Usage'

@description('The gallery that the workbook will been shown under. Supported values include workbook, tsg, etc. Usually, this is \'workbook\'')
param workbookType string = 'workbook'

@description('The id of resource instance to which the workbook will be associated')
param workbookSourceId string

@description('The unique guid for this workbook instance')
param workbookId string = '5fc75aa1-db43-4938-bbea-90dcb71ef5a2'
param resourceTags object

param resourceGroupLocation string = resourceGroup().location

resource workbookId_resource 'microsoft.insights/workbooks@2022-04-01' = {
  name: workbookId
  location: resourceGroupLocation
  tags: resourceTags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(loadJsonContent('reservations-usage.json'))
    version: '1.0'
    sourceId: workbookSourceId
    category: workbookType
  }
  dependsOn: []
}

output workbookId string = workbookId_resource.id
