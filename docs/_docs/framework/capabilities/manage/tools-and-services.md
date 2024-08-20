---
layout: default
grand_parent: FinOps Framework
parent: Manage
title: FinOps tools and services
permalink: /framework/capabilities/manage/tools
nav_order: 7
description: This article helps you understand the FinOps tools and services capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
---

<!--
author: bandersmsft
ms.author: banders
ms.date: 06/22/2023
ms.topic: conceptual
ms.service: finops
ms.reviewer: micflan
-->

<span class="fs-9 d-block mb-4">FinOps tools and services</span>
This article helps you understand the FinOps tools and services capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
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
**FinOps tools and services encapsulates identifying, configuring, and integrating tools and services that meet the needs of FinOps capabilities and enable the FinOps practice at scale throughout the organization.**
{: .fs-6 .fw-300 }

Define selection criteria that maps to organizational needs and objectives and select the tools and services that complement each other and offer the best coverage. Prefer tools and services that can integrate easily with existing tools and processes to maximize return on investment.

Implement and test tools and services to validate hypotheses before scaling efforts out to the rest of the organization. Track adoption as part of your assessment and maturity efforts. Periodically review selection criteria to ensure tools and services continue to meet the targeted objectives.

<br>

## ✋ Before you begin

To clarify terminology, a FinOps "tool" is a software solution that facilitates one or more FinOps capabilities, while a FinOps "service" refers to expert guidance delivered through means such as training, consulting, or even outsourcing. FinOps tools and services are a critical part of any FinOps practice and can be pivotal when aligning cloud spending with business objectives or ensuring efficient and cost-effective cloud operations.

<br>

## ▶️ Getting started

When you first start managing cost in the cloud, you use the native tools available in the portal. This includes, but is not limited to:

- **Microsoft Cost Management**: A suite of tools designed to help organizations monitor, allocate, and optimize their cloud costs within the Microsoft Cloud.
- **Azure Advisor**: Follow best practices to optimize your Microsoft Cloud deployments.  
- **Pricing Calculator**: Helps you configure and estimate the costs for Azure products and features based on specific scenarios.  

If you're migrating on-premises infrastructure to the cloud, you'll also be interested in:

- **TCO Calculator**: Allows you to estimate the cost savings achievable by migrating your application workloads to Microsoft Cloud.  
- **Azure Migrate**: Discover, migrate, and modernize on-premises infrastructure.

As you dig deeper into optimization and governance, you'll start to use:

- **Azure Monitor**: Monitoring solution that collects, analyzes, and responds to monitoring data from cloud and on-premises environments.
- **Azure Resource Graph**: Powerful management tool to query, explore, and analyze your cloud resources at scale.
- **Azure Resource Manager**: Deploy and manage resources and applications via API or declarative templates.
- **Azure Hybrid Benefit**: A benefit that lets you reduce the costs of your licences with Software Assurance.  
- **Azure Reservations**: A commitment discount that helps you save money by committing to one-year or three-year plans for multiple products.  
- **Azure Savings Plan for Compute**: A pricing model that offers discounts on compute services when you commit to a fixed hourly amount for one or three years.


Once you have a consolidated list of the Microsoft, third-party, and homegrown tools and services available:

- Map tools and services to organizational objectives.
- Identify which tools are used by different teams and stakeholders.
- Investigate options to extend current tools and services, like the [FinOps toolkit](../../../../README.md).
<br>

## 🏗️ Building on the basics

At this point, you've defined your organizational objectives, identified how current tools and services meet them, and hopefully identified any limitations and gaps. As you move beyond the basics, you'll focus on establishing a plan to address limitations and gaps or opportunities to go beyond your basic requirements to further maximize cloud ROI through new opportunities made available via new or existing tools and services.

- Evaluate limitations and gaps in existing tools and services and establish a plan to address them.
  - Automate tasks with [PowerShell commands](../../../../_automation/powershell/README.md) and [Bicep modules](../../../../_automation/bicep-registry/README.md).
  - Consider lightweight tools for engineers, like the [Cost optimization](../../../../_optimize/optimization-workbook/README.md) or [Governance](../../../../_optimize/governance-workbook/README.md) workbooks.
  - If you're looking for an extensible platform for reporting and analytics, check out [FinOps hubs](../../../../_reporting/hubs/README.md) and connect to your hub from Microsoft Fabric to go even further.
- Document the key processes around the tools and services available to teams.
  - Include when to use and how to get started with each.
  - Set expectations around any costs, if applicable.
- Seek to standardize processes and maximize adoption.
- Periodically assess progress towards organizational objectives to ensure tools and services are achieving their desired results.


## 🍎 Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [FinOps tools and services](https://www.finops.org/framework/capabilities/finops-tools-services/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

<!--[!VIDEO https://www.youtube.com/embed/I4nRDraHaJc?list=PLUSCToibAswnrMcPgpshJr-10XDwD0E0i&pp=iAQB]-->
{% include video.html title="Tools and services videos" id="I4nRDraHaJc" list="PLUSCToibAswnrMcPgpshJr-10XDwD0E0i" %}

<br>

## ⏩ Next steps

Related FinOps capabilities:

- [FinOps practice operations](./operations.md)
- [FinOps assessment](./assessment.md)

<br>

---

## 🧰 Related tools

{ % include tools.md bicep="0" data="0" gov="1" hubs="1" opt="1" pbi="1" ps="0" %}

<br>
