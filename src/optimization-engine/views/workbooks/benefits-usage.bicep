@description('The friendly name for the workbook that is used in the Gallery or Saved List.  This name must be unique within a resource group.')
param workbookDisplayName string = 'Benefits Usage'

@description('The gallery that the workbook will been shown under. Supported values include workbook, tsg, etc. Usually, this is \'workbook\'')
param workbookType string = 'workbook'

@description('The id of resource instance to which the workbook will be associated')
param workbookSourceId string

@description('The unique guid for this workbook instance')
param workbookId string = '4730b9ab-9f13-4c28-a999-bcce218b283d'
param resourceTags object

param resourceGroupLocation string = resourceGroup().location

resource workbookId_resource 'microsoft.insights/workbooks@2022-04-01' = {
  name: workbookId
  location: resourceGroupLocation
  tags: resourceTags
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    serializedData: string(loadJsonContent('benefits-usage.json'))
    version: '1.0'
    sourceId: workbookSourceId
    category: workbookType
  }
  dependsOn: []
}

output workbookId string = workbookId_resource.id
