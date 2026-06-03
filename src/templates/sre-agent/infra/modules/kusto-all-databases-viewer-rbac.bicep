@description('Kusto cluster name.')
param clusterName string

@description('Microsoft Entra application/client ID to assign to the Kusto cluster.')
param principalApplicationId string

@description('Principal tenant ID.')
param principalTenantId string

@description('Stable principal assignment name.')
param principalAssignmentName string

resource cluster 'Microsoft.Kusto/clusters@2024-04-13' existing = {
  name: clusterName
}

resource allDatabasesViewer 'Microsoft.Kusto/clusters/principalAssignments@2024-04-13' = {
  parent: cluster
  name: principalAssignmentName
  properties: {
    principalId: principalApplicationId
    principalType: 'App'
    role: 'AllDatabasesViewer'
    tenantId: principalTenantId
  }
}
