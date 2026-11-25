// Shared infrastructure entry point for the portal and CLI.

targetScope = 'subscription'

@description('Resource group that holds the SRE Agent resources.')
param resourceGroupName string

@description('Agent base name. The selected mode is appended to the resource name.')
@minLength(3)
@maxLength(56)
param agentName string

@description('Primary location for all resources.')
@allowed(['australiaeast', 'canadacentral', 'eastus2', 'francecentral', 'koreacentral', 'swedencentral', 'uksouth'])
param location string = 'eastus2'

@description('Resource groups the agent can observe or act on. The agent resource group is always included.')
param targetResourceGroups array = []

@description('Comma-separated resource groups the agent can observe or act on. Used by the Azure portal form.')
param targetResourceGroupNames string = ''

@discriminator('mode')
type CostSource = {
  mode: 'native'
} | {
  mode: 'hubs'
  @minLength(1)
  clusterUri: string
  @minLength(1)
  clusterResourceId: string
}

@description('Cost data source. FinOps hubs mode requires an existing ADX cluster and the Hub database URI.')
param costSource CostSource

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

@description('Assign Reader on the deployment subscription to the agent managed identity.')
param enableSubscriptionReaderRole bool = false

@description('Grant Cost Management Reader on the deployment subscription.')
param enableSubscriptionCostReaderRole bool = false

@description('URI for the generated SRE Agent recipe package. Deploy-to-Azure links derive this from the template URI when no URI is supplied.')
@secure()
param recipePackageUri string = ''

@description('Apply the packaged profile in Azure. The CLI applies the same package locally.')
param applyPackagedExtras bool = true

@description('Forces the recipe deployment script to run when the template is redeployed.')
param forceUpdateTag string = utcNow()

@description('Azure resource tags.')
param tags object = {
  'finops-toolkit': 'sre-agent'
  source: 'microsoft-finops-toolkit'
}

var rawTargetResourceGroups = split(replace(targetResourceGroupNames, ' ', ''), ',')
var parsedTargetResourceGroups = filter(rawTargetResourceGroups, rgName => !empty(rgName))
var targetRgs = union([resourceGroupName], targetResourceGroups, parsedTargetResourceGroups)
var agentResourceGroupId = subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
var targetRgIds = [for rgName in targetRgs: subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)]
var deployedAgentName = '${agentName}-${costSource.mode}'
var namingSeed = toLower('${subscription().subscriptionId}|${agentResourceGroupId}|${deployedAgentName}')
var hasKustoCluster = costSource.mode == 'hubs'
var finopsHubKustoClusterResourceId = costSource.?clusterResourceId ?? ''
var kustoClusterSubscriptionId = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[2] : ''
var kustoClusterResourceGroupName = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[4] : ''
var kustoClusterName = hasKustoCluster ? split(finopsHubKustoClusterResourceId, '/')[8] : ''

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'infra/resources.bicep' = {
  name: 'resources-deployment'
  scope: rg
  params: {
    agentName: deployedAgentName
    location: location
    namingSeed: namingSeed
    targetResourceGroupIds: targetRgIds
    accessLevel: 'Low'
    actionMode: 'review'
    upgradeChannel: upgradeChannel
    defaultModelProvider: defaultModelProvider
    defaultModelName: defaultModelName
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
    experimentalSettings: experimentalSettings
    tags: union(tags, { 'cost-source': costSource.mode })
  }
}

module targetRbac 'infra/modules/resource-group-rbac.bicep' = [for rgName in targetRgs: {
  name: 'target-rbac-${uniqueString(toLower(subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)), namingSeed)}'
  scope: resourceGroup(rgName)
  params: {
    principalId: resources.outputs.agentPrincipalId
    accessLevel: 'Low'
  }
}]

module subscriptionReaders 'infra/modules/subscription-reader-rbac.bicep' = if (enableSubscriptionReaderRole || enableSubscriptionCostReaderRole) {
  name: 'subscription-readers-${uniqueString(namingSeed)}'
  params: {
    principalId: resources.outputs.agentPrincipalId
    enableReader: enableSubscriptionReaderRole
    enableCostManagementReader: enableSubscriptionCostReaderRole
  }
}

module finopsHubKustoViewerRbac 'infra/modules/kusto-database-viewer-rbac.bicep' = if (hasKustoCluster) {
  name: 'kusto-rbac-${uniqueString(finopsHubKustoClusterResourceId, namingSeed)}'
  scope: resourceGroup(kustoClusterSubscriptionId, kustoClusterResourceGroupName)
  params: {
    clusterName: kustoClusterName
    databaseName: 'Hub'
    principalApplicationId: resources.outputs.agentPrincipalId
    principalTenantId: tenant().tenantId
  }
}

// Hub stored functions read the Ingestion database across database scope.
module finopsHubIngestionViewerRbac 'infra/modules/kusto-database-viewer-rbac.bicep' = if (hasKustoCluster) {
  name: 'kusto-ingestion-rbac-${uniqueString(finopsHubKustoClusterResourceId, namingSeed)}'
  scope: resourceGroup(kustoClusterSubscriptionId, kustoClusterResourceGroupName)
  params: {
    clusterName: kustoClusterName
    databaseName: 'Ingestion'
    principalApplicationId: resources.outputs.agentPrincipalId
    principalTenantId: tenant().tenantId
  }
}

module applyExtras 'infra/modules/apply-extras.bicep' = if (applyPackagedExtras) {
  name: 'apply-extras'
  scope: rg
  params: {
    location: location
    agentName: deployedAgentName
    agentEndpoint: resources.outputs.agentEndpoint
    subscriptionId: subscription().subscriptionId
    recipePackageUri: empty(recipePackageUri) ? uri(any(deployment()).properties.templateLink.uri, 'sre-agent-recipe.zip') : recipePackageUri
    costSourceMode: costSource.mode
    kustoConnectorUri: costSource.?clusterUri ?? ''
    forceUpdateTag: forceUpdateTag
    tags: tags
  }
  dependsOn: [
    targetRbac
    subscriptionReaders
    finopsHubKustoViewerRbac
    finopsHubIngestionViewerRbac
  ]
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output SRE_AGENT_NAME string = resources.outputs.agentName
output SRE_AGENT_ENDPOINT string = resources.outputs.agentEndpoint
output AGENT_PORTAL_URL string = resources.outputs.agentPortalUrl
output SYSTEM_MANAGED_IDENTITY_PRINCIPAL_ID string = resources.outputs.agentPrincipalId
output SYSTEM_MANAGED_IDENTITY_TENANT_ID string = resources.outputs.agentTenantId
output LOG_ANALYTICS_WORKSPACE_ID string = resources.outputs.logAnalyticsWorkspaceId
output APPLY_EXTRAS_SCRIPT string = applyPackagedExtras ? applyExtras!.outputs.scriptName : ''
