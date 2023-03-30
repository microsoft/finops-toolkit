targetScope = 'subscription' // @resourceGroup @subscription @tenant

param startTime string = utcNow('yyyy-MM-dd')

var scheduleStartDate = '${dateTimeAdd(startTime, 'P1M', 'yyyy-MM-dd')}T08:00Z'
var scheduleEndDate = '${dateTimeAdd(startTime, 'P1M1D', 'yyyy-MM-dd')}T08:00Z'

// Test 1 - Create a shared scheduled action for the DailyCosts built-in view.
module dailyCostsAlert '../main.bicep' = {
  name: 'dailyCostsAlert'
  params: {
    name: 'DailyCostsAlert'
    displayName: 'My schedule'
    // billingAccountId: '8611537' // @tenant
    builtInView: 'DailyCosts'
    emailRecipients: [ 'ema@contoso.com' ]
    scheduleFrequency: 'Weekly'
    scheduleDaysOfWeek: [ 'Monday' ]
    scheduleStartDate: scheduleStartDate
    scheduleEndDate: scheduleEndDate
  }
}

// Test 2 - Creating a private scheduled action for the DailyCosts built-in view.
module privateAlert '../main.bicep' = {
  name: 'privateAlert'
  params: {
    name: 'PrivateAlert'
    displayName: 'My private schedule'
    private: true
    // privateScope: '/providers/Microsoft.Billing/billingAccounts/8611537' // @tenant
    builtInView: 'DailyCosts'
    emailRecipients: [ 'priya@contoso.com' ]
    scheduleFrequency: 'Monthly'
    scheduleDayOfMonth: 1
    scheduleStartDate: scheduleStartDate
    scheduleEndDate: scheduleEndDate
  }
}

// @subscription
//// Test 3 - Creating an anomaly alert.
module anomalyAlert '../main.bicep' = {
  name: 'anomalyAlert'
  params: {
    name: 'AnomalyAlert'
    kind: 'InsightAlert'
    displayName: 'My anomaly check'
    emailRecipients: [ 'ana@contoso.com' ]
  }
}

output dailyCostsAlertId string = dailyCostsAlert.outputs.scheduledActionId
output privateAlertId string = privateAlert.outputs.scheduledActionId
output anomalyAlertId string = anomalyAlert.outputs.scheduledActionId // @subscription
