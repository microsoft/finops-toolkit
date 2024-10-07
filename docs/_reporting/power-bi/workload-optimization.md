---
layout: default
parent: Power BI
title: Workload optimization
nav_order: 21
description: 'Summarize workload optimization opportunities like rightsizing and unused resources in Power BI.'
permalink: /power-bi/workload-optimization
---

<span class="fs-9 d-block mb-4">Workload optimization report</span>
Summarize workload optimization opportunities like rightsizing and unused resources in Power BI.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest/download/WorkloadOptimization.pbix){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Connect your data](./README.md#-connect-to-your-data){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [Get started](#get-started)
- [Recommendations](#recommendations)
- [Unattached disks](#unattached-disks)
- [See also](#see-also)
- [🙋‍♀️ Looking for more?](#️-looking-for-more)

</details>

---

The **Workload optimization report** provides insights into resource utilization and efficiency opportunities based on historical usage patterns. This report enables you to:

- Identify unattached disks.

This report pulls data from:

- Cost Management exports or FinOps hubs
- Azure Resource Graph

You can download the Workload optimization report from the [latest release](https://github.com/microsoft/finops-toolkit/releases).

<blockquote class="note" markdown="1">
_The Workload optimization report is new and still being fleshed out. We will continue to expand capabilities in each release in alignment with the [Cost optimization workbook](../../_optimize/workbooks/optimization/README.md). To request additional capabilities, please [create a feature request](https://aka.ms/ftk/ideas) in GitHub._
</blockquote>

<br>

## Get started

The **Get started** page includes a basic introduction to the report with additional links to learn more.

![Screenshot of the Get started page](https://github.com/user-attachments/assets/c467d8e2-dd49-4dcf-b5b6-2643a59d57fd)

<br>

## Recommendations

The **Recommendations** page provides a list of Azure Advisor cost recommendations, similar to what you will find in the Azure portal. There are currently no details available. Details will be added in a future release.

![Screenshot of the Recommendations page](https://github.com/user-attachments/assets/d8fbe2c2-424a-45cb-81b2-b3f4e084513e)

<br>

## Unattached disks

The **Unattached disks** page lists the unattached disks sorted by cost.

The chart shows the cost of each disk over time. The table shows the disks with related properties, including billed and effective cost and the dates the disk was available during the selected date range in the Charge period filter at the top-left of the page.

![Screenshot of the Unattached disks page](https://github.com/user-attachments/assets/fc815b6d-3564-466b-8100-b00403440fa4)

<br>

## See also

- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>

## 🙋‍♀️ Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
