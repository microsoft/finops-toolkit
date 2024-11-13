---
layout: default
title: FinOps hubs
has_children: true
nav_order: 20
description: 'Reliable, trustworthy platform for cost analytics, insights, and optimization.'
permalink: /hubs
---

<span class="fs-9 d-block mb-4">FinOps hubs</span>
Open, extensible, and scalable cost governance for the enterprise.
{: .fs-6 .fw-300 }

[Deploy](#-create-a-new-hub){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Learn more](#️-why-finops-hubs){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🙋‍♀️ Why FinOps hubs?](#️-why-finops-hubs)
- [🌟 Benefits](#-benefits)
- [📦 What's included](#-whats-included)
- [📚 Explore the FinOps reports](#-explore-the-finops-reports)
- [➕ Create a new hub](#-create-a-new-hub)
- [🛫 Get started with hubs](#-get-started-with-hubs)
- [🔐 Required permissions](#-required-permissions)
- [🧰 Related tools](#-related-tools)

</details>

---

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs. FinOps hubs focus on 3 core design principles:

- **Be the standard**<br>_<sup>Strive to be the principal embodiment of the FinOps Framework.</sup>_
- **Built for scale**<br>_<sup>Designed to support the largest accounts and organizations.</sup>_
- **Open and extensible**<br>_<sup>Embrace the ecosystem and prioritize enabling the platform.</sup>_

FinOps hubs extend Cost Management to provide a scalable platform for advanced data reporting and analytics, through tools like Power BI and Microsoft Fabric. FinOps hubs are a foundation to build your own cost management and optimization solution.




<blockquote class="highlight-green-title" markdown="1">
  💵 Estimated cost: $120/mo + $10/mo per $1M in cost being monitored
  
_Estimated monthly cost includes $120 for a single-node Azure Data Explorer cluster, plus $10 in Azure storage and processing cost per $1M being monitored. Exact cost will vary based on discounts, data size (we estimate ~20GB per $1M), and Power BI license requirements. Cost without Data Explorer is $5 per $1M. For details, refer to the [FinOps hub cost estimate](https://aka.ms/finops/hubs/calculator) in the Azure Pricing Calculator._
</blockquote>

<blockquote class="note" markdown="1">
  _FinOps hubs requires an Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), or Microsoft Partner Agreement (MPA) account (including Cloud Solution Provider subscriptions). If you have a Microsoft Online Services Agreement (MOSA, aka PAYG) or a Microsoft internal subscription, you will need to use FinOps hubs 0.1.1. Please note Power BI reports have not been tested extensively with MOSA and MS Internal subscriptions. Speak to a Microsoft representative or file a billing support request to ask about migrating your subscription to Microsoft Customer Agreement._
</blockquote>

<br>

## 🙋‍♀️ Why FinOps hubs?

Many organizations that use Microsoft Cost Management eventually hit a wall where they need some capability that isn't natively available. When they do, their only options are to leverage one of the many third party tools or build something from scratch. While the cost management tooling ecosystem is rich and vast with many great options, they may be overkill or perhaps they don't solve specific needs. In these cases, organizations export cost data and build a custom solution. But this comes with many challenges, as these organizations are not generally staffed with the data engineers needed to design, build, and maintain a scalable data platform. FinOps hubs seeks to provide that foundation to streamline efforts in getting up and running with your own homegrown cost management solution.

FinOps hubs will streamline implementing the FinOps Framework, are being designed to scale to meet the largest enterprise needs, and will be open and extensible to support building custom solutions without the hassle of building the backend data store. FinOps hubs are designed for and by the community. Please join the discussion and let us know what you'd like to see next or learn how to contribute and be a part of the team.

[Join the conversation](https://github.com/microsoft/finops-toolkit/discussions){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Learn how to contribute](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 🌟 Benefits

- Report on cost and usage across multiple accounts and subscriptions in separate tenants.
- Run advanced analytical queries and report on year over year cost trends in seconds.
- Report on negotiated and commitment discount savings for EA billing accounts and MCA billing profiles.
- Full alignment with the [FinOps Open Cost and Usage Specification (FOCUS)](../../_docs/focus/README.md).
- Clean up duplicated data in daily Cost Management exports (and save money on storage).
- Convert exported data to parquet for faster data access.
- Extensible via standard Data Factory and Power BI capabilities to integrate business or other providers cost data.
- Connect Power BI to Azure Government and Azure China¹.
- Connect Power BI to Microsoft Online Services Agreement (MOSA) subscriptions¹.

_<sup>1) Azure Government, Azure China, and MOSA (or PAYG) subscriptions are only supported in FinOps hubs 0.1.1. FinOps hubs 0.2+ requires FOCUS cost data from Cost Management exports, which is not yet available.</sup>_

<br>

## 📦 What's included

The FinOps hub template includes the following resources:

- Data Factory instance to manage data ingestion and cleanup.
- Storage account (Data Lake Storage Gen2) as a staging area for data ingestion.
- Azure Data Explorer (Kusto) as a scalable datastore for advanced analytics (optional).
- Key Vault to store the Data Factory system managed identity credentials.

Once deployed, you can report on the data directly using Data Explorer queries, Data Explorer dashboards, Power BI, or by connecting to the database or storage account directly.

<img alt="Screenshot of the cost summary report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882658-45f026f1-c895-48ca-81e2-35765af8e29e.png">
<img alt="Screenshot of the services cost report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882700-4e04b589-0580-4e49-9b40-9f5948792975.png">
<img alt="Screenshot of the commitment discounts coverage report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882916-bb7ecfa3-d092-4ae2-88e1-7a0425c14dca.png">

[Browse reports](../power-bi/README.md){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }
[See the template](./template.md){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>

## 📚 Explore the FinOps reports

Each report in the FinOps toolkit is available as a PBIX or PBIT file. The PBIX file contains sample data that can be viewed in Power BI desktop without connecting to your account.

To visualize the reports available, simply download the PBIX Power BI report file from the desired [release](https://github.com/microsoft/finops-toolkit/releases) and open the report in Power BI Desktop. From there, you can navigate through the different pages of the report, which have been pre-filled with test data.

![Screenshot of the Rate optimization report with test data](../../assets/images/hubs/rate-optimization-report.png)

<br>

## ➕ Create a new hub

1. **Deploy your FinOps hub.**

   {% include deploy.html template="finops-hub" public="1" gov="0" china="0" %}

   [Learn more](../../_resources/deploy.md)

2. **Configure scopes to monitor.**

   FinOps hubs use Cost Management exports to load the data you want to monitor. You can configure exports manually or grant access to your hub to manage exports for you.

   [Learn more](./configure-scopes.md)

3. **Connect to your data.**

   You can connect to your data from any system that supports Azure Data Explorer or Azure storage. For ideas, see [get started with hubs](#-get-started-with-hubs). We recommend using pre-built Power BI starter templates to get started quickly.

   [Learn more](../power-bi/README.md#-connect-to-your-data)

If you run into any issues, see [Troubleshooting Power BI reports](../../_resources/troubleshooting.md).

<blockquote class="note" markdown="1">
  _If you need to deploy to Azure Gov or Azure China, please use [FinOps hubs 0.1.1](https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1). Instructions are the same except you will create an amortized cost export instead of a FOCUS export._

  {% include deploy.html template="finops-hub" public="0" gov="1" china="1" %}
</blockquote>

If you run into any issues, refer to the [Troubleshooting guide](../../_resources/troubleshooting.md).

_<sup>1) A "scope" is an Azure construct that contains resources or enables purchasing services, like a resource group, subscription, management group, or billing account. The resource ID for a scope will be the Azure Resource Manager URI that identifies the scope (e.g., "/subscriptions/###" for a subscription or "/providers/Microsoft.Billing/billingAccounts/###" for a billing account). To learn more, see [Understand and work with scopes](https://aka.ms/costmgmt/scopes).</sup>_

<br>

## 🛫 Get started with hubs

After deploying a hub instance, there are several ways for you to get started:

1. Customize the pre-built Power BI reports.

   Our Power BI reports are starter templates and intended to be customized. We encourage you to customize as needed. [Learn more](../power-bi/README.md).

2. Create your own Power BI reports.

   If you'd like to create your own reports or add cost data to an existing report, you can either [copy queries from a pre-built report](../power-bi/README.md#setup-a-finops-hub-report) or connect manually using the Azure Data Lake Storage Gen2 connector.

3. Connect to Microsoft Fabric for advanced queries.

   If you use OneLake in Microsoft Fabric, you can create a shortcut to the `ingestion` container in your hubs storage account to run SQL or KQL queries directly against the data in hubs. [Learn more](https://learn.microsoft.com/fabric/real-time-analytics/onelake-shortcuts?tabs=adlsgen2).

4. Access the cost data from custom tools.

   Cost data is stored in [Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer) and an [Azure Data Lake Storage Gen2](https://learn.microsoft.com/azure/storage/blobs/data-lake-storage-introduction) account. You can use any tool that supports these services to access the data. Refer to the [data dictionary](../../_resources/data-dictionary.md) for details about available columns.

5. Apply cost allocation logic, augment, or manipulate your cost data using Data Factory.

   [Data Factory](https://learn.microsoft.com/azure/data-factory/introduction) is used to ingest and transform data. We recommend using Data Factory as a cost-efficient solution to apply custom logic to your cost data. Do not modify built-in pipelines or data in the **msexports** container. If you create custom pipelines, monitor new data in the **ingestion** container and use a consistent prefix to ensure they don't overlap with new pipelines. Refer to [data processing](./data-processing.md) for details about how data is processed.

   <blockquote class="important" markdown="1">
     _Keep in mind this is the primary area we are planning to evolve in [upcoming FinOps toolkit releases](https://aka.ms/finops/toolkit/roadmap). Please familiarize yourself with our roadmap to avoid conflicts with future updates. Consider [contributing to the project](https://github.com/microsoft/finops-toolkit/blob/dev/CONTRIBUTING.md) to add support for new scenarios to avoid conflicts._
   </blockquote>

6. Generate custom alerts using Power Automate.

   You have many options for generating custom alerts. [Power Automate](https://powerautomate.microsoft.com/connectors/details/shared_azureblob/azure-blob-storage) is a great option for people who are new to automation but you can also use [Data Factory](https://learn.microsoft.com/azure/data-factory/introduction), [Functions](https://learn.microsoft.com/azure/azure-functions/functions-overview), or any other service that supports custom code or direct access to data in Azure Data Lake Storage Gen2.

No matter what you choose to do, we recommend creating a new Bicep module to support updating your solution. You can reference `finops-hub/main.bicep` or `hub.bicep` directly to ensure you can apply new updates as they're released.

If you need to change `hub.bicep`, be sure to track those changes and re-apply them when upgrading to the latest release. We generally don't recommend modifying the template or modules directly to avoid conflicts with future updates. Instead, consider contributing those changes back to the open source project. [Learn more](https://github.com/microsoft/finops-toolkit/blob/main/CONTRIBUTING.md).

If you access data in storage or are creating or customizing Power BI reports, please refer to the [data dictionary](../../_resources/data-dictionary.md) for details about the available columns.

<br>

## 🔐 Required permissions

Required permissions for deploying or updating hub instances are covered in the [template details](./template.md#-prerequisites).

You will need one or more of the following to export your cost data:

| Scope                                                 | Permission                                                                                                                             |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Subscriptions and resource groups (all account types) | [Cost Management Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#cost-management-contributor). |
| EA billing scopes                                     | Enterprise Reader, Department Reader, or Account Owner (aka enrollment account).                                                       |
| MCA billing scopes                                    | Contributor on the billing account, billing profile, or invoice section.                                                               |
| MPA billing scopes                                    | Contributor on the billing account, billing profile, or customer.                                                                      |

Note that CSP customers will need to configure exports for each subscription in order to ingest their total cost into FinOps hubs. Cost Management does not support management group exports for MCA or CSP subscriptions (as of May 2024).

For additional details, refer to [Cost Management documentation](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data).

<br>

---

## 🧰 Related tools

{% include tools.md aoe="1" bicep="0" data="1" gov="0" pbi="1" ps="1" opt="1" %}

<br>
