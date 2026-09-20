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

// Dashboards that only need the hub cluster. The Codex, Agent framework, and
// GitHub Copilot dashboards are not included because they also require an
// Application Insights resource that the hub does not create. The AI Foundry
// dashboard is included: it reads token usage from Azure Monitor metrics and
// token cost from the hub, so the hub cluster is all it needs.
var dashboards = [
  {
    name: 'ftk-ai-foundry'
    content: loadJsonContent('../../../workbooks/ftk-ai-foundry.json')
  }
  {
    name: 'ftk-hub-summary'
    content: loadJsonContent('../../../workbooks/ftk-hub-summary.json')
  }
  {
    name: 'ftk-hub-overview'
    content: loadJsonContent('../../../workbooks/ftk-hub-overview.json')
  }
  {
    name: 'ftk-hub-rate-optimization'
    content: loadJsonContent('../../../workbooks/ftk-hub-rate-optimization.json')
  }
  {
    name: 'ftk-hub-anomaly-management'
    content: loadJsonContent('../../../workbooks/ftk-hub-anomaly-management.json')
  }
  {
    name: 'ftk-hub-budgeting'
    content: loadJsonContent('../../../workbooks/ftk-hub-budgeting.json')
  }
  {
    name: 'ftk-hub-data-ingestion'
    content: loadJsonContent('../../../workbooks/ftk-hub-data-ingestion.json')
  }
  {
    name: 'ftk-hub-invoicing-chargeback'
    content: loadJsonContent('../../../workbooks/ftk-hub-invoicing-chargeback.json')
  }
  {
    name: 'ftk-hub-licensing-saas'
    content: loadJsonContent('../../../workbooks/ftk-hub-licensing-saas.json')
  }
]

//==============================================================================
// Resources
//==============================================================================

resource dashboard 'Microsoft.Dashboard/dashboards@2026-09-01' = [
  for item in dashboards: {
    name: item.name
    location: location
    tags: tags
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
              : (variable.name == 'database' ? databaseVariable : variable)
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
