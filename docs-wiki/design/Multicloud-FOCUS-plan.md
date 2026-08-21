# Plan: make AWS and Google FOCUS ingestion an optional FinOps hub setup step

> Scope, rationale, and high-level decisions for the feature. The technical detail — manifest contract, Bicep parameters, module structure, and file checklist — lives in [Multicloud-FOCUS-design](./Multicloud-FOCUS-design.md).
> Working branch: `arthursilvany/multicloud-focus`.

## Problem

Add optional support for ingesting FOCUS data from AWS and Google (GCP) during FinOps hub setup, without turning it into a requirement of the default deployment. The goal is to let an Azure hub deployment also receive multicloud data through a controlled ingestion flow, following the template's existing model for optional extensions.

## References reviewed

- <https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/deploy?tabs=azure-portal%2Cadx-dashboard#managed-exports>
- <https://techcommunity.microsoft.com/blog/finopsblog/getting-started-with-finops-hubs-multicloud-cost-reporting-with-azure-and-google/4415190>
- Current repository: `src/templates/finops-hub/main.bicep`, `src/templates/finops-hub/modules/hub.bicep`, `src/templates/finops-hub/createUiDefinition.json`, `src/templates/finops-hub/modules/Microsoft.FinOpsHubs/RemoteHub/app.bicep`

## Findings

- The current template already uses an optional-flag pattern for setup extensions (`enableManagedExports`, `enableRecommendations`, `remoteHubStorageUri`, `remoteHubStorageKey`).
- `createUiDefinition.json` shows that the Azure portal UI already exposes optional settings in advanced sections for remote hub scenarios.
- `Microsoft.FinOpsHubs/RemoteHub/app.bicep` is the best reference pattern in the repository for: (1) connecting an external resource to the hub's Data Factory; (2) overriding datasets; and (3) keeping the hub working as centralized ingestion.
- Microsoft documentation covers multicloud/remote hub for Azure, but does not yet model AWS and Google as native, optional FinOps hub installer settings. There is a deployment-experience gap between "Azure-only defaults" and "multicloud custom ingestion".

## Direction

1. Keep the default FinOps hub deployment fully Azure-first, with no behavior changes by default.
2. Add an optional "Multicloud" step to the wizard, with separate toggles for AWS and Google.
3. Reuse the hub's Data Factory as the orchestrator for collecting external FOCUS files instead of creating a parallel deployment.
4. Treat AWS/Google as extra data sources, not as required hub resources.

## Architectural revision after reading the code (key decision)

The full analysis is in [Multicloud-FOCUS-design](./Multicloud-FOCUS-design.md). Its conclusion changed the original design:

**Do not build a parallel ETL.** The hub already has the complete `msexports → Parquet → ingestion → ADX` chain, and it is fired by a `BlobEventsTrigger` that reacts **exclusively** to `manifest.json` (`Microsoft.CostManagement/Exports/app.bicep:1712-1728`). The FOCUS 1.0/1.0r2/1.2 schemas and the CSV, gzip, and Parquet datasets already exist.

So the multicloud connector only needs to:

1. copy the FOCUS files from the S3/GCS bucket into `msexports/<provider>/...`;
2. write a Cost Management-compatible `manifest.json` **last**.

Everything after that — conversion, retention, and analytical ingestion — already works unchanged. This drastically reduces new code and maintenance cost.

Reference pattern to follow: `Microsoft.Billing/Invoices`, the newest and most complete optional app in the repository (`enableInvoiceDownload` parameter + conditional module + UI step + README + `.build.config` entry).

## Spike results (complete)

Run on the `arthursilvany/multicloud-focus` branch. Details in [Multicloud-FOCUS-design](./Multicloud-FOCUS-design.md) §8b.

