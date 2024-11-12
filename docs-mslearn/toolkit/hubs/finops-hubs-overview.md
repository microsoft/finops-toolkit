---
title: FinOps hubs overview
description: FinOps hubs provide a reliable platform for cost analytics, insights, and optimization, supporting large accounts and organizations.
author: bandersmsft
ms.author: banders
ms.date: 10/30/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps hubs are so that I can use them in my organization.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps hubs

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs. FinOps hubs focus on three core design principles:

- **Be the standard**<br>_Strive to be the principal embodiment of the FinOps Framework._
- **Built for scale**<br>_Designed to support the largest accounts and organizations._
- **Open and extensible**<br>_Embrace the ecosystem and prioritize enabling the platform._

FinOps hubs are in early development. Today, FinOps hubs extend Cost Management by exporting cost details to a consolidated storage account. FinOps hubs address a few of the inherent limitations that make exports more difficult to use. In their most basic form, FinOps hubs enable more Power BI reporting options. On the more advanced end, FinOps hubs are a foundation for you to build your own cost management and optimization solution.

> [!NOTE]
> Estimated cost: $25/mo per $1M in cost being monitored.
>
> Estimated cost includes $5 for Azure storage and data processing plus up to $20 per user for [Power BI licenses](https://www.microsoft.com/power-platform/products/power-bi/pricing). Exact cost varies based on discounts, data size per $1M (~20GB of data), and Power BI license requirements. Pipelines run once a day per export, plus one additional monthly run per export. Pipeline run time depends on data size. For details, refer to the [FinOps hub cost estimate](https://azure.com/e/c3d98263bec048b6af52acb180c42b7e) in the Azure Pricing Calculator or monitor hub cost using the [Data ingestion report](../power-bi/data-ingestion.md).

<br>

> [!NOTE]
> FinOps hubs requires an Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), or Microsoft Partner Agreement (MPA) account (including Cloud Solution Provider subscriptions). If you have a Microsoft Online Services Agreement (MOSA, often called pay-as-you-go) or a Microsoft internal subscription, you need to use FinOps hubs 0.1.1. Power BI reports weren't tested extensively with MOSA and MS Internal subscriptions. Speak to a Microsoft representative or file a billing support request to ask about migrating your subscription to Microsoft Customer Agreement.

<br>

## Why FinOps hubs?

Many organizations that use Microsoft Cost Management eventually hit a wall where they need some capability that isn't natively available. When they do, their only options are to use one of the many third party tools or build something from scratch. While the cost management tooling ecosystem is rich and vast with many great options, they might be overkill or perhaps they don't solve specific needs. In these cases, organizations export cost data and build a custom solution. But it comes with many challenges, as these organizations aren't staffed with the data engineers needed to design, build, and maintain a scalable data platform. FinOps hubs seek to provide that foundation to streamline efforts in getting up and running with your own homegrown cost management solution.

FinOps hubs streamline implementing the FinOps Framework. They're being designed to scale to meet the largest enterprise needs. And, they're open and extensible to support building custom solutions without the hassle of building the backend data store. FinOps hubs are designed for and by the community. Join the discussion and let us know what you'd like to see next or learn how to contribute and be a part of the team.

