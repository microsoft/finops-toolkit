---
title: Create a Fabric workspace for FinOps
description: This article guides you through creating and configuring a Microsoft Fabric workspace for FinOps. When completed, you can use Power BI to build reports.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-workspaces
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps best practices I should use with web services.
---

# Create a Fabric workspace for FinOps

This article walks you through creating and configuring a [Microsoft Fabric](/fabric/get-started/microsoft-fabric-overview) workspace for FinOps. It provides a step-by-step guide to create and configure Azure Data Lake storage (ADLS) setup, data export, workspace creation, and data ingestion. When completed, you can use Power BI to build reports.

## Prerequisites

Before you begin, you must have:

- A paid Azure subscription with cost and usage information
- Owner of a storage account or have access to grant permissions to the storage account
- You must have the _Storage Blob Data Contributor_ role when you use _Organizational account_ authentication. If you don't have the required permission, you can use other authentication types like _Account key_. Otherwise, you get an `Invalid credentials` error.

To complete this walkthrough, you create the following resources that incur costs:

- An Azure Data Lake Storage Gen2 account
- A Power BI workspace
- A Fabric workspace

<br>

## Create and configure Azure Data Lake Storage

Microsoft Fabric is optimized to work with storage accounts with hierarchical namespace enabled, also known as Azure Data Lake Storage Gen2. You have two options to get a Data Lake storage account:

- Option 1: To create a Data Lake storage account, see [Create a storage account for Azure Data Lake Storage Gen2](/azure/storage/blobs/create-data-lake-storage-account).
- Option 2: To enable hierarchical namespace on an existing storage account, see [Upgrade Azure Blob Storage with Azure Data Lake Storage Gen2 capabilities](/azure/storage/blobs/upgrade-to-data-lake-storage-gen2-how-to?tabs=azure-portal).

> [!TIP]
> If you deployed [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md), you can use the storage account created as part of the hub resource group.

For the following example, we used the following Data Lake Gen 2 storage account. You use your own storage account and subscription details.

- Subscription = _Contoso subscription_.
- Storage account = _Contoso-storage-account_.

:::image type="content" source="./media/create-fabric-workspace-finops/storage-account-configuration-gen-2.png" border="true" alt-text="Screenshot showing converting an existing storage account into Data Lake storage." lightbox="./media/create-fabric-workspace-finops/storage-account-configuration-gen-2.png" :::

<br>

## Export cost data

Since we're creating a workspace optimized for FinOps, we export cost data using the FinOps Open Cost and Usage Specification (FOCUS), a provider-agnostic data format for cost details. All our examples use FOCUS but you can also use existing actual or amortized cost exports that have file overwriting enabled.

