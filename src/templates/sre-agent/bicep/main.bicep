// ═══════════════════════════════════════════════════════════════
// Azure SRE Agent — deployment template
//
// Pick a starting point:
//   - quickstart.parameters.json   — minimum: turn on AppInsights, deploys clean
//   - agent.parameters.json        — full feature menu (toggles + advanced arrays)
//   - parameters.reference.json    — kitchen-sink reference for the array shapes
//
// Two ways to opt in to features:
//   (1) TOGGLES — for the common 80% (e.g. enableAppInsightsConnector=true).
//                 Set the toggle, fill 1-2 conditional strings, done.
//   (2) ARRAYS  — for everything else / advanced overrides. Author entries
//                 directly per parameters.reference.json shapes.
//                 Toggle output and array entries are merged at deploy time.
//
// Usage:
//   az deployment sub create --location <region> \
//     --template-file main.bicep \
//     --parameters @<your-parameters-file>.json
//   ./apply-extras.sh <sub> <rg> <agent-name> extras.parameters.json
// ═══════════════════════════════════════════════════════════════

targetScope = 'subscription'

// ═════════════════════════ REQUIRED ═════════════════════════

@description('Required. Agent name (lowercase, no spaces).')
param agentName string

@description('Required. Resource group that holds the agent + its identity + LAW + App Insights. Separate from the RGs the agent monitors.')
param agentResourceGroupName string

@description('Required. Region. Only the regions in @allowed are currently supported by the SRE Agent RP.')
@allowed(['swedencentral', 'uksouth', 'eastus2', 'australiaeast'])
param location string = 'eastus2'

@description('Required. Resource groups the agent is granted access to (read or act, depending on accessLevel).')
param targetResourceGroups array = []

@description('Optional. Low = read-only investigation. High = can take actions on target RGs.')
@allowed(['High', 'Low'])
param accessLevel string = 'Low'

@description('Optional. Review = human approval before actions. Autonomous = agent acts independently.')
@allowed(['Review', 'Autonomous', 'ReadOnly'])
param actionMode string = 'Review'

@description('Optional. Upgrade channel for the agent runtime.')
@allowed(['Stable', 'Preview'])
param upgradeChannel string = 'Preview'

@description('Optional. Monthly agent unit consumption limit.')
param monthlyAgentUnitLimit int = 10000

@description('Optional. Default LLM provider (MicrosoftFoundry, Anthropic).')
param defaultModelProvider string = 'Anthropic'

@description('Optional. Default LLM model name.')
param defaultModelName string = 'Automatic'

@description('Optional. Azure resource tags applied to the agent.')
param tags object = {}

@description('Optional. Resource ID of an existing UAMI. If provided, skips creating a new one.')
param existingManagedIdentityId string = ''

@description('Optional. Resource ID of an existing Application Insights for agent telemetry. If provided, skips creating a new one.')
param existingAgentAppInsightsId string = ''

// ═════════ FEATURE TOGGLES — common starter features ═════════
// Flip a toggle to true, fill the conditional strings below it.
// Each toggle synthesizes a single connector / hook / prompt entry
// and merges it with the matching advanced array further down.

// ── Connector: Application Insights ──
@description('Optional. Enable an Application Insights connector. Requires appInsightsResourceId + appInsightsAppId.')
param enableAppInsightsConnector bool = false
@description('Conditional. Required when enableAppInsightsConnector=true. Full Azure resource ID of the App Insights component.')
param appInsightsResourceId string = ''
@description('Conditional. Required when enableAppInsightsConnector=true. App Insights Application ID (GUID from the Overview blade).')
param appInsightsAppId string = ''

// ── Connector: Log Analytics ──
@description('Optional. Enable a Log Analytics connector. Requires lawResourceId.')
param enableLogAnalyticsConnector bool = false
@description('Conditional. Required when enableLogAnalyticsConnector=true. Full Azure resource ID of the LAW workspace.')
param lawResourceId string = ''

// ── Connector: Azure Monitor (subscription-scoped alerts) ──
@description('Optional. Enable an Azure Monitor connector that reads alerts at the subscription level.')
param enableAzureMonitorConnector bool = false
@description('Optional. Lookback window in days for the Azure Monitor connector.')
param azureMonitorLookbackDays int = 7

