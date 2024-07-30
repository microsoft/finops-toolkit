---
layout: default
parent: FinOps hubs
title: Configure scopes
nav_order: 1
description: 'Reliable, trustworthy platform for cost analytics, insights, and optimization.'
permalink: /hubs/configure
---

<span class="fs-9 d-block mb-4">Configure scopes</span>
Connect FinOps hubs to your billing accounts and subscriptions by configuring Cost Management exports manually or granting FinOps hubs access to manage exports for you.
{: .fs-6 .fw-300 }

[Grant access](#-configure-managed-exports){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Configure exports](#️-configure-exports-manually){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🔐 Configure managed exports](#-configure-managed-exports)
- [🖥️ Configure exports via PowerShell](#️-configure-exports-via-powershell)
- [🛠️ Configure exports manually](#️-configure-exports-manually)
- [⏭️ Next steps](#️-next-steps)

</details>

---

FinOps hubs uses Cost Management exports to import cost data for the billing accounts and subscriptions you want to monitor. You can either configure Cost Management exports manually or grant FinOps hubs access to manage exports for you.

<blockquote class="important" markdown="1">
  _Microsoft Cost Management does not support managed exports for Microsoft Customer Agreement billing accounts. Please [configure Cost Management exports manually](#️-configure-exports-manually)._
</blockquote>

For the most seamless experience, we recommend allowing FinOps hubs to manage exports for you when possible. This is the simplest to setup and requires the least effort to maintain over time. We only recommend configuring Cost Management exports manually if you cannot grant FinOps hubs access to manage exports for you.

<br>

## 🔐 Configure managed exports

Managed exports allow FinOps hubs to setup and maintain Cost Management exports for you. To enable managed exports, you must grant Azure Data Factory access to read data across each scope you want to monitor.

| Scope type            | Minimum required permissions |
| --------------------- | ---------------------------- |
| EA enrollment         | Enterprise Reader            |
| EA department         | Department Reader            |
| EA enrollment account | Not supported<sup>1</sup>    |
| MPA billing account   | Not supported<sup>1</sup>    |
| MPA customer          | Not supported<sup>1</sup>    |
| MCA billing account   | Not supported<sup>1</sup>    |
| MCA billing profile   | Not supported<sup>1</sup>    |
| MCA invoice section   | Not supported<sup>1</sup>    |
| Management group      | Not supported<sup>2</sup>    |
| Subscription          | Cost Management Contributor  |
| Resource group        | Cost Management Contributor  |

<sup>1) Scope does not support managed exports. Please [configure exports manually](#️-configure-exports-manually).</sup><br>
<sup>2) Scope not supported by FinOps hubs. Please enable each subscription separately.</sup><br>

1. **Grant access to Azure Data Factory.**

   - From the FinOps hub resource group, navigate to **Deployments** > **hub** > **Outputs**, and make note of the values for **managedIdentityId** and **managedIdentityTenantId**. You'll use these in the next step.
   - Use the following guides to assign access to each scope you want to monitor:
     - EA enrollments – [Assign enrollment reader role permission](https://learn.microsoft.com/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn).
     - EA departments – [Assign department reader role permission](https://learn.microsoft.com/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn).
     - Subscriptions and resource groups – [Assign Azure roles using the Azure portal](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal).

<!--
    ### Enterprise agreement billing accounts and departments
   
    1. [Find your enrollment (and department) Id](https://learn.microsoft.com/azure/cost-management-billing/manage/view-all-accounts#switch-billing-scope-in-the-azure-portal).
    2. Load the FinOps Toolkit PowerShell module.
    3. Grant reader permissions to the data factory
   
       ```powershell
       # Grants enrollment reader permissions to the specified service principal or managed identity
       Add-FinOpsServicePrincipal `
         -ObjectId 00000000-0000-0000-0000-000000000000 ` # Object Id of data factory managed identity
         -TenantId 00000000-0000-0000-0000-000000000000 ` # Azure Active Directory tenant Id
         -BillingAccountId 12345                          # Enrollment ID
   
       # Grants department reader permissions to the specified service principal or managed identity
       Add-FinOpsServicePrincipal `
         -ObjectId 00000000-0000-0000-0000-000000000000 ` # Object Id of data factory managed identity
         -TenantId 00000000-0000-0000-0000-000000000000 ` # Azure Active Directory tenant Id
         -BillingAccountId 12345 `                        # Enrollment Id
         -DepartmentId 67890                              # Department Id
        ```
-->

2. **Add the desired scopes.**

   1. From the FinOps hub resource group, open the storage account and navigate to **Storage browser** > **Blob containers** > **config**.
   2. Select the **settings.json** file, then select **⋯** > **View/edit** to open the file.
   3. Update the **scopes** property to include the scopes you want to monitor. See [Settings.json scope examples](#settingsjson-scope-examples) for details.
   4. Select the **Save** command to save your changes. FinOps hubs should process the change within a few minutes and data should be available within 30 minutes or so, depending on the size of your account.

   <blockquote class="important" markdown="1">
     _Do not add duplicate or overlapping scopes as this will lead to duplication of data._
   </blockquote>

3. **Backfill historical data.**

   As soon as you configure a new scope, FinOps hubs will start to monitor current and future costs. To backfill historical data, you must run the **config_RunBackfill** pipeline.

   To run the pipeline from the Azure portal:

   1. From the FinOps hub resource group, open the Data Factory instance, select **Launch Studio**, and navigate to **Author** > **Pipelines** > **config_RunBackfill**.
   2. Select **Debug** in the command bar to run the pipeline. The total run time will vary depending on the retention period and number of scopes you're monitoring.

   To run the pipeline from PowerShell:

   ```powershell
   Get-AzDataFactoryV2 `
     -ResourceGroupName "{hub-resource-group}" `
     -ErrorAction SilentlyContinue `
   | ForEach-Object {
       Invoke-AzDataFactoryV2Pipeline `
         -ResourceGroupName $_.ResourceGroupName `
         -DataFactoryName $_.DataFactoryName `
         -PipelineName 'config_RunBackfill'
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
      "scope": "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  ]
  ```

- Multiple subscriptions

  ```json
  "scopes": [
    {
      "scope": "/subscriptions/00000000-0000-0000-0000-000000000000"
    },
    {
      "scope": "subscriptions/00000000-0000-0000-0000-000000000001"
    }
  ]
  ```

- Resource group

  ```json
  "scopes": [
    {
      "scope": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftk-finops-hub"
    }
  ]
  ```

<br>

## 🖥️ Configure exports via PowerShell

If this is the first time you are using the FinOps toolkit PowerShell module , refer to the [PowerShell](/docs/_automation/powershell/README.md) deployment guide to install the module.

1. Install the FinOps toolkit PowerShell module.

   ```powershell
   Import-Module -Name FinOpsToolkit
   ```

2. Create the export and run it now to backfill up to 12 months of data.

   ```powershell
   New-FinopsCostExport -Name 'ftk-FinOpsHub-costs' `
     -Scope "{scope-id}" `
     -StorageAccountId "{storage-resource-id}" `
     -Backfill 12 `
     -Execute
   ```

<br>

## 🛠️ Configure exports manually

If you cannot grant permissions for your scope, you can create Cost Management exports manually to accomplish the same goal.

1. [Create a new FOCUS cost export](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-export-acm-data?tabs=azure-portal) using the following settings:

   <!-- TODO: Replace the portal link with the docs link when exports v2 docs are available. -->

   - **Type of data** = `Cost and usage details (FOCUS)`<sup>1</sup>
   - **Dataset version** = `1.0`<sup>2</sup>
   - **Frequency** = `Daily export of month-to-date costs`<sup>3</sup>
   - **File partitioning** = On
   - **Overwrite data** = Off<sup>4</sup>
   - **Storage account** = (Use subscription/resource deployed with your hub)
   - **Container** = `msexports`
   - **Directory** = (Use the resource ID of the scope<sup>5</sup> you're exporting without the first "/")
     - _**Billing account:** `providers/Microsoft.Billing/billingAccounts/{billingAccountId}`_
     - _**Billing profile:** `providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}`_
     - _**Department:** `providers/Microsoft.Billing/billingAccounts/{billingAccountId}/departments/{departmentId}`_

    <blockquote class="tip" markdown="1">
      _If you get an error about invalid characters for a billing scope, replace the unsupported characters (e.g., `:`) in the billing account ID with a dash (`-`)._
    </blockquote>

2. Create another export with the same settings except set **Frequency** to `Monthly export of last month's costs`.
3. Run your exports to initialize the dataset.
   - Exports can take up to a day to show up after first created.
   - Use the **Run now** command at the top of the Cost Management Exports page.
   - Your data should be available within 15 minutes or so, depending on how big your account is.
   - If you want to backfill data, open the export details and select the **Export selected dates** command to export one month at a time or use the [Start-FinOpsCostExport PowerShell command](../../_automation/powershell/cost/Start-FinOpsCostExport.md) to export a larger date range.
4. Repeat steps 1-3 for each scope you want to monitor.

_<sup>1) FinOps hubs 0.2 and beyond requires FOCUS cost data. As of July 2024, the option to export FOCUS cost data is only accessible from the central Cost Management experience in the Azure portal. If you do not see this option, please search for or navigate to [Cost Management Exports](https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/open/exports).</sup>_
_<sup>2) FinOps hubs 0.4 supports both FOCUS 1.0 and FOCUS 1.0 preview. Power BI reports in 0.4 are aligned to FOCUS 1.0 regardless of whether data was ingested as FOCUS 1.0 preview. If you need 1.0 preview data and reports, please use FinOps hubs 0.3.</sup>_
_<sup>3) Configuring a daily export starts in the current month. If you want to backfill historical data, create a one-time export and set the start/end dates to the desired date range.</sup>_
_<sup>4) While most settings are required, overwriting is optional. We recommend **not** overwriting files so you can monitor your ingestion pipeline using the [Data ingestion](../power-bi/data-ingestion.md) report. If you do not plan to use that report, please enable overwriting.</sup>_
_<sup>5) A "scope" is an Azure construct that contains resources or enables purchasing services, like a resource group, subscription, management group, or billing account. The resource ID for a scope will be the Azure Resource Manager URI that identifies the scope (e.g., "/subscriptions/###" for a subscription or "/providers/Microsoft.Billing/billingAccounts/###" for a billing account). To learn more, see [Understand and work with scopes](https://aka.ms/costmgmt/scopes).</sup>_

---

## ⏭️ Next steps

[Connect to Power BI](./reports/README.md){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Learn more](./README.md#-why-finops-hubs){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
