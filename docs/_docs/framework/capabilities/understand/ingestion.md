---
layout: default
grand_parent: FinOps Framework
parent: Understand
title: Data ingestion
permalink: /framework/capabilities/understand/ingestion
nav_order: 1
description: This article helps you understand the data ingestion capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/22/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Data ingestion</span>
This article helps you understand the data ingestion capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Data ingestion refers to the process of collecting, transforming, and organizing data from various sources into a single, easily accessible repository.**
{: .fs-6 .fw-300 }

Gather cost, utilization, performance, and other business data from cloud providers, vendors, and on-premises systems. Gathering the data can include:

- Internal IT data. For example, from a configuration management database (CMDB) or IT asset management (ITAM) systems.
- Business-specific data, like organizational hierarchies and metrics that map cloud costs to or quantify business value. For example, revenue, as defined by your organizational and divisional mission statements.

Understand how data gets reported and plan for data standardization requirements to support reporting on similar data from multiple sources. 
 
Consider how to handle cost data from multiple clouds or account types. Prefer open standards, like the FinOps Open Cost & Usage Specification ([FOCUS project](../../../focus/README.md)), which delivers consistency and standardization to cloud cost data, and interoperability with and across providers, vendors, and internal tools.
 
It may also require restructuring data in a logical and meaningful way by categorizing or tagging data so it can be easily accessed, analyzed, and understood.

When armed with a comprehensive collection of cost and usage information tied to business value, organizations can empower stakeholders and accelerate the goals of other FinOps capabilities. Stakeholders are able to make more informed decisions, leading to more efficient use of resources and potentially significant cost savings.

<br>

## ✋ Before you begin

While data ingestion is critical to long-term efficiency and effectiveness of any FinOps practice, it isn't a blocking requirement for your initial set of FinOps investments. If it is your first iteration through the FinOps lifecycle, consider lighter-weight capabilities that can deliver quicker return on investment, like [Reporting and analytics](./reporting.md). Data ingestion can require significant time and effort depending on account size and complexity. We recommend focusing on this process once you have the right level of understanding of the effort and commitment from key stakeholders to support that effort.

During the first iteration to start adopting this capability, consider using FOCUS as the standard billing data format for all of your data sources. To learn why organizations needs it and why Microsoft belives in FOCUS, you can review the [FOCUS documentation](../../../focus/README.md) available on FinOps toolkit provided by Microsoft.

<br>

## ▶️ Getting started

When you first start managing cost in the cloud, you use the native tools available in the portal or through Power BI. If you need more, you may download the data for local analysis, or possibly build a small report or merge it with another dataset. Eventually, you need to automate this process, which is where "data ingestion" comes in. As a starting point, we focus on ingesting cost data into a common data store.

- Before you ingest cost data, think about your reporting needs.
  - Talk to your stakeholders to ensure you have a firm understanding of what they need. Try to understand their motivations and goals to ensure the data or reporting helps them.
  - Determine whether to adopt FOCUS as the standard billing schema for any new solution. Converting existing dashboards to utilize a different dataset could pose challenges.
    - Microsoft Cost Management supports cost and usage data exports aligned to the FOCUS schema which can save you significant time and effort.
  - Identify the data you need, where you can get the data from, and who can give you access. Make note of any common datasets that may require normalization.
  - Determine the level of granularity required and how often the data needs to be refreshed. Daily cost data can be a challenge to manage for a large account. Consider monthly aggregates to reduce costs and increase query performance and reliability if that meets your reporting needs.
