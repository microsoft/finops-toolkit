//==============================================================================
// Parameters
//==============================================================================

targetScope = 'resourceGroup'

@description('Azure location where resources should be created')
param location string = resourceGroup().location

@description('Name of the logic app')
@minLength(1)
@maxLength(20)
param appName string = 'FinOpsAlert'

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

//==============================================================================
// Resources
//==============================================================================

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


