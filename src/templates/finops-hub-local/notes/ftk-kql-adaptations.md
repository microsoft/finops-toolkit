# FTK KQL adaptations for the local stack

There are **two distinct adaptation layers** in the local stack. This document covers
both.

| Layer         | Where it runs                                            | Purpose                                                                   |
| ------------- | -------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Load-time** | `scripts/load-ftk-kql.ps1`                               | Loads upstream FTK KQL into the emulator at setup time (idempotent).      |
| **On-read**   | `scripts/ftk.ps1` `Convert-CatalogQuery` (lines 341–382) | Adapts catalog `.kql` files at query time before posting to the emulator. |

The upstream KQL scripts live in
`src/templates/finops-hub/modules/Microsoft.FinOpsHubs/Analytics/scripts/`.

**Design constraint:** only two categories of adaptation are permitted in the load-time
layer:

1. Replace ARM/Bicep deployment-time templating macros with concrete local values.
2. Adjust for the two-database topology that the local stack preserves (see below).

No transform logic is modified. If an upstream FTK function has a bug, it is logged
as a gap — not patched locally.

---

## Topology note

FTK deploys to ADX as a **two-database** system: an `Ingestion` database (raw + transform

- final tables) and a `Hub` database (view functions). The local stack preserves this
  topology exactly — the emulator runs both `Ingestion` and `Hub` databases, and
  `database('Ingestion').*` cross-references inside Hub view functions resolve in the
  emulator the same way they do in ADX.

Earlier prototype notes described collapsing these into a single local `FtkLocal` database.
That design was superseded. The current stack uses the two-database topology throughout.

---

## Adaptation 1 — Macro substitution: `$$rawRetentionInDays$$` → `3650`

**File:** `IngestionSetup_RawTables.kql`

