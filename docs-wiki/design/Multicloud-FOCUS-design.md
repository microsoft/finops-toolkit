# Design: optional AWS and Google FOCUS ingestion in FinOps hub

> Technical detail for the plan approved in [Multicloud-FOCUS-plan](./Multicloud-FOCUS-plan.md). Based on a reading of the current code in `src/templates/finops-hub`.
> Working branch: `arthursilvany/multicloud-focus`.

---

## 1. The discovery that defines the architecture

The hub **already has** the entire FOCUS → Parquet → ADX pipeline. All that is missing is **delivering the file to the right door**.

The current chain, confirmed in code:

```
Cost Management export
  → writes files + manifest.json to the "msexports" container
    → msexports_ManifestAdded trigger  (BlobEventsTrigger, storagePathEndsWith: 'manifest.json')
      → msexports_ExecuteETL pipeline   (reads the manifest, picks the schema)
        → msexports_ETL_ingestion       (converts to Parquet in the "ingestion" container)
          → ingestion_ManifestAdded trigger
            → ADX / Fabric ingestion pipeline
```

Evidence:

| Fact | File |
| --- | --- |
| Trigger fires **only** on `manifest.json` | `Microsoft.CostManagement/Exports/app.bicep:1712-1728` |
| Same for the ingestion trigger | `Microsoft.FinOpsHubs/Analytics/app.bicep:682-698` |
| FOCUS 1.0 / 1.0r2 / 1.2 schemas already published to the `config` container | `Microsoft.CostManagement/Exports/app.bicep:59-85` |
| Datasets for CSV, **gzip**, and **Parquet** already exist | `Microsoft.CostManagement/Exports/app.bicep:164-254` |

**Design consequence:** do not build a parallel ETL. The AWS/Google connector only has to:

1. copy the FOCUS files from the bucket into `msexports/<provider>/...`;
2. write a compatible `manifest.json` **last**.

From there, everything that already exists works unchanged — including Parquet conversion, retention, and ADX ingestion. Because the trigger only reacts to `manifest.json`, writing the data first and the manifest afterward is safe by construction.

This also settles the format question: AWS delivers FOCUS as `.csv.gz` or `.parquet`, and GCS as `.csv`/`.parquet` — all three are already handled by the `msexports`, `msexports_gzip`, and `msexports_parquet` datasets.

---

## 2. The `manifest.json` contract

Fields actually consumed by `msexports_ExecuteETL` (extracted from the `activity('Read Manifest').output.firstRow.*` expressions):

| Field | Use | Value for AWS/GCP |
| --- | --- | --- |
| `exportConfig.type` | 1st part of the schema file name | `FocusCost` |
| `exportConfig.dataVersion` | 2nd part of the schema file name (and **only** that — see §8/R2) | `1.2-aws` / `1.2-gcp` (see §2.1) |
| `exportConfig.exportName` | logical export name | `aws-focus` / `gcp-focus` |
| `exportConfig.resourceId` | derives the scope (= path segment) | see §2.2 |
| `runInfo.runId` | run identity | GUID generated in the pipeline |
| `runInfo.startDate` | data period | start of the file's month |
| `blobCount` / `blobs[].blobName` | file list | populated by Get Metadata |
| `dataRowCount` | empty-export short-circuit | **omit the property** — never `null` or `0` (see §10) |
| `retention.msexports.days` | cleanup | copy from `settings.json` |
| `additionalColumns`, `translator` | come from the schema file, not the manifest | omit |

The manifest is assembled inside the pipeline (a `Set Variable` activity + a `Copy` with `JsonSink`), not as a static file — its content depends on the run.

### 2.1 How the schema is selected — the extension point

```
schemaFile = toLower(concat(exportDatasetType, '_', exportDatasetVersion, <channel suffix>, '.json'))
```

The `<channel suffix>` (`_ea` / `_mca`) is only applied when `mcaColumnToCheck` is non-null, and that variable is null for `FocusCost` — it is only populated for `pricesheet`, `reservationtransactions`, and `reservationrecommendations`. So for FOCUS the file name is determined **entirely** by two fields we control in the synthetic manifest.

Consequence: publishing `focuscost_1.2-aws.json` and setting `dataVersion: '1.2-aws'` makes the ETL load the correct schema **without a single change to the existing pipeline**. `exportConfig.type`, by contrast, must be exactly `FocusCost` — see §8d.

### 2.2 Value of `exportConfig.resourceId`

Recommended: `/aws/<accountId>` and `/gcp/<projectId>`, **always lowercase** (see §10 — the ADX tag comparison is case-sensitive, and case variations silently duplicate data).

