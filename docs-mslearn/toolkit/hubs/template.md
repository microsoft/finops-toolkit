---
title: FinOps hub template
description: Learn about what's included in the FinOps hub template including parameters, resources, and outputs.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand what FinOps hubs are so that I can use them in my organization.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps hub template

This document provides a detailed summary of what's included in the FinOps hubs deployment template. You can use this as a guide for tuning your deployment or to inform customizations you can make to the template to meet your organizational needs. This document explains the required prerequisites to deploy the template, input parameters you can customize, resources that will be deployed, and the template outputs. Template outputs can be used to connect to your hub instances in Power BI, Data Explorer, or other tools.

FinOps hubs includes many resources to offer a secure and scalable FinOps platform. The main resources you will interact with include:

- Data Explorer (Kusto) as a scalable datastore for advanced analytics (optional).
- Storage account (Data Lake Storage Gen2) as a staging area for data ingestion.
- Data Factory instance to manage data ingestion and cleanup.

> [!IMPORTANT]
> To use the template, you need to create Cost Management exports to publish data to the `msexports` container in the included storage account. For more information, see [Create a new hub](finops-hubs-overview.md#create-a-new-hub).

<br>

## Prerequisites

Ensure the following prerequisites are met before you deploy the template:

- You must have the following permissions to create the [deployed resources](#resources).

   | Resource                                             | Minimum Azure RBAC                                                                                                                                                                                                                                                                                                           |
   | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | Deploy and configure Data Factory¹                   | [Data Factory Contributor](/azure/role-based-access-control/built-in-roles#data-factory-contributor)                                                                                                                                                                                                                         |
   | Deploy Key Vault (remote hub only)¹                  | [Key Vault Contributor](/azure/role-based-access-control/built-in-roles#key-vault-contributor)                                                                                                                                                                                                                               |
   | Configure Key Vault secrets (remote hub only)¹       | [Key Vault Administrator](/azure/role-based-access-control/built-in-roles#key-vault-administrator)                                                                                                                                                                                                                           |
   | Create managed identity¹                             | [Managed Identity Contributor](/azure/role-based-access-control/built-in-roles#managed-identity-contributor)                                                                                                                                                                                                                 |
   | Deploy and configure storage¹                        | [Storage Account Contributor](/azure/role-based-access-control/built-in-roles#storage-account-contributor)                                                                                                                                                                                                                   |
   | Assign managed identity to resources¹                | [Managed Identity Operator](/azure/role-based-access-control/built-in-roles#managed-identity-operator)                                                                                                                                                                                                                       |
   | Create deployment scripts¹                           | Custom role containing only the `Microsoft.Resources/deploymentScripts/write` and `Microsoft.ContainerInstance/containerGroups/write` permissions as allowed actions or, alternatively, [Contributor](/azure/role-based-access-control/built-in-roles#contributor), which includes these permissions and all the above roles |
   | Assign permissions to managed identities¹            | [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) or, alternatively, [Owner](/azure/role-based-access-control/built-in-roles#owner), which includes this role and all the above roles                                                       |
   | Create a subscription or resource group cost export² | [Cost Management Contributor](/azure/role-based-access-control/built-in-roles#cost-management-contributor)                                                                                                                                                                                                                   |
   | Create an EA billing cost export²                    | Enterprise Reader, Department Reader, or Enrollment Account Owner ([Learn more](/azure/cost-management-billing/manage/understand-ea-roles))                                                                                                                                                                                  |
   | Create an MCA billing cost export²                   | [Contributor](/azure/cost-management-billing/manage/understand-mca-roles)                                                                                                                                                                                                                                                    |
   | Read blob data in storage³                           | [Storage Blob Data Contributor](/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)                                                                                                                                                                                                               |

   _¹ It's sufficient to assign hubs resources deployment permissions on the resource group scope._<br/>
   _² Cost Management permissions must be assigned on the scope where you want to export your costs from._<br/>
   _³ Blob data permissions are required to access exported cost data from Power BI or other client tools._<br/>

- You must have permissions to assign the following roles to managed identities as part of the deployment:

   | Azure RBAC role                                                                                                                              | Notes                                                                                                      |
   | -------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
   | [Data Factory Contributor](/azure/role-based-access-control/built-in-roles#data-factory-contributor)                                         | Assigned to the deployment trigger manager identity to auto-start Data Factory triggers.                   |
   | [Reader](/azure/role-based-access-control/built-in-roles#reader)                                                                             | Assigned to Data Factory to manage data in storage.                                                        |
   | [Storage Account Contributor](/azure/role-based-access-control/built-in-roles#storage-account-contributor)                                   | Assigned to Data Factory to manage data in storage.                                                        |
   | [Storage Blob Data Contributor](/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)                               | Assigned to Data Factory and Data Explorer to manage data in storage.                                      |
   | [Storage File Data Privileged Contributor](/azure/role-based-access-control/built-in-roles/storage#storage-file-data-privileged-contributor) | Assigned to the deployment file upload identity that uploads files to the config container.                |
   | [User Access Administrator](/azure/role-based-access-control/built-in-roles#user-access-administrator)                                       | Assigned to Data Factory to manage data in storage. Not applied when **enableManagedExports** is disabled. |

- The Microsoft.EventGrid resource provider must be registered in your subscription. For more information, see [Register a resource provider](/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider).

   > [!IMPORTANT]
   > If you forget this step, the deployment will succeed, but the pipeline trigger will not be started and data will not be ready. For more information, see [Troubleshooting Power BI reports](../help/troubleshooting.md).

<br>

## Parameters

Here are the parameters you can use to customize the deployment:

| Parameter                              | Type   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Default value      |
| -------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| **hubName**                            | String | Optional. Name of the hub. Used to ensure unique resource names.                                                                                                                                                                                                                                                                                                                                                                                                                                          | "finops-hub"       |
| **location**                           | String | Optional. Azure location where all resources should be created. See https://aka.ms/azureregions.                                                                                                                                                                                                                                                                                                                                                                                                          | Same as deployment |
| **storageSku**                         | String | Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: `Premium_LRS`, `Premium_ZRS`.                                                                                                                                                                                                                                                                                                                         | "Premium_LRS"      |
| **dataExplorerName**                   | String | Optional. Name of the Azure Data Explorer cluster to use for advanced analytics. If empty, Azure Data Explorer will not be deployed. Required to use with Power BI if you have more than $2-5M/mo in costs being monitored. Default: "" (do not use).                                                                                                                                                                                                                                                     |                    |
| **dataExplorerSkuName**                | String | Optional. Name of the Azure Data Explorer SKU. Default: "Dev(No SLA)_Standard_E2a_v4".                                                                                                                                                                                                                                                                                                                                                                                                                    |                    |
| **dataExplorerSkuTier**                | String | Optional. SKU tier for the Azure Data Explorer cluster. Use Basic for the lowest cost with no SLA (due to a single node). Use Standard for high availability and improved performance. Allowed values: Basic, Standard. Default: "Basic".                                                                                                                                                                                                                                                                 |                    |
| **dataExplorerSkuCapacity**            | Int    | Optional. Number of nodes to use in the cluster. Allowed values: 1 for the Basic SKU tier and 2-1000 for Standard. Default: 1.                                                                                                                                                                                                                                                                                                                                                                            |                    |
| **tags**                               | Object | Optional. Tags to apply to all resources. We will also add the `cm-resource-parent` tag for improved cost roll-ups in Cost Management.                                                                                                                                                                                                                                                                                                                                                                    |                    |
| **tagsByResource**                     | Object | Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.                                                                                                                                                                                                                                                                                                                                                                |                    |
| **scopesToMonitor**                    | Array  | Optional. List of scope IDs to monitor and ingest cost for.                                                                                                                                                                                                                                                                                                                                                                                                                                               |                    |
| **exportRetentionInDays**              | Int    | Optional. Number of days of data to retain in the msexports container.                                                                                                                                                                                                                                                                                                                                                                                                                                    | 0                  |
| **ingestionRetentionInMonths**         | Int    | Optional. Number of months of data to retain in the ingestion container.                                                                                                                                                                                                                                                                                                                                                                                                                                  | 13                 |
| **dataExplorerLogRetentionInDays**     | Int    | Optional. Number of days of data to retain in the Data Explorer \*_log tables.                                                                                                                                                                                                                                                                                                                                                                                                                            | 0                  |
| **dataExplorerFinalRetentionInMonths** | Int    | Optional. Number of months of data to retain in the Data Explorer \*_final_v\* tables.                                                                                                                                                                                                                                                                                                                                                                                                                    | 13                 |
| **remoteHubStorageUri**                | String | Optional. Storage account to push data to for ingestion into a remote hub.                                                                                                                                                                                                                                                                                                                                                                                                                                |                    |
| **remoteHubStorageKey**                | String | Optional. Storage account key to use when pushing data to a remote hub.                                                                                                                                                                                                                                                                                                                                                                                                                                   |                    |
| **enableManagedExports**               | Bool   | Optional. Enable managed exports where your FinOps hub instance will create and run Cost Management exports on your behalf. Not supported for Microsoft Customer Agreement (MCA) billing profiles. Requires the ability to grant User Access Administrator role to FinOps hubs, which is required to create Cost Management exports.                                                                                                                                                                      | True               |
| **enablePublicAccess**                 | Bool   | Optional. Disable public access to the data lake (storage firewall).                                                                                                                                                                                                                                                                                                                                                                                                                                      | True               |
| **virtualNetworkAddressPrefix**        | String | Optional. IP Address range for the private virtual network used by FinOps hubs. Accepts any subnet size from `/8` to `/26` with a minimum of `/26` required. `/26` is recommended to avoid wasting IPs unless you need additional address space for services like Power BI VNet Data Gateway. Internally, the following subnets will be created: `/28` for private endpoints, another `/28` subnet for temporary deployment scripts (container instances), and `/27` for Azure Data Explorer, if enabled. | '10.20.30.0/26'    |

<br>

## Resources

The following resources are created in the target resource group during deployment.

Resources use the following naming convention: `<hubName>-<purpose>-<unique-suffix>`. Names are adjusted to account for length and character restrictions. The `<unique-suffix>` is used to ensure resource names are globally unique where required.

- `<hubName>store<unique-suffix>` storage account (Data Lake Storage Gen2)
  - Blob containers:
    - `msexports` – Temporarily stores Cost Management exports.
    - `ingestion` – Stores ingested data.
    - `config` – Stores hub metadata and configuration settings. Files:
      - `settings.json` – Hub settings.
      - `schemas/focuscost_1.0.json` – FOCUS 1.0 schema definition for parquet conversion.
      - `schemas/focuscost_1.0-preview(v1).json` – FOCUS 1.0-preview schema definition for parquet conversion.
      - `schemas/pricesheet_2023-05-01_ea.json` – Price sheet EA schema definition version 2023-05-01 for parquet conversion.
      - `schemas/pricesheet_2023-05-01_mca.json` – Price sheet MCA schema definition version 2023-05-01 for parquet conversion.
      - `schemas/reservationdetails_2023-03-01.json` – Reservation details schema definition version 2023-03-01 for parquet conversion.
      - `schemas/reservationrecommendations_2023-05-01_ea.json` – Reservation recommendations EA schema definition version 2023-05-01 for parquet conversion.
      - `schemas/reservationrecommendations_2023-05-01_mca.json` – Reservation recommendations MCA schema definition version 2023-05-01 for parquet conversion.
      - `schemas/reservationtransactions_2023-05-01_ea.json` – Reservation transactions EA schema definition version 2023-05-01 for parquet conversion.
      - `schemas/reservationtransactions_2023-05-01_mca.json` – Reservation transactions MCA schema definition version 2023-05-01 for parquet conversion.
- `<hubName>script<unique-suffix>` storage account (Data Lake Storage Gen2) for deployment scripts.
- `<hubName>-engine-<unique-suffix>` Data Factory instance
  - Pipelines:
    - `config_InitializeHub` – Initializes (or updates) the FinOps hub instance after deployment.
    - `config_ConfigureExports` – Creates Cost Management exports for all scopes.
    - `config_StartBackfillProcess` – Runs the backfill job for each month based on retention settings.
    - `config_RunBackfillJob` – Creates and triggers exports for all defined scopes for the specified date range.
    - `config_StartExportProcess` – Gets a list of all Cost Management exports configured for this hub based on the scopes defined in settings.json, then runs each export using the config_RunExportJobs pipeline.
    - `config_RunExportJobs` – Runs the specified Cost Management exports.
    - `msexports_ExecuteETL` – Queues the `msexports_ETL_ingestion` pipeline to account for Data Factory pipeline trigger limits.
    - `msexports_ETL_ingestion` – Converts Cost Management exports into parquet and removes historical data duplicated in each day's export.
    - `ingestion_ExecuteETL` – Queues the `ingestion_ETL_dataExplorer` pipeline to account for Data Factory pipeline trigger limits.
    - `ingestion_ETL_dataExplorer` – Ingests parquet data into an Azure Data Explorer cluster.
  - Triggers:
    - `config_SettingsUpdated` – Triggers the `config_ConfigureExports` pipeline when settings.json is updated.
    - `config_DailySchedule` – Triggers the `config_RunExportJobs` pipeline daily for the current month's cost data.
    - `config_MonthlySchedule` – Triggers the `config_RunExportJobs` pipeline monthly for the previous month's cost data.
    - `msexports_ManifestAdded` – Triggers the `msexports_ExecuteETL` pipeline when Cost Management exports complete.
    - `ingestion_ManifestAdded` – Triggers the `ingestion_ExecuteETL` pipeline when manifest.json files are added (handled by the `msexports_ETL_ingestion` pipeline).
  - Managed Private Endpoints
    - `<hubName>store<unique-suffix>` - Managed private endpoint for storage account.
    - `<hubName>-vault-<unique-suffix>` - Managed private endpoint for Azure Key Vault.
- `<hubName>-vault-<unique-suffix>` Key Vault instance (only included when deployed as a remote hub)
  - Secrets:
    - Data Factory system managed identity
- `<dataExplorerName>` Data Explorer cluster
  - `Hub` database – Public-facing functions to abstract internals.
    - Includes 2 sets of functions:
      - Dataset-specific functions for the latest supported FOCUS version (for example, `Costs`, `Prices`).
      - Dataset-specific functions for each supported FOCUS version (for example, `Costs_v1_0` for FOCUS 1.0). These functions are provided for backwards compatibility. All functions return all data aligned to the targeted FOCUS version.
    - Datasets include: `Costs`, `Prices`.
    - Supported FOCUS versions include: `v1_0`.
  - `Ingestion` database – Stores ingested data.
    - Settings:
      - `HubSettingsLog` table – Stores a history of high-level configuration changes (for example, versions, scopes).
      - `HubSettings` function – Gets the latest version of the hub instance settings.
      - `HubScopes` function – Gets the currently configured scopes for this hub instance.
    - Open data:
      - `PricingUnits` table – [PricingUnits mapping file](../open-data.md#pricing-units) from the FinOps toolkit. Used for data normalization and cleanup.
      - `Regions` table – [Regions mapping file](../open-data.md#regions) from the FinOps toolkit. Used for data normalization and cleanup.
      - `ResourceTypes` table – [ResourceTypes mapping file](../open-data.md#resource-types) from the FinOps toolkit. Used for data normalization and cleanup.
      - `Services` table – [Services mapping file](../open-data.md#services) from the FinOps toolkit. Used for data normalization and cleanup.
      - `resource_type` function – Simple function to map internal resource type IDs to display names based on the [ResourceTypes mapping file](../open-data.md#resource-types).
        - Use this function to map a single values and join with the `ResourceTypes` table to update many rows or map other values.
    - Datasets:
      - `<dataset>_raw` table – Raw data directly from the ingestion source. Uses a union schema for data from multiple sources.
      - `<dataset>_transform_vX_Y` function – Normalizes and cleans raw data to align to the targeted FOCUS version using open data tables as needed.
      - `<dataset>_final_vX_Y` table – Clean version of the corresponding raw table aligned to the targeted FOCUS version. Populated via an update policy that uses the corresponding transform function when data is ingested into raw tables.

In addition to the preceding information, the following resources are created to automate the deployment process. The deployment scripts should be deleted automatically. However, don't delete the managed identities as it might cause errors when upgrading to the next release.

<!-- cSpell:ignore datafactory -->

- Managed identities:
  - `<storage>_blobManager` ([Storage Blob Data Contributor](/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)) – Uploads the settings.json file.
  - `<datafactory>_triggerManager` ([Data Factory Contributor](/azure/role-based-access-control/built-in-roles#data-factory-contributor)) – Stops triggers before deployment and starts them after deployment.
- Deployment scripts (automatically deleted after a successful deployment):
  - `<datafactory>_deleteOldResources` – Deletes unused resources from previous FinOps hubs deployments.
  - `<datafactory>_stopTriggers` – Stops all triggers in the hub using the triggerManager identity.
  - `<datafactory>_startTriggers` – Starts all triggers in the hub using the triggerManager identity.
  - `<storage>_uploadSettings` – Uploads the settings.json file using the blobManager identity.

<br>

## Outputs

Here are the outputs generated by the deployment:

| Output | Type | Description | Value |
| ------ | ---- | ----------- ||
| **name**                    | String | Name of the resource group.                                                                                                               |
| **location**                | String | Azure resource location resources were deployed to.                                                                                       |
| **dataFactoryName**        | String | Name of the Data Factory.                                                                                                                 |
| **storageAccountId**        | String | Resource ID of the deployed storage account.                                                                                              |
| **storageAccountName**      | String | Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data. |
| **storageUrlForPowerBI**    | String | URL to use when connecting custom Power BI reports to your data.                                                                          |
| **clusterId**               | String | Resource ID of the Data Explorer cluster.                                                                                                 |
| **clusterUri**              | String | URI of the Data Explorer cluster.                                                                                                         |
| **ingestionDbName**         | String | Name of the Data Explorer database used for ingesting data.                                                                               |
| **hubDbName**               | String | Name of the Data Explorer database used for querying data.                                                                                |
| **managedIdentityId**       | String | Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.                                     |
| **managedIdentityTenantId** | String | Azure AD tenant ID. This will be needed when configuring managed exports.                                                                 |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20hubs%3F/cvaQuestion/How%20valuable%20are%20FinOps%20hubs%3F/surveyId/FTK0.12/bladeName/Hubs/featureName/Template)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20hubs%22%20sort%3A"reactions-%2B1-desc")

<br>

## Related content

> [!div class="nextstepaction"]
> [Deploy FinOps hubs](finops-hubs-overview.md#create-a-new-hub)

[Learn more](finops-hubs-overview.md#why-finops-hubs)

<br>
