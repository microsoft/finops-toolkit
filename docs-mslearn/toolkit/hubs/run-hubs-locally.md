---
title: Run FinOps hubs locally
description: Stand up a FinOps hub on your own hardware in a local container and ingest cost data, using the same KQL and open data as a deployed hub.
author: MSBrett
ms.author: brettwil
ms.date: 08/13/2026
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: brettwil
#customer intent: As a FinOps user, I want to run a FinOps hub locally so I can explore my cost data without deploying Azure resources.
---

<!-- markdownlint-disable MD033 -->

# Run FinOps hubs locally

This article shows how to run a FinOps hub on your own hardware using the [Kusto emulator](/azure/data-explorer/kusto-emulator-overview), a free local container. It uses the same analytics KQL, transforms, and open data as a deployed [FinOps hub](finops-hubs-overview.md) — only the host changes from Azure Data Explorer to a local container. Run the PowerShell blocks below in order; each is a step you (or an agent) can run one after another.

A local hub is useful when you need full hub analysis without managed daily refresh: exploring the data model, validating large customer datasets, supporting consulting deliveries, or working from on-premises, other-cloud, or disconnected environments where you can bring exported data to the machine. It isn't a replacement for a deployed hub — there's no scheduled ingestion, networking, security, or sharing.

<br>

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/), to run the Kusto emulator container, with at least 16 GB of memory available to the container. Start Docker before you run the commands and verify `docker info` works in the same PowerShell session.
- [PowerShell 7](/powershell/scripting/install/installing-powershell) — every command in this article is PowerShell.
- [Azure PowerShell](/powershell/azure/install-azure-powershell) (the `Az` modules), only needed to download cost data from an Azure storage account. Sign in first with `Connect-AzAccount` and select the subscription that holds your cost data — this article never runs a sign-in command. With `-UseConnectedAccount`, your identity also needs storage data-plane access, such as **Storage Blob Data Reader**, on the account or container.
- FOCUS cost exports as Parquet, available on the local machine. The emulator reads cost data from a local folder, so the files must be on disk — but you can download them from a [FinOps hub storage account](configure-scopes.md) or [Cost Management exports](/cost-management-billing/costs/tutorial-improved-exports) (shown below), or copy them from any other source into the same folder structure.

For background on the emulator and its platform requirements, see the [Kusto emulator overview](/azure/data-explorer/kusto-emulator-overview) and [installation guide](/azure/data-explorer/kusto-emulator-install).

<br>

## Start the emulator

Create a working folder outside the repository, then start the emulator. Two folders are mounted into the container: exports (read-only at `/data/export`) and a data folder where the engine persists its databases. Mounting the data folder means your databases survive container restarts and removals. For other ways to run the container, see [Install the Kusto emulator](/azure/data-explorer/kusto-emulator-install).

```powershell
$exportPath = '../exports/local-hub'
$dataPath   = '../exports/local-hub-data'

New-Item -ItemType Directory -Force -Path $exportPath | Out-Null
New-Item -ItemType Directory -Force -Path $dataPath   | Out-Null
docker run -d --name finops-hub-local --platform linux/amd64 `
  -p 8082:8080 -m 16g -e ACCEPT_EULA=Y `
  -v "$((Resolve-Path $exportPath).Path):/data/export:ro" `
  -v "$((Resolve-Path $dataPath).Path):/kustodata" `
  mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest
```

To restart after stopping the container, run `docker start finops-hub-local`. Your databases reload automatically from the data folder — no need to repeat the setup steps.

All later steps talk to the emulator's HTTP endpoint, so define a small helper to send a command. Management commands (those starting with `.`) go to `/v1/rest/mgmt`; queries go to `/v1/rest/query`. The endpoint has no authentication.

