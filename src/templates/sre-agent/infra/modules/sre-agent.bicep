// Copied from microsoft/sre-agent labs/starter-lab/infra/modules/sre-agent.bicep
// and updated for the FinOps Toolkit SRE Agent template.

@description('Location for resources.')
param location string

@description('SRE Agent name.')
param agentName string

@description('Application Insights App ID.')
param appInsightsAppId string

@description('Application Insights connection string.')
@secure()
param appInsightsConnectionString string

@description('Application Insights resource ID.')
param appInsightsId string

@description('Resource group IDs to add as managed resources.')
param managedResourceGroupIds array

@description('Agent access level.')
param accessLevel string

@description('Agent action mode.')
param actionMode string

@description('Agent upgrade channel.')
param upgradeChannel string

@description('Monthly agent unit limit.')
param monthlyAgentUnitLimit int

@description('Agent experimental settings.')
param experimentalSettings object

@description('Azure resource tags.')
param tags object = {}

var sreAgentAdminRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

#disable-next-line BCP081
resource sreAgent 'Microsoft.App/agents@2026-01-01' = {
  name: agentName
  location: location
  tags: union(tags, {
    'hidden-link: /app-insights-resource-id': appInsightsId
    source: 'microsoft-sre-agent-starter-lab'
    'finops-toolkit': 'sre-agent'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    knowledgeGraphConfiguration: {
      managedResources: managedResourceGroupIds
      identity: 'system'
    }
    actionConfiguration: {
      mode: actionMode
      identity: 'system'
      accessLevel: accessLevel
    }
    upgradeChannel: upgradeChannel
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
    experimentalSettings: experimentalSettings
    mcpServers: []
    logConfiguration: {
      applicationInsightsConfiguration: {
        appId: appInsightsAppId
        connectionString: appInsightsConnectionString
      }
    }
  }
}

resource sreAgentAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sreAgent.id, deployer().objectId, sreAgentAdminRoleId)
  scope: sreAgent
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sreAgentAdminRoleId)
    principalId: deployer().objectId
    principalType: 'User'
  }
}

output agentName string = sreAgent.name
output agentId string = sreAgent.id
output agentEndpoint string = sreAgent.properties.agentEndpoint
output agentPortalUrl string = 'https://sre.azure.com/#/agent/${subscription().subscriptionId}/${resourceGroup().name}/${sreAgent.name}'
output agentPrincipalId string = sreAgent.identity.principalId
output agentTenantId string = sreAgent.identity.tenantId
