---
layout: default
grand_parent: FinOps Framework
parent: Quantify
title: Benchmarking
permalink: /framework/capabilities/quantify/benchmarking
nav_order: 3
description: This article helps you understand the benchmarking capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: ripadrao
ms.author: banders
ms.date: 03/25/2024
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Benchmarking</span>
This article helps you understand the benchmarking capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Benchmarking is a systematic process of evaluating the performance and value of cloud services using efficiency metrics, either within an organization or against industry peers**
{: .fs-6 .fw-300 }

Benchmarking empowers organizations to measure and analyze unit metrics and Key Performance Indicators (KPIs) related to cloud value and optimization. It encompasses internal evaluations across various teams within the organization, as well as external comparisons with peer entities utilizing Microsoft Cloud services in similiar capacities. It is important to recognize that cloud usage is unique to each organization, and there is no singular "correct" approach to correct benchmarking. 
For a successful internal benchmarking initiative, it is essential to establish well-defined metrics, maintain transparent communication regarding goals and objectives, ensure precise data collection and effective dashboarding, and garner management support. 

Benchmarking serves as a tool to gauge performance, encouraging companies to make informed decisions based on current knowledge rather than deferring action in anticipation of better data.

<br>

## ▶️ Getting started

When beginning with the Benchmarking capability, there are a few Azure built-in benchmarks that can be utilized, such as the [Azure Advisor score](https://learn.microsoft.com/en-us/azure/advisor/azure-advisor-score) and the [well-architected assessment](https://learn.microsoft.com/en-us/assessments/azure-architecture-review/). 

- Start by reviewing the [Azure Advisor score]() at the primary scope you manage, whether that's a subscription, resource group or based on tags.
  - The Advisor score consists of an overall score, which can be further broken down into five category scores. One score for each category of Advisor represents the five pillars of the Well-Architected Framework.
  - The objective of this capability is to analyze the Cost Optimizaiton pillar, but analyzing and improving the score of the other pillars will provide you with more insghts about the overall heaht of your application/environment.
  - Prioritize the recommendations with high priorities. 
  - If any of the Advisor recommendation related to Reserved Instances or Savings Plan for compute, refer to [commitment-based](docs/_docs/framework/capabilities/optimize/commitment-discounts.md) to learn more and about this capability.
- Continue evaluating the health of your environment by compliting an [Azure Well-Architected Review assessment](https://learn.microsoft.com/en-us/azure/well-architected/cross-cutting-guides/implementing-recommendations) which is a self-assessment that can help a workload team examine a workload from the perspective of the Azure Well-Architected Framework. 
    - Link your Azure Subscription to allow Azure Advisor recommendations to be included in this assessment.

<br>

## 🏗️ Building on the basics

Build up on what you already know about Well-Architecture Framework. Define internally your benchmarking metrics, communicate and manage different benchmarking programs for the different teams. 

- Establish and automate KPIs, such as:
  - Number of anomalies each month or quarter.
  - Total cost impact of idle resources each month or quarter.
  - Response time to detect and resolve anomalies.
  - Number of false positives and false negatives.
- Expand coverage of anomaly detection and response processes to include all costs.
- Foster a culture of continuous learning, innovation, and collaboration.
  - Regularly review and refine the benchmarking baseline based on feedback, industry best practices, and emerging technologies.
  - Promote knowledge sharing and cross-functional collaboration to drive continuous improvement in the benchmarking capability.

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see to the [benchmarking](https://www.finops.org/framework/capabilities/benchmarking) article in the FinOps Framework documentation.



You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/{id}?list={list}]-->
{% include video.html title="Budgeting videos" id="5Qe7eRXKMRzRrwBI" list="PLUSCToibAswnjB7fYRA02ePxySkpDex6q" %}

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
