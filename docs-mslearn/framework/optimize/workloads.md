---
title: Workloads
description: This article helps you understand the Workload optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 07/14/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the workload optimization capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Workload optimization

This article helps you understand the Workload optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Workload optimization refers to the process of ensuring cloud services are utilized and tuned to maximize business value and minimize wasteful usage and spending.**

Review how services are being used and ensure each is maximizing return on investment. Evaluate and implement best practices and recommendations.

Every cost should have direct or indirect traceability back to business value. Eliminate fully "optimized" resources that aren't contributing to business value.

Review resource usage patterns and determine if they can be scaled down or even shutdown (to stop billing) during off-peak hours. Consider cheaper alternatives to reduce costs. Avoid unnecessary usage and costs that don't contribute to the mission, which in turn increases return on investment and profitability.

<br>

## Getting started

When you first start working with a service or managing costs in the cloud, prioritize leveraging native tools within the portal to drive efficiency and optimize costs.

- Review and implement [Cloud Adoption Framework costing best practices](/azure/cloud-adoption-framework/govern/cost-management/best-practices.md).
- Review and implement [Azure Well-Architected Framework cost optimization guidance](/azure/well-architected/cost/overview.md).
- Review and implement [Azure Advisor cost recommendations](/azure/advisor/advisor-reference-cost-recommendations.md).
  - Azure Advisor gives you high-confidence recommendations based on your usage. Azure Advisor is always the best place to start when looking to optimize any workload.
  - Consider [subscribing to Azure Advisor alerts](/azure/advisor/advisor-alerts-portal.md) to get notified when there are new cost recommendations.
