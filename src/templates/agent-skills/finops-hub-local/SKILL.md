---
name: finops-hub-local
description: This skill should be used when the user wants to run FinOps hub cost analytics LOCALLY without an Azure deployment — e.g. "local FinOps hub", "FinOps hub local", "Kustainer", "Kusto emulator", "ftklocal", "run FinOps queries locally", "analyze FOCUS cost exports offline", "query cost parquet locally", "local cost analysis", or "FinOps toolkit without Azure". It drives a local Kusto emulator that runs the FinOps Toolkit's KQL analytics (the same Costs/Prices/Transactions functions a deployed hub exposes) against FOCUS parquet exports on disk. DO NOT use it to deploy Azure resources, provision infrastructure, or query a live Azure Data Explorer / Fabric cluster — for those, use the `finops-toolkit` skill.
license: MIT
compatibility: Requires Docker and PowerShell 7+. Runs a local Kusto emulator container — no Azure subscription, Azure MCP Server, or cloud cluster required. FOCUS exports must already be Parquet.
metadata:
  author: microsoft
  version: "1.0"
---

# FinOps hub (local)

Run the FinOps Toolkit's full KQL cost-analytics stack **locally**, against a Kusto
emulator (Docker) instead of a deployed Azure Data Explorer or Microsoft Fabric
cluster. The analytic IP is identical — the same `IngestionSetup` / `HubSetup` KQL,
the same hub view functions (`Costs`, `Prices`, `Transactions`, and their `*_v1_2`
variants), the same open data, and the same query catalog — so cost analysis works
offline on a developer machine. Only the cloud-orchestration glue (Data Factory,
storage, deployment) is replaced by local scripts.

The tooling lives in `src/templates/finops-hub-local/`. Run the commands below from
that directory.

## When to invoke

- The user has FOCUS cost exports (Parquet) and wants to query them locally.
- The user wants to develop or test FinOps hub KQL without standing up Azure.
- The user asks for "the local FinOps hub", "ftklocal", "Kustainer", or offline cost analytics.

Do **not** invoke for deploying or querying a real Azure hub — route those to the
`finops-toolkit` skill.

## Topology (so queries are written correctly)

The local stack mirrors a real hub's **two-database** layout:

| Database | Holds | You query it for |
|----------|-------|------------------|
| `Ingestion` | Raw tables (`Costs_raw`, `Prices_raw`), the `*_transform_v1_2()` functions, and the final tables (`Costs_final_v1_2`, `Prices_final_v1_2`) | Ingestion/transform internals, parity checks |
| `Hub` | The hub **view functions** (`Costs`, `Prices`, `Transactions`, `Costs_v1_2`, `Prices_v1_2`, …) which read `database('Ingestion').*` | All analytics — this is the default query database |

The cross-database references (`database('Ingestion').*`) inside the Hub functions
resolve in the emulator exactly as they do in ADX. The CLI defaults to the `Hub`
database.

## Prerequisites

- Docker (the emulator runs as a container via `docker compose`).
- PowerShell 7+ (`pwsh`) — all tooling is PowerShell; there are no Python dependencies.
- FOCUS cost exports as **Parquet**, staged under `export/` (see the staging contract
  in `src/templates/finops-hub-local/notes/staging-contract.md`).

## Quickstart

```bash
# from src/templates/finops-hub-local/
cp .env.example .env            # 1. configure (HOST_PORT, MEM_LIMIT, EXPORT_DIR)
make up                         # 2. start the emulator; blocks until healthcheck passes
make load-ftk-kql               # 3. create Ingestion + Hub, load FTK KQL + open data (idempotent)
make ingest                     # 4. bulk-ingest the Parquet exports under export/
pwsh scripts/ftk.ps1 query "Costs() | summarize TotalEffectiveCost = sum(EffectiveCost) by ServiceName | top 10 by TotalEffectiveCost"
```

## Task routing

