// Copied from microsoft/sre-agent labs/starter-lab/infra/main.bicep and
// updated for the FinOps Toolkit SRE Agent template:
// - no azd environment dependency
// - no Grubify sample application
// - resource-group scoped target access

targetScope = 'subscription'

@description('Resource group that holds the SRE Agent resources.')
param resourceGroupName string

@description('SRE Agent name.')
param agentName string

@description('Primary location for all resources.')
@allowed(['swedencentral', 'uksouth', 'eastus2', 'australiaeast'])
param location string = 'eastus2'

@description('Resource groups the agent can observe or act on.')
param targetResourceGroups array = []

@description('Agent access level.')
@allowed(['Low', 'High'])
param accessLevel string = 'Low'

@description('Agent action mode.')
@allowed(['review', 'autonomous', 'readOnly'])
param actionMode string = 'review'

@description('Agent upgrade channel.')
@allowed(['Stable', 'Preview'])
param upgradeChannel string = 'Preview'

@description('Default SRE Agent model provider. MicrosoftFoundry maps to the Azure OpenAI provider in the SRE Agent portal.')
@allowed(['MicrosoftFoundry', 'Anthropic'])
param defaultModelProvider string = 'MicrosoftFoundry'

@description('Default SRE Agent model name. Automatic lets SRE Agent route to the appropriate model within the selected provider.')
param defaultModelName string = 'Automatic'

@description('Monthly agent unit limit.')
@minValue(1)
param monthlyAgentUnitLimit int = 10000

@description('Agent experimental settings.')
param experimentalSettings object = {
  EnableSandboxGroup: true
  EnableWorkspaceTools: true
}

@description('Azure resource tags.')
param tags object = {}

@description('Optional. FinOps Hub Azure Data Explorer cluster resource ID for Kusto viewer assignment.')
param finopsHubKustoClusterResourceId string = ''

@description('Assign Reader on the deployment subscription to the agent managed identity.')
param enableSubscriptionReaderRole bool = true

var targetRgs = empty(targetResourceGroups) ? [resourceGroupName] : targetResourceGroups
var agentResourceGroupId = subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
var targetRgIds = [for rgName in targetRgs: subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)]
var namingSeed = toLower('${subscription().subscriptionId}|${agentResourceGroupId}|${agentName}')
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources-deployment'
  scope: rg
  params: {
    agentName: agentName
    location: location
    namingSeed: namingSeed
    targetResourceGroupIds: targetRgIds
    accessLevel: accessLevel
    actionMode: actionMode
    upgradeChannel: upgradeChannel
    defaultModelProvider: defaultModelProvider
    defaultModelName: defaultModelName
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
    experimentalSettings: experimentalSettings
    tags: tags
  }
}

module targetRbac 'modules/resource-group-rbac.bicep' = [for rgName in targetRgs: {
  name: 'target-rbac-${uniqueString(toLower(subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)), namingSeed)}'
  scope: resourceGroup(rgName)
  params: {
    principalId: resources.outputs.agentPrincipalId
    accessLevel: accessLevel
  }
}]

resource subscriptionReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableSubscriptionReaderRole) {
  name: guid(subscription().id, namingSeed, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: resources.outputs.agentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

var hasKustoCluster = !empty(finopsHubKustoClusterResourceId)
var kustoClusterSubscriptionId = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[2] : ''
var kustoClusterResourceGroupName = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[4] : ''
var kustoClusterName = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[8] : ''

module finopsHubKustoAllDatabasesViewerRbac 'modules/kusto-all-databases-viewer-rbac.bicep' = if (hasKustoCluster) {
  name: 'kusto-rbac-${uniqueString(finopsHubKustoClusterResourceId, namingSeed)}'
  scope: resourceGroup(kustoClusterSubscriptionId, kustoClusterResourceGroupName)
  params: {
    clusterName: kustoClusterName
    principalApplicationId: resources.outputs.agentPrincipalId
    principalTenantId: tenant().tenantId
    principalAssignmentName: 'sre-agent-${uniqueString(finopsHubKustoClusterResourceId, namingSeed, 'all-db-viewer')}'
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output SRE_AGENT_NAME string = resources.outputs.agentName
output SRE_AGENT_ENDPOINT string = resources.outputs.agentEndpoint
output AGENT_PORTAL_URL string = resources.outputs.agentPortalUrl
output SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID string = resources.outputs.agentPrincipalId
output SYSTEM_MANAGED_IDENTITY_TENANT_ID string = resources.outputs.agentTenantId
output LOG_ANALYTICS_WORKSPACE_ID string = resources.outputs.logAnalyticsWorkspaceId
