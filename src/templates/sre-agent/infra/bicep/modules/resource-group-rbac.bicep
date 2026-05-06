// =============================================================================
// SRE Agent managed resource group RBAC assignment module
// =============================================================================
// Assigns the Azure RBAC permissions required by the FinOps toolkit SRE Agent
// user-assigned managed identity on a managed resource group.
// =============================================================================

@description('Required. Principal ID of the SRE Agent user-assigned managed identity to assign roles to.')
param principalId string

@description('Optional. Principal type of the assignee. Managed identities are ServicePrincipal in Azure RBAC.')
@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
param principalType string = 'ServicePrincipal'

var roles = [
  {
    name: 'Reader'
    id: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
  {
    name: 'Monitoring Contributor'
    id: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  }
]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: {
  name: guid(resourceGroup().id, principalId, role.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: principalId
    principalType: principalType
  }
}]