- **R1 — `exportConfig.resourceId`: disproved.** The ETL runs `split(toLower(resourceId), '/providers/microsoft.costmanagement/exports/')[0]` and uses the result only as a path segment. There is no resource ID parsing. Any string works — `/aws/<accountId>` and `/gcp/<projectId>` were adopted. Risk dropped from high to low.
- **R2 — FOCUS schema reuse: confirmed as a problem, and solved.** The hub's FOCUS schema is dominated by Azure-specific `x_*` columns and is not reusable. Solution: publish per-provider schemas and select them through the synthetic manifest's `exportConfig.dataVersion` field, since the schema file name is derived from `type` + `dataVersion` — both under our control. **Zero ETL changes.**
- **Bonus:** the schema file's `additionalColumns` field, empty today, looked like a ready-made mechanism for stamping `x_SourceProvider` to distinguish data origin in ADX.

> **Superseded by the design doc.** Two of the statements above were later corrected: the real AWS export is FOCUS **1.2**, so the schema is `focuscost_1.2-aws.json` (not `1.0-aws`); and `additionalColumns` **cannot** stamp provenance, because the ETL intersects it with a fixed `Microsoft` / `Cost Management` array. Provenance turned out to require no work at all — ADX already classifies AWS and GCP from the shape of the data. See design §8/R2, §8b, and §8c.

Conclusion: the synthetic manifest approach is validated. No blockers remain for starting implementation.

## Proposed scope

### 1) Setup configuration

Add optional parameters to the main template and the portal UI:

- `enableAwsFocusIngestion` (bool, default false)
- `enableGoogleFocusIngestion` (bool, default false)
- `awsFocusBucketName` / `awsFocusPrefix` / `awsFocusRegion`
- `awsFocusAccessKeySecretName` or `awsFocusCredentialsSecretName`
- `googleFocusBucketUri` / `googleFocusPrefix` / `googleProjectId`
- `googleFocusCredentialsSecretName`
- `focusIngestionSchedule` or `triggerFrequency`

These inputs must be conditional: they are only visible when the matching source is enabled.

### 2) Security and secrets

- Use Key Vault to store AWS/Google credentials instead of exposing secrets in the template.
- Model the property as Key Vault references, similar to the `remoteHubStorageKey`/`AzureKeyVaultSecret` pattern.
- Validate that credentials are optional and that configuration fails explicitly when the flag is enabled but the secret or URI is missing.

### 3) Data Factory extension

Add Bicep modules to the hub flow to:

- create the AWS and/or Google source `linkedService`
- create source and destination datasets
- create copy pipelines that move FOCUS files from external storage into the FinOps hub
- create a periodic trigger (daily/hourly, depending on the source)
- preserve the current `startTriggers` logic via `fx/hub-initialize.bicep`

The extension must follow the same pattern already used in `Microsoft.FinOpsHubs/RemoteHub/app.bicep`.

### 4) Ingestion and normalization

- Ensure the final destination is compatible with the model the hub already uses for FOCUS/Parquet files and analytical ingestion.
- Define folder structure and naming rules to avoid collisions between AWS, Google, and Azure sources.
- Validate that the provider's FOCUS schema is consistent with what the hub expects, and whether a transformation layer is needed before final ingestion.

### 5) Testing, validation, and documentation

- Validate the template deployment with the flags off (baseline unchanged).
- Validate the deployment with each source enabled separately.
- Validate `bicep build`/deployment validation and the repository tests (`src/scripts/Test-PowerShell`).
- Update the FinOps hub and deployment portal documentation to explain the optional multicloud flow.

## Risks and considerations

- AWS/Google integration topology tends to depend on provider-specific services, APIs, and credentials; the solution must be a connector pattern, not a single hardcoded scenario.
- Ingestion cost and latency increase with external connections; the feature must be explicitly optional and documented.
- The hub assumes Azure-first data; the multicloud extension must be isolated so it does not affect the default installation.
- Google/AWS configurations may require distinct network and egress rules; this must be addressed in the template design.

## Planned tasks

- `multicloud-research`: confirm the technical scope and choose the extension model most compatible with the current hub.
- `multicloud-design`: define installer parameters, UI, and configuration object.
- `multicloud-iac`: specify the hub Bicep and the Data Factory pattern for AWS/Google.
- `multicloud-docs`: validate documentation, tests, and rollout.

## Expected outcome

A FinOps hub installation that keeps working as Azure-first by default, but offers the option to collect FOCUS data from AWS and Google as complementary sources, with security, isolation, and compatibility with the hub's current flow.