```powershell
$hub = 'http://localhost:8082/v1/rest'
function Invoke-Kusto {
  param([string]$Database, [string]$Command, [ValidateSet('mgmt','query')][string]$Endpoint = 'mgmt')
  Invoke-RestMethod -Uri "$hub/$Endpoint" -Method Post -ContentType 'application/json' `
    -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
}
```

Wait for the engine to answer before continuing:

```powershell
do {
  Start-Sleep -Seconds 3
  $ready = try { Invoke-Kusto NetDefaultDB '.show version'; $true } catch { Write-Host 'waiting for emulator...'; $false }
} until ($ready)
Write-Host 'emulator ready'
```

<br>

## Set up the hub

Set up the databases, schema, and open data in one step with the [FinOps toolkit PowerShell module](../powershell/powershell-commands.md), or follow the next three sections to do it by hand. Both run the same released scripts and produce the same result.

To use the module, stage the open data CSVs in the mounted folder first (the emulator reads them from there), then run one command:

```powershell
New-Item -ItemType Directory -Force -Path "$exportPath/open-data" | Out-Null
foreach ($f in 'PricingUnits', 'Regions', 'ResourceTypes', 'Services') {
  Invoke-WebRequest "https://github.com/microsoft/finops-toolkit/releases/latest/download/$f.csv" -OutFile "$exportPath/open-data/$f.csv"
}

Install-Module -Name FinOpsToolkit -Scope CurrentUser
Initialize-FinOpsHubLocal -ClusterUri 'http://localhost:8082' -RawRetentionInDays 90
```

`Initialize-FinOpsHubLocal` creates the `Ingestion` and `Hub` databases, applies the released setup scripts, and loads open data from `/data/export/open-data`. It doesn't manage the container or ingest cost data — start the emulator first and ingest your exports later. Add `-SkipOpenData` to skip open data. When it finishes, skip ahead to [Download your cost data](#download-your-cost-data).

To set everything up by hand instead, continue with the steps below.

<br>

## Create the two databases

A FinOps hub uses two databases: `Ingestion` for raw and transformed data, and `Hub` for the view functions you query.

```powershell
foreach ($db in 'Ingestion', 'Hub') {
  Invoke-Kusto NetDefaultDB ".create-merge database $db persist (@`"/kustodata/dbs/$db/md`", @`"/kustodata/dbs/$db/data`")" | Out-Null
}
```

<br>

## Load the schema

Download the hub's setup scripts from the latest toolkit release and load each into its database. These are the same `finops-hub-fabric-setup-*.kql` files used to set up a [Microsoft Fabric hub](deploy.md#optional-set-up-microsoft-fabric) — each is a single `.execute database script` that creates every table, mapping, transform function, and update policy.

The Ingestion script has one placeholder, `$$rawRetentionInDays$$` (how long to keep raw data). Replace it with a number of days before loading.

```powershell
$release = 'https://github.com/microsoft/finops-toolkit/releases/latest/download'
New-Item -ItemType Directory -Force -Path "$exportPath/setup" | Out-Null
Invoke-WebRequest "$release/finops-hub-fabric-setup-Ingestion.kql" -OutFile "$exportPath/setup/setup-Ingestion.kql"
Invoke-WebRequest "$release/finops-hub-fabric-setup-Hub.kql"        -OutFile "$exportPath/setup/setup-Hub.kql"

# Ingestion: raw tables, transforms, final tables, update policies
$ingestion = (Get-Content "$exportPath/setup/setup-Ingestion.kql" -Raw) -replace '\$\$rawRetentionInDays\$\$', '90'
Invoke-Kusto Ingestion $ingestion

# Hub: the Costs/Prices/Transactions view functions
Invoke-Kusto Hub (Get-Content "$exportPath/setup/setup-Hub.kql" -Raw)
```

Each response is a table with one row per statement. The Hub functions reference `database('Ingestion').*`, which resolves because both databases exist.

<br>

## Load the open data

FinOps hubs enrich cost data with open-data reference tables (regions, services, resource types, and pricing units). Download the reference CSVs and the matching load script from the toolkit release, then run the script. The load script (`finops-hub-local-opendata.kql`) is generated by the toolkit build from the same open data a deployed hub uses, so its schema always matches the published CSVs.

The emulator's first external-data read right after setup sometimes returns no rows without raising an error, so load the open data, check the tables filled, and retry if they didn't:

```powershell
New-Item -ItemType Directory -Force -Path "$exportPath/open-data" | Out-Null
foreach ($f in 'PricingUnits', 'Regions', 'ResourceTypes', 'Services') {
  Invoke-WebRequest "$release/$f.csv" -OutFile "$exportPath/open-data/$f.csv"
}
Invoke-WebRequest "$release/finops-hub-local-opendata.kql" -OutFile "$exportPath/setup/load-open-data.kql"