- Review your usage and purchase [commitment discounts](./rates.md) when it makes sense.
- Take advantage of Azure Hybrid Benefit for [Windows](/windows-server/get-started/azure-hybrid-benefit.md), [Linux](/azure/virtual-machines/linux/azure-hybrid-benefit-linux.md), and [SQL Server](/azure/azure-sql/azure-hybrid-benefit.md).
- Familiarize yourself with the services you use, how you're charged, and what service-specific cost optimization options you have.
  - You can discover the services you use from the Azure portal All resources page or from the [Services view in Cost analysis](/azure/cost-management-billing/costs/cost-analysis-built-in-views.md#break-down-product-and-service-costs).
  - Explore the [Azure pricing pages](https://azure.microsoft.com/pricing) and [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) to learn how each service charges you. Use them to identify options that might reduce costs. For example, shared infrastructure and commitment discounts.
  - Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
    - Choose [spot VMs](/azure/well-architected/cost/optimize-vm.md#spot-vms) for low priority, interruptible workloads.
    - Avoid [cross-region data transfer](/azure/well-architected/cost/design-regions.md#traffic-across-billing-zones-and-regions).
- Determine if services can be paused or stopped to stop incurring charges.
  - Some services support autostop natively, like [Microsoft Dev Box](/azure/dev-box/how-to-configure-stop-schedule.md), [Azure DevTest Labs](/azure/devtest-labs/devtest-lab-auto-shutdown.md), [Azure Lab Services](/azure/lab-services/how-to-configure-auto-shutdown-lab-plans.md), and [Azure Load Testing](/azure/load-testing/how-to-define-test-criteria#auto-stop-configuration.md).
  - If you use a service that supports being stopped, but not autostopping, consider using a lightweight flow in [Power Automate](/power-automate/getting-started.md) or [Logic Apps](/azure/logic-apps/logic-apps-overview.md).
  - If the service can't be stopped, review alternatives to determine if there are any options that can be stopped to stop billing.
  - Pay close attention to noncompute charges that might continue to be billed when a resource is stopped so you're not surprised. Storage is a common example of a cost that continues to be charged even if a compute resource that was using the storage is no longer running.
- Does the service support serverless compute?
  - Serverless compute tiers can reduce costs when not active. Some examples: [Azure SQL Database](/azure/azure-sql/database/serverless-tier-overview.md), [Azure SignalR Service](/azure/azure-signalr/concept-service-mode.md), [Cosmos DB](/azure/cosmos-db/serverless.md), [Synapse Analytics](/azure/synapse-analytics/sql/on-demand-workspace-overview.md), [Azure Databricks](/azure/databricks/serverless-compute/.md).
- Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
  - Choose [spot VMs](/azure/well-architected/cost/optimize-vm.md#spot-vms) for low priority, interruptible workloads.
  - Avoid [cross-region data transfer](/azure/well-architected/cost/design-regions.md#traffic-across-billing-zones-and-regions).
- Determine if services support autoscaling.
  - If the service supports [autoscaling](/azure/architecture/best-practices/auto-scaling.md), configure it to scale based on your application's needs.
  - Autoscaling can work with autostop behavior for maximum efficiency.
- Consider automatically stopping and manually starting nonproduction resources during work hours to avoid unnecessary costs.
  - Avoid automatically starting nonproduction resources that aren't used every day.
  - If you choose to autostart, be aware of vacations and holidays where resources may get started automatically but not be used.
  - Consider tagging manually stopped resources. [Save a query in Azure Resource Graph](/azure/governance/resource-graph/first-query-portal.md) or a view in the All resources list and pin it to the Azure portal dashboard to ensure all resources are stopped.
- Consider architectural models such as containers and serverless to only use resources when they're needed, and to drive maximum efficiency in key services.
- Levarage the [Cost optimization workbook](../../../toolkit/optimization-workbook/cost-optimization-workbook.md) to evaluate resource utilization, like idle and unused resources.

<br>

## 🏗️ Building on the basics

At this point, you've implemented all the basic cost optimization recommendations and tuned applications to meet the most fundamental best practices. As you move beyond the basics, consider the following points:

- Automate cost recommendations using [Azure Resource Graph](/azure/advisor/resource-graph-samples.md)
- Stay abreast of emerging technologies, tools, and industry best practices to further optimize resource utilization.
- Automate the process of automatically scaling or stopping resources that don't support it or have more complex requirements.
  - Consider using automation services, like [Azure Automation](/azure/automation/automation-solution-vm-management.md) or [Azure Functions](/azure/azure-functions/start-stop-vms/overview.md).
- [Assign an "Env" or Environment tag](/azure/azure-resource-manager/management/tag-resources.md) to identify which resources are for development, testing, staging, production, etc.
  - Prefer assigning tags at a subscription or resource group level. Then enable the [tag inheritance policy for Azure Policy](/azure/governance/policy/samples/built-in-policies#tags.md) and [Cost Management tag inheritance](/azure/cost-management-billing/costs/enable-tag-inheritance.md) to cover resources that don't emit tags with usage data.
  - Consider setting up automated scripts to stop resources with specific up-time profiles (for example, stop developer VMs during off-peak hours if they weren't used in 2 hours).
  - Document up-time expectations based on specific tag values and what happens when the tag isn't present.
  - [Use Azure Policy to track compliance](/azure/governance/policy/how-to/get-compliance-data.md) with the tag policy.
  - Use Azure Policy to enforce specific configuration rules based on environment.
  - Consider using "override" tags to bypass the standard policy when needed. To ensure accountability, track the cost and report them to stakeholders.
- Consider establishing and tracking KPIs for low-priority workloads, like development servers.
- Consider deploying other tools to help you optimizing your environment, for example the [Azure Optimization Engine]() available on FinOps toolkit provided by Microsoft.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Workload optimization capability](https://www.finops.org/framework/capabilities/workload-optimization/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/Fjp0Y9lOaXphvBc0?list=PLUSCToibAswnEoBY6zl_1bpIAqbdIDxUW]

<br>

## Related content

Related FinOps capabilities:

- [Rate optimization](./rates.md)
- [Cloud policy and governance](../manage/policy.md)

Related products:

- [Azure Advisor](/azure/advisor/)
- [Azure Monitor](/azure/azure-monitor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)
- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Policy](/azure/governance/policy/)

Related solutions:

- [Cost optimization workbook](../../toolkit/optimization-workbook/cost-optimization-workbook.md)
- [Governance workbook](https://microsoft.github.io/finops-toolkit/governance-workbook)
- [FinOps toolkit Power BI reports](https://aka.ms/ftk/pbi)
- [FinOps hubs](https://aka.ms/finops/hubs)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)

<br>