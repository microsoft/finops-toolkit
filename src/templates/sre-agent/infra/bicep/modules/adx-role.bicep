// =============================================================================
// ADX cluster AllDatabasesViewer principal assignment module
// =============================================================================
// Assigns AllDatabasesViewer on an existing Azure Data Explorer cluster to the
// SRE Agent managed identity. Deployed at resource-group scope; the caller
// targets the correct resource group via module scope.
// =============================================================================

@description('Required. Name of the target Azure Data Explorer cluster.')
param clusterName string

@description('Required. Object (principal) ID of the SRE Agent managed identity to grant access to.')
param principalId string

@description('Optional. Microsoft Entra tenant ID for the SRE Agent managed identity.')
param principalTenantId string = tenant().tenantId

var principalAssignmentName = guid(resourceId('Microsoft.Kusto/clusters', clusterName), principalId, principalTenantId, 'AllDatabasesViewer')

resource cluster 'Microsoft.Kusto/clusters@2024-04-13' existing = {
  name: clusterName
}

resource allDatabasesViewerAssignment 'Microsoft.Kusto/clusters/principalAssignments@2024-04-13' = {
  parent: cluster
  name: principalAssignmentName
  properties: {
    principalType: 'App'
    principalId: principalId
    tenantId: principalTenantId
    role: 'AllDatabasesViewer'
  }
}

@description('Resource ID of the target Azure Data Explorer cluster.')
output clusterId string = cluster.id

@description('Name of the cluster-level principal assignment.')
output principalAssignmentName string = allDatabasesViewerAssignment.name

@description('Resource ID of the cluster-level principal assignment.')
output principalAssignmentId string = allDatabasesViewerAssignment.id
