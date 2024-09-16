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


<sup>Severity: Critical</sup>

Unable to identify the version of FinOps hubs from the settings file. Please verify settings are correct. FinOps hubs 0.1.1 and earlier does not work with this Power BI report.

**Mitigation**: Upgrade to the latest version of [FinOps hubs](../_reporting/hubs/README.md) or download Power BI reports from https://github.com/microsoft/finops-toolkit/releases/tag/v0.1.1

---

## UnsupportedExportType

<sup>Severity: Warning</sup>

The export manifest in hub storage indicates the export was for an unsupported dataset. Exported data will be reported as ingestion errors.

**Mitigation**: Create a new Cost Management export for FOCUS cost and either stop the current export or change it to export to a different storage container.

---

## The \<name> resource provider is not registered in subscription \<guid>

Open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the resource provider row (e.g., Microsoft.EventGrid), then select the **Register** command at the top of the page. Registration may take a few minutes.

---

## x_PricingSubcategory shows the commitment discount ID

Cost Management exports before Feb 28, 2024 had a bug where `x_PricingSubcategory` was being set incorrectly for committed usage. You should expect to see values like `Committed Spend` and `Committed Usage`. Instead, you may see values like:

- `Committed /providers/Microsoft.BillingBenefits/savingsPlanOrders/###/savingsPlans/###`
- `Committed /providers/Microsoft.Capacity/reservationOrders/###/reservations/###`

If you see these values, please re-export the cost data for that month. If you need to export data for an older month that is not available, please contact support to request the data be exported for you to resolve the data quality issue from the previous export runs.

---

## Power BI: Reports are empty (no data)

If you don't see any data in your Power BI or other reports or tools, try the following based on your data source:

1. If using the Cost Management connector in Power BI, check the `Billing Account ID` and `Number of Months` parameters to ensure they're set correctly. Keep in mind old billing accounts may not have data in recent months.
2. If using FinOps hubs, check the storage account to ensure data is populated in the **ingestion** container. You should see either a **providers** or **subscriptions** folder. Use the sections below to troubleshoot further.

### FinOps hubs: Ingestion container is empty

If the **ingestion** container is empty, open the Data Factory instance in Data Factory Studio and select **Manage** > **Author** > **Triggers** and verify the **msexports_FileAdded** trigger is started. If not, start it.

If the trigger fails to start with a "resource provider is not registered" error, open the subscription in the Azure portal, then select **Settings** > **Resource providers**, select the **Microsoft.EventGrid** row, then select the **Register** command at the top of the page. Registration may take a few minutes.

After registration completes, start the **msexports_FileAdded** trigger again.

After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes, depending on the size of the account.

If the issue persists, check if Cost Management exports are configured with file partitioning enabled. If you find it disabled, turn it on and re-run the exports.

Confirm the **ingestion** container is populated and refresh your reports or other connected tools.

### FinOps hubs: Files available in the ingestion container

If the **ingestion** container is not empty, confirm whether you have **parquet** or **csv.gz** files by drilling into the folders.

Once you know, verify the **FileType** parameter is set to `.parquet` or `.gz` in the Power BI report. See [Connect to your data](../_reporting/power-bi/README.md#-connect-to-your-data) for details.

If you're using another tool, ensure it supports the file type you're using.

### Power BI: Reports are not showing data

If the report does not include any data outside of the RangeStart/RangeEnd parameter, you will need to return to the transform data page of the Power BI report, and change RangeStart and RangeEnd to the desired start/end dates for your report. See [Set up your first report](../_reporting/power-bi/setup.md) for details.

---

## Power BI: Exception of type 'Microsoft.Mashup.Engine.Interface.ResourceAccessForbiddenException' was thrown

Indicates that the account loading data in Power BI does not have the [Storage Blob Data Reader role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader). Grant this role to the account loading data in Power BI.

---

## Power BI: The remote name could not be resolved: '\<storage-account>.dfs.core.windows.net'

Indicates that the storage account name is incorrect. If using FinOps hubs, verify the **StorageUrl** parameter from the deployment. See [Connect to your data](../_reporting/power-bi/README.md#-connect-to-your-data) for details.

---

## Power BI: We cannot convert the value null to type Logical

Indicates that the **Billing Account ID** parameter is empty. If using FinOps hubs, set the value to the desired billing account ID. If you do not have access to the billing account or do not want to include commitment purchases and refunds, set the value to `0` and open the **CostDetails** query in the advanced editor and change the `2` to a `1`. This will inform the report to not load actual/billed cost data from the Cost Management connector. See [Connect to your data](../_reporting/power-bi/README.md#-connect-to-your-data) for details.

Applicable versions: **0.1 - 0.1.1** (fixed in **0.2**)
=======
- Error: "Access to the resource is forbidden" - Check user permissions or SAS token settings.
- Error: "Invalid Billing Account ID" - Ensure the correct billing account ID is used in the Commitment Discounts report.
-->


This guide helps you troubleshoot issues with the FinOps Hubs, focusing on two main sections: Data Ingestion and Connecting to Your Data. Always start troubleshooting with the Data Ingestion section before moving on to Connecting to Your Data.

### Step 1: Verify Cost Management export

1. Go to Cost Management exports and make sure the export status is "Successful".
2. If it is not successful, ensure you have the Cost Management resource provider registered for the subscription where your hub is deployed.

### Step 2: Verify Data Factory pipelines

1. Go to Data Factory studio, then go to Monitor and make sure both pipelines are running.
2. Compare the last run time with the time of the last cost export. They should be close.
3. Open the Data Factory instance in Data Factory Studio and select Manage > Author > Triggers. Verify the `msexports_FileAdded` trigger is started. If not, start it.
4. If the trigger fails to start with a “resource provider is not registered” error, open the subscription in the Azure portal, then select Settings > Resource providers, select the Microsoft.EventGrid row, then select Register. Registration may take a few minutes.
5. After registration completes, start the `msexports_FileAdded` trigger again.
6. After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes.
7. If the ingestion pipeline is not running and it is showing a `MappingColumnNameNotFoundInSourceFile` error message, verify the export is configured for FOCUS `1.0-preview(v1)` and not `1.0`.

### Step 3: Verify storage account – msexports container

1. The **msexports** container is where the Cost Management pushes "raw" export to. This container should not have CSV files as hubs transforms them into parquet files.
2. If the you see CSV files in the msexports container, refer back to [Verify Data Factory pipelines](#step-2-verify-data-factory-pipelines).

### Step 4: Verify storage account – ingestion container

1. The **ingestion** container is where clients, like Power BI, connect to pull data. This container should always have one or more parquet files for each month.
2. If you don't see any parquet files in the ingestion container, check for CSV files in the mseports container.
3. If you find CSV files inside the msexports container, it means that Data Factory pipeline is not working. Refer back to [Verify Data Factory pipelines](#step-2-verify-data-factory-pipelines)..
4. If there are no CSV files in the msexports container and no parquet files inside the ingestion container, it means the Cost Management export is not running properly. Refer back to [Verify Cost Management export](#step-1-verify-cost-management-export).

<!--
### Step 5: Confirm data ingestion is working

1. If you have a parquet file in the ingestion container, it means the "Data Ingestion" component is working fine.
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
2. If you ssee an error about access being forbidden, review if the billing account that you are connecting to is correct. Power BI reports are provided with a sample billing account, and if you don't change that to your own ID, you won't be able to connect.

<br>