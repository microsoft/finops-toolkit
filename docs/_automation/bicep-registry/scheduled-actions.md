---
layout: default
parent: Bicep Registry
title: Scheduled actions
nav_order: 10
description: 'Send an email on a schedule or when an anomaly is detected'
permalink: /bicep/scheduled-actions
---

<span class="fs-9 d-block mb-4">Scheduled actions</span>
Send an email on a schedule or when an anomaly is detected.
{: .fs-6 .fw-300 }

[Syntax](#-syntax){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Examples](#-examples){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🧮 Syntax](#-syntax)
- [📥 Parameters](#-parameters)
- [🌟 Examples](#-examples)
- [🧐 See also](#-see-also)
- [🧰 Related tools](#-related-tools)

</details>

---

Scheduled actions allow you to configure email alerts on a daily, weekly, or monthly basis. Scheduled actions are configured based on a Cost Management view, which can be opened and edited in Cost analysis in the Azure portal. Email alerts include a picture of the selected view and optionally a link to a CSV file with the summarized cost data.

You can also use scheduled actions to configure anomaly detection alerts for subscriptions.

[About scheduled alerts](https://learn.microsoft.com/azure/cost-management-billing/costs/save-share-views#subscribe-to-scheduled-alerts){: .btn .mb-4 .mb-md-0 .mr-4 }
[About anomaly alerts](https://learn.microsoft.com/azure/cost-management-billing/understand/analyze-unexpected-charges){: .btn .mb-4 .mb-md-0 .mr-4 }

<br>

## 🧮 Syntax

<small>Version: **1.1**</small>
{: .label .label-green .pt-0 .pl-3 .pr-3 .m-0 }
<small>Scopes: **Subscription, Resource group**</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

```bicep
module <string> 'br/public:cost/<scope>-scheduled-action:1.1' = {
  name: <string>
  params: {
    name: <string>
    kind: 'Email' | 'InsightAlert'
    private: <bool>
    builtInView: 'AccumulatedCosts' | 'CostByService' | 'DailyCosts'
    viewId: <string>
    displayName: <string>
    status: 'Enabled' | 'Disabled'
    notificationEmail: <string>
    emailRecipients: [ <string>, <string>, ... ]
    emailSubject: <string>
    emailMessage: <string>
    emailLanguage: <string>
    emailRegionalFormat: <string>
    includeCsv: <bool>
    scheduleFrequency: 'Daily' | 'Weekly' | 'Monthly'
    scheduleDaysOfWeek: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' ]
    scheduleDayOfMonth: <int>
    scheduleWeeksOfMonth: [ 'First', 'Second', 'Third', 'Fourth', 'Last' ]
    scheduleStartDate: 'yyyy-MM-ddTHH:miZ'
    scheduleEndDate: 'yyyy-MM-dd'
  }
}
```

<br>

## 📥 Parameters

| Name                   |   Type   | Description                                                                                                                                                                                                                                                                                           |
| ---------------------- | :------: | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                 | `string` | Required. Name of the scheduled action used in the resource ID.                                                                                                                                                                                                                                       |
| `kind`                 | `string` | Optional. Indicates the kind of scheduled action. Default: Email.                                                                                                                                                                                                                                     |
| `private`              |  `bool`  | Optional. Indicates whether the scheduled action is private and only editable by the current user. If false, the scheduled action will be shared with other users in the same scope. Ignored if kind is "InsightAlert". Default: false.                                                               |
| `builtInView`          | `string` | Optional. Specifies which built-in view to use. This is a shortcut for the full view ID.                                                                                                                                                                                                              |
| `viewId`               | `string` | Optional. Required if kind is "Email" and builtInView is not set. The resource ID of the view to which the scheduled action will send. The view must either be private (tenant level) or owned by the same scope as the scheduled action. Ignored if kind is "InsightAlert" or if builtInView is set. |
| `displayName`          | `string` | Optional. The display name to show in the portal when viewing the list of scheduled actions. Default: (scheduled action name).                                                                                                                                                                        |
| `status`               | `string` | Optional. The status of the scheduled action. Default: Enabled.                                                                                                                                                                                                                                       |
| `notificationEmail`    | `string` | Required. Email address of the person or team responsible for this scheduled action. This email address will be included in emails. Default: (email address of user deploying the template).                                                                                                          |
| `emailRecipients`      | `array`  | Required. List of email addresses that should receive emails. At least one valid email address is required.                                                                                                                                                                                           |
| `emailSubject`         | `string` | Optional. The subject of the email that will be sent to the email recipients. Default: (view name).                                                                                                                                                                                                   |
| `emailMessage`         | `string` | Optional. Include a message for recipients to add context about why they are getting the email, what to do, and/or who to contact. Default: "" (no message).                                                                                                                                          |
| `emailLanguage`        | `string` | Optional. The language that will be used for the email template. Default: en.                                                                                                                                                                                                                         |
| `emailRegionalFormat`  | `string` | Optional. The regional format that will be used for dates, times, and numbers. Default: en-us.                                                                                                                                                                                                        |
| `includeCsv`           |  `bool`  | Optional. Indicates whether to include a link to a CSV file with the backing data for the chart. Ignored if kind is "InsightAlert". Default: false.                                                                                                                                                   |
| `scheduleFrequency`    | `string` | Optional. The frequency at which the scheduled action will run. Default: Daily for "Email" and Weekly for "InsightAlert".                                                                                                                                                                             |
| `scheduleDaysOfWeek`   | `array`  | Optional. Required if kind is "Email" and scheduleFrequency is "Weekly". List of days of the week that emails should be delivered. Allowed: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday. Default: Monday.                                                                          |
| `scheduleDayOfMonth`   |  `int`   | Optional. Required if kind is "Email" and scheduleFrequency is "Monthly". The day of the month that emails should be delivered. Note monthly cost is not final until the 3rd of the month. This or scheduleWeeksOfMonth is required if scheduleFrequency is "Monthly". Default: 0 (not set).          |
| `scheduleWeeksOfMonth` | `array`  | Optional. List of weeks of the month that emails should be delivered. This or scheduleDayOfMonth is required if scheduleFrequency is "Monthly". Allowed: First, Second, Third, Fourth, Last. Default [] (not set).                                                                                    |
| `scheduleStartDate`    | `string` | Optional. The first day the schedule should run. Use the time to indicate when you want to receive emails. Must be in the format yyyy-MM-ddTHH:miZ. Default = Now.                                                                                                                                    |
| `scheduleEndDate`      | `string` | Optional. The last day the schedule should run. Must be in the format yyyy-MM-dd. Default = 1 year from start date.                                                                                                                                                                                   |

<br>

## 🌟 Examples

### Schedule an email for a built-in view

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

Creates a shared scheduled action for the DailyCosts built-in view.

```bicep
module dailyCostsAlert 'br/public:cost/subscription-scheduled-action:1.0.2' = {
  name: 'dailyCostsAlert'
  params: {
    name: 'DailyCostsAlert'
    displayName: 'My schedule'
    builtInView: 'DailyCosts'
    emailRecipients: [ 'ema@contoso.com' ]
    notificationEmail: 'ema@contoso.com'
    scheduleFrequency: 'Weekly'
    scheduleDaysOfWeek: [ 'Monday' ]
  }
}
```

### Schedule an email with a custom start date

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }
<small>Resource group</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

Creates a private scheduled action for the DailyCosts built-in view with custom start/end dates.

```bicep
module privateAlert 'br/public:cost/resourcegroup-scheduled-action:1.0.2' = {
  name: 'privateAlert'
  params: {
    name: 'PrivateAlert'
    displayName: 'My private schedule'
    private: true
    builtInView: 'DailyCosts'
    emailRecipients: [ 'priya@contoso.com' ]
    notificationEmail: 'priya@contoso.com'
    scheduleFrequency: 'Monthly'
    scheduleDayOfMonth: 1
    scheduleStartDate: scheduleStartDate
    scheduleEndDate: scheduleEndDate
  }
}
```

### Configure an anomaly alert

<small>Subscription</small>
{: .label .pt-0 .pl-3 .pr-3 .m-0 }

Creates an anomaly alert for a subscription.

```bicep
module anomalyAlert 'br/public:cost/subscription-scheduled-action:1.0.2' = {
  name: 'anomalyAlert'
  params: {
    name: 'AnomalyAlert'
    kind: 'InsightAlert'
    displayName: 'My anomaly check'
    emailRecipients: [ 'ana@contoso.com' ]
    notificationEmail: 'ana@contoso.com'
  }
}
```

<br>

## 🧐 See also

- Bicep Registry: [Scheduled actions for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-scheduled-action/README.md)
- Bicep Registry: [Scheduled actions for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-scheduled-action/README.md)
- [ScheduledActions API reference](https://learn.microsoft.com/rest/api/cost-management/scheduled-actions)

<br>

---

## 🧰 Related tools

{% include tools.md ps="1" %}

<br>
