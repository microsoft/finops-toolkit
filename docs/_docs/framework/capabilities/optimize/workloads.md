---
layout: default
grand_parent: FinOps Framework
parent: Optimize
title: Workload optimization
permalink: /framework/capabilities/optimize/workloads
nav_order: 2
description: This article helps you understand the Workload optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/23/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Workload optimization</span>
This article helps you understand the Workload optimization capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
{: .fs-6 .fw-300 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [▶️ Getting started](#️-getting-started)
- [🏗️ Building on the basics](#️-building-on-the-basics)
- [🍎 Learn more at the FinOps Foundation](#-learn-more-at-the-finops-foundation)
- [⏩ Next steps](#-next-steps)
- [🧰 Related tools](#-related-tools)

</details>

---

<a name="definition"></a>
**Workload optimization refers to the process of ensuring cloud services are utilized and tuned to maximize business value and minimize wasteful usage and spending.**
{: .fs-6 .fw-300 }

Review how services are being used and ensure each is maximizing return on investment. Evaluate and implement best practices and recommendations.

Every cost should have direct or indirect traceability back to business value. Eliminate fully "optimized" resources that aren't contributing to business value.

Review resource usage patterns and determine if they can be scaled down or even shutdown (to stop billing) during off-peak hours. Consider cheaper alternatives to reduce costs. Avoid unnecessary usage and costs that don't contribute to the mission, which in turn increases return on investment and profitability.

<br>

## ▶️ Getting started

When you first start working with a service or managing costs in the cloud, prioritize leveraging native tools within the portal to drive efficiency and optimize costs.

- Review and implement [Cloud Adoption Framework costing best practices](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/cost-management/best-practices).
- Review and implement [Azure Well-Architected Framework cost optimization guidance](https://learn.microsoft.com/azure/well-architected/cost/overview).
- Review and implement [Azure Advisor cost recommendations](https://learn.microsoft.com/azure/advisor/advisor-reference-cost-recommendations).
  - Azure Advisor gives you high-confidence recommendations based on your usage. Azure Advisor is always the best place to start when looking to optimize any workload.
  - Consider [subscribing to Azure Advisor alerts](https://learn.microsoft.com/azure/advisor/advisor-alerts-portal) to get notified when there are new cost recommendations.
- Review your usage and purchase [commitment discounts](./rates.md) when it makes sense.
- Take advantage of Azure Hybrid Benefit for [Windows](https://learn.microsoft.com/windows-server/get-started/azure-hybrid-benefit), [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/azure-hybrid-benefit-linux), and [SQL Server](https://learn.microsoft.com/azure/azure-sql/azure-hybrid-benefit).
- Familiarize yourself with the services you use, how you're charged, and what service-specific cost optimization options you have.
  - You can discover the services you use from the Azure portal All resources page or from the [Services view in Cost analysis](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-analysis-built-in-views#break-down-product-and-service-costs).
  - Explore the [Azure pricing pages](https://azure.microsoft.com/pricing) and [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) to learn how each service charges you. Use them to identify options that might reduce costs. For example, shared infrastructure and commitment discounts.
  - Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
    - Choose [spot VMs](https://learn.microsoft.com/azure/well-architected/cost/optimize-vm#spot-vms) for low priority, interruptible workloads.
    - Avoid [cross-region data transfer](https://learn.microsoft.com/azure/well-architected/cost/design-regions#traffic-across-billing-zones-and-regions).
- Determine if services can be paused or stopped to stop incurring charges.
  - Some services support autostop natively, like [Microsoft Dev Box](https://learn.microsoft.com/azure/dev-box/how-to-configure-stop-schedule), [Azure DevTest Labs](https://learn.microsoft.com/azure/devtest-labs/devtest-lab-auto-shutdown), [Azure Lab Services](https://learn.microsoft.com/azure/lab-services/how-to-configure-auto-shutdown-lab-plans), and [Azure Load Testing](https://learn.microsoft.com/azure/load-testing/how-to-define-test-criteria#auto-stop-configuration).
  - If you use a service that supports being stopped, but not autostopping, consider using a lightweight flow in [Power Automate](https://learn.microsoft.com/power-automate/getting-started) or [Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview).
  - If the service can't be stopped, review alternatives to determine if there are any options that can be stopped to stop billing.
  - Pay close attention to non-compute charges that may continue to be billed when a resource is stopped so you're not surprised. Storage is a common example of a cost that continues to be charged even if a compute resource that was using the storage is no longer running.
- Determine if services support serverless compute.
  - Serverless compute tiers can reduce costs when not active. Some examples: [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/serverless-tier-overview), [Azure SignalR Service](https://learn.microsoft.com/azure/azure-signalr/concept-service-mode), [Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/serverless), [Synapse Analytics](https://learn.microsoft.com/azure/synapse-analytics/sql/on-demand-workspace-overview), [Azure Databricks](https://learn.microsoft.com/azure/databricks/serverless-compute/).
- Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
  - Choose [spot VMs](https://learn.microsoft.com/azure/well-architected/cost/optimize-vm#spot-vms) for low priority, interruptible workloads.
  - Avoid [cross-region data transfer](https://learn.microsoft.com/azure/well-architected/cost/design-regions#traffic-across-billing-zones-and-regions).
- Determine if services support autoscaling.
  - If the service supports [autoscaling](https://learn.microsoft.com/azure/architecture/best-practices/auto-scaling), configure it to scale based on your application's needs.
  - Autoscaling can work with autostop behavior for maximum efficiency.
- Consider automatically stopping and manually starting nonproduction resources during work hours to avoid unnecessary costs.
  - Avoid automatically starting nonproduction resources that aren't used every day.
  - If you choose to autostart, be aware of vacations and holidays where resources may get started automatically but not be used.
  - Consider tagging manually stopped resources. [Save a query in Azure Resource Graph](https://learn.microsoft.com/azure/governance/resource-graph/first-query-portal) or a view in the All resources list and pin it to the Azure portal dashboard to ensure all resources are stopped.
- Consider architectural models such as containers and serverless to only use resources when they're needed, and to drive maximum efficiency in key services.
- Levarage the [Cost optimization workbook](../../../../_workbooks/optimization-workbook/cost-optimization-workbook.md) to evaluate resource utilization, like idle and unused resources.

<br>

## 🏗️ Building on the basics

At this point, you've implemented all the basic cost optimization recommendations and tuned applications to meet the most fundamental best practices. As you move beyond the basics, consider the following points:

- Automate cost recommendations using [Azure Resource Graph](https://learn.microsoft.com/azure/advisor/resource-graph-samples)
- Stay abreast of emerging technologies, tools, and industry best practices to further optimize resource utilization.
- Automate the process of automatically scaling or stopping resources that don't support it or have more complex requirements.
  - Consider using automation services, like [Azure Automation](https://learn.microsoft.com/azure/automation/automation-solution-vm-management) or [Azure Functions](https://learn.microsoft.com/azure/azure-functions/start-stop-vms/overview).
- [Assign an "Env" or Environment tag](https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources) to identify which resources are for development, testing, staging, production, etc.
  - Prefer assigning tags at a subscription or resource group level. Then enable the [tag inheritance policy for Azure Policy](https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#tags) and [Cost Management tag inheritance](https://learn.microsoft.com/azure/cost-management-billing/costs/enable-tag-inheritance) to cover resources that don't emit tags with usage data.
  - Consider setting up automated scripts to stop resources with specific up-time profiles (for example, stop developer VMs during off-peak hours if they haven't been used in 2 hours).
  - Document up-time expectations based on specific tag values and what happens when the tag isn't present.
  - [Use Azure Policy to track compliance](https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data) with the tag policy.
  - Use Azure Policy to enforce specific configuration rules based on environment.
  - Consider using "override" tags to bypass the standard policy when needed. Track the cost and report them to stakeholders to ensure accountability.
- Consider establishing and tracking KPIs for low-priority workloads, like development servers.
- Consider deploying other tools to help you optimizing your environment, for example the [Azure Optimization Engine]() available on FinOps toolkit provided by Microsoft.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Workload optimization capability](https://www.finops.org/framework/capabilities/workload-optimization/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/w2tDf_PMnZY?list=PLUSCToibAswnEoBY6zl_1bpIAqbdIDxUW&pp=iAQB]-->
{% include video.html title="Workload optimization videos" id="w2tDf_PMnZY" list="PLUSCToibAswnEoBY6zl_1bpIAqbdIDxUW" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Rate optimization](./rates.md)
- [Workload management and automation](./workloads.md)
- [Measuring unit cost](../quantify/unit-economics.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="1" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
