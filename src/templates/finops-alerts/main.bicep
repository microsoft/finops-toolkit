//==============================================================================
// Parameters
//==============================================================================

targetScope = 'resourceGroup'

@description('Azure location where resources should be created')
param location string = resourceGroup().location

@description('Name of the logic app')
@minLength(1)
@maxLength(20)
param appName string = 'finops-alerts'

@description('Specifies the frequency of the recurrence trigger. Possible values are Week, Day or Hour.')
param recurrenceFrequency string = 'Week'

@description('Specifies the interval for the recurrence trigger. Represents the number of frequency units.')
param recurrenceInterval int = 1

@description('Specifies the type of the trigger. For this example, it is a recurrence trigger.')
param recurrenceType string = 'Recurrence'

//@description('A list of resource Id of subscriptions.')
//param subscriptionsIds array = [
  //'dbc1e833-6b33-4788-b219-b9266b898fad'
//]

@description('The Id of the subscription to deploy the logic app in.')
param logicAppSubscriptionId string = ''

@description('The name of the resource group.')
param resourceGroupName string = ''

@sys.description('Optional. Enable telemetry to track anonymous module usage trends, monitor for bugs, and improve future releases.')
param enableDefaultTelemetry bool = true

//==============================================================================
// Resources
//==============================================================================

resource defaultTelemetry 'Microsoft.Resources/deployments@2022-09-01' = if (enableDefaultTelemetry) {
  name: 'pid-00f120b5-2007-6120-0000-a7e122500000-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      metadata: {
        _generator: {
          name: 'FinOps toolkit'
          version: loadTextContent('modules/ftkver.txt')  // cSpell:ignore ftkver
        }
      }
      resources: []
    }
  }
}

module logicApp 'modules/logicApp.bicep' = {
  name: 'logicApp-${uniqueString(deployment().name,location,appName)}'
  scope: resourceGroup(logicAppSubscriptionId, resourceGroupName)
  params: {
    appName: appName
    location: location
    recurrenceFrequency: recurrenceFrequency
    recurrenceInterval: recurrenceInterval
    recurrenceType: recurrenceType
  }
}
