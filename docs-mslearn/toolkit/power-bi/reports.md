---
title: FinOps toolkit Power BI reports
description: Learn about the Power BI reports in the FinOps toolkit to customize and enhance your FinOps reporting and connect to Cost Management exports or FinOps hubs.
author: bandersmsft
ms.author: banders
ms.date: 12/03/2024
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

The FinOps toolkit includes reports that connect to different data sources. We recommend using the following reports that connect to Cost Management exports or [FinOps hubs](../hubs/finops-hubs-overview.md):

- [Cost summary](cost-summary.md) – Overview of amortized costs with common breakdowns.
- [Rate optimization](rate-optimization.md) – Summarizes existing and potential savings from commitment discounts.
- [Workload optimization](workload-optimization.md) – Summarizes opportunities to achieve resource cost and usage efficiencies.
- [Cloud policy and governance](governance.md) – Summarize cloud governance posture including areas like compliance, security, operations, and resource management.
- [Data ingestion](data-ingestion.md) – Provides insights into your data ingestion layer.

If you need to monitor more than $2 million in spend, we generally recommend using Kusto Query Language (KQL) reports that connect to [FinOps hubs](../hubs/finops-hubs-overview.md) with Azure Data Explorer. As of November 2024, only the Cost summary and Rate optimization reports connect to Data Explorer. More reports will come in future updates. Organizations who need other reports can continue to connect to the underlying hub storage account.

In addition, the following reports use the Cost Management connector for Power BI to connect to your data. While the connector isn't recommended due to performance and scalability, these reports are also available for Enterprise Agreement (EA) and Microsoft Customer Agreement (MCA) accounts.

- [Cost Management connector](connector.md) – Summarizes costs, savings, and commitment discounts using the Cost Management connector for Enterprise Agreements and Microsoft Customer Agreement accounts.
- [Cost Management template app](template-app.md) (EA only) – The original Cost Management template app as a customizable .pbix file.

> [!div class="nextstepaction"]
> [Download demo](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip)

<br>

## Connect to your data

The FinOps toolkit includes three sets of reports. [Demo reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip) include sample data to explore without connecting to your account. When you're ready to connect to your account, download the correct report template:

| Data source                                | Download                                                                                                                             | Notes                                                                                                    |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| FinOps hubs with Data Explorer             | [KQL reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)                                  | Recommended when monitoring more than $2 million per month or more than 13 months of data.               |
| Exports in storage (including FinOps hubs) | [Storage reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)                          | Not recommended when monitoring more than $2 million per month.                                          |
| Cost Management connector                  | [Cost Management connector report](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostManagementConnector.zip) | Not recommended when monitoring more than $1M in total cost or accounts that contain savings plan usage. |

Configure FinOps hubs or Cost Management exports with KQL or storage reports. For FinOps hubs, refer to [Configure scopes](../hubs/configure-scopes.md). For Cost Management exports, refer to [How to create exports](/azure/cost-management-billing/costs/tutorial-improved-exports). Power BI reports use the following export types:

- Cost and usage (FOCUS) &ndash; Required for all reports.
- Price sheet
- Reservation details
- Reservation recommendations &ndash; Required to see reservation recommendations in the Rate optimization report.
- Reservation transactions

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
