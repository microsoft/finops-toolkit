---
layout: default
grand_parent: FinOps Framework
parent: Quantify
title: Planning and estimating
permalink: /framework/capabilities/quantify/planning
nav_order: 3
description: This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/23/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Planning and Estimating</span>
This article helps you understand the planning and estimating capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Planning and estimating refers to the estimation and exploration of potential cost and value of workloads if implemented in the Microsoft cloud.**
{: .fs-6 .fw-300 }

This involves collaboration between leadership, finance, engineering, FinOps, and product teams to define the scope, detail requirements, and the model parameters of the workload. With accurate and detailed architectural plans and cost estimates, organizations are better prepared to deploy new workloads in Azure or efficiently scale existing ones.

Before effectively planning and estimating costs for an Azure workload, several key components must be defined to determine the correct cloud resources and architecture:

- Define and document motivations for migrating workloads to the Microsoft cloud or developing and improving current workloads in Azure. Motivations may include cost savings, scaling abilities, or building new technical capabilities within your organization.
- Document business outcomes, such as investment in people and resources, executive sponsorship, support from IT/cloud team, and business team. Set up objectives and key results to clearly state intent and measure cloud adoption success.
- Understand financial considerations:
  - Cloud economics
  - OPEX
  - Staff productivity

- Define technical considerations:
  - Scalability
  - Availability
  - Resiliency
  - Security and Compliance
  - Elasticity (managed, maintain, pay for cloud)
  - Capacity optimization

Defining the above-mentioned aspects for the workload enables cross collaboration and provides clear expectations between leadership, finance, engineering, FinOps, and product teams.

<br>

## ▶️ Getting started


- The [Total Cost of Ownership (TCO) Calculator](https://azure.microsoft.com/pricing/tco/calculator/) can be used to input details about your on-premises infrastructure, including servers, databases, storage, and networking, to determine your current TCO and obtain recommended services in Azure. After entering details of your on-premises infrastructure, the TCO Calculator presents cost reports showcasing the cost differences between running workloads on-premises versus in Azure that can be saved and shared across team members.

- The [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) is a valuable tool for estimating and analyzing costs associated with various Microsoft Azure resources and services. Within the Azure Pricing Calculator, custom scenarios can be analyzed by generating estimates and configuring resources to match specific parameters. Cost savings such as Reserved Instances, Savings Plans, and Azure Hybrid Benefit can also be evaluated. By logging in with your Azure credentials, custom estimates can be saved and shared with other team members to make informed decisions about your Azure deployments.


<br>

## 🏗️ Building on the basics

- The [Azure Advisor Cost Optimization Workbook](https://learn.microsoft.com/azure/advisor/advisor-cost-optimization-workbook) can be used to evaluate usage optimization and rate optimization recommendations for current workloads in Azure. These insights provide recommendations such as rightsizing or shutting down underutilized resources and recommendations for acquiring reservations and savings plans. The recommendations provide resource details that can be used for planning adjustments or estimating the cost of any changes to the workload.

- Within Microsoft Cost Management and Billing, [Cost Analysis](https://learn.microsoft.com/azure/cost-management-billing/costs/quick-acm-cost-analysis) can be used to analyze Actual, Amortized, and Forecasted costs of the selected scope. Built-in views can provide cost insights on resources, resource groups, subscriptions, or reservations.

- Budgets in [Microsoft Cost Management and Billing](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-analysis-common-uses) help with planning for and driving organizational accountability by proactively informing stakeholders of Azure spending. With budgets, spending limits and alerts can be configured based on either actual or forecasted cost thresholds allowing for timely action to take place.

- The [Dev/Test Offer](https://learn.microsoft.com/azure/devtest/offer/overview-what-is-devtest-offer-visual-studio) can be used for trial runs to estimate cost/test architecture.

- Define [Azure Policies](https://learn.microsoft.com/azure/governance/policy/overview) needed to enforce organizational standards and to assess compliance at scale. Built-in policy definitions can be leveraged to compare the properties of resources against defined standards and built-in initiatives to simplify management by enforcing multiple policies as a single unit.

With these insights, you can make more accurate cost predictions and manage your cloud budget effectively.


<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see to the [planning and estimating](https://www.finops.org/framework/capabilities/planning-estimating/) article in the FinOps Framework documentation.

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Forecasting](./forecasting.md)
- [Onboarding workloads](../manage/onboarding.md)
- [Chargeback and finance integration](../manage/invoicing-chargeback.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="0" pbi="1" ps="0" %}

<br>