`$$rawRetentionInDays$$` is the FTK Bicep deployment-time macro substituted by the
ARM template at hub-deploy time. Kustainer rejects the literal macro syntax with a
`SyntaxException`. The loader substitutes `3650` (10 years — effectively "never
delete" for a local dev database).

**Implementation:** `scripts/load-ftk-kql.ps1` applies the substitution via a
`subst_macros` transform pass on `IngestionSetup_RawTables.kql` only.

---

## Adaptation 2 — Two-database cross-references pass through unmodified

**Files:** `HubSetup_v1_2.kql`, `HubSetup_OpenData.kql`

No rewrite is needed. The local emulator runs both `Ingestion` and `Hub` databases,
so `database('Ingestion').X` inside Hub view functions resolves correctly — the same
as in a real ADX deployment. The loader runs `HubSetup_v1_2.kql` and
`HubSetup_OpenData.kql` against the `Hub` database without modification.

---

## Adaptation 3 — Empty v1_0 final-table stubs

**Source:** synthesized in-memory by `scripts/load-ftk-kql.ps1`

The v1_2 view functions in `HubSetup_v1_2.kql` union v1_2 final tables with v1_0
final tables for backward compatibility. Kustainer eagerly resolves function bodies
at creation time, so without the v1_0 tables present,
`.create-or-alter function Costs_v1_2()` fails with `General_BadRequest`.

The loader extracts only the five `.create-merge table X_final_v1_0 (...)` DDL blocks
from `IngestionSetup_v1_0.kql` — no transforms, no update policies, no ingestion
mappings. The resulting tables are empty and serve only to satisfy the eager-compilation
check.

Tables created (empty stubs):

- `Costs_final_v1_0`
- `Prices_final_v1_0`
- `CommitmentDiscountUsage_final_v1_0`
- `Recommendations_final_v1_0`
- `Transactions_final_v1_0`

Because the v1_0 tables are empty, union queries are semantically identical to
v1_2-only queries — no data is hidden or duplicated.

---

## Adaptation 4 — Splitter: trailing inter-command comments stripped

This is a feature of the loader's command splitter, not a modification to FTK content.

FTK KQL scripts intersperse top-level commands with `//` comment lines between them.
The splitter accumulates lines into commands until the next line that starts a new
command (`^\.[a-z]`). Without special handling, the trailing `// <comment>` line before
the next command gets glued onto the end of the preceding command body, causing
Kustainer's management endpoint to reject it with `General_BadRequest`.

The splitter strips trailing blank lines and comment-only lines from each accumulated
command before posting. The commands themselves are submitted verbatim. This resolved
all 31 false failures observed across `Common.kql`, `IngestionSetup_HubInfra.kql`,
`IngestionSetup_v1_2.kql`, `HubSetup_v1_2.kql`, and `HubSetup_OpenData.kql`.

---

## Adaptation 5 — Database creation prefix

Not in any FTK script — the loader adds this as a prerequisite before loading any
FTK content. A clean checkout has no databases; the loader creates `Ingestion` and
`Hub` with their `persist` paths matching what `docker-compose.yml` mounts at
`/kustodata`. On re-runs, the `EntityNameAlreadyExistsException` response (HTTP 400)
is treated as "already exists — idempotent OK".

---

## Adaptation 6 — Open-data CSV column mapping

**Files:** `PricingUnits.csv`, `Regions.csv`, `ResourceTypes.csv`, `Services.csv`
(from `src/open-data/`)

The open-data CSV files were generated against an older table schema than the one
declared in `IngestionSetup_HubInfra.kql`. The HubInfra DDL uses FOCUS-aligned column
names (`x_PricingUnitDescription`, `x_ResourceType`, etc.), but the CSVs still use
legacy raw names (`UnitOfMeasure`, `ResourceType`, etc.). In a production hub
deployment an Azure Function applies this rename; that function is not part of any KQL
script.

The loader applies the same rename at load time. Key mappings:

| Table           | CSV column         | Table column               |
| --------------- | ------------------ | -------------------------- |
| `PricingUnits`  | `UnitOfMeasure`    | `x_PricingUnitDescription` |
| `PricingUnits`  | `PricingBlockSize` | `x_PricingBlockSize`       |
| `PricingUnits`  | `DistinctUnits`    | `PricingUnit`              |
| `Regions`       | `OriginalValue`    | `ResourceLocation`         |
| `ResourceTypes` | `ResourceType`     | `x_ResourceType`           |
| `ResourceTypes` | `Icon`             | `IconUri`                  |
| `Services`      | `ConsumedService`  | `x_ConsumedService`        |
| `Services`      | `ResourceType`     | `x_ResourceType`           |
| `Services`      | `PublisherType`    | `x_PublisherCategory`      |
| `Services`      | `Environment`      | `x_Environment`            |
| `Services`      | `ServiceModel`     | `x_ServiceModel`           |

The loader reads each CSV, projects to the target column order, clears the destination
table (idempotency), and ingests inline into the FTK-declared table schema.

---

## Drops: none

Nothing was dropped from the FTK scripts on grounds of "Kustainer doesn't support
this". Streaming ingestion policy commands (`alter table X policy streamingingestion
disable`) were empirically verified to be accepted by Kustainer (HTTP 200). No
`.alter cluster`, managed-identity, EventGrid, or other cluster-level commands appear
in the seven scripts the loader processes.

---

## On-read adapter — `ftk.ps1 run` (`Convert-CatalogQuery`, lines 341–382)

`ftk.ps1 run` adapts catalog `.kql` files at query time before posting them to the
emulator. This is a separate layer from the load-time adaptations above. The function
`Convert-CatalogQuery` applies the following rules in order:

### Rule 1 — Date-window retarget (lines 352–359)

Rewrites `let startDate = ...;` and `let endDate = ...;` bindings in catalog queries
to match the `--start` / `--end` CLI arguments (or the last complete month when no
range is supplied). This lets time-bounded catalog queries work locally without
editing the `.kql` files.

### Rule 1b — `--param` typed-literal override (lines 361–371)

Rewrites any top-level `let <name> = ...;` binding when `--param name=value` is
supplied on the CLI. Values are serialised to KQL typed literals (datetime, timespan,
bool, int, real, or string). Throws if `name` does not match a top-level `let` in the
query (no silent no-ops).

### Rule 2 — `decimal`→`real` normalisation (lines 373–376)

```
todecimal('') → real(null)
todecimal(    → toreal(
decimal(      → real(
```

Kustainer's free image does not support the `decimal` scalar type. The FTK query
catalog uses `decimal()` for monetary columns in some queries. This substitution is
lossless for the numeric range involved and is the verified compatibility fix.

### Rule 3 — Project-away tolerance (lines 378–379)

If a catalog query contains a `project-away` clause and calls a hub view function
(`Costs()`, `Prices()`, `Recommendations()`, or `Transactions()`), the adapter
inspects the live function schema and silently drops any column names from the
`project-away` list that do not exist in the local schema. This prevents errors when
an upstream catalog query projects away a column the local Hub does not yet expose.

### Cross-database references — pass through unmodified

Catalog queries that explicitly reference `database('Ingestion').X` are **not
rewritten**. The two-database topology means `database('Ingestion').*` resolves
correctly in the emulator (Hub functions hold live cross-DB references to Ingestion
final tables). Stripping the prefix would break any catalog query that legitimately
targets an Ingestion table directly. This is consistent with the load-time behaviour
(the Hub KQL bundle is also submitted verbatim).

---

## Documented upstream FTK behavior (not adapted — logged only)

### `.alter table Costs_raw policy update` collision

`IngestionSetup_v1_2.kql` calls `.alter table Costs_raw policy update` twice (once for
the `ActualCosts_raw` chain, once for `AmortizedCosts_raw`). Because `.alter` replaces
rather than merges the policy, the second call overwrites the first. The result is that
only the `AmortizedCosts_raw → AmortizedCosts_transform_v1_2()` chain is active after
loading.

This behavior is identical on ADX and on Kustainer. The local test dataset uses
FOCUS-format exports (not the legacy `ActualCosts`/`AmortizedCosts` format), so this
does not affect parity results. Documented here for awareness; not patched locally per
the "no transform modifications" rule.
