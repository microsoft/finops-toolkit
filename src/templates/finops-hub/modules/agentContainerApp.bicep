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
param containerImage string

@description('Specifies the container port.')
param targetPort int

@description('Specifies the Tenant Id of the Entra Id App Registration for the container app.')
param hubAgentTenantId string

@description('Specifies the Application Id of the Entra Id App Registration for the container app.')
param hubAgentAppId string

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

param revisionId int = dateTimeToEpoch(utcNow())

param ADX_CLUSTER_URL string
param ADX_DATABASE string

@secure()
param TAVILY_API_KEY string
@secure()
param AZURE_AI_SEARCH_ADMIN_KEY string
@secure()
param AZURE_OPENAI_KEY string
@secure()
param AZURE_INFERENCE_KEY string

param PROJECT_CONNECTION_STRING string
param AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED string
param AZURE_AI_SEARCH_SERVICE_ENDPOINT string
param AZURE_AI_SEARCH_INDEX_NAME string
param AZURE_AI_SEARCH_INDEX_KQL string
param AZURE_OPENAI_ENDPOINT string
param AZURE_OPENAI_EMBEDDING_DEPLOYMENT string
param AZURE_OPENAI_API_VERSION string
param AZURE_INFERENCE_ENDPOINT string

param MODEL_NAME  string

@description('Resource ID of the virtual network for private endpoints.')
param virtualNetworkId string = ''

// DNS configuration for private deployments
var containerAppDnsZoneName = '${location}.azurecontainerapps.io'

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
      activeRevisionsMode: 'Single'
      maxInactiveRevisions: 1
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
      secrets: [
        {
          name: 'tavily-key'
          value: TAVILY_API_KEY
        }
        { 
          name : 'search-key'
          value: AZURE_AI_SEARCH_ADMIN_KEY
        }
        { 
          name : 'openai-key'
          value: AZURE_OPENAI_KEY
        }
        { 
          name : 'inference-key'
          value: AZURE_INFERENCE_KEY
        }
      ]
    }
    template: {
      revisionSuffix: '${revisionId}'
      containers: [
        {
          name: containerAppName
          image: containerImage
          resources: {
            cpu: json(cpuCore)
            memory: '${memorySize}Gi'
          }
          env: [
            {
              name: 'ADX_CLUSTER_URL'
              value: ADX_CLUSTER_URL
            }
            {
              name: 'ADX_DATABASE'
              value: ADX_DATABASE
            }
            {
              name: 'PROJECT_CONNECTION_STRING'
              value: PROJECT_CONNECTION_STRING
            }
            {
              name: 'AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED'
              value: AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED
            }
            {
              name: 'AZURE_AI_SEARCH_SERVICE_ENDPOINT'
              value: AZURE_AI_SEARCH_SERVICE_ENDPOINT
            }
            {
              name: 'AZURE_AI_SEARCH_ADMIN_KEY'
              secretRef: 'search-key'
            }
            {
              name: 'AZURE_AI_SEARCH_INDEX_NAME'
              value: AZURE_AI_SEARCH_INDEX_NAME
            }
            {
              name: 'AZURE_AI_SEARCH_INDEX_KQL'
              value: AZURE_AI_SEARCH_INDEX_KQL
            }
            {
              name: 'AZURE_OPENAI_KEY'
              secretRef: 'openai-key'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: AZURE_OPENAI_ENDPOINT
            }
            {
              name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
              value: AZURE_OPENAI_EMBEDDING_DEPLOYMENT
            }
            {
              name: 'AZURE_OPENAI_API_VERSION'
              value: AZURE_OPENAI_API_VERSION
            }
            {
              name: 'AZURE_INFERENCE_ENDPOINT'
              value: AZURE_INFERENCE_ENDPOINT
            }
            {
              name: 'AZURE_INFERENCE_KEY'
              secretRef: 'inference-key'
            }
            {
              name: 'MODEL_NAME'
              value: MODEL_NAME
            }
            {
              name: 'TAVILY_API_KEY'
              secretRef: 'tavily-key'
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

resource containerAppAuthConfig 'Microsoft.App/containerApps/authConfigs@2025-01-01' = {
  parent: containerApp
  name: 'current'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        registration: {
          openIdIssuer: '${environment().authentication.loginEndpoint}${hubAgentTenantId}/v2.0'
          clientId: hubAgentAppId
        }
        validation: {
          allowedAudiences: []
          defaultAuthorizationPolicy: {
            allowedApplications: [
              hubAgentAppId
            ]
          }
        }
        isAutoProvisioned: false
      }
    }
    login: {
      routes: {}
      preserveUrlFragmentsForLogins: false
      cookieExpiration: {}
      nonce: {}
    }
    encryptionSettings: {}  }
}

resource containerAppDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!enablePublicAccess) {
  name: containerAppDnsZoneName
  location: 'global'
  tags: union(tags, tagsByResource[?'Microsoft.Network/privateDnsZones'] ?? {})
  properties: {}
}

resource containerAppDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!enablePublicAccess) {
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

resource containerAppDnsARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = if (!enablePublicAccess) {
  parent: containerAppDnsZone
  name: containerAppName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: containerAppEnv.properties.staticIp
      }
    ]
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