This produces the paths `Costs/2026/08/aws/123456789012/` and `Costs/2026/08/gcp/my-project/`, which are readable and isolated from Azure scope paths. The first segment is the `hubDataset` (`focuscost` → `Costs`), not the `exportDatasetType`. See §8/R1 for the analysis that supports this freedom of format.

---

## 3. New parameters

### `main.bicep` and `modules/hub.bicep`

These follow the `enableInvoiceDownload` pattern exactly (`main.bicep:52-57`).

```bicep
@description('Optional. Enable ingestion of FOCUS cost data exported from Amazon Web Services. Requires an S3 bucket with a FOCUS 1.0 or 1.2 export and an access key stored during deployment. Default: false.')
param enableAwsFocusIngestion bool = false

@description('Optional. Name of the Amazon S3 bucket that contains the FOCUS export. Requires enableAwsFocusIngestion.')
param awsBucketName string = ''

@description('Optional. Path prefix within the S3 bucket where FOCUS files are written. Requires enableAwsFocusIngestion.')
param awsBucketPrefix string = ''

@description('Optional. AWS region of the S3 bucket. Requires enableAwsFocusIngestion.')
param awsRegion string = ''

@description('Optional. AWS access key ID used to read the S3 bucket. Requires enableAwsFocusIngestion.')
param awsAccessKeyId string = ''

@description('Optional. AWS secret access key used to read the S3 bucket. Stored in Key Vault. Requires enableAwsFocusIngestion.')
@secure()
param awsSecretAccessKey string = ''

@description('Optional. FOCUS version of the AWS export. Allowed: 1.0, 1.2. Default: 1.0.')
@allowed(['1.0', '1.2'])
param awsFocusVersion string = '1.0'
```

The Google equivalent uses the names `enableGoogleFocusIngestion`, `googleBucketName`, `googleBucketPrefix`, `googleProjectId`, `googleAccessKeyId`, `googleSecretAccessKey` (GCS HMAC), and `googleFocusVersion`.

Common to both:

```bicep
@description('Optional. Hour of the day (UTC) to collect multicloud FOCUS files. Default: 4.')
@minValue(0)
@maxValue(23)
param multiCloudScheduleHour int = 4
```

**Key design point:** the defaults leave everything off. An existing deployment that runs `main.bicep` without these parameters changes in no way — no new resources, no new cost.

### Telemetry — `modules/hub.bicep`

`telemetryString` (`hub.bicep:206-222`) is limited to 12 characters. Add only two flags:

```bicep
// A = AWS FOCUS ingestion, G = Google FOCUS ingestion
enableAwsFocusIngestion ? 'A' : ''
enableGoogleFocusIngestion ? 'G' : ''
```

---

## 4. Portal UI — `createUiDefinition.json`

Current step structure: `pricing`, `retention`, `recommendations`, `invoices`, `advanced`, `tags`.

Add a `multicloud` step between `invoices` and `advanced`, mirroring the layout of the `invoices` step (`createUiDefinition.json:841-930`):

```
- multicloud  (label: "🆕 Multicloud")
    * multicloudIntro        [Microsoft.Common.TextBlock]
    * enableAws              [Microsoft.Common.CheckBox]
    * aws                    [Microsoft.Common.Section]   visible: [steps('multicloud').enableAws]
        - bucketName         [Microsoft.Common.TextBox]
        - bucketPrefix       [Microsoft.Common.TextBox]
        - region             [Microsoft.Common.TextBox]
        - accessKeyId        [Microsoft.Common.TextBox]
        - secretAccessKey    [Microsoft.Common.PasswordBox]
        - focusVersion       [Microsoft.Common.DropDown]  (1.0 | 1.2)
    * enableGoogle           [Microsoft.Common.CheckBox]
    * google                 [Microsoft.Common.Section]   visible: [steps('multicloud').enableGoogle]
        - (same fields + projectId)
    * schedule               [Microsoft.Common.Section]
    * permissions            [Microsoft.Common.Section]   (text describing the minimum IAM policy)
```

Outputs, in the same style as the existing ones (`createUiDefinition.json:1102`):

```json
"enableAwsFocusIngestion": "[steps('multicloud').enableAws]",
"awsBucketName": "[if(steps('multicloud').enableAws, steps('multicloud').aws.bucketName, '')]",
"awsSecretAccessKey": "[if(steps('multicloud').enableAws, steps('multicloud').aws.secretAccessKey, '')]"
```

The `if(...)` is mandatory: it guarantees that hidden fields never leak stale values into the template — the same pattern already used for `remoteHubStorageUri`/`remoteHubStorageKey`.

Use `Microsoft.Common.PasswordBox` for secrets so they never appear on screen or in portal history.

---

## 5. New modules

Two sibling apps, following the structure of `Microsoft.Billing/Invoices` (the newest and most complete optional app in the repository):

