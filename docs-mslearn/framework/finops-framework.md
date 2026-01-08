---
title: FinOps Framework overview
description: 'Learn about what the FinOps Framework is and how you can use it to accelerate your cost management and optimization goals.'
author: flanakin
ms.author: micflan
ms.date: 04/25/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: kedelaro
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps Framework

Learn about what the FinOps Framework is and how you can use it to accelerate your cost management and optimization goals.

The [FinOps Framework](https://finops.org/framework) by the FinOps Foundation is a comprehensive set of best practices and principles. It provides a structured approach to implement a FinOps culture to:

- Help organizations manage their cloud costs more effectively
- Align cloud spending with business goals
- Drive greater business value from their cloud infrastructure

Microsoft's guidance is largely based on the FinOps Framework with a few enhancements based on the lessons learned from our vast ecosystem of Microsoft Cloud customers and partners. These extensions map cleanly back to FinOps Framework concepts and are intended to provide more targeted, actionable guidance for Microsoft Cloud customers and partners. We're working with the FinOps Foundation to incorporate our collective learnings back into the FinOps Framework.

In the next few sections, we cover the basic concepts of the FinOps Framework:

- The **principles** that should guide your FinOps efforts.
- The **scopes** to which you apply FinOps concepts.
- The **stakeholders** that should be involved.
- The **lifecycle** that you iterate through.
- The **capabilities** that you implement with stakeholders throughout the lifecycle.
- The **maturity model** that you use to measure growth over time.

<br>

## Principles

Before digging into FinOps, it's important to understand the core principles that should guide your FinOps efforts. The FinOps community developed the principles by applying their collective experience to help you create a culture of shared accountability and transparency.

- **Teams need to collaborate** – Build a common focus on cost efficiency, processes, and cost decisions across teams that might not typically work closely together.
- **Business value drives technology decisions** – Balance cost decisions with business benefits including quality, speed, and business capability.
- **Everyone takes ownership for their technology usage** – Decentralize decisions about cloud resource usage and optimization, and drive technical teams to consider cost as well as uptime and performance.
- **FinOps data should be accessible, timely, and accurate** – Provide clear usage and cost data quickly, to the right people, to enable prompt decisions and forecasting.
- **FinOps should be enabled centrally** – Centralize management of FinOps practices for consistency, automation, and rate negotiations.
- **Take advantage of the variable cost model of the cloud** – Make continuous small adjustments in cloud usage and optimization.

For more information about FinOps principles, including tips from the experts, see [FinOps with Azure – Bringing FinOps to life through organizational and cultural alignment](https://azure.microsoft.com/resources/finops-with-azure-bringing-finops-to-life-through-organizational-and-cultural-alignment/).

<br>

## Scopes

FinOps scopes conceptually represent the boundaries for which you apply your FinOps efforts. Your scope indicates the usage, spend, and sustainability management area of responsibility your team covers. This area of responsibility may also identify which personas are involved and what capabilities apply. Your team's scope is generally defined by and aligned with your organization's strategic goals and operational needs.

The scope or area of responsibility of your FinOps efforts may cover multiple technologies and platforms. Examples of things that may be part of your scope include, but are not limited to:

- Public, private, and hybrid clouds.
- Data centers.
- Cloud-based services offered by third-party providers (often referred to as "SaaS providers").
- Professional services, like consulting and training.

Your scope may also be a subset of these, if you focus solely on a single technology or even service. For instance, a team that only manages SQL databases may have a smaller area of responsibility than one that manages networking infrastructure for a global, multi-national company.

Ultimately, scopes represent what your team is responsible for managing or supporting, which impacts:

- What you need to know.
- Standards and processes you may need to apply to establish consistent execution and governance.
- Metrics and key performance indicators (KPIs) you need to measure success.
- What level of adoption you should target and expect within your organization.
- If and how you might automate tasks and processes to streamline your goals.

Your scope is determined based on your organization's business and technology needs and strategy to facilitate efficient execution of your FinOps practice to achieve your FinOps goals.

<br>

## Stakeholders

FinOps requires a holistic and cross-functional approach that involves various stakeholders (or personas). They have different roles, responsibilities, and perspectives that influence how they use and optimize cloud resources and costs. Familiarize yourself with each role and identify the stakeholders within your organization. An effective FinOps program requires collaboration across all stakeholders:

- Core stakeholders:
  - **Procurement** – Source and purchase necessary resources, negotiate contracts, and managing vendor relationships.
  - **Finance** – Accurately budget, forecast, and report on cloud costs.
  - **Leadership** – Apply the strengths of the cloud to maximize business value.
  - **Business owners** – Drives strategic decision-making, budgeting, and understanding the financial impact of operational decisions.
  - **Product owners** – Define and prioritize the product backlog, aligning it with user needs and business value.
  - **Engineering teams** – Deliver high quality, cost-effective services.
  - **FinOps practitioners** – Educate, standardize, and promote FinOps best practices.
- Allied stakeholders:
  - **Sustainability practitioners** – Manage and reduce the environmental impact of the cloud resources.
  - **ITFM/TBM teams** (Information Technology Financial Management / Technology Business Management) – Cost management beyond cloud infrastructure and services.
  - **ITSM/ITIL teams** (Information Technology Service Management / Information Technology Infrastructure Library) – Align IT services with business needs and deliver/support IT services that meet business goals.
  - **ITAM teams** (Information Technology Asset Management) – Manage and optimize the purchase, deployment, maintenance, utilization, and disposal of software and hardware assets.
  - **Security teams** – Ensure cloud operations and systems adhere to organizational security standards and policies.

<!--
You can also find related videos on the FinOps Foundation YouTube channel:
{% include video.html title="FinOps personas" id="gXzGwWDQmI0CFrHM" list="PLUSCToibAswkRhkO_PfxqD8et5j0F6VcC" %}
-->

<br>

## Lifecycle

FinOps is an iterative, hierarchical process. Every team iterates through the FinOps lifecycle at their own pace, partnering with teams mentioned throughout all areas of the organization.

The FinOps Framework defines a simple lifecycle with three phases:

- **Inform** – Deliver cost visibility and create shared accountability through allocation, benchmarking, budgeting, and forecasting.
- **Optimize** – Reduce cloud waste and improve cloud efficiency by implementing various optimization strategies.
- **Operate** – Define, track, and monitor key performance indicators and governance policies that align cloud and business objectives.

<br>

## Capabilities

The FinOps Framework includes capabilities that cover everything you need to perform FinOps tasks and manage a FinOps practice. Capabilities are organized into a set of related domains based on the goals of the capabilities. Each capability defines a functional area of activity and a set of tasks to support your FinOps practice.

- Understand usage and cost

  - [Data ingestion](./understand/ingestion.md)
  - [Allocation](./understand/allocation.md)
  - [Reporting and analytics](./understand/reporting.md)
  - [Anomaly management](./understand/anomalies.md)

- Quantify business value

  - [Planning and estimating](./quantify/planning.md)
  - [Forecasting](./quantify/forecasting.md)
  - [Budgeting](./quantify/budgeting.md)
  - [Benchmarking](./quantify/benchmarking.md)
  - [Unit economics](./quantify/unit-economics.md)

- Optimize usage and cost

  - [Architecting for the cloud](./optimize/architecting.md)
  - [Workload optimization](./optimize/workloads.md)
  - [Rate optimization](./optimize/rates.md)
  - [Licensing and SaaS](./optimize/licensing.md)
  - [Cloud sustainability](./optimize/sustainability.md)

- Manage the FinOps practice

  - [FinOps education and enablement](./manage/education.md)
  - [FinOps practice operations](./manage/operations.md)
  - [Onboarding workloads](./manage/onboarding.md)
  - [Policy and governance](./manage/governance.md)
  - [Invoicing and chargeback](./manage/invoicing-chargeback.md)
  - [FinOps assessment](./manage/assessment.md)
  - [FinOps tools and services](./manage/tools-services.md)
  - [Intersecting frameworks](./manage/intersecting-disciplines.md)

<br>

## Maturity model

As teams progress through the FinOps lifecycle, they naturally learn and grow, developing more mature practices with each iteration. Like the FinOps lifecycle, each team is at different levels of maturity based on their experience and focus areas.

The FinOps Framework defines a simple Crawl-Walk-Run maturity model, but the truth is that maturity is more complex and nuanced. Instead of focusing on a global maturity level, we believe it's more important to identify and assess progress against your goals in each area. At a high level, you will:

1. Identify the most critical capabilities for your business.
2. Define how important it is that each team has knowledge, process, success metrics, organizational alignment, and automation for each of the identified capabilities.
3. Evaluate each team's current knowledge, process, success metrics, organizational alignment, and level of automation based on the defined targets.
4. Identify steps that each team could take to improve maturity for each capability.
5. Set up regular check-ins to monitor progress and reevaluate the maturity assessment every 3-6 months.

<br>

## Learn more at the FinOps Foundation

FinOps Foundation offers many resources to help you learn and implement FinOps. Join the FinOps community, explore training and certification programs, participate in community working groups, and more. For more information about FinOps, including useful playbooks, see the [FinOps Framework documentation](https://finops.org/framework).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.Framework/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Start your first or plan your next iteration:

- [Conduct a FinOps iteration](../conduct-iteration.md)

<br>
