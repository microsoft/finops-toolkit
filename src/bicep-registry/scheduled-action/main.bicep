// @resourceGroup @subscription @tenant

// See https://learn.microsoft.com/rest/api/cost-management/scheduled-actions/create-or-update

//===| Parameters |============================================================

targetScope = 'subscription'

@description('Name of the scheduled action used in the resource ID.')
param name string

@description('Indicates the kind of scheduled action.')
@allowed([
  'Email'
  'InsightAlert' // @subscription
])
param kind string = 'Email'

// @tenant
//   @description('The Azure resource ID for the billing scope to use. This is the full resource ID of a billing account, billing profile, department, etc. Do not use the GUID only.')
//   param scope string

@description('Specifies which built-in view to use. This is a shortcut for the full view ID.')
@allowed([
  ''
  'AccumulatedCosts'
  'DailyCosts'
  'InvoiceDetails'
])
param builtInView string = ''

@description('Required if kind is "Email" and builtInView is not set. The resource ID of the view to which the scheduled action will send. The view must either be private (tenant level) or owned by the same scope as the scheduled action. Ignored if kind is "InsightAlert" or if builtInView is set.')
param viewId string = ''

@description('The display name to show in the portal when viewing the list of scheduled actions.')
param displayName string = name

@description('The status of the scheduled action.')
@allowed([
  'Enabled'
  'Disabled'
])
param status string = 'Enabled'

@description('Email address of the person or team responsible for this scheduled action. This email address will be included in emails.')
param notificationEmail string = ''

@description('List of email addresses that should receive emails. At least one valid email address is required.')
param emailRecipients array

@description('The subject of the email that will be sent to the email recipients.')
@maxLength(70)
param emailSubject string = ''

@description('Include a message for recipients to add context about why they are getting the email, what to do, and/or who to contact.')
@maxLength(250)
param emailMessage string = ''

@description('The language that will be used for the email template.')
param emailLanguage string = 'en'

@description('The regional format that will be used for dates, times, and numbers.')
param emailRegionalFormat string = 'en-US'

@description('Indicates whether to include a link to a CSV file with the backing data for the chart. Ignored if kind is "InsightAlert".')
param includeCsv bool = false

@description('The frequency at which the scheduled action will run.')
@allowed([
  'Daily'
  'Weekly'
  'Monthly'
])
param scheduleFrequency string = kind == 'InsightAlert' ? 'Daily' : 'Weekly'

@description('Required if kind is "Email" and scheduleFrequency is "Weekly". List of days of the week that emails should be delivered. Allowed: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday.')
param scheduleDaysOfWeek array = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' ]

@description('Required if kind is "Email" and scheduleFrequency is "Monthly". The day of the month that emails should be delivered. Note monthly cost is not final until the 3rd of the month. This or scheduleWeeksOfMonth is required if scheduleFrequency is "Monthly".')
@allowed([ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 ])
param scheduleDayOfMonth int = 0

@description('List of weeks of the month that emails should be delivered. This or scheduleDayOfMonth is required if scheduleFrequency is "Monthly". Allowed: First, Second, Third, Fourth, Last.')
param scheduleWeeksOfMonth array = []

@description('The first day the schedule should run. Use the time to indicate when you want to receive emails. Must be in the format yyyy-MM-ddTHH:miZ. Default = Today')
param scheduleStartDate string = utcNow('yyyy-MM-ddTHH:mm:ssZ')

@description('The last day the schedule should run. Must be in the format yyyy-MM-dd. Default = 1 year from start date.')
param scheduleEndDate string = ''

// @subscription
var scope = subscription().id
// @resourceGroup
//   var scope = resourceGroup().id

var internalViewId = builtInView == null ? viewId : '${scope}/providers/Microsoft.CostManagement/views/ms:${builtInView}'

//===| Resources |=============================================================

resource sa 'Microsoft.CostManagement/scheduledActions@2022-10-01' = {
  name: name
  kind: kind
  properties: {
    scope: scope
    displayName: displayName
    viewId: kind == 'InsightAlert' ? '${scope}/providers/Microsoft.CostManagement/views/ms:DailyAnomalyByResourceGroup' : internalViewId
    notificationEmail: notificationEmail
    status: status
    fileDestination: includeCsv ? {
      fileFormats: [ 'Csv' ]
    } : {}
    notification: union(
      {
        subject: emailSubject != null && emailSubject != '' ? emailSubject : (displayName != null && displayName != '' ? displayName : name)
        to: emailRecipients
        language: emailLanguage
        regionalFormat: emailRegionalFormat
      },
      emailMessage == '' ? {} : { message: emailMessage }
    )
    schedule: union(
      {
        startDate: scheduleStartDate
        endDate: scheduleEndDate != null && scheduleEndDate != '' ? scheduleEndDate : dateTimeAdd(scheduleStartDate, 'P1Y')
        frequency: kind == 'InsightAlert' ? 'Daily' : scheduleFrequency
      },
      (kind == 'Email' && scheduleFrequency == 'Weekly') ? { daysOfWeek: scheduleDaysOfWeek } : {},
      (kind == 'Email' && scheduleFrequency == 'Monthly' && scheduleDayOfMonth != null) ? { dayOfMonth: scheduleDayOfMonth } : {},
      (kind == 'Email' && scheduleFrequency == 'Monthly' && scheduleDayOfMonth == null) ? { weeksOfMonth: scheduleWeeksOfMonth } : {}
    )
  }
}

//===| Outputs |===============================================================

@description('Resource ID of the scheduled action.')
output scheduledActionId string = sa.id
