---
name: ftklocal
description: Deploy, operate, recover, and query a local FinOps hub on your own hardware with the Kusto emulator. Use when the user mentions ftklocal, local FinOps hub, running FinOps hubs locally, Kusto emulator hub, offline/on-prem/other-cloud FinOps analysis, local Hub database queries, large exported FOCUS datasets, or validating FinOps toolkit data without Azure-hosted ADX/Fabric.
license: MIT
compatibility: Requires Docker and PowerShell 7. Optional Azure PowerShell is only needed to download exports from Azure Storage.
metadata:
  author: microsoft
  version: "1.0"
---

# ftklocal

Use this skill to run a FinOps hub analytics layer locally on your own hardware. The local hub uses the Azure Data Explorer Kusto emulator container and the same released FinOps hub setup KQL, schemas, transforms, update policies, open data, and Hub view functions used by deployed hubs.

## What ftklocal is for

- **Offline/customer delivery analysis**: Analyze full exported customer datasets without managed daily refresh.
- **Own-hardware/on-prem/other-cloud operation**: Run where Docker and exported data are available, including disconnected environments.
- **Agent UAT and troubleshooting**: Validate hub transforms, large ingestions, and KQL behavior without deploying Azure-hosted ADX or Fabric.
- **Scale shape**: Keep data in Kusto and query summarized results. Do not load tens of GB or hundreds of millions of rows into PowerShell objects.

Not production: the Kusto emulator has no authentication, access control, encrypted connections, managed ingestion, or production support. It is provided as-is and is not intended for production workloads or benchmark claims.

## Core model

- Container endpoint: `http://localhost:8082/v1/rest`
- Databases:
  - `Ingestion`: raw tables, final tables, transforms, update policies, open data
  - `Hub`: user-facing view functions such as `Costs_v1_2`
- Data flow:
  1. Stage `manifest.json` and `*.parquet` exports under a local export folder.
  2. Mount that folder read-only into the container at `/data/export`.
  3. Load released setup KQL into `Ingestion` and `Hub`.
  4. Load open data CSVs.
  5. `.ingest` Parquet files into `Costs_raw` / `Prices_raw`; update policies fill final tables.
  6. Query the `Hub` database, not local Parquet files, for analysis.

## Task routing

Load [references/ftklocal-runbook.md](references/ftklocal-runbook.md) for deployment, recovery, ingestion, troubleshooting, or any non-trivial query/operations task.

## Quick operations

### Start existing local hub

```powershell
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
& $docker start finops-hub-local
```

Then wait for:

```powershell
$hub = 'http://localhost:8082/v1/rest'
function Invoke-Kusto {
  param([string]$Database, [string]$Command, [ValidateSet('mgmt','query')][string]$Endpoint = 'mgmt')
  Invoke-RestMethod -Uri "$hub/$Endpoint" -Method Post -ContentType 'application/json' `
    -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
}
Invoke-Kusto NetDefaultDB '.show version'
```

### Stop local hub

```powershell
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
& $docker stop finops-hub-local
```

### Check row counts

```powershell
foreach ($t in 'Costs_raw', 'Costs_final_v1_2', 'Prices_raw', 'Prices_final_v1_2') {
  $count = (Invoke-Kusto Ingestion "$t | count" -Endpoint query).Tables[0].Rows[0][0]
  Write-Host "$t`: $count"
}
```

### Query analysis data

```powershell
$result = Invoke-Kusto Hub @'
Costs_v1_2
| summarize EffectiveCost = round(sum(EffectiveCost), 2) by ServiceCategory
| top 10 by EffectiveCost
'@ -Endpoint query
$result.Tables[0].Rows
```

## Operational rules for agents

1. Prefer Kusto queries over reading Parquet/CSV into PowerShell objects.
2. Use the `Hub` database for analysis; use `Ingestion` only for row counts, raw/final validation, and troubleshooting.
3. For large imports, start around one ingest thread per 8 GB of emulator memory.
4. Exit code 137 means the emulator was OOM-killed: lower concurrency, increase memory, ingest one month at a time, and restart between batches.
5. For very large imports, keep per-file logs and idempotency tags so failed files can be retried.
6. Do not call this production, secure, or managed. It is a local analysis and validation tier.
7. Do not use local storage-export row materialization as the scalable analysis path.

## Learn more

| Topic | How to find |
|-------|-------------|
| FinOps hubs overview | `microsoft_docs_search(query="FinOps hubs overview Azure Data Explorer Fabric")` |
| Kusto emulator overview | `microsoft_docs_fetch(url="https://learn.microsoft.com/en-us/azure/data-explorer/kusto-emulator-overview")` |
| Kusto emulator install | `microsoft_docs_fetch(url="https://learn.microsoft.com/en-us/azure/data-explorer/kusto-emulator-install")` |
| Kusto query language | `microsoft_docs_search(query="Azure Data Explorer KQL summarize top project")` |

## CLI alternative

If the Learn MCP server is not available, use the `mslearn` CLI instead:

| MCP tool | CLI command |
|----------|-------------|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

Run directly with `npx @microsoft/learn-cli <command>` or install globally with `npm install -g @microsoft/learn-cli`.

