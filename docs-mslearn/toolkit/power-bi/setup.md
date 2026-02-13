---
title: Set up Power BI reports
description: Learn how to set up Power BI FinOps reports using the FinOps toolkit, customize visuals, and connect to your cost data for detailed analysis.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn how to set up Power BI FinOps reports so that I can use them analyze my cost data.
---

<!-- markdownlint-disable-next-line MD025 -->
# How to set up Power BI

The FinOps toolkit Power BI reports provide a great starting point for your FinOps reporting. We recommend customizing them to keep what works, edit and augment reports with your own data, and remove anything that isn't needed. You can also copy and paste visuals between reports to create your own custom reports.

FinOps toolkit reports support several ways to connect to your cost data. We generally recommend starting with Cost Management exports, which support up to $2-5 million in monthly spend. If you experience data refresh timeouts or need to report on data across multiple directories or tenants, use [FinOps hubs](../hubs/finops-hubs-overview.md). It's a data pipeline solution that optimizes data and offers more functionality. For more information about choosing the right backend, see [Help me choose](help-me-choose.md).

## Datasets and compatible tools

The following table shows the different datasets available and which reports and tools can access them:

| Dataset | Description | Compatible reports and tools | Notes |
|---------|-------------|------------------------------|-------|
| Cost Management exports | Raw cost and usage data exported to Azure Data Lake Storage Gen2 | • Power BI storage reports<br>• Custom Power BI reports<br>• Direct storage access | Recommended for accounts with less than $2M monthly spend |
| FinOps hubs + Data Explorer (ADX) | Cost data processed and stored in Azure Data Explorer clusters | • Power BI KQL reports<br>• Data Explorer dashboards<br>• Azure Monitor workbooks<br>• Direct KQL queries<br>• Custom applications via Kusto API | Recommended for accounts with more than $100K total spend |
| FinOps hubs + Microsoft Fabric RTI | Cost data processed and stored in Microsoft Fabric Real-Time Intelligence | • Power BI KQL reports<br>• Fabric Real-Time dashboards<br>• Direct KQL queries<br>• Custom applications via Kusto API | Best performance and capabilities option |
| Microsoft Fabric OneLake | Raw exports stored in Microsoft Fabric OneLake | • Custom Fabric notebooks<br>• Custom Power BI reports<br>• Fabric data pipelines | For organizations already using Microsoft Fabric |
| Cost Management connector | Direct Power BI connection to Cost Management APIs | • Cost Management connector Power BI reports | Deprecated - not recommended for new implementations |

Each dataset offers different capabilities and is optimized for different use cases. For detailed guidance on choosing the right option, see [Help me choose](help-me-choose.md).

Support for the [Cost Management connector for Power BI](/power-bi/connect-data/desktop-connect-azure-cost-management) is available for backwards compatibility, but isn't recommended. The Microsoft Cost Management team is no longer updating the Cost Management connector and instead recommends exporting data. Use following information to connect and customize FinOps toolkit and other Power BI reports.

<br>

## Set up your first report

The FinOps toolkit Power BI reports include preconfigured visuals, but aren't connected to your data. Use the following steps to connect them to your data:

1. Create a premium storage account with hierarchical namespace enabled.
   - If using [FinOps hubs](../hubs/finops-hubs-overview.md), you can skip this step. Storage is deployed as part of the template.
   - Use the following settings when creating a new storage account:
     - Primary service = **Azure Data Lake Storage Gen2**
     - Performance = **Premium**
     - Premium account type = **Block blobs**
     - Hierarchical namespace = **Enabled**
   - If using an existing storage account, verify the following settings:
     - On the **Overview** page, under **Essentials**, confirm **Performance** is set to **Premium**.
       - If set to "Standard", you will need to create a new storage account.
     - On the **Overview** page, under **Properties**, confirm **Hierarchical namespace** is set to **Enabled**.
       - If disabled, check the menu for **Settings** > **Data Lake Gen2 upgrade** and upgrade to Data Lake Gen2 storage.
       - If this option is not available and hierarchical namespace is not enabled, you must create a new storage account.
     - On the **Overview** page, under **Properties**, confirm **Access tier** is set to **Hot**.
       - If not, select the link and change the access tier to "Hot".
       - Other access tiers have not been tested and are not recommended due to the performance impact.
