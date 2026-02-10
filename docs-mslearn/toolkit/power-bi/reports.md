---
title: FinOps toolkit Power BI reports
description: Learn about the Power BI reports in the FinOps toolkit to customize and enhance your FinOps reporting and connect to Cost Management exports or FinOps hubs.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn about FinOps reports so that I can use them to better understand my cost data.
---

<!-- markdownlint-disable-next-line MD025 -->
# Power BI reports

The FinOps toolkit Power BI reports provide a great starting point for your FinOps reporting. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed. You can also copy and paste visuals between reports to create your own custom reports.

FinOps toolkit reports use data from various sources and support several ways to connect to that data. We generally recommend starting with Cost Management exports, which support up to $2-5 million in monthly spend depending on your Power BI license. If you experience data refresh timeouts or need to report on data across multiple directories or tenants, use [FinOps hubs](../hubs/finops-hubs-overview.md). It's a data pipeline solution that optimizes data and offers more functionality. For more information about choosing the right backend, see [Help me choose](help-me-choose.md).

Support for the [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) is available for backwards compatibility but isn't recommended. There are no plans to update the Cost Management connector or the Cost Management app for Enterprise Agreement accounts. The Cost Management team recommends exporting data and using the Azure Data Lake Storage Gen2 connector to build custom reports. The FinOps toolkit reports do it for you and normalize data across Enterprise Agreement and Microsoft Customer Agreement accounts.

<br>

## Available reports

The FinOps toolkit includes reports that connect to different data sources. We recommend using the following reports that connect to Cost Management exports or [FinOps hubs](../hubs/finops-hubs-overview.md):

