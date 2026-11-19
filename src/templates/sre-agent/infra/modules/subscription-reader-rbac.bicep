targetScope = 'subscription'

@description('Object ID of the current SRE Agent system-assigned managed identity.')
param principalId string

param enableReader bool
param enableCostManagementReader bool

var roleIds = concat(
  enableReader ? ['acdd72a7-3385-48ef-bd42-f606fba81ae7'] : [],
  enableCostManagementReader ? ['72fafb9e-0641-4937-9268-a91bfd8191a3'] : []
)

// Name by principal so recreating a deleted agent doesn't try to change an immutable assignment.
resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleId in roleIds: {
  name: guid(subscription().id, principalId, roleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
