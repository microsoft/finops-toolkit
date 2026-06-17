# Local vs remote: reusing the FinOps Toolkit analytics

The local FinOps hub runs the **same FinOps Toolkit analytics** as a deployed hub, but
against a local Kusto emulator instead of an Azure Data Explorer (ADX) or Microsoft
Fabric cluster. The query IP is identical; only the **connection** and a couple of
small, on-read **query adaptations** differ.

## What is the same: the analytic IP

Both local and remote expose the FinOps hub analytic view functions, so the published
query catalog is portable across both:

| Function | Purpose |
|----------|---------|
| `Costs()` / `Costs_v1_2()` | Cost & usage analytics (FOCUS-aligned) |
| `Prices()` / `Prices_v1_2()` | Price sheets (list / contracted / effective) |
| `Transactions()` | Commitment purchases, refunds, exchanges |

These functions live in the `Hub` database and read the final tables in the
`Ingestion` database via `database('Ingestion').*` references — the same two-database
topology a deployed hub uses. The cross-database references resolve in the emulator
exactly as they do in ADX.

## What is different: connecting

| Aspect | Deployed hub | Local |
|--------|-------------|-------|
| Endpoint | `https://<cluster>.kusto.windows.net` | `http://localhost:8082` (default `HOST_PORT`) |
| Auth | Azure AD (tenant) | none (local, single user) |
| Query database | `Hub` | `Hub` (same) |
| Client | MCP Kusto server / Power BI | `ftk.ps1` CLI |
| Settings | environment settings file | `.env` (`HOST_PORT`, `MEM_LIMIT`, `EXPORT_DIR`) |

Run a catalog query locally:

```bash
pwsh scripts/ftk.ps1 list                        # discover catalog queries
pwsh scripts/ftk.ps1 run savings-summary-report  # adapt + run a named catalog query
pwsh scripts/ftk.ps1 query "Costs() | summarize sum(EffectiveCost) by ServiceName | top 10 by sum_EffectiveCost"
```

## On-read query adaptations (applied automatically by `ftk run`)

The emulator is the same engine as ADX, so catalog queries run **almost** verbatim.
`ftk run` reads each upstream `.kql` **in place** (it never forks the file) and applies
a few small, inspectable transforms:

1. **Date window** — catalog queries default to a trailing-30-day window, which returns
   nothing against a static local export. `ftk` retargets the window to the latest
   period present in the data. Override with `--start` / `--end`.
2. **`decimal` → `real`** — a few catalog queries use `decimal()` / `todecimal()`
   literals. The hub's cost columns are typed `real`; ADX silently coerces the mix, but
   the emulator (stricter) rejects it, so `ftk` normalizes `decimal(N)`→`real(N)` and
   `todecimal(x)`→`toreal(x)`.
3. **Cross-database prefix** — the rare catalog query that explicitly names
   `database('Ingestion').` is normalized for the local default-database context.
4. **`project-away` tolerance** — a few catalog queries `project-away` a column that
   exists in a different hub schema version but not this one (for example `x_InvoiceId`,
   which the v1.2 transform folds into the FOCUS-standard `InvoiceId`). `project-away`
   errors on unknown columns, so `ftk` drops any such name from the list and the query
   still runs. The local schema is correct; this only keeps version-loose catalog
   queries portable.

These adaptations are **local-only conveniences**. The upstream catalog files are
unchanged and run as-is against a real hub.

## What the local stack does NOT have (vs a deployed hub)

| Hub component | Local |
|---------------|-------|
| Azure Data Factory (blob trigger → convert → ingest) | Replaced by `scripts/ingest.ps1`. Exports must already be FOCUS Parquet — no CSV-to-Parquet convert step. |
| ADLS storage (msexports / ingestion containers) | Local `export/` folder + raw tables. |
| Bicep / ARM deployment | Not needed — `docker compose` (`make up`). |
| Power BI binding | Not wired locally; use `ftk.ps1 ... --format csv`, or see `notes/dashboard.md`. |
| Multi-user / TLS / auth | None. Single developer, local only. |

There is **no** local Azure Data Factory emulator. Data Factory in a hub is only
orchestration glue and carries no analytic IP, so the local stack replaces it with the
ingest script rather than emulating it.

## IP reuse, at a glance

| FinOps Toolkit component | Local |
|--------------------------|-------|
| `IngestionSetup_v1_2.kql` (raw tables, update policies, `*_transform_v1_2()`) | Loaded verbatim into the `Ingestion` database |
| `HubSetup_v1_2.kql` (hub view functions + UDFs) | Loaded verbatim into the `Hub` database |
| Open-data reference CSVs | Loaded as-is |
| Query catalog (`src/queries/catalog/*.kql`, agent-skill subset) | Run as-is, with the four on-read adaptations above |
| Data Factory orchestration | Replaced by `scripts/ingest.ps1` |
| ADLS storage | Replaced by `export/` + raw tables |
| Bicep / ARM deploy | Not needed locally |

**Net: essentially all of the analytic IP (transforms + hub functions + open data +
catalog queries) is reused; only cloud-orchestration glue is reimplemented locally.**
