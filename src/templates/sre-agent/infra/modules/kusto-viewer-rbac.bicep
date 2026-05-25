@description('Kusto cluster name.')
param clusterName string

@description('Principal ID to assign to the Kusto cluster.')
param principalId string

@description('Principal tenant ID.')
param principalTenantId string

@description('Stable principal assignment name.')
param principalAssignmentName string

resource allDatabasesViewer 'Microsoft.Kusto/clusters/principalAssignments@2023-08-15' = {
  name: '${clusterName}/${principalAssignmentName}'
  properties: {
    principalId: principalId
    principalType: 'App'
    role: 'AllDatabasesViewer'
    tenantId: principalTenantId
  }
}
