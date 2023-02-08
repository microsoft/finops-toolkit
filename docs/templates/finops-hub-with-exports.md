---
QuickstartPath: tenant-deployments/finops-hub-with-exports
---

# FinOps hub with exports template

![Status: Not started](https://img.shields.io/badge/status-not%20started-red) &nbsp;<sup>→</sup>&nbsp;
[![#1](https://img.shields.io/github/issues/detail/state/microsoft/cloud-hubs/1)](https://github.com/microsoft/cloud-hubs/issues/1)

This template creates a new **FinOps hub** instance and a Cost Management export to ingest cost details.

FinOps hubs include Data Lake storage to host the export and a Data Factory instance with a pipeline to clean up duplicated cost data after each export is processed.

On this page:

- [Parameters](#parameters)
- [Modules](#modules)
- [Outputs](#outputs)

---

## Parameters

- **subscription** (string) – ID of the subscription to deploy the hub instance to.
- **hubName** (string) – Name of the resource group and name prefix for all resources. Default: `"finops-hub"`.
- **dataFactoryName** (string) – Optional. Name of the data factory. Used to ensure unique resource names. Default: `"finops-hub-engine"`. Minimum Characters: `3`. Maximum Characters: `63`.
- **location** (string) – Azure location where all resources should be created.
- **exportScopes** (array) – Optional. List of scope IDs to create exports for.

<br>

## Modules

- **[hub.bicep](./modules/hub.md)** – Create the FinOps hub instance first to ensure the storage account is in place.
  - **hubName** = `param:hubName`
  - **dataFactoryName** = `param:dataFactoryName`
  - **location** = `param:location`
- **[export.bicep](./modules/export.md)** – Exports should be created as nested template deployments. Depends on: hub.bicep. Parameters:
  - **exportName** = `"FinOpsHubs_" + param:hubName + "_" + param:subscription`
    > _**NOTE:** The FinOpsHubs prefix is used as a standard to indicate the purpose of the export. The subscription ID enables exporting to multiple hub instances and act as a pointer to raise awareness of where exported data is being used._
  - **amortize** = `true`
  - **storageAccountId** = (use the `storageAccountId` output from hub.bicep)
  - **storageAccountContainer** = `ms-cm-exports`
    > _**NOTE:** Using this name as we think ahead to future releases where CM exports will need special processing before ingested into the data store._
  - **storageAccountPath** = (scope ID from `exportScopes` without the first "/")

<br>

## Outputs

- **name** (string) – Name of the deployed hub instance.
- **resourceGroupId** (string) – Resource ID of the resource group resources were deployed to.
- **location** (string) – Azure resource location resources were deployed to.
- **storageAccountId** (string) – Resource ID of the storage account created for the hub instance. This must be used when creating the Cost Management export.

<br>
