// Source: 
// Date: 2023-02-02
// Version: 

@description('Required. The name of the parent Azure Data Factory.')
param dataFactoryName string

@description('The name of the keyvault.')
param keyVaultName string

resource dataFactoryRef 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource linkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: keyVaultName
  parent: dataFactoryRef
  properties: {
    description: 'string'
    annotations: []
    parameters: {}
    type: 'AzureKeyVault'
    typeProperties:  {
        baseUrl: reference('Microsoft.KeyVault/vaults/${keyVaultName}', '2022-11-01').vaultUri
      } 
  }
}

@description('The name of the linked service.')
output name string = linkedService.name

@description('The resource ID of the linked service.')
output resourceId string = linkedService.id
