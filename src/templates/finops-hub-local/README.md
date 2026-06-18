# FinOps hub (local)

Run the FinOps Toolkit's full KQL cost-analytics stack **locally** against a Kusto
emulator (Docker) — no Azure subscription, no cloud cluster, no Data Factory required.
The analytic IP is identical to a deployed hub: the same `IngestionSetup` / `HubSetup`
KQL, the same hub view functions (`Costs`, `Prices`, `Transactions`, and their `*_v1_2`
variants), the same open data, and the same query catalog.

---

## When to use this vs deploying a real hub

| Situation | Use |
|-----------|-----|
| Offline analysis, air-gapped network, or no Azure subscription | **ftklocal** |
| Developing or testing KQL changes before deploying | **ftklocal** |
| Working with FOCUS parquet already on disk | **ftklocal** |
| Production analytics for an organization | [Deploy a FinOps hub](../finops-hub/README.md) |
| Querying a live Azure Data Explorer or Fabric cluster | [FinOps hub](../finops-hub/README.md) |

---

## Prerequisites

- **Docker Desktop ≥ 4.0** — Compose v2 is required (`docker compose`, not the legacy
  `docker-compose`).
- **PowerShell 7+** (`pwsh`) — all tooling is PowerShell; there are no Python
  dependencies. On Windows this is **PowerShell 7**, not the built-in Windows PowerShell
  5.1 (`winget install Microsoft.PowerShell`).
- **FOCUS cost exports as Parquet** — staged under `export/`. See
  [notes/staging-contract.md](notes/staging-contract.md) for the folder layout.
