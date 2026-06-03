@description('Principal ID of the managed identity to assign roles to.')
param principalId string

@description('Agent access level.')
@allowed(['Low', 'High'])
param accessLevel string

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var monitoringReaderRoleId = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
var logAnalyticsReaderRoleId = '73c42c96-874c-492b-b04d-ab87d138a893'
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var roleIds = accessLevel == 'High'
  ? [
      readerRoleId
      monitoringReaderRoleId
      logAnalyticsReaderRoleId
      contributorRoleId
    ]
  : [
      readerRoleId
      monitoringReaderRoleId
      logAnalyticsReaderRoleId
    ]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleId in roleIds: {
  name: guid(resourceGroup().id, principalId, roleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
