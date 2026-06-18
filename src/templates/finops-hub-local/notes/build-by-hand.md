# Build a local FinOps hub by hand

This is the manual runbook. It shows every command needed to stand up a local FinOps
hub on the Kusto emulator and load your FOCUS cost data — no helper scripts. The
[helper scripts](#automating-the-steps) automate exactly these steps; read this first so
you know what they do.

The whole thing is six steps and about a dozen commands:

1. [Start the emulator](#1-start-the-emulator)
2. [Create the two databases](#2-create-the-two-databases)
3. [Load the schema](#3-load-the-schema)
4. [Ingest your Parquet exports](#4-ingest-your-parquet-exports) — the final tables populate themselves
5. [Large datasets: defer the transform](#5-large-datasets-defer-the-transform)
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
mappings (`Costs_raw_mapping`, `Prices_raw_mapping`). It also enabled an **update policy**
on each final table: as rows land in `Costs_raw`, the engine runs `Costs_transform_v1_2()`
automatically and appends the FOCUS-normalized result to `Costs_final_v1_2` (and the same
for prices). This is the exact mechanism a deployed FinOps hub uses — so on the local
emulator, **ingesting the raw data is all you need**; the final tables populate
themselves.

Ingest the files mounted at `/data/export`. List one `h@'...'` URI per file,
comma-separated, to load many files in a single command:

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

Confirm the raw counts and that the final tables filled in via the update policy:

```kusto
// db: Ingestion
Costs_raw | count
Costs_final_v1_2 | count   // populated automatically by the update policy
Prices_raw | count
Prices_final_v1_2 | count
```

> Do **not** also run `.set-or-append Costs_final_v1_2 <| Costs_transform_v1_2()` here —
> with the update policy enabled, the transform already ran during ingest, and a manual
> backfill would append a second copy and double the final tables.

## 5. Large datasets: defer the transform

The update policy is `IsTransactional`, so it transforms every ingested batch inline. That
is ideal for incremental exports, but a one-shot bulk load of tens of millions of rows
makes each batch's transform slow and memory-heavy, and a whole-table transform can exceed
the container's `MEM_LIMIT`. For a large historical load, turn the policy off, ingest, then
run the transform once — in chunks bounded by source extent:

````kusto
// db: Ingestion
// 1. disable the update policy so ingest doesn't transform inline
.alter table Costs_final_v1_2 policy update ```[{"IsEnabled":false,"Source":"Costs_raw","Query":"Costs_transform_v1_2()","IsTransactional":true,"PropagateIngestionProperties":true}]```

// 2. ingest all the raw data (as in step 4)

// 3. run the transform once, one extent group at a time so each pass is bounded
.set-or-append Costs_final_v1_2 <|
    let Costs_raw = __table("Costs_raw", 'All', 'AllButRowStore')
      | where extent_id() in (<guid1>, <guid2>);
    Costs_transform_v1_2()

// 4. re-enable the update policy (set IsEnabled back to true)
````

The [`ingest.ps1`](../scripts/ingest.ps1) helper does exactly this — disable, bulk-ingest,
chunked backfill, re-enable — so you don't have to manage the policy or the extent GUIDs by
hand. See [performance.md](performance.md) for the memory measurements that set the chunk
threshold. **For large data, use the helper; this section is what it does under the hood.**

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

| Step                          | By hand                                                       | Helper                                                                                                                                                            |
| ----------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2–3. Create DBs + load schema | `.create database` ×2, POST each bundle                       | [`load-ftk-kql.ps1`](../scripts/load-ftk-kql.ps1)                                                                                                                 |
| 4–5. Ingest                   | `.ingest` per file; for large data, disable policy + backfill | [`ingest.ps1`](../scripts/ingest.ps1) — discovers your files, skips already-loaded ones, and for large tables disables the update policy and chunks the transform |
| 6. Query                      | POST to `/v1/rest/query`                                      | [`ftk.ps1`](../scripts/ftk.ps1) — also runs the published query catalog                                                                                           |

On macOS and Linux the [`Makefile`](../Makefile) wraps these (`make up`, `make
load-ftk-kql`, `make ingest`). See the [README](../README.md) for the quickstart.