# Point the load script at the mounted open-data folder.
$openData = (Get-Content "$exportPath/setup/load-open-data.kql" -Raw) -replace '\$\$openDataPath\$\$', '/data/export/open-data'

# Load, verify the tables filled, and retry if the first read came back empty.
foreach ($attempt in 1..5) {
  Invoke-Kusto Ingestion $openData | Out-Null
  $empty = 'PricingUnits', 'Regions', 'ResourceTypes', 'Services' | Where-Object {
    (Invoke-Kusto Ingestion "$_ | count" -Endpoint query).Tables[0].Rows[0][0] -eq 0
  }
  if (-not $empty) { Write-Host 'open data loaded'; break }
  if ($attempt -eq 5) { throw "Open data tables still empty: $($empty -join ', ')" }
  Start-Sleep -Seconds 2
}
```

<br>

## Download your cost data

Download FOCUS cost and price exports from your storage account into the export folder, using your existing Azure sign-in. This works against either the **msexports** or **ingestion** container of a FinOps hub, or any container holding Cost Management exports. Only the data files (`manifest.json` and `*.parquet`) are downloaded.

Set these to match your storage account, then run the download:

> [!NOTE]
> This download step is specific to Azure Storage. The local hub uses the same FOCUS transforms as a deployed hub, which are aligned to [FOCUS](../../focus/what-is-focus.md) and validated against Microsoft Cost Management cost data. If your FOCUS exports already live elsewhere, copy each dataset's `manifest.json` and `*.parquet` files into `$exportPath` and skip to [Ingest the data](#ingest-the-data).

```powershell
$account   = '<your-storage-account>'
$container = 'ingestion'   # or: msexports
$prefix    = ''            # optional, e.g. 'billingAccounts/00000000' for msexports

