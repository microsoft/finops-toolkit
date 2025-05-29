---
title: Allocation
description: This article helps you understand the Allocation capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the allocation capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Allocation

This article helps you understand the allocation capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Allocation refers to the process of attributing, assigning, and redistributing shared cost and usage using accounts, tags, and other metadata to establish accountability among teams and projects within an organization.**

Identify the most critical attributes to report against based on stakeholder needs. Consider the different reporting structures within the organization and how you'll handle change over time. Consider engineering practices that might introduce different types of cost that need to be analyzed independently.

Establish and maintain a mapping of cloud and on-premises costs to each attribute and apply governance policies to ensure data is appropriately tagged in advance. Define a process for how to handle tagging gaps and misses.

Review shared cost and usage and develop an allocation plan with rules and methods for dividing the shared costs fairly and equitably. Track and report shared cost and usage and their allocation to the relevant stakeholders. Regularly review and update allocation plan to ensure it remains accurate and fair.

Allocation is the foundational element of accountability and enables organizations to gain visibility into the impact of their cloud solutions and related activities and initiatives. Effectively managing shared costs and usage as part of your allocation strategy reduces overhead, increases transparency and accountability, and aligns cloud costs and usage with business value. This approach maximizes efficiencies and cost savings from shared services.

<br>

## Before you begin

Before you start, it's important to have a clear understanding of your organization's goals and priorities when it comes to allocation. Keep in mind that not all shared costs might need to be redistributed, and some are more effectively managed with other means. Carefully evaluate each shared cost to determine the most appropriate approach for your organization.

This guide doesn't cover commitment discounts, like reservations and savings plans. For details about how to handle showback and chargeback, refer to [Rate optimization](../optimize/rates.md).

<br>

## Getting started

When you first start managing cost in the cloud, you use the native allocation tools to organize subscriptions and resources to align to your primary organizational reporting structure. For anything beyond it, [tags](/azure/azure-resource-manager/management/tag-resources) can augment cloud resources and their usage to add business context, which is critical for any allocation strategy.

Allocation is usually an afterthought and requires some level of cleanup when introduced. You need a plan to implement your allocation strategy. We recommend outlining that plan first to get alignment and possibly prototyping on a small scale to demonstrate the value. Consider whether to include shared costs from services shared by multiple products or teams. Managing shared costs can be complex and many organizations start without it. Identify shared costs and establish a prioritized plan for how they should be handled.

- Decide how you want to manage access to the cloud.
  - At what level in the organization do you want to centrally provision access to the cloud: Departments, teams, projects, or applications? High levels require more governance and low levels require more management.
  - What [cloud scope](/azure/cost-management-billing/costs/understand-work-scopes) do you want to provision for this level?
    - Billing scopes are used for to organize costs between and within invoices.
    - [Management groups](/azure/governance/management-groups/overview) are used to organize costs for resource management. You can optimize management groups for policy assignment or organizational reporting.
    - Subscriptions provide engineers with the most flexibility to build the solutions they need but can also come with more management and governance requirements due to this freedom.
    - Resource groups enable engineers to deploy some solutions but might require more support when solutions require multiple resource groups or options to be enabled at the subscription level.
- Identify shared costs and how they should be handled.
  - Notify stakeholders that you're evaluating shared costs and request details about any known scenarios. Self-identification can save you significant time and effort.
