---
title: How to create and update FinOps hubs
description: This tutorial helps you create a new or update an existing FinOps hubs instance in Azure or Microsoft Fabric.
author: flanakin
ms.author: micflan
ms.date: 06/05/2025
ms.topic: tutorial
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps hubs are so that I can use them in my organization.
---

<!-- markdownlint-disable-next-line MD025 -->
# Tutorial: Create and update FinOps hubs

In this tutorial, you learn how to create a new or update an existing FinOps hub instance in Azure or Microsoft Fabric. The tutorial walks through deployment options and decisions that need to be made as you set up and configure FinOps hubs. This article helps you:

> [!div class="checklist"]
> - Apply FinOps hubs prerequisites. <!-- markdownlint-disable-line MD032 -->
> - Create a new or update an existing FinOps hub instance.
> - Ingest and backfill data in FinOps hubs.
> - Connect your hub to Microsoft Fabric.
> - Create reports and dashboards.

<br>

## Prerequisites

- Access to an active Azure subscription with permissions to deploy the FinOps hubs template:
  - [Contributor](/azure/role-based-access-control/built-in-roles#contributor) to deploy resources.
  - [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) to configure managed identity.
  - For least-privileged access, see [template details](template.md#prerequisites).
- Access to one or more supported Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), or Microsoft Partner Agreement (MPA) scope in Cost Management to configure exports:
  - Subscriptions and resource groups: [Cost Management Contributor](/azure/role-based-access-control/built-in-roles#cost-management-contributor).
  - EA billing scopes: Enterprise Reader, Department Reader, or Account Owner (also known as enrollment account).
  - MCA billing scopes: Contributor on the billing account, billing profile, or invoice section.
  - MPA billing scopes: Contributor on the billing account, billing profile, or customer.
- Optional: Access to Power BI or a Microsoft Fabric workspace with Contributor or Member permissions to create resources and publish reports.
- Optional: PowerShell 7 or Azure Cloud Shell with the [FinOps toolkit PowerShell module](../powershell/powershell-commands.md) installed and imported.

More permissions are covered as part of the tutorial.

<br>

## Enable required resource providers

FinOps hubs use Cost Management to export data and Event Grid to know when data is added to your storage account. Before deploying the template, you need to register the **Microsoft.CostManagementExports** and **Microsoft.EventGrid** resource providers.

<!-- markdownlint-disable-next-line -->
### [Azure portal](#tab/azure-portal)

1. From the Azure portal, open the [list of subscriptions](https://portal.azure.com/#view/Microsoft_Azure_Billing/SubscriptionsBladeV2).
2. Select the subscription to use for your FinOps hub deployment.
3. In the left menu, select **Settings** > **Resource providers**.
4. In the list of resource providers, find the row for **Microsoft.EventGrid**.
5. If the **Status** column shows Not Registered, select the context menu to the right of the provider name (⋅⋅⋅) and then select **Register**.
6. Repeat steps 4-5 for **Microsoft.CostManagementExports**.

<!-- markdownlint-disable-next-line -->
### [PowerShell](#tab/powershell)

The following command is part of the FinOps toolkit PowerShell module. To install the module, see [Install the FinOps toolkit PowerShell module](../powershell/powershell-commands.md#install-the-module).

This command is run as part of the [Deploy-FinOpsHub command](../powershell/hubs/Deploy-FinOpsHub.md). If you're deploying the template via PowerShell, you can skip this step.

```powershell
Initialize-FinOpsHubDeployment
```

To learn more about this command, see [Initialize-FinOpsHubDeployment](../powershell/hubs/Initialize-FinOpsHubDeployment.md)

---

<br>

## Plan your network architecture

Do you prefer public or private network routing?

Public routing is most common and easiest to use. Resources are reachable from the open internet. Access is controlled via role-based access control (RBAC). Public routing doesn't require configuration.

Do you prefer public or private network routing?

- Public routing is most common, easiest to use, and makes resources reachable from the open internet.
- Private routing is most secure, comes with added cost, and makes resources only reachable from peered networks.

Public routing doesn't require configuration. If you opt for private routing, work with your network admin to configure peering and routing so the FinOps hubs isolated network is reachable from your network. Before you decide, learn more about the extra configuration steps required in [Configure private networking](private-networking.md).

<br>

## Optional: Configure remote hubs

Remote hubs enable cross-tenant cost data collection scenarios where a central tenant aggregates cost data from multiple tenants or subscriptions. In this setup, "satellite" FinOps hubs in different tenants send their processed data to a central "primary" hub for consolidated reporting and analysis.

### When to use remote hubs

Consider remote hubs when you have:

- Multiple Azure tenants with separate billing relationships
- A centralized FinOps team that needs visibility across multiple organizations
- Subsidiaries or business units in separate tenants
- Partners or customers who want to contribute cost data to a shared analysis

### Architecture overview

In a remote hub configuration:

1. **Primary hub**: Central FinOps hub that receives and stores aggregated data from all tenants
2. **Remote (satellite) hubs**: FinOps hubs in remote tenants that process local cost data and send it to the primary hub

### Configure the primary hub

1. Deploy a standard FinOps hub in your central tenant using the regular deployment process
2. Note the storage account name (found in the resource group after deployment)
3. Get the Data Lake storage endpoint:
   - Navigate to the storage account in the Azure portal
   - Select **Settings** > **Endpoints**
   - Copy the **Data Lake storage** URL (format: `https://storageaccount.dfs.core.windows.net/`)
4. Get the storage account access key:
   - Navigate to **Security + networking** > **Access keys**
   - Copy **key1** or **key2** value

### Configure remote hubs

When deploying remote hubs, provide the primary hub's storage details:

#### [Azure portal](#tab/azure-portal)

1. When deploying the FinOps hub template, navigate to the **Advanced** tab
2. Expand **Remote hub configuration**
3. Enter the **Remote hub storage URI** from the primary hub
4. Enter the **Remote hub storage key** from the primary hub
5. Complete the deployment normally

#### [PowerShell](#tab/powershell)

```powershell
Deploy-FinOpsHub `
    -Name MyRemoteHub `
    -ResourceGroup MyRemoteHubResourceGroup `
    -Location westus `
    -RemoteHubStorageUri "https://primaryhubstore123.dfs.core.windows.net/" `
    -RemoteHubStorageKey "abc123...xyz789=="
```

---

### Security considerations

- **Storage keys**: Treat storage keys as secrets. They provide full access to the storage account
- **Network access**: Consider using private networking for both primary and remote hubs
- **Key rotation**: Regularly rotate storage keys and update remote hub configurations
- **Least privilege**: The storage key provides broad access; consider using Azure AD authentication when available

### Data flow and processing

Remote hubs process data locally and then send processed (not raw) cost data to the primary hub. This approach:

- Reduces data transfer costs
- Maintains data sovereignty for initial processing
- Centralizes only the final, processed cost data
- Preserves full granularity in the primary hub

<br>

## Optional: Set up Microsoft Fabric

Many organizations adopt Microsoft Fabric as a unified data platform to streamline data analytics, storage, and processing. FinOps hubs can use Microsoft Fabric Real-Time Intelligence (RTI) as either a primary or secondary data store. This section only applies when configuring Microsoft Fabric as a primary data store instead of Azure Data Explorer.

Configuring Microsoft Fabric is a manual process and requires explicit steps before and after template deployment. This section covers the initial setup requirements.

1. Create a workspace and eventhouse:<!-- cSpell:ignore eventhouse -->
   1. From Microsoft Fabric, open the desired workspace or create a new workspace. [Learn more](/fabric/fundamentals/create-workspaces).
   2. From your Fabric workspace, select the **+ New item** command at the top of the page.
   3. Select **Store data** > **Eventhouse**.
   4. Specify a name (for example, `FinOpsHub`) and select **Create**.
2. Create and configure the **Ingestion** database:
   1. Select **Eventhouse** > **+ Database** at the top of the page, set the name to `Ingestion`, and select **Create**.
   2. Select the **Ingestion_queryset** in the left menu.<!-- cSpell:ignore queryset -->
   3. Delete all text in the file.
   4. Download and open the [finops-hub-fabric-setup-Ingestion.kql file](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-fabric-setup-Ingestion.kql) in a text editor.
   5. Copy the entire text from this file into the Fabric queryset editor.
   6. Press <kbd>Ctrl+H</kbd> to trigger the find and replace dialog, set the find text to `$$rawRetentionInDays$$`, and replace it with `0` or desired number of days to keep data in **_raw** tables, then press <kbd>Ctrl+Alt+Enter</kbd> to replace all instances.
   7. Press <kbd>Ctrl+Home</kbd> to bring the cursor to the beginning of the file and press <kbd>Shift+Enter</kbd> or select the **Run** command at the top of the page.
   8. Wait for the script to complete and then review the **Result** column to confirm all commands completed successfully.
      - If you see an error for a line that has **$$rawRetentionInDays$$**, repeat steps 2.6 and 2.7.
      - If you experience a different error, [create an issue in GitHub](https://aka.ms/ftk/ideas).
3. Repeat step 2 for the **Hub** database using the [finops-hub-fabric-setup-Hub.kql file](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-fabric-setup-Hub.kql) script file.
4. In the left pane, select **System overview**, then select the **Copy URI** link for the **Query URI** property in the details pane on the right.
   - Make note of the query URI. You'll use it in the next step.

<br>

## Deploy the FinOps hub template

The core engine for FinOps hubs is deployed via an Azure Resource Manager deployment template. The template is available in [bicep](/azure/azure-resource-manager/bicep/overview). The template includes a storage account, Azure Data Factory, Azure Data Explorer, and other supporting resources. To learn more about the template and least-privileged access requirements, refer to the [FinOps hub template details](template.md).

<!-- markdownlint-disable-next-line -->
### [Azure portal](#tab/azure-portal)

1. Open the desired template in the Azure portal:
   - [Deploy to Azure](https://aka.ms/finops/hubs/deploy)
   - [Deploy to Azure Gov](https://aka.ms/finops/hubs/deploy/gov)
   - [Deploy to Azure China](https://aka.ms/finops/hubs/deploy/china) (MCA only)
2. Select the desired subscription and resource group.
3. Select an Azure region where you would like to deploy resources to.
   - If connecting to Microsoft Fabric, select the same region as your Fabric capacity. You can find the region in your workspace settings > **License info** > **License capacity**.
4. Specify a hub name used for core resources and reporting purposes.
   - All resources have a common **cm-resource-parent** tag to group them together under the hub in Cost Management.
5. Specify a unique Azure Data Explorer cluster name or the Microsoft Fabric eventhouse Query URI.
   - This name is used to query data and connect to reports, dashboards, and other tools.
   - If deploying to Microsoft Fabric, use your Fabric eventhouse query URI and leave the Data Explorer cluster name empty.
   - Data Explorer and Fabric are optional, but recommended if monitoring more than $100,000 in total spend.
   - Warning: Power BI may experience timeouts and data refresh issues if relying on storage for more than $1 million in spend. If you experience issues, redeploy with Data Explorer or Microsoft Fabric.
6. Select the **Next** button at the bottom of the form.
7. If desired, you can change the storage redundancy or Data Explorer SKU.
   - We don't recommend changing either setting for your initial deployment.
   - If using Data Explorer, the storage account is a temporary data store and shouldn't need geo-redundancy.
   - Most deployments doesn't require a larger Data Explorer SKU. We recommend starting with the dev/test cluster and monitoring performance before scaling up or out.
   - For details about scaling Data Explorer, see [Select a SKU for your cluster](/azure/data-explorer/manage-cluster-choose-sku).
8. Select the **Next** button at the bottom of the form.
9. Set the desired data retention periods.
   - Raw data retention refers to data added to Data Explorer, but not normalized into the final tables. Use 0 unless you need to troubleshoot ingestion issues. This number indicates retention in days.
   - Normalized data retention refers to the time frame in months that data is available in the final tables. 0 only keeps the current month, 1 is only last month and the current month, and so on.
10. Select the **Next** button at the bottom of the form.
11. Indicate if you need infrastructure encryption.
    - Not recommended unless you have specific policies requiring infrastructure encryption.
12. Indicate is you want public or private network routing. [Learn more](private-networking.md).
13. If you selected private, specify the desired private network address prefix.
14. Select the **Next** button at the bottom of the form.
15. If desired, specify more tags to add to resources.
16. Select the **Next** button at the bottom of the form.
17. Review the configuration summary and select the **Create** button at the bottom of the form.

<!-- markdownlint-disable-next-line -->
### [PowerShell](#tab/powershell)

The following command is part of the FinOps toolkit PowerShell module. To install the module, see [Install the FinOps toolkit PowerShell module](../powershell/powershell-commands.md#install-the-module).

```powershell
# Deploying to Azure Data Explorer
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location westus `
    -DataExplorerName MyFinOpsHubCluster

# Deploying to Microsoft Fabric
Deploy-FinOpsHub `
    -Name MyHub `
    -ResourceGroupName MyNewResourceGroup `
    -Location westus `
    -DataExplorerName https://abcxyz123789.x0.kusto.fabric.microsoft.com
```

For other parameters, see [Deploy-FinOpsHub](../powershell/hubs/Deploy-FinOpsHub.md).

---

<br>

## Optional: Configure Fabric access

If you set up Microsoft Fabric as a primary data store, configure access for Data Factory and the Fabric eventhouse.

1. Get the Data Factory identity:
   1. From the Azure portal, open the FinOps hub resource group.
   2. In the list of resources, select the Data Factory instance.
   3. In the menu on the left, select **Settings** > **Managed identities** and copy the **Object (principal) ID**.
2. Give Data Factory access to the Hub and Ingestion databases:
   1. From Microsoft Fabric, open the desired workspace and select the target eventhouse.
   2. Select the **Ingestion** database in the left pane.
   3. Select **Ingestion_queryset** in the left pane.
   4. Run the following commands separately, replacing `<adf-identity-id>` with the Data Factory managed identity object ID from step 1:

      <!-- cSpell:ignore aadapp -->
      ```kusto
      .add database Ingestion admins ('aadapp=<adf-identity-id>')

      .add database Hub admins ('aadapp=<adf-identity-id>')
      ```
<!--
1. Create an identity for your Fabric workspace:
   1. From Microsoft Fabric, open the workspace and select **Workspace settings** in the top-right corner.
   2. In the flyout menu, select **Workspace identity** and then select the **+ Workspace identity** button.
   3. Copy the ID.
2. Grant your Fabric workspace access to storage:
   1. From the Azure portal, open the FinOps hub resource group.
   2. In the list of resources, select the primary storage account (not the "script" storage).
   3. Select **Access control (IAM)** > **+ Add** > **Add role assignment**.
   4. Select **Storage Blob Data Reader** and then **Next**.
   5. Select **+ Select members**.
   6. In the filter box, paste the workspace identity ID from step 3.
   7. Select the workspace "application" from the list and then the **Select** button at the bottom.
   8. Select **Review + assign** at the bottom-left of the page.
-->

<br>

## Configure scopes to monitor

FinOps hubs can monitor any cost and usage dataset that aligns to the [FinOps Open Cost and Usage Specification (FOCUS)](../../focus/what-is-focus.md).

You can ingest data from Microsoft Cost Management by creating exports manually or granting access to FinOps hubs to create and manage exports for you. The following steps must be repeated for each scope you need to monitor. We recommend using EA billing accounts and MCA billing profiles for the best coverage and broadest available datasets. To learn more about the difference between manual and managed exports, see [Configure scopes](configure-scopes.md).

<!-- markdownlint-disable-next-line -->
### [Azure portal](#tab/azure-portal)

1. From the Azure portal, open [Cost Management](https://aka.ms/costmgmt).
2. Select the desired scope from the scope picker towards the top of the page.
3. In the menu on the left, select **Reporting + analytics** > **Exports**.
4. Select the **Create** command.
5. Select the **All costs (FOCUS) + prices** template.
6. Specify a prefix (for example, **finops-hub**) and select **Next** at the bottom.
7. Select the subscription and storage account created by the FinOps hub deployment.
8. Set the container to `msexports`.
9. Set the directory to a unique string that identifies the scope (for example, `billingAccounts/###`).
10. Select the **Parquet** format and **Snappy** compression for the best performance.
    - Any combination of CSV and parquet, compressed or uncompressed is supported, but snappy parquet is recommended.
11. Select **Next** at the bottom.
12. Review and correct settings as needed and then select **Create** at the bottom.
13. Repeat steps 4-12 for any more datasets.
    - Reservation recommendations are required for the Rate optimization report's Reservation recommendations page to load.

<!-- markdownlint-disable-next-line -->
### [PowerShell](#tab/powershell)

The following command is part of the FinOps toolkit PowerShell module. To install the module, see [Install the FinOps toolkit PowerShell module](../powershell/powershell-commands.md#install-the-module).

```powershell
# Prices (required to populate missing prices)
# Only supported for EA billing accounts and MCA billing profiles
New-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name finops-hub-prices `
    -Dataset PriceSheet `
    -StorageAccountId $FinOpsHubStorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingAccounts/###/billingProfiles/###' `
    -DoNotOverwrite `
    -Backfill 13 # or desired number of months

# Cost and usage data
# Supported on all scopes except management groups
New-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name finops-hub-costs `
    -Dataset FocusCost `
    -StorageAccountId $FinOpsHubStorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingAccounts/###/billingProfiles/###' `
    -DoNotOverwrite `
    -Backfill 13 # or desired number of months

# Optional: Shared VM reservation recommendations with 30-day lookback
# Only supported for EA billing accounts and MCA billing profiles
New-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name finops-hub-resrecs-vm-shared-30d `
    -Dataset ReservationRecommendations `
    -CommitmentDiscountResourceType VirtualMachines `
    -CommitmentDiscountScope Shared `
    -CommitmentDiscountLookback Shared 30 # or 7 or 60 `
    -StorageAccountId $FinOpsHubStorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingAccounts/###/billingProfiles/###' `
    -DoNotOverwrite `
    -Backfill 13 # or desired number of months

# Optional: Single (subscription) VM reservation recommendations with 30-day lookback
# Only supported for EA billing accounts and MCA billing profiles
New-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name finops-hub-resrecs-vm-shared-30d `
    -Dataset ReservationRecommendations `
    -CommitmentDiscountResourceType VirtualMachines `
    -CommitmentDiscountScope Single `
    -CommitmentDiscountLookback Shared 30 # or 7 or 60 `
    -StorageAccountId $FinOpsHubStorageAccountId `
    -StorageContainer msexports `
    -StoragePath 'billingAccounts/###/billingProfiles/###' `
    -DoNotOverwrite `
    -Backfill 13 # or desired number of months
```

For other parameters, see [New-FinOpsCostExport](../powershell/cost/New-FinOpsCostExport.md).

---

### Managed exports

Managed exports allow FinOps hubs to set up and maintain Cost Management exports for you. To enable managed exports, you must grant Azure Data Factory access to read data across each scope you want to monitor. For detailed instructions, see [Configure managed exports](configure-scopes.md#configure-managed-exports).

### Ingest from other data sources

To ingest data from other data providers that support FOCUS, such as Amazon Web Services (AWS), Google Cloud Platform (GCP), Oracle Cloud Infrastructure (OCI), and Tencent:

1. Configure a FOCUS dataset from your provider.
2. Create a workflow to copy data into the **ingestion** container in the FinOps hub storage account.
   - Files are separated by UTC calendar month and should be less than 2 GB each, saved in parquet format. Snappy compression is optional.
   - Files should be placed in the following folder path: `Costs/yyyy/mm/{scope}`.
     - `yyyy` represents the four-digit year of the dataset.
     - `mm` represents the two-digit month of the dataset.
     - `{scope}` represents a logical, consistent identifier for the dataset. This value can be any valid path using one or more nested folders.
   - If the provider generates nonoverlapping deltas in each dataset, add an extra folder for the day and/or hour (`dd` or `dd/hh`) between the month and scope folders.
     - The goal is to ensure that overriding datasets should consistently land in the same folder path so they're overwritten each time. Nonoverlapping datasets should be pushed to a new folder path.
3. Create an empty `manifest.json` file in the same folder.
   - Data Explorer ingestion is triggered when manifest.json files are added or updated.
4. If there are any columns not covered in the current ingestion process, update the **Costs_raw** and **Costs_final_v1_0** tables, and **Costs_transform_v1_0**, **Costs_v1_0**, and **Costs** functions accordingly.
   - Submit a [feature request](https://aka.ms/ftk/ideas) to add new columns to the default ingestion code to ensure customizations don't block future upgrades.

<br>

## Optional: Populate historical data

FinOps hubs don't automatically backfill data. To populate historical data, run historical data exports from the original data provider, including any custom data pipelines used to publish data into the **ingestion** storage container.

For Microsoft Cost Management:

<!-- markdownlint-disable-next-line -->
### [Azure portal](#tab/azure-portal)

1. From the Azure portal, open [Cost Management](https://aka.ms/costmgmt).
2. Select the desired scope from the scope picker towards the top of the page.
3. In the menu on the left, select **Reporting + analytics** > **Exports**.
4. Select the desired export in the list of exports.
   - Always export prices before costs to ensure they're available to populate missing prices in the cost and usage dataset.
   - If costs are exported first, rerun the **ingestion_ExecuteETL** pipeline for the month's cost data to populate the missing prices.
5. Select **Export selected dates** and specify the desired month. Always export the full  month.
6. Repeat step 5 for all desired months.
   - Cost Management only supports exporting up to the last 12 months from the Azure portal.
   - Consider using PowerShell to export beyond the last 12 months.
7. Repeat steps 4-6 for each export.
8. Repeat steps 2-7 for each scope.

<!-- markdownlint-disable-next-line -->
### [PowerShell](#tab/powershell)

The following command is part of the FinOps toolkit PowerShell module. To install the module, see [Install the FinOps toolkit PowerShell module](../powershell/powershell-commands.md#install-the-module).

Run the following command for price exports first, then other datasets.

```powershell
Start-FinOpsCostExport `
    -Scope '/providers/Microsoft.Billing/billingAccounts/###/billingProfiles/###' `
    -Name '{export-name}' `
    -Backfill 13 # or desired number of months
```

For other parameters, see [Start-FinOpsCostExport](../powershell/cost/Start-FinOpsCostExport.md).

---

<br>

## Optional: Connect to Microsoft Fabric as a follower

<!-- cSpell:ignore eventhouses -->
If you chose to configure FinOps hubs with Data Explorer, but are still interested in making data available in Microsoft Fabric, create a shortcut (follower) database using Fabric eventhouses. Shortcut databases are not necessary if you ingested directly into a Fabric eventhouse.

1. From your Fabric workspace, select the **+ New item** command at the top of the page.
2. Select **Store data** > **Eventhouse**.
3. Specify a name and select **Create**.
4. Select **+ Database** at the top of the page.
5. Set the name to `Ingestion` and type to **New shortcut database (follower)**, then select **Next**.
6. Set the cluster URI to the FinOps hub cluster URI and database to `Ingestion`, then select **Create**.
7. Repeat steps 4-6 for the `Hub` database.

<br>

## Configure reports and dashboards

FinOps hubs come with a Data Explorer dashboard and Power BI reports that can connect to data in Data Explorer (via KQL) or in Azure Data Lake Storage.

We recommend setting up the Data Explorer dashboard even if you use Power BI due to the quick and easy setup and insights into ingested data.

<!-- markdownlint-disable-next-line -->
### [Data Explorer dashboard](#tab/adx-dashboard)

1. [Download the dashboard template](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json).
2. Grant any users **Viewer** (or greater) access to the **Hub** and **Ingestion** databases. [Learn more](/kusto/management/manage-database-security-roles#database-level-security-roles).
3. Go to [Azure Data Explorer dashboards](https://dataexplorer.azure.com/dashboards).
4. Import a new dashboard from the file in step 1.
5. Edit the dashboard and change the data source to your FinOps hub cluster.

For more information, see [Configure Data Explorer dashboards](configure-dashboards.md).

<!-- markdownlint-disable-next-line -->
### [Fabric real-time dashboard](#tab/fabric-real-time-dashboard)

1. [Download the dashboard template](https://github.com/microsoft/finops-toolkit/releases/latest/download/finops-hub-dashboard.json).
2. Grant any users **Viewer** (or greater) access to the workspace. [Learn more](/fabric/fundamentals/roles-workspaces).
3. From your Fabric workspace, select the **+ New item** command at the top of the page.
4. Select **Visualize data** > **Real-time dashboard**.
5. Specify a name and select **Create**.
6. Select **Manage** > **Replace with file** at the top of the page.
7. Select the downloaded file from step 1.
8. Select **Manage** > **Data sources** at the top of the page.
9. Select the edit (pencil) icon for the **Hub** database.
10. Select **Database** > **Eventhouse / KQL database**, then select the **Hub** database and **Connect**.
11. Select **Apply**, then **Close**.

For more information, see [Configure Data Explorer dashboards](configure-dashboards.md).

<!-- markdownlint-disable-next-line -->
### [Power BI reports](#tab/power-bi)

1. Download the Power BI reports for your backend:
   - If connecting to Data Explorer or Microsoft Fabric, use [KQL reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-kql.zip).
   - If connecting to storage (including FinOps hubs), use [Storage reports](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-storage.zip).
2. Open each report and specify applicable report parameters:
   - **Cluster URI** is the Data Explorer cluster URI or Microsoft Fabric eventhouse query URI.
   - **Storage URL** is the DFS endpoint for the Azure Data Lake Storage account.
   - All other parameters are optional or have defaults.
3. Authorize each data source:
   - **Azure Data Explorer (Kusto)** &ndash; Use an account that has at least viewer access to the Hub and Ingestion databases.
   - **Azure Resource Graph** &ndash; Use an account that has direct access to any subscriptions you would like to report on.
   - **(your storage account)** &ndash; Use a SAS token or an account that has Storage Blob Data Reader or greater access.
   - **https://ccmstorageprod...** &ndash; Anonymous access. This URL is used for reservation size flexibility data.
   - **https://github.com/...** &ndash; Anonymous access. This URL is used for FinOps toolkit open data files.

For more information, see [Set up Power BI reports](../power-bi/setup.md).

To preview reports without connecting to your data, download the [Power BI demo](https://github.com/microsoft/finops-toolkit/releases/latest/download/PowerBI-demo.zip).

---

<br>

## Troubleshooting

If you experience a specific error, check the [list of common errors](../help/errors.md) for mitigation steps. If you aren't experiencing a specific error code or run into any other issues, refer to the [Troubleshooting guide](../help/troubleshooting.md).

If your issue isn't resolved with the troubleshooting guide, see [Get support for FinOps toolkit issues](../help/support.md) for additional help.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.11/bladeName/Hubs/featureName/Deploy)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3Areactions-%2B1-desc)

<br>

## Related content

Related FinOps capabilities:

- [Data ingestion](../../framework/understand/ingestion.md)
- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps workbooks](../workbooks/finops-workbooks-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
