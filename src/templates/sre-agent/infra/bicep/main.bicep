// =============================================================================
// FinOps toolkit SRE agent deployment
// =============================================================================
// Deploys the FinOps SRE Agent with optional FinOps hub co-deployment.
//
// Three modes:
//   1. Agent only:          omit finopsHubClusterUri and DEPLOY_FINOPS_HUB
//   2. Agent + existing hub: set finopsHubClusterUri to an existing cluster
//   3. Agent + new hub:      set DEPLOY_FINOPS_HUB = true
//
// Subscription-level RBAC (Reader, Monitoring Contributor) is handled by
// post-provision scripts, not Bicep, to keep this template resource-group scoped.
// =============================================================================


// =============================================================================
// Parameters
// =============================================================================

@description('Required. Name of the azd environment.')
param environmentName string

@description('Optional. Primary location for all resources. SRE Agent requires swedencentral, eastus2, or australiaeast. When DEPLOY_FINOPS_HUB is true, the hub is deployed to the same location.')
param location string = 'eastus2'

@description('Optional. Principal type of the deploying identity. Use ServicePrincipal for CI/CD pipelines.')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

@description('Optional. FinOps Hub ADX cluster URI (e.g. https://cluster.region.kusto.windows.net). Used to configure the Kusto connector. Ignored when DEPLOY_FINOPS_HUB is true.')
param finopsHubClusterUri string = ''

@description('Optional. Deploy a FinOps hub alongside the SRE agent. Set to true to deploy a full FinOps hub (ADX, storage, Data Factory) and auto-wire the Kusto connector.')
@allowed([
  'false'
  'true'
])
param DEPLOY_FINOPS_HUB string = 'false'

@description('Optional. ADX cluster SKU for the deployed FinOps hub. Only used when DEPLOY_FINOPS_HUB is true.')
param FINOPS_HUB_DATA_EXPLORER_SKU string = 'Standard_E2ads_v5'

@description('Optional for Bicep, required for manual azd deployments that connect to an existing FinOps Hub. The packaged wrapper resolves this from finopsHubClusterUri.')
param adxClusterName string = ''

@description('Optional for Bicep, required for manual azd deployments that connect to an existing FinOps Hub. The packaged wrapper resolves this from finopsHubClusterUri.')
param adxClusterResourceGroupName string = ''


// =============================================================================
// Variables
// =============================================================================

var hubClusterName = 'adx-${environmentName}'
var deployFinopsHub = toLower(DEPLOY_FINOPS_HUB) == 'true'


// =============================================================================
// Modules
// =============================================================================

// --- FinOps hub (optional co-deployment) ---

module finopsHub '../../../finops-hub/main.bicep' = if (deployFinopsHub) {
  name: 'finops-hub'
  params: {
    hubName: 'finopshub-${environmentName}'
    location: location
    dataExplorerName: hubClusterName
    dataExplorerSku: FINOPS_HUB_DATA_EXPLORER_SKU
  }
}

// --- SRE Agent resources (with co-deployed hub) ---

module resourcesWithHub 'resources.bicep' = if (deployFinopsHub) {
  name: 'resources-deployment'
  params: {
    environmentName: environmentName
    location: location
    deployerObjectId: deployer().objectId
    deployerPrincipalType: deployerPrincipalType
    finopsHubClusterUri: finopsHub.outputs.clusterUri
  }
}

// --- SRE Agent resources (without co-deployed hub) ---

module resourcesStandalone 'resources.bicep' = if (!deployFinopsHub) {
  name: 'resources-deployment'
  params: {
    environmentName: environmentName
    location: location
    deployerObjectId: deployer().objectId
    deployerPrincipalType: deployerPrincipalType
    finopsHubClusterUri: finopsHubClusterUri
  }
}

// --- ADX role assignments ---

// Co-deployed hub: cluster is in the same RG
module adxRoleDeployed 'modules/adx-role.bicep' = if (deployFinopsHub) {
  name: 'adx-role-deployed'
  params: {
    clusterName: hubClusterName
    principalId: resourcesWithHub.outputs.identityPrincipalId
  }
}

module adxRoleDeployedSystem 'modules/adx-role.bicep' = if (deployFinopsHub) {
  name: 'adx-role-deployed-system'
  params: {
    clusterName: hubClusterName
    principalId: resourcesWithHub.outputs.systemPrincipalId
  }
}

// External hub: cluster is in a different RG
module adxRole 'modules/adx-role.bicep' = if (!deployFinopsHub && !empty(adxClusterName) && !empty(adxClusterResourceGroupName)) {
  name: 'adx-role'
  scope: resourceGroup(adxClusterResourceGroupName)
  params: {
    clusterName: adxClusterName
    principalId: resourcesStandalone.outputs.identityPrincipalId
  }
}

module adxRoleSystem 'modules/adx-role.bicep' = if (!deployFinopsHub && !empty(adxClusterName) && !empty(adxClusterResourceGroupName)) {
  name: 'adx-role-system'
  scope: resourceGroup(adxClusterResourceGroupName)
  params: {
    clusterName: adxClusterName
    principalId: resourcesStandalone.outputs.systemPrincipalId
  }
}


// =============================================================================
// Outputs
// =============================================================================

@description('Name of the deployed SRE Agent resource.')
output SRE_AGENT_NAME string = deployFinopsHub ? resourcesWithHub.outputs.agentName : resourcesStandalone.outputs.agentName

@description('Endpoint of the deployed SRE Agent resource.')
output SRE_AGENT_ENDPOINT string = deployFinopsHub ? resourcesWithHub.outputs.agentEndpoint : resourcesStandalone.outputs.agentEndpoint

@description('URI of the FinOps Hub ADX cluster. Empty if no hub was deployed or connected.')
output FINOPS_HUB_CLUSTER_URI string = deployFinopsHub ? finopsHub.outputs.clusterUri : finopsHubClusterUri

@description('Name of the deployed FinOps hub. Empty if no hub was deployed.')
output FINOPS_HUB_NAME string = deployFinopsHub ? finopsHub.outputs.name : ''

@description('User-assigned managed identity principal ID for post-provision RBAC.')
output IDENTITY_PRINCIPAL_ID string = deployFinopsHub ? resourcesWithHub.outputs.identityPrincipalId : resourcesStandalone.outputs.identityPrincipalId
