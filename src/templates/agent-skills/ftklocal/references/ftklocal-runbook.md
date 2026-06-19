# ftklocal runbook

This runbook describes how to deploy, manage, ingest, recover, and query a local FinOps hub with the Azure Data Explorer Kusto emulator.

## Positioning

ftklocal is the own-hardware path for FinOps hubs. It is useful for customer deliveries, consulting, offline analysis, on-premises/other-cloud hosts, disconnected environments, and agent UAT where managed daily refresh is not required but full-fidelity hub analysis is.

Use Kusto as the execution engine. Avoid designs that download storage exports and materialize all rows as PowerShell objects; that does not scale to tens of GB or hundreds of millions of rows.

## Requirements

- Docker Desktop or Docker engine capable of running Linux containers.
- PowerShell 7.
- At least 16 GB container memory for small/medium imports; for large imports use roughly 8 GB per ingestion thread.
- Exported FOCUS data as Parquet with `manifest.json` files, staged locally or downloaded from a FinOps hub / Cost Management export storage account.
- Optional Az PowerShell modules if downloading from Azure Storage.

Official Kusto emulator constraints:

- Runs locally as a Linux Docker container.
- Exposes HTTP only.
- No Microsoft Entra authentication, access control, encrypted connections, managed ingestion, streaming ingestion, or production support.
- No Azure service provisioning or internet connectivity is required after image/data/artifacts are available locally.
- Not intended for production or benchmark claims.

## Start Docker and existing container

```powershell
$dockerDesktop = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'

if (-not (Test-Path $docker)) { throw 'Docker CLI not found.' }

try { & $docker info | Out-Null } catch {
  if (Test-Path $dockerDesktop) { Start-Process -FilePath $dockerDesktop | Out-Null }
}

for ($i = 0; $i -lt 60; $i++) {
  & $docker info 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Seconds 5
}

& $docker start finops-hub-local
```

## Create a new container

```powershell
$exportPath = 'D:\exports\local-hub'
New-Item -ItemType Directory -Force -Path $exportPath | Out-Null

$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
& $docker run -d --name finops-hub-local --platform linux/amd64 `
  -p 8082:8080 -m 16g -e ACCEPT_EULA=Y `
  -v "$((Resolve-Path $exportPath).Path):/data/export:ro" `
  mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest
```

Use more memory for large imports:

```powershell
& $docker run -d --name finops-hub-local --platform linux/amd64 `
  -p 8082:8080 -m 32g -e ACCEPT_EULA=Y `
  -v "$((Resolve-Path $exportPath).Path):/data/export:ro" `
  mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest
```

## Define the Kusto helper

```powershell
$hub = 'http://localhost:8082/v1/rest'
function Invoke-Kusto {
  param(
    [string]$Database,
    [string]$Command,
    [ValidateSet('mgmt','query')][string]$Endpoint = 'mgmt'
  )

  Invoke-RestMethod -Uri "$hub/$Endpoint" -Method Post -ContentType 'application/json' `
    -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
}
```

Wait for readiness:

```powershell
do {
  Start-Sleep -Seconds 3
  $ready = try { Invoke-Kusto NetDefaultDB '.show version'; $true } catch { $false }
} until ($ready)
```

## Create databases

```powershell
foreach ($db in 'Ingestion', 'Hub') {
  Invoke-Kusto NetDefaultDB ".create database $db persist (@`"/kustodata/dbs/$db/md`", @`"/kustodata/dbs/$db/data`")" | Out-Null
}
```

## Load released hub schema

```powershell
$release = 'https://github.com/microsoft/finops-toolkit/releases/latest/download'
New-Item -ItemType Directory -Force -Path "$exportPath\setup" | Out-Null
Invoke-WebRequest "$release/finops-hub-fabric-setup-Ingestion.kql" -OutFile "$exportPath\setup\setup-Ingestion.kql"
Invoke-WebRequest "$release/finops-hub-fabric-setup-Hub.kql" -OutFile "$exportPath\setup\setup-Hub.kql"

