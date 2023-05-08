//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the Key Vault. Must be globally unique.')
@maxLength(24)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Array of access policies object.')
param accessPolicies array = []

@description('Optional. All secrets to create.')
@secure()
param secrets object = {}

@description('Optional. Specifies the SKU for the vault.')
@allowed([
  'premium'
  'standard'
])
param vaultSku string = 'premium'

@description('Optional. Resource tags.')
param tags object = {}

var formattedAccessPolicies = [for accessPolicy in accessPolicies: {
  applicationId: contains(accessPolicy, 'applicationId') ? accessPolicy.applicationId : ''
  objectId: contains(accessPolicy, 'objectId') ? accessPolicy.objectId : ''
  permissions: accessPolicy.permissions
  tenantId: contains(accessPolicy, 'tenantId') ? accessPolicy.tenantId : tenant().tenantId
}]

var secretList = !empty(secrets) ? secrets.secureList : []

//==============================================================================
// Resources
//==============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: false
    createMode: 'default'
    enablePurgeProtection: false
    tenantId: subscription().tenantId
    accessPolicies: formattedAccessPolicies
    sku: {
      name: vaultSku
      family: 'A'
    }
  }
}

resource keyVault_accessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2021-06-01-preview' = if (!empty(accessPolicies)) {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: formattedAccessPolicies
  }
}

resource keyVault_secrets 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = [for (secret, index) in secretList: {
  name: secret.name
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exp: contains(secret, 'attributesExp') ? secret.attributesExp : null
      nbf: contains(secret, 'attributesNbf') ? secret.attributesNbf : null
    }
    value: secret.value
  }
}]

//==============================================================================
// Outputs
//==============================================================================

@description('The resource ID of the key vault.')
output resourceId string = keyVault.id

@description('The name of the key vault.')
output name string = keyVault.name

@description('The URI of the key vault.')
output uri string = keyVault.properties.vaultUri