[Join the conversation](https://aka.ms/ftk/discuss) &nbsp; [Learn how to contribute](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md)

<br>

## Benefits

FinOps hubs provide many benefits over using Cost Management exports.

- Clean up duplicated data in daily Cost Management exports (and save money on storage).
- Convert exported data to parquet for faster data access.
- Connect Power BI to subscriptions, resource groups, and other scopes.
- Connect Power BI to Azure Government and Azure China.
- Connect Power BI to Microsoft Online Services Agreement (MOSA) subscriptions¹.
- Report on multiple subscriptions, resource groups, or billing accounts.
- Streamlined deployment and management with PowerShell.
- Full alignment with the [FinOps Open Cost and Usage Specification (FOCUS)](../../focus/what-is-focus.md).
- _In development: Ingest data from subscriptions in multiple tenants into a single storage account²._
- _In development: Ingest data into Azure Data Explorer._

_¹ MOSA (or pay-as-you-go) subscriptions are only supported in FinOps hubs 0.1.x. FinOps hubs 0.2 requires FOCUS cost data from Cost Management exports, which aren't supported for MOSA subscriptions. Contact support about transitioning to a Microsoft Customer Agreement account._

_² EA billing scopes can be exported to any tenant today. Sign in to that tenant with an account that has access to the billing scope and target storage account to configure exports. Nonbilling scopes (subscriptions, management groups, and resource groups) and all MCA scopes are only supported in the tenant they exist in today. They'll be supported via a "remote hubs" feature in a future FinOps hubs release._

<br>

## What's included

The FinOps hub template includes the following resources:

- Storage account (Data Lake Storage Gen2) to hold all cost data.
- Data Factory instance to manage data ingestion and cleanup.
- Key Vault to store the Data Factory system managed identity credentials.

Once deployed, you can report on the data in Power BI or by connecting to the storage account directly.

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

Here are some examples of the reports:

:::image type="content" source="./media/finops-hubs-overview/cost-summary-report.png" border="true" alt-text="Screenshot showing the Cost summary report." lightbox="./media/finops-hubs-overview/cost-summary-report.png" :::

:::image type="content" source="./media/finops-hubs-overview/services-cost-report.png" border="true" alt-text="Screenshot showing the Services cost report." lightbox="./media/finops-hubs-overview/services-cost-report.png" :::

:::image type="content" source="./media/finops-hubs-overview/commitment-discounts-coverage-report.png" border="true" alt-text="Screenshot showing the Commitment discounts coverage report." lightbox="./media/finops-hubs-overview/commitment-discounts-coverage-report.png" :::

[Browse reports](../power-bi/reports.md) &nbsp; [See the template](template.md)

<br>

## Explore the FinOps reports

Each report in the FinOps toolkit is available as a PBIX or PBIT file. The PBIX file contains sample data that can be viewed in Power BI desktop without connecting to your account.

To visualize the reports available, download the PBIX Power BI report file from the desired [release](https://github.com/microsoft/finops-toolkit/releases) and open the report in Power BI Desktop. From there, you can navigate through the different pages of the report, which are prefilled with test data.

:::image type="content" source="./media/finops-hubs-overview/rate-optimization-commitment-discounts.png" border="true" alt-text="Screenshot of the Rate optimization report with test data." lightbox="./media/finops-hubs-overview/rate-optimization-commitment-discounts.png" :::

<br>

## Create a new hub

To create a new FinOps hub, follow these steps:

1. **Deploy your FinOps hub.**

   <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-latest.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-latest.ui.json"><img alt="Deploy To Azure" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true" /></a>

   <!-- TODO: Uncomment when files are added
   [Learn more](../../_resources/deploy.md)
   -->

2. **Configure scopes to monitor.**

   FinOps hubs use Cost Management exports to load the data you want to monitor. You can configure exports manually or grant access to your hub to manage exports for you.

   For more information, see [Configure scopes](configure-scopes.md).

3. **Connect to your data.**

   You can connect to your data from any system that supports Azure storage. For ideas, see [get started with hubs](#get-started-with-hubs). We recommend using prebuilt Power BI starter templates to get started quickly.

   For more information, see [Connect to your data](../power-bi/reports.md#connect-to-your-data).

If you run into any issues, see [Troubleshooting Power BI reports](../help/troubleshooting.md).

> [!NOTE]
> If you need to deploy to Azure Gov or Azure China, use [FinOps hubs 0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1). Instructions are the same except you will create an amortized cost export instead of a FOCUS export.

  <a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.ui.json"><img alt="Deploy To Azure Gov" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true" /></a>
  &nbsp;
  <a href="https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.json/createUIDefinitionUri/https%3A%2F%2Fmicrosoft.github.io%2Ffinops-toolkit%2Fdeploy%2Ffinops-hub-0.1.1.ui.json"><img alt="Deploy To Azure China" src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazurechina.svg?sanitize=true" /></a>

If you run into any issues, refer to the [Troubleshooting guide](../help/troubleshooting.md).

A *scope* is an Azure construct that contains resources or enables purchasing services, like a resource group, subscription, management group, or billing account. The resource ID for a scope is the Azure Resource Manager URI that identifies the scope (for example, "/subscriptions/###" for a subscription or "/providers/Microsoft.Billing/billingAccounts/###" for a billing account). For more information, see [Understand and work with scopes](https://aka.ms/costmgmt/scopes).

<br>

## Get started with hubs

After you deploy a hub instance, there are several ways for you to get started:

1. Customize the prebuilt Power BI reports.

   Our Power BI reports are starter templates and intended to be customized. We encourage you to customize as needed. [Learn more](../power-bi/reports.md).

2. Create your own Power BI reports.

   If you want to create your own reports or add cost data to an existing report, you can [copy queries from a prebuilt report](../power-bi/setup.md#copy-queries-from-a-toolkit-report). Or you can connect manually using the Azure Data Lake Storage Gen2 connector.

3. Connect to Microsoft Fabric for advanced queries.

   If you use OneLake in Microsoft Fabric, you can create a shortcut to the `ingestion` container in your hubs storage account to run SQL or KQL queries directly against the data in hubs. [Learn more](../../fabric/create-fabric-workspace-finops.md#create-a-shortcut-to-storage).

4. Access the cost data from custom tools.

   Cost data is stored in an [Azure Data Lake Storage Gen2](/azure/storage/blobs/data-lake-storage-introduction) account. You can use any tool that supports Azure Data Lake Storage Gen2 to access the data.
<!--- Refer to the [data dictionary](../../_resources/data-dictionary.md) for details about available columns. -->

5. Apply cost allocation logic, augment, or manipulate your cost data using Data Factory.

   [Data Factory](/azure/data-factory/introduction) is used to ingest and transform data. We recommend using Data Factory as a cost-efficient solution to apply custom logic to your cost data. Don't modify built-in pipelines or data in the **msexports** container. If you create custom pipelines, monitor new data in the **ingestion** container and use a consistent prefix to ensure they don't overlap with new pipelines. Refer to [data processing](./data-processing.md) for details about how data is processed.

   > [!IMPORTANT]
   > Keep in mind this is the primary area we are planning to evolve in [upcoming FinOps toolkit releases](../roadmap.md). Get familiar the roadmap to avoid conflicts with future updates. Consider [contributing to the project](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md) to add support for new scenarios to avoid conflicts.

6. Generate custom alerts using Power Automate.

   You have many options for generating custom alerts. [Power Automate](https://powerautomate.microsoft.com/connectors/details/shared_azureblob/azure-blob-storage) is a great option for people who are new to automation. You can also use [Data Factory](/azure/data-factory/introduction), [Functions](/azure/azure-functions/functions-overview), or any other service that supports custom code or direct access to data in Azure Data Lake Storage Gen2.

No matter what you choose to do we recommend creating a new Bicep module to support updating your solution. You can reference `finops-hub/main.bicep` or `hub.bicep` directly to ensure you can apply new updates as they're released.

If you need to change `hub.bicep`, be sure to track those changes and reapply them when upgrading to the latest release. We generally don't recommend modifying the template or modules directly to avoid conflicts with future updates. Instead, consider contributing those changes back to the open source project. [Learn more](https://github.com/microsoft/finops-toolkit/blob/main/CONTRIBUTING.md).

<!-- TODO: Uncomment when files are added
If you access data in storage or are creating or customizing Power BI reports, please refer to the [data dictionary](../../_resources/data-dictionary.md) for details about the available columns.
-->

<br>

## Required permissions

Required permissions for deploying or updating hub instances are covered in the [template details](template.md#prerequisites).

You need one or more of the following to export your cost data:

| Scope                                                 | Permission                                                                                                  |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Subscriptions and resource groups (all account types) | [Cost Management Contributor](/azure/role-based-access-control/built-in-roles#cost-management-contributor). |
| EA billing scopes                                     | Enterprise Reader, Department Reader, or Account Owner (also known as enrollment account).                  |
| MCA billing scopes                                    | Contributor on the billing account, billing profile, or invoice section.                                    |
| MPA billing scopes                                    | Contributor on the billing account, billing profile, or customer.                                           |

CSP customers need to configure exports for each subscription in order to ingest their total cost into FinOps hubs. Cost Management doesn't support management group exports for MCA or CSP subscriptions (as of May 2024).

For for information, see [Cost Management documentation](/azure/cost-management-billing/costs/tutorial-export-acm-data).

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
