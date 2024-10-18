---
title: Set up Power BI reports
description: Learn how to set up Power BI FinOps reports using the FinOps toolkit, customize visuals, and connect to your cost data for detailed analysis.
author: bandersmsft
ms.author: banders
ms.date: 10/03/2024
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn how to set up Power BI FinOps reports so that I can use them analyze my cost data.
---

<!-- markdownlint-disable-next-line MD025 -->
# How to set up Power BI

The FinOps toolkit Power BI reports provide a great starting point for your FinOps reporting. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed. You can also copy and paste visuals between reports to create your own custom reports.

FinOps toolkit reports support several ways to connect to your cost data. We generally recommend starting with Cost Management exports, which support up to $2-5 million in monthly spend. If you experience data refresh timeouts or need to report on data across multiple directories or tenants, use [FinOps hubs](../hubs/finops-hubs-overview.md). It's a data pipeline solution that optimizes data and offers more functionality. For more information about choosing the right backend, see [Help me choose](help-me-choose.md).

Support for the [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) is available for backwards compatibility, but isn't recommended. The Microsoft Cost Management team is no longer updating the Cost Management connector and instead recommends exporting data. Use following information to connect and customize FinOps toolkit and other Power BI reports.

<br>

## Set up your first report

The FinOps toolkit Power BI reports include preconfigured visuals, but aren't connected to your data. Use the following steps to connect them to your data:

1. Configure Cost Management exports for any data you would like to include in reports, including:

   - Cost and usage (FOCUS) &ndash; Required for all reports.
   - Price sheet
   - Reservation details
   - Reservation recommendations &ndash; Required to see reservation recommendations in the Rate optimization report.
   - Reservation transactions

2. Download and open the desired report in Power BI Desktop.
3. Select **Transform data** on the toolbar.

   :::image type="content" source="./media/setup/transform-data.png" border="true" alt-text="Screenshot of the Transform data button in the Power BI Desktop toolbar." lightbox="./media/setup/transform-data.png" :::

   :::image type="content" source="./media/setup/start-here.png" border="true" alt-text="Screenshot showing instructions to connect to a storage account." lightbox="./media/setup/start-here.png" :::

4. If connecting to a FinOps hub instance, set the **Hub Storage URL**.
   1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
   2. Select the hub resource group.
   3. Select **Deployments** in the menu.
   4. Select the **hub** deployment.
   5. Select **Outputs**.
   6. Copy the value for `storageUrlForPowerBI`.
5. If connecting directly to Cost Management exports, set the **Export Storage URL**.
   1. Open the desired storage account in the Azure portal.
   2. Select **Settings** > **Endpoints** in the menu.
   3. Copy the **Data Lake Storage** URL.
   4. Append the container and export path, if applicable.