2. Configure Cost Management exports for any data you would like to include in reports.
   
   You can create exports manually in the Azure portal or programmatically using the [`New-FinOpsCostExport`](../powershell/cost/new-finopscostexport.md) PowerShell command. Include the following datasets:

   | Dataset                     | Version          | Notes                                                                                                                           |
   | --------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
   | Cost and usage (FOCUS)      | `1.0` or `1.0r2` | Required for all reports. If you need FOCUS 1.0-preview, use [FinOps hubs](../hubs/finops-hubs-overview.md) with Data Explorer. |
   | Price sheet                 | `2023-05-01`     | Required to populate missing prices for EA and MCA.                                                                             |
   | Reservation details         | `2023-03-01`     | Optional.                                                                                                                       |
   | Reservation recommendations | `2023-05-01`     | Required to see reservation recommendations in the Rate optimization report.                                                    |
   | Reservation transactions    | `2023-05-01`     | Optional.                                                                                                                       |

3. Download and open the desired report in Power BI Desktop.

   | Data source                                | Download                                                                                                                              | Notes                                                                                                      |
   | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
   | FinOps hubs with Data Explorer             | [KQL reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip)                                   | Recommended when monitoring over $100,000 or 13 months of data.                                            |
   | Exports in storage (including FinOps hubs) | [Storage reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip)                           | Not recommended when monitoring over $2 million per month.                                                 |
   | Cost Management connector                  | [Cost Management connector report](https://github.com/microsoft/finops-toolkit/releases/latest/download/CostManagementConnector.pbix) | Not recommended when monitoring over $1 million in total cost or accounts that contain savings plan usage. |

4. Open each report and specify the applicable report parameters:

   - **Cluster URI** (KQL reports only) &ndash; Required Data Explorer cluster URI.
     1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
     2. Select the hub resource group.
     3. Select **Deployments** in the menu.
     4. Select the **hub** deployment.
     5. Select **Outputs**.
     6. Copy the value for `clusterUri`.
        > [!IMPORTANT]
        > When using private endpoints in conjunction with a Power BI data gateway, make sure to use the fully qualified domain name (FQDN) of the Azure Data Explorer cluster (like `clustername.region.kusto.windows.net`) rather than the abbreviated version (like `clustername.region`). This ensures proper name resolution for the private endpoint functions as expected.
   - **Daily or Monthly** (KQL reports only) &ndash; Required granularity of data. Use this to report on longer periods of time.
     - Consider creating two copies of these reports to show both daily data for a short time period and monthly data for historical reporting.
   - **Storage URL** (storage reports only) &ndash; Required DFS endpoint for the Azure Data Lake Storage account with your data.
     - If connecting to FinOps hubs:
       1. Open the [list of resource groups](https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups) in the Azure portal.
       2. Select the hub resource group.
       3. Select **Deployments** in the menu.
       4. Select the **hub** deployment.
       5. Select **Outputs**.
       6. Copy the value for `storageUrlForPowerBI`.
     - If connecting directly to Cost Management exports in storage:
       1. Open the desired storage account in the Azure portal.
       2. Select **Settings** > **Endpoints** in the menu.
       3. Copy the **Data Lake Storage** URL (not the Blob service URL).
          > [!IMPORTANT]
          > Make sure to use the Data Lake Storage endpoint (contains `.dfs.core.windows.net`), not the Blob service endpoint (contains `.blob.core.windows.net`). Power BI storage reports require the DFS endpoint to function properly.
       4. Append the container and export path, if applicable.
   - **Number of Months** &ndash; Optional number of closed months you would like to report on if you want to always show a specific number of recent months. If not specified, the report will include all data in storage.
   - **RangeStart** / **RangeEnd** &ndash; Optional date range you would like to limit to. If not specified, the report will include all data in storage.
     - We generally recommend leaving these dates empty. They are included to support incremental refresh.
     - If you need to configure incremental refresh, consider using [FinOps hubs](../hubs/finops-hubs-overview.md) with Data Explorer instead.
     - FinOps hubs with Data Explorer offers improved performance and is recommended for anyone monitoring over $100,000 in total spend.
     - Storage reports only support ~$2 million of data without incremental refresh and ~$2 million per month in raw cost details. To learn more, see [Configure incremental refresh](/power-bi/connect-data/incremental-refresh-configure#define-policy).

5. Authorize each data source:

   - **Azure Data Explorer (Kusto)** &ndash; Use an account that has at least viewer access to the Hub database.
   - **Azure Resource Graph** &ndash; Use an account that has direct access to any subscriptions you would like to report on.
   - **(your storage account)** &ndash; Use a SAS token or an account that has Storage Blob Data Reader or greater access.
   - **https://ccmstorageprod...** &ndash; Anonymous access. This URL is used for reservation size flexibility data.
   - **https://github.com/...** &ndash; Anonymous access. This URL is used for FinOps toolkit open data files.

If you run into any issues syncing your data, see [Troubleshooting Power BI reports](../help/troubleshooting.md).

<br>

## Configure scheduled refresh in Power BI service

After publishing your reports to the Power BI service, you can configure scheduled refresh to automatically update your data on a regular basis. The need for scheduled refresh depends on your data source:

**Data sources that require scheduled refresh:**
- **Storage-based reports** (Cost Management exports) &ndash; Data is exported periodically and needs to be refreshed to reflect the latest exports.
- **Azure Resource Graph queries** &ndash; Resource information changes over time and should be refreshed regularly.
- **FinOps toolkit open data** &ndash; Reference data is updated periodically and should be refreshed to get the latest versions.

**Data sources that do not require scheduled refresh:**
- **FinOps hubs with Azure Data Explorer** &ndash; Data is automatically ingested and immediately available through KQL queries.
- **FinOps hubs with Microsoft Fabric** &ndash; Data is automatically ingested and immediately available through SQL queries.

### Set up scheduled refresh

To configure scheduled refresh for your published Power BI reports:

1. **Publish your report to Power BI service:**
   1. In Power BI Desktop, select **File** > **Publish** > **Publish to Power BI**.
   2. Choose your workspace and select **Select**.
   3. Once published, select **Got it** to close the confirmation dialog.

2. **Configure the semantic model refresh:**
   1. Open the [Power BI service](https://app.powerbi.com) in your web browser.
   2. Navigate to your workspace.
   3. In the workspace, locate your semantic model (it has the same name as your report).
   4. Select the **More options** (three dots) menu for the semantic model.
   5. Select **Settings**.

3. **Set up data source credentials:**
   1. In the **Data source credentials** section, configure credentials for each data source:
      - For **Azure Data Lake Storage Gen2**: Use your organizational account or configure a service principal.
      - For **Azure Resource Graph**: Use your organizational account with appropriate subscription access.
      - For **https://github.com/...**: This should already be set to anonymous access.
   2. Select **Sign in** for each data source that requires authentication.

4. **Configure scheduled refresh:**
   1. In the **Scheduled refresh** section, turn on **Keep your data up to date**.
   2. Choose your refresh frequency (for example, **Daily** or **Weekly**).
   3. Add refresh times that work for your organization.
   4. Optionally, configure **Refresh failure notifications** to receive email alerts if refresh fails.
   5. Select **Apply**.

### Refresh frequency recommendations

For optimal performance and cost management:

- **Cost data (exports)**: Daily refresh is typically sufficient as Cost Management exports are usually updated once per day.
- **Resource data**: Weekly refresh may be sufficient unless you need to track resource changes more frequently.
- **Reference data**: Weekly or monthly refresh is typically sufficient for FinOps toolkit open data.

For FinOps hubs using Azure Data Explorer or Microsoft Fabric, data is ingested automatically and you don't need to configure refresh schedules.

### Troubleshooting refresh issues

If you encounter refresh failures:

1. **Check data source credentials** &ndash; Ensure all credentials are valid and have appropriate permissions.
2. **Review the refresh history** &ndash; Check the semantic model settings for error details in the refresh history.
3. **Verify storage account access** &ndash; Ensure the account has Storage Blob Data Reader access to the storage account.
4. **Check for data size limits** &ndash; Large datasets may require incremental refresh configuration.

For more information about configuring scheduled refresh in Power BI, see:
- [Configure scheduled refresh](/power-bi/connect-data/refresh-scheduled-refresh) in Power BI documentation
- [Configure scheduled refresh for semantic models in Microsoft Fabric](/fabric/data-warehouse/semantic-model-refresh) for Fabric-specific guidance

<br>

## Use a SAS token to connect data to a report

Shared Access Signature (SAS) tokens allow you to connect to a storage account without end user credentials or setting up a service principal. To connect Power BI reports to your data via SAS tokens:

1. Generate the SAS token with required permissions:
   1. Navigate the FinOps hub storage account in the Azure portal.
   2. Select **Security + Networking** > **Shared access signature** in the menu on the left.
   3. Under **Allowed resource types**, select `Container` and `Object`.
   4. Under **Allowed permissions**, select **Read, List**.
   5. Provide the start and expiration date range as desired.
   6. Keep the remaining default values or update as desired.
   7. Select **Generate SAS token and URL**.
   8. Copy the generated token.

   :::image type="content" source="./media/setup/storage-account-sas.png" border="true" alt-text="Screenshot showing the SAS token configuration in the Azure portal." lightbox="./media/setup/storage-account-sas.png" :::

1. Configure SAS token access in Power BI:
   1. Open the report in Power BI Desktop.
   2. Select **Transform data** > **Data Source Settings** in the ribbon.
   3. Select **Edit permissions** at the bottom of the dialog.
   4. Select **Edit** below the credentials.
      :::image type="content" source="./media/setup/data-source-permissions.png" border="true" alt-text="Screenshot of the data source settings within Transform data." lightbox="./media/setup/data-source-permissions.png" :::
   5. Select the **Shared access signature** tab.
   6. Paste the copied SAS token from the Azure portal.
   7. Select **Save**.
   8. Select **Close**.
   9. Select **Apply and Close** in the ribbon.
      :::image type="content" source="./media/setup/sas-token.png" border="true" alt-text="Screenshot showing the SAS token dialog." lightbox="./media/setup/sas-token.png" :::

If you get a **403 Forbidden** error, create a SAS token at the storage account level instead of the container level.

<br>

## Copy queries from a toolkit report

FinOps toolkit reports manipulate the raw data to facilitate specific types of reports. To connect your data to a Power BI report that doesn't use a FinOps toolkit or Cost Management data source, copy queries, columns, and measures from a FinOps toolkit report.

1. Download one of the FinOps toolkit reports.
2. Open the report in Power BI Desktop.
3. Select **Transform data** in the toolbar.
4. In the Queries list on the left, right-click **Costs** (or other query) and select **Copy**.
5. Open your report in Power BI Desktop.
6. Select **Transform data** in the toolbar.
7. Right-click the empty space in the bottom of the **Queries** pane and select **New group...**.
8. Set the name to `FinOps toolkit` and select **OK**.
9. Right-click the **FinOps toolkit** folder and select **Paste**.
10. Select **Close & Apply** in the toolbar for both reports.

At this point, you have the core data from the FinOps toolkit reports, extended to support Azure Hybrid Benefit and FOCUS reports. In addition, you might also be interested in the custom columns and measures that summarize savings, utilization, cost over time, and more. Unfortunately, Power BI doesn't provide an easy way to copy columns and measures. Perform the steps for each column and measure you'd like to copy:

1. In the FinOps toolkit report, expand the **Costs** (or other table) table in the **Data** pane on the right.
2. Select a custom column or measure, then copy the formula from the editor at the top of the window, under the toolbar.
   > [!NOTE]
   > Be sure to make note if this is a column or a measure. Columns have a table symbol with a "Σ" or "fx" symbol and measures have a calculator symbol.
   >
   > :::image type="content" source="./media/setup/column-icons.png" border="true" alt-text="Screenshot showing the calculated column and measure icons in Power BI." lightbox="./media/setup/column-icons.png" :::
3. In your report, right select the **Costs** table and select **New measure** or **New column** based on what you copied.
4. When the formula editor is shown, paste the formula using `Ctrl+V` or `Cmd+V`.
5. Repeat steps 2-4 for each desired column and measure.

Some columns and measures depend on one another. You can ignore those errors as you copy each formula. Each resolves itself when the dependent column or measure is added.

For details about the columns available in Power BI, refer to the [data dictionary](../help/data-dictionary.md).

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
     3. Copy the **Data Lake Storage** URL (not the Blob service URL).
     4. Append the container and export path, if applicable.
5. Select **OK**.
   > [!WARNING]
   > If you receive an "Access to the resource is forbidden" error, grant the account loading data in Power BI the [Storage Blob Data Reader role](/azure/role-based-access-control/built-in-roles#storage-blob-data-reader).
6. Select **Combine**.
7. Select **OK**.

For more information about connecting to Azure Data Lake Storage Gen2, see [Connect to Azure Data Lake Storage Gen2 from Power Query Desktop](/power-query/connectors/data-lake-storage#connect-to-azure-data-lake-storage-gen2-from-power-query-desktop).

For details about the columns available in storage, refer to the [data dictionary](../help/data-dictionary.md).

<br>

## Migrate from the Cost Management template app

The Cost Management template app doesn't support customization in Power BI Desktop and is only supported for Enterprise Agreement (EA) accounts. We recommend starting from one of the FinOps toolkit reports that work across account types rather than customizing the template app. If you would like to customize or copy something from the template, see [Cost Management template app](template-app.md).

<br>

## Migrate from the Cost Management connector

The Cost Management connector provides separate queries for actual (billed) and amortized costs. To minimize data size and improve performance, the FinOps toolkit reports combine them into a single query. The best way to migrate from the Cost Management connector is to copy the queries from a FinOps toolkit report and then update your visuals to use the **Costs** table.

1. Download one of the FinOps toolkit reports.
2. Open the report in Power BI Desktop.
3. Select **Transform data** in the toolbar.
4. In the **Queries** list on the left, right-click **Costs** and select **Copy**.
5. Before you change your report, make a copy first to ensure you can roll back if needed.
6. Open your report in Power BI Desktop.
7. Select **Transform data** in the toolbar.
8. Right-click the empty space in the bottom of the **Queries** pane and select **New group...**.
9. Set the name to `FinOps toolkit` and select **OK**.
10. Right-click the **FinOps toolkit** folder and select **Paste**.
11. Right-click the **Costs** query and select **Advanced Editor**.
12. Copy all text and close the editor dialog.
13. Right-click the **Usage details** query and select **Advanced Editor**.
14. Replace all text with the copied text from Costs and select **Done**.
15. Rename the **Usage details** query to `Costs` and drag it into the `FinOps toolkit` folder.
16. Delete the **Usage details amortized** query.
17. Select **Close & Apply** in the toolbar for both reports.
18. Review each page to ensure the visuals are still working as expected. Update any references to old columns or measures to the new names.
    1. Start at the report level:
       - In the **Data** pane, expand each custom table and check custom columns and measures.
       - In the **Filters** pane, check **Filters on all pages**.
    2. Then check each page:
       - In the **Filters** pane, check **Filters on this page**.
    3. Then check each visual on each page:
       - In the **Filters** pane, check **Filters on this visual**.
       - In the **Visualizations** pane, check **Fields**.
         > [!NOTE]
         > If the column name was customized and you aren't sure what the original name was, right-click the field and select **Rename for this visual**, then delete the name, and press `Enter` to reset the name back to the original column name.

If interested in custom columns and measures, see [Copy queries from a toolkit report](#copy-queries-from-a-toolkit-report) for required steps.

<br>

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
