---
title: Cost Management scheduled action bicep modules
description: This article describes the Cost Management scheduled actions Bicep Registry modules that help you send an email on a schedule or when an anomaly is detected.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what Cost Management scheduled action bicep modules can help me accomplish.
---

# Cost Management scheduled action bicep modules

This article describes the Cost Management scheduled actions Bicep Registry modules that help you send an email on a schedule or when an anomaly is detected.

Scheduled actions allow you to configure email alerts on a daily, weekly, or monthly basis. Scheduled actions are configured based on a Cost Management view, which can be opened and edited in Cost analysis in the Azure portal. Email alerts include a picture of the selected view and optionally a link to a CSV file with the summarized cost data. You can also use scheduled actions to configure anomaly detection alerts for subscriptions.

To learn about scheduled alerts, see [Save and share views](/azure/cost-management-billing/costs/save-share-views#subscribe-to-scheduled-alerts). To learn about anomaly alerts, see [Analyze unexpected charges](/azure/cost-management-billing/understand/analyze-unexpected-charges).

<br>

## Syntax

Version: **1.1** &nbsp; Scopes: **Subscription, Resource group**

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

## Parameters

Here are the parameters for the scheduled action modules:

| Name                   |   Type   | Description                                                                                                                                                                                                                                                                                        |
| ---------------------- | :------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                 | `string` | Required. Name of the scheduled action used in the resource ID.                                                                                                                                                                                                                                    |
| `kind`                 | `string` | Optional. Indicates the kind of scheduled action. Default: Email.                                                                                                                                                                                                                                  |
| `private`              |  `bool`  | Optional. Indicates whether the scheduled action is private and only editable by the current user. If false, the scheduled action is shared with other users in the same scope. Ignored if kind is `InsightAlert`. Default: false.                                                                 |
| `builtInView`          | `string` | Optional. Specifies which built-in view to use. It's a shortcut for the full view ID.                                                                                                                                                                                                              |
| `viewId`               | `string` | Optional. Required if kind is `Email` and builtInView isn't set. The resource ID of the view to which the scheduled action sends. The view must either be private (tenant level) or owned by the same scope as the scheduled action. Ignored if kind is `InsightAlert` or if builtInView is set.   |
| `displayName`          | `string` | Optional. The display name to show in the portal when viewing the list of scheduled actions. Default: (scheduled action name).                                                                                                                                                                     |
| `status`               | `string` | Optional. The status of the scheduled action. Default: Enabled.                                                                                                                                                                                                                                    |
| `notificationEmail`    | `string` | Required. Email address of the person or team responsible for this scheduled action. This email address is included in emails. Default: (email address of user deploying the template).                                                                                                            |
| `emailRecipients`      | `array`  | Required. List of email addresses that should receive emails. At least one valid email address is required.                                                                                                                                                                                        |
| `emailSubject`         | `string` | Optional. The subject of the email that gets sent to the email recipients. Default: (view name).                                                                                                                                                                                                   |
| `emailMessage`         | `string` | Optional. Include a message for recipients to add context about why they're getting the email, what to do, and/or who to contact. Default: `""` (no message).                                                                                                                                      |
| `emailLanguage`        | `string` | Optional. The language that is used for the email template. Default: en.                                                                                                                                                                                                                           |
| `emailRegionalFormat`  | `string` | Optional. The regional format that is used for dates, times, and numbers. Default: en-us.                                                                                                                                                                                                          |
| `includeCsv`           |  `bool`  | Optional. Indicates whether to include a link to a CSV file with the backing data for the chart. Ignored if kind is `InsightAlert`. Default: false.                                                                                                                                                |
| `scheduleFrequency`    | `string` | Optional. The frequency that the scheduled action runs. Default: Daily for `Email` and Weekly for `InsightAlert`.                                                                                                                                                                                  |
| `scheduleDaysOfWeek`   | `array`  | Optional. Required if kind is `Email` and scheduleFrequency is `Weekly`. List of days of the week that emails should be delivered. Allowed: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday. Default: Monday.                                                                       |
| `scheduleDayOfMonth`   |  `int`   | Optional. Required if kind is `Email` and scheduleFrequency is `Monthly`. The day of the month that emails should be delivered. Monthly cost isn't final until the third day of the month. This value or scheduleWeeksOfMonth is required if scheduleFrequency is `Monthly`. Default: 0 (not set). |
| `scheduleWeeksOfMonth` | `array`  | Optional. List of weeks of the month that emails should be delivered. This value or scheduleDayOfMonth is required if scheduleFrequency is `Monthly`. Allowed: First, Second, Third, Fourth, Last. Default [] (not set).                                                                           |
| `scheduleStartDate`    | `string` | Optional. The first day the schedule should run. Use the time to indicate when you want to receive emails. Must be in the format yyyy-MM-ddTHH:miZ. Default = Now.                                                                                                                                 |
| `scheduleEndDate`      | `string` | Optional. The last day the schedule should run. Must be in the format yyyy-MM-dd. Default = 1 year from start date.                                                                                                                                                                                |

<br>

## Examples

The following examples help you send an email on a schedule or when an anomaly is detected.

### Schedule an email for a built-in view

Subscription &nbsp; Resource group

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

Subscription &nbsp; Resource group

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

Subscription

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20deploy%20Cost%20Management%20scheduled%20actions%20with%20the%20FinOps%20toolkit%20bicep%20modules%3F/cvaQuestion/How%20valuable%20are%20the%20Cost%20Management%20scheduled%20actions%20bicep%20modules%3F/surveyId/FTK/bladeName/BicepRegistry/featureName/CostManagement.ScheduledActions)
<!-- prettier-ignore-end -->

If you're looking for a specific module or template, vote for an existing or create a new idea. Share your ideas with others. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Tool%3A+Bicep+Registry%22+sort%3Areactions-%2B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related resources:

- Bicep Registry: [Scheduled actions for subscriptions](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/subscription-scheduled-action/README.md)
- Bicep Registry: [Scheduled actions for resource groups](https://github.com/Azure/bicep-registry-modules/tree/main/modules/cost/resourcegroup-scheduled-action/README.md)
- [ScheduledActions API reference](/rest/api/cost-management/scheduled-actions)

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Anomaly management](../../framework/understand/anomalies.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)

<br>