$ctx = New-AzStorageContext -StorageAccountName $account -UseConnectedAccount
Get-AzStorageBlob -Container $container -Context $ctx -Prefix $prefix |
  Where-Object { $_.Name -match '(manifest\.json|\.parquet)$' } |
  ForEach-Object {
    Get-AzStorageBlobContent -Container $container -Context $ctx -Blob $_.Name `
      -Destination $exportPath -Force | Out-Null
  }
```

> [!NOTE]
> FinOps hub storage accounts use a hierarchical namespace, where each folder is also a zero-byte marker blob. Downloading only `manifest.json` and `*.parquet` skips those markers, which otherwise collide with same-named folders on disk. `-UseConnectedAccount` reuses your existing Azure sign-in.

<br>

## Ingest the data

Ingest each Parquet file into the matching raw table. As rows land, the update policy created by the schema runs the FOCUS transform automatically and appends the result to the final table — the same mechanism a deployed hub uses. Cost exports go to `Costs_raw`; price sheets go to `Prices_raw`.

For large exports, use a small amount of parallelism. Start with about one ingestion thread per 8 GB of emulator memory. For the 16 GB container below, use two threads; if you increase the container to 32 GB, four threads is a good starting point.

Ingest price sheets before cost data. The cost transform enriches rows with missing prices from `Prices_final_v1_2`, and the update policy runs as each file lands, so any prices must already be in place when costs are ingested.

```powershell
$ingestConcurrency = 2

# Group exports by manifest type, then ingest each dataset's Parquet files
$ingestJobs = Get-ChildItem $exportPath -Recurse -Filter manifest.json | ForEach-Object {
  # Default to FocusCost; treat as PriceSheet only when the manifest type or path says so.
  $manifest = Get-Content $_.FullName -Raw
  $isPrice  = $manifest -match '"type"\s*:\s*"PriceSheet"' -or $_.FullName -match '(?i)price'
  $target   = if ($isPrice) { 'Prices_raw', 'Prices_raw_mapping' } else { 'Costs_raw', 'Costs_raw_mapping' }
  Get-ChildItem $_.Directory -Filter *.parquet | ForEach-Object {
    [PSCustomObject]@{
      Table   = $target[0]
      Mapping = $target[1]
      File    = $_.FullName
      # Prices first (0) then costs (1): the cost transform enriches from Prices_final_v1_2.
      Phase   = if ($isPrice) { 0 } else { 1 }
    }
  }
}

# Ingest prices, then costs. Each phase finishes before the next starts.
foreach ($phase in $ingestJobs | Group-Object Phase | Sort-Object Name) {
  $phase.Group | ForEach-Object -Parallel {
    $hub = $using:hub
    $exportPath = $using:exportPath
    function Invoke-Kusto {
      param([string]$Database, [string]$Command, [ValidateSet('mgmt','query')][string]$Endpoint = 'mgmt')
      Invoke-RestMethod -Uri "$hub/$Endpoint" -Method Post -ContentType 'application/json' `
        -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
    }
    function Invoke-Ingest {
      param([string]$Table, [string]$Mapping, [string]$File)
      $rel  = [IO.Path]::GetRelativePath((Resolve-Path $exportPath), $File) -replace '\\', '/'
      $path = "/data/export/$rel"
      Invoke-Kusto Ingestion ".ingest into table $Table (h@'$path') with (format='parquet', ingestionMappingReference='$Mapping')" | Out-Null
      Write-Host "  ingested $(Split-Path $File -Leaf)"
    }
    Invoke-Ingest $_.Table $_.Mapping $_.File
  } -ThrottleLimit $ingestConcurrency
}
```

If the emulator exits with code 137, it ran out of memory. Reduce `$ingestConcurrency`, increase the container memory, or ingest one month at a time and restart the emulator between batches. For very large imports, keep a per-file log so you can retry failed files without restarting the entire load.

Confirm the data landed and the final tables filled in:

```powershell
foreach ($t in 'Costs_raw', 'Costs_final_v1_2', 'Prices_raw', 'Prices_final_v1_2') {
  $count = (Invoke-Kusto Ingestion "$t | count" -Endpoint query).Tables[0].Rows[0][0]
  Write-Host "$t`: $count"
}
```

> [!TIP]
> Ingesting raw data is all you need — the final tables populate themselves through the update policy. Keep the policy enabled so each file's transform stays small; it scales to tens of millions of rows without running out of memory.

<br>

## Query your data

The `Hub` database exposes the same view functions a deployed hub does. Query them directly:

```powershell
$result = Invoke-Kusto Hub 'Costs_v1_2 | summarize EffectiveCost = round(sum(EffectiveCost), 2) by ServiceCategory | top 10 by EffectiveCost' -Endpoint query
$result.Tables[0].Rows
```

You now have a working local FinOps hub. To explore it visually, connect the [Azure Data Explorer web UI](https://dataexplorer.azure.com) to `http://localhost:8082`, or point Power BI and other tools at the same endpoint.

<br>

## Clean up

Remove the container when you're done. Your downloaded data stays in the export folder you created (`$exportPath`), but removing the container deletes its databases — re-creating it means re-loading the schema and open data and re-ingesting. To keep the loaded data between sessions, use `docker stop finops-hub-local` instead and restart it later with `docker start finops-hub-local`.

```powershell
docker rm -f finops-hub-local
```

<br>

## Related content

- [FinOps hubs overview](finops-hubs-overview.md)
- [Create and update FinOps hubs](deploy.md)
- [FinOps hub data model](data-model.md)
- [How data is processed](data-processing.md)

<br>
