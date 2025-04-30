@description('Optional. Enable public access to the data lake.  Default: false.')
param enablePublicAccess bool = true

@description('Resource ID of the subnet')
param subnetId string

@description('Location for all resources.')
param location string

@description('Container group name')
param containerGroupName string

@description('Container name')
param containerName string

@description('Container image to deploy. Should be of the form accountName/imagename:tag for images stored in Docker Hub or a fully qualified URI for a private registry like the Azure Container Registry.')
param image string

@description('Port to open on the container.')
param port int

@description('The number of CPU cores to allocate to the container. Must be an integer.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

var networkProfileName = 'aci-networkProfile'
var interfaceConfigName = 'eth0'
var interfaceIpConfig = 'ipconfigprofile1'

resource networkProfile 'Microsoft.Network/networkProfiles@2020-11-01' = if (!enablePublicAccess){
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
                  id: subnetId
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
          ports: [
            {
              port: port
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    osType: 'Linux'
    networkProfile: enablePublicAccess ? null : {
      id: networkProfile.id
    }
    restartPolicy: 'Always'
  }
}

output containerIPv4Address string = containerGroup.properties.ipAddress.ip
