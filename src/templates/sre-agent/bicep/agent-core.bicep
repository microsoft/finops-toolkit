// shared/modules/agent-core.bicep
// Creates: Agent resource + Managed Identity + Log Analytics + App Insights + RBAC + Admin role
// Used by both github-emu and ado templates

param agentName string
param location string
param suffix string
@allowed(['High', 'Low'])
param accessLevel string
@allowed(['Review', 'Autonomous', 'ReadOnly'])
param actionMode string = 'Review'
param targetResourceGroups array
param subscriptionId string
@allowed(['Stable', 'Preview'])
param upgradeChannel string = 'Preview'
param monthlyAgentUnitLimit int = 10000
param defaultModelProvider string = 'MicrosoftFoundry'
param defaultModelName string = 'Automatic'
param tags object = {}

@description('Optional. Resource ID of an existing User-Assigned Managed Identity. If provided, skips creating a new one.')
param existingManagedIdentityId string = ''

@description('Optional. Resource ID of an existing Application Insights for agent telemetry. If provided, skips creating a new one.')
param existingAgentAppInsightsId string = ''

// ── Observability ──

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${suffix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (empty(existingAgentAppInsightsId)) {
  name: 'ai-${suffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'SreAgent'
    WorkspaceResourceId: law.id
  }
}

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(existingAgentAppInsightsId)) {
  name: last(split(existingAgentAppInsightsId, '/'))
  scope: resourceGroup(split(existingAgentAppInsightsId, '/')[2], split(existingAgentAppInsightsId, '/')[4])
}

var effectiveAppInsightsAppId = empty(existingAgentAppInsightsId) ? appInsights.properties.AppId : existingAppInsights.properties.AppId
var effectiveAppInsightsConnStr = empty(existingAgentAppInsightsId) ? appInsights.properties.ConnectionString : existingAppInsights.properties.ConnectionString

// ── Managed Identity ──

#disable-next-line BCP073
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = if (empty(existingManagedIdentityId)) {
  name: '${agentName}-id-${suffix}'
  location: location
  properties: { isolationScope: 'Regional' }
}

resource existingIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = if (!empty(existingManagedIdentityId)) {
  name: last(split(existingManagedIdentityId, '/'))
  scope: resourceGroup(split(existingManagedIdentityId, '/')[2], split(existingManagedIdentityId, '/')[4])
}

var effectiveIdentityId = empty(existingManagedIdentityId) ? identity.id : existingManagedIdentityId
var effectivePrincipalId = empty(existingManagedIdentityId) ? identity.properties.principalId : existingIdentity.properties.principalId

// ── RBAC on target resource groups ──

module targetRbac 'role-assignments-target.bicep' = [for (rg, i) in targetResourceGroups: {
  name: 'rbac-${i}-${uniqueString(deployment().name)}'
  scope: resourceGroup(subscriptionId, rg)
  params: {
    principalId: effectivePrincipalId
    accessLevel: accessLevel
  }
}]

// ── Monitoring Reader on deployment RG ──

resource monitoringReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, effectiveIdentityId, '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
    principalId: effectivePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── SRE Agent ──

#disable-next-line BCP081
resource sreAgent 'Microsoft.App/agents@2025-05-01-preview' = {
  name: agentName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: { '${effectiveIdentityId}': {} }
  }
  properties: {
    knowledgeGraphConfiguration: {
      identity: effectiveIdentityId
      // Tells the agent which RGs are "in scope" — what shows up under
      // "Connected resources" in the portal. Must be full ARM RG IDs.
      managedResources: [for rg in targetResourceGroups: subscriptionResourceId('Microsoft.Resources/resourceGroups', rg)]
    }
    actionConfiguration: {
      accessLevel: accessLevel
      identity: effectiveIdentityId
      mode: actionMode
    }
    logConfiguration: {
      applicationInsightsConfiguration: {
        appId: effectiveAppInsightsAppId
        connectionString: effectiveAppInsightsConnStr
      }
    }
    upgradeChannel: upgradeChannel
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
    defaultModel: {
      provider: defaultModelProvider
      name: defaultModelName
    }
    experimentalSettings: {
      EnableWorkspaceTools: true
      EnableHttpTriggers: true
      EnableV2AgentLoop: true
    }
  }
  dependsOn: [ targetRbac, monitoringReader ]
}

// ── RBAC for system-assigned identity on target RGs ──
// The agent uses system MI for connector queries (App Insights, Log Analytics).
// Same roles as UAMI: Reader + Log Analytics Reader + Contributor (if High).

module targetRbacSystemMi 'role-assignments-target.bicep' = [for (rg, i) in targetResourceGroups: {
  name: 'rbac-smi-${i}-${uniqueString(deployment().name)}'
  scope: resourceGroup(subscriptionId, rg)
  params: {
    principalId: sreAgent.identity.principalId
    accessLevel: accessLevel
  }
}]

// ── SRE Agent Administrator for deployer ──

resource adminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sreAgent.id, deployer().objectId, 'e79298df-d852-4c6d-84f9-5d13249d1e55')
  scope: sreAgent
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'e79298df-d852-4c6d-84f9-5d13249d1e55')
    principalId: deployer().objectId
    principalType: 'User'
  }
}

// ── SRE Agent Administrator for UAMI (needed for Logic App webhook bridge to call HTTP triggers) ──

resource uamiAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sreAgent.id, effectiveIdentityId, 'e79298df-d852-4c6d-84f9-5d13249d1e55')
  scope: sreAgent
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'e79298df-d852-4c6d-84f9-5d13249d1e55')
    principalId: effectivePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ──

output agentId string = sreAgent.id
output agentDataPlaneUrl string = 'https://${agentName}.${location}.azuresre.ai'
output managedIdentityId string = effectiveIdentityId
output systemAssignedPrincipalId string = sreAgent.identity.principalId
output lawId string = law.id
