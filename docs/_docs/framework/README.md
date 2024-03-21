---
layout: default
title: FinOps Framework
has_children: true
nav_order: 20
description: 'Learn about what the FinOps Framework is and how you can use it to accelerate your cost management and optimization goals.'
permalink: /framework
---

<span class="fs-9 d-block mb-4">FinOps Framework</span>
Learn about what the FinOps Framework is and how you can use it to accelerate your cost management and optimization goals.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [⚖️ Principles](#️-principles)
- [👥 Stakeholders](#-stakeholders)
- [♻️ Lifecycle](#️-lifecycle)
- [📝 Capabilities](#-capabilities)
- [📏 Maturity model](#-maturity-model)
- [🍎 Learn more at the FinOps Foundation](#-learn-more-at-the-finops-foundation)
- [⏩ Next steps](#-next-steps)
- [🧰 Related tools](#-related-tools)

</details>

---

The [FinOps Framework](https://finops.org/framework) by the FinOps Foundation is a comprehensive set of best practices and principles. It provides a structured approach to implement a FinOps culture to:

- Help organizations manage their cloud costs more effectively
- Align cloud spending with business goals
- Drive greater business value from their cloud infrastructure

Microsoft's guidance is largely based on the FinOps Framework with a few enhancements based on the lessons learned from our vast ecosystem of Microsoft Cloud customers and partners. These extensions map cleanly back to FinOps Framework concepts and are intended to provide more targeted, actionable guidance for Microsoft Cloud customers and partners. We're working with the FinOps Foundation to incorporate our collective learnings back into the FinOps Framework.

In the next few sections, we cover the basic concepts of the FinOps Framework:

- The **principles** that should guide your FinOps efforts.
- The **stakeholders** that should be involved.
- The **lifecycle** that you iterate through.
- The **capabilities** that you implement with stakeholders throughout the lifecycle.
- The **maturity model** that you use to measure growth over time.

<br>

## ⚖️ Principles

Before digging into FinOps, it's important to understand the core principles that should guide your FinOps efforts. The FinOps community developed the principles by applying their collective experience, and helps you create a culture of shared accountability and transparency.

- **Teams need to collaborate** – Build a common focus on cost efficiency, processes and cost decisions across teams that might not typically work closely together.
- **Everyone takes ownership** – Decentralize decisions about cloud resource usage and optimization, and drive technical teams to consider cost as well as uptime and performance.
- **A centralized team drives FinOps** – Centralize management of FinOps practices for consistency, automation, and rate negotiations.
- **FinOps reports should be accessible and timely** – Provide clear usage and cost data quickly, to the right people, to enable prompt decisions and forecasting.
- **Decisions are driven by the business value of cloud** – Balance cost decisions with business benefits including quality, speed, and business capability.
- **Take advantage of the variable cost model of the cloud** – Make continuous small adjustments in cloud usage and optimization.

For more information about FinOps principles, including tips from the experts, see [FinOps with Azure – Bringing FinOps to life through organizational and cultural alignment](https://azure.microsoft.com/resources/finops-with-azure-bringing-finops-to-life-through-organizational-and-cultural-alignment/).

<br>

## 👥 Stakeholders

FinOps requires a holistic and cross-functional approach that involves various stakeholders (or personas). They have different roles, responsibilities, and perspectives that influence how they use and optimize cloud resources and costs. Familiarize yourself with each role and identify the stakeholders within your organization. An effective FinOps program requires collaboration across all stakeholders:

- **Finance** – Accurately budget, forecast, and report on cloud costs.
- **Leadership** – Apply the strengths of the cloud to maximize business value.
- **Product owners** – Launch new offerings at the right price.
- **Engineering teams** – Deliver high quality, cost-effective services.
- **FinOps practitioners** – Educate, standardize, and promote FinOps best practices.

<!--
You can also find related videos on the FinOps Foundation YouTube channel:
{% include video.html title="FinOps personas" id="gXzGwWDQmI0CFrHM" list="PLUSCToibAswkRhkO_PfxqD8et5j0F6VcC" %}
-->

<br>

## ♻️ Lifecycle

FinOps is an iterative, hierarchical process. Every team iterates through the FinOps lifecycle at their own pace, partnering with teams mentioned throughout all areas of the organization.

The FinOps Framework defines a simple lifecycle with three phases:

- **Inform** – Deliver cost visibility and create shared accountability through allocation, benchmarking, budgeting, and forecasting.
- **Optimize** – Reduce cloud waste and improve cloud efficiency by implementing various optimization strategies.
- **Operate** – Define, track, and monitor key performance indicators and governance policies that align cloud and business objectives.

<br>

## 📝 Capabilities

The FinOps Framework includes capabilities that cover everything from cost analysis and monitoring to optimization and organizational alignment, grouped into a set of related domains. Each capability defines a functional area of activity and a set of tasks to support your FinOps practice.

- Understanding cloud usage and cost

  - [Cost allocation](./capabilities/understand/allocation.md)
  - [Data analysis and showback](./capabilities/understand/reporting.md)
  - [Managing shared cost](./capabilities/understand/shared-cost.md)
  - [Data ingestion and normalization](./capabilities/understand/ingestion.md)

- Performance tracking and benchmarking

  - [Measuring unit costs](./capabilities/quantify/unit-economics.md)
  - [Forecasting](./capabilities/quantify/forecasting.md)
  - [Budget management](./capabilities/quantify/budgeting.md)

- Real-time decision making

  - [Managing anomalies](./capabilities/understand/anomalies.md)
  - [Establishing a FinOps decision and accountability structure](./capabilities/manage/structure.md)

- Cloud rate optimization

  - [Managing commitment-based discounts](./capabilities/optimize/rate-optimization.md)

- Cloud usage optimization

  - [Onboarding workloads](./capabilities/manage/onboarding.md)
  - [Resource utilization and efficiency](./capabilities/optimize/utilization-efficiency.md)
  - [Workload management and automation](./capabilities/optimize/workloads.md)

- Organizational alignment

  - [Establishing a FinOps culture](./capabilities/manage/culture.md)
  - [Chargeback and finance integration](./capabilities/manage/invoicing-chargeback.md)
  - [FinOps education and enablement](./capabilities/manage/education.md)
  - [Cloud policy and governance](./capabilities/manage/policy.md)
  - [FinOps and intersecting frameworks](./capabilities/manage/intersecting-disciplines.md)

<br>

## 📏 Maturity model

As teams progress through the FinOps lifecycle, they naturally learn and grow, developing more mature practices with each iteration. Like the FinOps lifecycle, each team is at different levels of maturity based on their experience and focus areas.

The FinOps Framework defines a simple Crawl-Walk-Run maturity model, but the truth is that maturity is more complex and nuanced. Instead of focusing on a global maturity level, we believe it's more important to identify and assess progress against your goals in each area. At a high level, you will:

1. Identify the most critical capabilities for your business.
2. Define how important it is that each team has knowledge, process, success metrics, organizational alignment, and automation for each of the identified capabilities.
3. Evaluate each team's current knowledge, process, success metrics, organizational alignment, and level of automation based on the defined targets.
4. Identify steps that each team could take to improve maturity for each capability.
5. Set up regular check-ins to monitor progress and reevaluate the maturity assessment every 3-6 months.

<br>

## 🍎 Learn more at the FinOps Foundation

FinOps Foundation offers many resources to help you learn and implement FinOps. Join the FinOps community, explore training and certification programs, participate in community working groups, and more. For more information about FinOps, including useful playbooks, see the [FinOps Framework documentation](https://finops.org/framework).

<br>

## ⏩ Next steps

Start your first or plan your next iteration:

- [Conduct a FinOps iteration](../conduct-an-iteration.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="0" gov="1" hubs="1" opt="1" pbi="1" ps="0" %}

<br>
