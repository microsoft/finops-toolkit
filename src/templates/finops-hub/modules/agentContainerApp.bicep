@description('Specifies the name of the container app.')
param containerAppName string

@description('Specifies the name of the container app environment.')
param containerAppEnvName string

@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool

@description('Required. Id of the subnet for container app environment.')
param containerSubnetId string

@description('Specifies the location for all resources.')
param location string

@description('Specifies the docker container image to deploy.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Specifies the container port.')
param targetPort int = 80

@description('Tags to add to the resources')
param tags object

@description('Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.')
param tagsByResource object = {}

@description('Number of CPU cores the container can use. Can be with a maximum of two decimals.')
@allowed([
  '0.25'
  '0.5'
  '0.75'
  '1'
  '1.25'
  '1.5'
  '1.75'
  '2'
])
param cpuCore string

@description('Amount of memory (in gibibytes, GiB) allocated to the container up to 4GiB. Can be with a maximum of two decimals. Ratio with CPU cores must be equal to 2.')
@allowed([
  '0.5'
  '1'
  '1.5'
  '2'
  '3'
  '3.5'
  '4'
])
param memorySize string

@description('Minimum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param minReplicas int

@description('Maximum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param maxReplicas int

param appId string = ''
@secure()
param appSecret string = ''


resource containerAppEnv 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: containerAppEnvName
  location: location
  tags: union(tags, tagsByResource[?'Microsoft.App/managedEnvironments'] ?? {})
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    vnetConfiguration: enablePublicAccess ? null : {
      infrastructureSubnetId: containerSubnetId
      internal: true
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  tags: union(tags, tagsByResource[?'Microsoft.App/containerApps'] ?? {})
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      revisionSuffix: 'firstrevision'
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: json(cpuCore)
            memory: '${memorySize}Gi'
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
output containerAppEnvStaticIP string = containerAppEnv.properties.staticIp
output containerAppEnvId string = containerAppEnv.id
output containerAppId string = containerApp.id
output containerAppEnvName string = containerAppEnv.name
output containerAppName string = containerApp.name
output containerAppEnvIdentityId string = containerAppEnv.identity.principalId
output containerAppIdentityId string = containerApp.identity.principalId
