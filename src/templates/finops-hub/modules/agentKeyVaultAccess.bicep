// Configures Key Vault access for AI Hub and Project managed identities
// Supports both RBAC and Access Policy modes

@description('Key Vault name')
param keyVaultName string

@description('AI Hub managed identity principal ID')
param aiHubPrincipalId string

@description('AI Project managed identity principal ID') 
param aiProjectPrincipalId string

@description('AI Services managed identity principal ID')
param aiServicesPrincipalId string = ''

@description('Enable RBAC mode for Key Vault (false = use access policies)')
param enableRbacAuthorization bool = true

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Update Key Vault to add access policies if not using RBAC
resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = if (!enableRbacAuthorization) {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aiHubPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
          keys: [
            'get'
            'list'
            'create'
            'delete'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: aiProjectPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
          keys: [
            'get'
            'list'
            'create'
            'delete'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Add access policy for AI Services if principal ID is provided
resource keyVaultAccessPoliciesAIServices 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = if (!enableRbacAuthorization && !empty(aiServicesPrincipalId)) {
  name: 'add'
  parent: keyVault
  dependsOn: [
    keyVaultAccessPolicies
  ]
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aiServicesPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          keys: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri