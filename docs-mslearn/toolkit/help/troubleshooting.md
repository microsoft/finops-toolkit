---
title: Troubleshooting
description: This article describes how to validate that FinOps toolkit solutions are deployed and configured correctly, including troubleshooting common errors.
author: bandersmsft
ms.author: banders
ms.date: 10/30/2024
ms.topic: troubleshooting
ms.service: finops
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

### Step 1: Verify Cost Management export

1. Go to Cost Management exports and make sure the export status is `Successful`.
2. If it isn't successful, ensure you have the Cost Management resource provider registered for the subscription where your hub is deployed.

### Step 2: Verify Data Factory pipelines

1. Go to Data Factory studio, then go to Monitor and make sure both pipelines are running.
2. Compare the last run time with the time of the last cost export. They should be close.
3. Open the Data Factory instance in Data Factory Studio and select Manage > Author > Triggers. Verify the `msexports_FileAdded` trigger is started. If not, start it.
4. If the trigger fails to start with a “resource provider isn't registered” error, open the subscription in the Azure portal, then select Settings > Resource providers, select the Microsoft.EventGrid row, then select Register. Registration might take a few minutes.
5. After registration completes, start the `msexports_FileAdded` trigger again.
6. After the trigger is started, rerun all connected Cost Management exports. Data should be fully ingested within 10-20 minutes.
7. If the ingestion pipeline isn't running and it's showing a `MappingColumnNameNotFoundInSourceFile` error message, verify the export is configured for FOCUS `1.0-preview(v1)` and not `1.0`.

### Step 3: Verify storage account – msexports container

1. The **msexports** container is where the Cost Management pushes "raw" export to. This container shouldn't have CSV files as hubs transforms them into parquet files.
2. If you see CSV files in the msexports container, refer back to [Verify Data Factory pipelines](#step-2-verify-data-factory-pipelines).

### Step 4: Verify storage account – ingestion container

1. The **ingestion** container is where clients, like Power BI, connect to pull data. This container should always have one or more parquet files for each month.
2. If you don't see any parquet files in the ingestion container, check for CSV files in the `mseports` container.
3. If you find CSV files inside the msexports container, it means that Data Factory pipeline isn't working. Refer back to [Verify Data Factory pipelines](#step-2-verify-data-factory-pipelines).
4. If there are no CSV files in the msexports container and no parquet files inside the ingestion container, it means the Cost Management export isn't running properly. Refer back to [Verify Cost Management export](#step-1-verify-cost-management-export).

<!--
### Step 5: Confirm data ingestion is working

1. If you have a parquet file in the ingestion container, it means the "Data Ingestion" component is working fine.
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
   - **RangeStart** and **RangeEnd define an explicit date range of data to show in the reports. Anything before or after these dates isn't shown.
   - If **RangeStart** is empty, all historical data before **RangeEnd** is included.
   - If **RangeEnd** is empty, all new data after **RangeStart** is included.
   - If all date parameters are empty, all available data is included.

<br>

<!--
## Create a support request

If you're facing an error not listed above or need more help, file a [support request](/azure/azure-portal/supportability/how-to-create-azure-support-request) and specify the issue type as Billing.

<br>
-->
## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)