$ingestion = (Get-Content "$exportPath\setup\setup-Ingestion.kql" -Raw) -replace '\$\$rawRetentionInDays\$\$', '90'
Invoke-Kusto Ingestion $ingestion
Invoke-Kusto Hub (Get-Content "$exportPath\setup\setup-Hub.kql" -Raw)
```

## Load open data

```powershell
New-Item -ItemType Directory -Force -Path "$exportPath\open-data" | Out-Null
foreach ($f in 'PricingUnits', 'Regions', 'ResourceTypes', 'Services') {
  Invoke-WebRequest "$release/$f.csv" -OutFile "$exportPath\open-data\$f.csv"
}

$openData = @'
.execute database script with (ContinueOnErrors=true) <|
.set-or-replace PricingUnits <| externaldata(x_PricingUnitDescription: string, AccountTypes: string, x_PricingBlockSize: real, PricingUnit: string)[@'/data/export/open-data/PricingUnits.csv'] with (format='csv', ignoreFirstRecord=true) | project-away AccountTypes
.set-or-replace Regions <| externaldata(ResourceLocation: string, RegionId: string, RegionName: string)[@'/data/export/open-data/Regions.csv'] with (format='csv', ignoreFirstRecord=true)
.set-or-replace ResourceTypes <| externaldata(x_ResourceType: string, SingularDisplayName: string, PluralDisplayName: string, LowerSingularDisplayName: string, LowerPluralDisplayName: string, IsPreview: bool, Description: string, IconUri: string, Links: string)[@'/data/export/open-data/ResourceTypes.csv'] with (format='csv', ignoreFirstRecord=true) | project-away Links
.set-or-replace Services <| externaldata(x_ConsumedService: string, x_ResourceType: string, ServiceName: string, ServiceCategory: string, ServiceSubcategory: string, PublisherName: string, x_PublisherCategory: string, x_Environment: string, x_ServiceModel: string)[@'/data/export/open-data/Services.csv'] with (format='csv', ignoreFirstRecord=true)
'@
Invoke-Kusto Ingestion $openData
```

## Download exports from Azure Storage

Only needed when the data is not already staged locally.

```powershell
$account   = '<storage-account>'
$container = 'ingestion'
$prefix    = ''

$ctx = New-AzStorageContext -StorageAccountName $account -UseConnectedAccount
Get-AzStorageBlob -Container $container -Context $ctx -Prefix $prefix |
  Where-Object { $_.Name -match '(manifest\.json|\.parquet)$' } |
  ForEach-Object {
    Get-AzStorageBlobContent -Container $container -Context $ctx -Blob $_.Name `
      -Destination $exportPath -Force | Out-Null
  }
```

Skip zero-byte hierarchical namespace marker blobs; download only `manifest.json` and `*.parquet`.

## Ingest cost and price data

```powershell
$ingestConcurrency = 2

$ingestJobs = Get-ChildItem $exportPath -Recurse -Filter manifest.json | ForEach-Object {
  $type = if ((Get-Content $_.FullName -Raw) -match '"type"\s*:\s*"(FocusCost|PriceSheet)"') { $Matches[1] } else { return }
  $target = if ($type -eq 'FocusCost') { 'Costs_raw', 'Costs_raw_mapping' } else { 'Prices_raw', 'Prices_raw_mapping' }
  Get-ChildItem $_.Directory -Filter *.parquet | ForEach-Object {
    [PSCustomObject]@{
      Table   = $target[0]
      Mapping = $target[1]
      File    = $_.FullName
    }
  }
}

$ingestJobs | ForEach-Object -Parallel {
  $hub = $using:hub
  $exportPath = $using:exportPath

  function Invoke-Kusto {
    param([string]$Database, [string]$Command, [ValidateSet('mgmt','query')][string]$Endpoint = 'mgmt')
    Invoke-RestMethod -Uri "$hub/$Endpoint" -Method Post -ContentType 'application/json' `
      -Body (@{ db = $Database; csl = $Command } | ConvertTo-Json)
  }

  $rel  = [IO.Path]::GetRelativePath((Resolve-Path $exportPath), $_.File) -replace '\\', '/'
  $path = "/data/export/$rel"
  Invoke-Kusto Ingestion ".ingest into table $($_.Table) (h@'$path') with (format='parquet', ingestionMappingReference='$($_.Mapping)')" | Out-Null
  Write-Host "ingested $(Split-Path $_.File -Leaf)"
} -ThrottleLimit $ingestConcurrency
```

## Large import guidance

Validated pattern from a large import:

- 734 Parquet files.
- About 41.9 GB of exported files.
- About 322M source rows.
- About 644M raw + final Kusto rows after transforms.
- Stable run used 32 GB emulator memory and 4 ingestion threads, with monthly batches and restarts between batches.

Rules:

- Start with one ingestion thread per 8 GB of emulator memory.
- If the container exits with code 137, it ran out of memory.
- For very large imports, ingest month-by-month and restart the emulator between batches.
- Keep a JSONL per-file log with status, elapsed time, row count if known, and error text.
- Use idempotency tags for safe retries when custom scripting direct `.ingest`.

Correct tag syntax uses double quotes:

```kusto
.ingest into table Costs_raw (h@'/data/export/.../part.parquet')
  with (format='parquet', ingestionMappingReference='Costs_raw_mapping',
        ingestIfNotExists='ingest-by:<hash>', tags='["ingest-by:<hash>"]')
