// Copied from microsoft/sre-agent labs/starter-lab/infra/resources.bicep and
// updated for the FinOps Toolkit SRE Agent template.

@description('SRE Agent name.')
param agentName string

@description('Location for all resources.')
param location string

@description('Deterministic naming seed built from subscription ID, agent resource group ID, and agent name.')
param namingSeed string

@description('Resource group IDs shown as managed resources in the SRE Agent.')
param targetResourceGroupIds array

@description('Agent access level.')
param accessLevel string

@description('Agent action mode.')
param actionMode string

@description('Azure resource tags.')
param tags object = {}

var uniqueSuffix = uniqueString(namingSeed)
var logAnalyticsName = 'law-${uniqueSuffix}'
var appInsightsName = 'appi-${uniqueSuffix}'
var identityName = '${agentName}-id-${uniqueSuffix}'

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    identityName: identityName
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
    managedResourceGroupIds: targetResourceGroupIds
    accessLevel: accessLevel
    actionMode: actionMode
    tags: tags
  }
}

output agentName string = sreAgent.outputs.agentName
output agentEndpoint string = sreAgent.outputs.agentEndpoint
output agentPortalUrl string = sreAgent.outputs.agentPortalUrl
output identityId string = identity.outputs.identityId
output identityPrincipalId string = identity.outputs.identityPrincipalId
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
