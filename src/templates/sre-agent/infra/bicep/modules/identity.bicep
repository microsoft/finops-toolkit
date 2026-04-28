// =============================================================================
// SRE Agent user-assigned managed identity module
// =============================================================================
// Creates the single user-assigned managed identity used by the FinOps SRE Agent.
// =============================================================================

@description('Required. Resource location.')
param location string

@description('Required. Identity resource name.')
param identityName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

@description('Resource ID of the user-assigned managed identity.')
output identityId string = userAssignedIdentity.id

@description('Name of the user-assigned managed identity.')
output identityName string = userAssignedIdentity.name

@description('Principal ID of the user-assigned managed identity.')
output identityPrincipalId string = userAssignedIdentity.properties.principalId

@description('Client ID of the user-assigned managed identity.')
output identityClientId string = userAssignedIdentity.properties.clientId
