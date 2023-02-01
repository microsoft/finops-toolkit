---
QuickstartPath: quickstarts/microsoft.costmanagement/finops-hub
---

![Status: In progress](https://img.shields.io/badge/status-in%20progress-blue) &nbsp;<sup>→</sup>&nbsp;
[![#1](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)
[![#21](https://img.shields.io/github/pulls/detail/state/microsoft/cloud-hubs/21)](https://github.com/microsoft/cloud-hubs/pulls/21)

# FinOps hub template

This template creates a new **FinOps hub** instance.

FinOps hubs include Data Lake storage to host the export and a Data Factory instance with a pipeline to clean up duplicated cost data after each export is processed.

> **Important:** This template does not include a Cost Management export. In order to ingest cost details, a Cost Management export must be created and configured to push data to the included storage account and into the `ms-cm-exports` container.

On this page:

- [Parameters](#parameters)
- [Modules](#modules)
- [Outputs](#outputs)

---

## Parameters

- **hubName** (string) – Optional. Name of the resource group and name prefix for all resources. Default: `"finops-hub"`.
- **location** (string) – Optional. Azure location where all resources should be created. Default: (resource group location).
- **storageSku** (string) – Optional. Storage SKU to use. Allowed: `Premium_LRS`, `Premium_ZRS`. Default: `Premium_LRS`.
- **tags** (object) – Optional. Tags to apply to all resources. Default: `cm-resource-parent: <rg-scope>/providers/Microsoft.Cloud/hubs/<params:hubName>` (merged with user-defined tags).

## Modules

- **[hub.bicep](./modules/hub.md)** – Create the FinOps hub instance first to ensure the storage account is in place.
  - **hubName** = `param:hubName`
  - **location** = `param:location`
  - **storageSku** = `param:storageSku`
  - **tags** = `param:tags`

## Outputs

- **name** (string) – Name of the deployed hub instance.
- **location** (string) – Azure resource location resources were deployed to.
- **storageAccountId** (string) – Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.
- **primaryBlobEndpoint** (string) – Primary blob endpoint reference for the storage account.
- **pbix** (string) – URL for the Power BI file to use for this template.
