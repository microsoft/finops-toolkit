---
layout: default
grand_parent: FinOps Framework
parent: Optimize
title: Workload management
permalink: /framework/capabilities/optimize/workloads
nav_order: 2
description: This article helps you understand the workload management and automation capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
"ms.author": banders
"ms.date": 06/23/2023
"ms.topic": conceptual
"ms.service": finops
"ms.reviewer": micflan
---

<span class="fs-9 d-block mb-4">Workload management and automation</span>
This article helps you understand the workload management and automation capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
{: .fs-6 .fw-300 }

<details open markdown="1">
    <summary class="fs-2 text-uppercase">On this page</summary>

- [Getting started](#getting-started)
- [Building on the basics](#building-on-the-basics)
- [Learn more at the FinOps Foundation](#learn-more-at-the-finops-foundation)
- [Next steps](#next-steps)

</details>

---

<a name="definition"></a>
**Workload management and automation refers to running resources only when necessary and at the level or capacity needed for the active workload.**
{: .fs-6 .fw-300 }

Tag resources based on their up-time requirements. Review resource usage patterns and determine if they can be scaled down or even shutdown (to stop billing) during off-peak hours. Consider cheaper alternatives to reduce costs.

An effective workload management and automation plan can significantly reduce costs by adjusting configuration to match supply to demand dynamically, ensuring the most effective utilization.

<br>

## Getting started

When you first start working with a service, consider the following points:

- Can the service be stopped (and if so, stop billing)?
  - If the service can't be stopped, review alternatives to determine if there are any options that can be stopped to stop billing.
  - Pay close attention to non-compute charges that may continue to be billed when a resource is stopped so you're not surprised. Storage is a common example of a cost that continues to be charged even if a compute resource that was using the storage is no longer running.
- Does the service support serverless compute?
  - Serverless compute tiers can reduce costs when not active. Some examples: [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/serverless-tier-overview), [Azure SignalR Service](https://learn.microsoft.com/azure/azure-signalr/concept-service-mode), [Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/serverless.md), [Synapse Analytics](https://learn.microsoft.com/azure///learn.microsoft.com/azure///learn.microsoft.com/azure/synapse-analytics/sql/on-demand-workspace-overview.md), [Azure Databricks](https://learn.microsoft.com/azure/databricks/serverless-compute/).
- Does the service support autostop or autoshutdown functionality?
  - Some services support autostop natively, like [Microsoft Dev Box](https://learn.microsoft.com/azure/dev-box/how-to-configure-stop-schedule.md), [Azure DevTest Labs](https://learn.microsoft.com/azure/devtest-labs/devtest-lab-auto-shutdown.md), [Azure Lab Services](https://learn.microsoft.com/azure/lab-services/how-to-configure-auto-shutdown-lab-plans.md), and [Azure Load Testing](https://learn.microsoft.com/azure/load-testing/how-to-define-test-criteria.md#auto-stop-configuration).
  - If you use a service that supports being stopped, but not autostopping, consider using a lightweight flow in [Power Automate](/power-automate/getting-started) or [Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview.md).
- Does the service support autoscaling?
  - If the service supports [autoscaling](https://learn.microsoft.com/azure/architecture/best-practices/auto-scaling), configure it to scale based on your application's needs.
  - Autoscaling can work with autostop behavior for maximum efficiency.
- Consider automatically stopping and manually starting nonproduction resources during work hours to avoid unnecessary costs.
  - Avoid automatically starting nonproduction resources that aren't used every day.
  - If you choose to autostart, be aware of vacations and holidays where resources may get started automatically but not be used.
  - Consider tagging manually stopped resources. [Save a query in Azure Resource Graph](https://learn.microsoft.com/azure/governance/resource-graph/first-query-portal.md) or a view in the All resources list and pin it to the Azure portal dashboard to ensure all resources are stopped.
- Consider architectural models such as containers and serverless to only use resources when they're needed, and to drive maximum efficiency in key services.

<br>

## Building on the basics

At this point, you have setup autoscaling and autostop behaviors. As you move beyond the basics, consider the following points:

- Automate the process of automatically scaling or stopping resources that don't support it or have more complex requirements.
  - Consider using automation services, like [Azure Automation](https://learn.microsoft.com/azure///learn.microsoft.com/azure/automation/automation-solution-vm-management.md) or [Azure Functions](https://learn.microsoft.com/azure/azure-functions/start-stop-vms/overview.md).
- [Assign an "Env" or Environment tag](https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources.md) to identify which resources are for development, testing, staging, production, etc.
  - Prefer assigning tags at a subscription or resource group level. Then enable the [tag inheritance policy for Azure Policy](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies.md#tags) and [Cost Management tag inheritance](https://learn.microsoft.com/azure/cost-management-billing/costs/enable-tag-inheritance.md) to cover resources that don't emit tags with usage data.
  - Consider setting up automated scripts to stop resources with specific up-time profiles (for example, stop developer VMs during off-peak hours if they haven't been used in 2 hours).
  - Document up-time expectations based on specific tag values and what happens when the tag isn't present.
  - [Use Azure Policy to track compliance](https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data.md) with the tag policy.
  - Use Azure Policy to enforce specific configuration rules based on environment.
  - Consider using "override" tags to bypass the standard policy when needed. Track the cost and report them to stakeholders to ensure accountability.
- Consider establishing and tracking KPIs for low-priority workloads, like development servers.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Workload management and automation capability](https://www.finops.org/framework/capabilities/workload-management-automation) article in the FinOps Framework documentation.

<br>

## Next steps

- [Resource utilization and efficiency](./utilization-efficiency.md)
- [Cloud policy and governance](../manage/policy.md)

<br>
