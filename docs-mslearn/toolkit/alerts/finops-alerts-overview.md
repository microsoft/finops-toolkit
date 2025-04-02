---
title: FinOps alerts overview
description: FinOps alerts will accelerate your cost optimization efforts with scheduled notifications that continuously monitor your cloud environment, empowering you to make informed decisions without the hassle.
author: bandersmsft
ms.author: banders
ms.date: 02/18/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: robelmamecha
#customer intent: As a FinOps practitioner, I need to learn about FinOps alerts.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps alerts

FinOps alerts is an automated and proactive cost optimization tool built on Azure Logic Apps. It continuously scans your Azure environment for idle resources and sends notifications to help you take timely action. This solution empowers FinOps practitioners to better manage cloud spending while minimizing waste in the environment.

## How it works

FinOps alerts leverages Azure Logic Apps to automate detection of waste across selected subscriptions:

- **Automated resource monitoring** <br> FinOps alerts runs on a configurable schedule to assess resource activity. It inspects various resource properties to identify idle resources that might be leading to unnecessary costs.

- **Automated notifications** <br> Upon detecting idle resources, the Logic App triggers notifications—via email or other integrated channels to designated administrators, ensuring that the right stakeholders are alerted promptly to review and to take action.

- **Flexibility** <br> Users can tailor key parameters, including the recurrence interval, alert recipients, and the specific subscriptions to monitor. This makes the tool adaptable to a wide range of cloud environments.

## Benefits

- By automating the detection of idle resources, FinOps alerts helps you preemptively address inefficient spending, ensuring that cloud costs remain under control.

- Designed to operate seamlessly across single or multi-subscription environments.

## Why FinOps alerts?

If you are using the [FinOps workbook](/finops/toolkit/workbooks/finops-workbooks-overview) to identify idle or underutilized resources, you'll notice it doesn’t provide any automatic alerts-meaning engineers must continually check back to review flagged items. FinOps alerts automates this process, ensuring that when resources are identified as potentially inefficient, stakeholders receive timely notifications without having to manually monitor a workbook. This not only frees up valuable time for busy teams but also improves the chances of catching cost-saving opportunities as they arise. Moreover, future releases of the app are planned to include additional queries, broadening its scope and further enhancing its ability to deliver actionable insights for sustainable cloud cost management.

## Required permissions

Deploying FinOps alerts template requires one of the following:

- For least-privileged access, [Contributor](/azure/role-based-access-control/built-in-roles#contributor) and [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator)
- [Owner](/azure/role-based-access-control/built-in-roles#owner)

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20alerts%3F/cvaQuestion/How%20valuable%20are%20FinOps%20alerts%3F/surveyId/FTK0.9/bladeName/Alerts/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20alerts%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Azure Logic Apps](/azure/azure-logic-apps/)

Related solutions:

- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
  
<br>
