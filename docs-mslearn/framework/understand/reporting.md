---
title: Reporting and analytics
description: This article helps you understand the reporting and analytics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the reporting and analytics capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Reporting and analytics

This article helps you understand the reporting and analytics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Reporting and analytics refers to the analysis of cloud data and creation of reports to gain insights into usage and spend patterns, identify opportunities for improvement, and support informed decision-making about cloud resources.**

Provides transparency and visibility into cloud usage and costs across different departments, teams, and projects. Organizational alignment requires cost allocation metadata and hierarchies, and enabling visibility requires structured access control against these hierarchies.

Reporting and analytics require a deep understanding of organizational needs to provide an appropriate level of detail to each stakeholder. Consider the following points:

- Level of knowledge and experience each stakeholder has
- Different types of reporting and analytics you can provide
- Assistance they need to answer their questions

With the right tools, Reporting and analytics enable stakeholders to understand how resources are used, track cost trends, and make informed decisions regarding resource allocation, optimization, and budget planning.

<br>

## When to prioritize

Reporting and analytics are a common part of your iterative process. Some examples of when you want to prioritize Reporting and analytics include:

- New datasets become available, which need to be prepared for stakeholders.
- New requirements are raised to add or update reports.
- Adoption of a multicloud environment and the need of having a single report to access cross-cloud information.
- Implementing more cost visibility measures to drive awareness.

If you're new to FinOps, we recommend starting with reporting and analytics using native cloud tools as you learn more about the data and the specific needs of your stakeholders. You revisit this capability again as you adopt new tools and datasets. Data could be ingested into a custom data store or used by a third-party solution from the Marketplace.

<br>

## Before you begin

