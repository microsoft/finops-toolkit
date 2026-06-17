// One-click portal entry point for the FinOps Toolkit SRE Agent.
// The CLI path keeps using infra/main.bicep directly.

targetScope = 'subscription'

@description('Resource group that holds the SRE Agent resources.')
param resourceGroupName string

@description('SRE Agent name.')
param agentName string

@description('Primary location for all resources.')
@allowed(['australiaeast', 'canadacentral', 'eastus2', 'francecentral', 'koreacentral', 'swedencentral', 'uksouth'])
param location string = 'eastus2'

@description('Resource groups the agent can observe or act on. The agent resource group is always included.')
param targetResourceGroups array = []

@description('Comma-separated resource groups the agent can observe or act on. Used by the Azure portal form.')
param targetResourceGroupNames string = ''

@description('Optional database-qualified FinOps Hub Kusto connector URI. Example: https://<cluster>.<region>.kusto.windows.net/Hub')
param finopsHubKustoConnectorUri string = ''

@description('Optional. FinOps Hub Azure Data Explorer cluster resource ID for Kusto viewer assignment.')
param finopsHubKustoClusterResourceId string = ''

@description('Agent access level. Low (read-only) is recommended for reporting and analysis without modification risk.')
@allowed(['Low', 'High'])
param accessLevel string = 'Low'

@description('Agent action mode.')
@allowed(['review', 'autonomous', 'readOnly'])
param actionMode string = 'autonomous'

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

@description('Assign Reader on the deployment subscription to the agent managed identity. Optional — required only for subscription-wide ARM-backed reports; otherwise scope reads via target resource groups.')
param enableSubscriptionReaderRole bool = false

@description('Public URI for the generated SRE Agent recipe package. Deploy-to-Azure links derive this from the template URI.')
param recipePackageUri string = uri(any(deployment()).properties.templateLink.uri, 'sre-agent-recipe.zip')

@description('SHA256 hash of the recipe package for integrity verification.')
param recipePackageSha256 string = 'PLACEHOLDER_RECIPE_PACKAGE_SHA256'

@description('Forces the recipe deployment script to run when the template is redeployed.')
param forceUpdateTag string = utcNow()

@description('Azure resource tags.')
param tags object = {
  'finops-toolkit': 'sre-agent'
  source: 'microsoft-finops-toolkit'
}

@description('Principal type of the deployer.')
@allowed(['User', 'ServicePrincipal'])
param deployerPrincipalType string = 'User'

var rawTargetResourceGroups = split(replace(targetResourceGroupNames, ' ', ''), ',')
var parsedTargetResourceGroups = filter(rawTargetResourceGroups, rgName => !empty(rgName))
var targetRgs = union([resourceGroupName], targetResourceGroups, parsedTargetResourceGroups)
var agentResourceGroupId = subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
var targetRgIds = [for rgName in targetRgs: subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)]
var namingSeed = toLower('${subscription().subscriptionId}|${agentResourceGroupId}|${agentName}')
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var hasKustoCluster = !empty(finopsHubKustoClusterResourceId)
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
    deployerPrincipalType: deployerPrincipalType
    tags: tags
  }
}

module targetRbac 'infra/modules/resource-group-rbac.bicep' = [for rgName in targetRgs: {
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

module finopsHubKustoAllDatabasesViewerRbac 'infra/modules/kusto-all-databases-viewer-rbac.bicep' = if (hasKustoCluster) {
  name: 'kusto-rbac-${uniqueString(finopsHubKustoClusterResourceId, namingSeed)}'
  scope: resourceGroup(kustoClusterSubscriptionId, kustoClusterResourceGroupName)
  params: {
    clusterName: kustoClusterName
    principalApplicationId: resources.outputs.agentPrincipalId
    principalTenantId: tenant().tenantId
    principalAssignmentName: 'sre-agent-${uniqueString(finopsHubKustoClusterResourceId, namingSeed, 'all-db-viewer')}'
  }
}

module applyExtras 'infra/modules/apply-extras.bicep' = {
  name: 'apply-extras'
  scope: rg
  params: {
    location: location
    agentName: agentName
    agentEndpoint: resources.outputs.agentEndpoint
    subscriptionId: subscription().subscriptionId
    recipePackageUri: recipePackageUri
    recipePackageSha256: recipePackageSha256
    kustoConnectorUri: finopsHubKustoConnectorUri
    forceUpdateTag: forceUpdateTag
    tags: tags
  }
  dependsOn: [
    targetRbac
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
output APPLY_EXTRAS_SCRIPT string = applyExtras.outputs.scriptName
