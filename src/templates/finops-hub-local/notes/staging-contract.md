# ftklocal staging contract

This document defines the data-in story for ftklocal: how Cost Management exports are
configured (Part 1) and how the resulting parquet files are staged locally for ingestion
into the Kusto emulator (Part 2).

---

## Part 1 — Export configuration (Azure-only)

### Honest design constraint

Cost Management exports are **Azure-only**. `New-FinOpsCostExport` writes parquet to an
Azure Storage account; there is no local export mode. Export _configuration_ lives in Azure;
ftklocal _consumes_ the parquet that configuration produces. No Azure export was created as
part of authoring this document.

### Relevant PowerShell cmdlets

All three cmdlets are part of the FinOps Toolkit PowerShell module under
`src/powershell/Public/`.

---

#### `New-FinOpsCostExport`

**File:** `src/powershell/Public/New-FinOpsCostExport.ps1`

Creates a Cost Management export that writes FOCUS parquet to Azure Storage.

| Parameter                 | Required | Notes                                                                                                                                  |
| ------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `-Name`                   | Yes      | Unique name within the scope.                                                                                                          |
| `-Scope`                  | Yes      | Azure resource ID of the billing scope (subscription, billing account, etc.).                                                          |
| `-Dataset`                | No       | Default: `FocusCost`. Use `FocusCost` for cost data or `PriceSheet` for prices.                                                        |
| `-DatasetVersion`         | No       | Default: `1.2-preview` (FocusCost). Use `1.2-preview` to get the latest FOCUS schema.                                                  |
| `-Format`                 | No       | Default: `Csv`. **Set to `Parquet`** for ftklocal (ingest.ps1 expects parquet).                                                        |
| `-CompressionMode`        | No       | Default: `None`. `Snappy` is also accepted but adds a decompression step not tested with ftklocal.                                     |
| `-StorageAccountId`       | Yes      | Resource ID of the target Azure Storage account.                                                                                       |
| `-StorageContainer`       | No       | Default: `cost-management`. Use `msexports` to match hub conventions, or any container for ftklocal staging.                           |
| `-StoragePath`            | No       | Subfolder path prefix within the container. Defaults to the scope ID.                                                                  |
| `-DoNotPartition`         | No       | Omit this flag (leave partitioning **enabled**). Partitioning is recommended for reliability.                                          |
| `-DoNotOverwrite`         | No       | Default: overwrite enabled. For ftklocal, overwrite is acceptable; for FinOps hubs, use `-DoNotOverwrite` to simplify troubleshooting. |
| `-Monthly`                | No       | Monthly cadence (mutually exclusive with `-OneTime`).                                                                                  |
| `-OneTime`                | No       | Single run over an explicit date range.                                                                                                |
| `-StartDate` / `-EndDate` | No       | Date range for the export. Defaults for scheduled and one-time differ; see cmdlet help.                                                |
| `-Backfill`               | No       | Number of prior months to export immediately at creation time (scheduled exports only).                                                |
| `-Execute`                | No       | Run the export once immediately after creation.                                                                                        |

**Minimal FOCUS/Parquet example:**

```powershell
New-FinOpsCostExport `
    -Name 'focus-parquet-monthly' `
    -Scope '/subscriptions/<subscriptionId>' `
    -Dataset FocusCost `
    -DatasetVersion '1.2-preview' `
    -Format Parquet `
    -StorageAccountId '/subscriptions/<subscriptionId>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storageAccount>' `
    -StorageContainer 'msexports' `
    -Monthly
```

---

#### `Get-FinOpsCostExport`

**File:** `src/powershell/Public/Get-FinOpsCostExport.ps1`

Lists or filters existing Cost Management exports for a scope.