```
modules/Microsoft.FinOpsHubs/AmazonWebServices/
    app.bicep
    metadata.bicep
    README.md
modules/Microsoft.FinOpsHubs/GoogleCloud/
    app.bicep
    metadata.bicep
    README.md
```

Publisher = `Microsoft.FinOpsHubs`, because Microsoft is who publishes the connector. This keeps the resources in the hub's own Data Factory / Key Vault / storage instead of creating a second Data Factory when `publisherIsolation` is enabled in the future (`hub-types.bicep`, `newApp`).

### `app.bicep` header (required repository pattern)

```bicep
import { finOpsToolkitVersion, HubAppProperties, privateRoutingForLinkedServices, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as ExportsMetadata } from '../../Microsoft.CostManagement/Exports/metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.AmazonWebServices'
  version: '$$ftkver$$'
  dependencies: ['Microsoft.FinOpsHubs.Core', 'Microsoft.CostManagement.Exports']
}

@validate(x => isSupportedVersion(x.version, '13.0', ''), 'AWS FOCUS ingestion requires FinOps hubs version 13.0 or higher.')
param core CoreMetadata
```

The dependency on `Microsoft.CostManagement.Exports` is real and not optional: it owns the `msexports` container and the schema files.

### Resources created per app

| Type | Name (AWS) | Name (Google) | Purpose |
| --- | --- | --- | --- |
| Key Vault secret | `aws-secret-access-key` | `gcp-secret-access-key` | via `fx/hub-vault.bicep` |
| Linked service | `aws_s3` | `gcp_storage` | `AmazonS3` / `GoogleCloudStorage` |
| Dataset | `aws_focus_source` | `gcp_focus_source` | `Binary` + `AmazonS3Location` / `GoogleCloudStorageLocation` |
| Dataset | `aws_focus_landing` | `gcp_focus_landing` | `Binary` in the `msexports` container |
| Dataset | `aws_focus_manifest` | `gcp_focus_manifest` | `Json` in the `msexports` container |
| Pipeline | `aws_CollectFocusExport` | `gcp_CollectFocusExport` | copy + generate manifest |
| Trigger | `aws_DailySchedule` | `gcp_DailySchedule` | daily `ScheduleTrigger` |

The linked service uses a Key Vault secret exactly like RemoteHub does (`Microsoft.FinOpsHubs/RemoteHub/app.bicep:88-98`):

```bicep
resource linkedService_awsS3 'linkedservices' = {
  name: 'aws_s3'
  properties: {
    type: 'AmazonS3'
    typeProperties: {
      authenticationType: 'AccessKey'
      accessKeyId: awsAccessKeyId
      secretAccessKey: {
        type: 'AzureKeyVaultSecret'
        store: { referenceName: app.keyVault, type: 'LinkedServiceReference' }
        secretName: awsSecretSecretName
      }
    }
    ...privateRoutingForLinkedServices(app.hub)
  }
}
```

The `...privateRoutingForLinkedServices(app.hub)` spread is not optional — without it the linked service ignores the Managed VNet when the hub runs on a private network.

### `*_CollectFocusExport` pipeline activities

The pipeline is **manifest-driven**, not listing-driven. An earlier draft of this section proposed a `Get Metadata` (`childItems`) listing of the bucket prefix followed by a `Filter`. That approach is wrong and must not be used: in "create new" mode the `data/billing_period=YYYY-MM/` folder accumulates one subfolder per daily refresh, so a recursive listing copies every refresh and duplicates the month's costs. Only the provider's own manifest identifies the current run. See §10, design consequence #2.

The pipeline is invoked once per collection period. A parent pipeline iterates the current and previous month (§10, "Collection window") and calls the child pipeline through `ExecutePipeline`, which also keeps each period in its own variable scope.