- Consider using a third-party FinOps platform.
  - Review the available [third-party solutions in the Azure Marketplace](https://portal.azure.com/#view/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/searchQuery/cost).
  - If you decide to build your own solution, consider starting with [FinOps hubs](https://aka.ms/finops/hubs), part of the open source FinOps toolkit provided by Microsoft.
    - FinOps hubs will accelerate your development and help you focus on building the features you need rather than infrastructure.
    - FinOps hubs includes a [Power BI report](../../../../_reporting/power-bi/README.md) that normalizes data to the FOCUS schema, which can be a good starting point.
- Complement cloud cost data with organizational hierarchies and budgets.    
- Select the [cost details solution](https://learn.microsoft.com/azure/cost-management-billing/automate/usage-details-best-practices) that is right for you. We recommend scheduled exports, which push cost data to a storage account on a daily or monthly basis.
  - If you use daily exports, notice that data is pushed into a new file each day. Ensure that you only select the latest day when reporting on costs.
- Determine if you need a data integration or workflow technology to process data.
  - In an early phase, you may be able to keep data in the exported storage account without other processing. We recommend that you keep the data there for small accounts with lightweight requirements and minimal customization.
  - If you need to ingest data into a more advanced data store or perform data cleanup or normalization, you may need to implement a data pipeline. [Choose a data pipeline orchestration technology](https://learn.microsoft.com/azure/architecture/data-guide/technology-choices/pipeline-orchestration-data-movement).
- Determine what your data storage requirements are.
  - In an early phase, we recommend using the exported storage account for simplicity and lower cost.
  - If you need an advanced query engine or expect to hit data size limitations within your reporting tools, you should consider ingesting data into an analytical data store. [Choose an analytical data store](https://learn.microsoft.com/azure/architecture/data-guide/technology-choices/analytical-data-stores).

<br>

## 🏗️ Building on the basics

At this point, you have a data pipeline and are ingesting data into a central data repository. As you move beyond the basics, consider the following points:

- Normalize data to a standard schema to support aligning and blending data from multiple sources.
  - For cost data, we recommend using the [FinOps Open Cost & Usage Specification (FOCUS) schema](https://finops.org/focus).
  - Consider using the [FOCUS converter tool](https://github.com/finopsfoundation/focus_converters) to convert billing data files from other public clouds.  
  - Consider labeling or tagging requirements to map cloud costs to organizational hierarchies.
- Enrich cloud resource and solution data with internal CMDB or ITAM data.
- Consider what internal business and revenue metrics are needed to map cloud costs to business value.
- Determine what other datasets are required based on your reporting needs:
  - Cost and pricing
    - [Azure retail prices](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices) for pay-as-you-go rates without organizational discounts.
    - [Price sheets](https://learn.microsoft.com/rest/api/cost-management/price-sheet) for organizational pricing for Microsoft Customer Agreement accounts.
    - [Price sheets](https://learn.microsoft.com/rest/api/consumption/price-sheet/get) for organizational pricing for Enterprise Agreement accounts.
    - [Balance summary](https://learn.microsoft.com/rest/api/consumption/balances/get-by-billing-account) for Enterprise Agreement monetary commitment balance.
  - Commitment discounts
    - [Reservation details](https://learn.microsoft.com/rest/api/cost-management/generate-reservation-details-report) for recommendation details.
    - [Benefit utilization summaries](https://learn.microsoft.com/rest/api/cost-management/generate-benefit-utilization-summaries-report) for savings plans.
    <!-- TODO: Add Savings plan details -->
    <!-- TODO: Add Savings plan transactions -->
    <!-- TODO: Add Savings plan recommendations -->
    <!-- TODO: Add Reservation transactions -->
    <!-- TODO: Add Reservation recommendations -->
    <!-- TODO: Add Reservation utilization summaries -->
  - Utilization and efficiency
    - [Resource Graph](https://learn.microsoft.com/rest/api/azureresourcegraph/resourcegraph(2020-04-01-preview)/resources/resources) for Azure Advisor recommendations.
    - [Monitor metrics](https://learn.microsoft.com/cli/azure/monitor/metrics) for resource usage.
  - Resource details
    - [Resource Graph](https://learn.microsoft.com/rest/api/azureresourcegraph/resourcegraph(2020-04-01-preview)/resources/resources) for resource details.
    - [Resource changes](https://learn.microsoft.com/rest/api/resources/changes/list) to list resource changes from the past 14 days.
    - [Subscriptions](https://learn.microsoft.com/rest/api/resources/subscriptions/list) to list subscriptions.
    - [Tags](https://learn.microsoft.com/rest/api/resources/tags/list) for tags that have been applied to resources and resource groups.
  - [Azure service-specific APIs](https://learn.microsoft.com/rest/api/azure/) for lower-level configuration and utilization details.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [data ingestion capability](https://www.finops.org/framework/capabilities/data-ingestion/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/RIU7srzbBVE?list=PLUSCToibAswkNY0BoImEsOxwuYA_nd_gu&pp=iAQB]-->
{% include video.html title="Data ingestion videos" id="RIU7srzbBVE" list="PLUSCToibAswkNY0BoImEsOxwuYA_nd_gu" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [Cost allocation](./allocation.md)
- [Data analysis and showback](./reporting.md)

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
