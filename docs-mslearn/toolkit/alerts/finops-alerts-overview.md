---
title: FinOps alerts overview
description: FinOps alerts accelerate cost optimization efforts with scheduled notifications that continuously monitor your cloud environment.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: robelmamecha
#customer intent: As a FinOps practitioner, I need to learn about FinOps alerts.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps alerts

FinOps alerts automate the identification of cost optimization opportunities using Azure Logic Apps for notifications and custom actions. It continuously scans your Azure environment for idle resources and sends notifications to help you take timely action. This solution empowers FinOps practitioners to better manage cloud spending while minimizing waste in the environment.

## How it works

FinOps alerts uses Azure Logic Apps to automate detection of waste across selected subscriptions:

- **Automated resource monitoring** <br> FinOps alerts run on a configurable schedule to assess resource activity. It inspects various resource properties to identify idle resources that might be leading to unnecessary costs.

- **Automated notifications** <br> When idle resources are detected, the Logic App triggers notifications—via email or other integrated channels to designated administrators, ensuring that the right stakeholders are alerted promptly to review and to take action.

- **Flexibility** <br> Users can tailor key parameters, including the recurrence interval, alert recipients, and the specific subscriptions to monitor. This makes the tool adaptable to a wide range of cloud environments.

## Benefits

FinOps alerts helps you preemptively address inefficient spending by automating the detection of idle resources, ensuring that cloud costs remain under control. FinOps alerts are designed to operate seamlessly across single and multi-subscription environments.

## Why FinOps alerts?

If you use [FinOps workbooks](../workbooks/finops-workbooks-overview.md) to identify idle or underutilized resources, engineers must continually review flagged items. FinOps alerts automate this process, ensuring that when resources are identified as potentially inefficient and stakeholders receive timely notifications without having to manually monitor a workbook. FinOps alerts free up valuable time for busy teams and helps catch cost-saving opportunities as they arise.

## Required permissions

Deploying FinOps alerts requires access to create logic apps, assign access, and read resource metadata. You can use the [Owner](/azure/role-based-access-control/built-in-roles#owner) role or, for least-privileged access, use [Contributor](/azure/role-based-access-control/built-in-roles#contributor) and [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) roles.

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20alerts%3F/cvaQuestion/How%20valuable%20are%20FinOps%20alerts%3F/surveyId/FTK0.10/bladeName/Alerts/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20alerts%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Logic Apps](/azure/logic-apps/)

Related solutions:

- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
  
<br>
