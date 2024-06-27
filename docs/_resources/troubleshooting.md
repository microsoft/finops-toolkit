---
layout: default
title: Troubleshooting
nav_order: 999
description: 'Details and solutions for common issues you may experience.'
permalink: /resources/troubleshoot
---

<span class="fs-9 d-block mb-4">Troubleshooting common errors</span>
Sorry to hear you're having a problem. We're here to help!
{: .fs-6 .fw-300 }

---
# FinOps Hubs Troubleshooting Guide

## Overview
This guide helps you troubleshoot issues with the FinOps Hubs, focusing on two main sections: Data Ingestion and Connecting to Your Data. Always start troubleshooting with the Data Ingestion section before moving on to Connecting to Your Data.

## Key Services

1. Cost Export
2. Azure Data Factory
3. Storage Account (MSExport and Ingestion Containers)

---

### Section 1: Data Ingestion

#### Step 1: Verify Cost Export
1. **Check Cost Export Status**
    - Go to Cost Export and make sure the export status is "Successful".
    - If it is not successful, ensure you have the Cost Management register provider registered for the subscription where Hubs is deployed to.

#### Step 2: Verify Data Factory Pipelines
2. **Check Data Factory Pipelines**
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
3. **Check Storage Account - MSExport Container**
    - **MSExport Container**: This is where the Cost Export sends the "raw" export to. This container should be empty as Hubs transforms this raw (.csv) file into .parquet.
    - If the MSExport container is not empty, refer back to Section 1, Step 2: Verify Data Factory Pipelines.

#### Step 4: Verify Storage Account - Ingestion Container
4. **Check Storage Account - Ingestion Container**
    - **Ingestion Container**: This is where Power BI connects to. This container should always have at least one (or multiple) .parquet files.
    - If you don't see any .parquet files in the Ingestion container, check for .csv files inside the MSExport container.
    - If you find .csv files inside the MSExport container, it means that Data Factory pipeline is not working and not transforming the data to parquet. Refer back to Section 1, Step 2: Verify Data Factory Pipelines.
    - If there are no .csv files inside the MSExport container and no .parquet files inside the Ingestion container, it means that Cost Export is not running properly. Refer back to Section 1, Step 1: Verify Cost Export.

#### Step 5: Confirm Data Ingestion is Working
5. **Confirm Data Ingestion Working**
    - If you have a .parquet file in the Ingestion container, it means the "Data Ingestion" component is working fine.

---

### Section 2: Connecting to Your Data

#### Step 1: Connect Power BI to Storage Account
1. **Connect Power BI to Storage Account**
    - Decide how you will connect to this container: Using a username or using a SAS key.

#### Step 2: Using Username
2. **Using Username**
    - Ensure you have the Blob Storage Reader permissions assigned explicitly to your user. This permission is not inherited even if you have "Owner" or "Contributor" permissions.

#### Step 3: Using SAS Token
3. **Using SAS Token**
    - Ensure you have set the following permissions for the token:
        - Allowed Services: Blob
        - Allowed Resource Types: Container and Object
        - Allowed Permissions: Read and List
    - Ensure you have also set a valid start and expiry date/time.

#### Step 4: Troubleshoot Connection Errors
4. **Troubleshoot Connection Errors**
    - If you try to connect to your Storage account and receive an error: "Access to the resource is forbidden", it is very likely you are missing a few permissions. Refer back to Section 2, Step 2: Using Username or Section 2, Step 3: Using SAS Token to ensure you have the correct permissions.
    - **Only applicable if you are using the Commitment Discounts report**: If you have the correct permissions but are still seeing the error about access being forbidden, review if the Billing Account that you are connecting to is correct. The Commitment Discounts PBI template is provided with a sample billing ID, and if you don't change that to your own ID, you won't be able to connect.

---

### Common Errors
- **Cost Export Issues**: 
  - Error: "Failed to export cost data" - Ensure the Cost Management register provider is registered.
  - Error: "Export status failed" - Verify subscription settings and permissions.

