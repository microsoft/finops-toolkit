// =============================================================================
// SRE Agent resource group orchestrator
// =============================================================================
// Wires the FinOps toolkit SRE Agent leaf modules together and surfaces outputs for the
// subscription-scoped deployment entry point.
// =============================================================================

@description('Required. Environment name used to generate unique resource names.')
param environmentName string

@description('Required. Resource location.')
param location string

@description('Required. Object ID of the deploying principal assigned the SRE Agent Administrator role.')
param deployerObjectId string

@description('Optional. Principal type of the deploying principal.')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

@description('Optional. FinOps Hub ADX cluster URI with database name for Kusto connector.')
param finopsHubClusterUri string = ''

// =============================================================================
// Variables
// =============================================================================

var uniqueSuffix = uniqueString(resourceGroup().id, environmentName)
var identityName = 'id-sre-${uniqueSuffix}'
var logAnalyticsName = 'law-${uniqueSuffix}'
var appInsightsName = 'appi-${uniqueSuffix}'
var agentName = 'sre-agent-${uniqueSuffix}'

// =============================================================================
// Modules
// =============================================================================

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    identityName: identityName
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
  }
}

module sreAgent 'modules/sre-agent.bicep' = {
  name: 'sre-agent'
  params: {
    location: location
    agentName: agentName
    identityId: identity.outputs.identityId
    appInsightsAppId: monitoring.outputs.appInsightsAppId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsId: monitoring.outputs.appInsightsId
    deployerObjectId: deployerObjectId
    deployerPrincipalType: deployerPrincipalType
    finopsHubClusterUri: finopsHubClusterUri
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('Name of the SRE Agent resource.')
output agentName string = sreAgent.outputs.agentName

@description('Endpoint of the SRE Agent resource.')
output agentEndpoint string = sreAgent.outputs.agentEndpoint

@description('Principal ID of the SRE Agent user-assigned managed identity.')
output identityPrincipalId string = identity.outputs.identityPrincipalId

@description('Principal ID of the SRE Agent system-assigned managed identity.')
output systemPrincipalId string = sreAgent.outputs.systemPrincipalId
