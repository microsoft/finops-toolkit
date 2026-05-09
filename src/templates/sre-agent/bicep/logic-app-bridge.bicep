// modules/logic-app-bridge.bicep
//
// Deploys a Consumption Logic App that acts as an auth bridge for external
// webhook sources (Dynatrace, Grafana, Datadog, etc.) that can't natively
// acquire Azure AD tokens for the SRE Agent data plane.
//
// Flow: External webhook → Logic App HTTP trigger (no auth) →
//       Logic App acquires AAD token via Managed Identity →
//       Forwards to SRE Agent HTTP Trigger with Bearer token.
//
// The Logic App's system-assigned MI is granted "SRE Agent Administrator"
// on the agent resource so it can invoke the data plane.

param agentName string
param location string

@description('The SRE Agent HTTP Trigger URL to forward requests to.')
param triggerUrl string

// ─── Logic App ───
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${agentName}-webhook-bridge'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      triggers: {
        incoming_webhook: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
            }
          }
        }
      }
      actions: {
        forward_to_sre_agent: {
          type: 'Http'
          runAfter: {}
          inputs: {
            method: 'POST'
            uri: triggerUrl
            headers: {
              'Content-Type': 'application/json'
            }
            body: '@triggerBody()'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://azuresre.dev'
            }
          }
        }
      }
    }
  }
}

// ─── RBAC: SRE Agent Administrator on the agent resource ───
// Role ID for "SRE Agent Administrator"
var sreAgentAdminRoleId = 'e79298df-d852-4c6d-84f9-5d13249d1e55'

resource agent 'Microsoft.App/agents@2025-05-01-preview' existing = {
  name: agentName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agent.id, logicApp.id, sreAgentAdminRoleId)
  scope: agent
  properties: {
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sreAgentAdminRoleId)
  }
}

output logicAppName string = logicApp.name
output logicAppPrincipalId string = logicApp.identity.principalId
output logicAppCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'incoming_webhook'), '2019-05-01').value
