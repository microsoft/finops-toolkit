---
layout: default
parent: FinOps hubs
title: Template
nav_order: 3
description: "Details about what's included in the FinOps hub template."
permalink: /hubs/template
---

<span class="fs-9 d-block mb-4">FinOps hub template</span>
Behind the scenes peek at what makes up the FinOps hub template, including inputs and outputs.
{: .fs-6 .fw-300 }

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Learn more](️#-why-finops-hubs){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

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

1. You must have permission to create the [deployed resources](#️-resources).
2. The Microsoft.EventGrid resource provider must be registered in your subscription. See [Register a resource provider](https://docs.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) for details.

   <blockquote class="important" markdown="1">
     _If you forget this step, the deployment will succeed, but the pipeline trigger will not be started and data will not be ready. See [Troubleshooting Power BI reports](reports/README.md#-troubleshooting-power-bi-reports) for details._
   </blockquote>

<br>

## 📥 Parameters

| Parameter                      | Type   | Description                                                                                                                                                                       | Default value             |
| ------------------------------ | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **hubName**                    | String | Optional. Name of the hub. Used to ensure unique resource names.                                                                                                                  | `"finops-hub"`            |
| **location**                   | String | Optional. Azure location where all resources should be created. See https://aka.ms/azureregions.                                                                                  | (resource group location) |
| **storageSku**                 | String | Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: `Premium_LRS`, `Premium_ZRS`. | `Premium_LRS`             |
| **tags**                       | Object | Optional. Tags to apply to all resources. We will also add the `cm-resource-parent` tag for improved cost roll-ups in Cost Management.                                            |
| **exportScopes**               | Array  | Optional. List of scope IDs to create exports for.                                                                                                                                |
| **exportRetentionInDays**      | Int    | Optional. Number of days of cost data to retain in the ms-cm-exports container.                                                                                                   | 0                         |
| **ingestionRetentionInMonths** | Int    | Optional. Number of months of cost data to retain in the ingestion container.                                                                                                     | 13                        |

<br>

## 🎛️ Resources

The following resources are created in the target resource group during deployment.

Resources use the following naming convention: `<hubName>-<purpose>-<unique-suffix>`. Names are adjusted to account for length and character restrictions. The `<unique-suffix>` is used to ensure resource names are globally unique where required.

- `<hubName>store<unique-suffix>` storage account (Data Lake Storage Gen2)
  - Blob containers:
    - `msexports` – Temporarily stores Cost Management exports.
    - `ingestion` – Stores ingested data.
      > ℹ️ _In the future, we will use this container to stage external data outside of Cost Management._
    - `config` – Stores hub metadata and configuration settings. Files:
      - `schema_ea_normalized.json` – Configuration to map the EA schema to a normalized schema.
      - `schema_mca_normalized.json` – Configuration to map the MCA schema to a normalized schema.
      - `settings.json` – Hub settings.
- `<hubName>-engine-<unique-suffix>` Data Factory instance
  - Pipelines:
    - `msexports_backfill` – Triggers a series of monthly Cost Management exports (msexports_fill pipeline) to fill the dataset per the retention setting defined in settings.json
    - `msexports_fill` – Creates and triggers Cost Management exports (both actual and amortized) for the selected scope and date range.
    - `msexports_get` – Retrieves the list of configured Cost Management exports for scopes defined in settings.json and triggers them via the msexports_run pipeline.
    - `msexports_run` – Triggers Cost Management exports for the selected scope.
    - `msexports_setup` – Create or update exports in Cost Management for supported scopes defined in settings.json.
    - `msexport_extract` – Triggers the ingestion process for Cost Management exports to account for Data Factory pipeline trigger limits.
    - `msexports_transform` – Converts Cost Management exports into parquet or gzipped CSV and removes historical data duplicated in each day's exports.
  - Triggers:
    - `msexports_extract` – Triggers the `msexport_extract` pipeline when Cost Management exports complete.
    - `msexports_setup` – Triggers the `msexport_setup` pipeline when settings.json is updated.
    - `msexports_daily` – Scheduled trigger for activities which execute daily.
    - `msexports_monthly` – Scheduled trigger for activities which execute monthly.
- `<hubName>-vault-<unique-suffix>` Key Vault instance
  - Secrets:
    - Data Factory system managed identity

In addition to the above, the following resources are created to automate the deployment process. Each of these can be safely removed after deployment without impacting runtime functionality. Note they will be recreated if you redeploy the template.

- Managed identities:
  - `<storage>_config_blobManager` ([Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)) – Uploads the settings.json file.
  - `<datafactory>_triggerManager` ([Data Factory Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#data-factory-contributor)) – Stops triggers before deployment and starts them after deployment.
- Deployment scripts (automatically deleted after a successful deployment):
  - `<datafactory>_stopHubTriggers` – Stops all triggers in the hub using the triggerManager identity.
  - `<datafactory>_startHubTriggers` – Starts all triggers in the hub using the triggerManager identity.
  - `uploadSettings` – Uploads the settings.json file using the blobManager identity.

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

[Deploy](./README.md#-create-a-new-hub){: .btn .btn-primary .mt-2 .mb-4 .mb-md-0 .mr-4 }
[Learn more](./README.md#-why-finops-hubs){: .btn .mt-2 .mb-4 .mb-md-0 .mr-4 }

<br>
