param clusterName string
@allowed(['Hub', 'Ingestion'])
param databaseName string
param principalApplicationId string
param principalTenantId string

resource cluster 'Microsoft.Kusto/clusters@2024-04-13' existing = {
  name: clusterName
}

resource database 'Microsoft.Kusto/clusters/databases@2024-04-13' existing = {
  parent: cluster
  name: databaseName
}

resource viewer 'Microsoft.Kusto/clusters/databases/principalAssignments@2024-04-13' = {
  parent: database
  name: 'sre-agent-${uniqueString(database.id, principalApplicationId)}'
  properties: {
    principalId: principalApplicationId
    principalType: 'App'
    role: 'Viewer'
    tenantId: principalTenantId
  }
}
