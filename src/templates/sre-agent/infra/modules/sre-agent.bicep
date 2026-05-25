// Copied from microsoft/sre-agent labs/starter-lab/infra/modules/sre-agent.bicep
// and updated for the FinOps Toolkit SRE Agent template.

@description('Location for resources.')
param location string

@description('SRE Agent name.')
param agentName string

@description('User-assigned managed identity resource ID.')
param identityId string

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

@description('Azure resource tags.')
param tags object = {}

var sreAgentAdminRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

#disable-next-line BCP081
resource sreAgent 'Microsoft.App/agents@2025-05-01-preview' = {
  name: agentName
  location: location
  tags: union(tags, {
    'hidden-link: /app-insights-resource-id': appInsightsId
    source: 'microsoft-sre-agent-starter-lab'
    'finops-toolkit': 'sre-agent'
  })
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    knowledgeGraphConfiguration: {
      managedResources: managedResourceGroupIds
      identity: identityId
    }
    actionConfiguration: {
      mode: actionMode
      identity: identityId
      accessLevel: accessLevel
    }
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
