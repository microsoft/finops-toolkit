---
layout: default
parent: Power BI
title: How to setup
nav_order: 10
description: 'Publish your next FinOps reporting with Power BI starter kits.'
permalink: /power-bi/setup
---

<span class="fs-9 d-block mb-4">How to setup Power BI</span>
Publish new Power BI reports based on FinOps toolkit starter kits, extend them to include business context, integrate cost data into your existing reports, or migrate from older Cost Management solutions.
{: .fs-6 .fw-300 }

[Download](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[How to setup](#-setup-your-first-report){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [➕ Setup your first report](#-setup-your-first-report)
- [📋 Copy queries from a toolkit report](#-copy-queries-from-a-toolkit-report)
- [🛠️ Connect manually](#️-connect-manually)
- [🚚 Migrate from the Cost Management template app](#-migrate-from-the-cost-management-template-app)
- [🏗️ Migrate from the Cost Management connector](#️-migrate-from-the-cost-management-connector)
- [🧰 Related tools](#-related-tools)

</details>

---

<!-- markdownlint-disable-line --> {% include_relative _intro.md %}

Use the guides below to connect and customize FinOps toolkit and other Power BI reports.

<br>

## ➕ Setup your first report

The FinOps toolkit Power BI reports include pre-configured visuals, but are not connected to your data. Use the following steps to connect them to your data:

1. Download and open the desired report in Power BI Desktop.
2. Select the **Transform data** button in the toolbar.

   ![Screenshot of the Transform data button in the Power BI Desktop toolbar.](https://user-images.githubusercontent.com/399533/216573265-fa76828f-c9a2-497d-ae1e-19b55fef412c.png)

<!--
1. In the **Queries** pane on the left, set the **🛠️ Setup** > **Data source** property.

   - `Cost Management exports` requires read access to an EA or MCA billing account or billing profile.
   - `FinOps hubs` requires [Storage Blob Data Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader) access to the storage account deployed with your hub.
-->

1. If connecting to a FinOps hub instance, set the following properties:

   - **Storage URL** is the URL of your hub storage account. Copy this value from the portal:
     1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
     2. Select the hub resource group.
     3. Select Deployments in the menu.
     4. Select the **hub** deployment.
     5. Select **Outputs**.
     6. Copy the value for `storageUrlForPowerBI`.
   - If you customized the deployment to use compressed CSV instead of Parquet, change **FileType** to `.gz`. Most people will not change this.
   - Change **RangeStart** and **RangeEnd** to the desired start/end dates for your report. The default is the current calendar year. Consider using your fiscal year.
     <blockquote class="warning" markdown="1">
       _[Enable incremental refresh](https://learn.microsoft.com/power-bi/connect-data/incremental-refresh-configure#define-policy) to load more than $5M of raw cost details. Power BI reports can only support $2-5M of data when incremental refresh is not enabled. After incremental refresh is enabled, they can support $2-5M/month for a total of ~$65M in raw cost details._
     </blockquote>
   - **CM connector** settings are required for any reports that rely on data not supported in FinOps hubs yet (i.e., actual costs, reservation recommendations). Be sure to also supply those settings in the next section.
   - Actual costs are included by default when the connector details are specified. If you do not want to include actual cost data from the Cost Management connector, open the **CostDetails** query in the advanced editor and change the `2` to a `1`. This will avoid calling the Cost Management connector.

   ![Screenshot of instructions to connect to a FinOps hub](https://github.com/microsoft/finops-toolkit/assets/399533/5582b428-e811-4d7e-83d0-4a8fbb905d30)

2. If using the [Cost Management connector report](./connector.md) or [Commitment discounts report](./commitment-discounts.md), set the following properties in the **🛠️ Setup** > **CM connector** folder:

   - **Scope** is your EA enrollment number or MCA scope ID.
     - A "scope ID" is a fully-qualified Azure resource ID for the MCA billing account or billing profile you want to connect to.
     - If using the Cost Management connector report, you can connect to an MCA billing account to view cost across all billing profiles but reservation recommendations will not be available in the Coverage pages.
     - If using the Commitment discounts report, you must use a billing profile since the connector is used for reservation recommendations which are only available for billing profiles.
     - An MCA billing account scope ID looks like `/providers/Microsoft.Billing/billingAccounts/{billingAccountId}`.
     - An MCA billing profile scope ID looks like `/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}`.
     - You can get the billing account and profile IDs from the Azure portal:
       - Go to https://aka.ms/costmgmt/config
       - 
   - **Type** is your MCA billing profile ID.
     <blockquote class="note" markdown="1">
       _The billing profile ID is optional for cost reports, but is required for reservation recommendations. When not specified, cost reports will include all billing profiles within the account._
     </blockquote>
   - **Number of Months** is the number of months of data to include in the report.
     <blockquote class="warning" markdown="1">
       _The Cost Management connector does not support incremental refresh and Power BI reports can only support ~$2-5M of data when incremental refresh is not enabled. You may need to adjust the number of months in your report to fit within this limit._
     </blockquote>

   ![Screenshot of instructions to connect to the Cost Management connector](https://github.com/microsoft/finops-toolkit/assets/399533/efeb85d6-cdd3-40f8-a501-e1959fdb1d4f)

3. Select the **Close & Apply** to save your settings.

If you run into any issues syncing your data, see [Troubleshooting Power BI reports](../resources/troubleshooting.md).

<br>

## 📋 Copy queries from a toolkit report

FinOps toolkit reports manipulate the raw data to facilitate specific types of reports. If you need to connect your data to a new or existing Power BI report that doesn't currently use FinOps toolkit or Cost Management data source, the best option is to copy queries, columns, and measures from a FinOps toolkit report.

1. Download one of the FinOps toolkit reports.
2. Open the report in Power BI Desktop.
3. Select **Transform data** in the toolbar.
4. In the Queries list on the left, right-click **CostDetails** (or other query) and select **Copy**.
5. Open your report in Power BI Desktop.
6. Select **Transform data** in the toolbar.
7. Right-click the empty space in the bottom of the **Queries** pane and select **New group...**.
8. Set the name to `FinOps toolkit` and select **OK**.
9. Right-click the **FinOps toolkit** folder and select **Paste**.
10. Select **Close & Apply** in the toolbar for both reports.

At this point, you have the core data from the FinOps toolkit reports, extended to support Azure Hybrid Benefit and FOCUS reports. In addition to these, you may also be interested in the custom columns and measures that summarize savings, utilization, cost over time, and more. Unfortunately, Power BI doesn't provide a simple way to copy columns and measures. Perform the following for each column and measure you'd like to copy:

1. In the FinOps toolkit report, expand the **CostDetails** (or other table) table in the **Data** pane on the right.
2. Select a custom column or measure, then copy the formula from the editor at the top of the window, under the toolbar.
   <blockquote class="note" markdown="1">
     _Be sure to make note if this is a column or a measure. Columns have a table icon with a "Σ" or "fx" symbol and measures have a calculator icon._<br>![Screenshot of the calculated column and measure icons in Power BI](https://user-images.githubusercontent.com/399533/216805396-96abae2d-473a-4136-8943-cac4ddd74dce.png)
   </blockquote>
3. In your report, right click the **CostDetails** table and select **New measure** or **New column** based on what you just copied.
4. When the formula editor is shown, paste the formula using <kbd>Ctrl+V</kbd> or <kbd>Cmd+V</kbd>.
5. Repeat steps 2-4 for each desired column and measure.

Note that some columns and measures depend on one another. You can ignore these errors as you copy each formula. Each will resolve itself when the dependent column or measure is added.

For details about the columns available in Power BI, refer to the [data dictionary](../resources/data-dictionary.md).

<br>

## 🛠️ Connect manually

If you don't need any of the custom columns and measures provided by the FinOps toolkit reports, you can also connect directly to your data using one of the built-in Power BI connectors.

If using the Cost Management connector, refer to [Create visuals and reports with the Cost Management connector](https://learn.microsoft.com/power-bi/connect-data/desktop-connect-azure-cost-management).

If using FinOps hubs, you'll use the Azure Data Lake Storage Gen2 connector:

1. Open your desired report in Power BI Desktop.
2. Select **Get data** in the toolbar.
3. Search for `lake` and select **Azure Data Lake Storage Gen2**
4. Set the URL using deployment outputs:
   1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
   2. Select the hub resource group.
   3. Select Deployments in the menu.
   4. Select the **hub** deployment.
   5. Select **Outputs**.
   6. Copy the value for `storageUrlForPowerBI`.
5. Select the **OK** button.
   <blockquote class="warning" markdown="1">
      _If you receive an "Access to the resource is forbidden" error, grant the account loading data in Power BI the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader)._
   </blockquote>
6. Select the **Combine** button.
7. Select the **OK** button.

For more details about connecting to Azure Data Lake Storage Gen2, see [Connect to ADLS Gen2](https://learn.microsoft.com/power-query/connectors/data-lake-storage#connect-to-azure-data-lake-storage-gen2-from-power-query-desktop). For details about the columns available in storage, refer to the [data dictionary](../resources/data-dictionary.md).

<br>

## 🚚 Migrate from the Cost Management template app

The Cost Management template app does not support customization in Power BI Desktop and is only supported for Enterprise Agreement (EA) accounts. We recommend starting from one of the FinOps toolkit reports that work across account types rather than customizing the template app. If would like to customize or copy something from the template, see [Cost Management template app](./template-app.md).

<br>

## 🏗️ Migrate from the Cost Management connector

The Cost Management connector provides separate queries for actual (billed) and amortized costs. In an effort to minimize data size and improve performance, the FinOps toolkit reports combine these into a single query. The best way to migrate from the Cost Management connector is to copy the queries from a FinOps toolkit report and then update your visuals to use the **CostDetails** table.

1. Download one of the FinOps toolkit reports.
2. Open the report in Power BI Desktop.
3. Select **Transform data** in the toolbar.
4. In the **Queries** list on the left, right-click **CostDetails** and select **Copy**.
5. Before you change your report, make a copy first to ensure you can rollback if needed.
6. Open your report in Power BI Desktop.
7. Select **Transform data** in the toolbar.
8. Right-click the empty space in the bottom of the **Queries** pane and select **New group...**.
9. Set the name to `FinOps toolkit` and select **OK**.
10. Right-click the **FinOps toolkit** folder and select **Paste**.
11. Right-click the **CostDetails** query and select **Advanced Editor**.
12. Copy all text and close the editor dialog.
13. Right-click the **Usage details** query and select **Advanced Editor**.
14. Replace all text with the copied text from CostDetails and select the **Done** button.
15. Rename the **Usage details** query to `CostDetails` and drag it into the `FinOps toolkit` folder.
16. Delete the **Usage details amortized** query.
17. Select **Close & Apply** in the toolbar for both reports.
18. Review each page to ensure the visuals are still working as expected. Update any references to old columns or measures to the new names.
    - Start at the report level:
      - In the **Data** pane, expand each custom table and check custom columns and measures.
      - In the **Filters** pane, check **Filters on all pages**.
    - Then check each page:
      - In the **Filters** pane, check **Filters on this page**.
    - Then check each visual on each page:
      - In the **Filters** pane, check **Filters on this visual**.
      - In the **Visualizations** pane, check **Fields**.
        <blockquote class="note" markdown="1">
          _If the column name was customized and you aren't sure what the original name was, right-click the field and select **Rename for this visual**, then delete the name, and press <kbd>Enter</kbd> to reset the name back to the original column name._
        </blockquote>

If interested in custom columns and measures, see [Copy queries from a toolkit report](#-copy-queries-from-a-toolkit-report) for required steps.

<!--
See [Queries and datasets](#️-queries-and-datasets) below for additional details.
-->

<br>

<!--
## 🗃️ Queries and datasets

FinOps toolkit reports offer multiple versions of cost details to align to different schemas for backwards compatibility. These schemas are only provided to assist in migrating from older versions. We recommend updating visuals to use CostDetails or the newest underlying dataset. If you do not need legacy datasets, you can remove them from the Power Query Editor (Transform data) window.

<blockquote class="warning" markdown="1">
   _FinOps hubs will eventually adopt the [FOCUS standard](https://aka.ms/finops/focus) when available._
</blockquote>

### CostDetails

The **CostDetails** dataset is a reference to the latest version of the schema. All visuals in FinOps hub reports are connected to this latest version. If you do not want to point to the latest version, you can edit the CostDetails query in the Power Query editor and change it to reference a different schema version.

### CMExports

The CMExports dataset uses the raw column names from Cost Management exports. This mostly aligns to the CMConnector schema, but with a few small differences. See [CMConnector](#cmconnector) for details.

This dataset is hidden from the list of tables. To see it, right-click any table and select **Unhide all**.

### CMConnector

The CMConnector dataset uses the original schema from the "Azure Cost Management" Power BI connector. This dataset is only provided for backwards compatibility.

Internally, the CMConnector dataset starts with CMExports data and reverses the schema changes:

- **BillingCurrencyCode** renamed to **BillingCurrency**.
- **CostInBilling** renamed to **Cost**.
- **InvoiceSectionName** renamed to **InvoiceSection**.
- **IsAzureCreditEligible** renamed to **IsCreditEligible** and changed from a boolean to a string (`True` or `False`).
- **ProductName** renamed to **Product**.

Note the following columns are new in this release. These columns were not previously present in the Cost Management connector:

- **CostAllocationRuleName**
- **benefitId**
- **benefitName**
- **Month**
- **CPUHours**
- **CommitmentNameUnique**
- **ResourceNameUnique**
- **ResourceGroupNameUnique**
- **SubscriptionNameUnique**
- **CommitmentType**
- **CommitmentUtilizationAmount**
- **CommitmentUtilizationPotential**
- **RetailPrice**
- **RetailCost**
- **OnDemandCost**
- **CommitmentSavings**
- **DiscountSavings**
- **NegotiatedSavings**

<br>
-->

---

## 🧰 Related tools

{% include tools.md hubs="1" %}

<br>
