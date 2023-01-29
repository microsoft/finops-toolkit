![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

# hub.bicep

This module deploys a **FinOps hub** instance into a resource group.

On this page:

- [Resources](#resources)
- [Parameters](#parameters)
- [Outputs](#outputs)

---

## Resources

- Storage account (Data Lake Storage v2)
  - **ms-cm-exports** container to host exported data
- Data factory
  - **ms-cm-exports-ingestion** pipeline to clean up duplicated files

## Parameters

- **hubName** (string) – Name of the resource group and name prefix for all resources. Default: `"finops-hub"`.
- **location** (string) – Azure location where all resources should be created.

## Outputs

- **storageAccountId** (string) – Storage account resource ID that was created for the hub instance. This must be used when creating the Cost Management export.
- **pbix** (string) – URL for the Power BI file to use for this template.
