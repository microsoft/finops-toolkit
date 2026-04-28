targetScope = 'subscription'

// =============================================================================
// SRE Agent subscription deployment entry point
// =============================================================================
// Creates the target resource group, deploys the FinOps SRE Agent resources into
// that group, and assigns required subscription and optional Azure Data Explorer
// permissions to the agent managed identity.
// =============================================================================


// =============================================================================
// Parameters
// =============================================================================

@description('Required. Name of the azd environment.')
param environmentName string

@description('Optional. Primary location for all resources.')
@allowed([
  'swedencentral'
  'eastus2'
  'australiaeast'
])
param location string = 'eastus2'

@description('Optional. Resource group name override. Defaults to rg-{environmentName}.')
param resourceGroupName string = 'rg-${environmentName}'

@description('Optional. ADX cluster name for conditional FinOps Hub role assignment.')
param adxClusterName string = ''

@description('Optional. Resource group containing the ADX cluster.')
param adxClusterResourceGroupName string = ''

@description('Optional. Principal type of the deploying identity. Use ServicePrincipal for CI/CD pipelines.')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

@description('Optional. FinOps Hub ADX cluster URI with database name (e.g. https://cluster.region.kusto.windows.net/hub).')
param finopsHubClusterUri string = ''


// =============================================================================
// Resources
// =============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}


// =============================================================================
// Modules
// =============================================================================

module resources 'resources.bicep' = {
  name: 'resources-deployment'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    deployerObjectId: deployer().objectId
    deployerPrincipalType: deployerPrincipalType
    finopsHubClusterUri: finopsHubClusterUri
  }
}

module subscriptionRbac 'modules/subscription-rbac.bicep' = {
  name: 'subscription-rbac'
  params: {
    principalId: resources.outputs.identityPrincipalId
  }
}

module adxRole 'modules/adx-role.bicep' = if (!empty(adxClusterName) && !empty(adxClusterResourceGroupName)) {
  name: 'adx-role'
  scope: resourceGroup(adxClusterResourceGroupName)
  params: {
    clusterName: adxClusterName
    principalId: resources.outputs.identityPrincipalId
  }
}

module adxRoleSystem 'modules/adx-role.bicep' = if (!empty(adxClusterName) && !empty(adxClusterResourceGroupName)) {
  name: 'adx-role-system'
  scope: resourceGroup(adxClusterResourceGroupName)
  params: {
    clusterName: adxClusterName
    principalId: resources.outputs.systemPrincipalId
  }
}


// =============================================================================
// Outputs
// =============================================================================

@description('Name of the Azure resource group containing the SRE Agent resources.')
output AZURE_RESOURCE_GROUP string = rg.name

@description('Azure location used for the SRE Agent resources.')
output AZURE_LOCATION string = location

@description('Name of the deployed SRE Agent resource.')
output SRE_AGENT_NAME string = resources.outputs.agentName

@description('Endpoint of the deployed SRE Agent resource.')
output SRE_AGENT_ENDPOINT string = resources.outputs.agentEndpoint
