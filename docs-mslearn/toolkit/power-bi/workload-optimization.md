---
title: Workload optimization report
description: Summarize workload optimization opportunities like rightsizing and unused resources in Power BI.
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Workload optimization report

The **Workload optimization report** provides insights into resource utilization and efficiency opportunities based on historical usage patterns. This report enables you to:

- Identify unattached disks.

This report pulls data from:

- Cost Management exports or FinOps hubs
- Azure Resource Graph

You can download the Workload optimization report from the [latest release](https://github.com/microsoft/finops-toolkit/releases).

> [!NOTE]
> The Workload optimization report is new and still being fleshed out. We will continue to expand capabilities in each release in alignment with the [Cost optimization workbook](../optimization-workbook/cost-optimization-workbook.md). To request additional capabilities, please [create a feature request](https://aka.ms/ftk/ideas) in GitHub.

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

![Screenshot of the Unattached disks page](https://github.com/user-attachments/assets/e81cc448-9090-47f4-b990-daded98a17d8)

<br>

<!-- TODO: Uncomment when files are added
## See also

- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>
-->

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea)

<br>
