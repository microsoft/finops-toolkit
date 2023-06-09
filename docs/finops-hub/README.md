# ☁️ FinOps hubs

![Version 0.0.1](https://img.shields.io/badge/version-0.0.1-darkgreen)
&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/title/microsoft/cloud-hubs/1?label=roadmap)](https://github.com/microsoft/cloud-hubs/issues/1)

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs. FinOps hubs focus on 3 core design principles:

- **Be the standard**<br>_<sup>Strive to be the principal embodiment of the FinOps Framework.</sup>_
- **Built for scale**<br>_<sup>Designed to support the largest accounts and organizations.</sup>_
- **Open and extensible**<br>_<sup>Embrace the ecosystem and prioritize enabling the platform.</sup>_

> #### 💵 Estimated cost: $25 per $1M in cost <!-- markdownlint-disable-line -->
>
> _Exact cost of the solution may vary. Cost is primarily for data storage and number of times data is ingested. Pipelines will run once a day per export._

On this page:

- [ℹ️ Summary](#ℹ️-summary)
- [➕ Create a new hub](#-create-a-new-hub)
- [🛫 Get started with hubs](#-get-started-with-hubs)

---

## ℹ️ Summary

The FinOps hub template includes the following resources:

- Storage account (Data Lake Storage Gen2) to hold all cost data.
- Data Factory instance to manage data ingestion and cleanup.
- Key Vault to store the Data Factory system managed identity credentials.

Once deployed, you can create new exports in Cost Management and use [out of the box Power BI reports](reports) to customize and share reports with your stakeholders.

<img alt="Screenshot of the cost summary report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882658-45f026f1-c895-48ca-81e2-35765af8e29e.png">
<img alt="Screenshot of the services cost report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882700-4e04b589-0580-4e49-9b40-9f5948792975.png">
<img alt="Screenshot of the commitment-based discounts coverage report" style="max-width:200px" src="https://user-images.githubusercontent.com/399533/216882916-bb7ecfa3-d092-4ae2-88e1-7a0425c14dca.png">

To learn more, see [FinOps hub template details](template.md).

<br>

## ➕ Create a new hub

1. Register the Microsoft.EventGrid resource provider
   > See [Register a resource provider](https://docs.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) for details.
2. [Deploy the **finops-hub** template](../deploy).
3. [Create a new cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:
   - **Metric** = `Amortized cost`
   - **Export type** = `Daily export of month-to-date costs`
     > 💡 _**Tip:** Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range._
   - **File Partitioning** = On
   - **Storage account** = (Use subscription/resource from step 1)
   - **Container** = `msexports`
   - **Directory** = (Use the resource ID of the scope you're exporting without the first "/")
4. Run your export.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.
5. Download one or more of the available Power BI starter templates:
   - [Cost summary](./reports/cost-summary.md) for standard cost roll-ups.
   - [Commitment discounts](./reports/commitment-discounts.md) for commitment-based savings utilization and coverage.
6. [Connect Power BI to your hub](./reports/README.md#setup-a-finops-toolkit-report)

If you run into any issues, see [Troubleshooting Power BI reports](./troubleshooting.md).

<br>

## 🛫 Get started with hubs

After deploying a hub instance, there are several ways for you to get started:

1. Customize the built-in Power BI reports.

   Our Power BI reports are starter templates and intended to be customized. We encourage you to customize as needed. [Learn more](./reports).

2. Create your own Power BI reports.

   If you'd like to create your own reports or add cost data to an existing report, you can either [copy queries from a toolkit report](./reports/README.md#setup-a-finops-toolkit-report) or [connect manually](./reports/README.md#connect-manually) using the Azure Data Lake Storage Gen2 connector.

   <!-- NOTE TO CONTRIBUTORS: Keep this info note in sync with the same one under #3 below. -->

   > ℹ️ _The schema may change multiple times before the 0.1 release. We will ensure Power BI reports have backwards compatibility, but if you access data directly, you may run into breaking changes with new releases. Familiarize yourself with [upcoming releases](https://aka.ms/finops/toolkit/roadmap) and review the [changelog](changelog.md) for breaking changes before you update._

3. Access the cost data from custom tools.

   Cost data is stored in an [Azure Data Lake Storage Gen2](https://learn.microsoft.com/azure/storage/blobs/data-lake-storage-introduction) account. You can use any tool that supports Azure Data Lake Storage Gen2 to access the data. Refer to the [data dictionary](./data-dictionary.md) for details about available columns.

   <!-- NOTE TO CONTRIBUTORS: Keep this info note in sync with the same one under #2 above. -->

   > ℹ️ _The schema may change multiple times before the 0.1 release. We will ensure Power BI reports have backwards compatibility, but if you access data directly, you may run into breaking changes with new releases. Familiarize yourself with [upcoming releases](https://aka.ms/finops/toolkit/roadmap) and review the [changelog](changelog.md) for breaking changes before you update._

4. Apply cost allocation logic, augment, or manipulate your cost data using Data Factory.

   [Data Factory](https://learn.microsoft.com/azure/data-factory/introduction) is used to ingest and transform data. We recommend using Data Factory as a cost-efficient solution to apply custom logic to your cost data. Do not modify built-in pipelines or data in the **msexports** container. If you create custom pipelines, monitor new data in the **ingestion** container and use a consistent prefix to ensure they don't overlap with new pipelines. Refer to [data processing](./data-processing.md) for details about how data is processed.

   > ⚠️ _Keep in mind this is the primary area we are planning to evolve in [upcoming FinOps toolkit releases](https://aka.ms/finops/toolkit/roadmap). Please familiarize yourself with our roadmap to avoid conflicts with future updates. Consider [contributing to the project](../CONTRIBUTING.md) to add support for new scenarios to avoid conflicts._

5. Generate custom alerts using Power Automate.

   You have many options for generating custom alerts. [Power Automate](https://powerautomate.microsoft.com/connectors/details/shared_azureblob/azure-blob-storage) is a great option for people who are new to automation but you can also use [Data Factory](https://learn.microsoft.com/azure/data-factory/introduction), [Functions](https://learn.microsoft.com/azure/azure-functions/functions-overview), or any other service that supports custom code or direct access to data in Azure Data Lake Storage Gen2.

No matter what you choose to do, we recommend creating a new Bicep module to support updating your solution. You can reference `finops-hub/main.bicep` or `hub.bicep` directly to ensure you can apply new updates as they're released.

If you need to change `hub.bicep`, be sure to track those changes and re-apply them when upgrading to the latest release. We generally don't recommend modifying the template or modules directly to avoid conflicts with future updates. Instead, consider contributing those changes back to the open source project. [Learn more](../CONTRIBUTING.md).

If you access data in storage or are creating or customizing Power BI reports, please refer to the [data dictionary](data-dictionary.md) for details about the available columns.

<br>
