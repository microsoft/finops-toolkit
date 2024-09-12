---
layout: default
grand_parent: FinOps Framework
parent: Manage
title: Policy + governance
permalink: /framework/capabilities/manage/policy
nav_order: 4
description: This article helps you understand the cloud policy and governance capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 06/22/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">Cloud policy and governance</span>
This article helps you understand the cloud policy and governance capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**Cloud policy and governance refers to the process of defining, implementing, and monitoring a framework of rules that guide an organization's FinOps efforts.**
{: .fs-6 .fw-300 }

Define your governance goals and success metrics. Review and document how existing policies are updated to account for FinOps efforts. Review with all stakeholders to get buy-in and endorsement.

Establish a rollout plan that starts with audit rules and slowly (and safely) expands coverage to drive compliance without negatively impacting engineering efforts.

Implementing a policy and governance strategy enables organizations to sustainably implement FinOps at scale. Policy and governance can act as a multiplier to FinOps efforts by building them natively into day-to-day operations.

<br>

## ▶️ Getting started

When you first start managing cost in the cloud, you use the native compliance tracking and enforcement tools.

- Review your existing FinOps processes to identify opportunities for policy to automate enforcement. Some examples:
  - [Enforce your tagging strategy](https://learn.microsoft.com/azure/governance/policy/tutorials/govern-tags) to support different capabilities, like:
    - Organizational reporting hierarchy tags for [allocation](../understand/allocation.md).
    - Financial reporting tags for [chargeback](./invoicing-chargeback.md).
    - Environment and application tags for [workload management](../optimize/workloads.md).
    - Business and application owners for [anomalies](../understand/anomalies.md).
  - Monitor required and suggested alerting for [anomalies](../understand/anomalies.md) and [budgets](../quantify/budgeting.md).
  - Block or audit the creation of more expensive resource SKUs (for example, E-series virtual machines).
  - Implementation of cost recommendations and unused resources for [utilization and efficiency](../optimize/workloads.md).
  - Application of Azure Hybrid Benefit for [utilization and efficiency](../optimize/workloads.md).
  - Monitor [commitment discounts](../optimize/rates.md) coverage.
- Identify what policies can be automated through [Azure Policy](https://learn.microsoft.com/azure/governance/policy/overview) and which need other tooling.
- Review and [implement built-in policies](https://learn.microsoft.com/azure/governance/policy/assign-policy-portal) that align with your needs and goals.
- Start small with audit policies and expand slowly (and safely) to ensure engineering efforts aren't negatively impacted.
  - Test rules before you roll them out and consider a staged rollout where each stage has enough time to get used and garner feedback. Start small.

<br>

## 🏗️ Building on the basics

At this point, you have a basic set of policies in place that are being managed across the organization. As you move beyond the basics, consider the following points:

- Formalize compliance reporting and promote within leadership conversations across stakeholders.
  - Map governance efforts to FinOps efficiencies that can be mapped back to more business value with less effort.
- Expand coverage of more scenarios.
  - Consider evaluating ways to quantify the impact of each rule in cost and/or business value.
- Integrate policy and governance into every conversation to establish a plan for how you want to automate the tracking and application of new policies.
- Consider advanced governance scenarios outside of Azure Policy. Build monitoring solutions using systems like [Power Automate](https://learn.microsoft.com/power-automate/getting-started) or [Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview).

<br>

## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Cloud policy and governance capability](https://www.finops.org/framework/capabilities/policy-governance/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/wiqCovCttOc?list=PLUSCToibAswnr2q_J-kn7Yii1CO2-PU35&pp=iAQB]-->
{% include video.html title="Cloud policy and governance videos" id="wiqCovCttOc" list="PLUSCToibAswnr2q_J-kn7Yii1CO2-PU35" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [FinOps practice operations](./operations.md)
- [Workload optimization](../optimize/workloads.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="1" hubs="0" opt="0" pbi="0" ps="0" %}

<br>
