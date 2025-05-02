@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Name of the AI service')
param aiServiceName string

@description('List of deployments for Cognitive Services.')
param deployments array = []

@description('Name of the AI service private link endpoint for cognitive services')
param aiServicesPleName string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool = true

@description('Resource ID of the subnet')
param privateEndpointSubnetId string

@description('Resource ID of the virtual network')
param virtualNetworkId string

@description('Location of the virtual network')
param virtualNetworkLocation string = location

@allowed([
  'S0'
])
@description('AI service SKU')
param aiServiceSkuName string = 'S0'

var aiServiceNameCleaned = replace(aiServiceName, '-', '')

var cognitiveServicesPrivateDnsZoneName = 'privatelink.cognitiveservices.azure.com'
var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServiceNameCleaned
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.CognitiveServices/accounts'] ?? {})
  sku: {
    name: aiServiceSkuName
  }
  kind: 'AIServices'
  properties: {
    publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    disableLocalAuth: false
    networkAcls: {
      defaultAction: enablePublicAccess ? 'Allow' : 'Deny'
      virtualNetworkRules: enablePublicAccess ? [] : [
        {
          id: privateEndpointSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ]
    }
    customSubDomainName: aiServiceNameCleaned
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource raiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01' = {
  parent: aiServices
  name: '${aiServiceName}-policy'
  properties: {
    basePolicyName: 'Microsoft.Default'
    contentFilters:[
      {
          name: 'Hate'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Hate'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Sexual'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Sexual'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Violence'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Violence'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Selfharm'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Selfharm'
          severityThreshold: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
        name: 'jailbreak'
        blocking: true
        enabled: true
        source: 'Prompt'
      }
      {
          name: 'protected_material_text'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'protected_material_code'
          blocking: true
          enabled: true
          source: 'Completion'
      }
    ]
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: aiServices
  name: deployment.name
  properties: {
    model: deployment.?model ?? null
    raiPolicyName: deployment.?raiPolicyName ?? raiPolicy.name
  }
  sku: deployment.?sku ?? null
}]

resource aiServicesPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (!enablePublicAccess) {
  name: aiServicesPleName
  location: virtualNetworkLocation
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateEndpoints'] ?? {})
  properties: {
    privateLinkServiceConnections: [
      { 
        name: aiServicesPleName
        properties: {
          groupIds: [
            'account'
          ]
          privateLinkServiceId: aiServices.id
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

resource cognitiveServicesPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!enablePublicAccess) {
  name: cognitiveServicesPrivateDnsZoneName
  location: 'global'
}

resource openAiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!enablePublicAccess) {
  name: openAiPrivateDnsZoneName
  location: 'global'
  tags: union(tags, tagsByResource[?'Microsoft.KeyVault/privateDnsZones'] ?? {})
}

resource cognitiveServicesVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!enablePublicAccess) {
  parent: cognitiveServicesPrivateDnsZone
  name: uniqueString(virtualNetworkId)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource openAiVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!enablePublicAccess) {
  parent: openAiPrivateDnsZone
  name: uniqueString(virtualNetworkId)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource aiServicesPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!enablePublicAccess) {
  parent: aiServicesPrivateEndpoint
  name: 'default'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: replace(openAiPrivateDnsZoneName, '.', '-')
        properties:{
          privateDnsZoneId: openAiPrivateDnsZone.id
        }
      }
      {
        name: replace(cognitiveServicesPrivateDnsZoneName, '.', '-')
        properties:{
          privateDnsZoneId: cognitiveServicesPrivateDnsZone.id
        }
      }
    ]
  }
}

output aiServicesId string = aiServices.id
output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesName string = aiServices.name
output aiServicesPrincipalId string = aiServices.identity.principalId
