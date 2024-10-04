---
title: Power BI
description: Accelerate your FinOps reporting with Power BI starter kits.
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Power BI reports

The FinOps toolkit Power BI reports provide a great starting point for your FinOps reporting. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed. You can also copy and paste visuals between reports to create your own custom reports.

FinOps toolkit reports support several ways to connect to your cost data. We generally recommend starting with Cost Management exports, which supports up to $2-5 million in monthly spend depending on your Power BI license. If you experience data refresh timeouts or need to report on data across multiple directories or tenants, please use [FinOps hubs](../hubs/finops-hubs-overview.md), a data pipeline solution that optimizes data and offers additional functionality. For additional details and help choosing the right backend, see [Help me choose](./help-me-choose.md).

Please note support for the [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) is available for backwards compatibility but is not recommended. There are no plans to update the Cost Management connector or the Cost Management app for Enterprise Agreement accounts. The Cost Management team recommends exporting data and leveraging the Azure Data Lake Storage Gen2 connector to build custom reports. The FinOps toolkit reports do this for you and normalize data across Enterprise Agreement and Microsoft Customer Agreement accounts.

<br>

## Available reports

The FinOps toolkit includes two sets of reports that connect to different data sources. We recommend using the following reports which connect to Cost Management exports or [FinOps hubs](../hubs/finops-hubs-overview.md):

- [Cost summary](./cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Data ingestion](./data-ingestion.md) – Provides insights into your data ingestion layer.
- [Rate optimization](./rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.

The following reports use the Cost Management connector for Power BI to connect to your data. While the connector is not recommended due to the reasons below, these reports will be available as long as the connector is supported by the Cost Management team.

- [Cost Management connector](./connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for EA and MCA accounts.
- [Cost Management template app](./template-app.md) (EA only) – The original Cost Management template app as a customizable PBIX file.

[Download reports](https://github.com/microsoft/finops-toolkit/releases/latest)

<br>

## Connect to your data

All FinOps toolkit reports, come with sample data to explore without connecting to your account. Reports have a built-in tutorial to help you connect to your data.

1. Select the **Transform data** button (table with a pencil icon) in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

2. Select **Queries** > **🛠️ Setup** > **▶ START HERE** and follow the instructions.

   Make sure you have the [Storage Blob Data Reader role](/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) on the storage account so you can access the data.

   ![Screenshot of instructions to connect to a storage account](https://github.com/user-attachments/assets/3723c94b-d853-420e-9101-98d1ca518fa0)

3. Select **Close & Apply** in the toolbar and allow Power BI to refresh to see your data.

For more details, see [How to setup Power BI](./setup.md).

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
