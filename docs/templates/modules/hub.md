![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

# hub.bicep

This module deploys a **FinOps hub** instance into a resource group.

On this page:

- [Parameters](#parameters)
- [Resources](#resources)
- [Outputs](#outputs)

---

## Parameters

- **hubName** (string) – Name of the resource group and name prefix for all resources. Default: `"finops-hub"`.
- **location** (string) – Azure location where all resources should be created.

## Resources

- Storage account (Data Lake Storage v2) – Used for data storage.
  - **storageAccountName** = `param:hubName + "store"`
  - containers – Create the following nested containers:
    - **config** – Used for configuration settings. Include the following files within the template:
      - [metadata.json](#metadatajson)
    - **ms-cm-exports** – Used for Cost Management exports that have not been transformed.
- Data factory – Used for data ingestion and processing. Depends on: Storage account.
  - **dataFactoryName** = `param:hubName + "-engine"`
  - pipelines – Create the following nested pipelines:
    - **ms-cm-exports_RemoveOldFiles** – Removes all old files in the same directory when a new file is added to the ms-cm-exports container.

### metadata.json

The **metadata.json** file is used to identify the toolkit version.

```json
{
  "$schema": "https://aka.ms/finops/toolkit/metadata-schema",
  "type": "HubInstance",
  "version": "0.1",
  "learnMore": "https://aka.ms/finops/toolkit"
}
```

## Outputs

- **storageAccountId** (string) – Storage account resource ID that was created for the hub instance. This must be used when creating the Cost Management export.
- **pbix** (string) – URL for the Power BI file to use for this template.