- Review the services that were purchased and are getting used with the [Services view in Cost analysis](/azure/cost-management-billing/costs/cost-analysis-built-in-views#break-down-product-and-service-costs).
- Familiarize yourself with each service to determine if they're designed for and/or could be used for shared resources. A few examples of commonly shared services are:
  - Application hosting services, like Azure Kubernetes Service, Azure App Service, and Azure Virtual Desktop.
  - Observability tools, like Azure Monitor and Log Analytics.
  - Management and security tools, like Microsoft Defender for Cloud and DevTest Labs.
  - Networking services, like ExpressRoute.
  - Database services, like Cosmos DB and SQL databases.
  - Collaboration and productivity tools, like Microsoft 365.
- Contact stakeholders who are responsible for the potentially shared services. Make sure they understand if the shared services are shared and how costs are allocated today. If not accounted for, how allocation could or should be done.
- How do you want to use management groups?
  - Organize subscriptions into environment-based management groups to optimize for policy assignment. Management groups allow policy admins to manage policies at the top level but blocks the ability to perform cross-subscription reporting without an external solution, which increases your data analysis and showback efforts.
  - To optimize for organizational reporting, organize subscriptions into management groups based on the organizational hierarchy. Management groups allow leaders within the organization to view costs more naturally from the portal but requires policy admins to use tag-based policies, which increases policy and governance efforts. Also keep in mind you might have multiple organizational hierarchies and management groups only support one.
- [Define a comprehensive tagging strategy](/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging) that aligns with your organization's allocation objectives.
  - Consider the specific attributes that are relevant for cost attribution, such as:
    - How to map costs back to financial constructs, for example, cost center?
    - Can you map back to every level in the organizational hierarchy, for example, business unit, department, division, and team?
    - Who is accountable for the service, for example, business owner and engineering owner?
    - What effort does this map to, for example project and application?
    - What is the engineering purpose of this resource, for example, environment, component, and purpose?
  - Clearly communicate tagging guidelines to all stakeholders.
- Once defined, it's time to implement your allocation strategy.
  - Consider a top-down approach that prioritizes getting departmental costs in place before optimizing at the lowest project and environment level. You might want to implement it in phases, depending on how broad and deep your organization is.
  - Enable [tag inheritance in Cost Management](/azure/cost-management-billing/costs/enable-tag-inheritance) to copy subscription and resource group tags in cost data only. It doesn't change tags on your resources.
  - Use Azure Policy to [enforce your tagging strategy](/azure/azure-resource-manager/management/tag-policies), automate the application of tags at scale, and track compliance status. Use compliance as a KPI for your tagging strategy.
  - If you need to move costs between subscriptions, resource groups, or add or change tags, [configure allocation rules in Cost Management](/azure/cost-management-billing/costs/allocate-costs).
    - Contracted (on-demand) prices for reservations are currently not available in Cost Management when cost allocation is enabled. Keep that in mind before you enable Cost Management cost allocation. To quantify cost savings, you need to join cost and price datasets.
  - To view costs together in Cost analysis, consider [grouping related resources together with the "cm-resource-parent" tag](/azure/cost-management-billing/costs/group-filter#group-related-resources-in-the-resources-view).
  - Distribute responsibility for any remaining change to scale out and drive efficiencies.
  - Make note of any unallocated costs or costs that should be split but couldn't be. Consider the importance of full allocation compared to other efforts and prioritize accordingly. As a simple option, you might be able to split costs in your reporting layer.

Once all resources are tagged and/or organized into the appropriate resource groups and subscriptions, you can report against that data as part of [Data analysis and showback](./reporting.md).

Keep in mind that tagging takes time to apply, review, and clean up. Expect to go through multiple tagging cycles after everyone has visibility into the cost data. Many people don't realize there's a problem until they have visibility, which is why FinOps is so important.

<br>

## Building on the basics

At this point, you have an allocation strategy with detailed cloud management and tagging requirements. Tagging should be automatically enforced or at least tracked with compliance KPIs. As you move beyond the basics, consider the points:

- Fill any gaps unmet by native tools.
  - At a minimum, this gap requires reporting outside the portal, where tagging gaps can be merged with other data.
  - If tagging gaps need to be resolved directly in the data, you need to implement [Data ingestion](./ingestion.md).
- Consider other costs that aren't yet covered or might be tracked separately.
  - To align tagging implementations, strive to drive consistency across data sources. When not feasible, implement cleanup as part of [Data ingestion and normalization](./ingestion.md) or reallocate costs as part of your overarching allocation strategy.
- Notify stakeholders that you're evaluating shared costs and request details about any known scenarios. Self-identification can save you significant time and effort.
- Review the purchased services that are used with the [Services view in Cost analysis](/azure/cost-management-billing/costs/cost-analysis-built-in-views#break-down-product-and-service-costs).
- Familiarize yourself with each service to determine if they're designed for and/or could be used for shared resources. A few examples of commonly shared services are:
  - Application hosting services, like Azure Kubernetes Service, Azure App Service, and Azure Virtual Desktop.
  - Observability tools, like Azure Monitor and Log Analytics.
  - Management and security tools, like Microsoft Defender for Cloud and DevTest Labs.
  - Networking services, like ExpressRoute.
  - Database services, like Cosmos DB and SQL databases.
  - Collaboration and productivity tools, like Microsoft 365.
- Contact stakeholders who are responsible for the potentially shared services. Make sure they understand if the shared services are shared and how costs are allocated today. If not accounted for, how allocation could or should be done.
- Use [Cost allocation rules in Microsoft Cost Management](/azure/cost-management-billing/costs/allocate-costs) to redistribute shared costs based on static percentages or compute, network, or storage costs.
- Regularly review and refine your allocation rules to ensure they remain accurate and fair.
  - Consider this process as part of your reporting feedback loop. If your allocation strategy is falling short, the feedback you get might not be directly associated with allocation or metadata. It might instead be related to reporting. Watch out for this feedback and ensure the feedback is addressed at the most appropriate layer.
  - Ensure naming, metadata, and hierarchy requirements are being used consistently and effectively throughout your environment.
  - Consider other KPIs to track and monitor success of your allocation strategy.
- Establish and track common KPIs, like the percentage of unallocated shared costs.
- Use utilization data from [Azure Monitor metrics](/azure/azure-monitor/essentials/data-platform-metrics) where possible to understand service usage.
- Consider using application telemetry to quantify the distribution of shared costs. There's more information about it in [Unit economics](../quantify/unit-economics.md).
- Automate the process of identifying the percentage breakdown of shared costs and consider using cost allocation rules in Cost Management to redistribute the costs.
- Automate cost allocation rules to update their respective percentages based on changing usage patterns.
- Consider sharing targeted reporting about the distribution of shared costs with relevant stakeholders.
- Build a reporting process to raise awareness of and drive accountability for unallocated shared costs.
- Share guidance with stakeholders on how they can optimize shared costs.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Allocation capability](https://www.finops.org/framework/capabilities/allocation/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/IwVBmcaiY0M?list=PLUSCToibAswmQicVCOwicTWHGjB3ykikr&pp=iAQB]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.Framework/featureName/Capabilities.Understand.Allocation)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](./reporting.md)
- [Unit economics](../quantify/unit-economics.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management)
- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)

<br>
