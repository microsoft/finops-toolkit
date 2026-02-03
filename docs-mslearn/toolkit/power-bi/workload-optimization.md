---
title: FinOps toolkit Workload optimization report
description: Learn about the Workload optimization report, which identifies opportunities for rightsizing and removing unused resources to enhance efficiency.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a As a FinOps user, I want to learn about the Workload optimization report so that I can identify and eliminate inefficiencies in my cloud resource usage.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Workload optimization report

> [!WARNING]
> **This report is being retired**
>
> The Workload optimization report will be retired on December 31, 2025, and will no longer be supported. We recommend using the Azure Advisor Cost Optimization workbook instead, which provides similar capabilities with more features and ongoing support.
>
> ### View the Cost optimization workbook in Advisor
>
> 1. Sign in to the [Azure portal](https://portal.azure.com/).
> 2. Search for Azure Advisor.
> 3. In the left navigation menu, select **Workbooks**.
> 4. In the Workbooks Gallery, select the **Cost Optimization (Preview)** workbook template.
> 5. Select an area to explore.

The **Workload optimization report** provides insights into resource utilization and efficiency opportunities based on historical usage patterns. This report helps you:

- Identify unattached disks

This report pulls data from:

- Cost Management exports or FinOps hubs
- Azure Resource Graph

The Workload optimization report is new and still in development. We will continue to expand capabilities in each release in alignment with the [Cost optimization workbook](../workbooks/optimization.md). To request other capabilities, [create a feature request](https://aka.ms/ftk/ideas) in GitHub.

> [!div class="nextstepaction"]
> [Download for KQL](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)
> [!div class="nextstepaction"]
> [Download for storage](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)

Power BI reports are provided as template (.PBIT) files. Template files are not preconfigured and do not include sample data. When you first open a Power BI template, you will be prompted to specify report parameters, then authenticate with each data source to view your data. To access visuals and queries without loading data, select Edit in the Load menu button.

<br>

## Export requirements

Before using this report, you need to configure Cost Management exports to provide the necessary data. The following exports are required or recommended:

| Dataset                     | Version          | Requirement | Notes                                                                                             |
| --------------------------- | ---------------- | ----------- | ------------------------------------------------------------------------------------------------- |
| Cost and usage (FOCUS)      | `1.0` or `1.0r2` | **Required** | Provides the primary cost and usage data for resource cost analysis.                            |
| Price sheet                 | `2023-05-01`     | Recommended | Required to populate missing prices for EA and MCA accounts to show accurate cost calculations.  |
| Azure Resource Graph        | Latest           | **Required** | Required to gather resource metadata for workload optimization analysis.                        |

For instructions on how to create Cost Management exports, see [Create and manage exports](/azure/cost-management-billing/costs/tutorial-improved-exports). If using FinOps hubs, these exports can be configured automatically.

<br>

## Get started

The **Get started** page includes a basic introduction to the report with links to learn more.

For instructions on how to connect this report to your data, including details about supported parameters, select the **Connect your data** button. Hold <kbd>Ctrl</kbd> when clicking the button in Power BI Desktop. If you need assistance, select the **Get help** button.

:::image type="content" source="./media/workload-optimization/get-started.png" border="true" alt-text="Screenshot of the Get started page that shows basic information and links to learn more." lightbox="./media/workload-optimization/get-started.png" :::

<br>

## Recommendations

The **Recommendations** page provides a list of Azure Advisor cost recommendations, similar to what you see in the Azure portal. There are currently no details available in the report. Details will be added in a future release.

:::image type="content" source="./media/workload-optimization/advisor-recommendations.png" border="true" alt-text="Screenshot of the Recommendations page that shows a list of Azure Advisor cost recommendations." lightbox="./media/workload-optimization/advisor-recommendations.png" :::

<br>

## Unattached disks

The **Unattached disks** page lists the unattached disks sorted by cost.

The chart shows the cost of each disk over time. The table shows the disks with related properties. It includes billed and effective cost and the dates the disk was available during the selected date range. The date range is shown in the Charge period filter at the top-left of the page.

:::image type="content" source="./media/workload-optimization/unattached-disks.png" border="true" alt-text="Screenshot of the Unattached disks page that shows unattached disks sorted by cost." lightbox="./media/workload-optimization/unattached-disks.png" :::

<br>

<!-- TODO: Uncomment when files are added
## See also

- [Common terms](../../_resources/terms.md)
- [Data dictionary](../../_resources/data-dictionary.md)

<br>
-->

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps alerts](../alerts/finops-alerts-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
