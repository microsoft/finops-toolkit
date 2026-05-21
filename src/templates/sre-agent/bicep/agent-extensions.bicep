// modules/agent-extensions.bicep
//
// Two input layers:
//   (1) Toggle params (enable*) + their conditional inputs synthesize one
//       built-in entry each (e.g. builtInConnectors).
//   (2) Caller-supplied arrays (connectors, hooks, etc.) — advanced authoring.
// The two layers are concat-merged before the resource loop, so a customer
// can flip a toggle, fill in two strings, and skip array authoring entirely.
//
// Note: only sub-resource types currently registered with the regional SRE
// Agent ARM RP are deployed here. Script-only types (repos, repoInstructions,
// knowledge, plugin marketplaces/installations) live in apply-extras.sh.

param agentName string

// ── Caller arrays (advanced) ──
param subagents array = []
param tools array = []
param skills array = []
param scheduledTasks array = []
param incidentFilters array = []
param connectors array = []
param hooks array = []
param commonPrompts array = []
param pluginConfigs array = []

// ── Toggles (forwarded from main.bicep) ──
param enableAppInsightsConnector bool = false
param appInsightsResourceId string = ''
param appInsightsAppId string = ''
param enableLogAnalyticsConnector bool = false
param lawResourceId string = ''
param enableAzureMonitorConnector bool = false
param azureMonitorLookbackDays int = 7
param enableDailyHealthCheckTask bool = false
param enableDenyProdDeletesHook bool = false
param enableSafetyRulesPrompt bool = false

// ─────────── Synthesize built-in entries from toggles ───────────
// Connector shape (2025-05-01-preview, typed):
//   properties: { dataConnectorType, dataSource, extendedProperties, identity }
// identity: 'system' = system-assigned MI, '' = none, '<UAMI resourceId>' = user-assigned.

var builtInConnectors = concat(
  enableAppInsightsConnector ? [
    {
      name: 'app-insights'
      properties: {
        dataConnectorType: 'AppInsights'
        dataSource: appInsightsResourceId
        extendedProperties: {
          armResourceId: appInsightsResourceId
          resource: { name: empty(appInsightsResourceId) ? '' : last(split(appInsightsResourceId, '/')) }
          appId: appInsightsAppId
        }
        identity: 'system'
      }
    }
  ] : [],
  enableLogAnalyticsConnector ? [
    {
      name: 'log-analytics'
      properties: {
        dataConnectorType: 'LogAnalytics'
        dataSource: lawResourceId
        extendedProperties: {
          armResourceId: lawResourceId
          resource: { name: empty(lawResourceId) ? '' : last(split(lawResourceId, '/')) }
        }
        identity: 'system'
      }
    }
  ] : [],
  enableAzureMonitorConnector ? [
    {
      name: 'azure-monitor'
      properties: {
        dataConnectorType: 'AzureMonitor'
        dataSource: subscription().id
        extendedProperties: {
          armResourceId: subscription().id
          lookbackDays: azureMonitorLookbackDays
        }
        identity: 'system'
      }
    }
  ] : []
)

var builtInScheduledTasks = enableDailyHealthCheckTask ? [
  {
    metadata: { name: 'daily-health-check' }
    spec: {
      description: 'Daily 8am health summary (toggle-generated).'
      schedule: '0 8 * * *'
      prompt: 'Summarize the last 24h of incidents and SLO burn for all services this agent watches.'
      enabled: true
      mode: 'Review'
    }
  }
] : []

var builtInHooks = enableDenyProdDeletesHook ? [
  {
    metadata: { name: 'deny-prod-deletes' }
    spec: {
      eventType: 'PreToolUse'
      hookType: 'Prompt'
      matcher: { toolPattern: '^(delete_|remove_).*' }
      permissionDecision: 'deny'
      hookBody: {
        prompt: 'If the tool targets a production resource (name contains "prod" or "prd"), deny. Otherwise allow.'
      }
      enabled: true
    }
  }
] : []

var builtInCommonPrompts = enableSafetyRulesPrompt ? [
  {
    metadata: { name: 'safety-rules' }
    spec: {
      prompt: '## Safety rules\n\n- Never restart services without paging the on-call.\n- Always confirm subscription before destructive ops.\n- For any High accessLevel action, require human review even if actionMode=Automatic.'
    }
  }
] : []

// ─────────── Merge built-in + caller-supplied ───────────

var allConnectors      = concat(builtInConnectors,     connectors)
var allScheduledTasks  = concat(builtInScheduledTasks, scheduledTasks)
var allHooks           = concat(builtInHooks,          hooks)
var allCommonPrompts   = concat(builtInCommonPrompts,  commonPrompts)

// ─────────── Resource loops ───────────

resource parent 'Microsoft.App/agents@2025-05-01-preview' existing = {
  name: agentName
}

@batchSize(1)
resource subagentRes 'Microsoft.App/agents/subagents@2025-05-01-preview' = [for s in subagents: {
  parent: parent
  name: s.metadata.name
  properties: { value: base64(string(s.spec)) }
}]

@batchSize(1)
resource toolRes 'Microsoft.App/agents/tools@2025-05-01-preview' = [for t in tools: {
  parent: parent
  name: t.metadata.name
  properties: { value: base64(string(t.spec)) }
}]

@batchSize(1)
resource skillRes 'Microsoft.App/agents/skills@2025-05-01-preview' = [for s in skills: {
  parent: parent
  name: s.metadata.name
  properties: {
    value: base64(string({
      name: s.metadata.name
      description: s.metadata.description
      tools: s.metadata.spec.tools
      skillContent: s.skillContent
      additionalFiles: s.additionalFiles
    }))
  }
}]

// scheduledTasks — NOT deployed via Bicep.
// The Bicep resource loop triggers K8s extension provisioning which
// intermittently fails with "Failed to create or update extension in Kubernetes".
// The ARM PUT path in apply-extras.sh uses a simpler code path that works reliably.
// Same issue as incidentFilters (platform sequencing).

// incidentFilters — NOT deployed via Bicep.
// The filter requires incidentPlatform to be set first (ARM PATCH in apply-extras.sh),
// but Bicep can't guarantee sequencing. Stays in apply-extras.sh with retry logic.

// ─────────── NOT deployed via Bicep (RP does not expose as ARM child type) ───────────
// hooks, pluginConfigs, incidentFilters aren't deployed here.
// Surface them as outputs for apply-extras.sh.

// Connectors (working typed shape — see comment above builtInConnectors).
#disable-next-line BCP081
@batchSize(1)
resource connectorRes 'Microsoft.App/agents/connectors@2025-05-01-preview' = [for c in allConnectors: {
  parent: parent
  name: c.name
  properties: c.properties
}]

// commonPrompts — ARM PUT sub-resource (base64 envelope, same as skills)
// Shape: { name, type, tags, properties: { prompt } }
#disable-next-line BCP081
@batchSize(1)
resource commonPromptRes 'Microsoft.App/agents/commonPrompts@2025-05-01-preview' = [for p in allCommonPrompts: {
  parent: parent
  name: p.name
  properties: { value: base64(string(p.properties)) }
}]

output pendingHooks         array = allHooks
output pendingPluginConfigs array = pluginConfigs