- [Cost summary](cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Rate optimization](rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.
- [Invoicing and chargeback](invoicing.md) – Summarizes billed cost trends and facilitates invoice reconciliation and chargeback.
- [Workload optimization](workload-optimization.md) – Summarizes opportunities to achieve resource cost and usage efficiencies.
- [Policy and governance](governance.md) – Summarizes the governance posture including areas like compliance, security, operations, and resource management.
- [Data ingestion](data-ingestion.md) – Provides insights into your data ingestion layer.

If you need to monitor more than $1 million in spend, we generally recommend using Kusto Query Language (KQL) reports that connect to [FinOps hubs](../hubs/finops-hubs-overview.md) with Azure Data Explorer or Microsoft Fabric. Organizations who need other reports can continue to connect to the underlying hub storage account.

> [!div class="nextstepaction"]
> [Download demo](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip)

In addition, the following reports use the Cost Management connector for Power BI to connect to your data. While the connector isn't recommended due to performance and scalability, these reports are also available for Enterprise Agreement (EA) and Microsoft Customer Agreement (MCA) accounts.

- [Cost Management connector](connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for Enterprise Agreements and Microsoft Customer Agreement accounts.
- [Cost Management template app](template-app.md) (EA only) – The original Cost Management template app as a customizable .pbix file.

### Community reports

The FinOps community also contributes specialized Power BI reports for specific use cases and industries. Community reports are maintained by their contributors and are not officially supported by the FinOps toolkit team.

> [!div class="nextstepaction"]
> [Explore community reports](community.md)

<br>

## Data sources

Here's a summary of each data source for the reports. For more information about choosing the right data source for your organization, see [Help me choose](help-me-choose.md).

**Cost Management connector**

It connects to Azure to retrieve usage and charges data for Power BI reports. The connector is available for backwards compatibility but isn't recommended. There are no plans to update the Cost Management connector, so we recommend that you use a different data source.

**Cost Management exports**

Cost Management pushes cost and usage data to Azure Data Lake Storage in your subscription. Power BI will connect to your data using the Azure Data Lake Storage connector.

**FinOps hubs with Azure storage**

Cost Management pushes cost and usage data to Azure Data Lake Storage in your subscription. Power BI will connect to your data using the Azure Data Lake Storage connector. The difference between exports and FinOps hubs is that FinOps hubs include data pipelines to prepare and ingest data. FinOps hubs can also manage Cost Management exports on your behalf or push data to a remote hub instance in another tenant.

If you use more than $2 million in monthly spend, we generally recommend using FinOps hubs with Data Explorer for the best performance.

**FinOps hubs with Azure Data Explorer**

Cost Management pushes cost and usage data to Azure Data Lake Storage in your subscription. FinOps hubs includes an Azure Data Factory pipeline that will prepare, normalize, and ingest data into Azure Data Explorer or Microsoft Fabric Real-Time Intelligence (RTI). Power BI will connect to your data using the Azure Data Explorer connector.

Azure Data Explorer and Microsoft Fabric RTI offer the best performance and additional capabilities, like populating missing prices and costs. We recommend using FinOps hubs with Data Explorer or Microsoft Fabric for the best experience.

**Microsoft Fabric**

While FinOps toolkit Power BI reports don't support Microsoft Fabric yet, you can customize them to connect to data stored in OneLake. Customizing reports to connect to OneLake would require experience with Power Query M language. If looking for data in Microsoft Fabric, we generally recommend using FinOps hubs with Microsoft Fabric Real-Time Intelligence for the best performance and most functionality.

<br>

## Connect to your data

The core reports in the FinOps toolkit are available in two versions. One that connects to Azure storage and another that connects to FinOps hubs with Azure Data Explorer. Each report is focused on a specific FinOps capability and provides the same functionally. The main difference between versions is in performance and scalability for larger datasets. FinOps hubs also provides additional benefits with Data Explorer that streamline reporting by improving data quality and providing more backwards compatibility on top of Cost Management exports.

Reports are provided as Power BI template (.pbit) files that do not include sample data. To explore sample reports without connecting your data, download the [demo reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip). When you're ready to connect to your account, download the set of report templates based on your backend data source.

| Data source                                        | Download                                                                                                                             | Notes                                                                                                    |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| FinOps hubs with Data Explorer or Microsoft Fabric | [KQL reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)                                  | Recommended when monitoring more than $1 million per month or more than 13 months of data.               |
| Exports in storage (including FinOps hubs)         | [Storage reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)                          | Not recommended when monitoring more than $2 million per month.                                          |
| Cost Management connector                          | [Cost Management connector report](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostManagementConnector.zip) | Not recommended when monitoring more than $1M in total cost or accounts that contain savings plan usage. |

Configure FinOps hubs or Cost Management exports with KQL or storage reports. For FinOps hubs, refer to [Configure scopes](../hubs/configure-scopes.md). For Cost Management exports, refer to [How to create exports](/azure/cost-management-billing/costs/tutorial-improved-exports).

### Export requirements

**Before using any Power BI report**, you need to configure the appropriate Cost Management exports. Different reports require different datasets:

| Dataset                     | Version          | Required for reports                                    | Notes                                                                                             |
| --------------------------- | ---------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Cost and usage (FOCUS)      | `1.0` or `1.0r2` | **All reports**                                         | Primary cost and usage data. Required for all functionality.                                     |
| Price sheet                 | `2023-05-01`     | All reports (recommended for accurate pricing)         | Required to populate missing prices for EA and MCA accounts.                                     |
| Reservation details         | `2023-03-01`     | Rate optimization (recommended)                         | Provides detailed reservation usage data for utilization analysis.                              |
| Reservation recommendations | `2023-05-01`     | **Rate optimization** (required for recommendations)   | Required to display reservation purchase recommendations.                                        |
| Reservation transactions    | `2023-05-01`     | Rate optimization, Invoicing (optional)                | Provides reservation purchase and refund details.                                               |

> [!IMPORTANT]
> Each report documentation page includes specific export requirements. Review the "Export requirements" section on each report page before downloading to ensure you have the necessary data configured.

For more information, see [How to setup Power BI](setup.md#set-up-your-first-report).

<br>

## Looking for more?

We'd love to hear about any reports, charts, or general reporting questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new reports.

> [!div class="nextstepaction"]
> [Share feedback](https://aka.ms/ftk/ideas)

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
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
