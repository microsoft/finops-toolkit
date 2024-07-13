---
layout: default
grand_parent: FinOps Framework
parent: Quantify
title: Planning and estimating
permalink: /framework/capabilities/quantify/planning
nav_order: 1
description: This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/23/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Planning and estimating</span>

This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
{: .fs-6 .fw-300 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [✋ Before you begin](#-before-you-begin)
- [▶️ Getting started](#️-getting-started)
- [🏗️ Building on the basics](#️-building-on-the-basics)
- [🍎 Learn more at the FinOps Foundation](#-learn-more-at-the-finops-foundation)
- [⏩ Next steps](#-next-steps)
- [🧰 Related tools](#-related-tools)

</details>

---

<a name="definition"></a>
**Planning and estimating refers to the process of estimating the cost and usage of new and existing workloads based on exploratory or planned architectural changes and evolving business priorities.**
{: .fs-6 .fw-300 }

Leverage historical usage and cost trends from similar workloads to estimate initial costs for new workloads. Adjust or augment that based on the unique of new or changing workloads.

Collaborate with other teams to map business goals to product requirements to technical needs that can be utilized during planning and estimation efforts to ensure leadership, finance, product, engineering, and FinOps teams are aligned and that the solution will meet the business and customer needs. 

With accurate and detailed architectural plans and cost estimates, organizations are better prepared to deploy new workloads and efficiently scale existing ones to achieve business goals.

<br>

## ✋ Before you begin

Before you can effectively plan for and estimate usage and costs for a cloud workload, you need to drive alignment across stakeholders on the goals and priority of the effort and map that to the product requirements and technical needs.

- Document requirements, motivations, and expected outcomes for building new or improving existing workloads, including cloud migrations.
  - Motivations may include cost savings, scaling abilities, or building new technical capabilities within your organization. Leverage existing KPIs and project potential impact.
  - Describe any requirements necessary for successful delivery, such as executive sponsorship or support from individual teams.
  - Define the scope of the effort, including detailed requirements, and unique needs of the workload necessary to meet business goals.
- Understand financial constraints and considerations, like staff productivity, cloud economics, and the nuances with an OpEx model.
- Define technical considerations:
  - Scalability
  - Availability
  - Resiliency
  - Security and Compliance
  - Elasticity (managed, maintain, pay for cloud)
  - Capacity optimization
- Familiarize yourself with [how you’re charged for the services you use](https://azure.microsoft.com/pricing#product-pricing) to understand:
  - Factors that contribute to costs (for example, compute, storage, networking, and data transfer).
  - How usage aligns with the various pricing models (for example, pay-as-you-go, reservations, and Azure Hybrid Benefit).

Starting with well-defined requirements that are aligned across teams helps set clear expectations and establishes a solid foundation for effective cross-group collaboration over the lifecycle of each workload.

<br>

## ▶️ Getting started
- If you're migrating on-premises infrastructure to the cloud:
  - Leverage the [Total Cost of Ownership (TCO) Calculator](https://azure.microsoft.com/pricing/tco/calculator) to get a high-level comparison of on-premises vs. cloud servers, databases, storage, and networking infrastructure.
    > After entering details of your on-premises infrastructure, the TCO Calculator presents cost reports showcasing the cost differences between running workloads on-premises compared to Azure that can be saved and shared across team members.
  - Use [Azure Migrate](https://azure.microsoft.com/products/azure-migrate) to automate the discovering and migration of your on-premises workloads.
- If you're estimating changes to an existing workload, review the [Forecasting](./forecasting.md) capability.
- If you're building a new solution, start with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator) to estimate costs based on projected usage patterns.
  > Within the pricing calculator, custom scenarios can be analyzed by generating estimates and configuring resources to match specific parameters. Cost savings such as reservations, savings plans, and Azure Hybrid Benefit can also be evaluated. Sign in to save estimates based on your enterprise pricing.

<br>

## 🏗️ Building on the basics

- Use the [Cost optimization workbook](../../../../_optimize/optimization-workbook/README.md) to optimize current workloads and reduce potential future estimates.
- Review the [Architecting for cloud](../optimize/architecting.md) capability to ensure workloads are designed for efficiency.
- Evaluate options to reduce costs through the [Rate optimization](../optimize/rates.md) capability.
- Automate best practices through [Azure Policy](https://learn.microsoft.com/azure/governance/policy/overview) to enforce organizational standards at scale.

With these insights, you can make more accurate cost predictions and manage your cloud budget effectively.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see to the [planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/) article in the FinOps Framework documentation.

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Forecasting](./forecasting.md)
- [Architecting for cloud](../optimize/architecting.md)
- [Workload optimization](../optimize/workloads.md)
- [Rate optimization](../optimize/rates.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="0" pbi="1" ps="0" %}

<br>
