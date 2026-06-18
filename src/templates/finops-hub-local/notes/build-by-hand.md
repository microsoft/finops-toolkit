# Build a local FinOps hub by hand

This is the manual runbook. It shows every command needed to stand up a local FinOps
hub on the Kusto emulator and load your FOCUS cost data — no helper scripts. The
[helper scripts](#automating-the-steps) automate exactly these steps; read this first so
you know what they do.

The whole thing is six steps and about a dozen commands:

1. [Start the emulator](#1-start-the-emulator)
2. [Create the two databases](#2-create-the-two-databases)
3. [Load the schema](#3-load-the-schema)
4. [Ingest your Parquet exports](#4-ingest-your-parquet-exports)
5. [Build the final tables](#5-build-the-final-tables)
6. [Query](#6-query)

## Prerequisites

- Docker and PowerShell 7 — see [install-windows.md](install-windows.md) or
  [install-mac.md](install-mac.md).
- FOCUS cost exports as Parquet, staged under `export/` — see
  [staging-contract.md](staging-contract.md).
- The two schema bundles, which the toolkit build produces from the FinOps hub KQL:
  `release/finops-hub-fabric-setup-Ingestion.kql` and
  `release/finops-hub-fabric-setup-Hub.kql`. Run `npm run build` (or
  `pwsh ./src/scripts/Build-Toolkit.ps1 -Template finops-hub`) once to generate them.

## How to run a command

The emulator is a plain HTTP endpoint with no auth. Send any management command (a `.`
command) to `/v1/rest/mgmt` and any query to `/v1/rest/query`. Every command below can be
run with `curl`:

```bash
curl -s "http://localhost:8082/v1/rest/mgmt" \
  -H "Content-Type: application/json" \
  -H "x-ms-client-version: Kusto.Python.Client:1.0.0" \
  -d '{"db":"<database>","csl":"<command>"}'
```

You can also paste commands into the query window of the
[ADX web UI](dashboard.md) connected to `http://localhost:8082`.

---

## 1. Start the emulator

```bash
docker compose up -d --wait
```

`--wait` blocks until the container's healthcheck passes, so the engine is ready to
answer when the command returns. The emulator mounts your `export/` directory read-only
at `/data/export` inside the container.

## 2. Create the two databases

A FinOps hub uses two databases — `Ingestion` for the raw and transformed data, and `Hub`
for the view functions analysts query. Create both, persisted so they survive a restart:

```kusto
// db: NetDefaultDB
.create database Ingestion persist (@'/kustodata/dbs/Ingestion/md', @'/kustodata/dbs/Ingestion/data')
.create database Hub persist (@'/kustodata/dbs/Hub/md', @'/kustodata/dbs/Hub/data')
```

## 3. Load the schema

Each schema bundle is a single `.execute database script` command, so loading it is one
POST per database — the engine runs every statement in the file in order.

The Ingestion bundle has one placeholder, `$$rawRetentionInDays$$`, the raw-data
retention in days. Replace it with a number (for example `90`) before loading.

```bash
# Ingestion schema (raw tables, transform functions, final tables, open data)
sed 's/\$\$rawRetentionInDays\$\$/90/g' release/finops-hub-fabric-setup-Ingestion.kql \
  | python3 -c 'import sys,json; print(json.dumps({"db":"Ingestion","csl":sys.stdin.read()}))' \
  | curl -s "http://localhost:8082/v1/rest/mgmt" \
      -H "Content-Type: application/json" \
      -H "x-ms-client-version: Kusto.Python.Client:1.0.0" --data-binary @-

# Hub schema (the Costs/Prices/Transactions view functions)
python3 -c 'import sys,json; print(json.dumps({"db":"Hub","csl":open("release/finops-hub-fabric-setup-Hub.kql").read()}))' \
  | curl -s "http://localhost:8082/v1/rest/mgmt" \
      -H "Content-Type: application/json" \
      -H "x-ms-client-version: Kusto.Python.Client:1.0.0" --data-binary @-
```

The bundle is loaded with `ContinueOnErrors=true`, so the response is a table with one row
per statement and its result — scan it for any `Failed` rows. The Hub functions reference
`database('Ingestion').*`; those resolve once both databases exist.

## 4. Ingest your Parquet exports

The schema created the raw tables (`Costs_raw`, `Prices_raw`) and their Parquet ingestion
mappings (`Costs_raw_mapping`, `Prices_raw_mapping`). Ingest the files mounted at
`/data/export`. List one `h@'...'` URI per file, comma-separated, to load many files in a
single command:

```kusto
// db: Ingestion — cost exports
.ingest into table Costs_raw (
    h@'/data/export/<scope>/ms--focus-cost/<period>/<run>/part_0.parquet',
    h@'/data/export/<scope>/ms--focus-cost/<period>/<run>/part_1.parquet'
  ) with (format='parquet', ingestionMappingReference='Costs_raw_mapping')

// db: Ingestion — price sheets
.ingest into table Prices_raw (
    h@'/data/export/<scope>/ms--pricesheet/<period>/<run>/part_0.parquet'
  ) with (format='parquet', ingestionMappingReference='Prices_raw_mapping')
```

Confirm the row counts:

```kusto
// db: Ingestion
Costs_raw | count
Prices_raw | count
```

## 5. Build the final tables

The raw tables hold the data as-exported. The FinOps transform functions
(`Costs_transform_v1_2`, `Prices_transform_v1_2`) apply the FOCUS normalization; run them
into the final tables:

```kusto
// db: Ingestion
.set-or-append Costs_final_v1_2 <| Costs_transform_v1_2()
.set-or-append Prices_final_v1_2 <| Prices_transform_v1_2()
```

**Large datasets:** a single-pass transform materializes the whole table in memory and can
exceed the container's `MEM_LIMIT` on tens of millions of rows. When that happens, run the
transform one source extent at a time so each pass is bounded:

```kusto
// db: Ingestion — repeat per extent_id() group
.set-or-append Prices_final_v1_2 <|
    let Prices_raw = __table("Prices_raw", 'All', 'AllButRowStore')
      | where extent_id() in (<guid1>, <guid2>);
    Prices_transform_v1_2()
```

The [`ingest.ps1`](../scripts/ingest.ps1) helper does this automatically (see
[performance.md](performance.md) for the memory measurements). Doing it by hand for a huge
table is impractical — this is the main reason to use the helper.

## 6. Query

The `Hub` database exposes the same view functions a deployed hub does. Query them
directly:

```kusto
// db: Hub
Costs_v1_2()
| summarize EffectiveCost = round(sum(EffectiveCost), 2) by ServiceName
| top 10 by EffectiveCost
```

That is a working local FinOps hub.

---

## Automating the steps

The helper scripts in [`scripts/`](../scripts/) are this runbook, automated. They add
nothing the engine doesn't already do — they just save you the manual file-listing and,
for large data, the per-extent chunking:

| Step                          | By hand                                        | Helper                                                                                                                             |
| ----------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| 2–3. Create DBs + load schema | `.create database` ×2, POST each bundle        | [`load-ftk-kql.ps1`](../scripts/load-ftk-kql.ps1)                                                                                  |
| 4–5. Ingest + build finals    | `.ingest` per file, `.set-or-append` per table | [`ingest.ps1`](../scripts/ingest.ps1) — discovers your files, skips already-loaded ones, and chunks the transform for large tables |
| 6. Query                      | POST to `/v1/rest/query`                       | [`ftk.ps1`](../scripts/ftk.ps1) — also runs the published query catalog                                                            |

On macOS and Linux the [`Makefile`](../Makefile) wraps these (`make up`, `make
load-ftk-kql`, `make ingest`). See the [README](../README.md) for the quickstart.
