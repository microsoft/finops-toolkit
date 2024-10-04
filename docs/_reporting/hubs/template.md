---
layout: default
parent: FinOps hubs
title: Template
nav_order: 10
description: "Details about what's included in the FinOps hub template."
permalink: /hubs/template
---

<span class="fs-9 d-block mb-4">FinOps hub template</span>
Behind the scenes peek at what makes up the FinOps hub template, including inputs and outputs.
{: .fs-6 .fw-300 }

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Prerequisites](#-prerequisites){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
  <summary class="fs-2 text-uppercase">On this page</summary>

- [📋 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🎛️ Resources](#️-resources)
- [📤 Outputs](#-outputs)
- [⏭️ Next steps](#️-next-steps)

</details>

---

This template creates a new **FinOps hub** instance.

FinOps hubs include:

- Data Lake storage to host cost data.
- Data Factory for data processing and orchestration.
- Key Vault for storing secrets.

<blockquote class="important" markdown="1">
  _To use this template, you will need to create a Cost Management export that publishes cost data to the `msexports` container in the included storage account. See [Create a new hub](README.md#-create-a-new-hub) for details._
</blockquote>

<br>

## 📋 Prerequisites

Please ensure the following prerequisites are met before deploying this template:

1. You must have the following permissions to create the [deployed resources](#️-resources).

   | Resource                                                        | Minimum RBAC                                                                                                                                                                                                                                                                                                                                            |
   | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | Deploy and configure Data Factory<sup>1</sup>                   | [Data Factory Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor)                                                                                                                                                                                                                         |
   | Deploy Key Vault<sup>1</sup>                                    | [Key Vault Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-contributor)                                                                                                                                                                                                                               |
   | Configure Key Vault secrets<sup>1</sup>                         | [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)                                                                                                                                                                                                                           |
   | Create managed identity<sup>1</sup>                             | [Managed Identity Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-contributor)                                                                                                                                                                                                                 |
   | Deploy and configure storage<sup>1</sup>                        | [Storage Account Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor)                                                                                                                                                                                                                   |
   | Assign managed identity to resources<sup>1</sup>                | [Managed Identity Operator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#managed-identity-operator)                                                                                                                                                                                                                       |
   | Create deployment scripts<sup>1</sup>                           | Custom role containing only the `Microsoft.Resources/deploymentScripts/write` and `Microsoft.ContainerInstance/containerGroups/write` permissions as allowed actions or, alternatively, [Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor), which includes these permissions and all the above roles |
   | Assign permissions to managed identities<sup>1</sup>            | [Role Based Access Control Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator) or, alternatively, [Owner](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#owner), which includes this and all the above roles                                 |
   | Create a subscription or resource group cost export<sup>2</sup> | [Cost Management Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#cost-management-contributor)                                                                                                                                                                                                                   |
   | Create an EA billing cost export<sup>2</sup>                    | Enterprise Reader, Department Reader, or Enrollment Account Owner ([Learn more](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-ea-roles))                                                                                                                                                                                  |
   | Create an MCA billing cost export<sup>2</sup>                   | [Contributor](https://learn.microsoft.com/azure/cost-management-billing/manage/understand-mca-roles)                                                                                                                                                                                                                                                    |
   | Read blob data in storage<sup>3</sup>                           | [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)                                                                                                                                                                                                               |

   <!--
   | Optional: Deploy temporary Event Grid namespace                 | [Event Grid Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#event-grid-contributor)                                                                                                                                                                                                                             |
   -->

   _<sup>1. It is sufficient to assign hubs resources deployment permissions on the resource group scope.</sup>_<br/>
   _<sup>2. Cost Management permissions must be assigned on the scope where you want to export your costs from.</sup>_<br/>
   _<sup>3. Blob data permissions are required to access exported cost data from Power BI or other client tools.</sup>_<br/>

2. The Microsoft.EventGrid resource provider must be registered in your subscription. See [Register a resource provider](https://docs.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) for details.

   <blockquote class="important" markdown="1">
     _If you forget this step, the deployment will succeed, but the pipeline trigger will not be started and data will not be ready. See [Troubleshooting Power BI reports](../../_resources/troubleshooting.md) for details._
   </blockquote>

<br>

## 📥 Parameters

| Parameter                      | Type   | Description                                                                                                                                                                                                                                                       | Default value       |
| ------------------------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| **hubName**                    | string | Optional. Name of the hub. Used to ensure unique resource names.                                                                                                                                                                                                  | "finops-hub"        |
| **location**                   | string | Optional. Azure location where all resources should be created. See https://aka.ms/azureregions.                                                                                                                                                                  | Same as deployment  |
| **skipEventGridRegistration**  | bool   | Indicates whether the Event Grid resource provider has already been registered (e.g., in a previous hub deployment). Event Grid RP registration is required. If not set, a temporary Event Grid namespace will be created to auto-register the resource provider. | false (register RP) |
| **EventGridLocation**          | string | Optional. Azure location to use for a temporary Event Grid namespace to register the Microsoft.EventGrid resource provider if the primary location is not supported. The namespace will be deleted and is not used for hub operation.                             | Same as `location`  |
| **storageSku**                 | String | Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: `Premium_LRS`, `Premium_ZRS`.                                                                                 | "Premium_LRS"       |
| **tags**                       | object | Optional. Tags to apply to all resources. We will also add the `cm-resource-parent` tag for improved cost roll-ups in Cost Management.                                                                                                                            |                     |
| **tagsByResource**             | object | Optional. Tags to apply to resources based on their resource type. Resource type specific tags will be merged with tags for all resources.                                                                                                                        |                     |
| **scopesToMonitor**            | array  | Optional. List of scope IDs to monitor and ingest cost for.                                                                                                                                                                                                       |                     |
| **exportRetentionInDays**      | int    | Optional. Number of days of cost data to retain in the ms-cm-exports container.                                                                                                                                                                                   | 0                   |
| **ingestionRetentionInMonths** | int    | Optional. Number of months of cost data to retain in the ingestion container.                                                                                                                                                                                     | 13                  |
| **remoteHubStorageUri**        | string | Optional. Storage account to push data to for ingestion into a remote hub.                                                                                                                                                                                        |                     |
| **remoteHubStorageKey**        | string | Optional. Storage account key to use when pushing data to a remote hub.                                                                                                                                                                                           |                     |

<br>

## 🎛️ Resources

The following resources are created in the target resource group during deployment.

Resources use the following naming convention: `<hubName>-<purpose>-<unique-suffix>`. Names are adjusted to account for length and character restrictions. The `<unique-suffix>` is used to ensure resource names are globally unique where required.

- `<hubName>store<unique-suffix>` storage account (Data Lake Storage Gen2)
  - Blob containers:
    - `msexports` – Temporarily stores Cost Management exports.
    - `ingestion` – Stores ingested data.
      <blockquote class="note" markdown="1">
        _In the future, we will use this container to stage external data outside of Cost Management._
      </blockquote>
    - `config` – Stores hub metadata and configuration settings. Files:
      - `settings.json` – Hub settings.
      - `schemas/focuscost_1.0.json` – FOCUS 1.0 schema definition for parquet conversion.
      - `schemas/focuscost_1.0-preview(v1).json` – FOCUS 1.0-preview schema definition for parquet conversion.
- `<hubName>-engine-<unique-suffix>` Data Factory instance
  - Pipelines:
    - `msexports_ExecuteETL` – Queues the `msexports_ETL_ingestion` pipeline to account for Data Factory pipeline trigger limits.
    - `msexports_ETL_transform` – Converts Cost Management exports into parquet and removes historical data duplicated in each day's export.
    - `config_ConfigureExports` – Creates Cost Management exports for all scopes.
    - `config_StartBackfillProcess` – Runs the backfill job for each month based on retention settings.
    - `config_RunBackfillJob` – Creates and triggers exports for all defined scopes for the specified date range.
    - `config_StartExportProcess` – Gets a list of all Cost Management exports configured for this hub based on the scopes defined in settings.json, then runs each export using the config_RunExportJobs pipeline.
    - `config_RunExportJobs` – Runs the specified Cost Management exports.
    - `msexports_ExecuteETL` – Triggers the ingestion process for Cost Management exports to account for Data Factory pipeline trigger limits.
    - `msexports_ETL_transform` – Converts Cost Management exports into parquet and removes historical data duplicated in each day's export.
  - Triggers:
    - `config_SettingsUpdated` – Triggers the `config_ConfigureExports` pipeline when settings.json is updated.
    - `config_DailySchedule` – Triggers the `config_RunExportJobs` pipeline daily for the current month's cost data.
    - `config_MonthlySchedule` – Triggers the `config_RunExportJobs` pipeline monthly for the previous month's cost data.
    - `msexports_FileAdded` – Triggers the `msexports_ExecuteETL` pipeline when Cost Management exports complete.
- `<hubName>-vault-<unique-suffix>` Key Vault instance
  - Secrets:
    - Data Factory system managed identity

In addition to the above, the following resources are created to automate the deployment process. The deployment scripts should be deleted automatically but please do not delete the managed identities as this may cause errors when upgrading to the next release.

- Managed identities:
  - `<storage>_blobManager` ([Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)) – Uploads the settings.json file.
  - `<datafactory>_triggerManager` ([Data Factory Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor)) – Stops triggers before deployment and starts them after deployment.
- Deployment scripts (automatically deleted after a successful deployment):
  - `<datafactory>_deleteOldResources` – Deletes unused resources from previous FinOps hubs deployments.
  - `<datafactory>_stopTriggers` – Stops all triggers in the hub using the triggerManager identity.
  - `<datafactory>_startTriggers` – Starts all triggers in the hub using the triggerManager identity.
  - `<storage>_uploadSettings` – Uploads the settings.json file using the blobManager identity.

<br>

## 📤 Outputs

| Output                      | Type   | Description                                                                                                                               |
| --------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **name**                    | String | Name of the deployed hub instance.                                                                                                        |
| **location**                | String | Azure resource location resources were deployed to.                                                                                       | `location`                                                                                                      |
| **dataFactorytName**        | String | Name of the Data Factory.                                                                                                                 | `dataFactory.name`                                                                                              |
| **storageAccountId**        | String | Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.              | `storage.outputs.resourceId`                                                                                    |
| **storageAccountName**      | String | Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data. | `storage.outputs.name`                                                                                          |
| **storageUrlForPowerBI**    | String | URL to use when connecting custom Power BI reports to your data.                                                                          | `'https://${storage.outputs.name}.dfs.${environment().suffixes.storage}/${storage.outputs.ingestionContainer}'` |
| **managedIdentityId**       | String | Object ID of the Data Factory managed identity. This will be needed when configuring managed exports.                                     | `dataFactory.identity.principalId`                                                                              |
| **managedIdentityTenantId** | String | Azure AD tenant ID. This will be needed when configuring managed exports.                                                                 | `tenant().tenantId`                                                                                             |

---

## ⏭️ Next steps

<br>

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Learn more](./README.md#-why-finops-hubs){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
