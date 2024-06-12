---
title: Resource utilization and efficiency
description: This article helps you understand the resource utilization and efficiency capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/12/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the resource utilization and efficiency capability so that I can implement it in the Microsoft Cloud.

---

<!-- markdownlint-disable-next-line MD025 -->
# Resource utilization and efficiency

This article helps you understand the resource utilization and efficiency capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Resource utilization and efficiency refers to the process of ensuring cloud services are utilized and tuned to maximize business value and minimize wasteful spending.**

Review how services get used and ensure each is maximizing return on investment. Evaluate and implement best practices and recommendations.

Every cost should have direct or indirect traceability back to business value. Eliminate fully "optimized" resources that aren't contributing to business value.

Resource utilization and efficiency maximize the business value of cloud costs by avoiding unnecessary costs that don't contribute to the mission, which in turn increases return on investment and profitability.

<br>

## Getting started

When you first start managing cost in the cloud, you use the native tools to drive efficiency and optimize costs in the portal.

- Review and implement [Azure Advisor cost recommendations](/azure/advisor/advisor-reference-cost-recommendations.md).
  - Azure Advisor gives you high-confidence recommendations based on your usage. Azure Advisor is always the best place to start when looking to optimize any workload.
  - Consider [subscribing to Azure Advisor alerts](/azure/advisor/advisor-alerts-portal.md) to get notified when there are new cost recommendations.
- Review your usage and purchase [commitment-based discounts](./commitment-discounts.md) when it makes sense.
- Take advantage of Azure Hybrid Benefit for [Windows](/windows-server/get-started/azure-hybrid-benefit), [Linux](/azure/virtual-machines/linux/azure-hybrid-benefit-linux.md), and [SQL Server](/azure/azure-sql/azure-hybrid-benefit.md).
- Review and implement [Cloud Adoption Framework costing best practices](/azure/cloud-adoption-framework/govern/cost-management/best-practices.md).
- Review and implement [Azure Well-Architected Framework cost optimization guidance](/azure/well-architected/cost/overview.md).
- Familiarize yourself with the services you use, how you're charged, and what service-specific cost optimization options you have.
  - You can discover the services you use from the Azure portal All resources page or from the [Services view in Cost analysis](/azure/cost-management-billing/costs/cost-analysis-built-in-views#break-down-product-and-service-costs.md).
  - To learn how each service charges you, explore the [Azure pricing pages](https://azure.microsoft.com/pricing) and [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator). Use them to identify options that might reduce costs. For example, shared infrastructure and commitment discounts.
  - Review service documentation to learn about any cost-related features that could help you optimize your environment or improve cost visibility. Some examples:
    - Choose [spot VMs](/azure/well-architected/cost/optimize-vm#spot-vms.md) for low priority, interruptible workloads.
    - Avoid [cross-region data transfer](/azure/well-architected/cost/design-regions#traffic-across-billing-zones-and-regions.md).
- Use and customize the [Cost optimization workbook](../../toolkit/optimization-workbook/cost-optimization-workbook.md). The Cost Optimization workbook is a central point for some of the most often used tools that can help achieve utilization and efficiency goals.

<br>

## Building on the basics

At this point, you implemented all the basic cost optimization recommendations and tuned applications to meet the most fundamental best practices. As you move beyond the basics, consider the following points:

- Automate cost recommendations using [Azure Resource Graph](/azure/advisor/resource-graph-samples.md)
- Implement the [Workload management and automation capability](./workloads.md) for more optimizations.
- Stay abreast of emerging technologies, tools, and industry best practices to further optimize resource utilization.

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Resource utilization and efficiency capability](https://www.finops.org/framework/capabilities/utilization-efficiency/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/DIcO8EulN8PuXuWL?list=PLUSCToibAswlL6Ms76cl9GDmcpM85nlWA]

<br>

## Related content

Related FinOps capabilities:

- [Managing commitment-based discounts](./commitment-discounts.md)
- [Workload management and automation](./workloads.md)
- [Measuring unit cost](../quantify/unit-economics.md)

Related products:

- [Azure Advisor](/azure/advisor/)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [Cost optimization workbook](../../toolkit/optimization-workbook/cost-optimization-workbook.md)
- [Governance workbook](https://microsoft.github.io/finops-toolkit/governance-workbook)

Other resources:

- [Azure pricing](https://azure.microsoft.com/pricing#product-pricing)
- [Well-Architected Framework](/azure/well-architected/)
- [Cloud Adoption Framework](/azure/cloud-adoption-framework/)

<br>
