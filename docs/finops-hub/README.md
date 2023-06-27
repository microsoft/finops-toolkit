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

- [☁️ FinOps hubs](#️-finops-hubs)
  - [ℹ️ Summary](#ℹ️-summary)
  - [Create a new hub](#create-a-new-hub)
  - [Configure daily/monthly exports](#configure-dailymonthly-exports)
    - [Configure daily/monthly exports using managed exports](#configure-dailymonthly-exports-using-managed-exports)
      - [Managed export requirements](#managed-export-requirements)
      - [Managed export configuration](#managed-export-configuration)
      - [Export scope examples](#export-scope-examples)
    - [Configure daily/monthly exports using Cost Management exports](#configure-dailymonthly-exports-using-cost-management-exports)
  - [Connect to your data](#connect-to-your-data)
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

## Create a new hub

1. [Deploy the **finops-hub** template](../deploy).

## Configure daily/monthly exports

Configure exports for supported scopes using either managed exports or Cost Management exports.

### Configure daily/monthly exports using managed exports

#### Managed export requirements

- Managed exports require granting permissions against the export scope to the managed identity used by Data Factory.  If this is not desireable/feasable use Cost Management exports instead
- Managed exports support EA Enrollment, EA Department and Subscription level imports.
- **MCA Billing Accounts and Billing Profiles are not supported by managed exports at present.  Use Cost Management exports instead.**
- Minimum required permissions for the export scope:
  - _**EA Enrollment:** EA Reader_
  - _**EA Department:** Department Reader_
  - _**Subscription:** Cost Management Contributor_
  
#### Managed export configuration

> 💡 _Note: MCA billing scopes are not supported for managed exports at this time.  Use Cost Management Exports instead._

1. Grant required permissions to the managed identity of the Data Factory.
2. Add the export scope(s) to the exportScopes section of the settings.json file in the config container.  
3. Wait for the msexports_setup pipeline to configure managed exports for the specified scopes.
4. Execute the msexports_backfill pipeline to fill the dataset per the retention settings in settings.json.

#### Export scope examples

````json
   "exportScopes": [
      {
         "scope": "/subscriptions/00000000-0000-0000-0000-000000000000"
      },
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/12345678"
      },
      {
         "scope": "/providers/Microsoft.Billing/billingAccounts/12345678/departments/1234"
      }
    ]
````

### Configure daily/monthly exports using Cost Management exports

Use Cost Management exports for MCA scopes or scenarios where you cannot grant permissions to Azure Data Factory.

1. [Create a new cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:
   - **Metric** = `Amortized cost`
   - **Export type** = `Daily export of month-to-date costs`
     > 💡 _**Tip:** Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range.  For best performance create one for calendar month of historical data you want to backfill._
   - **File Partitioning** = `on`
     > 💡 _Tip: This setting must be enabled for the extract trigger to fire correctly.  If data isn't appearing in the ingestion container make sure this setting is turned on and the trigger is enabled in Data Factory._
   - **Storage account** = (Use subscription/resource from step 1)
   - **Container** = `msexports`
   - **Directory** = (Use the resource ID of the scope you're exporting without the first "/")

   > - _**EA Enrollment:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}_
   > - _**EA Department:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}_
   > - _**MCA Billing Account:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}_
   > - _**MCA Billing Profile:** providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}_
   > - _**Subscription:** subscriptions/{subscriptionId}_

2. Run your export.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.

## Connect to your data

1. Download one or more of the available Power BI starter templates:
   - [Cost summary](./reports/cost-summary.md) for standard cost roll-ups.
   - [Commitment discounts](./reports/commitment-discounts.md) for commitment-based savings utilization and coverage.
2. [Connect Power BI to your hub](./reports/README.md#setup-a-finops-toolkit-report)

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
