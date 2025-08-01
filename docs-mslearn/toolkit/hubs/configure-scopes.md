---
title: Configure scopes for FinOps hubs
description: Connect FinOps hubs to billing accounts and subscriptions by configuring Cost Management exports manually or give FinOps hubs access to manage exports for you.
author: flanakin
ms.author: micflan
ms.date: 04/29/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
# customer intent: As a FinOps toolkit user, I want to learn about how to connect FinOps hubs to billing accounts and subscriptions so that I can do it.
---

<!-- markdownlint-disable-next-line MD025 -->
# Configure scopes

Connect FinOps hubs to your billing accounts and subscriptions by configuring Cost Management exports manually or granting FinOps hubs access to manage exports for you.

FinOps hubs use Cost Management exports to import cost data for the billing accounts and subscriptions you want to monitor. You can either configure Cost Management exports manually or grant FinOps hubs access to manage exports for you. For information about identifying your billing account and scope IDs, see [Find your billing account and scope IDs](#find-your-billing-account-and-scope-ids).

<br>

## Prerequisites

Before you begin, you must have:

- [Deployed a FinOps hub instance](finops-hubs-overview.md#create-a-new-hub).

This walkthrough will trigger the following indirect costs:

- Cost Management exports do not have a direct cost, but push data to storage, which does incur cost for the number of GB stored.
- When exports complete, Data Factory pipelines start to process the data, which incurs cost for the time the pipelines are running.

<br>

## Find your billing account and scope IDs

Before configuring exports, you need to identify the billing account and scope IDs you want to monitor. The specific ID format depends on your billing account type.

### Enterprise Agreement (EA) accounts

For EA accounts, you need your enrollment number (billing account ID):

1. Sign in to the [Azure portal](https://portal.azure.com).
2. Search for and select **Cost Management + Billing**.
3. Select **Billing scopes** from the left menu.
4. Select your billing account.
5. On the **Overview** page, copy the **Billing account ID** (enrollment number).
   - Use this format for billing account scope: `/providers/Microsoft.Billing/billingAccounts/{enrollment-number}`
   - For departments, append the department ID: `/providers/Microsoft.Billing/billingAccounts/{enrollment-number}/departments/{department-id}`

### Microsoft Customer Agreement (MCA) accounts

For MCA accounts, you need your billing profile ID:

1. Sign in to the [Azure portal](https://portal.azure.com).
2. Search for and select **Cost Management + Billing**.
3. Select **Billing scopes** from the left menu.
4. Select your billing account, then select the billing profile you want to monitor.
5. On the billing profile **Overview** page, copy the **Billing profile ID**.
   - Use this format: `/providers/Microsoft.Billing/billingAccounts/{billing-account-id}/billingProfiles/{billing-profile-id}`

### Subscriptions and resource groups

For subscriptions and resource groups:

1. Sign in to the [Azure portal](https://portal.azure.com).
2. Search for and select **Subscriptions**.
3. Select the subscription you want to monitor.
4. On the **Overview** page, copy the **Subscription ID**.
   - For subscription scope: `/subscriptions/{subscription-id}`
   - For resource group scope: `/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}`

For more information about finding your billing account and scope information, see [View all your billing accounts in Azure portal](/azure/cost-management-billing/manage/view-all-accounts).

<br>

## About Cost Management exports

Cost Management provides the following 5 types of exports:

- Cost and usage details (FOCUS)
  - Exports all costs using the FOCUS version of the cost and usage details file  as they're defined in the FinOps Open Cost and Usage Specification (FOCUS) project.
  - Maps to the Costs folder in the ingestion container.
- Price sheet
  - Exports prices for your Azure services.
  - Maps to the Prices folder in the ingestion container.
- Reservation details
  - Exports reservation details for Azure services, including used and unused reservation hours.
  - Maps to the CommitmentDiscountUsage folder in the ingestion container.
- Reservation recommendations
  - Exports all of the reservation recommendation details for savings. The savings are calculated in addition to your negotiated, or discounted, if applicable, prices.
  - Maps to the Recommendations folder in the ingestion container.
- Reservation transactions
  - Exports reservation transaction for the Azure reservations bought.
  - Maps to the Transactions folder in the ingestion container.

FinOps hubs support the following dataset types, versions, and API versions:

- FocusCost: 1.0r2, 1.0, 1.0-preview(v1)
- PriceSheet: 2023-05-01
- ReservationDetails: 2023-03-01
- ReservationRecommendations: 2023-05-01
- ReservationTransactions: 2023-05-01
- API versions: 2023-07-01-preview

For the most seamless experience, we recommend [allowing FinOps hubs to manage exports](#configure-managed-exports) for you. This option requires the least effort to maintain over time. Please note that Cost Management does not support managed exports for Microsoft Customer Agreement billing accounts or billing profiles.

<br>

## Configure exports manually

If you can't grant permissions for your scope, you can create Cost Management exports manually to accomplish the same goal.

1. Determine the scope for your data export.
   - For information about finding your billing account and scope IDs, see [Find your billing account and scope IDs](#find-your-billing-account-and-scope-ids).
   - We recommend exporting from either an **EA billing account** or **MCA billing profile** scope to access additional datasets, including price sheets and reservation recommendations.
   - Price sheet exports are required to populate missing prices and costs.
   - Reservation recommendation exports are used on the Rate optimization Reservation recommendations page.
   
   > [!IMPORTANT]
   > **Microsoft Customer Agreement (MCA) scope requirements**
   > 
   > For MCA contracts, certain datasets are **only available at the billing profile level**, not at the billing account level:
   > - Price sheet data
   > - Reservation recommendations 
   > - Reservation details
   > 
   > You must use the billing profile scope (`/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###`) for these exports. This is a Cost Management limitation.
   
   - We recommend creating daily exports for each export type supported at your chosen billing scope:
      - Enterprise Agreement billing account: FocusCosts, Pricesheet, ReservationTransactions, ReservationDetails, ReservationRecommendations
      - Microsoft Customer Agreement billing profile: FocusCosts, Pricesheet, ReservationTransactions, ReservationDetails, ReservationRecommendations
      - Subscription: FocusCosts
2. [Create a new FOCUS cost export](/azure/cost-management-billing/costs/tutorial-export-acm-data) using the following settings:
   - **Type of data** = `Cost and usage details (FOCUS)`¹
   - **Dataset version** = `1.0` or `1.0r2`²
   - **Frequency** = `Daily export of month-to-date costs`³
   - **Storage account** = (Use subscription/resource deployed with your hub)
   - **Container** = `msexports`
   - **Format** = `Parquet` (when available)
   - **Compression Type** = `Snappy` (when available)
   - **Directory** = (Specify a unique path for this scope⁵)
     - _**EA billing account:** `billingAccounts/{enrollment-number}`_
     - _**MCA billing profile:** `billingProfiles/{billing-profile-id}`_
     - _**Subscription:** `subscriptions/{subscription-id}`_
     - _**Resource group:** `subscriptions/{subscription-id}/resourceGroups/{rg-name}`_
   - **File partitioning** = On
   - **Overwrite data** = Off⁴
3. Create another export with the same settings except set **Frequency** to `Monthly export of last month's costs`.
4. Create exports for any other data you would like to include in your reports.
   - Supported datasets and versions:
     - Price sheet `2023-05-01`
       - Required to populate missing prices/costs and calculate savings when using Azure Data Explorer.
     - Reservation details `2023-03-01`
     - Reservation recommendations `2023-05-01`
       - Virtual machine reservation recommendations are required on the Reservation recommendations page of the Rate optimization report. If you do not create an export, the page will be empty.
     - Reservation transactions `2023-05-01`
   - Supported formats: Parquet (preferred) or CSV
   - Supported compression: Snappy (preferred), GZip, or uncompressed
5. To initialize the dataset, run your exports.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how large your account is.
   - If you want to backfill data, open the export details and select the **Export selected dates** command to export one month at a time or use the [Start-FinOpsCostExport PowerShell command](../powershell/cost/Start-FinOpsCostExport.md) to export a larger date range with either the `-Backfill` parameter or specific start and end dates.
6. Repeat steps 1-4 for each scope you want to monitor.

_¹ FinOps hubs 0.2 and later requires FOCUS cost data. As of July 2024, the option to export FOCUS cost data is only accessible from the central Cost Management experience in the Azure portal. If you don't see this option, search for or navigate to [Cost Management Exports](https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/open/exports)._

_² The only difference in FOCUS 1.0r2 compared to 1.0 is the inclusion of seconds in date columns. If seconds are not required for the system you are ingested data into, there is no need to change existing 1.0 exports to leverage 1.0r2._

_³ Configuring a daily export starts in the current month._

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
   
   1. [Find your enrollment (and department) Id](/azure/cost-management-billing/manage/view-all-accounts#switch-billing-scope-in-the-azure-portal).
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

   As soon as you configure a new scope, FinOps hubs will start to monitor current and future costs. To backfill historical data, you have several options:

   #### Option 1: Using config_RunBackfillJob pipeline

   Use the **config_RunBackfillJob** pipeline to process historical data after it's been exported. For more information about running Azure Data Factory pipelines, see [Azure Data Factory pipelines](/azure/data-factory/concepts-pipelines-activities).

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

   #### Option 2: Using Cost Management exports

   You can backfill multiple months of data directly using the Cost Management UI. Learn more about exports in the [Cost Management exports documentation](/azure/cost-management-billing/costs/tutorial-export-acm-data).

   1. Open the Azure portal and navigate to **Cost Management** > **Exports**.
   2. Select the managed export created by your FinOps hub.
   3. Select **Export selected dates** from the top menu.
   4. Select the date range you want to backfill (you can specify multiple months at once).
   5. Select **Run** to start the export.

   #### Option 3: Using Start-FinOpsCostExport PowerShell command

   The most efficient approach for backfilling large date ranges is to use the [Start-FinOpsCostExport PowerShell command](../powershell/cost/Start-FinOpsCostExport.md). For information about working with Cost Management via PowerShell, see [Cost Management cmdlets](/powershell/module/az.costmanagement/).

   ```powershell
   # Backfill the previous 12 months for a specific export
   Start-FinOpsCostExport -Name 'ftk-monthly-costdetails' `
     -Scope '/providers/Microsoft.Billing/billingAccounts/1234567/departments/56789' `
     -Backfill 12

   # Or specify a specific date range
   Start-FinOpsCostExport -Name 'ftk-monthly-costdetails' `
     -Scope '/providers/Microsoft.Billing/billingAccounts/1234567/departments/56789' `
     -StartDate '2023-01-01' -EndDate '2023-12-31'
   ```

   This command handles exporting data for multiple months at once and handles any API throttling issues that might occur.

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

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK/bladeName/Hubs/featureName/ConfigureScopes)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)

## Related content

- [Connect to Power BI](../power-bi/setup.md)
- [Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>
