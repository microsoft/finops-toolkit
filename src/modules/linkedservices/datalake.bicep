// Description: An Azure Data Factory Linked Service to access and store data in Azure Data Lake Storage Gen2.
//              Authenticated using a storage account key stored in Azure Key Vault.

@description('Conditional. The name of the parent Azure Data Factory. Required if the template is used in a standalone deployment.')
param dataFactoryName string

@description('The name of the storage account.')
param storageAccountName string

@description('The name of the keyvault.')
param keyVaultName string

var linkedServiceName = storageAccountName
var linkedServiceType = 'AzureBlobFS'

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource linkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: linkedServiceName
  parent: dataFactoryRef
  properties: {
    description: 'string'
    annotations: []
    parameters: {}
    type: linkedServiceType
    typeProperties: {
        url: reference('Microsoft.Storage/storageAccounts/${storageAccountName}', '2019-04-01').primaryEndpoints.dfs
        accountKey: {
          type: 'AzureKeyVaultSecret'
          store: {
            referenceName: keyVaultName
            type: 'LinkedServiceReference'
          }
          secretName: linkedServiceName
        }
      }
  }
}

@description('The name of the linked service.')
output name string = linkedService.name

@description('The resource ID of the linked service.')
output resourceId string = linkedService.id
