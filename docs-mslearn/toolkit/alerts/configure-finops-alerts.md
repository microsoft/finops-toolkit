---
title: Configure FinOps alerts 
description: Learn how to configure and customize FinOps alerts to perform notifications and actions based on your organizational needs.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: robelmamecha
#customer intent: As a FinOps practitioner, I want to deploy FinOps alerts to detect idle resources.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure FinOps alerts

FinOps alerts is an automated and proactive cost optimization tool built on Azure Logic Apps. It continuously scans your Azure environment for idle resources and sends notifications to help you take timely action. This solution empowers FinOps practitioners to better manage cloud spending while minimizing waste in the environment.

<br>

## Overview

To configure FinOps alerts, follow these steps:

1. **Deploy FinOps alerts**

   > [!div class="nextstepaction"]
   > [Deploy to Azure](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json)
   >
   > [!div class="nextstepaction"]
   > [Deploy to Azure Gov](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json)
   >
   > [!div class="nextstepaction"]
   > [Deploy to Azure China](https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-alerts-latest.ui.json)
  
2. **Authorize API connection**

    > [!NOTE]
    > After deployment, the Logic app will show a failed run this is due to the API connection, this is a temporary state until authorization is complete.

   1. Select the **API connection** resource, then select **Edit API   Connection** in the General tab to authorize the connection. Once you enable connection select **Save**.

    :::image type="content" source="./media/configure-finops-alerts/authorize-api-connection.png" alt-text="Screenshot of the edit form for API connections." lightbox="./media/configure-finops-alerts/authorize-api-connection.png" :::

3. **Assigning reader permission**

    1. The Logic App’s system-assigned identity must have the **Reader** role on the targeted subscriptions. This role enables it to query resource utilization data. Follow [these steps](/azure/role-based-access-control/role-assignments-portal-managed-identity#system-assigned-managed-identity) to assign the reader role.

        1. For environments that span multiple subscriptions, consider assigning the Reader role at the management group level to streamline permissions management and ensure comprehensive monitoring.

4. **Configuring the Logic App**

    1. Within the Logic App designer adjust the recurrence setting (defaulting to 1 week) based on your monitoring needs.
  
    2. Configure details such as the email subject, alert recipients, and filter which subscription IDs should be included or excluded. This level of customization allows you to tailor the monitoring to your specific cloud environment and cost optimization strategy.

    3. If needed, further modify the Logic App’s workflow such as conditions, thresholds, and notification channels to align with your organization’s requirements.

5. **Testing and validation**

    1. After completing the setup, run the Logic App to ensure it correctly identifies idle resources and triggers the appropriate notifications.

    2. Analyze test results to adjust thresholds or alert parameters as necessary.

<br>

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
