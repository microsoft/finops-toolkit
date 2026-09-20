metadata name = 'FinOps hub workbook'
metadata description = 'Deploys the FinOps hub workbook and points it at the hub Data Explorer cluster.'

//==============================================================================
// Parameters
//==============================================================================

@sys.description('Required. URI of the Data Explorer cluster or Fabric eventhouse that hosts the hub database.')
param clusterUri string

@sys.description('Optional. Name of the hub database. Default: "Hub".')
param hubDatabaseName string = 'Hub'

@sys.description('Optional. Resource ID of the Application Insights resource that holds AI agent telemetry. The Foundry agents tab reads from it. Default: "" (pick the resource in the workbook).')
param appInsightsResourceId string = ''

@sys.description('Optional. Display name for the workbook used in the gallery. Must be unique in the resource group.')
param displayName string = 'FinOps hub'

@sys.description('Optional. Workbook description.')
param workbookDescription string = 'Reports to help you analyze cost, usage, and AI workloads in a FinOps hub.'

@sys.description('Optional. Azure location to deploy the workbook to. Default: resource group location.')
param location string = resourceGroup().location

@sys.description('Optional. Tags to apply to the workbook.')
param tags object = {}

//==============================================================================
// Variables
//==============================================================================

// The workbook ships with its cluster parameters resolved by Azure Resource Graph
// so it still works when imported by hand. The deployment replaces them with the
// hub that was just deployed so no one has to pick a cluster before reading a
// report. The parameters are rewritten on the loaded object rather than on the
// serialized text, because Azure Resource Manager limits a string expression to
// 131,072 characters and the workbook is larger than that.
var workbookContent = loadJsonContent('../workbooks/hub/workbook.json')

// Data Explorer queries address the cluster by name and region, for example
// "contoso.westus", so the scheme and the well known suffix are removed. A
// Fabric eventhouse URI keeps its host, which the query editor also accepts.
var clusterHost = replace(replace(clusterUri, 'https://', ''), 'http://', '')
var clusterName = replace(clusterHost, '.kusto.windows.net', '')

// The Foundry agents tab reads agent telemetry through the Azure Monitor Logs
// data source, which accepts an Application Insights component as well as a Log
// Analytics workspace, so the deployed resource is preselected when supplied.
var hasAppInsights = !empty(appInsightsResourceId)

var telemetryTypeFilter = {
  'microsoft.operationalinsights/workspaces': true
  'microsoft.insights/components': true
}

var parametersItem = workbookContent.items[0]

var resolvedParameters = map(parametersItem.content.parameters, parameter =>
  parameter.name == 'HubQueryUri'
    ? {
        id: parameter.id
        version: parameter.version
        name: parameter.name
        label: parameter.label
        type: 1
        isRequired: true
        isHiddenWhenLocked: true
        value: clusterUri
      }
    : parameter.name == 'HubClusterName'
        ? {
            id: parameter.id
            version: parameter.version
            name: parameter.name
            label: parameter.label
            type: 1
            isRequired: true
            isHiddenWhenLocked: true
            value: clusterName
          }
        : parameter.name == 'HubDatabase'
            ? union(parameter, { value: hubDatabaseName, isHiddenWhenLocked: true })
            : parameter.name == 'TelemetryResources' && hasAppInsights
                ? union(parameter, {
                    value: [appInsightsResourceId]
                    typeSettings: union(parameter.typeSettings, { resourceTypeFilter: telemetryTypeFilter })
                  })
                : parameter
)

var resolvedContent = union(workbookContent, {
  items: union(
    [
      union(parametersItem, {
        content: union(parametersItem.content, { parameters: resolvedParameters })
      })
    ],
    skip(workbookContent.items, 1)
  )
})

//==============================================================================
// Resources
//==============================================================================

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, 'Microsoft.Insights/workbooks', displayName)
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    category: 'workbook'
    description: workbookDescription
    displayName: displayName
    serializedData: string(resolvedContent)
    sourceId: 'Azure Monitor'
    version: ''
  }
}

//==============================================================================
// Outputs
//==============================================================================

@sys.description('The resource ID of the workbook.')
output workbookId string = workbook.id

@sys.description('Link to the workbook in the Azure portal.')
output workbookUrl string = '${environment().portal}/#view/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Monitor/ConfigurationId/${uriComponent(workbook.id)}/Type/${workbook.properties.category}/WorkbookTemplateName/${uriComponent(workbook.properties.displayName)}'
