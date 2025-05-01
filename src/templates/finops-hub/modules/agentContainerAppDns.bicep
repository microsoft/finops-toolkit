param containerAppDnsZoneName string

param containerAppFQDN string

param containerAppEnvStaticIP string

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Required. Id of the virtual network for container app environment.')
param virtualNetworkId string

var containerAppName = replace(containerAppFQDN, '.${containerAppDnsZoneName}', '')

resource containerAppDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' =  {
  name: containerAppDnsZoneName
  location: 'global'
  tags: union(tags, tagsByResource[?'Microsoft.KeyVault/privateDnsZones'] ?? {})
  properties: {}
}

resource containerAppDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' =  {
  name: '${replace(containerAppDnsZone.name, '.', '-')}-link'
  location: 'global'
  parent: containerAppDnsZone
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateDnsZones/virtualNetworkLinks'] ?? {})
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource a 'Microsoft.Network/privateDnsZones/A@2024-06-01' =  {
  parent: containerAppDnsZone
  name: containerAppName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: containerAppEnvStaticIP
      }
    ]
  }
}
