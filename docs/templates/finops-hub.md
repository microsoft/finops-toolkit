---
QuickstartPath: quickstarts/microsoft.costmanagement/finops-hub
---

# FinOps hub template

![Status: In progress](https://img.shields.io/badge/status-in%20progress-blue) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)
[![Go to PR](https://img.shields.io/github/pulls/detail/state/microsoft/cloud-hubs/21)](https://github.com/microsoft/cloud-hubs/pulls/21)
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/23)](https://github.com/microsoft/cloud-hubs/issues/23)

This template creates a new **FinOps hub** instance.

FinOps hubs include Data Lake storage to host the export and a Data Factory instance with a pipeline to clean up duplicated cost data after each export is processed.

> **Important:** This template does not include a Cost Management export. In order to ingest cost details, a Cost Management export must be created and configured to push data to the included storage account and into the `ms-cm-exports` container.

On this page:

- [Parameters](#parameters)
- [Modules](#modules)
- [Outputs](#outputs)

---

## Parameters

- **hubName** (string) – Optional. Name of the hub. Used to ensure unique resource names. Default: `"finops-hub"`.
- **location** (string) – Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).
- **storageSku** (string) – Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: `Premium_LRS`, `Premium_ZRS`. Default: `Premium_LRS`.
- **tags** (object) – Optional. Tags to apply to all resources. We will also add the `cm-resource-parent` tag for improved cost roll-ups in Cost Management.

<br>

## Modules

- **[hub.bicep](./modules/hub.md)** – Create the FinOps hub instance first to ensure the storage account is in place.
  - **hubName** = `param:hubName`
  - **location** = `param:location`
  - **storageSku** = `param:storageSku`
  - **tags** = `param:tags`

<br>

## Outputs

- **name** (string) – Name of the deployed hub instance.
- **location** (string) – Azure resource location resources were deployed to.
- **storageAccountId** (string) – Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.
- **storageAccountName** (string) – Name of the storage account created for the hub instance. This must be used when connecting FinOps toolkit Power BI reports to your data.
- **storageUrlForPowerBI** (string) – URL to use when connecting custom Power BI reports to your data.

<br>
