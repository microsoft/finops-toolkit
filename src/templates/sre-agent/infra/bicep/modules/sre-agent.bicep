// =============================================================================
// SRE Agent resource module
// =============================================================================
// Creates the FinOps SRE Agent by using the Microsoft.App/agents API and
// assigns the deploying principal the SRE Agent Administrator role. The action
// mode is intentionally set to Autonomous based on live deployment validation
// so that scheduled tasks can deliver reports to Teams without human approval.
// =============================================================================

@description('Required. Resource location.')
param location string

@description('Required. Agent resource name.')
param agentName string

@description('Required. Full ARM resource ID of the user-assigned managed identity.')
param identityId string

@description('Required. Application ID of the Application Insights component.')
param appInsightsAppId string

@secure()
@description('Required. Connection string for the Application Insights component.')
param appInsightsConnectionString string

@description('Required. Resource ID of the Application Insights component used for the hidden-link tag.')
param appInsightsId string

@description('Required. Object ID of the deploying principal.')
param deployerObjectId string

@description('Optional. Principal type of the deploying principal.')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

@description('Optional. FinOps Hub ADX cluster URI with database name (e.g. https://cluster.region.kusto.windows.net/hub).')
param finopsHubClusterUri string = ''

// SRE Agent Administrator
var sreAgentAdminRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

// Preview API — 2026-01-01 is documented but not yet registered in the resource provider.
#disable-next-line BCP081
resource sreAgent 'Microsoft.App/agents@2025-05-01-preview' = {
  name: agentName
  location: location
  tags: {
    'hidden-link: /app-insights-resource-id': appInsightsId
  }
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    knowledgeGraphConfiguration: {
      managedResources: [
        resourceGroup().id
      ]
      identity: identityId
    }
    // Microsoft Learn:
    // - Tools in Azure SRE Agent: built-in visualization and code execution are platform capabilities.
    // - Use Code Interpreter: the portal exposes this through the Early access toggle.
    // Keep workspace tools enabled in IaC so code-interpreter-backed workflows are available by default.
    experimentalSettings: {
      EnableV2AgentLoop: true
      EnableWorkspaceTools: true
    }
    actionConfiguration: {
      mode: 'Autonomous'
      identity: identityId
    }
    logConfiguration: {
      applicationInsightsConfiguration: {
        appId: appInsightsAppId
        connectionString: appInsightsConnectionString
      }
    }
    mcpServers: []
  }
}

resource sreAgentAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sreAgent.id, deployerObjectId, sreAgentAdminRoleId)
  scope: sreAgent
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sreAgentAdminRoleId)
    principalId: deployerObjectId
    principalType: deployerPrincipalType
  }
}

#disable-next-line BCP081
resource finopsHubConnector 'Microsoft.App/agents/dataConnectors@2025-05-01-preview' = if (!empty(finopsHubClusterUri)) {
  parent: sreAgent
  name: 'finops-hub-kusto'
  properties: {
    dataConnectorType: 'Kusto'
    dataSource: finopsHubClusterUri
    identity: 'system'
  }
}

@description('Name of the SRE Agent resource.')
output agentName string = sreAgent.name

@description('Resource ID of the SRE Agent resource.')
output agentId string = sreAgent.id

@description('Endpoint of the SRE Agent resource.')
output agentEndpoint string = sreAgent.properties.agentEndpoint

@description('Principal ID of the system-assigned managed identity.')
output systemPrincipalId string = sreAgent.identity.principalId