// ── Scheduled task: daily health check ──
@description('Optional. Enable a daily 8am health summary scheduled task.')
param enableDailyHealthCheckTask bool = false

// ── Hook: deny destructive tools on prod resources ──
@description('Optional. Enable a PreToolUse hook that denies delete_*/remove_* tools when the target name contains "prod"/"prd".')
param enableDenyProdDeletesHook bool = false

// ── Common prompt: safety rules ──
@description('Optional. Enable a "safety-rules" common prompt (no restarts without paging on-call, confirm subscription before destructive ops).')
param enableSafetyRulesPrompt bool = false

// ── Logic App webhook bridge (for HTTP Triggers) ──
@description('Optional. Deploy a Logic App that acts as an auth bridge for external webhooks (Dynatrace, Grafana, etc.) that cannot natively acquire Azure AD tokens. Set to true when using httpTriggers with external webhook sources.')
param enableWebhookBridge bool = false
@description('Conditional. Required when enableWebhookBridge=true. The SRE Agent HTTP Trigger URL that the Logic App should forward requests to. Obtained from the httpTriggers creation step.')
param webhookBridgeTriggerUrl string = ''

// ═════════════ ADVANCED — author array entries ═════════════
// Use these for anything not exposed as a toggle above, or to override.
// Entries here are concatenated with toggle output. See parameters.reference.json.

@description('Optional. Subagent definitions (array). Shape: see parameters.reference.json.')
param subagents array = []

@description('Optional. Tool definitions (KustoTool / HttpClientTool / PythonFunctionTool / LinkTool).')
param tools array = []

@description('Optional. Skill definitions (Markdown playbooks bound to tools).')
param skills array = []

@description('Optional. Scheduled task definitions (cron-triggered runs).')
param scheduledTasks array = []

@description('Optional. Incident filter definitions (AzMonitor / PagerDuty / ServiceNow rules + handling subagent).')
param incidentFilters array = []

@description('Optional. Connector definitions for any kind not covered by toggles above (kusto, mcp, github, azuredevops, teams, outlook, servicenow, pagerduty, grafana) or to override a toggle-generated entry.')
param connectors array = []

@description('Optional. Enable Bicep-managed Kusto AllDatabasesViewer assignment for the agent system identity.')
param enableFinopsHubKustoViewerRole bool = false

@description('Optional. Resource ID of the FinOps Hub Azure Data Explorer cluster used by the Kusto connector.')
param finopsHubKustoClusterResourceId string = ''

@description('Optional. Hook definitions for any handler beyond the toggles above (additional PreToolUse/Start/Stop entries).')
param hooks array = []

@description('Optional. Common prompt definitions for any prompt beyond the toggles above.')
param commonPrompts array = []

@description('Optional. Plugin configuration definitions. Plugin installations themselves are wired via apply-extras.sh.')
param pluginConfigs array = []

// NOTE: repos, repoInstructions, knowledge, plugin marketplaces/installations,
// and connector auth (PATs, OAuth) are NOT part of this Bicep template — they
// are applied by `./apply-extras.sh` after deployment using extras.parameters.json.

// ═══════════════════════════════════════════════════════════════
// DEPLOYMENT — you don't need to edit below this line
// ═══════════════════════════════════════════════════════════════

var subscriptionId = subscription().subscriptionId
var suffix = uniqueString(subscriptionId, agentResourceGroupName, agentName)
var applyFinopsHubKustoViewerRole = enableFinopsHubKustoViewerRole && !empty(finopsHubKustoClusterResourceId)
var finopsHubKustoClusterSubscriptionId = empty(finopsHubKustoClusterResourceId) ? '' : split(finopsHubKustoClusterResourceId, '/')[2]
var finopsHubKustoClusterResourceGroupName = empty(finopsHubKustoClusterResourceId) ? '' : split(finopsHubKustoClusterResourceId, '/')[4]
var finopsHubKustoClusterName = empty(finopsHubKustoClusterResourceId) ? '' : split(finopsHubKustoClusterResourceId, '/')[8]

// Create the agent RG if it doesn't already exist (idempotent — ARM no-op if present).
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: agentResourceGroupName
  location: location
}

