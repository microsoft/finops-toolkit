targetScope = 'subscription'

// =============================================================================
// SRE Agent subscription RBAC assignment module
// =============================================================================
// Assigns the minimum subscription-level Azure RBAC permissions required by the
// FinOps toolkit SRE Agent managed identity. The live ftk-sre deployment assigns only
// Reader and Monitoring Contributor; broader reference-lab roles are intentionally
// excluded because they are redundant or unused by this template.
// =============================================================================


// =============================================================================
// Parameters
// =============================================================================

@description('Required. Principal ID of the identity to assign roles to.')
param principalId string

@description('Optional. Principal type of the assignee. Managed identities (system- or user-assigned) are ServicePrincipal in Azure RBAC.')
@allowed([
  'User'
  'ServicePrincipal'
  'Group'
])
param principalType string = 'ServicePrincipal'


// =============================================================================
// Variables
// =============================================================================

var roles = [
  {
    name: 'Reader'
    // Reader
    id: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
  {
    name: 'Monitoring Contributor'
    // Monitoring Contributor
    id: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  }
]


// =============================================================================
// Resources
// =============================================================================

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: {
  name: guid(subscription().id, principalId, role.id)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: principalId
    principalType: principalType
  }
}]
