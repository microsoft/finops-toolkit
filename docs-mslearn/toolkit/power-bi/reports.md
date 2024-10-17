---
title: Power BI reports
description: Learn about the Power BI reports in the FinOps toolkit to customize and enhance your FinOps reporting and connect to Cost Management exports or FinOps hubs.
author: bandersmsft
ms.author: banders
ms.date: 10/10/2024
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about FinOps reports so that I can use them to better understand my cost data.
---

<!-- markdownlint-disable-next-line MD025 -->
# Power BI reports

The FinOps toolkit Power BI reports provide a great starting point for your FinOps reporting. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed. You can also copy and paste visuals between reports to create your own custom reports.

FinOps toolkit reports support several ways to connect to your cost data. We generally recommend starting with Cost Management exports, which support up to $2-5 million in monthly spend depending on your Power BI license. If you experience data refresh timeouts or need to report on data across multiple directories or tenants, use [FinOps hubs](../hubs/finops-hubs-overview.md). It's a data pipeline solution that optimizes data and offers more functionality. For more information about choosing the right backend, see [Help me choose](help-me-choose.md).

Support for the [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) is available for backwards compatibility but isn't recommended. There are no plans to update the Cost Management connector or the Cost Management app for Enterprise Agreement accounts. The Cost Management team recommends exporting data and using the Azure Data Lake Storage Gen2 connector to build custom reports. The FinOps toolkit reports do it for you and normalize data across Enterprise Agreement and Microsoft Customer Agreement accounts.

<br>

## Available reports

The FinOps toolkit includes two sets of reports that connect to different data sources. We recommend using the following reports that connect to Cost Management exports or [FinOps hubs](../hubs/finops-hubs-overview.md):

- [Cost summary](cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Rate optimization](rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.
- [Workload optimization](workload-optimization.md) – Summarizes opportunities to achieve resource cost and usage efficiencies.
- [Cloud policy and governance](governance.md) – Summarize cloud governance posture including areas like compliance, security, operations, and resource management.
- [Data ingestion](data-ingestion.md) – Provides insights into your data ingestion layer.

The following reports use the Cost Management connector for Power BI to connect to your data. While the connector isn't recommended due to the following reasons, these reports are available as long as the Cost Management team supports the connector.

- [Cost Management connector](connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for Enterprise Agreements and Microsoft Customer Agreement accounts.
- [Cost Management template app](template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download reports](https://github.com/microsoft/finops-toolkit/releases/latest)

<br>

## Connect to your data

All FinOps toolkit reports, come with sample data to explore without connecting to your account. Reports have a built-in tutorial to help you connect to your data.

1. Configure Cost Management exports for any data you would like to include in reports, including:

   - Cost and usage (FOCUS) &ndash; Required for all reports.
   - Price sheet
   - Reservation details
   - Reservation recommendations &ndash; Required to see reservation recommendations in the Rate optimization report.
   - Reservation transactions

2. Select the **Transform data** button (table with a pencil symbol) in the toolbar.

   :::image type="content" source="./media/reports/transform-data.png" border="true" alt-text="Screenshot of the Transform data button in the Power BI Desktop toolbar." lightbox="./media/reports/transform-data.png" :::

3. Select **Queries** > **Setup** > **▶ START HERE** and follow the instructions.

   Make sure you have the [Storage Blob Data Reader role](/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) on the storage account so you can access the data.

   :::image type="content" source="./media/reports/start-here.png" border="true" alt-text="Screenshot showing instructions about how to connect to a storage account." lightbox="./media/reports/start-here.png" :::

4. Select **Close & Apply** in the toolbar and allow Power BI to refresh to see your data.

For more information, see [How to setup Power BI](setup.md).

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

[Share feedback](https://aka.ms/ftk/idea)

<br>

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](https://aka.ms/finops/workbooks)
- [FinOps toolkit open data](../open-data.md)

<br>
