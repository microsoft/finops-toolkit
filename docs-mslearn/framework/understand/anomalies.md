---
title: Anomaly management
description: This article helps you understand the anomaly management capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the anomaly management capability so that I can implement it in the Microsoft Cloud.
---


<!-- markdownlint-disable-next-line MD025 -->
# Anomaly management

This article helps you understand the anomaly management capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Anomaly management refers to the practice of detecting and addressing abnormal or unexpected cost and usage patterns in a timely manner.**

Use automated tools to detect anomalies and notify stakeholders. Review usage trends periodically to reveal anomalies that automated tools might miss.

To uncover the root cause of the anomaly, investigate changes in application behaviors, resource utilization, and resource configuration.

With a systematic approach to anomaly detection, analysis, and resolution, organizations can minimize unexpected costs that impact budgets and business operations. And, they can even identify and prevent security and reliability incidents that can surface in cost data.

<br>

## Getting started

When you first start managing cost in the cloud, you use the native tools available in the portal.

- Start with proactive alerts.
  - [Subscribe to anomaly alerts](/azure/cost-management-billing/understand/analyze-unexpected-charges#create-an-anomaly-alert) for each subscription in your environment to receive email alerts when an unusual spike or drop is detected in your normalized usage based on historical usage.
  - Consider [subscribing to scheduled alerts](/azure/cost-management-billing/costs/save-share-views#subscribe-to-scheduled-alerts) to share a chart of the recent cost trends with stakeholders. It can help you drive awareness as costs change over time and potentially catch changes the anomaly model might miss.
  - To track that specific scope or workload, consider [creating a budget in Cost Management](/azure/cost-management-billing/costs/tutorial-acm-create-budgets). Specify filters and set alerts for both actual and forecast costs for finer-grained targeting.
- Review costs periodically, using detailed cost breakdowns, usage analytics, and visualizations to identify potential anomalies that might get missed.
  - Use smart views in Cost analysis to [review anomaly insights](/azure/cost-management-billing/understand/analyze-unexpected-charges#identify-cost-anomalies) that were automatically detected for each subscription.
  - Use customizable views in Cost analysis to [manually find unexpected changes](/azure/cost-management-billing/understand/analyze-unexpected-charges#manually-find-unexpected-cost-changes).
  - Consider [saving custom views](/azure/cost-management-billing/costs/save-share-views) that show cost over time for specific workloads to save time.
  - Consider creating more detailed usage reports using [Power BI](../../toolkit/power-bi/reports.md).
- Once an anomaly is identified, take appropriate actions to address it.
  - Review the anomaly details with the engineers who manage the related cloud resources. Some auto-detected "anomalies" are planned or at least known resource configuration changes as part of building and managing cloud services.
  - If you need lower-level usage details, review resource utilization in [Azure Monitor metrics](/azure/azure-monitor/essentials/metrics-getting-started).
  - If you need resource details, review [resource configuration changes in Azure Resource Graph](/azure/governance/resource-graph/how-to/get-resource-changes).

<br>

## Building on the basics

At this point, you have automated alerts configured and ideally views and reports saved to streamline periodic checks.

- Establish and automate KPIs, such as:
  - Number of anomalies each month or quarter.
  - Total cost impact of anomalies each month or quarter
  - Response time to detect and resolve anomalies.
  - Number of false positives and false negatives.
- Expand coverage of your anomaly detection and response process to include all costs.
- Define, document, and automate workflows to guide the response process when anomalies are detected.
- Foster a culture of continuous learning, innovation, and collaboration.
  - Regularly review and refine anomaly management processes based on feedback, industry best practices, and emerging technologies.
  - Promote knowledge sharing and cross-functional collaboration to drive continuous improvement in anomaly detection and response capabilities.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Anomaly management capability](https://www.finops.org/framework/capabilities/anomaly-management) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/nhPcLxbdv98?list=PLUSCToibAswl7gsq9Zt4sol0Dp3ibfl1L]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.Framework/featureName/Capabilities.Understand.Anomalies)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Budgeting](../quantify/budgeting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [FinOps toolkit bicep modules](../../toolkit/bicep-registry/modules.md)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)

<br>
