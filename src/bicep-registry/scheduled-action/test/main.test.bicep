/* @resourceGroup
targetScope = 'subscription'
*/
/* @subscription
targetScope = 'subscription'
*/
/* @tenant
targetScope = 'subscription'
*/

param startTime string = utcNow('yyyy-MM-dd')

var scheduleStartDate = '${dateTimeAdd(startTime, 'P1M', 'yyyy-MM-dd')}T08:00Z'
var scheduleEndDate = '${dateTimeAdd(startTime, 'P1M1D', 'yyyy-MM-dd')}T08:00Z'

/* @subscription
Test:Creates a shared scheduled action for the DailyCosts built-in view.
module dailyCostsAlert '../main.bicep' = {
  name: 'dailyCostsAlert'
  params: {
    name: 'DailyCostsAlert'
    displayName: 'My schedule'
    billingAccountId: '8611537' // @tenant
    builtInView: 'DailyCosts'
    emailRecipients: [ 'ema@contoso.com' ]
    scheduleFrequency: 'Weekly'
    scheduleDaysOfWeek: [ 'Monday' ]
  }
}
*/

/* @subscription
Test:Creates a private scheduled action for the DailyCosts built-in view with custom start/end dates.
module privateAlert '../main.bicep' = {
  name: 'privateAlert'
  params: {
    name: 'PrivateAlert'
    displayName: 'My private schedule'
    private: true
    privateScope: '/providers/Microsoft.Billing/billingAccounts/8611537'
    builtInView: 'DailyCosts'
    emailRecipients: [ 'priya@contoso.com' ]
    scheduleFrequency: 'Monthly'
    scheduleDayOfMonth: 1
    scheduleStartDate: scheduleStartDate
    scheduleEndDate: scheduleEndDate
  }
}
*/

/* @subscription
Test:Creates an anomaly alert.
module anomalyAlert '../main.bicep' = {
  name: 'anomalyAlert'
  params: {
    name: 'AnomalyAlert'
    kind: 'InsightAlert'
    displayName: 'My anomaly check'
    emailRecipients: [ 'ana@contoso.com' ]
  }
}
*/

output dailyCostsAlertId string = dailyCostsAlert.outputs.scheduledActionId
output privateAlertId string = privateAlert.outputs.scheduledActionId

/* @subscription
output anomalyAlertId string = anomalyAlert.outputs.scheduledActionId //
*/
