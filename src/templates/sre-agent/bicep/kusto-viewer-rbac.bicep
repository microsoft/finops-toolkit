targetScope = 'resourceGroup'

@description('Required. Name of the target Azure Data Explorer cluster.')
param clusterName string

@description('Required. Service principal object ID to grant access.')
param principalId string

@description('Required. Tenant ID for the service principal.')
param principalTenantId string

@description('Required. Name of the principal assignment resource.')
param principalAssignmentName string

resource allDatabasesViewer 'Microsoft.Kusto/clusters/principalAssignments@2023-08-15' = {
  name: '${clusterName}/${principalAssignmentName}'
  properties: {
    principalType: 'App'
    principalId: principalId
    tenantId: principalTenantId
    role: 'AllDatabasesViewer'
  }
}
