@description('Required. The KeyVault to store the secret in.')
param keyVaultName string

@description('Required. The name of the storage account to create the secret for.')
param storageAccountName string

var secretName = 'ms_cm_exports'

resource storageAccountRef 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  scope: resourceGroup(resourceGroup().name)
}

module storageAccountSecret '../Microsoft.KeyVault/vaults/secrets/deploy.bicep' = {
  name: secretName
  dependsOn: [
    storageAccountRef
  ]
  params: {
    name: storageAccountRef.name
    keyVaultName: keyVaultName
    value: storageAccountRef.listKeys().keys[0].value
    attributesExp: 1702648632
    attributesNbf: 10000
  }
}
