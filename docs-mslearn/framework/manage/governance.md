---
title: Cloud policy and governance
description: This article helps you understand the cloud policy and governance capability within the FinOps Framework and how to implement that in the Microsoft Cloud.
author: bandersmsft
ms.author: banders
ms.date: 08/15/2024
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
# customer intent: As a FinOps practitioner, I want to understand the cloud policy and governance capability so that I can implement it in the Microsoft Cloud.
---

<!-- markdownlint-disable-next-line MD025 -->
# Cloud policy and governance

This article helps you understand the cloud policy and governance capability within the FinOps Framework and how to implement that in the Microsoft Cloud.

<br>

## Definition

**Cloud policy and governance refers to the process of defining, implementing, and monitoring a framework of rules that guide an organization's FinOps efforts.**

Define your governance goals and success metrics. Review and document how existing policies are updated to account for FinOps efforts. Review with all stakeholders to get buy-in and endorsement.

Establish a rollout plan that starts with audit rules and slowly (and safely) expands coverage to drive compliance without negatively impacting engineering efforts.

Implementing a policy and governance strategy enables organizations to sustainably implement FinOps at scale. Policy and governance can act as a multiplier to FinOps efforts by building them natively into day-to-day operations.

<br>

## Getting started

When you first start managing cost in the cloud, you use the native compliance tracking and enforcement tools.

- Review your existing FinOps processes to identify opportunities for policy to automate enforcement. Some examples:
  - [Enforce your tagging strategy](/azure/governance/policy/tutorials/govern-tags) to support different capabilities, like:
    - Organizational reporting hierarchy tags for [allocation](../understand/allocation.md).
    - Financial reporting tags for [chargeback](./invoicing-chargeback.md).
    - Environment and application tags for [workload management](../optimize/workloads.md).
    - Business and application owners for [anomalies](../understand/anomalies.md).
  - Monitor required and suggested alerting for [anomalies](../understand/anomalies.md) and [budgets](../quantify/budgeting.md).
  - Block or audit the creation of more expensive resource SKUs (for example, E-series virtual machines).
  - Implementation of cost recommendations and unused resources for [utilization and efficiency](../optimize/workloads.md).
  - Application of Azure Hybrid Benefit for [utilization and efficiency](../optimize/workloads.md).
  - Monitor [commitment discounts](../optimize/rates.md) coverage.
- Identify what policies can be automated through [Azure Policy](/azure/governance/policy/overview) and which need other tooling.
- Review and [implement built-in policies](/azure/governance/policy/assign-policy-portal) that align with your needs and goals.
- Start small with audit policies and expand slowly (and safely) to ensure engineering efforts aren't negatively impacted.
  - Test rules before you roll them out and consider a staged rollout where each stage has enough time to get used and garner feedback. Start small.

<br>

## Building on the basics

At this point, you have a basic set of policies in place that are being managed across the organization. As you move beyond the basics, consider the following points:

- Formalize compliance reporting and promote within leadership conversations across stakeholders.
  - Map governance efforts to FinOps efficiencies that can be mapped back to more business value with less effort.
- Expand coverage of more scenarios.
  - Consider evaluating ways to quantify the impact of each rule in cost and/or business value.
- Integrate policy and governance into every conversation to establish a plan for how you want to automate the tracking and application of new policies.
- Consider advanced governance scenarios outside of Azure Policy. Build monitoring solutions using systems like [Power Automate](/power-automate/getting-started) or [Logic Apps](/azure/logic-apps/logic-apps-overview).

<br>

## Learn more at the FinOps Foundation

This capability is a part of the FinOps Framework by the FinOps Foundation, a non-profit organization dedicated to advancing cloud cost management and optimization. For more information about FinOps, including useful playbooks, training and certification programs, and more, see the [Cloud policy and governance capability](https://www.finops.org/framework/capabilities/policy-governance/) article in the FinOps Framework documentation.

You can also find related videos on the FinOps Foundation YouTube channel:

> [!VIDEO https://www.youtube.com/embed/wiqCovCttOc?list=PLUSCToibAswnr2q_J-kn7Yii1CO2-PU35]

<br>

## Related content

Related FinOps capabilities:

- [FinOps practice operations](./operations.md)
- [Workload optimization](../optimize/workloads.md)

Related products:

- [Azure Policy](/azure/governance/policy/)
- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [Governance workbook](https://microsoft.github.io/finops-toolkit/workbooks/governance)

Other resources:

- [Cloud Adoption Framework](/azure/cloud-adoption-framework/)
- [Well-Architected Framework](/azure/well-architected/)

<br>
