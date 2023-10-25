//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Resource tags.')
param tags object = {}

@description('Required. The name of the Azure Key Vault instance.')
param keyVaultName string

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

// Generate globally unique cluster name: 4-22 chars; lowercase letters and numbers
var safeHubName = replace(replace(toLower(hubName), '-', ''), '_', '')
var clusterName = replace('${take(safeHubName, 22)}', '--', '-')

//==============================================================================
// Resources
//==============================================================================

resource cluster 'Microsoft.Kusto/clusters@2022-12-29' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    capacity: 1
    name: 'string'
    tier: 'string'
  }
  identity: {
    type: 'string'
    userAssignedIdentities: {}
  }
  properties: {
    acceptedAudiences: [
      {
        value: 'string'
      }
    ]
    allowedFqdnList: [
      'string'
    ]
    allowedIpRangeList: [
      'string'
    ]
    enableAutoStop: true
    enableDiskEncryption: false
    enableDoubleEncryption: false
    enablePurge: false
    enableStreamingIngest: false
    engineType: 'V3'
    keyVaultProperties: {
      keyName: keyVaultName
      keyVaultUri: 'string'
      keyVersion: 'string'
      userIdentity: 'string'
    }
    languageExtensions: {
      value: [
        {
          languageExtensionImageName: 'string'
          languageExtensionName: 'string'
        }
      ]
      value: [
        {
          languageExtensionImageName: 'string'
          languageExtensionName: 'string'
        }
      ]
    }
    optimizedAutoscale: {
      isEnabled: bool
      maximum: int
      minimum: int
      version: int
    }
    publicIPType: 'string'
    publicNetworkAccess: 'string'
    restrictOutboundNetworkAccess: 'string'
    trustedExternalTenants: [
      {
        value: 'string'
      }
    ]
    virtualClusterGraduationProperties: 'string'
    virtualNetworkConfiguration: {
      dataManagementPublicIpId: 'string'
      enginePublicIpId: 'string'
      subnetId: 'string'
    }
  }
  zones: [
    'string'
  ]
}

resource database 'Microsoft.Kusto/clusters/databases@2022-12-29' = {
  name: 'Hub'
  location: location
  parent: cluster
  kind: 'ReadWrite'
  properties: {
    hotCachePeriod: '30.00:00:00' // 30 days
    softDeletePeriod: '30.00:00:00' // 30 days
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The resource ID of the cluster.')
output clusterId string = cluster.id

@description('The name of the cluster.')
output clusterName string = cluster.name

@description('The URI of the cluster.')
output clusterUri string = cluster.properties.uri

@description('The resource ID of the database.')
output databaseId string = database.id

@description('The name of the database.')
output databaseName string = database.name
