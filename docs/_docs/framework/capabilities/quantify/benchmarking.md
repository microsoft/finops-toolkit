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
**Benchmarking is a systematic process of evaluating the performance and value of cloud services using efficiency metrics, either within an organization or against industry peers.**

{: .fs-6 .fw-300 }

Benchmarking enables organizations to understand how key performance indicators (KPIs) compare with others and identify areas to improve and possibly learn from. Benchmarking encompasses internal evaluations across various teams within the organization, as well as external comparisons with peer entities utilizing Microsoft Cloud services in similar capacities. It's important to recognize that cloud usage is unique to each organization, and there isn't a single "correct" approach when comparing KPIs across teams and organizations.

Benchmarking serves as a tool to gauge performance, encouraging companies to make informed decisions based on current knowledge rather than deferring action in anticipation of better data. Establish well-defined metrics, maintain transparent communication regarding goals and objectives, ensure precise data collection and effective dashboarding, and garner management support to maximize your return on investment from benchmarking efforts.

<br>

## ▶️ Getting started

When you first start managing cost in the cloud, leverage the existing guidance and recommendations which are based on benchmarks established across all Microsoft Cloud customers, such as the [Azure Advisor score](https://learn.microsoft.com/azure/advisor/azure-advisor-score) and the [well-architected assessment](https://learn.microsoft.com/assessments/azure-architecture-review/).

- Start by reviewing the [Azure Advisor score](https://learn.microsoft.com/azure/advisor/azure-advisor-score) at the primary scope you manage, whether that's a subscription, resource group, or based on tags.
  - The Advisor score consists of an overall score, which can be further broken down into five category scores. One score for each category of Advisor represents the five pillars of the Well-Architected Framework.
  - Leverage the [Workload optimization](../optimize/workloads.md] capability to prioritize and implement recommendations with the highest priority.
  - Leverage the [Rate optimization](../optimize/commitment-discounts.md) capability to maximize savings with commitment discounts, like reservations and savings plans.
- Complete the [Azure Well-Architected Review self-assessment](https://learn.microsoft.com/azure/well-architected/cross-cutting-guides/implementing-recommendations) to identify areas your existing workloads can be improved based on the Azure Well-Architected Framework.
    - Link your subscription to include Azure Advisor recommendations in the assessment.

<br>

## 🏗️ Building on the basics

At this point, you have implemented best practices based on cross-company benchmarks integrated into the Well-Architected Framework. As you move beyond the basics, consider the following:

- Establish and automate KPIs, such as:
  - Number of anomalies each month or quarter.
  - Total cost impact of idle resources each month or quarter.
  - Response time to detect and resolve anomalies.
  - Number of false positives and false negatives.
- Build and share reports covering your KPIs to publicize benchmarks within the organization.
- Foster a culture of continuous learning, innovation, and collaboration by celebrating successes and sharing proven practices.
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
- [Budgeting](./budgeting.md)
- [Unit economics](./unit-economics.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="0" hubs="1" opt="0" pbi="1" ps="0" %}

<br>
