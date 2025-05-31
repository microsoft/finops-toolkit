---
title: FinOps hubs overview
description: FinOps hubs provide a reliable platform for cost analytics, insights, and optimization, supporting large accounts and organizations.
author: flanakin
ms.author: micflan
ms.date: 05/17/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps hubs are so that I can use them in my organization.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps hubs

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs. FinOps hubs focus on three core design principles:

- **Be the standard**<br>_Strive to be the principal embodiment of the FinOps Framework._
- **Built for scale**<br>_Designed to support the largest accounts and organizations._
- **Open and extensible**<br>_Embrace the ecosystem and prioritize enabling the platform._

FinOps hubs extend Cost Management to provide a scalable platform for advanced data reporting and analytics, through tools like Microsoft Fabric, Azure Data Explorer, and GitHub Copilot. FinOps hubs are a foundation to build your own cost management and optimization solution or augment existing solutions with seamlessly connected AI-powered tools.

:::image type="content" source="media/finops-hubs-overview/architecture.png" border="true" alt-text="Diagram depicting the FinOps hubs architecture with Cost Management exporting data into Data Lake storage, Data Factory transforming and ingesting data into Data Explorer or Fabric, and GitHub Copilot, Power BI reports, and ADX/Fabric dashboards querying data." lightbox="media/finops-hubs-overview/architecture.png" :::

