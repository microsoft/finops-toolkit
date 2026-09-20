metadata name = 'FinOps toolkit Grafana dashboards'
metadata description = 'Deploys the FinOps hub Grafana dashboards and points them at the hub Data Explorer cluster.'

//==============================================================================
// Parameters
//==============================================================================

@description('Required. URI of the Data Explorer cluster or Fabric eventhouse that hosts the hub database.')
param clusterUri string

@description('Optional. Name of the hub database. Default: "Hub".')
param hubDatabaseName string = 'Hub'

@description('Optional. Azure location to deploy the dashboards to. Default: resource group location.')
param location string = resourceGroup().location

@description('Optional. Tags to apply to the dashboards.')
param tags object = {}

@description('Optional. Resource ID of the Application Insights resource that holds AI agent telemetry. The Codex, Agent framework, and GitHub Copilot dashboards read from it. Default: "" (pick the resource in the dashboard).')
param appInsightsResourceId string = ''

//==============================================================================
// Variables
//==============================================================================

// The dashboards ship with the cluster and database variables empty so they can
// be imported by hand. The deployment replaces those two template variables so
// the dashboards resolve against the hub that was just deployed. The variables
// are rewritten on the loaded object rather than on the serialized text, because
// Azure Resource Manager limits a string expression to 131,072 characters and
// the largest dashboards exceed that.
var clusterVariable = {
  current: {
    text: clusterUri
    value: clusterUri
  }
  type: 'textbox'
  hide: 0
  query: clusterUri
  name: 'cluster'
  label: 'Cluster URI'
  options: []
}

var databaseVariable = {
  current: {
    value: hubDatabaseName
    text: hubDatabaseName
  }
  type: 'textbox'
  hide: 0
  query: hubDatabaseName
  name: 'database'
  label: 'Database'
}

// The Application Insights resource ID is split so the AI dashboards open on
// the resource that holds the agent telemetry. The dashboards keep their own
// queries for these variables, so a reader can still switch resources.
var appInsightsParts = split(appInsightsResourceId, '/')
var hasAppInsights = length(appInsightsParts) == 9
var appInsightsVariables = hasAppInsights
  ? {
      sub: appInsightsParts[2]
      rg: appInsightsParts[4]
      res: appInsightsParts[8]
    }
  : {}

// Identifies every dashboard as a FinOps toolkit resource. The deployment sets
// the same tag on all 12 dashboards.
var dashboardGalleryTag = {
  GrafanaDashboardResourceType: 'FinOps-toolkit'
}

// Every FinOps toolkit dashboard. The hub dashboards and the AI Foundry
// dashboard need the hub cluster. The Codex, Agent framework, and GitHub
// Copilot dashboards read per call telemetry from Application Insights.
var dashboards = [
  {
    name: 'ftk-ai-foundry'
    content: loadJsonContent('dashboards/ftk-ai-foundry.json')
  }
  {
    name: 'ftk-codex'
    content: loadJsonContent('dashboards/ftk-codex.json')
  }
  {
    name: 'ftk-agent-framework'
    content: loadJsonContent('dashboards/ftk-agent-framework.json')
  }
  {
    name: 'ftk-github-copilot'
    content: loadJsonContent('dashboards/ftk-github-copilot.json')
  }
  {
    name: 'ftk-hub-summary'
    content: loadJsonContent('dashboards/ftk-hub-summary.json')
  }
  {
    name: 'ftk-hub-overview'
    content: loadJsonContent('dashboards/ftk-hub-overview.json')
  }
  {
    name: 'ftk-hub-rate-optimization'
    content: loadJsonContent('dashboards/ftk-hub-rate-optimization.json')
  }
  {
    name: 'ftk-hub-anomaly-management'
    content: loadJsonContent('dashboards/ftk-hub-anomaly-management.json')
  }
  {
    name: 'ftk-hub-budgeting'
    content: loadJsonContent('dashboards/ftk-hub-budgeting.json')
  }
  {
    name: 'ftk-hub-data-ingestion'
    content: loadJsonContent('dashboards/ftk-hub-data-ingestion.json')
  }
  {
    name: 'ftk-hub-invoicing-chargeback'
    content: loadJsonContent('dashboards/ftk-hub-invoicing-chargeback.json')
  }
  {
    name: 'ftk-hub-licensing-saas'
    content: loadJsonContent('dashboards/ftk-hub-licensing-saas.json')
  }
]

//==============================================================================
// Resources
//==============================================================================

resource dashboard 'Microsoft.Dashboard/dashboards@2026-09-01' = [
  for item in dashboards: {
    name: item.name
    location: location
    tags: union(tags, dashboardGalleryTag)
  }
]

resource dashboardDefinition 'Microsoft.Dashboard/dashboards/dashboardDefinitions@2026-09-01' = [
  for (item, index) in dashboards: {
    name: '${item.name}/default'
    properties: {
      serializedData: string(union(item.content, {
        templating: union(item.content.templating, {
          list: map(
            item.content.templating.list,
            variable => variable.name == 'cluster'
              ? clusterVariable
              : variable.name == 'database'
                  ? databaseVariable
                  : contains(appInsightsVariables, variable.name)
                      ? union(variable, {
                          current: {
                            text: appInsightsVariables[variable.name]
                            value: appInsightsVariables[variable.name]
                          }
                        })
                      : variable
          )
        })
      }))
    }
    dependsOn: [
      dashboard[index]
    ]
  }
]

//==============================================================================
// Outputs
//==============================================================================

@description('Names of the dashboards that were deployed.')
output dashboardNames array = [for (item, index) in dashboards: dashboard[index].name]
