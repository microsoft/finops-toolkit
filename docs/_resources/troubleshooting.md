---
layout: default
title: Troubleshooting
nav_order: 999
description: 'Details and solutions for common issues you may experience.'
permalink: /help/troubleshoot
---

<span class="fs-9 d-block mb-4">Troubleshooting guide</span>
Sorry to hear you're having a problem. We're here to help!
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [⏩ Do you have a specific error code?](#-do-you-have-a-specific-error-code)
- [📋 Validate your FinOps hub deployment](#-validate-your-finops-hub-deployment)
- [📋 Validate your Power BI configuration](#-validate-your-power-bi-configuration)

</details>

---

## ⏩ Do you have a specific error code?

⚡ [Find common errors](./errors.md) ▶

<br>

## 📋 Validate your FinOps hub deployment

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

This guide helps you troubleshoot issues with the FinOps Hubs, focusing on two main sections: Data Ingestion and Connecting to Your Data. Always start troubleshooting with the Data Ingestion section before moving on to Connecting to Your Data.

### Step 1: Verify Cost Management exports

1. Go to Cost Management exports and make sure the export status is "Successful".
2. If it is not successful, ensure you have the Cost Management resource provider registered for the subscription where your hub is deployed.
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
### Step 5: Verify Data Explorer

1. TODO
-->

<br>

## 📋 Validate your Power BI configuration

### Step 1: Connect Power BI to storage

Decide whether you will connect to storage using a user or service principal account or using a storage account key (aka SAS token).

- **Using a user or service principal account**
  1. Ensure you have the Storage Blob Data Reader role explicitly to the account you will use. This permission is not inherited even if you have "Owner" or "Contributor" permissions.
- **Using a SAS token**
  1. Ensure you've set the following permissions for the token:
     - Allowed services: Blob
     - Allowed resource types: Container and Object
     - Allowed permissions: Read and List
  2. Ensure you have also set a valid start and expiry date/time.

### Step 2: Troubleshoot connection errors

1. If you try to connect to your storage account and receive an error: "Access to the resource is forbidden", it is very likely you are missing a few permissions. Refer back to [Connect Power BI to storage](#step-1-connect-power-bi-to-storage) to ensure you have the correct permissions.
2. If you see an error about access being forbidden, review if the billing account that you are connecting to is correct. Power BI reports are provided with a sample billing account, and if you don't change that to your own ID, you won't be able to connect.

### Step 3: Troubleshoot missing months of data

1. If the Power BI report does not include entire months of data, confirm the date parameters in the Power BI report by checking **Transform data** > **Edit parameters** in the ribbon. See [Set up your first report](../_reporting/power-bi/setup.md) for details.
   - **Number of Months** defines how many closed months (before the current month) will be shown in reports. Even if data is exported, data outside this range will not be shown. If defined, this parameter overrides others.
   - **RangeStart** and **RangeEnd define an explicit date range of data to show in the reports. Anything before or after these dates will not be shown.
   - If **RangeStart** is empty, all historical data before **RangeEnd** will be included.
   - If **RangeEnd** is empty, all new data after **RangeStart** will be included.
   - If all date parameters are empty, all available data will be included.

<br>