Before you can effectively analyze usage and costs, you need to familiarize yourself with [how you're charged for the services you use](https://azure.microsoft.com/pricing#product-pricing). Understanding the factors that contribute to costs such as compute, storage, networking, data transfer, or executions helps you understand what you ultimately get billed. Understanding how your service usage aligns with the various pricing models also helps you understand what you get billed. These patterns vary between services, which can result in unexpected charges if you don't fully understand how you're charged and how you can stop billing.

> [!NOTE]
> _For example, many people understand "VMs are not billed when they're not running." However, this is only partially true. There's a slight nuance for VMs where a "stopped" VM _will_ continue to charge you, because the cloud provider is still reserving that capacity for you. To stop billing, you must "deallocate" the VM. But you also need to remember that compute time isn't the only charge for a VM – you're also charged for network bandwidth, disk storage, and other connected resources. In the simplest example, a deallocated VM will always charge you for disk storage, even if the VM is not running. Depending on what other services you have connected, there could be other charges as well. This is why it's important to understand how the services and features you use will charge you._

We also recommend learning about [how cost data is tracked, stored, and refreshed in Microsoft Cost Management](/azure/cost-management-billing/costs/understand-cost-mgt-data). Some examples include:

- Which subscription types (or offers) are supported. For instance, data for classic CSP and sponsorship subscriptions isn't available in Cost Management and must be obtained from other data sources.
- Which charges are included. For instance, taxes aren't included.
- How tags get used and tracked. For instance, some resources don't support tags and [tag inheritance](/azure/cost-management-billing/costs/enable-tag-inheritance) must be enabled manually to inherit tags from subscriptions and resource groups.
- When to use "actual" and "amortized" cost.
  - "Actual" cost shows charges as they were or as they're shown on the invoice. Use actual costs for invoice reconciliation.
  - "Amortized" cost shows the effective cost of resources that used a commitment-based discount (reservation or savings plan). Use amortized costs for cost allocation, to "smooth out" large purchases that might look like usage spikes, and numerous commitment-based discount scenarios.
- How credits are applied. For instance, credits are applied when the invoice is generated and not when usage is tracked.

Understanding your cost data is critical to enable accurate and meaningful showback to all stakeholders.

Consider using the [FinOps Open Cost & Usage Specification (FOCUS) project](../../focus/what-is-focus.md) as the standard billing schema for your report if you need to report from multiple sources, such as:

- Various cloud providers
- Configuration management databases (CMDB)
- IT asset management (ITAM) systems

<br>

## Getting started

When you first start managing cost in the cloud, you use the native tools:

- [Cost analysis](/azure/cost-management-billing/costs/quick-acm-cost-analysis) helps you explore and get quick answers about your costs.
- [Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) helps you build advanced reports merged with other cloud or business data.
- [Billing](/azure/cost-management-billing/manage/) helps you review invoices and manage credits.
- [Azure Monitor](/azure/azure-monitor/overview) helps you analyze resource usage metrics, logs, and traces.
- [Azure Resource Graph](/azure/governance/resource-graph/overview) helps you explore resource configuration, changes, and relationships.

As a starting point, we focus on tools available in the Azure portal and Microsoft 365 admin center.

- Familiarize yourself with the [built-in views in Cost analysis](/azure/cost-management-billing/costs/cost-analysis-built-in-views), concentrate on your top cost contributors, and drill in to understand what factors are contributing to that cost.
  - Use the Services view to understand the larger services (not individual cloud resources) that were purchased or are being used within your environment. This view provides stakeholders with a broad overview of resource usage, even if they aren't familiar with the technical specifics of how each resource supports business objectives.
  - Use the Subscriptions and Resource groups views to identify which departments, teams, or projects are incurring the highest cost, based on how you organized your resources.
  - Use the Resources view to identify which deployed resources are incurring the highest cost.
  - Use the Reservations view to review utilization for a billing account or billing profile or to break down usage to the individual resources that received the reservation discount.
  - Always use the view designed to answer your question. Avoid using the most detailed view to answer all questions, as it's slower and requires more work to find the answer you need.
  - Use drilldown, filtering, and grouping to narrow down to the data you need, including the cost meters of an individual resource.
- [Save and share customized views](/azure/cost-management-billing/costs/save-share-views) to revisit them later, collaborate with stakeholders, and drive awareness of current costs.
  - Use private views for yourself and shared views for others to see and manage.
  - Pin views to the Azure portal dashboard to create a heads-up display when you sign into the portal.
  - To provide quick access from external emails, documents, and other information, download an image of the chart and copy a link to the view. Note recipients are required to sign in and have access to the cost data.
  - Download summarized data to share with others who don't have direct access.
  - Subscribe to scheduled alerts to send emails with a chart and/or data to stakeholders on a daily, weekly, or monthly basis.
- As you review costs, make note of questions that you can't answer with the raw cloud usage and cost data. To ensure more metadata is added via tags and labels, feed this back into your cost allocation strategy.
- Use the different tools optimized to provide the details you need to understand the holistic picture of your resource cost and usage.
  - [Analyze resource usage metrics in Azure Monitor](/azure/azure-monitor/essentials/tutorial-metrics).
  - [Review resource configuration changes in Azure Resource Graph](/azure/governance/resource-graph/how-to/get-resource-changes).
- If you need to build more advanced reports or merge cost data with other cloud or business data, [use the FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md).

<br>

## Building on the basics

At this point, you're likely utilizing the native reporting and analysis solutions in the portal and possibly started building advanced reports in Power BI. As you move beyond the basics, consider the following to help you scale your reporting and analysis capabilities:

- Talk to your stakeholders to ensure you have a firm understanding of their end goals.
  - Differentiate between "tasks" and "goals." Tasks are performed to accomplish goals and will change as technology and our use of it evolves, while goals are more consistent over time.
  - Think about what they'll do after you give them the data. Can you help them achieve that through automation or providing links to other tools or reports? How can they rationalize cost data against other business metrics (the benefits their resources are providing)?
  - Do you have all the data you need to facilitate their goals? If not, consider ingesting other datasets to streamline their workflow. Adding other datasets is a common reason for moving from in-portal reporting into a custom or third-party solution to support other datasets.
- Consider reporting needs of each capability. Some examples include:
  - Cost breakdowns aligned to cost allocation metadata and hierarchies.
  - Optimization reports tuned to specific services and pricing models.
  - Commitment-based discount utilization, coverage, savings, and chargeback.
  - Reports to track and drill into KPIs across each capability.
- How can you make your reporting and KPIs an inherent part of day-to-day business and operations?
  - Promote dashboards and KPIs at recurring meetings and reviews.
  - Consider both bottom-up and top-down approaches to drive FinOps through data.
  - Use alerting systems and collaboration tools to raise awareness of costs on a recurring basis.
- Regularly evaluate the quality of the data and reports.
  - Consider introducing a feedback mechanism to learn how stakeholders are using reports and when they can't or aren't meeting their needs. Use it as a KPI for your reports.
  - Focus heavily on data quality and consistency. Many issues surfaced within the reporting tools are result from the underlying data ingestion, normalization, and cost allocation processes. Channel the feedback to the right stakeholders and raise awareness of and resolve issues that are impacting end-to-end cost visibility, accountability, and optimization.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Reporting and analytics capability](https://www.finops.org/framework/capabilities/reporting-analytics/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/CVTJLdcozj1eEpxT?list=PLUSCToibAswlDSQdehKhi7ysP2hmetigl]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.12/bladeName/Guide.Framework/featureName/Capabilities.Understand.Reporting)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Forecasting](../quantify/forecasting.md)
- [Anomaly management](./anomalies.md)
- [Budgeting](../quantify/budgeting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Billing](/azure/cost-management-billing/manage/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)
- [FinOps workbooks](../../toolkit/workbooks/finops-workbooks-overview.md)
- [FinOps toolkit bicep modules](../../toolkit/bicep-registry/modules.md)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)

<br>
