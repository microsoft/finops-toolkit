targetScope = 'subscription'

// =============================================================================
// SRE Agent subscription RBAC assignment module
// =============================================================================
// Assigns the minimum subscription-level Azure RBAC permissions required by the
// FinOps SRE Agent managed identity. The live ftk-sre deployment assigns only
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

// Custom role for checkZonePeers — not included in Reader.
// Required by the zone-mapping Python tool for cross-subscription zone alignment.
resource zonePeersRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'finops-sre-zone-peers')
  properties: {
    roleName: 'FinOps SRE Zone Peers Reader'
    description: 'Allows checking availability zone peer mappings across subscriptions. Used by the zone-mapping Python tool.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/checkZonePeers/action'
        ]
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource zonePeersAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, zonePeersRole.id)
  properties: {
    roleDefinitionId: zonePeersRole.id
    principalId: principalId
    principalType: principalType
  }
}
