---
title: FinOps tools and services
description: This article helps you understand the FinOps tools and services capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the FinOps tools and services capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps tools and services

This article helps you understand the FinOps tools and services capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**FinOps tools and services encapsulates identifying, configuring, and integrating tools and services that meet the needs of FinOps capabilities and enable the FinOps practice at scale throughout the organization.**

Define selection criteria that maps to organizational needs and objectives and select the tools and services that complement each other and offer the best coverage. To maximize your return on investment (ROI), prefer tools and services that can integrate easily with existing tools and processes.

Implement and test tools and services to validate hypotheses before scaling efforts out to the rest of the organization. Track adoption as part of your assessment and maturity efforts. Periodically review selection criteria to ensure tools and services continue to meet the targeted objectives.

<br>

## Before you begin

To clarify terminology, a FinOps "tool" is a software solution that facilitates one or more FinOps capabilities, while a FinOps "service" refers to expert guidance delivered through means such as training, consulting, or even outsourcing. FinOps tools and services are a critical part of any FinOps practice and can be pivotal when aligning cloud spending with business objectives or ensuring efficient and cost-effective cloud operations.

<br>

## Getting started

When you first start managing cost in the cloud, you use the native tools available in the portal, including but not limited to:

- **Microsoft Cost Management**: A suite of tools designed to help organizations monitor, allocate, and optimize their cloud costs within the Microsoft Cloud.
- **Azure Advisor**: Follow best practices to optimize your Microsoft Cloud deployments.  
- **Pricing Calculator**: Helps you configure and estimate the costs for Azure products and features based on specific scenarios.  

If you're migrating on-premises infrastructure to the cloud, you might also be interested in:

- **Azure Migrate**: Discover, migrate, and modernize on-premises infrastructure. Estimate the cost savings achievable by migrating your application to Microsoft Cloud.

As you dig deeper into optimization and governance, you start to use:

- **Azure Monitor**: Monitoring solution that collects, analyzes, and responds to monitoring data from cloud and on-premises environments.
- **Azure Resource Graph**: Powerful management tool to query, explore, and analyze your cloud resources at scale.
- **Azure Resource Manager**: Deploy and manage resources and applications via API or declarative templates.
- **Azure Hybrid Benefit**: A benefit that lets you reduce the costs of your licenses with Software Assurance.  
- **Azure Reservations**: A commitment discount that helps you save money by committing to one-year or three-year plans for multiple products.  
- **Azure Savings Plan for Compute**: A pricing model that offers discounts on compute services when you commit to a fixed hourly amount for one or three years.


Once you have a consolidated list of the Microsoft, third-party, and homegrown tools and services available:

- Map tools and services to organizational objectives.
- Identify which tools are used by different teams and stakeholders.
- Investigate options to extend current tools and services, like the [FinOps toolkit](../../toolkit/finops-toolkit-overview.md).
<br>

## Building on the basics

At this point, you defined your organizational objectives, identified how current tools and services meet them, and hopefully identified any limitations and gaps. As you move beyond the basics, you focus on establishing a plan to address limitations and gaps or opportunities to go beyond your basic requirements to further maximize cloud ROI through new opportunities made available via new or existing tools and services.

- Evaluate existing tools and services and establish a plan to address any limitations and gaps.
  - Automate tasks with [PowerShell commands](../../toolkit/powershell/powershell-commands.md) and [Bicep modules](../../toolkit/bicep-registry/modules.md).
  - Consider lightweight tools for engineers, like the [FinOps workbooks](../../toolkit/workbooks/finops-workbooks-overview.md) workbooks.
  - If you're looking for an extensible platform for reporting and analytics, check out [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md) and connect to your hub from Microsoft Fabric to go even further.
- Document the key processes around the tools and services available to teams.
  - Include when to use and how to get started with each.
  - Set expectations around any costs, if applicable.
- Seek to standardize processes and maximize adoption.
- Periodically assess progress towards organizational objectives to ensure tools and services are achieving their desired results.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [FinOps tools and services](https://www.finops.org/framework/capabilities/finops-tools-services/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/I4nRDraHaJc?list=PLUSCToibAswnrMcPgpshJr-10XDwD0E0i]

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.Framework/featureName/Capabilities.Manage.ToolsAndServices)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [FinOps practice operations](./operations.md)
- [FinOps assessment](./assessment.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Monitor](/azure/azure-monitor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Policy](/azure/governance/policy/)

Related solutions:

- [FinOps toolkit Power BI reports](../../toolkit/power-bi/reports.md)
- [FinOps hubs](../../toolkit/hubs/finops-hubs-overview.md)
- [Cost optimization workbook](../../toolkit/workbooks/optimization.md)
- [Governance workbook](../../toolkit/workbooks/governance.md)
- [FinOps toolkit PowerShell module](../../toolkit/powershell/powershell-commands.md)
- [FinOps toolkit bicep modules](../../toolkit/bicep-registry/modules.md)

<br>