| Parameter           | Notes                                                                                                                                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-Scope`            | Azure resource ID of the scope. Defaults to current Az context subscription.                                                                                                                                                        |
| `-Name`             | Filter by export name. Supports wildcards.                                                                                                                                                                                          |
| `-Dataset`          | Filter by dataset type (e.g., `FocusCost`, `PriceSheet`).                                                                                                                                                                           |
| `-DatasetVersion`   | Filter by schema version.                                                                                                                                                                                                           |
| `-StorageAccountId` | Filter by destination storage account.                                                                                                                                                                                              |
| `-StorageContainer` | Filter by container name. Supports wildcards.                                                                                                                                                                                       |
| `-RunHistory`       | Switch. When present, the API response is expanded to include run history for each export. This is the enumeration primitive a future auto-download bridge (T-5000.9) would use to discover available runs and their storage paths. |

**Enumerate run history (future auto-bridge use):**

```powershell
Get-FinOpsCostExport -Scope '/subscriptions/<subscriptionId>' -Dataset FocusCost -RunHistory
```

---

#### `Start-FinOpsCostExport`

**File:** `src/powershell/Public/Start-FinOpsCostExport.ps1`

Triggers an on-demand run of an existing export using the Cost Management Run API.

| Parameter                 | Notes                                                           |
| ------------------------- | --------------------------------------------------------------- |
| `-Name`                   | Required. Name of the export to run.                            |
| `-Scope`                  | Azure resource ID. Defaults to current Az context subscription. |
| `-StartDate` / `-EndDate` | Optional date range override.                                   |
| `-Backfill`               | Number of prior months to run in sequence.                      |

---

### Auto-download bridge (deferred)

The automatic storage-to-local-folder sync is **deferred** and tracked in **T-5000.9**. In
v1, parquet files are staged manually (see Part 2). `Get-FinOpsCostExport -RunHistory` is
the intended enumeration primitive for that future bridge.

---

## Part 2 — Local staging contract

### Overview

`ingest.ps1` walks a local directory tree and ingests parquet files into the Kusto emulator.
The contract below is the exact interface that script expects. It applies regardless of where
the parquet originated.

### Folder layout

```
export/
└── <scope>/
    └── <type>/
        └── <period>/
            ├── <run-uuid>/
            │   ├── manifest.json
            │   └── *.parquet
            └── <run-uuid>/          ← older run; superseded if present
                ├── manifest.json
                └── *.parquet