module core './agent-core.bicep' = {
  name: 'core-${uniqueString(deployment().name)}'
  scope: rg
  params: {
    agentName: agentName
    location: location
    suffix: suffix
    accessLevel: accessLevel
    actionMode: actionMode
    targetResourceGroups: targetResourceGroups
    subscriptionId: subscriptionId
    upgradeChannel: upgradeChannel
    monthlyAgentUnitLimit: monthlyAgentUnitLimit
    defaultModelProvider: defaultModelProvider
    defaultModelName: defaultModelName
    tags: tags
    existingManagedIdentityId: existingManagedIdentityId
    existingAgentAppInsightsId: existingAgentAppInsightsId
  }
}

module finopsHubKustoViewerRbac './kusto-viewer-rbac.bicep' = if (applyFinopsHubKustoViewerRole) {
  name: 'kusto-rbac-${uniqueString(deployment().name)}'
  scope: resourceGroup(finopsHubKustoClusterSubscriptionId, finopsHubKustoClusterResourceGroupName)
  params: {
    clusterName: finopsHubKustoClusterName
    principalId: core.outputs.systemAssignedPrincipalId
    principalTenantId: tenant().tenantId
    principalAssignmentName: 'sre-agent-${uniqueString(subscriptionId, agentResourceGroupName, agentName, 'all-db-viewer')}'
  }
}

module extensions './agent-extensions.bicep' = {
  name: 'ext-${uniqueString(deployment().name)}'
  scope: rg
  params: {
    agentName: agentName
    subagents: subagents
    tools: tools
    skills: skills
    scheduledTasks: scheduledTasks
    incidentFilters: incidentFilters
    connectors: connectors
    hooks: hooks
    commonPrompts: commonPrompts
    pluginConfigs: pluginConfigs
    enableAppInsightsConnector: enableAppInsightsConnector
    appInsightsResourceId: appInsightsResourceId
    appInsightsAppId: appInsightsAppId
    enableLogAnalyticsConnector: enableLogAnalyticsConnector
    lawResourceId: lawResourceId
    enableAzureMonitorConnector: enableAzureMonitorConnector
    azureMonitorLookbackDays: azureMonitorLookbackDays
    enableDailyHealthCheckTask: enableDailyHealthCheckTask
    enableDenyProdDeletesHook: enableDenyProdDeletesHook
    enableSafetyRulesPrompt: enableSafetyRulesPrompt
  }
  dependsOn: [ core ]
}

// Conditional: deploy a Logic App auth bridge for external webhooks.
// External platforms (Dynatrace, Grafana, etc.) send plain HTTP webhooks but
// the SRE Agent HTTP Trigger requires Azure AD auth. The Logic App uses
// Managed Identity to acquire the token transparently.
module webhookBridge './logic-app-bridge.bicep' = if (enableWebhookBridge && !empty(webhookBridgeTriggerUrl)) {
  name: 'bridge-${uniqueString(deployment().name)}'
  scope: rg
  params: {
    agentName: agentName
    location: location
    triggerUrl: webhookBridgeTriggerUrl
  }
  dependsOn: [ core ]
}

output agentId string = core.outputs.agentId
output agentDataPlaneUrl string = core.outputs.agentDataPlaneUrl
output managedIdentityId string = core.outputs.managedIdentityId
output lawId string = core.outputs.lawId

// Quick links to open the agent / its resource group in the portal.
output agentPortalUrl string = 'https://sre.azure.com/#/agent/${subscription().subscriptionId}/${agentResourceGroupName}/${agentName}'
output resourceGroupPortalUrl string = 'https://portal.azure.com/#@/resource/subscriptions/${subscription().subscriptionId}/resourceGroups/${agentResourceGroupName}/overview'

// hooks/commonPrompts/pluginConfigs aren't ARM-exposed at 2025-05-01-preview.
// Apply post-deploy with apply-extras.sh.
output pendingHooks         array = extensions.outputs.pendingHooks
output pendingPluginConfigs array = extensions.outputs.pendingPluginConfigs

// Webhook bridge URL — give this to your external platform (Dynatrace, Grafana, etc.)
output webhookBridgeUrl string = (enableWebhookBridge && !empty(webhookBridgeTriggerUrl)) ? webhookBridge.outputs.logicAppCallbackUrl : ''