- Roughly **16 GiB of RAM** available for the container (the default `MEM_LIMIT` in
  `.env.example`). Costs-only datasets work at 8 GiB; 16 GiB is required for the full
  Prices transform. See [Limits](#limits).
- Host port **8082** free (configurable via `HOST_PORT` in `.env`).

**Per-platform install guides** (prerequisites, memory tuning, troubleshooting):

- 🪟 **[Windows](notes/install-windows.md)** — primary platform; the `linux/amd64` engine
  runs natively (no emulation). Covers Docker Desktop + WSL 2, PowerShell 7, and WSL memory
  tuning.
- 🍎 **[macOS](notes/install-mac.md)** — secondary; Apple Silicon runs the engine under
  Rosetta emulation. Covers Rosetta and Docker Desktop memory.

---

## Quickstart

The commands below work on **Windows, macOS, and Linux** (PowerShell 7 + Docker Compose v2).
`make` targets are an optional convenience on macOS/Linux — see the
[macOS guide](notes/install-mac.md).

```bash
# From src/templates/finops-hub-local/

cp .env.example .env            # 1. review tunables (HOST_PORT, MEM_LIMIT, EXPORT_DIR)
                                #    (Windows: Copy-Item .env.example .env)
docker compose up -d --wait     # 2. start the emulator; blocks until the healthcheck passes
pwsh scripts/load-ftk-kql.ps1   # 3. create Ingestion + Hub DBs, load FTK KQL + open data (idempotent)
pwsh scripts/ingest.ps1         # 4. bulk-ingest all Parquet exports under export/

# 5. query your FOCUS data
pwsh scripts/ftk.ps1 query "Costs() | summarize TotalCost = sum(EffectiveCost) by ServiceName | top 10 by TotalCost"
```

`docker compose up -d --wait` is the cross-platform equivalent of `make up` — it uses the
container's healthcheck and returns only once the engine is answering. After step 4
completes, the Hub database holds the same view functions a deployed hub exposes;
`pwsh scripts/ingest.ps1 -DryRun` previews ingest and `make ingest-status` (macOS/Linux)
summarizes what was loaded.

---

## Configuration

All tunables live in `.env` (gitignored). `.env.example` documents them:

| Variable | Default | Meaning |
|----------|---------|---------|
| `HOST_PORT` | `8082` | Host port mapped to the Kustainer container's HTTP endpoint. |
| `MEM_LIMIT` | `16g` | Memory ceiling for the Kustainer container. |
| `EXPORT_DIR` | `./export` | Host directory with Parquet exports (read-only mount). |
| `BACKFILL_CHUNK_ROW_THRESHOLD` | `2000000` | Row count above which `ingest.ps1` uses proactive chunked backfill. See [Chunked backfill](#automatic-chunked-backfill). |

---

## Architecture

### Two-database topology

The local stack mirrors the real hub's **two-database** layout:

| Database | Holds | You query it for |
|----------|-------|------------------|
| **`Ingestion`** | Raw tables (`Costs_raw`, `Prices_raw`), `*_transform_v1_2()` functions, final tables (`Costs_final_v1_2`, `Prices_final_v1_2`), open-data lookups, and `Ingest_Manifest` | Ingestion internals, parity checks, transform debugging |
| **`Hub`** | Hub view functions (`Costs`, `Prices`, `Transactions`, `Costs_v1_2`, `Prices_v1_2`, …) that read `database('Ingestion').*` | All analytics — this is the default query database |

The `Hub` database is the default for `make kql` and `ftk.ps1`. To inspect raw tables,
override: `make kql KQL_DB=Ingestion QUERY='Costs_raw | count'`.

### How it maps to a real hub

| Real hub component | Local equivalent |
|--------------------|-----------------|
| Azure Data Explorer (ADX) cluster | Kusto emulator (Docker, `http://localhost:8082`) |
| `Ingestion` ADX database | `Ingestion` database in the emulator |
| `Hub` ADX database | `Hub` database in the emulator |
| Data Factory pipeline (ADF) | `scripts/ingest.ps1` |
| Azure Storage (`msexports/` or `ingestion/` container) | `export/` directory on disk |
| Bicep/ARM deployment | `make load-ftk-kql` (idempotent KQL loader) |

The KQL itself — `IngestionSetup_RawTables.kql`, `IngestionSetup_v1_2.kql`,
`HubSetup_v1_2.kql`, `HubSetup_OpenData.kql` — is loaded verbatim from the upstream
FTK source with [minimal on-load adaptations](notes/ftk-kql-adaptations.md).

---

## Ingesting data

### Staging your exports

Parquet exports must be staged under `export/` in the layout described in
[notes/staging-contract.md](notes/staging-contract.md). The short version:

```
export/
└── <scope>/
    └── <type>/           # ms--focus-cost | ms--pricesheet
        └── <YYYYMMDD-YYYYMMDD>/
            └── <run-uuid>/
                ├── manifest.json
                └── *.parquet
```

A `manifest.json` produced directly by Azure Cost Management can be used without
modification. See [staging-contract.md](notes/staging-contract.md) for minimum
viable manifest fields and instructions for both `msexports/` and `ingestion/`
source containers.

### Running ingest

```bash
make ingest                              # ingest all scopes/periods
make ingest SCOPE=ea                     # one scope
make ingest SCOPE=ea PERIOD=20260501-20260531  # scope + period
make ingest-status                       # show Ingest_Manifest summary
```

`ingest.ps1` is idempotent: it tracks every ingested file in `Ingest_Manifest` by
`(scope, type, period, run-uuid, file-name)` and SHA-256 checksum. Re-running `make
ingest` on an unchanged export directory is safe — already-ingested files are skipped.

### Overwrite semantics

| Situation | Behavior |
|-----------|----------|
| Same run-uuid, same file checksum | Skip (already ingested) |
| Same `(scope, type, period)`, **new** run-uuid | Safe replace — old extents are dropped, new data is ingested |
| Same run-uuid, **changed** file checksum | **Fail-fast double-ingest guard** — the script detects the checksum mismatch and refuses. Stage the replacement files under a **new run-uuid** instead. |

> **How to replace data:** stage replacement parquet under a new `<run-uuid>` directory
> with a `manifest.json` whose `runInfo.submittedTime` is later than the existing run.
> `ingest.ps1` selects the latest run per `(scope, type, period)`, drops the old run's
> extents, and ingests the new files cleanly.

### Automatic chunked backfill

For large tables, `ingest.ps1` avoids the single-pass OOM by chunking the final-table
backfill automatically:

- **Proactive:** if the raw table row count exceeds `BACKFILL_CHUNK_ROW_THRESHOLD`
  (default 2,000,000), single-pass `.set-or-append` is skipped entirely and per-extent
  chunked backfill is used from the start.
- **Reactive:** if the row count is at or below the threshold, single-pass is tried
  first; if it OOMs the engine, `ingest.ps1` falls back to chunked automatically.

The threshold is sized so that at `MEM_LIMIT=16g`:
- Costs (~1.35 M rows) → single-pass (safely below threshold).
- Prices (~12.7 M rows) → proactive chunked (safely above threshold).

To trigger the chunked backfill manually (e.g., recovery after a crash):

```bash
make chunked-prices-backfill
```

---

## Querying

### `ftk.ps1` CLI

```bash
# Ad-hoc query (Hub DB by default)
pwsh scripts/ftk.ps1 query "Costs() | summarize sum(EffectiveCost) by ServiceName | top 10 by sum_EffectiveCost"

# List available named catalog queries
pwsh scripts/ftk.ps1 list

# Run a named catalog query
pwsh scripts/ftk.ps1 run savings-summary-report
pwsh scripts/ftk.ps1 run savings-summary-report --format csv
pwsh scripts/ftk.ps1 run savings-summary-report --start 2026-01-01 --end 2026-06-30

# Inspect schema
pwsh scripts/ftk.ps1 schema
pwsh scripts/ftk.ps1 schema -Tables
pwsh scripts/ftk.ps1 schema -Functions
pwsh scripts/ftk.ps1 tables Costs_final_v1_2

# Override database (e.g., query Ingestion raw tables)
pwsh scripts/ftk.ps1 query "Costs_raw | count" -Database Ingestion
```

The CLI connects to `http://localhost:8082` by default. Override with the `HOST_PORT`
environment variable or the `-Endpoint` parameter.

### Agent skill

For agent-driven analytics, the `finops-hub-local` agent skill wraps the same CLI
into structured tool calls. See
[`../agent-skills/finops-hub-local/SKILL.md`](../agent-skills/finops-hub-local/SKILL.md).

---

## Dashboard

The included `dashboard.json` is the upstream FinOps hub dashboard with the cluster
URI changed to `http://localhost:8082` and the database set to `Hub`. All tiles and
KQL queries are unmodified.

**Proven path (CLI):** `ftk.ps1 query` and `ftk.ps1 run` work today with no browser
dependency.

**Best-effort path (ADX web UI):** Import `dashboard.json` via
**https://dataexplorer.azure.com → Dashboards → Import dashboard from file**. Note
that browsers apply strict mixed-content rules: connecting an HTTPS page to a plain
`http://localhost:8082` endpoint may be blocked. See
[notes/dashboard.md](notes/dashboard.md) for step-by-step instructions, the
mixed-content caveat, and the ngrok HTTPS workaround.

---

## Limits

These numbers were measured on `MEM_LIMIT=16g`, amd64-on-Rosetta (Apple Silicon),
with a dataset of approximately 1,350,561 Cost rows and 12,735,587 Price rows plus
open-data lookups. Your results vary by `MEM_LIMIT` and dataset size.

| Metric | Measured value |
|--------|----------------|
| Raw file ingest wall-clock (31 parts, ~991 MB) | 419.6 s (7.0 min) |
| Full `ingest.ps1` wall-clock (raw + all backfill) | 841.6 s (14.0 min) |
| **Cold loaded** — post-restart, data on disk, extents not yet materialized (anon) | **1.12 GiB (7.0% of 16 GiB)** — this is the floor |
| **Hot post-ingest** — immediately after transform pipeline; extents in memory (anon) | **13.99 GiB (≈87% of 16 GiB)** — sustained until restart |
| Chunked backfill memory.peak (cumulative HWM, Prices per-extent) | **15.03 GiB (93.9% of 16 GiB)** |
| Single-pass Prices transform (~12.7 M rows) | anon ~14.74 GiB / memory.peak **15.12 GiB** → engine crash |
| Single-pass Costs transform (~1.35 M rows) | Completes in 53 s; peak 6.89 GiB (43% of 16 GiB) |

See [notes/performance.md](notes/performance.md) for the full row-count → memory curve,
per-stage cgroup v2 measurements, and OOM ceiling analysis.

---

## Troubleshooting

### Port 8082 already in use

```bash
lsof -nP -iTCP:8082 -sTCP:LISTEN
```

Set `HOST_PORT=<other-port>` in `.env` and re-run `make up`. Do not use port 8080.

### Container does not become healthy in 90 s

- **Apple Silicon:** ensure Rosetta is enabled (Docker Desktop → Settings → General).
- **Logs:** `make logs` — look for `Database NetDefaultDB has been created and is
  answering queries`.
- **Memory:** `docker stats --no-stream kustainer` — raise `MEM_LIMIT` in `.env` if
  near the ceiling. After editing `.env`, always use `make down && make up` (never
  `--force-recreate`; see below).

### `Ingestion` or `Hub` DB missing after `make up`

After a `make down && make up` cycle the databases should reattach from `kustainer-data/`.
If they are missing:

1. Run `make nuke` to remove the data volume.
2. Run `make up && make load-ftk-kql && make ingest` to rebuild from scratch.

If you used `docker compose up --force-recreate` the metadata volume was torn down
and cannot be reattached. `make nuke` + full reload is the only recovery path.

### Row count is 0 after `make ingest`

Check whether the update policy was left disabled by a crashed run:

```bash
make kql KQL_DB=Ingestion QUERY=".show table Costs_final_v1_2 policy update"
```

If `IsEnabled` is `false`, re-enable the policy and manually trigger the backfill.
`ingest.ps1` will refuse to run until the policy is restored; pass
`--force-policy-recapture` only if you have manually verified the disabled state is
safe.

### Prices backfill OOM (container exits under load)

Raise `MEM_LIMIT` to `16g` in `.env`:

```bash
# Edit .env, then bounce:
make down && make up
make ingest
```

If the OOM persists at 16 GiB (rare, larger datasets), use the manual chunked path:

```bash
make chunked-prices-backfill
```

`ingest.ps1` normally handles the reactive fallback automatically; this target is the
manual override.

### Checksum mismatch guard

If you modified files in an already-ingested run directory, `ingest.ps1` will refuse
with a checksum error. This is the **fail-fast double-ingest guard**: mutating an
ingested file is not a safe overwrite path. Stage the corrected files under a **new
`<run-uuid>` directory** and re-run `make ingest`.

### Rosetta SIGSEGV (rare crashes under heavy load)

`restart: unless-stopped` in `docker-compose.yml` restarts the container automatically.
The `kustainer-data/` volume is preserved and the databases reattach. `ingest.ps1`'s
chunked-backfill retry loop catches the resulting `RemoteDisconnected` error, waits for
the engine to recover, drops any partial output, and retries. No operator action is
needed unless the same chunk fails repeatedly (lower `--extents-per-batch` or raise
`MEM_LIMIT`).

---

## Parity status

The parity check suite validates that the local transform produces output identical to
what the FTK pipeline would produce. Current status: **11 pass / 0 fail / 2 manual**
of 13 checks. See [notes/parity-gaps.md](notes/parity-gaps.md) for details.

Run the suite:

```bash
make parity
```

---

## Makefile reference

| Target | What it does |
|--------|--------------|
| `make up` | Bring Kustainer up and block until the healthcheck passes. |
| `make down` | Stop the container (data volume preserved). |
| `make nuke` | Destructive full reset — removes the `kustainer-data/` volume. |
| `make logs` | Tail Kustainer container logs. |
| `make kql QUERY='...'` | One-shot KQL against Hub (override: `KQL_DB=Ingestion`). |
| `make load-ftk-kql` | Load FTK KQL + open data into Ingestion + Hub (idempotent). |
| `make ingest` | Bulk-ingest all Parquet exports under `export/`. |
| `make ingest SCOPE=<s>` | Ingest one scope only. |
| `make ingest SCOPE=<s> PERIOD=<p>` | Ingest one scope + period. |
| `make ingest-status` | Show `Ingest_Manifest` summary (files + rows per scope/type). |
| `make parity` | Run the parity check suite (exit 0 iff all checks pass). |
| `make chunked-prices-backfill` | Manual per-extent Prices backfill (auto-triggered by threshold). |
| `make help` | Print all targets. |
