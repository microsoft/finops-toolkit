//==============================================================================
// Parameters
//==============================================================================

@description('Required. Name of the hub. Used to ensure unique resource names.')
param hubName string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Resource tags.')
param tags object = {}

// @description('Required. The name of the Azure Key Vault instance.')
// param keyVaultName string

@description('Optional. Forces the table to be updated if different from the last time it was deployed.')
param forceUpdateTag string = utcNow()

@description('Optional. If true, ingestion will continue even if some rows fail to ingest.')
param continueOnErrors bool = false

//------------------------------------------------------------------------------
// Variables
//------------------------------------------------------------------------------

// Generate globally unique cluster name: 4-22 chars; lowercase letters and numbers
var safeHubName = replace(replace(toLower(hubName), '-', ''), '_', '')
var clusterName = replace('${take(safeHubName, 22)}', '--', '-')

//==============================================================================
// Resources
//==============================================================================

resource adxCluster 'Microsoft.Kusto/clusters@2023-05-02' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    capacity: 2
    name: 'Standard_E2ads_v5'
    tier: 'Standard'
  }
  // identity: {
  //   type: 'string'
  //   userAssignedIdentities: {}
  // }
  // properties: {
  //   acceptedAudiences: [
  //     {
  //       value: 'string'
  //     }
  //   ]
  //   allowedFqdnList: [
  //     'string'
  //   ]
  //   allowedIpRangeList: [
  //     'string'
  //   ]
  //   enableAutoStop: bool
  //   enableDiskEncryption: bool
  //   enableDoubleEncryption: bool
  //   enablePurge: bool
  //   enableStreamingIngest: bool
  //   engineType: 'string'
  //   keyVaultProperties: {
  //     keyName: 'string'
  //     keyVaultUri: 'string'
  //     keyVersion: 'string'
  //     userIdentity: 'string'
  //   }
  //   languageExtensions: {
  //     value: [
  //       {
  //         languageExtensionImageName: 'string'
  //         languageExtensionName: 'string'
  //       }
  //     ]
  //     value: [
  //       {
  //         languageExtensionImageName: 'string'
  //         languageExtensionName: 'string'
  //       }
  //     ]
  //   }
  //   optimizedAutoscale: {
  //     isEnabled: bool
  //     maximum: int
  //     minimum: int
  //     version: int
  //   }
  //   publicIPType: 'string'
  //   publicNetworkAccess: 'string'
  //   restrictOutboundNetworkAccess: 'string'
  //   trustedExternalTenants: [
  //     {
  //       value: 'string'
  //     }
  //   ]
  //   virtualClusterGraduationProperties: 'string'
  //   virtualNetworkConfiguration: {
  //     dataManagementPublicIpId: 'string'
  //     enginePublicIpId: 'string'
  //     subnetId: 'string'
  //   }
  // }
  // zones: [
  //   'string'
  // ]
}

resource adxDatabase 'Microsoft.Kusto/clusters/databases@2023-05-02' = {
  name: 'hub'
  location: location
  kind: 'ReadWrite'
  parent: adxCluster
}

resource adxDbTable 'Microsoft.Kusto/clusters/databases/scripts@2023-05-02' = {
  name: 'ingestion'
  parent: adxDatabase
  properties: {
      scriptContent: loadTextContent('adxTableSchema.kql')
      continueOnErrors: continueOnErrors
      forceUpdateTag: forceUpdateTag
  }
}

//==============================================================================
// Outputs
//==============================================================================

@description('The resource ID of the cluster.')
output clusterId string = adxCluster.id

@description('The name of the cluster.')
output clusterName string = adxCluster.name

@description('The URI of the cluster.')
output clusterUri string = adxCluster.properties.uri

@description('The resource ID of the database.')
output databaseId string = adxDatabase.id

@description('The name of the database.')
output databaseName string = adxDatabase.name
