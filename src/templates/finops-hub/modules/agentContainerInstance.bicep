@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool

@description('Resource ID of the subnet')
param containerSubnetId string

@description('Location for all resources.')
param location string

@description('Container group name')
param containerGroupName string

@description('Container name')
param containerName string

@description('Container image to deploy. Should be of the form accountName/imagename:tag for images stored in Docker Hub or a fully qualified URI for a private registry like the Azure Container Registry.')
param image string = 'mcr.microsoft.com/azuredocs/aci-helloworld'

@description('The number of CPU cores to allocate to the container. Must be an integer.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

param ports array = [
  {
    port: 80
    protocol: 'TCP'
  }
]

param environmentVariables array = [
  {
    name: 'SEC_VAR'
    secureValue: 'value'
  }
  {
    name: 'DEF_VAR'
    value: 'value'
  }
]

var networkProfileName = 'aci-networkProfile'
var interfaceConfigName = 'eth0'
var interfaceIpConfig = 'ipconfigprofile1'

resource networkProfile 'Microsoft.Network/networkProfiles@2020-11-01' = if(!enablePublicAccess) {
  name: networkProfileName
  location: location
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        name: interfaceConfigName
        properties: {
          ipConfigurations: [
            {
              name: interfaceIpConfig
              properties: {
                subnet: {
                  id: containerSubnetId
                }
              }
            }
          ]
        }
      }
    ]
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2019-12-01' = {
  name: containerGroupName
  location: location
  properties: {
    containers: [
      {
        name: containerName
        properties: {
          image: image
          ports: ports
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          environmentVariables: environmentVariables
        }
      }
    ]
    osType: 'Linux'
    networkProfile: enablePublicAccess ? null : {
      // Use the network profile only if public access is disabled
      id: networkProfile.id
    }
    restartPolicy: 'Always'

  }
}

output containerIPv4Address string = containerGroup.properties.ipAddress.ip
