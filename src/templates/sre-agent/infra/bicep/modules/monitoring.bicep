// =============================================================================
// SRE Agent monitoring module
// =============================================================================
// Creates the Log Analytics workspace and workspace-based Application Insights
// component used to collect telemetry for the FinOps toolkit SRE Agent.
// =============================================================================

@description('Required. Resource location.')
param location string

@description('Required. Log Analytics workspace resource name.')
param logAnalyticsName string

@description('Required. Application Insights resource name.')
param appInsightsName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Resource ID of the Application Insights component.')
output appInsightsId string = applicationInsights.id

@description('Application ID of the Application Insights component.')
output appInsightsAppId string = applicationInsights.properties.AppId

@description('Connection string for the Application Insights component.')
@secure()
output appInsightsConnectionString string = applicationInsights.properties.ConnectionString
