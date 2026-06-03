targetScope = 'resourceGroup'

@description('Location for the deployment script resources.')
param location string

@description('SRE Agent name.')
param agentName string

@description('SRE Agent data-plane endpoint.')
param agentEndpoint string

@description('Subscription that contains the SRE Agent.')
param subscriptionId string

@description('Public URI for the generated SRE Agent recipe package.')
param recipePackageUri string

@description('Optional database-qualified Kusto connector URI.')
param kustoConnectorUri string = ''

@description('Forces the deployment script to run when the template is redeployed.')
param forceUpdateTag string

@description('Azure resource tags.')
param tags object = {}

var identityName = 'id-sre-apply-${uniqueString(resourceGroup().id, agentName)}'
var scriptName = 'apply-sre-${uniqueString(resourceGroup().id, agentName)}'
var sreAgentAdminRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

#disable-next-line BCP081
resource sreAgent 'Microsoft.App/agents@2026-01-01' existing = {
  name: agentName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

resource sreAgentAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sreAgent.id, identity.id, sreAgentAdminRoleId)
  scope: sreAgent
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sreAgentAdminRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource applyExtras 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: scriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT2H'
    forceUpdateTag: forceUpdateTag
    scriptContent: loadTextContent('../scripts/Apply-SreAgentExtras.ps1')
    environmentVariables: [
      {
        name: 'subscriptionId'
        value: subscriptionId
      }
      {
        name: 'resourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'agentName'
        value: agentName
      }
      {
        name: 'agentEndpoint'
        value: agentEndpoint
      }
      {
        name: 'recipePackageUri'
        value: recipePackageUri
      }
      {
        name: 'kustoConnectorUri'
        value: kustoConnectorUri
      }
    ]
  }
  dependsOn: [
    sreAgentAdminRoleAssignment
  ]
}

output identityName string = identity.name
output scriptName string = applyExtras.name