| Task | Run this |
|------|----------|
| Start / stop the emulator | `make up` / `make down` (data preserved); `make nuke` (destructive reset) |
| Load the analytics schema + open data | `make load-ftk-kql` (idempotent; safe to re-run) |
| Ingest Parquet exports | `make ingest` (or `pwsh scripts/ingest.ps1`); scope/period subsets: `make ingest SCOPE=<scope> PERIOD=<YYYYMMDD-YYYYMMDD>` |
| Check what's been ingested | `make ingest-status` |
| Run an ad-hoc KQL query | `pwsh scripts/ftk.ps1 query "<kql>"` (default database `Hub`) |
| List the reusable query catalog | `pwsh scripts/ftk.ps1 list` |
| Run a named catalog query | `pwsh scripts/ftk.ps1 run <name>` (add `--format csv`, `--start`/`--end`) |
| Verify transform parity | `make parity` (exit 0 iff all checks pass) |
| Recover a Prices backfill OOM | `make chunked-prices-backfill` (per-extent fallback) |
| See all targets | `make help` |

The `ftk.ps1 run` command reuses the published FinOps Toolkit query catalog **in
place** (it never forks the `.kql` files). It applies a few small, inspectable
on-read adaptations so version-loose catalog queries run against the emulator — see
`references/local-vs-remote.md`. There is **no** new KQL in this skill; all analytic
logic is upstream FinOps Toolkit.

## Common queries

All examples use `Costs_v1_2()` — the Hub view function. Substitute `Costs_final_v1_2`
(in the `Ingestion` database) for the un-enriched final table. Results vary with the
data you ingested; if `Costs_v1_2() | count` returns 0, run `make ingest` first.

```kql
// Top 10 services by effective cost
Costs_v1_2()
| summarize TotalEffectiveCost = sum(EffectiveCost) by ServiceName
| top 10 by TotalEffectiveCost
```

```kql
// Monthly cost trend
Costs_v1_2()
| summarize MonthlyCost = sum(EffectiveCost) by Month = monthstring(ChargePeriodStart)
| order by Month asc
```

```kql
// Top 20 most expensive resources
Costs_v1_2()
| summarize TotalCost = sum(EffectiveCost), BilledCost = sum(BilledCost)
  by ResourceId, ResourceName, ServiceName, x_ResourceGroupName
| top 20 by TotalCost
```

```kql
// Subscription-level cost summary
Costs_v1_2()
| summarize EffectiveCost = sum(EffectiveCost), BilledCost = sum(BilledCost)
  by SubAccountId, SubAccountName
| order by EffectiveCost desc
```

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Emulator won't start; port in use | Another process holds `HOST_PORT` (default 8082). Change `HOST_PORT` in `.env`, then `make up`. |
| Container OOM during the Prices backfill | The single-pass `Prices_transform_v1_2()` exceeds memory on large datasets. Keep `MEM_LIMIT=16g` (the `.env.example` default); ingest now chunks large tables automatically, and `make chunked-prices-backfill` is the manual recovery. |
| `Costs_v1_2() \| count` returns 0 after load | The schema is loaded but no data is ingested yet. Run `make ingest`. |
| Database doesn't appear after `make up` | Emulator metadata can need a clean reset between image versions — `make nuke && make up && make load-ftk-kql`. |
| Ingest aborts: "checksum mismatch … stage under a NEW run-uuid" | A corrected file was re-staged under the same run-uuid. This guard prevents silently duplicating cost rows — stage the corrected data under a new run-uuid for the same scope/type/period (it supersedes the old run). |

## Limits and non-goals

- **Single user, local only.** No auth, no TLS, no multi-tenancy.
- **No Azure Data Factory.** Ingest orchestration (blob trigger → convert → ingest) is
  replaced by `scripts/ingest.ps1`. Exports must already be FOCUS Parquet — there is no
  CSV-to-Parquet convert step.
- **No deployment.** No Bicep/ARM; the stack is `docker compose`.
- **Not a production hub.** Use it for local analysis and KQL development. For a real
  hub (scale, Power BI, multi-user, AAD), deploy with the `finops-toolkit` skill.

## References

- `references/local-vs-remote.md` — what is identical vs adapted between a deployed hub
  and the local stack (connection, the on-read query adaptations, the IP-reuse map).
- `src/templates/finops-hub-local/notes/staging-contract.md` — the data-in contract for `export/`.
- `src/templates/finops-hub-local/notes/dashboard.md` — querying the local Hub from the ADX dashboard / CLI.
