---
layout: default
parent: Power BI
title: Governance
nav_order: 21
description: 'Summarize cloud governance posture including areas like compliance, security, operations, and resource management in Power BI.'
permalink: /power-bi/governance
---

<span class="fs-9 d-block mb-4">Governance report</span>
Summarize cloud governance posture including areas like compliance, security, operations, and resource management in Power BI.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](./README.md#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Get started](#get-started)
- [Summary](#summary)
- [Policy compliance](#policy-compliance)
- [Virtual machines](#virtual-machines)
- [Managed disks](#managed-disks)
- [SQL databases](#sql-databases)
- [Network security groups](#network-security-groups)
- [See also](#see-also)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **Governance report** summarizes your Microsoft Cloud governance posture. It offers standard metrics aligned with the Cloud Adoption Framework to facilitate identifying issues, applying recommendations, and resolving compliance gaps.

The CAF Govern methodology provides a structured approach for establishing and optimizing cloud governance in Azure. The guidance is relevant for organizations across any industry. It covers essential categories of cloud governance, such as regulatory compliance, security, operations, cost, data, resource management, and artificial intelligence (AI).
Cloud governance is how you control cloud use across your organization. Cloud governance sets up guardrails that regulate cloud interactions. These guardrails are a framework of policies, procedures, and tools you use to establish control. Policies define acceptable and unacceptable cloud activity, and the procedures and tools you use ensure all cloud usage aligns with those policies. Successful cloud governance prevents all unauthorized or unmanaged cloud usage.
To assess your transformation journey, try the [governance benchmark tool](https://learn.microsoft.com/assessments/b1891add-7646-4d60-a875-32a4ab26327e/?WT.mc_id=FinOpsToolkit).

This report pulls data from:

- Cost Management exports or FinOps hubs
- Azure Resource Graph

You can download the Governance report from the [latest release](https://github.com/microsoft/finops-toolkit/releases).

<blockquote class="note" markdown="1">
_The Governance report is new and still being fleshed out. We will continue to expand capabilities in each release in alignment with the [Cost optimization workbook](../../_optimize/optimization-workbook/README.md). To request additional capabilities, please [create a feature request](https://aka.ms/ftk/ideas) in GitHub._
</blockquote>

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

> ![Screenshot of the Get started page](https://github.com/user-attachments/assets/d4b699cd-72c8-453c-9d54-7c1b6dbb155c)

<br>

## Summary

The **Summary** page provides a summary of subscriptions, resource types, resources, and regions across your environment.

> ![Screenshot of the Summary page](https://github.com/user-attachments/assets/46ded4d2-51c6-4a7f-9e24-35edc3d6ce56)

<br>

## Policy compliance

The **Policy compliance** page lists policies configured in Azure Policy for the selected subscriptions.

> ![Screenshot of the Policy compliance page](https://github.com/user-attachments/assets/338d6648-fd78-4aa4-b56e-858e0fcc5873)

<br>

## Virtual machines

The **Virtual machines** page lists the virtual machines, disks, and public IP addresses with related right-sizing recommendations.

> ![Screenshot of the Virtual machines page](https://github.com/user-attachments/assets/4f055d3c-a368-4f0d-8b0d-c16049bc79ea)

<br>

## Managed disks

The **Managed disks** page lists the managed disks.

> ![Screenshot of the Managed disks page](https://github.com/user-attachments/assets/7cec9e2b-d597-43d0-810a-6762aa9a82e0)

<br>

## SQL databases

The **SQL databases** page lists the SQL databases.

The chart shows the cost of each disk over time. The table shows the disks with related properties, including billed and effective cost and the dates the disk was available during the selected date range in the Charge period filter at the top-left of the page.

> ![Screenshot of the SQL databases page](https://github.com/user-attachments/assets/3aaf5ce2-cd88-40e1-a82c-b4e292cd0692)

<br>

## Network security groups

The **Network security groups** page lists network security groups and NSG rules.

> ![Screenshot of the Network security groups page](https://github.com/user-attachments/assets/c333c694-8c4d-4656-a0cb-3beeb94f6e70)

<br>

## See also

- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
