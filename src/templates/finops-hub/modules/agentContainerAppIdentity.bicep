extension microsoftGraphV1

param agentUniqueName string

param createSecret bool = false

param startDateTime string = utcNow()
param endDateTime string = dateTimeAdd(utcNow(), 'P29D')

resource agentContainerAppIdentity 'Microsoft.Graph/applications@v1.0' = {
  displayName: agentUniqueName
  uniqueName: agentUniqueName
  passwordCredentials : !createSecret ? [] : [
    {
      displayName: agentUniqueName
      startDateTime: startDateTime
      endDateTime: endDateTime
    }
  ]
}

resource agentContainerAppIdentitySp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: agentContainerAppIdentity.appId
}

output id string = agentContainerAppIdentity.id
output appId string = agentContainerAppIdentity.appId
output agentUniqueName string = agentContainerAppIdentity.uniqueName