> [!NOTE]
> Estimated cost: Starts at $120/mo + $10/mo per $1M in cost being monitored.
>
> Estimated monthly cost includes $120 for a single-node Azure Data Explorer cluster or $300 for F2 Fabric capacity, plus $10 in Azure storage and processing cost per $1M being monitored. Exact cost will vary based on discounts, data size (we estimate ~20GB per $1M), and Fabric or Power BI license requirements. Cost without Data Explorer or Fabric is $5 per $1M. For details, refer to the [FinOps hub cost estimate](https://aka.ms/finops/hubs/calculator) in the Azure Pricing Calculator.

<br>

> [!div class="nextstepaction"]
> [Create a hub](#create-a-new-hub)

<br>

## Why FinOps hubs?

Many organizations that use Microsoft Cost Management eventually hit a wall where they need some capability that isn't natively available. When they do, their only options are to use one of the many third party tools or build something from scratch. While the cost management tooling ecosystem is rich and vast with many great options, they might be overkill or perhaps they don't solve specific needs. In these cases, organizations export cost data and build a custom solution. But it comes with many challenges, as these organizations aren't staffed with the data engineers needed to design, build, and maintain a scalable data platform. FinOps hubs seek to provide that foundation to streamline efforts in getting up and running with your own homegrown cost management solution.

FinOps hubs streamline implementing the FinOps Framework. They're being designed to scale to meet the largest enterprise needs. And, they're open and extensible to support building custom solutions without the hassle of building the backend data store. FinOps hubs are designed for and by the community. Join the discussion and let us know what you'd like to see next or learn how to contribute and be a part of the team.

> [!div class="nextstepaction"]
> [Join the conversation](https://aka.ms/ftk/discuss)

[Learn how to contribute](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md)

<br>

## Benefits

FinOps hubs provide many benefits over using Cost Management exports:

- Report on cost and usage across multiple accounts and subscriptions in separate tenants.
- Summarize negotiated and commitment discount savings for EA and MCA accounts.
- Run advanced analytical queries and report on year-over-year cost trends in seconds.
- Leverage AI-powered tools, like GitHub Copilot, or build custom agents to accelerate FinOps tasks with an MCP server that understands FinOps and seamlessly connects to your data.
- Ingest data into Microsoft Fabric Real-Time Intelligence (RTI) or Azure Data Explorer (ADX).
- Full alignment with the [FinOps Open Cost and Usage Specification (FOCUS)](../../focus/what-is-focus.md).
- Expanded support for more clouds, accounts, and scopes:
  - Billing and subscription scopes
  - Azure Government
  - Azure China
  - Microsoft Online Services Agreement (MOSA) subscriptions¹
- Extensible via Data Factory, Data Explorer, Fabric, and Power BI capabilities to integrate business or other provider cost data.
- Backwards compatibility as future dataset versions add new or change existing columns.
- Convert exported data to parquet for faster data access.

_¹ MOSA (or pay-as-you-go) subscriptions are only supported in FinOps hubs 0.1.1. FinOps hubs 0.2+ requires FOCUS cost data from Cost Management exports, which aren't supported for MOSA subscriptions. Contact support about transitioning to a Microsoft Customer Agreement account._

<br>

## What's included

The FinOps hub template includes the following resources:

- Optional: Azure Data Explorer (Kusto) or Microsoft Fabric Real-Time Intelligence (RTI) as a scalable datastore for advanced analytics.
- Storage account (Data Lake Storage Gen2) as a staging area for data ingestion.
- Data Factory instance to manage data ingestion and cleanup.
- Key Vault to store the Data Factory system managed identity credentials.

Once deployed, you can query data directly using KQL queries, visualize data using the available Data Explorer dashboards, Fabric Real-Time dashboards, or Power BI reports; or connect to the database or storage account directly from your own tools.

> [!div class="nextstepaction"]
> [See the template](template.md)

<br>

## Explore the FinOps reports

The FinOps toolkit includes five Power BI reports that are available in three sets:

- [PowerBI-demo.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip) includes reports with sample data.
- [PowerBI-kql.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip) for templates that connect to Data Explorer.
- [PowerBI-storage.zip](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip) for templates that connect to the storage account.

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

:::image type="content" source="../power-bi/media/cost-summary/charge-breakdown.png" border="true" alt-text="Screenshot of the Charge breakdown page that shows a breakdown of all charges." lightbox="../power-bi/media/cost-summary/charge-breakdown.png" :::

:::image type="content" source="../power-bi/media/rate-optimization/summary.png" border="true" alt-text="Screenshot of the Summary page that shows cost and savings breakdown." lightbox="../power-bi/media/rate-optimization/summary.png" :::

:::image type="content" source="../power-bi/media/workload-optimization/advisor-recommendations.png" border="true" alt-text="Screenshot of the Recommendations page that shows a list of Azure Advisor cost recommendations." lightbox="../power-bi/media/workload-optimization/advisor-recommendations.png" :::

:::image type="content" source="../power-bi/media/governance/summary.png" border="true" alt-text="Screenshot of the Governance report Summary page that shows a summary of subscriptions, resource types, and other information." lightbox="../power-bi/media/governance/summary.png" :::

> [!div class="nextstepaction"]
> [Browse reports](../power-bi/reports.md)

<br>

## Create a new hub

To create a new FinOps hub, follow these steps:

1. Enable the CostManagementExports and EventGrid resource providers for your subscription.
2. Plan for public or private network routing with your network admins. [Learn more](private-networking.md).
3. Optional: Set up Microsoft Fabric Real-Time Intelligence.
4. Deploy the FinOps hub template.
   - [Deploy to Azure](https://aka.ms/finops/hubs/deploy)
   - [Deploy to Azure Gov](https://aka.ms/finops/hubs/deploy/gov)
   - [Deploy to Azure China](https://aka.ms/finops/hubs/deploy/china) (MCA only)
5. Create exports in Cost Management or grant access to FinOps hubs. [Learn more](configure-scopes.md).
6. Set up the [Data Explorer dashboard](configure-dashboards.md) or [Power BI reports](../power-bi/reports.md#connect-to-your-data).

For more detailed instructions, see [Create and update FinOps hubs](deploy.md). If you run into any issues, refer to the [Troubleshooting guide](../help/troubleshooting.md).

<br>

## Get started with hubs

After you deploy a hub instance, there are several ways for you to get started:

- Customize the prebuilt Power BI reports.

  Our Power BI reports are starter templates and intended to be customized. We encourage you to customize as needed. [Learn more](../power-bi/reports.md).

- Create your own Power BI reports.

  If you want to create your own reports or add cost data to an existing report, you can [copy queries from a prebuilt report](../power-bi/setup.md#copy-queries-from-a-toolkit-report). Or you can connect manually using the Azure Data Lake Storage Gen2 connector.

- Access the cost data from custom tools.

  Data is stored in [Azure Data Explorer](/azure/data-explorer) or [Microsoft Fabric Real-Time Intelligence](/fabric/real-time-intelligence) and [Azure Data Lake Storage Gen2](/azure/storage/blobs/data-lake-storage-introduction). You can use any tool that supports one of these platforms. Refer to the [data dictionary](../help/data-dictionary.md) for details about available columns.

- Apply cost allocation logic, augment, or manipulate your cost data using Data Factory.

  [Data Factory](/azure/data-factory/introduction) is used to ingest and transform data. We recommend using Data Factory as a cost-efficient solution to apply custom logic to your cost data. Don't modify built-in pipelines or data in the **msexports** container. If you create custom pipelines, monitor new data in the **ingestion** container and use a consistent prefix to ensure they don't overlap with new pipelines. Refer to [data processing](./data-processing.md) for details about how data is processed.

   > [!IMPORTANT]
   > Keep in mind this is the primary area we are planning to evolve in [upcoming FinOps toolkit releases](../roadmap.md). Get familiar the roadmap to avoid conflicts with future updates. Consider [contributing to the project](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md) to add support for new scenarios to avoid conflicts.

- Generate custom alerts using Power Automate.

  You have many options for generating custom alerts. [Power Automate](https://powerautomate.microsoft.com/connectors/details/shared_azureblob/azure-blob-storage) is a great option for people who are new to automation. You can also use [Data Factory](/azure/data-factory/introduction), [Functions](/azure/azure-functions/functions-overview), or any other service that supports custom code or direct access to data in Azure Data Lake Storage Gen2.

For additional examples, see [Creating custom analyses and reports with FinOps hubs](https://techcommunity.microsoft.com/blog/finopsblog/creating-custom-analyses-and-reports-with-finops-hubs/4408601).

No matter what you choose to do we recommend creating a new Bicep module to support updating your solution. You can reference `finops-hub/main.bicep` or `hub.bicep` directly to ensure you can apply new updates as they're released.

If you need to change `hub.bicep`, be sure to track those changes and reapply them when upgrading to the latest release. We generally don't recommend modifying the template or modules directly to avoid conflicts with future updates. Instead, consider contributing those changes back to the open source project. [Learn more](https://github.com/microsoft/finops-toolkit/blob/main/CONTRIBUTING.md).

If you access data in storage or are creating or customizing Power BI reports, please refer to the [data dictionary](../help/data-dictionary.md) for details about the available columns.

<br>

## Required permissions

Configuring and managing FinOps hubs requires the following permissions:

- Configuring exports requires one of the following, depending on scope:
  - Subscriptions and resource groups: [Cost Management Contributor](/azure/role-based-access-control/built-in-roles#cost-management-contributor).
  - EA billing scopes: Enterprise Reader, Department Reader, or Account Owner (also known as enrollment account).
  - MCA billing scopes: Contributor on the billing account, billing profile, or invoice section.
  - MPA billing scopes: Contributor on the billing account, billing profile, or customer.
- Deploying the FinOps hubs template requires one of the following:
  - [Contributor](/azure/role-based-access-control/built-in-roles#contributor) and [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator)
  - [Owner](/azure/role-based-access-control/built-in-roles#owner)
  - For least-privileged access, see  [template details](template.md#prerequisites).
- Configuring Power BI requires one of the following
  - Storage reports: [Storage Blob Data Reader](/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-reader) or SAS token
  - KQL reports: Viewer on the Hub and Ingestion databases.

CSP customers need to configure exports for each subscription in order to ingest their total cost into FinOps hubs. Cost Management doesn't support management group exports for MCA or CSP subscriptions (as of May 2024).

For for information, see [Cost Management documentation](/azure/cost-management-billing/costs/tutorial-export-acm-data).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.10/bladeName/Hubs/featureName/Overview)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