- **Data Factory Issues**:
  - Error: "Pipeline failed to run" - Check triggers and resource provider registration.
  - Error: "Pipeline not running" - Ensure pipelines are active and compare last run times.

- **Storage Account Issues**:
  - Error: "No parquet files in Ingestion container" - Verify Data Factory pipeline and Cost Export status.
  - Error: "CSV files in MSExport container" - Data Factory pipeline not transforming data.

- **Power BI Connection Issues**:
  - Error: "Access to the resource is forbidden" - Check user permissions or SAS token settings.
  - Error: "Invalid Billing Account ID" - Ensure the correct billing account ID is used in the Commitment Discounts report.

---


If you encounter any other errors, please refer to the [common error messages](https://flanakin.github.io/finops-toolkit/resources/troubleshoot) for additional troubleshooting steps.

## Error Messages

If you have validated all the previous steps and are still encountering issues, refer to the following error messages for further guidance:

- **Access to the resource is forbidden**: Ensure you have the appropriate permissions or correct SAS token settings.
- **Blob Storage Reader permissions not assigned**: Explicitly add Blob Storage Reader permissions to your user.
- **Cost Export not successful**: Register the Cost Management provider for the subscription.
- **Data Factory trigger not started**: Register the Microsoft.EventGrid provider and start the trigger.
- **No parquet files in Ingestion container**: Check the MSExport container for .csv files and ensure the Data Factory pipeline is transforming data correctly.
- **Connection to Billing Account**: Verify the Billing Account ID if using the Commitment Discounts report.

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

---

## FinOps hubs: RoleAssignmentUpdateNotPermitted

Full error message:

> _Tenant ID, application ID, principal ID, and scope are not allowed to be updated._

This error happens when you try to update an Azure role assignment with a new identity. This can happen in FinOps hubs if you delete a managed identity and re-deploy because the managed identity will be created with the same name but a new principal ID. ARM cannot use the principal ID to generate a unique role assignment ID, so the deployment tries to reuse the old role assignment ID, which can't be updated and results in the error. To prevent this in the future, do not delete the managed identities that are created as part of the deployment. But since you're here, there are two options:

1. Delete the resource group and re-deploy.
   - If you go this route, also make sure the Key Vault instance was also fully deleted by going to [Key vaults](https://portal.azure.com/#browse/Microsoft.KeyVault%2Fvaults) > **Manage deleted vaults** and purge the deleted vault, if it was soft-deleted.
2. Manually delete the role assignment in the Azure portal.
   - Go to check role assignments for the resource group, ADF instance, and storage account and remove any unidentified accounts that have a direct assignment on those scopes.

---

## FinOps hubs: We cannot convert the value null to type Table

This error typically indicates that data was not ingested into the **ingestion** container.

If you just upgraded to FinOps hubs 0.2, this may be due to the Power BI report being old (from 0.1.x) or because you are not using FOCUS exports. See the [Upgrade guide](../_reporting/hubs/upgrade.md) for details.

See [Reports are empty (no data)](#power-bi-reports-are-empty-no-data) for additional troubleshooting steps.

---

## FinOps hubs: Deployment failed with RoleAssignmentUpdateNotPermitted error

If you've deleted FinOps Hubs and are attempting to redeploy it with the same values, including the Managed Identity name, you might encounter the following known issue:

```json
"code": "RoleAssignmentUpdateNotPermitted",
"message": "Tenant ID, application ID, principal ID, and scope are not allowed to be updated."
```

To fix that issue you will have to remove the stale identity:

- Navigate to the storage account and select **Access control (IAM)** in the menu.
- Select the **Role assignments** tab.
- Find any role assignments with an "unknown" identity and delete them.

---

By following this guide and checking these common errors, you can systematically troubleshoot and resolve issues within the FinOps Hubs' data ingestion and connection processes.