1. **Set Run Id** — `@guid()`, used as `runInfo.runId` and as the destination subfolder.
2. **Set Billing Period** — derive `yyyy-MM` from `@addToTime(utcNow(), periodOffsetMonths, 'Month')`.
3. **Load Settings** — `Lookup` on the `config` dataset to read `retention.msexports.days`.
4. **Read Source Manifest** — `Lookup` on the provider manifest (`<prefix>/<exportName>/metadata/billing_period=<period>/<exportName>-Manifest.json`) read **directly from S3/GCS**. This file is never copied into `msexports` — its schema is incompatible with the Cost Management contract (§10, design consequence #1).
5. **Copy FOCUS Files** — `ForEach` over `dataFiles` (parallel) with a binary `Copy` from S3/GCS to `msexports/<provider>/<accountId>/<period>/<runId>/`. Each item is a full `s3://` URI and must have the `s3://<bucket>/` prefix stripped to obtain the object key.
6. **Build Blob List** — `ForEach` (sequential) appending one `{ "blobName": "..." }` entry per copied file. Sequential because `AppendVariable` is not safe inside a parallel `ForEach`. `blobName` is the path **inside the `msexports` container**, matching how the ETL passes it to `msexports_parquet` as `blobPath`.
7. **Build Manifest** — `Set Variable` assembling the JSON contract from §2. Emit `blobCount = length(dataFiles)` and **omit `dataRowCount` entirely**; `exportConfig.resourceId` must be lowercase.
8. **Write Manifest** — `Copy` with a `JsonSink` writing `manifest.json` to the **same folder**, with `dependsOn: Succeeded` on steps 5 and 6.

Step 8 depending on `Succeeded` (not `Completed`) is what guarantees the manifest is never published over a partial copy. Because the manifest lands last, it is also the signal that fires the existing `msexports_ManifestAdded` trigger — no new trigger wiring is needed on the ETL side.

> **Data Factory constraint.** A container activity cannot contain another container activity. A `ForEach` or `Until` nested inside an `If` or `Switch` **deploys successfully but fails at runtime** with `Container activity cannot include another container activity`. Every loop above is therefore top level; conditional behavior is expressed by iterating an empty array (`@if(cond, json('[]'), realArray)`) rather than by wrapping the loop in an `If`.

### Folder structure in `msexports`

```
msexports/
├── aws/<accountId>/<yyyy-MM>/<runId>/{data files, manifest.json}
└── gcp/<projectId>/<yyyy-MM>/<runId>/{data files, manifest.json}
```

The `aws/` and `gcp/` prefixes isolate the sources and avoid collisions with Cost Management scope paths. The `<runId>` subfolder keeps concurrent or repeated runs of the same period from overwriting each other mid-copy; idempotency in the data lake is handled downstream by the `drop-by` tag mechanism described in §10, which keys on the stable `Costs/YYYY/MM/aws/<accountId>` destination rather than on this staging path.

---

## 6. Wiring in `modules/hub.bicep`

Insert after the Invoices block (`hub.bicep:368-380`), following the same format:

```bicep
//------------------------------------------------------------------------------
// Multicloud FOCUS ingestion
//------------------------------------------------------------------------------

module awsFocus 'Microsoft.FinOpsHubs/AmazonWebServices/app.bicep' = if (enableAwsFocusIngestion) {
  name: 'Microsoft.FinOpsHubs.AmazonWebServices'
  params: {
    app: newApp(hub, 'Microsoft.FinOpsHubs', 'AmazonWebServices')
    core: core.outputs.metadata
    exports: cmExports.outputs.metadata
    bucketName: awsBucketName
    // ...
  }
}
```

Also add `awsFocus` / `googleFocus` to the `dependsOn` of the `startTriggers` module (`hub.bicep:423-442`, `dependsOn` array at `425-432`) — otherwise the new triggers stay stopped after deployment, because they are started by `Init-DataFactory.ps1`, which is called by `fx/hub-initialize.bicep`.

---

## 7. File checklist

| # | File | Action |
| --- | --- | --- |
| 1 | `src/templates/finops-hub/main.bicep` | + parameters, + passthrough |
| 2 | `src/templates/finops-hub/modules/hub.bicep` | + parameters, + 2 modules, + telemetry, + `dependsOn` |
| 3 | `src/templates/finops-hub/createUiDefinition.json` | + `multicloud` step, + outputs |
| 4 | `.../modules/Microsoft.FinOpsHubs/AmazonWebServices/{app,metadata}.bicep` + `README.md` | new |
| 5 | `.../modules/Microsoft.FinOpsHubs/GoogleCloud/{app,metadata}.bicep` + `README.md` | new |
| 6 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.2-aws.json` | ✅ **created and validated** — 56 mappings, checked one by one against a real manifest (§10) and end to end in a deployed hub (§11) |
| 7 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.2-gcp.json` | new (see R2) |
| 8 | `.../Microsoft.CostManagement/Exports/app.bicep` | ✅ **done** — AWS schema registered in the `files:` map |
| 9 | `src/templates/finops-hub/.build.config` | + 2 READMEs under `ignore` |
| 10 | `docs-mslearn/toolkit/hubs/template.md` | + rows in the parameter table |
| 11 | `docs-mslearn/toolkit/hubs/configure-multicloud.md` | new how-to |
| 12 | `docs-mslearn/toolkit/changelog.md` | **Added** entry under FinOps hubs |
| 13 | `src/powershell/Public/Deploy-FinOpsHub.ps1` | + equivalent parameters |
| 14 | `src/powershell/Tests/Unit/Deploy-FinOpsHub.Tests.ps1` | + test cases |

Items 9, 10, and 12 are repository requirements, not optional: `.build.config` must ignore module READMEs (otherwise they ship in the Azure Quickstart Templates package), and the changelog has its own rules in `docs-wiki/Coding-guidelines.md`.

Note on item 8: the schemas live in the `Microsoft.CostManagement.Exports` app because it owns the `msexports` container and publishes the `schemas/` folder. Alternative, if isolation is preferred: each multicloud app publishes its own schema via `fx/hub-storage.bicep` to the same path — this avoids touching the Exports app, at the cost of spreading the responsibility.

---

## 8. Risks

**R1 — `exportConfig.resourceId` — RESOLVED, low risk.** Spike complete. The real expression:

```
scope       = split(toLower(exportConfig.resourceId), '/providers/microsoft.costmanagement/exports/')[0]
destination = replace(concat(hubDataset, '/', year, '/', month, '/', toLower(scope), ...), '//', '/')
```

`split()` with a missing delimiter returns the whole string in `[0]`. There is no resource ID decomposition, format validation, or lookup — the value is used only as a path segment, lowercased, with `//` collapsed. Any string works. The original hypothesis that an ARN would break the parsing was wrong. An Azure-format pseudo-scope is not needed; see §2.2.

**R2 — FOCUS schema parity — RESOLVED, requires per-provider schemas.** Validated against a **real** AWS FOCUS file (snappy parquet, 60 columns, 19,827 rows). The file is **FOCUS 1.2**, not 1.0.

Comparison with `focuscost_1.2.json` (104 mappings):

| | Count | Note |
| --- | --- | --- |
| FOCUS columns matching exactly by name | 53 | reusable unchanged |
| Azure `x_*` columns missing from the AWS file | 51 | `x_BillingProfileId`, `x_SkuMeterId`, … — cannot be mapped |
| AWS columns missing from the hub schema | 7 | `AvailabilityZone`, `x_Operation`, `x_ServiceCode`, `x_Discounts`, 3× `PricingCurrency*` |

So the existing schema **cannot be reused**. `schemas/focuscost_1.2-aws.json` was published with **56 mappings**: the 53 shared ones (types inherited from the hub's 1.2 schema) plus `AvailabilityZone`, `x_Operation`, and `x_ServiceCode` — all three confirmed as existing columns of the ADX `Costs_raw` table.

Omitted because they do not exist in the ADX schema: `x_Discounts` (`map<string,double>`) and `PricingCurrencyContractedUnitPrice` / `PricingCurrencyEffectiveCost` / `PricingCurrencyListUnitPrice`. Including them would require changing `IngestionSetup_RawTables.kql`, `HubSetup_v1_2.kql`, and the final tables — a change that also affects Azure data and is out of scope for this feature. Record it as a known gap in the README.

**Correction to an earlier design error:** the schema file's `additionalColumns` **cannot** be used to stamp provenance. The ETL applies:

```
intersection(
  [{"name":"x_SourceProvider","value":"Microsoft"}, {"name":"x_SourceName","value":"Cost Management"},
   {"name":"x_SourceType","value":"<dataVersion>"}, {"name":"x_SourceVersion","value":"<dataVersion>"}],
  activity('Load Schema Mappings').output.firstRow.additionalColumns
)
```

(`Exports/app.bicep:1225`). Because it is an **intersection** with an array of values fixed to `Microsoft` / `Cost Management`, an object with `"value":"AWS"` never survives. And because **all** 14 schema files in the repository have `additionalColumns: []`, the intersection is always empty today — the ETL does not stamp `x_Source*` for any dataset.

**Good consequence:** `dataVersion` does not leak into `x_SourceType` / `x_SourceVersion`. It is purely a schema-selection parameter with no side effects. The residual risk flagged earlier **does not exist**.

**R3 — private networking (medium).** With `enablePublicAccess = false`, egress to S3/GCS depends on the ADF Managed VNet and the NAT Gateway (`enableNatGateway`). Document that private networking + multicloud requires `enableNatGateway = true`.

**R4 — long-lived secrets (medium).** AWS/GCS access keys do not expire on their own. The secret is already created in Key Vault, but the README must require rotation and a minimum IAM policy (`s3:GetObject` + `s3:ListBucket` restricted to the prefix).

**R5 — egress cost (low).** The transfer leaves the source provider and is billed by it. Document this alongside the cost estimate, as the Invoices README already does.

---

## 8b. Spike results

Run on `arthursilvany/multicloud-focus`, by static reading of the ETL and schemas, and validated against a **real** AWS FOCUS export.

| Item | Initial hypothesis | Result |
| --- | --- | --- |
| R1 — `resourceId` parsing | High risk; could invalidate the approach | **Disproved.** It is just a path segment. Free format. |
| R2 — reusing `focuscost_1.2.json` | Probably reusable | **Disproved.** 51 of 104 columns are Azure-specific. Needs a per-provider schema. |
| Schema selection | Hardcoded in the ETL | **Better than expected.** Derived from `type` + `dataVersion`, and `dataVersion` is free and side-effect-free. |
| Provenance via `additionalColumns` | Ready-made mechanism | **Disproved.** The `intersection()` with fixed `Microsoft` values blocks it. See R2. |
| Multicloud provenance | Would need a new column | **Already solved upstream.** See §8c. |

### 8c. ADX already supports AWS and GCP

A finding that reduces the scope of the feature. `IngestionSetup_v1_0.kql:367-372` already classifies the provider from the shape of the data:

```kusto
| extend ProviderName = case(
    isnotempty(ProviderName), ProviderName,
    isnotempty(coalesce(x_CostCategories, x_Discount, x_Operation, x_ServiceCode, x_UsageType)), 'AWS',
    isnotempty(coalesce(tostring(UsageAmount), tostring(x_Cost), ..., x_Project, x_ServiceId)), 'GCP',
    isnotempty(coalesce(x_BillingProfileId, x_InvoiceSectionId)), 'Microsoft',
    ''
)
| extend x_SourceProvider = coalesce(x_SourceProvider, ProviderName)
| extend x_SourceVersion  = coalesce(x_SourceVersion, case(...))
```

The `Costs_raw` table already declares `x_Operation` and `x_ServiceCode` with the comment `// AWS 1.0`, and `AvailabilityZone` as `// FOCUS 0.5+`. The real AWS file arrives with `ProviderName = 'AWS'` already populated, so classification succeeds on the first branch.

**Conclusion: no provenance work is required.** Simply delivering the data into `Costs_raw` is enough — ADX classifies, versions, and routes it on its own.

### 8d. Constraints fixed by table routing

`Analytics/app.bicep:1815` derives the destination table from the **first folder segment** of the ingestion path:

```
table = concat(first(split(containerFolderPath, '/')), '_raw')
```

and `Exports/app.bicep:847` maps `exportDatasetType = 'focuscost'` → `hubDataset = 'Costs'`, falling back to the type name itself. Therefore:

| Manifest field | Required value | Reason |
| --- | --- | --- |
| `exportConfig.type` | **`FocusCost`** (exact) | any other value produces a `<type>` folder and a `<type>_raw` table, which does not exist |
| `exportConfig.dataVersion` | free | only selects the schema file |

Using a suffix in `dataVersion` already has precedent in the repository: `focuscost_1.0-preview(v1).json` and `focuscost_1.2-preview.json`.

---

## 9. Execution order

1. ~~R1 and R2 spikes~~ — **complete**, see §8b.
2. ~~Write `focuscost_1.2-aws.json` and validate it against a real AWS FOCUS file~~ — **complete**, see §10 and §11.
3. Complete AWS app (Bicep + README).
4. Google app, reusing the validated format.
5. UI, PowerShell parameters, and tests.
6. Documentation and changelog.

Validation at each stage:

```powershell
az bicep build --file src/templates/finops-hub/main.bicep --stdout
./src/scripts/Build-Toolkit finops-hub
./src/scripts/Deploy-Toolkit finops-hub -Build -WhatIf
./src/scripts/Test-PowerShell -Lint -Hubs
```

The first mandatory regression test is a deployment **with both flags off**, comparing the what-if against the baseline: the result must be empty.

---

## 10. AWS source topology (BCM Data Exports)

Confirmed in the [AWS documentation](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-export-delivery.html).

### S3 layout

```
s3://<bucket>/<prefix>/<export-name>/data/billing_period=YYYY-MM/            # "overwrite" mode
s3://<bucket>/<prefix>/<export-name>/data/billing_period=YYYY-MM/<timestamp>-<execution-id>/   # "create new" mode
s3://<bucket>/<prefix>/<export-name>/metadata/billing_period=YYYY-MM/<export-name>-Manifest.json
```

Files: `<export-name>-<chunk>.snappy.parquet` or `<export-name>-<chunk>.csv.gz`, where `chunk` is a 5-digit number starting at `00001`.

> The AWS documentation spells the partition key as `BILLING_PERIOD=`, but the real export delivers lowercase `billing_period=`. The pipeline must not write that literal: the path always comes from the manifest's `dataFiles` field.

### Three design consequences

**1. The AWS `Manifest.json` must not be copied into `msexports`.** Its schema is completely different from the Cost Management contract (§2) — if the trigger picked it up, `Read Manifest` would return nulls and the ETL would fail. It must be **read** by a `Lookup` directly against S3 and never written to the `msexports` container. Only the synthetic manifest we build is written there.

Mitigating factor: the AWS file is named `<export-name>-Manifest.json`, and the trigger filters on `storagePathEndsWith: 'manifest.json'`. Even so, Event Grid case sensitivity must not be relied on as a safety mechanism — the rule is simply not to copy it.

**2. Reading the AWS manifest is mandatory, not optional.** In "create new" mode, the `data/billing_period=YYYY-MM/` folder accumulates **one subfolder per daily refresh**. A recursive `Get Metadata` would copy them all and duplicate the month's costs. Only the `Manifest.json` at the `metadata/<partition>/` level identifies the current run.

**3. The manifest is the completeness signal.** AWS publishes it only after all data files have landed — it is the exact equivalent of the Cost Management `manifest.json` and removes the need for any "stable file" heuristic.

### Collection window

AWS may update the previous period for up to two weeks after it closes. The pipeline must iterate over **two** periods per run — the current month and the previous month — not just the current one.

### Idempotency: why a daily refresh does not duplicate data

`ingestionId = runInfo.runId` from the synthetic manifest, and the ADX post-ingestion cleanup (`Analytics/app.bicep:1423`) removes extents tagged `drop-by:<folderPath>` but **not** `drop-by:<ingestionId>`. In other words: by generating a new `runId` on every run and keeping the destination path stable per period (`Costs/YYYY/MM/aws/<accountId>`), each refresh **replaces** the whole month instead of accumulating. This is the same mechanism used by Azure exports.

#### The `drop-by` tag is case-sensitive — and includes the file name

Two details of the mechanism above were confirmed empirically and constrain the format of `exportConfig.resourceId`:

1. **The tag carries the full blob path, including the file name** — not just the folder. For example: `drop-by:Costs/2026/05/aws/390402570720/2026-05-20T22_19_25.548Z-<execId>_CCOE-PRODAM-AWS-00001.snappy.parquet`. Because the AWS file name embeds `<timestamp>-<executionId>`, it **changes on every refresh**. Replacement only works because the ADX cleanup matches on the folder prefix; any change to the path format breaks idempotency.
2. **The comparison is case-sensitive.** The ETL applies `toLower()` to the scope (§8/R1), so `resourceId: /aws/390402570720` always writes to `Costs/YYYY/MM/aws/390402570720/`. A manual load into `.../AWS/390402570720/` produces a distinct tag and both sets **coexist**, doubling the cost.

Observed in the lab: after ingesting the same parquet through both routes, `Costs_final_v1_2` held 39,654 rows (2 × 19,827) and USD 164,511.26 (2 × USD 82,264.63), under two tags that differ only by `AWS` vs `aws`:

```
drop-by:Costs/2026/05/AWS/390402570720/<file>.snappy.parquet
drop-by:Costs/2026/05/aws/390402570720/<file>.snappy.parquet
```

**Design consequence:** `exportConfig.resourceId` must **always** be emitted in lowercase by the `AmazonWebServices`/`GoogleCloud` modules. Any case variation in the account or provider identifier produces silent duplication — no error, no alert, just double the cost.

### The exact contract consumed by the ETL, revisited

| Real ETL expression | Implication for the synthetic manifest |
| --- | --- |
| `replace(substring(runInfo.startDate, 0, 7), '-', '')` | `startDate` must be ISO: `YYYY-MM-01T00:00:00Z`. Derivable from the `billing_period=YYYY-MM` segment present in `dataFiles[0]`. |
| `last(split(blobs[0].blobName, '.'))` | selects the dataset by extension: `parquet`, `gz`, or `csv`. `*.snappy.parquet` resolves to `parquet`. |
| `ForEach(blobs)` → `item().blobName` | `blobName` is the path **inside the `msexports` container**, not the S3 key. |
| `last(split(replace(replace(blobName,'.gz',''),'.csv','.parquet'), '/'))` | destination file name; preserves `.snappy.parquet`. |
| `blobCount` / `dataRowCount` | if `blobCount` is zero or null the ETL short-circuits. Populate it with `length(dataFiles)`. `dataRowCount` is only evaluated **if the property exists** (`contains(firstRow, 'dataRowCount')`) — since the AWS manifest carries no row count, the property must be **omitted**, never written as `0`. |

### The AWS `Manifest.json` contract — RESOLVED

Fixed against a **real** manifest (`CCOE-PRODAM-AWS`, period `2026-05`):

```json
{
  "executionId": "9b6b32ef-2b70-3d10-9448-07e23ebce6b9",
  "exportArn": "arn:aws:bcm-data-exports:us-east-1:<accountId>:export/<export-name>-<uuid>",
  "columns": [ { "name": "AvailabilityZone", "type": "string" }, ... ],
  "dataFiles": [
    "s3://<bucket>/<prefix>/<export-name>/data/billing_period=2026-05/2026-06-01T23:48:02.356Z-9b6b32ef-2b70-3d10-9448-07e23ebce6b9/<export-name>-00001.snappy.parquet"
  ],
  "additionalOutputFiles": []
}
```

Six points the `Lookup` and the synthetic manifest must respect:

| Confirmed fact | Consequence |
| --- | --- |
| The field is **`dataFiles`**, not `files`. | Settles the disagreement between public sources. |
| Each item is a **full `s3://` URI**, not a relative key. | The `Copy` must strip `s3://<bucket>/` to obtain the object key. Do not apply the dataset's `bucketName` on top of the raw URI. |
| **There is no period field** in the manifest. | `billing_period` is derived from the path in `dataFiles[0]` (or from the partition the manifest was read from), and the synthetic manifest's ISO `startDate` follows from it. |
| **There is no row count.** | Omit `dataRowCount` from the synthetic manifest (see the table above). `blobCount = length(dataFiles)`. |
| The path contains `<timestamp>-<executionId>`, and `executionId` is in the manifest itself. | Confirms design consequence #2: the customer is in "create new" mode and the folder accumulates one refresh per day. Copying only what is listed in `dataFiles` is mandatory. |
| `columns` carries the name and type of every delivered column. | This gives a free schema-drift detector: compare against the 56 mappings in `focuscost_1.2-aws.json` before copying, and fail with a clear message instead of silently ingesting truncated data. |

`additionalOutputFiles` was empty in this export; the pipeline should ignore it.

### Schema validation against the real manifest

The manifest's 60 column names were compared one by one against `focuscost_1.2-aws.json`:

- **56 of 56 schema mappings exist in the manifest**, with compatible types (`string`→`String`, `double`→`Decimal`, `timestamp`→`DateTimeOffset`).
- **No schema column is missing** from the AWS file.
- The 4 manifest columns without a mapping are exactly the omissions already documented in R2: `x_Discounts`, `PricingCurrencyContractedUnitPrice`, `PricingCurrencyEffectiveCost`, and `PricingCurrencyListUnitPrice`.
- `Tags` and `SkuPriceDetails` arrive as parquet `map` columns and are mapped as `String`. **Validated in a real deployment** (§11): the `TabularTranslator` serializes the map as JSON and ADX materializes it as `dynamic`. The type risk is closed.

---

## 11. End-to-end validation in a real hub

`focuscost_1.2-aws.json` was exercised against a deployed FinOps hub v14, using the real AWS FOCUS parquet file (19,827 rows, USD 82,264.63, May 2026, 16 sub-accounts, 57 services).

**Method.** Because the only ETL trigger is a `manifest.json` landing in `msexports`, a temporary Data Factory pipeline published the schema to `config/schemas/`, copied the parquet into `msexports/<folder>/`, and wrote a synthetic manifest with `exportConfig.type = FocusCost`, `dataVersion = 1.2-aws`, and `resourceId = /aws/<accountId>-test`. The whole test was driven from Data Factory because the hub storage account has `publicNetworkAccess: Disabled`.

**Result — the full chain succeeded:**

| Pipeline | Status | What it proves |
| --- | --- | --- |
| `msexports_ExecuteETL` | Succeeded | The trigger accepts a synthetic manifest; routing by `exportDatasetType` works. |
| `msexports_ETL_ingestion` → `Load Schema Mappings` | Succeeded | `toLower('FocusCost_1.2-aws.json')` resolves to `focuscost_1.2-aws.json`. The extension point from §2.1 works as designed. |
| `msexports_ETL_ingestion` → `Convert to Parquet` | Succeeded | The 56 `TabularTranslator` mappings are valid against the real AWS parquet, including the `map` columns. |
| `ingestion_ExecuteETL` → `ingestion_ETL_dataExplorer` | Succeeded | ADX ingestion and the `Costs_raw` → `Costs_final_v1_2` transforms accept AWS data unchanged. |

**ADX verification:** all 19,827 rows were ingested, with `ProviderName = "AWS"`, `Tags` materialized as `dynamic` (`{"map-migrated":"mig656O1TB0TE"}`), `ServiceCategory` correctly enriched, and non-empty cell counts identical to the native load.

**Conclusion:** `focuscost_1.2-aws.json` is validated. The remaining work is exclusively collection — the `AmazonWebServices`/`GoogleCloud` modules that read S3/GCS and write the synthetic manifest (§5). Nothing in the existing ETL needs to change.

**Note on `Get Existing Parquet Files`:** this activity fails with `PathNotFound` when the destination folder does not exist yet, and that is handled — the pipeline still completes successfully. It is not a symptom of a problem in the multicloud path.
