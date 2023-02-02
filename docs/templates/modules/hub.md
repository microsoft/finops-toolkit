![Status: Not started](https://img.shields.io/badge/status-in%20progress-blue) &nbsp;<sup>→</sup>&nbsp;
[![Go to issue](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)
[![#21](https://img.shields.io/github/pulls/detail/state/microsoft/cloud-hubs/21)](https://github.com/microsoft/cloud-hubs/pulls/21)

# hub.bicep

This module deploys a **FinOps hub** instance into a resource group.

On this page:

- [Parameters](#parameters)
- [Resources](#resources)
- [Outputs](#outputs)

---

## Parameters

- **hubName** (string) – Optional. Name of the hub. Used to ensure unique resource names. Default: `"finops-hub"`.
- **location** (string) – Optional. Azure location where all resources should be created. See https://aka.ms/azureregions. Default: (resource group location).
- **storageSku** (string) – Optional. Storage SKU to use. LRS = Lowest cost, ZRS = High availability. Note Standard SKUs are not available for Data Lake gen2 storage. Allowed: `Premium_LRS`, `Premium_ZRS`. Default: `Premium_LRS`.
- **tags** (object) – Optional. Tags to apply to all resources. We will also add the `cm-resource-parent` tag for improved cost roll-ups in Cost Management.

## Resources

- Storage account (Data Lake Storage v2) – Used for data storage.
  - **name** = `param:hubName + "store"`
  - **sku** = `param:storageSku`
  - **tags** = `param:tags`
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

- **name** (string) – Name of the deployed hub instance.
- **location** (string) – Azure resource location resources were deployed to.
- **storageAccountId** (string) – Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.
