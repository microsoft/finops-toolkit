---
title: Initialize-FinOpsHubLocal command
description: Set up a local FinOps hub in a running Kusto emulator using the Initialize-FinOpsHubLocal command in the FinOpsToolkit module.
author: MSBrett
ms.author: brettwil
ms.date: 07/31/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps user, I want to set up a local FinOps hub with one command so I can explore my cost data without deploying Azure resources.
---

# Initialize-FinOpsHubLocal command

The **Initialize-FinOpsHubLocal** command sets up a local FinOps hub in a running [Kusto emulator](/azure/data-explorer/kusto-emulator-overview). It creates the `Ingestion` and `Hub` databases, then downloads and applies the released FinOps hub setup scripts and open data load script, so the local hub uses the same KQL, transforms, and open data as a deployed hub.

The command doesn't install Docker or manage the emulator container, and it doesn't ingest cost data. Start the emulator first, then run this command against its endpoint. For the full walkthrough, see [Run FinOps hubs locally](../../hubs/run-hubs-locally.md).

<br>

## Syntax

```powershell
Initialize-FinOpsHubLocal `
    [-ClusterUri <string>] `
    [-ReleaseUri <string>] `
    [-RawRetentionInDays <int>] `
    [-OpenDataPath <string>] `
    [-SkipOpenData] `
    [-Destination <string>] `
    [-WhatIf]
```

<br>

## Parameters

| Name                  | Description                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------- |
| `‑ClusterUri`         | Optional. Base URI of the running Kusto emulator. Default = `http://localhost:8082`.                             |
| `‑ReleaseUri`         | Optional. Base URI to download the setup scripts and open data load script from. Default = the latest FinOps toolkit GitHub release. Point this at a local file server or a specific release to run offline or pin a version. |
| `‑RawRetentionInDays` | Optional. Number of days to keep raw data in the `Ingestion` database. Default = `90`.                          |
| `‑OpenDataPath`       | Optional. Path, as seen by the emulator, to the folder that holds the open data CSV files. Default = `/data/export/open-data`. |
| `‑SkipOpenData`       | Optional. Skips loading the open data reference tables. Default = `false`.                                       |
| `‑Destination`        | Optional. Local folder used to download the setup scripts. Default = temp folder.                               |
| `‑WhatIf`             | Optional. Shows what would happen if the command runs without actually running it.                              |

<br>

## Examples

### Set up a local hub

```powershell
Initialize-FinOpsHubLocal
```

Sets up a local FinOps hub in the emulator at `http://localhost:8082` using the latest release.

### Set up the schema only

```powershell
Initialize-FinOpsHubLocal `
    -RawRetentionInDays 30 `
    -SkipOpenData
```

Creates the databases and applies the schema with 30-day raw retention, and skips loading open data.

<br>

## Related content

Related solutions:

- [Run FinOps hubs locally](../../hubs/run-hubs-locally.md)
- [FinOps hubs](../../hubs/finops-hubs-overview.md)

<br>