For more information about FOCUS and its benefits, see [What is FOCUS](../focus/what-is-focus.md). The FinOps Foundation also offers a free [Introduction to FOCUS course](https://learn.finops.org/introduction-to-focus). Microsoft’s Power BI solutions for FinOps are aligned to FOCUS.

To create an export, see [Create exports](/azure/cost-management-billing/costs/tutorial-improved-exports#create-exports).

Here are the high-level steps to create an export:

1. Sign in to the Azure portal at [https://portal.azure.com](https://portal.azure.com/), search for **Cost Management**.
2. Select the required scope and select **Exports** in the left navigation menu.
3. Select **+ Create**
4. On the Basics tab, select the template = **Cost and usage (FOCUS)**
   :::image type="content" source="./media/create-fabric-workspace-finops/exports-cost-and-usage-focus.png" border="true" alt-text="Screenshot showing creating a new FOCUS export dataset." lightbox="./media/create-fabric-workspace-finops/exports-cost-and-usage-focus.png" :::
5. On the Datasets tab, fill in **Export prefix** to ensure you have a unique name for the export. For example, _june2024focus_.
6. On the Destination tab, select:
   - Storage type = Azure blob storage
   - Destination and storage = **Use existing**
   - Subscription = _Contoso subscription_
   - Storage account = _Contoso-storage-account_
   - Container = _msexports_
   - Directory = focuscost/&lt;_scope-id_&gt;
   - Compression type = **None**.
   - Overwrite data = **Enabled**
7. On the Review + Create tab, select **Create**.
8. Run the export by selecting **Run now** on the export page.

Ensure that your export completed and that the file is available before moving to the next step.

> [!IMPORTANT]
> Cost Management exports utilize managed identity. To create an export, you must be an Owner of the storage account or have access to grant permissions to the storage account. To see all required permissions, see [Prerequisites](/azure/cost-management-billing/costs/tutorial-improved-exports#prerequisites).

If you want to automate export creation, consider using the [New-FinOpsCostExport command](../toolkit/powershell/cost/New-FinOpsCostExport.md) in the FinOps toolkit PowerShell module.

If you deployed [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md), you can skip this step and use the processed data in hub storage.

<br>

## Create a Fabric workspace

If you already have a [Microsoft Fabric workspace](/fabric/get-started/workspaces), you can skip creating a new workspace, unless you want to keep your FinOps resources separate from others.

If you didn't set up Microsoft Fabric, see [Enable Microsoft Fabric for your organization](/fabric/admin/fabric-switch).

1. Sign in to the Fabric app using your [Fabric free account](https://www.microsoft.com/microsoft-fabric/getting-started) or [Microsoft Power BI](https://app.powerbi.com) account.
2. You can create a new workspace for your FinOps resources or choose to use an existing workspace. To create a workspace, see [Create a workspace](/fabric/get-started/create-workspaces).

If you’re new to Microsoft Fabric or don’t have Fabric capacity enabled, see [Fabric trial](/fabric/get-started/fabric-trial). If Fabric trials are disabled, you might need to [create a new Fabric capacity](/fabric/admin/capacity-settings?tabs=fabric-capacity#create-a-new-capacity).

Nontrial Fabric capacity incurs charges for your organization. See [Microsoft Fabric pricing](https://azure.microsoft.com/pricing/details/microsoft-fabric/).

Here's an example screenshot showing a new Fabric workspace getting created.

:::image type="content" source="./media/create-fabric-workspace-finops/fabric-create-workspace.png" border="true" alt-text="Screenshot showing a workspace getting created." lightbox="./media/create-fabric-workspace-finops/fabric-create-workspace.png" :::

<br>

## Create a lakehouse

Microsoft Fabric [lakehouses](/fabric/data-engineering/lakehouse-overview) are data architectures that allow organizations to store and manage structured and unstructured data in a single location. They use various tools and frameworks to process and analyze that data. These tools and frameworks can include SQL-based queries and analytics, machine learning, and other advanced analytics techniques.

You can either create a new lakehouse or use an existing one. Lakehouses are interoperable so we would generally recommend using a single lakehouse for all your FinOps datasets. A single lakehouse keeps related information together to share data models, pipelines, and security measures.

To create a new lakehouse in the Fabric workspace of your choice:

1. Sign in to the Fabric app using your [Fabric free account](https://www.microsoft.com/microsoft-fabric/getting-started) or [Microsoft Power BI](https://app.powerbi.com) account.
1. Select the workspace where you want to create the lakehouse.
1. Near the top left of the page, select **+ New** and then select **More options**.  
   :::image type="content" source="./media/create-fabric-workspace-finops/fabric-new-more-options.png" border="true" alt-text="Screenshot showing navigation to More options." lightbox="./media/create-fabric-workspace-finops/fabric-new-more-options.png" :::
1. Select **Lakehouse**  
   :::image type="content" source="./media/create-fabric-workspace-finops/fabric-new-lakehouse.png" border="true" alt-text="Screenshot showing the Lakehouse option." lightbox="./media/create-fabric-workspace-finops/fabric-new-lakehouse.png" :::

For more information, see [Create a lakehouse](/fabric/data-engineering/create-lakehouse).

<br>

## Create a shortcut to storage

Shortcuts in lakehouse allow you to reference data without copying it. It unifies data from different lakehouses, workspaces, or external storage, such as Data Lake Gen2 or Amazon Web Services (AWS) S3. You can quickly make large amounts of data available in your lakehouse locally without the latency of copying data from the source.

To create a shortcut, see [Create an Azure Data Lake Storage Gen2 shortcut](/fabric/onelake/create-adls-shortcut).

1. Sign in to the Fabric app using your [Fabric free account](https://www.microsoft.com/microsoft-fabric/getting-started) or [Microsoft Power BI](https://app.powerbi.com) account.
1. Select the lakehouse of your choice.
1. Select the ellipsis (**...**) next to **Files**.  
   You add CSV and Parquet files under **Files**. Delta tables get added under **Tables**.
1. Select **New shortcut**.  
   :::image type="content" source="./media/create-fabric-workspace-finops/fabric-new-shortcut.png" border="true" alt-text="Screenshot showing creating a new shortcut in a lakehouse under the Files folder." lightbox="./media/create-fabric-workspace-finops/fabric-new-shortcut.png" :::
1. Select **Azure Data Lake Storage Gen 2** and provide the following settings:
   - URL = **Data Lake Storage** URL of the Data Lake storage account. See the following note about authentication.
   - Connection = **Create a new connection**
   - Connection name = &lt;_Any name of your choice_&gt;
   - Authentication kind = **Organizational account**
   - Sign in when prompted.

Here’s an example screenshot showing the New shortcut connection settings.

:::image type="content" source="./media/create-fabric-workspace-finops/fabric-new-shortcut-connection-settings.png" border="true" alt-text="Screenshot showing the New shortcut connection settings." lightbox="./media/create-fabric-workspace-finops/fabric-new-shortcut-connection-settings.png" :::

To get the Data Lake Storage URL, view the storage account where the export created a directory and the FOCUS cost file. Under **Settings**, select **Endpoints**. Copy the URL marked as **Data Lake Storage**.

Here’s an example screenshot showing the Data Lake Storage URL on the **Endpoints** page.

:::image type="content" source="./media/create-fabric-workspace-finops/endpoints-page-storage-account.png" border="true" alt-text="Screenshot showing the Endpoints page of the storage account." lightbox="./media/create-fabric-workspace-finops/endpoints-page-storage-account.png" :::

<br>

## Copy data into Fabric

After you create the shortcut, you can view the FOCUS cost data inside **Files**. You can load the data directly into a Fabric with one of the following methods, based on your requirements. The following tabs provide two options:

### [Manual data ingestion](#tab/manual-data-ingestion)

After the shortcut gets created, you can view the FOCUS cost data inside **Files**. You can load the data directly into a Fabric table by using the following steps.

1. In the lakehouse, find the directory that you created when you set up the export. The Directory is in the **Files** section.
2. Next to the directory, select the ellipsis (**...**), and then select **Load to Tables** > **New table**.  
   :::image type="content" source="./media/create-fabric-workspace-finops/load-to-tables-new-table.png" border="true" alt-text="Screenshot showing the New table option." lightbox="./media/create-fabric-workspace-finops/load-to-tables-new-table.png" :::
   1. Table name = &lt;_Any valid name_&gt;
   2. File type = `CSV`
   3. Including subfolders = **Enabled**
   4. Use header for column names = **Enabled**
   5. Separator = `,`
   6. Select **Load**

:::image type="content" source="./media/create-fabric-workspace-finops/load-folder-to-new-table.png" border="true" alt-text="Screenshot showing the new table options." lightbox="./media/create-fabric-workspace-finops/load-folder-to-new-table.png" :::

For more information, see [Lakehouse Load to Delta Lake tables](/fabric/data-engineering/load-to-tables).

This process creates a table based on the CSV/Parquet file. For an automated process to ingest data using notebooks, see the **Automate data ingestion** tab.

Here’s an example screenshot showing data in the Lakehouse table.

:::image type="content" source="./media/create-fabric-workspace-finops/fabric-load-table-lakehouse.png" border="true" alt-text="Screenshot showing data in the table." lightbox="./media/create-fabric-workspace-finops/fabric-load-table-lakehouse.png" :::

### [Automate data ingestion](#tab/automate-data-ingestion)

For detailed information about automating the process to ingest data into Fabric tables, see [How to use notebooks](/fabric/data-engineering/how-to-use-notebook).

Here are the high-level steps:

1. Open the lakehouse instance.
2. Select **Open notebook** > **New notebook**. New notebook might be hidden behind an ellipsis (...) menu overflow symbol.
3. Select **PySpark (Python)** notebook and paste the following example Python script.
4. Replace `read_path` with &lt;abs-folder-path&gt;. You can find the Azure Blob Filesystem driver (ABFS) path by navigating to the desired path. Select the ellipsis (**...**), and then select **Copy ABFS path** as shown in the following screenshot.  
   :::image type="content" source="./media/create-fabric-workspace-finops/fabric-lakehouse-copy-path-load-table.png" border="true" alt-text="Screenshot showing an example of copying ABFS path to load table." lightbox="./media/create-fabric-workspace-finops/fabric-lakehouse-copy-path-load-table.png" :::
5. Replace `export_table` with the name for the table that you want to create.
6. Running the script ingests the data into Fabric.
7. You can create a schedule to automate running the script that results in automating the data ingestion pipeline.
8. To create a daily automation schedule, select the gear symbol on the left menu and select the **Schedule** option.  
   :::image type="content" source="./media/create-fabric-workspace-finops/schedule-tab.png" border="true" alt-text="Screenshot showing the Schedule tab to automate data ingestion." lightbox="./media/create-fabric-workspace-finops/schedule-tab.png" :::

#### Example Python script

Use the following Python script in step 3 above to ingest data into Fabric tables.

```python
#!/usr/bin/env python
# coding: utf-8

# ## Sample Read CSV to Delta Output
#
# Exports Platform Demo Notebook

# # Export to Delta Parquet

# In[1]:
read_path = '<USER INPUT>' # input path to your data stream
export_table = '<USER INPUT>' # output path for your delta parquet table, ex: "Tables/CostDetails"

# In[3]:
df = spark.read.format("csv").option("header", "true").option("inferSchema", "true").option("recursiveFileLookup", "true").load(read_path)

''' Use this for parquet reading
df = spark.read.format("parquet").option("header", "true").option("inferSchema", "true").option("recursiveFileLookup", "true").load(read_path)
'''

# In[4]:
''' Use this if you want to overwrite the schema as well
df.write.mode("overwrite").format("delta").option("overwriteSchema", "true").save(export_table)
'''
df.write.mode("overwrite").format("delta").save(export_table)
```

---

<br>

## Create a Power BI report

After the data is ingested into Fabric and tables are ready, you can move on to reporting.

1. Sign in to the Fabric app using your [Fabric free account](https://www.microsoft.com/microsoft-fabric/getting-started) or [Microsoft Power BI](https://app.powerbi.com) account.
1. Select the workspace where you created the lakehouse and then select the lakehouse.
1. In the Explorer pane, select **Tables** and then select the table that you created.
1. At the top of the page, select **New semantic model** and name the model. For more information, see [Default Power BI semantic models](/fabric/data-warehouse/semantic-models#sync-the-default-power-bi-semantic-model).
1. Select the Power BI symbol at the bottom left.
1. Select the same semantic model to build reports and then use Copilot to generate insights from your ingested data.

> [!NOTE]
> The Power BI demo uses simulated cost data for illustration purposes.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Workspaces/featureName/Documentation.Create)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

<br>

## Related content

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)

<br>
