targetScope = 'subscription'

param emailRecipients array
param notificationEmail string


module anomalyAlert 'br/public:cost/subscription-scheduled-action:1.0.2' = {
  name: 'anomalyAlert'
  scope: subscription()
  params: {
    name: 'AnomalyAlert'
    kind: 'InsightAlert'
    displayName: 'Cost anomaly alert'
    emailRecipients: emailRecipients
    notificationEmail: notificationEmail
  }
}