```

- **`export/`** — root staging directory. Default: `export/` relative to the ftklocal
  checkout root. Override via the `EXPORT_DIR` environment variable or `.env` file.
  (`ingest.ps1`, `Get-ExportDir`, lines 41–51.)
- **`<scope>`** — a short, user-defined label for the billing scope (e.g., `ea`,
  `sub-prod`, `mca-<billingAccountId>`). This becomes the `scope` column in
  `Ingest_Manifest`.
- **`<type>`** — dataset type token. Must be a key in `$script:DatasetTableMap`
  (`ingest.ps1`, lines 59–62). See [Dataset type tokens](#dataset-type-tokens) below.
- **`<period>`** — export billing period in `YYYYMMDD-YYYYMMDD` format
  (e.g., `20260501-20260531`). Must match this format; it becomes the `period` column.
- **`<run-uuid>`** — a UUID that identifies one export run. Multiple run directories
  under the same `(scope, type, period)` are allowed; `ingest.ps1` selects only the
  latest. Becomes `run_uuid` in `Ingest_Manifest`.

### Dataset type tokens

Defined in `$script:DatasetTableMap` at `ingest.ps1` lines 59–62:

| Token            | Raw table    | Ingestion mapping    | Cost Management dataset |
| ---------------- | ------------ | -------------------- | ----------------------- |
| `ms--focus-cost` | `Costs_raw`  | `Costs_raw_mapping`  | `FocusCost`             |
| `ms--pricesheet` | `Prices_raw` | `Prices_raw_mapping` | `PriceSheet`            |

Any directory name under `<scope>/` that is not one of these tokens is silently skipped
with a warning (`ingest.ps1`, lines 248–252).

### `manifest.json` per run

Each `<run-uuid>/` directory must contain a `manifest.json` file. The script reads
this file in `Read-RunManifest` (`ingest.ps1`, lines 209–215) to obtain sort and
row-count metadata. Fields consumed by `ingest.ps1`:

| JSON path               | Required    | Purpose                                                           |
| ----------------------- | ----------- | ----------------------------------------------------------------- |
| `runInfo.submittedTime` | Recommended | Primary sort key for latest-run selection. ISO 8601 string.       |
| `runInfo.createdDate`   | Fallback    | Used when `submittedTime` is absent.                              |
| `dataRowCount`          | Recommended | Total expected row count for the run (shown in the plan summary). |
| `blobs[].blobName`      | Recommended | Matched by filename suffix to resolve per-file row counts.        |
| `blobs[].dataRowCount`  | Recommended | Expected rows for each parquet file (used in verify summary).     |

**Minimum viable manifest for manual staging:**

```json
{
  "runInfo": {
    "submittedTime": "<ISO-8601-timestamp>",
    "runId": "<run-uuid>"
  },
  "dataRowCount": <total-row-count>,
  "blobs": [
    {
      "blobName": "<any-prefix>/<file-name>.parquet",
      "dataRowCount": <per-file-row-count>
    }
  ]
}
```

A manifest.json produced directly by Cost Management (from an `msexports/` export) already
contains all these fields and can be used without modification.

### Parquet files

One or more `.parquet` files in the run directory. File names must match the `blobName`
suffix pattern in `manifest.json` for per-file row counts to resolve correctly, though
mismatches are tolerated (the per-file count defaults to 0; the run is still ingested).
Files are sorted lexicographically by name before ingest (`ingest.ps1`,
`Sort-ByNameOrdinal`, lines 102–107 and 273).

### Latest-run selection

For each `(scope, type, period)` triple, `ingest.ps1` collects all run directories that
contain a valid `manifest.json`, then picks the **one latest run** using a three-key sort
(ascending): `submittedTime` → `LastWriteTimeUtc` → directory name ordinal. The last entry
after sorting is the winner. (`ingest.ps1`, `Build-Plan`, lines 269–272.)

All other runs in the same `(scope, type, period)` are **superseded**. Their previously
ingested extents are dropped from the raw table and their rows are removed from
`Ingest_Manifest` before the winning run is ingested. (`ingest.ps1`,
`Drop-SupersededExtents`, lines 571–613.)

### Idempotency via `Ingest_Manifest`

Ingest is idempotent at the file level. Before ingesting a parquet file, `ingest.ps1`
looks up the composite key `(scope, export_type, period, run_uuid, file_name)` in the
`Ingest_Manifest` table. If the key exists and the stored SHA-256 checksum matches the
file, the file is skipped. (`ingest.ps1`, lines 741–748.)

`Ingest_Manifest` schema:

| Column            | Type     | Notes                                                 |
| ----------------- | -------- | ----------------------------------------------------- |
| `scope`           | string   | Matches `<scope>` folder name.                        |
| `export_type`     | string   | Matches `<type>` folder name.                         |
| `period`          | string   | Matches `<period>` folder name.                       |
| `run_uuid`        | string   | Matches `<run-uuid>` folder name.                     |
| `file_name`       | string   | Parquet file name (base name only).                   |
| `file_size`       | long     | File size in bytes at ingest time.                    |
| `rows_ingested`   | long     | Expected rows (from manifest, or 0 if not available). |
| `checksum_sha256` | string   | SHA-256 hex of the parquet file.                      |
| `ingested_at`     | datetime | UTC timestamp of ingest.                              |

Defined at `ingest.ps1`, `Initialize-IngestManifestTable` / `Insert-ManifestRow`
(lines 299–351).

### Overwrite semantics summary

| Condition                                                           | Behavior                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Same `(scope, type, period, run-uuid)`, same file checksum          | **Skip.** File is already in `Ingest_Manifest` with a matching SHA-256; no ingest, no new row. (`ingest.ps1` lines 744–748.)                                                                                                                                                                     |
| Same `(scope, type, period, run-uuid)`, **different** file checksum | **Double-ingest — do not do this.** The old `Ingest_Manifest` row is not deleted and the prior extents are not dropped; a second ingest call is issued and a second `Ingest_Manifest` row is appended for the same key. The raw table will contain duplicate data. (`ingest.ps1` lines 744–776.) |
| Same `(scope, type, period)`, **new** `run-uuid`                    | **Safe replace.** `Drop-SupersededExtents` drops extents tagged with older run-uuids from the raw table and deletes their `Ingest_Manifest` rows before the new run is ingested. (`ingest.ps1` lines 571–613.)                                                                                   |
| Different `(scope, type, period)`                                   | **Independent.** No interaction with other tuples.                                                                                                                                                                                                                                               |

> **How to correct or replace data:** stage the replacement parquet under a **new `<run-uuid>`**
> directory for the same `(scope, type, period)`. Give it a `manifest.json` with a later
> `runInfo.submittedTime` than the run being replaced. `ingest.ps1` will then select it as
> the latest run, drop the old run's extents and manifest rows, and ingest the new files
> cleanly. Never mutate files in an already-ingested run directory — that path has no safe
> overwrite; it only appends a duplicate.

---

## Source modes — mapping to the local contract

### Mode A: `msexports/` container (no hub deployed)

When FinOps hubs is **not** deployed, Cost Management exports write directly to the
`msexports` Azure Storage container. The raw container path is:

```
msexports/{path}/{date-range}/{export-name}/{export-time}/{guid}/{file}
```

The `manifest.json` produced here contains `exportConfig.type` (dataset),
`runInfo.submittedTime`, `runInfo.runId`, and `blobs[].blobName` / `blobs[].dataRowCount`.
All fields that `ingest.ps1` consumes are present.

**To use with ftklocal (v1 — manual staging):**

1. Create the staging directory: `export/<scope>/ms--focus-cost/<YYYYMMDD-YYYYMMDD>/<run-uuid>/`
2. Copy the parquet file(s) from the `msexports` run folder into this directory.
3. Copy the `manifest.json` from the same run folder. No field changes are needed.
4. Run `make ingest` (or `pwsh scripts/ingest.ps1`).

**Notes:**

- If the export was configured with `-Format Csv` (the default), the data is CSV, not
  parquet, and cannot be ingested directly. **Always configure `-Format Parquet`.**
- The dataset type token (`ms--focus-cost`) corresponds to the `FocusCost` export type.
  Cost Management uses a different name in `exportConfig.type` (e.g., `FocusCost`); the
  `ms--focus-cost` token is ftklocal's local convention for the staging directory name.

### Mode B: `ingestion/` container (hub already deployed)

When FinOps hubs **is** deployed, the hub ETL pipeline converts raw `msexports/` data into
normalized FOCUS parquet and writes it to the `ingestion/` container:

```
ingestion/{dataset}/{date-folder-path}/{scope-id-path}/{ingestion-id}__{original-file-name}.parquet
```

The `ingestion/` parquet has already been normalized by the hub's FTK transforms (including
`x_SourceValues` and other derived columns). **This mode maps most cleanly to ftklocal**
because:

- The parquet schema matches what the FTK KQL transform functions loaded via
  `load-ftk-kql.ps1` expect.
- Row counts and manifest metadata are already reconciled by the hub pipeline.

**To use with ftklocal (v1 — manual staging):**

1. Identify the relevant `ingestion/` run folder(s) in Azure Storage.
2. Stage files: `export/<scope>/ms--focus-cost/<YYYYMMDD-YYYYMMDD>/<run-uuid>/`
3. Construct a `manifest.json` (minimum viable form above) referencing the parquet files.
4. Run `make ingest`.

### Auto-download (deferred — T-5000.9)

In v1, **all storage-to-local staging is manual**. The automatic bridge that would use
`Get-FinOpsCostExport -RunHistory` to enumerate runs, download parquet from the storage
container, and arrange files into the `export/{scope}/{type}/{period}/{run}/` layout is
tracked in **T-5000.9** and is not implemented in v1.

---

## Worked example directory tree

The following illustrates a fully staged `export/` tree for two scopes and two dataset types:

```
export/
├── ea/
│   ├── ms--focus-cost/
│   │   └── 20260501-20260531/
│   │       └── a1b2c3d4-0000-0000-0000-000000000001/
│   │           ├── manifest.json
│   │           └── focus_2026_05.parquet
│   └── ms--pricesheet/
│       └── 20260501-20260531/
│           └── a1b2c3d4-0000-0000-0000-000000000002/
│               ├── manifest.json
│               └── pricesheet_2026_05.parquet
└── sub-prod/
    └── ms--focus-cost/
        └── 20260501-20260531/
            ├── a1b2c3d4-0000-0000-0000-000000000003/   ← superseded
            │   ├── manifest.json
            │   └── focus_v1.parquet
            └── a1b2c3d4-0000-0000-0000-000000000004/   ← latest (ingested)
                ├── manifest.json
                └── focus_v2.parquet
```

In this tree, `ingest.ps1` ingests four runs:

- `ea / ms--focus-cost / 20260501-20260531` → one run, ingested into `Costs_raw`.
- `ea / ms--pricesheet / 20260501-20260531` → one run, ingested into `Prices_raw`.
- `sub-prod / ms--focus-cost / 20260501-20260531` → two runs; the `_004` run is latest,
  `_003` is superseded and its extents are dropped.

---

## gitignore note

The `export/` directory is already listed in
`src/templates/finops-hub-local/.gitignore` and is never committed to the repository.
All staged parquet and manifest files remain local only.
