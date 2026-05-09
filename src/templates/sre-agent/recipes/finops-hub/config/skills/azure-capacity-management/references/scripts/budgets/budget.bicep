targetScope = 'subscription'

@description('Name of the Budget. It should be unique within the subscription.')
param budgetName string = 'SubscriptionBudget'

@description('The total amount of cost to track with the budget (in the billing currency). If subscription has BudgetAmount tag, that value is used instead.')
param amount int = 10

@description('The time covered by a budget. Tracking of the amount will be reset based on the time grain.')
@allowed([
  'Monthly'
  'Quarterly'
  'Annually'
])
param timeGrain string = 'Monthly'

@description('The start date must be first of the month in YYYY-MM-DD format.')
param startDate string

@description('The end date for the budget in YYYY-MM-DD format.')
param endDate string

@description('First threshold percentage. Notification sent when cost exceeds this threshold.')
param firstThreshold int = 50

@description('Second threshold percentage. Notification sent when cost exceeds this threshold.')
param secondThreshold int = 75

@description('Third threshold percentage. Notification sent when cost exceeds this threshold.')
param thirdThreshold int = 90

@description('Forecasted threshold percentage. Notification sent when FORECASTED cost exceeds this threshold.')
param forecastedThreshold int = 100

@description('The list of email addresses to send the budget notification to when thresholds are exceeded.')
param contactEmails array

@description('The list of contact roles to send the budget notification to when the threshold is exceeded.')
param contactRoles array = [
  'Owner'
  'Contributor'
]

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    timeGrain: timeGrain
    amount: amount
    category: 'Cost'
    notifications: {
      Notification_FirstThreshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: firstThreshold
        contactEmails: contactEmails
        contactRoles: contactRoles
      }
      Notification_SecondThreshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: secondThreshold
        contactEmails: contactEmails
        contactRoles: contactRoles
      }
      Notification_ThirdThreshold: {
        enabled: true
        operator: 'GreaterThan'
        threshold: thirdThreshold
        contactEmails: contactEmails
        contactRoles: contactRoles
      }
      Notification_Forecasted: {
        enabled: true
        operator: 'GreaterThan'
        threshold: forecastedThreshold
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
        contactRoles: contactRoles
      }
    }
  }
}

output name string = budget.name
output resourceId string = budget.id
