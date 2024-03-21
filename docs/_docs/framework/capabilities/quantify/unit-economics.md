---
layout: default
grand_parent: FinOps Framework
parent: Quantify
title: Unit costs
permalink: /framework/capabilities/quantify/unit-economics
nav_order: 5
description: This article helps you understand the unit economics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 10/25/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Unit economics</span>
This article helps you understand the unit economics capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Unit economics refers to the process of calculating the cost of a single unit of a business that can show the business value of the cloud.**
{: .fs-6 .fw-300 }

Identify what a single unit is for your business – like a sale transaction for an ecommerce site or a user for a social app. Map each unit to the supporting cloud services that support it. Split the cost of shared infrastructure with utilization data to quantify the total cost of each unit.

Unit economics provides insights into profitability and allows organizations to make data-driven business decisions regarding cloud investments. Unit economics is what ties the cloud to measurable business value.

The ultimate goal of unit economics, as a derivative of activity-based costing methodology, is to factor in the whole picture of your business's cost. This article focuses on capturing how you can factor your Microsoft Cloud costs into those efforts. As your FinOps practice matures, consider the manual processes and steps outside of the cloud that might be important for calculating units that are critical for your business to track the most accurate cost per unit.

<br>

## ✋ Before you begin

Before you can effectively measure unit costs, you need to familiarize yourself with [how you're charged for the services you use](https://azure.microsoft.com/pricing#product-pricing). Understanding the factors that contribute to costs, helps you break down the usage and costs and map them to individual units. Cost contributing-factors factors include compute, storage, networking, and data transfer. How your service usage aligns with the various pricing models (for example, pay-as-you-go, reservations, and Azure Hybrid Benefit) also impacts your costs.

<br>

## ▶️ Getting started

Unit economics isn't a simple task. Unit economics requires a deep understanding of your architecture and needs multiple datasets to pull together the full picture. The exact data you need depends on the services you use and the telemetry you have in place.

- Start with application telemetry.
  - The more comprehensive your application telemetry is, the simpler unit economics can be to generate. Log when critical functions are executed and how long they run. You can use that to deduce the run time of each unit or relative to a function that correlates back to the unit.
  - When application telemetry isn't directly possible, consider workarounds that can log telemetry, like [API Management](https://learn.microsoft.com/azure/api-management/api-management-key-concepts) or even [configuring alert rules in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-create-new-alert-rule) that trigger [action groups](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups) that log the telemetry. The goal is to get all usage telemetry into a single, consistent data store.
  - If you don't have telemetry in place, consider setting up [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview), which is an extension of Azure Monitor.
- Use [Azure Monitor metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/data-platform-metrics) to pull resource utilization data.
  - If you don't have telemetry, see what metrics are available in Azure Monitor that can map your application usage to the costs. You need anything that can break down the usage of your resources to give you an idea of what percentage of the billed usage was from one unit vs. another.
  - If you don't see the data you need in metrics, also check [logs and traces in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/overview#data-platform). It might not be a direct correlation to usage but might be able to give you some indication of usage.
- Use service-specific APIs to get detailed usage telemetry.
  - Every service uses Azure Monitor for a core set of logs and metrics. Some services also provide more detailed monitoring and utilization APIs to get more details than are available in Azure Monitor. Explore [Azure service documentation](https://learn.microsoft.com/azure) to find the right API for the services you use.
- Using the data you've collected, quantify the percentage of usage coming from each unit.
  - Use pricing and usage data to facilitate this effort. It's typically best done after [Data ingestion and normalization](../understand/ingestion.md) due to the high amount of data required to calculate accurate unit costs.
  - Some amount of usage isn't mapped back to a unit. There are several ways to account for this cost, like distributing based on those known usage percentages or treating it as overhead cost that should be minimized separately.

<br>

## 🏗️ Building on the basics

- Automate any aspects of the unit cost calculation that haven't been fully automated.
- Consider expanding unit cost calculations to include other costs, like external licensing, on-premises operational costs, and labor.
- Build unit costs into business KPIs to maximize the value of the data you've collected.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Unit economics capability](https://www.finops.org/framework/capabilities/unit-economics/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/{id}?list={list}]-->
{% include video.html title="Unit economics videos" id="YAoi1Aip3fMwNfaY" list="PLUSCToibAswkxZme8TQKg3uBNh2Qk1MvL" %}

<br>

## ⏩ Next steps

- [Data analysis and showback](../understand/reporting.md)
- [Managing shared costs](../understand/shared-cost.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="0" pbi="1" ps="0" %}

<br>
