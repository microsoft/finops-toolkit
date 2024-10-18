---
title: Troubleshooting
description: This article describes how to validate FinOps toolkit solutions are configured correctly.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to validate FinOps toolkit solutions are deployed and configured correctly.
---

<!-- markdownlint-disable-next-line MD025 -->
# Troubleshooting guide

This article describes how to validate FinOps toolkit solutions have been deployed and configured correctly. If you have a specific error code, review [common errors](errors.md) for details and mitigation steps. If you need a more thorough walkthrough to validate your configuration, follow the applicable steps below.

<!--
If the information provided doesn't help you, [Create a support request](/azure/cost-management-billing/costs/cost-management-error-codes#create-a-support-request).
-->

<br>

## Do you have a specific error code?

If you have a specific error code, we recommend starting with [common errors](errors.md) for a direct explanation of the issue you are facing as well as how to mitigate or work around the issue.

<br>

## Validate your FinOps hub deployment

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

## Validate your Power BI configuration

### Step 1: Identify your storage URL

Before you begin validating your Power BI configuration, you need to know whether you are connecting to your data using one of the following mechanisms:

- Cost Management connector for Power BI – Ideal for small accounts with limited needs. Not recommended if reporting on more than $2M in total costs.
- Cost Management exports in storage – Requires exporting data from Cost Management into a storage account. Does not require additional deployments.
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
7. If using raw exports for any data, also follow the steps below.
8. If not using raw exports for any data, paste the hub storage URL into the **Export storage URL** in Power BI.
   > [!NOTE]
   > Power BI requires both parameters to be set in order for the Power BI service to refresh datasets.

If using raw exports without FinOps hubs for any datasets (even if you are using hubs for cost data), you can obtain the Data Lake Storage URI from your storage account in the Azure portal:

1. Navigate to the storage account in the Azure portal.
2. Select **Settings** > **Endpoints** in the menu.
3. Copy the **Data Lake Storage** > **Data Lake Storage** URL.
4. Paste this URL into the **Export storage URL** in Power BI.
5. If using FinOps hubs for any data, also follow the steps above.
6. If not using FinOps hubs for any data, paste the export storage URL into the **Hub storage URL** in Power BI.
   > [!NOTE]
   > Power BI requires both parameters to be set in order for the Power BI service to refresh datasets.

### Step 2: Connect Power BI to storage

Decide whether you will connect to storage using a user or service principal account or using a storage account key (also called SAS token).

- **Using a user or service principal account**
  1. Ensure you have the Storage Blob Data Reader role explicitly to the account you will use. This permission is not inherited even if you have "Owner" or "Contributor" permissions.
- **Using a SAS token**
  1. Ensure you've set the following permissions for the token:
     - Allowed services: Blob
     - Allowed resource types: Container and Object
     - Allowed permissions: Read and List
  2. Ensure you have also set a valid start and expiry date/time.

### Step 3: Troubleshoot connection errors

1. If you try to connect to your storage account and receive an error: "Access to the resource is forbidden", it is very likely you are missing a few permissions. Refer back to [Connect Power BI to storage](#step-2-connect-power-bi-to-storage) to ensure you have the correct permissions.
2. If you see an error about access being forbidden, review if the billing account that you are connecting to is correct. Power BI reports are provided with a sample billing account, and if you don't change that to your own ID, you won't be able to connect.

### Step 4: Troubleshoot missing months of data

1. If the Power BI report does not include entire months of data, confirm the date parameters in the Power BI report by checking **Transform data** > **Edit parameters** in the ribbon. See [Set up your first report](../power-bi/setup.md) for details.
   - **Number of Months** defines how many closed months (before the current month) will be shown in reports. Even if data is exported, data outside this range will not be shown. If defined, this parameter overrides others.
   - **RangeStart** and **RangeEnd define an explicit date range of data to show in the reports. Anything before or after these dates will not be shown.
   - If **RangeStart** is empty, all historical data before **RangeEnd** will be included.
   - If **RangeEnd** is empty, all new data after **RangeStart** will be included.
   - If all date parameters are empty, all available data will be included.

<br>

<!--
## Create a support request

If you're facing an error not listed above or need more help, file a [support request](/azure/azure-portal/supportability/how-to-create-azure-support-request) and specify the issue type as Billing.

<br>
-->