6. If only using one storage URL (whether it's for hubs or exports), paste that same URL in both parameters.
   - When only one URL is specified, the Power BI service thinks there's a problem. It blocks configuring a scheduled refresh.
   - To work around this problem, copy the same URL into both parameters.
   - If using hubs, the export storage URL is never used.
   - If using exports, the hub URL is ignored since exports don't meet the hub storage requirements.
   - These parameters will be merged in a future update.
7. Specify how much data you would like to include from storage using one of the following methods:
   - Set **Number of Months** to the number of closed months you would like to report on if you want to always show a specific number of recent months.
   - Set **RangeStart** and **RangeEnd** to specific start/end dates if you don't want the dates to move (for example, fiscal year reporting).
   - Don't set any date parameters to report on all data in storage.
     > [!WARNING]
     > [Enable incremental refresh](/power-bi/connect-data/incremental-refresh-configure#define-policy) to load more than $5M of raw cost details. Power BI reports can only support $2-5M of data when incremental refresh is not enabled. After incremental refresh is enabled, they can support $2-5M/month for a total of ~$65M in raw cost details.
8. Select **Close & Apply** to save your settings.

If you run into any issues syncing your data, see [Troubleshooting Power BI reports](../help/troubleshooting.md).

<br>

## Use a SAS token to connect data to a report

Shared Access Signature (SAS) tokens allow you to connect to a storage account without end user credentials or setting up a service principal. 

> [!NOTE]
> This article contains images showing example data. Any price data is for test purposes only.

To connect Power BI reports to your data via SAS tokens:

1. Generate the SAS token with required permissions:
   - Navigate the FinOps hub storage account in the Azure portal.
   - Select **Security + Networking** > **Shared access signature** in the menu on the left.
   - Under **Allowed resource types**, select `Container` and `Object`.
   - Under **Allowed permissions**, select **Read, List**.
   - Provide the start and expiration date range as desired.
   - Keep the remaining default values or update as desired.
   - Select **Generate SAS token and URL**.
   - Copy the generated token.

   :::image type="content" source="./media/setup/storage-account-sas.png" border="true" alt-text="Screenshot showing the SAS token configuration in the Azure portal." lightbox="./media/setup/storage-account-sas.png" :::

2. Configure SAS token access in Power BI:
   - Open the report in Power BI Desktop.
   - Select **Transform data** > **Data Source Settings** in the ribbon.
   - Select **Edit permissions** at the bottom of the dialog.
   - Select **Edit** below the credentials.

   :::image type="content" source="./media/setup/data-source-permissions.png" border="true" alt-text="Screenshot of the data source settings within Transform data." lightbox="./media/setup/data-source-permissions.png" :::

   - Select the **Shared access signature** tab.
   - Paste the copied SAS token from the Azure portal.
   - Select **Save**.
   - Select **Close**.
   - Select **Apply and Close** in the ribbon.

   :::image type="content" source="./media/setup/sas-token.png" border="true" alt-text="Screenshot showing the SAS token dialog." lightbox="./media/setup/sas-token.png" :::

<br>

## Copy queries from a toolkit report

FinOps toolkit reports manipulate the raw data to facilitate specific types of reports. To connect your data to a Power BI report that doesn't use a FinOps toolkit or Cost Management data source, copy queries, columns, and measures from a FinOps toolkit report.

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

At this point, you have the core data from the FinOps toolkit reports, extended to support Azure Hybrid Benefit and FOCUS reports. In addition, you might also be interested in the custom columns and measures that summarize savings, utilization, cost over time, and more. Unfortunately, Power BI doesn't provide an easy way to copy columns and measures. Perform the steps for each column and measure you'd like to copy:

1. In the FinOps toolkit report, expand the **CostDetails** (or other table) table in the **Data** pane on the right.
2. Select a custom column or measure, then copy the formula from the editor at the top of the window, under the toolbar.
   > [!NOTE]
   > Be sure to make note if this is a column or a measure. Columns have a table symbol with a "Σ" or "fx" symbol and measures have a calculator symbol.
   >
   > :::image type="content" source="./media/setup/column-icons.png" border="true" alt-text="Screenshot showing the calculated column and measure icons in Power BI." lightbox="./media/setup/column-icons.png" :::
3. In your report, right select the **CostDetails** table and select **New measure** or **New column** based on what you copied.
4. When the formula editor is shown, paste the formula using `Ctrl+V` or `Cmd+V`.
5. Repeat steps 2-4 for each desired column and measure.

Some columns and measures depend on one another. You can ignore those errors as you copy each formula. Each resolves itself when the dependent column or measure is added.

<!-- TODO: Uncomment when files are added
For details about the columns available in Power BI, refer to the [data dictionary](../../_resources/data-dictionary.md).
-->

<br>

## Connect manually

If you don't need any of the custom columns and measures provided by the FinOps toolkit reports, you can also connect directly to your data using one of the built-in Power BI connectors.

If using the Cost Management connector, refer to [Create visuals and reports with the Cost Management connector](/power-bi/connect-data/desktop-connect-azure-cost-management).

If using exports or FinOps hubs, you use the Azure Data Lake Storage Gen2 connector:

1. Open your desired report in Power BI Desktop.
2. Select **Get data** in the toolbar.
3. Search for `lake` and select **Azure Data Lake Storage Gen2**
4. Set the URL of your storage account.
   - If using FinOps hubs, copy the URL from deployment outputs:
     1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
     2. Select the hub resource group.
     3. Select Deployments in the menu.
     4. Select the **hub** deployment.
     5. Select **Outputs**.
     6. Copy the value for `storageUrlForPowerBI`.
   - If using raw exports, copy the URL from the storage account:
     1. Open the desired storage account in the Azure portal.
     2. Select **Settings** > **Endpoints** in the menu.
     3. Copy the **Data Lake Storage** URL.
     4. Append the container and export path, if applicable.
5. Select **OK**.
   > [!WARNING]
   > If you receive an "Access to the resource is forbidden" error, grant the account loading data in Power BI the [Storage Blob Data Reader role](/azure/role-based-access-control/built-in-roles#storage-blob-data-reader).
6. Select **Combine**.
7. Select **OK**.

For more information about connecting to Azure Data Lake Storage Gen2, see [Connect to ADLS Gen2](/power-query/connectors/data-lake-storage#connect-to-azure-data-lake-storage-gen2-from-power-query-desktop).

<!-- TODO: Uncomment when files are added
For details about the columns available in storage, refer to the [data dictionary](../../_resources/data-dictionary.md).
-->

<br>

## Migrate from the Cost Management template app

The Cost Management template app doesn't support customization in Power BI Desktop and is only supported for Enterprise Agreement (EA) accounts. We recommend starting from one of the FinOps toolkit reports that work across account types rather than customizing the template app. If you would like to customize or copy something from the template, see [Cost Management template app](template-app.md).

<br>

## Migrate from the Cost Management connector

The Cost Management connector provides separate queries for actual (billed) and amortized costs. To minimize data size and improve performance, the FinOps toolkit reports combine them into a single query. The best way to migrate from the Cost Management connector is to copy the queries from a FinOps toolkit report and then update your visuals to use the **CostDetails** table.

1. Download one of the FinOps toolkit reports.
2. Open the report in Power BI Desktop.
3. Select **Transform data** in the toolbar.
4. In the **Queries** list on the left, right-click **CostDetails** and select **Copy**.
5. Before you change your report, make a copy first to ensure you can roll back if needed.
6. Open your report in Power BI Desktop.
7. Select **Transform data** in the toolbar.
8. Right-click the empty space in the bottom of the **Queries** pane and select **New group...**.
9. Set the name to `FinOps toolkit` and select **OK**.
10. Right-click the **FinOps toolkit** folder and select **Paste**.
11. Right-click the **CostDetails** query and select **Advanced Editor**.
12. Copy all text and close the editor dialog.
13. Right-click the **Usage details** query and select **Advanced Editor**.
14. Replace all text with the copied text from CostDetails and select **Done**.
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
        > [!NOTE]
        > If the column name was customized and you aren't sure what the original name was, right-click the field and select **Rename for this visual**, then delete the name, and press `Enter` to reset the name back to the original column name.

If interested in custom columns and measures, see [Copy queries from a toolkit report](#copy-queries-from-a-toolkit-report) for required steps.

<!--
See [Queries and datasets](#️-queries-and-datasets) below for additional details.
-->

<br>

<!--
## Queries and datasets

FinOps toolkit reports offer multiple versions of cost details to align to different schemas for backwards compatibility. These schemas are only provided to assist in migrating from older versions. We recommend updating visuals to use CostDetails or the newest underlying dataset. If you do not need legacy datasets, you can remove them from the Power Query Editor (Transform data) window.

<blockquote class="warning" markdown="1">
   _FinOps hubs will eventually adopt the [FOCUS standard](../../focus/what-is-focus.md) when available._
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

## Related content

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Resource Graph](/azure/governance/resource-graph/)
- [Azure Monitor](/azure/azure-monitor/)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
