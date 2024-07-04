---
layout: default
title: Troubleshooting
has_children: true
description: 'Details and solutions for common issues you may experience.'
permalink: /resources/troubleshooting
---

---
<span class="fs-9 d-block mb-4">Troubleshooting common errors</span>
Sorry to hear you're having a problem. We're here to help!
{: .fs-6 .fw-300 }

## ⏩ Do you have a specific error code?
⚡ [Find common errors](./troubleshooting-errocode.md) ▶


## ▶️ Where is the problem surfaced?

1. [Cost Export](#cost-export)
2. [Azure Data Factory](#data-factory)
3. [Storage Account (MSExport and Ingestion Containers)](#storage-account)
4. [Power BI](#power-bi)
---
### Cost Export

- **Cost Export Issues**: 
  - Error: "Failed to export cost data" - Ensure the Cost Management register provider is registered.
  - Error: "Export status failed" - Verify subscription settings and permissions.

### Data Factory

- **Data Factory Issues**:
  - Error: "Pipeline failed to run" - Check triggers and resource provider registration.
  - Error: "Pipeline not running" - Ensure pipelines are active and compare last run times.

### Storage Account

- **Storage Account Issues**:
  - Error: "No parquet files in Ingestion container" - Verify Data Factory pipeline and Cost Export status.
  - Error: "CSV files in MSExport container" - Data Factory pipeline not transforming data.

### Power BI

- **Power BI Connection Issues**:
  - Error: "Access to the resource is forbidden" - Check user permissions or SAS token settings.
  - Error: "Invalid Billing Account ID" - Ensure the correct billing account ID is used in the Commitment Discounts report.

---

# 🍎 Learn more

## Overview

This guide helps you troubleshoot issues with the FinOps Hubs, focusing on two main sections: Data Ingestion and Connecting to Your Data. Always start troubleshooting with the Data Ingestion section before moving on to Connecting to Your Data.

### Section 1: Data Ingestion

#### Step 1: Verify Cost Export

- **Check Cost Export Status**
  - Go to Cost Export and make sure the export status is "Successful".
  - If it is not successful, ensure you have the Cost Management register provider registered for the subscription where Hubs is deployed to.

#### Step 2: Verify Data Factory Pipelines

- **Check Data Factory Pipelines**
  - Go to Data Factory studio, then go to Monitor and make sure both pipelines are running.
  - Compare the last run time with the time of the last cost export. They should be close.
  - Open the Data Factory instance in Data Factory Studio and select Manage > Author > Triggers. Verify the `msexports_FileAdded` trigger is started. If not, start it.
  - If the trigger fails to start with a “resource provider is not registered” error, open the subscription in the Azure portal, then select Settings > Resource providers, select the Microsoft.EventGrid row, then select Register. Registration may take a few minutes.
  - After registration completes, start the `msexports_FileAdded` trigger again.
  - After the trigger is started, re-run all connected Cost Management exports. Data should be fully ingested within 10-20 minutes.
  - If the ingestion pipeline is not running and it is showing this error message:
    ```
    Operation on target Convert CSV failed: ErrorCode=MappingColumnNameNotFoundInSourceFile,'Type=Microsoft.DataTransfer.Common.Shared.HybridDeliveryException,Message=Column 'AvailabilityZone' specified in column mapping cannot be found in 'part_0_0001.csv' source file.,Source=Microsoft.DataTransfer.ClientLibrary,'
    ```
    **Solution:** This error means that the Cost Export is not set to FOCUS 1.0 (Preview). Review the export settings and ensure it is configured to FOCUS 1.0 (Preview), then run the pipeline again.

#### Step 3: Verify Storage Account - MSExport Container

- **Check Storage Account - MSExport Container**
  - **MSExport Container**: This is where the Cost Export sends the "raw" export to. This container should be empty as Hubs transforms this raw (.csv) file into .parquet.
  - If the MSExport container is not empty, refer back to Section 1, Step 2: Verify Data Factory Pipelines.

#### Step 4: Verify Storage Account - Ingestion Container

- **Check Storage Account - Ingestion Container**
  - **Ingestion Container**: This is where Power BI connects to. This container should always have at least one (or multiple) .parquet files.
  - If you don't see any .parquet files in the Ingestion container, check for .csv files inside the MSExport container.
  - If you find .csv files inside the MSExport container, it means that Data Factory pipeline is not working and not transforming the data to parquet. Refer back to Section 1, Step 2: Verify Data Factory Pipelines.
  - If there are no .csv files inside the MSExport container and no .parquet files inside the Ingestion container, it means that Cost Export is not running properly. Refer back to Section 1, Step 1: Verify Cost Export.

#### Step 5: Confirm Data Ingestion is Working

- **Confirm Data Ingestion Working**
  - If you have a .parquet file in the Ingestion container, it means the "Data Ingestion" component is working fine.

### Section 2: Connecting to Your Data

#### Step 1: Connect Power BI to Storage Account

- **Connect Power BI to Storage Account**
  - Decide how you will connect to this container: Using a username or using a SAS key.

#### Step 2: Using Username

- **Using Username**
  - Ensure you have the Blob Storage Reader permissions assigned explicitly to your user. This permission is not inherited even if you have "Owner" or "Contributor" permissions.

#### Step 3: Using SAS Token

- **Using SAS Token**
  - Ensure you have set the following permissions for the token:
    - Allowed Services: Blob
    - Allowed Resource Types: Container and Object
    - Allowed Permissions: Read and List
  - Ensure you have also set a valid start and expiry date/time.

#### Step 4: Troubleshoot Connection Errors

- **Troubleshoot Connection Errors**
  - If you try to connect to your Storage account and receive an error: "Access to the resource is forbidden", it is very likely you are missing a few permissions. Refer back to Section 2, Step 2: Using Username or Section 2, Step 3: Using SAS Token to ensure you have the correct permissions.
  - **Only applicable if you are using the Commitment Discounts report**: If you have the correct permissions but are still seeing the error about access being forbidden, review if the Billing Account that you are connecting to is correct. The Commitment Discounts PBI template is provided with a sample billing ID, and if you don't change that to your own ID, you won't be able to connect.


---