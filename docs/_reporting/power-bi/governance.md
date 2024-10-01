---
layout: default
parent: Power BI
title: Governance
nav_order: 21
description: 'Summarize cloud governance posture including areas like compliance, security, operations, and resource management in Power BI.'
permalink: /power-bi/workload-optimization
---

<span class="fs-9 d-block mb-4">Governance report</span>
Summarize cloud governance posture including areas like compliance, security, operations, and resource management in Power BI.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/Governance.pbix){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
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

The **Governance report** provides insights into resource utilization and efficiency opportunities based on historical usage patterns. This report enables you to:

- Identify unattached disks.


Overview of the Cloud Adoption Framework

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

> ![Screenshot of the Summary page](https://github.com/user-attachments/assets/4376b964-f1b7-4fee-819a-7a40e3e07e06)

<br>

## Policy compliance

The **Policy compliance** page lists policies configured in Azure Policy for the selected subscriptions.

> ![Screenshot of the Policy compliance page](https://github.com/user-attachments/assets/3b91565f-f25e-474f-ad93-978df3d4937c)

<br>

## Virtual machines

The **Virtual machines** page lists the virtual machines, disks, and public IP addresses with related right-sizing recommendations.

> ![Screenshot of the Virtual machines page](https://github.com/user-attachments/assets/d951df9a-3f5b-4294-b48e-840cb4901add)

<br>

## Managed disks

The **Managed disks** page lists the managed disks.

> ![Screenshot of the Managed disks page](https://github.com/user-attachments/assets/545fd571-5753-4705-881a-b27e65269f13)

<br>

## SQL databases

The **SQL databases** page lists the SQL databases.

The chart shows the cost of each disk over time. The table shows the disks with related properties, including billed and effective cost and the dates the disk was available during the selected date range in the Charge period filter at the top-left of the page.

> ![Screenshot of the SQL databases page](https://github.com/user-attachments/assets/7da6e086-a6c1-44e2-a70b-b72df6bac346)

<br>

## Network security groups

The **Network security groups** page lists network security groups and NSG rules.

> ![Screenshot of the Network security groups page](https://github.com/user-attachments/assets/ac522ccc-4ab3-4819-b1c0-bf1252ff1cdd)

<br>

## See also

- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