```

## Validate ingestion

```powershell
foreach ($t in 'Costs_raw', 'Costs_final_v1_2', 'Prices_raw', 'Prices_final_v1_2') {
  $count = (Invoke-Kusto Ingestion "$t | count" -Endpoint query).Tables[0].Rows[0][0]
  Write-Host "$t`: $count"
}
```

Check final vs raw rows. Costs should generally match exactly. Prices may differ after transforms depending on expansion/normalization behavior.

## Query the Hub database

Use `Hub` functions for analysis:

```powershell
Invoke-Kusto Hub @'
Costs_v1_2
| summarize EffectiveCost = round(sum(EffectiveCost), 2) by ServiceCategory
| top 10 by EffectiveCost
'@ -Endpoint query
```

Useful queries:

```kusto
Costs_v1_2
| summarize EffectiveCost=sum(EffectiveCost) by BillingPeriodStart
| order by BillingPeriodStart asc
```

```kusto
Costs_v1_2
| summarize EffectiveCost=sum(EffectiveCost) by SubAccountId, ServiceName
| top 50 by EffectiveCost
```

```kusto
Prices_v1_2
| summarize Prices=count() by BillingAccountId
```

## Connect tools

- Azure Data Explorer web UI can connect to `http://localhost:8082`.
- The endpoint is HTTP and unauthenticated; configure clients to allow unsafe/no-auth connections where required.
- Power BI or custom tools should query the local Kusto endpoint, not read raw storage files for large datasets.

## Stop and clean up

Stop without deleting data:

```powershell
$docker = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
& $docker stop finops-hub-local
```

Remove the container:

```powershell
& $docker rm -f finops-hub-local
```

Downloaded exports remain in `$exportPath`. Container-internal database persistence depends on how the container/database paths were created and whether volumes were mounted.

## Troubleshooting

| Symptom | Meaning | Action |
|---------|---------|--------|
| `docker` not recognized | Docker CLI not on PATH | Use `C:\Program Files\Docker\Docker\resources\bin\docker.exe` or refresh PATH |
| Docker pipe missing | Docker Desktop/daemon not running | Start Docker Desktop, wait for `docker info` |
| Endpoint not ready | Kusto still starting | Retry `.show version` every few seconds |
| Exit 137 | OOM kill | Reduce concurrency, increase memory, batch by month, restart between batches |
| Zero-byte marker issues | ADLS hierarchical namespace folder blobs | Download only `manifest.json` and `*.parquet` |
| Reingest uncertainty | Raw extents lack source-file lineage | Add idempotency tags and per-file logs in custom recovery scripts |
| PowerShell storage reader is slow/OOM | Rows are being materialized outside Kusto | Query Hub database directly |

## Source

- FinOps toolkit repo: `docs-mslearn/toolkit/hubs/run-hubs-locally.md` from `origin/features/ftklocal`, read 2026-06-19.
- FinOps toolkit repo: `docs-mslearn/toolkit/hubs/data-processing.md`, read 2026-06-19.
- FinOps toolkit repo: `docs-mslearn/toolkit/hubs/finops-hubs-overview.md`, read 2026-06-19.
- Microsoft Docs: `https://learn.microsoft.com/en-us/azure/data-explorer/kusto-emulator-overview`, read 2026-06-19.
- Microsoft Docs: `https://learn.microsoft.com/en-us/azure/data-explorer/kusto-emulator-install`, read 2026-06-19.

