---
layout: default
grand_parent: FinOps Framework
parent: Optimize
title: Utilization and efficiency
permalink: /framework/capabilities/optimize/utilization-efficiency
nav_order: 1
description: This article helps you understand the resource utilization and efficiency capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/23/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Resource utilization and efficiency</span>
This article helps you understand the resource utilization and efficiency capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Resource utilization and efficiency refers to the process of ensuring cloud services are utilized and tuned to maximize business value and minimize wasteful spending.**
{: .fs-6 .fw-300 }

Review how services are being used and ensure each is maximizing return on investment. Evaluate and implement best practices and recommendations.

Every cost should have direct or indirect traceability back to business value. Eliminate fully "optimized" resources that aren't contributing to business value.

Resource utilization and efficiency maximize the business value of cloud costs by avoiding unnecessary costs that don't contribute to the mission, which in turn increases return on investment and profitability.

<br>

## ▶️ Getting started

When you first start managing cost in the cloud, you use the native tools to drive efficiency and optimize costs in the portal.

- Review and implement [Azure Advisor cost recommendations](https://learn.microsoft.com/azure/advisor/advisor-reference-cost-recommendations).
  - Azure Advisor gives you high-confidence recommendations based on your usage. Azure Advisor is always the best place to start when looking to optimize any workload.
  - Consider [subscribing to Azure Advisor alerts](https://learn.microsoft.com/azure/advisor/advisor-alerts-portal) to get notified when there are new cost recommendations.
- Review your usage and purchase [commitment discounts](./rate-optimization.md) when it makes sense.
- Take advantage of Azure Hybrid Benefit for [Windows](https://learn.microsoft.com/windows-server/get-started/azure-hybrid-benefit), [Linux](https://learn.microsoft.com/azure/virtual-machines/linux/azure-hybrid-benefit-linux), and [SQL Server](https://learn.microsoft.com/azure/azure-sql/azure-hybrid-benefit).
- Review and implement [Cloud Adoption Framework costing best practices](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/cost-management/best-practices).
- Review and implement [Azure Well-Architected Framework cost optimization guidance](https://learn.microsoft.com/azure/well-architected/cost/overview).
- Familiarize yourself with the services you use, how you're charged, and what service-specific cost optimization options you have.
  - You can discover the services you use from the Azure portal All resources page or from the [Services view in Cost analysis](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-analysis-built-in-views#break-down-product-and-service-costs).
  - Explore the [Azure pricing pages](https://azure.microsoft.com/pricing) and [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) to learn how each service charges you. Use them to identify options that might reduce costs. For example, shared infrastructure and commitment discounts.
  - Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
    - Choose [spot VMs](https://learn.microsoft.com/azure/well-architected/cost/optimize-vm#spot-vms) for low priority, interruptible workloads.
    - Avoid [cross-region data transfer](https://learn.microsoft.com/azure/well-architected/cost/design-regions#traffic-across-billing-zones-and-regions).
- Use and customize the [Cost optimization workbook](../../../../_workbooks/optimization-workbook/cost-optimization-workbook.md). The Cost Optimization workbook is a central point for some of the most often used tools that can help achieve utilization and efficiency goals.

<br>

## 🏗️ Building on the basics

At this point, you've implemented all the basic cost optimization recommendations and tuned applications to meet the most fundamental best practices. As you move beyond the basics, consider the following points:

- Automate cost recommendations using [Azure Resource Graph](https://learn.microsoft.com/azure/advisor/resource-graph-samples)
- Stay abreast of emerging technologies, tools, and industry best practices to further optimize resource utilization.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Resource utilization and efficiency capability](https://www.finops.org/framework/capabilities/utilization-efficiency/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/{id}?list={list}]-->
{% include video.html title="Resource utilization and efficiency videos" id="DIcO8EulN8PuXuWL" list="PLUSCToibAswlL6Ms76cl9GDmcpM85nlWA" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Rate optimization](./rate-optimization.md)
- [Workload management and automation](./workloads.md)
- [Measuring unit cost](../quantify/unit-economics.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="1" hubs="0" opt="1" pbi="0" ps="0" %}

<br>
