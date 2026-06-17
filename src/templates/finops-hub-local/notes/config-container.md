# Config container — decision record

## Context

A deployed FinOps Hub writes two artifacts to the Azure Storage `config`
container:

| Artifact | Location in storage | Schema |
|---|---|---|
| `settings.json` | `config/settings.json` | `https://aka.ms/finops/hubs/settings-schema` |
| Export schemas | `config/schemas/*.json` | Internal column-typing contract |

The `settings.json` file drives **scope registration** and **retention
configuration** for the Azure Data Factory (ADF) orchestration layer.  The
`config/schemas/*.json` files drive the ADF **msexports → ingestion
conversion** step — column typing and normalization of the raw Cost Management
CSV exports into Parquet.

ftklocal does not run ADF.  The question this note answers is: which of these
artifacts does ftklocal need, and when?

---

## Mode A — ingestion container (already-converted Parquet) ✅ v1 default

**What ftklocal does today.**

ftklocal ingests the already-converted `ingestion/`-container Parquet directly
into Kusto (`Costs_raw`, `Prices_raw`).  At this point the msexports → ingestion
conversion has already been performed by ADF in the deployed hub.

**Config container requirement:** none.

- `settings.json` — not required for the msexports → ingestion conversion path
  (that is an ADF concern).  However, `load-ftk-kql.ps1` does optionally read a
  local `settings.json` for one value — `retention.raw.days` — to set the Kusto
  raw-table soft-delete policy via the `$$rawRetentionInDays$$` macro; it falls
  back to 3650 days when the file is absent or when `raw.days` is 0.  The
  scopes array in `settings.json` is an ADF concern and is not read by the
  ADX/KQL layer.  See `settings.example.json` and `scripts/settings.ps1`.
- `config/schemas/*.json` — not required.  The Parquet files in the ingestion
  container are already normalized; the column-typing step that uses the schemas
  has already run.

---

## Mode B — msexports container (raw Cost Management exports) 🔮 future / deferred

**Not implemented in v1.**

If ftklocal were extended to ingest directly from the raw Cost Management CSV
exports (`msexports/` container), it would need to perform the same
msexports → ingestion conversion that ADF does.  That conversion uses the schema
files to type, deduplicate, and normalize each export.

**Config container requirement:**

- `config/schemas/*.json` — required for the conversion step.  **These must
  always be sourced from the in-repo copies** at
  `src/templates/finops-hub/modules/Microsoft.CostManagement/Exports/schemas/`
  (e.g. `focuscost_1.2.json`, `focuscost_1.2-preview.json`,
  `pricesheet_2023-05-01_ea.json`).  Never copy schemas from a customer's
  storage; the in-repo versions are the canonical, version-controlled
  definitions.
- `settings.json` — would be needed to resolve the scope list and retention
  parameters for the conversion orchestration.

**Status:** the full local msexports converter is deferred to the bridge work
tracked in T-5000.9.  Mode A remains the v1 happy path.

---

## ADX / KQL layer — `config/schemas/*.json` not consumed; `settings.json` read by `load-ftk-kql.ps1` for one value

The `config/schemas/*.json` files (the msexports → ingestion column-typing
schemas) are not consumed by any component of the ADX/KQL layer.  `settings.json`
is partially consumed: `load-ftk-kql.ps1` optionally reads it for
`retention.raw.days` only; everything else reads neither.  Evidence:

- **`scripts/load-ftk-kql.ps1`** — optionally reads a local `settings.json` for
  `retention.raw.days` (with a 3650-day fallback) and passes it to the
  `$$rawRetentionInDays$$` macro in the Ingestion bundle.  It does not read
  scopes, version, or any other `settings.json` field.  It does not read
  `config/schemas/*.json` at all.
- **`scripts/ftk.ps1`** — reads neither `settings.json` nor
  `config/schemas/*.json`.  It does use the word "schema" extensively, but only
  for querying live Kusto table schemas via KQL (`.show table ... cslschema`,
  `getschema`) — not for any on-disk config file.
- **Hub / Ingestion KQL queries** — the `.kql` files assembled by
  `src/templates/finops-hub/.build.config` `combineKql` bundles contain no
  reference to `settings.json` or `config/schemas/*.json`.
- The schema files in
  `src/templates/finops-hub/modules/Microsoft.CostManagement/Exports/schemas/`
  are consumed by the ADF pipeline, not by KQL.

For v1, `config/schemas/*.json` is therefore **not required** (the
msexports → ingestion conversion is an ADF concern).  `settings.json` is
**optional** — absent means 3650-day raw retention; present lets the operator
set it explicitly.

> **Local analysis note:** `retention.raw.days` in `settings.json` drives the
> Kusto raw-table soft-delete window (the `$$rawRetentionInDays$$` macro in
> `load-ftk-kql.ps1`).  Keep this value high (3650 days is the default) for
> local analysis — unlike Azure Storage, local raw tables ARE the source data;
> early soft-deletion means re-running a full ingest to recover.
