---
QuickstartPath: quickstarts/microsoft.costmanagement/finops-hub
---

![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![#1](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

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

- **hubName** (string) – Name of the resource group and name prefix for all resources. Default: `"finops-hub"`.
- **location** (string) – Azure location where all resources should be created.

## Modules

- **[hub.bicep](../../modules/hub.md)** – Create the FinOps hub instance first to ensure the storage account is in place.
  - **hubName** = `param:hubName`
  - **location** = `param:location`

## Outputs

- **resourceGroup** (string) – Name of the resource group the hub was deployed to.
- **storageAccountId** (string) – Storage account resource ID that was created for the hub instance. This must be used when creating the Cost Management export.
- **pbix** (string) – URL for the Power BI file to use for this template.
