---
title: Troubleshooting FinOps toolkit issues
description: This article describes how to validate that FinOps toolkit solutions are deployed and configured correctly, including troubleshooting common errors.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: troubleshooting
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to validate FinOps toolkit solutions are deployed and configured correctly.
---

<!-- markdownlint-disable-next-line MD025 -->

# FinOps toolkit troubleshooting guide

This article describes how to validate FinOps toolkit solutions were deployed and configured correctly. If you have a specific error code, review [common errors](errors.md) for details and mitigation steps. If you need a more thorough walkthrough to validate your configuration, use the following steps that apply to you.

<!--
If the information provided doesn't help you, [Create a support request](/azure/cost-management-billing/costs/cost-management-error-codes#create-a-support-request).
-->

<br>

## Do you have a specific error code?

If you have a specific error code, we recommend starting with [common errors](errors.md) for a direct explanation of the issue you're facing. There's also information about how to mitigate or work around the issue.

<br>

## Validate your FinOps hub deployment

Use the following steps to validate your FinOps hub deployment:

<!--
1. [Cost Export](#cost-export)
2. [Azure Data Factory](#data-factory)
3. [Storage Account (MSExport and Ingestion Containers)](#storage-account)
4. [Power BI](#power-bi)

### Cost Management export

- Error: "Failed to export cost data" - Ensure the Cost Management register provider is registered.
- Error: "Export status failed" - Verify subscription settings and permissions.

### Data Factory

- Error: "Pipeline failed to run" - Check triggers and resource provider registration.
- Error: "Pipeline not running" - Ensure pipelines are active and compare last run times.

### Storage account

- Error: "No parquet files in Ingestion container" - Verify Data Factory pipeline and Cost Export status.
- Error: "CSV files in MSExport container" - Data Factory pipeline not transforming data.

### Power BI

- Error: "Access to the resource is forbidden" - Check user permissions or SAS token settings.
- Error: "Invalid Billing Account ID" - Ensure the correct billing account ID is used in the Commitment Discounts report.
-->

### Step 1: Verify Cost Management exports

1. Go to Cost Management exports and make sure the export status is `Successful`.
2. If it isn't successful, ensure you have the Cost Management resource provider registered for the subscription where your hub is deployed.
3. File a support request with the Cost Management team to investigate further.

### Step 2: Verify Data Factory pipelines

1. From Data Factory Studio, select Monitor on the left menu and confirm pipelines are running successfully.
2. If pipelines are failing, review the error code and message and check [common errors](errors.md) for mitigation steps.
3. Compare the last run time with the time of the last export. They should be close.
4. Select **Manage** > **Author** > **Triggers** and verify the `msexports_ManifestAdded` trigger is started. If not, start it.
5. If the trigger fails to start with a "resource provider is not registered" error, open the subscription in the Azure portal, select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select **Register**. Registration may take a few minutes.
6. After registration completes, start the `msexports_ManifestAdded` trigger again.
7. After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes.
8. If the ingestion pipeline is not running and it is showing a `MappingColumnNameNotFoundInSourceFile` error message, verify the export is configured for a [supported dataset and version](../hubs/data-processing.md#datasets).

### Step 3: Verify storage account – msexports container

1. The **msexports** container is where Cost Management pushes "raw" exports to.
2. Confirm there are no CSV or parquet files in the most recent export path.
3. If there are CSV or parquet files from Cost Management exports, open Data Factory Studio and confirm the **msexports_ExecuteETL** and **msexports_ETL_ingestion** pipelines are successful.
   - Exported files are removed when ingestion completes unless the **msexports** container is configured to have a positive retention policy.

### Step 4: Verify storage account – ingestion container

1. The **ingestion** container is where clients, like Power BI, connect to pull data. This container should always have one or more parquet files for each month.
2. If you don't see any parquet files in the ingestion container, check for files in the **msexports** container.
3. If you find CSV or parquet files in the **msexports** container, it means that Data Factory pipeline is not working. Refer back to [Verify Data Factory pipelines](#step-2-verify-data-factory-pipelines).
4. If there are no files in the **msexports** container and no parquet files inside the ingestion container, it means the Cost Management export is not running properly. Refer back to [Verify Cost Management exports](#step-1-verify-cost-management-exports).

<!--
### Step 5: Confirm data ingestion is working

1. TODO
-->

<br>

## Validate your Power BI configuration

Use the following steps to validate your Power BI configuration:

### Step 1: Identify your storage URL

Before you begin validating your Power BI configuration, you need to know whether you're connecting to your data using one of the following mechanisms:

- Cost Management connector for Power BI – Ideal for small accounts with limited needs. Not recommended if reporting on more than $2M in total costs.
- Cost Management exports in storage – Requires exporting data from Cost Management into a storage account. Doesn't require other deployments.
- FinOps hubs – Requires deploying the [FinOps hub solution](../hubs/finops-hubs-overview.md).

If you need assistance in choosing the best approach for your needs, see [Choosing a Power BI data source](../power-bi/help-me-choose.md).

If using the Cost Management connector, see [Create visuals and reports with the Cost Management connector in Power BI Desktop](/power-bi/connect-data/desktop-connect-azure-cost-management).

If using FinOps hubs, you can copy the URL from the deployment outputs in the Azure portal:

1. Navigate to the resource group where FinOps hubs was deployed.
2. Select **Settings** > **Deployments** in the menu.
3. Select the **hub** deployment.
4. Select **Outputs** in the menu.
5. Copy the **storageUrlForPowerBI** value.
6. Paste this URL into the **Hub storage URL** in Power BI.
7. If using raw exports for any data, also use the following steps.
8. If not using raw exports for any data, paste the hub storage URL into the **Export storage URL** in Power BI.
   > [!NOTE]
   > Power BI requires both parameters to be set in order for the Power BI service to refresh datasets.

If using raw exports without FinOps hubs for any datasets (even if you're using hubs for cost data), you can obtain the Data Lake Storage URI from your storage account in the Azure portal:

1. Navigate to the storage account in the Azure portal.
2. Select **Settings** > **Endpoints** in the menu.
3. Copy the **Data Lake Storage** > **Data Lake Storage** URL.
4. Paste this URL into the **Export storage URL** in Power BI.
5. If using FinOps hubs for any data, also follow the preceding steps.
6. If not using FinOps hubs for any data, paste the export storage URL into the **Hub storage URL** in Power BI.
   > [!NOTE]
   > Power BI requires both parameters to be set in order for the Power BI service to refresh datasets.

### Step 2: Connect Power BI to storage

Decide whether want to connect to storage using a user or service principal account or using a storage account key (also called SAS token).

- **Using a user or service principal account**
  1. Ensure you have the Storage Blob Data Reader role explicitly to the account to use. This permission isn't inherited even if you have "Owner" or "Contributor" permissions.
- **Using a SAS token**
  1. Ensure you set the following permissions for the token:
     - Allowed services: Blob
     - Allowed resource types: Container and Object
     - Allowed permissions: Read and List
  2. Ensure you have also set a valid start and expiry date/time.

### Step 3: Troubleshoot connection errors

1. If you try to connect to your storage account and receive the `Access to the resource is forbidden` error, it's likely you're missing a few permissions. To ensure you have the correct permissions, refer back to [Connect Power BI to storage](#step-2-connect-power-bi-to-storage).
2. If you see an error about access being forbidden, review if the billing account that you're connecting to is correct. Power BI reports are provided with a sample billing account, and if you don't change that to your own ID, you can't connect.

### Step 4: Troubleshoot missing months of data

1. If the Power BI report doesn't include entire months of data, confirm the date parameters in the Power BI report by checking **Transform data** > **Edit parameters** in the ribbon. See [Set up your first report](../power-bi/setup.md) for details.
   - **Number of Months** defines how many closed months (before the current month) get shown in reports. Even if data is exported, data outside this range isn't shown. If defined, this parameter overrides others.
   - **RangeStart** and **RangeEnd** define an explicit date range of data to show in the reports. Anything before or after these dates isn't shown.
   - If **RangeStart** is empty, all historical data before **RangeEnd** is included.
   - If **RangeEnd** is empty, all new data after **RangeStart** is included.
   - If all date parameters are empty, all available data is included.

<br>

## Debug Power BI query failures

If Power BI returns an unknown error, use the following steps to identify the problem.

### Identify the failing query

1. Open the report.
2. In the ribbon, select **Transform data** > **Transform data**.
3. From the **Power Query Editor** window, find the query that is failing in the list of queries on the left.
4. Jump to the troubleshooting section based on the folder.

### Troubleshoot storage query errors

1. From the **Power Query Editor** window, select the query that is failing in the list of queries on the left.
2. In the **Applied Steps** section on the right, select the **RawData** step.
3. If that step errors, skip down to [Troubleshoot ftk_Storage errors](#troubleshoot-ftk_storage-errors).
4. If that step works, select the next step below it, skipping anything that starts with a lowercase or underscore.
5. Repeat step 4 until you find the first step that errors.
6. Share the name of the first step that is failing in any issue or support request to help troubleshoot further.

### Troubleshoot ftk_Storage errors

1. From the **Power Query Editor** window, right-click the **ftk_Storage** function on the left and select **Duplicate**.
2. Right-click **ftk_Storage (2)** and select **Advanced Editor**.
3. Remove the first line and replace the `data = if datasetType...` line with `data = "focuscost",`.
4. Select **Done** at the bottom-right of the dialog.
5. Select **ftk_Storage (2)** on the left and then click **Refresh Preview** in the ribbon at the top.
6. In the **Applied Steps** on the right, select the last step.
7. If that step errors, select the one before it (skip anything with an underscore or lowercase first character).
8. Repeat 7 until you find one that works.
9. Share the name of the first step that is failing in any issue or support request to help troubleshoot further.

### Troubleshoot Hub*and Storage* query errors

1. From the **Power Query Editor** window, select the failing query on the left and then click **Refresh Preview** in the ribbon at the top.
2. In the **Applied Steps** on the right, select the last step.
3. If that step errors, select the one before it (skip anything with an underscore or lowercase first character).
4. Repeat 3 until you find one that works.
5. Share the name of the first step that is failing in any issue or support request to help troubleshoot further.

<br>

<!--
## Create a support request

If you're facing an error not listed above or need more help, file a [support request](/azure/azure-portal/supportability/how-to-create-azure-support-request) and specify the issue type as Billing.

<br>
-->

## Still need help?

If you've followed the troubleshooting steps and still need assistance, join our [biweekly office hours](https://aka.ms/ftk/office-hours) to get live help from the team. If you need more hands-on support, you can request a paid, community-driven advisory session or consulting delivery during the office hours call.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"] > [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Toolkit/featureName/Help.Troubleshooting)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"] > [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)

<br>

## Related content

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
