---
title: Configure scopes
description: Connect FinOps hubs to billing accounts and subscriptions by configuring Cost Management exports manually or give FinOps hubs access to manage exports for you.
author: bandersmsft
ms.author: banders
ms.date: 10/30/2024
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
# customer intent: As a FinOps toolkit user, I want to learn about how to connect FinOps hubs to billing accounts and subscriptions so that I can do it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure scopes

Connect FinOps hubs to your billing accounts and subscriptions by configuring Cost Management exports manually or granting FinOps hubs access to manage exports for you.

FinOps hubs use Cost Management exports to import cost data for the billing accounts and subscriptions you want to monitor. You can either configure Cost Management exports manually or grant FinOps hubs access to manage exports for you.

> [!IMPORTANT]
> Microsoft Cost Management does not support managed exports for Microsoft Customer Agreement billing accounts. For more information, see [configure Cost Management exports manually](#configure-exports-manually).

For the most seamless experience, we recommend allowing FinOps hubs to manage exports for you when possible. This option requires the least effort to maintain over time.

<br>

## Configure exports manually

If you can't grant permissions for your scope, you can create Cost Management exports manually to accomplish the same goal.

1. [Create a new FOCUS cost export](/azure/cost-management-billing/costs/tutorial-export-acm-data) using the following settings:

   - **Type of data** = `Cost and usage details (FOCUS)`¹
   - **Dataset version** = `1.0`²
   - **Frequency** = `Daily export of month-to-date costs`³
   - **Storage account** = (Use subscription/resource deployed with your hub)
   - **Container** = `msexports`
   - **Format** = `CSV`
   - **Compression Type** = `none`
   - **Directory** = (Specify a unique path for this scope⁵)
     - _**EA billing account:** `billingAccounts/{enrollment-number}`_
     - _**MCA billing profile:** `billingProfiles/{billing-profile-id}`_
     - _**Subscription:** `subscriptions/{subscription-id}`_
     - _**Resource group:** `subscriptions/{subscription-id}/resourceGroups/{rg-name}`_
   - **Format** = Parquet
   - **Compression** = Snappy
   - **File partitioning** = On
   - **Overwrite data** = Off⁴
2. Create another export with the same settings except set **Frequency** to `Monthly export of last month's costs`.
3. Create exports for any other data you would like to include in your reports.
   - Supported datasets and versions:
     - Price sheet `2023-05-01`
     - Reservation details `2023-03-01`
     - Reservation recommendations `2023-05-01`
        > [!NOTE]
        > Virtual machine reservation recommendations exports are required on the Reservation recommendations page of the Rate optimization report. If you do not create an export, the page will be empty.
     - Reservation transactions `2023-05-01`
   - Supported formats: Parquet (preferred) or CSV
   - Supported compression: Snappy (preferred), GZip, or uncompressed
4. To initialize the dataset, run your exports.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how large your account is.
   - If you want to backfill data, open the export details and select the **Export selected dates** command to export one month at a time or use the [Start-FinOpsCostExport PowerShell command](../powershell/cost/Start-FinOpsCostExport.md) to export a larger date range.
5. Repeat steps 1-4 for each scope you want to monitor.

_¹ FinOps hubs 0.2 and later requires FOCUS cost data. As of July 2024, the option to export FOCUS cost data is only accessible from the central Cost Management experience in the Azure portal. If you don't see this option, search for or navigate to [Cost Management Exports](https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/open/exports)._

_² FinOps hubs 0.4 supports both FOCUS 1.0 and FOCUS 1.0 preview. Power BI reports in 0.4 are aligned to FOCUS 1.0 regardless of whether data was ingested as FOCUS 1.0 preview. If you need 1.0 preview data and reports, use FinOps hubs 0.3._

_³ Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range._

_⁴ While most settings are required, overwriting is optional. We recommend **not** overwriting files so you can monitor your ingestion pipeline using the [Data ingestion](../power-bi/data-ingestion.md) report. If you don't plan to use that report, enable overwriting._

_⁵ Export paths can be any value but must be unique per scope. We recommended using a path that identifies the source scope, for example, subscription or billing account. If two scopes share the same path, there could be ingestion errors._

<br>

## Configure managed exports

Managed exports allow FinOps hubs to set up and maintain Cost Management exports for you. To enable managed exports, you must grant Azure Data Factory access to read data across each scope you want to monitor.


:::image type="content" source="./media/configure-scopes/hubs-scopes.png" border="false" alt-text="Diagram showing the supported scopes for hubs." lightbox="./media/configure-scopes/hubs-scopes.png" :::

> [!NOTE]
> Managed exports are only available in FinOps hubs 0.4 and later.

Managed exports use a managed identity (MI) to configure the exports automatically. To set it up, use the following steps:

1. **Grant access to Azure Data Factory.**

   - From the FinOps hub resource group, navigate to **Deployments** > **hub** > **Outputs**, and make note of the values for **managedIdentityId** and **managedIdentityTenantId**. You'll use them in the next step.
   - Use the following guides to assign access to each scope you want to monitor:
     - EA enrollments – [Assign enrollment reader role permission](/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn).
     - EA departments – [Assign department reader role permission](/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn).
     - Subscriptions and resource groups – [Assign Azure roles using the Azure portal](/azure/role-based-access-control/role-assignments-portal).

   <!--
   ### Enterprise agreement billing accounts and departments
   
   1. [Find your enrollment (and department) Id](https://learn.microsoft.com/azure/cost-management-billing/manage/view-all-accounts#switch-billing-scope-in-the-azure-portal).
   2. Load the FinOps Toolkit PowerShell module.
   3. Grant reader permissions to the data factory
   
      ```powershell
      # Grants enrollment reader permissions to the specified service principal or managed identity
      Add-FinOpsServicePrincipal `
         -ObjectId aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb ` # Object Id of data factory managed identity
         -TenantId aaaabbbb-0000-cccc-1111-dddd2222eeee ` # Azure Active Directory tenant Id
         -BillingAccountId 12345                          # Enrollment ID
   
      # Grants department reader permissions to the specified service principal or managed identity
      Add-FinOpsServicePrincipal `
         -ObjectId aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb ` # Object Id of data factory managed identity
         -TenantId aaaabbbb-0000-cccc-1111-dddd2222eeee ` # Azure Active Directory tenant Id
         -BillingAccountId 12345 `                        # Enrollment Id
         -DepartmentId 67890                              # Department Id
   ```
   -->

2. **Add the desired scopes.**

   1. From the FinOps hub resource group, open the storage account and navigate to **Storage browser** > **Blob containers** > **config**.
   2. Select the **settings.json** file, then select **⋯** > **View/edit** to open the file.
   3. Update the **scopes** property to include the scopes you want to monitor. For more information, see [Settings.json scope examples](#settingsjson-scope-examples).
   4. Select the **Save** command to save your changes. FinOps hubs should process the change within a few minutes and data should be available within 30 minutes or so, depending on the size of your account.

   > [!IMPORTANT]
   > Do not add duplicate or overlapping scopes as this will lead to duplication of data.

3. **Backfill historical data.**

   As soon as you configure a new scope, FinOps hubs will start to monitor current and future costs. To backfill historical data, you must run the **config_RunBackfillJob** pipeline for each month.

   To run the pipeline from the Azure portal:

   1. From the FinOps hub resource group, open the Data Factory instance, select **Launch Studio**, and navigate to **Author** > **Pipelines** > **config_RunBackfillJob**.
   2. Select **Debug** in the command bar to run the pipeline. The total run time varies depending on the retention period and number of scopes you're monitoring.

   To run the pipeline from PowerShell:

   ```powershell
   Get-AzDataFactoryV2 `
     -ResourceGroupName "{hub-resource-group}" `
     -ErrorAction SilentlyContinue `
   | ForEach-Object {
       Invoke-AzDataFactoryV2Pipeline `
         -ResourceGroupName $_.ResourceGroupName `
         -DataFactoryName $_.DataFactoryName `
         -PipelineName 'config_RunBackfillJob'
   }
   ```

### Settings.json scope examples

- EA billing account

  ```json
  "scopes": [
    {
      "scope": "/providers/Microsoft.Billing/billingAccounts/1234567"
    }
  ]
  ```

- EA department

  ```json
  "scopes": [
    {
      "scope": "/providers/Microsoft.Billing/billingAccounts/1234567/departments/56789"
    }
  ]
  ```

- Subscription

  ```json
  "scopes": [
    {
      "scope": "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"
    }
  ]
  ```

- Multiple subscriptions

  ```json
  "scopes": [
    {
      "scope": "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e"
    },
    {
      "scope": "subscriptions/bbbb1b1b-cc2c-dd3d-ee4e-ffffff5f5f5f"
    }
  ]
  ```

- Resource group

  ```json
  "scopes": [
    {
      "scope": "/subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/ftk-finops-hub"
    }
  ]
  ```

<br>

## Configure exports via PowerShell

If it's the first time you're using the FinOps toolkit PowerShell module, refer to the [PowerShell](../powershell/powershell-commands.md) deployment guide to install the module.

1. Install the FinOps toolkit PowerShell module.

   ```powershell
   Import-Module -Name FinOpsToolkit
   ```

2. Create the export and run it now to backfill up to 12 months of data.

   ```powershell
   New-FinOpsCostExport -Name 'ftk-FinOpsHub-costs' `
     -Scope "{scope-id}" `
     -StorageAccountId "{storage-resource-id}" `
     -Backfill 12 `
     -Execute
   ```

<br>

## Related content

- [Connect to Power BI](../power-bi/setup.md)
- [Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>