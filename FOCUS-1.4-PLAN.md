# FOCUS 1.4 implementation plan

> **Temporary working document** for the `flanakin/focus14` integration branch. This file tracks the design and work breakdown for adding FOCUS 1.4 support across the FinOps toolkit. It will be **removed before the `flanakin/focus14` → `dev` PR is marked ready for review**. Progress is mirrored in the umbrella PR checklist.

## 1. Goal

Add full FOCUS 1.4 support across the FinOps toolkit: a new `v1_4` hub schema (tables, functions, transforms), Power BI reports, documentation, open data metadata, AI/agent knowledge files, and tests — following the proven `v1_0` → `v1_2` upgrade pattern, staged as small PRs into `flanakin/focus14`, then one PR into `dev`.

Microsoft Cost Management does **not** yet export FOCUS 1.4. This plan ships the `v1_4` hub schema converting all currently supported export versions (`1.0-preview(v1)`, `1.0`, `1.0r2`, `1.2-preview`, `1.2`) up to FOCUS 1.4, and pre-wires detection for native 1.4 exports. Export-side registration (schema mapping file, default export version) is staged as a follow-up gated on the Cost Management release.

## 2. Grounding: what changed in FOCUS 1.2 → 1.4

Sources: FOCUS spec repo tags `v1.2`/`v1.3`/`v1.4` (tags are ground truth; `working_draft` already contains 1.5 drift), `CHANGELOG.md`, `ERRATA.md`, and `supporting_content/appendix/version_migration_guidance.md` (1.3→1.4 guide added 2026-07-09, post-1.4-tag).

Both 1.2→1.3 and 1.3→1.4 are **backward-compatible releases** (no incompatible changes per spec changelog); the only removals are `ProviderName`/`PublisherName` (deprecated 1.3, removed 1.4).

### CostAndUsage (Costs) — 65 columns in 1.4 (vs 57 in 1.2)

New columns to add:

| Column | Introduced | Type | Feature level | Nulls | Hubs source (today) |
|---|---|---|---|---|---|
| AllocatedMethodDetails | 1.3 | JSON | Recommended | ✔ | null (no CM source) |
| AllocatedMethodId | 1.3 | String | Conditional | ✔ | null |
| AllocatedResourceId | 1.3 | String | Conditional | ✔ | null |
| AllocatedResourceName | 1.3 | String | Conditional | ✔ | null |
| AllocatedTags | 1.3 | JSON | Conditional | ✔ | null |
| ContractApplied | 1.3 (format revised 1.4) | JSON | Conditional | ✔ | null |
| HostProviderName | 1.3 | String | **Mandatory** | ✔ | derived (see D3) |
| ServiceProviderName | 1.3 | String | **Mandatory** | ✘ | derived (see D3) |
| CommitmentProgramEligibilityDetails | 1.4 | JSON | Conditional | ✔ | null |
| InvoiceDetailId | 1.4 | String | Conditional | ✔ | null |

Removed columns: **ProviderName**, **PublisherName** (successor mapping is semantic, not a rename — see D3).

Changed: `InvoiceId` feature level Recommended → Conditional (1.4); `PricingCurrency` and `PricingCurrencyEffectiveCost` non-nullable (1.4 errata fixes); `BilledCost`/`EffectiveCost` normative requirements substantially tightened (1.4); several price/quantity columns gained null-consistency rules tied to `SkuPriceId` (1.3). **No allowed-value changes to any pre-existing enum column across 1.2→1.4** (verified by value-set diff) — no value remapping needed for existing data.

### New FOCUS datasets (no Cost Management source yet)

- **ContractCommitment** (1.3: 13 columns → 1.4: 30 columns)
- **BillingPeriod** (1.4: 6 columns)
- **InvoiceDetail** (1.4: 22 columns)

### Attributes / metadata (docs + conformance impact only)

1.4 removes `ColumnHandling` → `FocusColumnHandling` + `CustomColumnHandling`, removes `DiscountHandling` (→ appendix) and `InvoiceHandling` (→ `DeliveryHandling` + `DatasetCompleteness`); revises `CurrencyFormat` (ISO 4217 only — virtual currency allowance removed), `NumericFormat`, `UnitFormat`, `StringHandling`, `NullHandling`. 1.3 added DatasetInstance + Recency metadata groups.

## 3. Design decisions

### D1. Single `v1_4` hub schema; skip `v1_3`

Hubs converts to the *latest* supported FOCUS version. 1.3 is a strict subset of 1.4 additions, Cost Management will never export 1.3, and both releases are backward-compatible. A `v1_3` schema layer would double the KQL surface for zero consumer value. **Decision: one new schema version, `v1_4`.**

### D2. Replicate the v1_2 architecture exactly

Per the v12 precedent (PR #1688 et al.):

- `{ds}_raw` update policies switch to `{ds}_transform_v1_4()` → `{ds}_final_v1_4` (new). The v1_2 update policies are flipped to `"IsEnabled": false` in `IngestionSetup_v1_2.kql`; `_final_v1_2` tables are kept (historical data stays put; no data migration).
- `{ds}_transform_v1_2()` docstrings marked deprecated (same as v1_0 functions were).
- Hub DB: new `{ds}_v1_4()` functions union `_final_v1_4 ∪ _final_v1_2 ∪ _final_v1_0` (up-converting older rows); existing `{ds}_v1_0()`/`{ds}_v1_2()` functions extended to also union `_final_v1_4` **down-converted** (back-compat guarantee).
- `HubSetup_Latest.kql` (and the unversioned tail of the newest HubSetup file) repoints `{ds}()` → `{ds}_v1_4()`.
- New FOCUS 1.4 superset columns added to `{ds}_raw` in `IngestionSetup_RawTables.kql` with `// FOCUS 1.3+` / `// FOCUS 1.4+` annotations (existing convention).
- `decimal`→`real` and JSON→`dynamic` type conventions carry forward from v1_2.

### D3. ProviderName / PublisherName → ServiceProviderName / HostProviderName

The spec migration guide (lines 197–230) defines a context-dependent mapping, not a rename. For Microsoft-billed data:

- **HostProviderName** = `'Microsoft'` (Microsoft operates the hosting infrastructure for all charges in CM exports). Nullable per spec, but always populated for our data.
- **ServiceProviderName** = `PublisherName` for Marketplace charges; `'Microsoft'` otherwise. (For native services PublisherName is already Microsoft, so `coalesce`-style logic collapses cleanly.)

Down-conversion (v1_2/v1_0 views over `_final_v1_4` rows): `ProviderName = HostProviderName`, `PublisherName = ServiceProviderName`. This round-trips correctly for both native and Marketplace charges. Original values preserved via the existing `x_SourceValues` mechanism (#1767 precedent) — for removed columns, follow the removed-column convention (`checkString(..., old_X, '')`) so originals are always captured.

> ⚠️ Note: a plain `ServiceProviderName = PublisherName` fallback is insufficient — the existing PublisherName fix-up can yield `''` (e.g., `x_PublisherCategory == 'Cloud Provider'` branch), violating the non-null mandate. Use the Marketplace-conditional mapping with a `'Microsoft'` fallback. Both #2126 and #2128 currently have this mapping **swapped** (Host↔Service inverted); fix must be coordinated across ingestion + hub + plugin docs.

### D4. New FOCUS datasets in scope (revised after PR review)

Original recommendation was to defer ContractCommitment, BillingPeriod, and InvoiceDetail (no Cost Management source). **Superseded by explicit owner direction** in PR #2126 review comments 3277231717/3277243626, which requested the tables — and the work already exists across the PR stack (raw tables, transforms, `_final_v1_4` tables, `{ds}_v1_4()` functions, unversioned aliases). **Decision: keep them in scope.** They remain empty until a data source ships; all docs/agent surfaces describing them must carry an explicit "no data until Cost Management ships an export" caveat.

### D5. Export-side registration staged behind Cost Management

The seams (all verified in code):

1. `Exports/schemas/focuscost_1.4*.json` — column mapping for the actual CM export; **cannot be authored correctly until CM publishes the 1.4 export column list.**
2. `Exports/app.bicep` `schemaFiles` registration.
3. `ManagedExports/app.bicep` `exportDataVersions.focuscost` (currently `1.2-preview`).
4. `New-FinOpsCostExport.ps1` `$DatasetVersion` default + Pester tests + PS docs.
5. `open-data/dataset-metadata/FocusCost_1.4*.json` + example CSV.

These ship as a **follow-up PR when CM announces FOCUS 1.4 exports** (tracked in the checklist as blocked). Meanwhile, `Costs_transform_v1_4()` pre-wires `x_SourceVersion` detection for 1.4 exports by column presence (e.g., `ServiceProviderName`), extending the existing heuristic (`IngestionSetup_v1_2.kql` ~L385), so day-one ingestion works once a schema file exists. The ETL pipeline already fails gracefully with an "upgrade" error for unknown schema versions.

### D6. Testing: add a static KQL/regression Pester harness (new)

There is **no existing KQL setup-script test coverage** (`HubsIngestionQueries.Tests.ps1` covers Recommendations query JSON only; the v1_2 rollout was manually verified — and shipped 4 regressions). Add `src/powershell/Tests/Unit/HubsSchemaSetup.Tests.ps1` (static analysis, no ADX needed), asserting:

1. **Registration completeness**: every `IngestionSetup_v1_*.kql` / `HubSetup_v1_*.kql` file is listed in `.build.config` (Fabric bundle) *and* loaded in `Analytics/app.bicep` — prevents regression #1777 (v1_2 script missing from Fabric build).
2. **Version-string consistency**: within `*_v1_X.kql`, function/table/docstring references use the file's own version except in an explicit allowlist (cross-version unions, deprecation pointers) — prevents the recurring copy-paste defects (#e036c2cd; paired-file drift).
3. **Structural pairing**: each managed dataset has `{ds}_transform_v1_4()`, `{ds}_final_v1_4` table, and an update policy wiring them; exactly one schema version has enabled update policies.
4. **Column contract**: `_final_v1_4` Costs columns match the FOCUS 1.4 column inventory (golden list checked into the test) plus documented `x_` extensions; `_raw` superset ⊇ every transform input.

Plus existing gates: `bicep build` via `Build-Toolkit`, `Test-PowerShell -Lint`, full Pester run, and a manual `Deploy-Toolkit -Build -Test` ADX validation pass before the umbrella PR is marked ready (ingest sample exports for **every** supported dataset version — prevents regression #1906, pre-1.2 data breaking in the new transform; and check hub-function join cardinality for duplicates — regression #1907).

### D7. Docs shipped in-band, not lagging

The v1_2 release left Power BI docs stale for months. Every code PR updates its own docs surface; the docs PR covers the schema/version matrices: `data-model.md` (schema version table + column tables), `upgrade.md`, `compatibility.md`, `data-processing.md`, `data-dictionary.md`, power-bi docs, changelog (Unreleased). `docs-mslearn` edits require manually setting `ms.date` to today.

### D8. FOCUS conformance docs regenerated for 1.4

`Build-FocusConformance.ps1` defaults `$Branch = "v1.2"` → bump to `v1.4` and regenerate `docs-mslearn/focus/*` (metadata, convert, conformance-summary, conformance-full-report). The 1.4 attribute restructuring (removed/renamed attributes) means the conformance report layout must be re-validated, not just re-run.

## 4. Work breakdown

Small PRs targeting `flanakin/focus14`; stacked where a hard dependency exists. Existing draft PRs (2123, 2126, 2128, 2135, 2136, 2194) are mapped to these work items after a full review pass (§6) — reworked, restructured, or superseded as needed.

| # | Work item | Depends on | Existing PR | Scope (files) |
|---|---|---|---|---|
| **W1** | Plan + umbrella PR | — | — | This doc; draft PR `flanakin/focus14` → `dev` |
| **W2** | Ingestion v1_4 | — | #2126 | `IngestionSetup_RawTables.kql` (superset columns), new `IngestionSetup_v1_4.kql` (transforms incl. D3 mapping + 1.4 source detection, `_final_v1_4` tables, update policies), `IngestionSetup_v1_2.kql` (disable policies, deprecate docstrings), `Analytics/app.bicep`, `.build.config`, changelog |
| **W3** | Hub functions v1_4 | W2 | #2128 | New `HubSetup_v1_4.kql`, `HubSetup_v1_0.kql`/`HubSetup_v1_2.kql` (union `_final_v1_4`, down-convert per D3), `HubSetup_Latest.kql`, `dashboard.json`, changelog |
| **W4** | KQL test harness | W2, W3 | #2136 (part) | New `HubsSchemaSetup.Tests.ps1` per D6; runs green against W2+W3 output |
| **W5** | Power BI | W3 | — | `kql/Shared.Dataset` TMDL repoint `Costs_v1_2`→`Costs_v1_4` (+ ReservationRecommendations), `storage/Shared.Dataset` `Has14` normalization + `expressions.tmdl` version inference, report.json "FOCUS 1.2" strings, `ftk_NormalizeSchema.pq` if needed, power-bi docs |
| **W6** | Core docs | W2, W3 | #2123 (upgrade.md) | `data-model.md`, `upgrade.md`, `compatibility.md`, `data-processing.md`, `data-dictionary.md`, hub README support matrix, changelog consolidation |
| **W7** | FOCUS conformance + open data | — | — | `Build-FocusConformance.ps1` branch bump, regenerated `docs-mslearn/focus/*`; open-data updates that are **not** CM-gated |
| **W8** | AI/agent surfaces | W3 | #2135 | copilot-studio knowledge files (`schema-reference.md` etc.), `agent-skills` references, claude-plugin output style, `Build-QueryCatalog`/`src/queries` `_v1_2` refs |
| **W9** | Recommendations enrichment | — | #2194 | `x_RecommendationCategory`/`x_RecommendationSubcategory` — independent feature; evaluated on its own merits |
| **W10** | *Blocked on CM 1.4 export release* | W2 | — | `focuscost_1.4*.json` schema, `Exports/app.bicep` registration, `ManagedExports` default, `New-FinOpsCostExport` default + tests + PS docs, open-data `FocusCost_1.4*.json` metadata + example CSV |

Execution order: W2 → W3 → W4 (stacked); W5–W8 parallel after W3; W9 anytime; W10 blocked.

### D9. KQL file-size limit (added after PR review)

Bicep `loadTextContent()` caps embedded files at **131,072 characters**. `IngestionSetup_v1_4.kql` on the PR stack is ~128 K before enrichments; PR #2194's +55 lines already broke CI (`Error BCP184`). **Decision: split `IngestionSetup_v1_4.kql` into two scripts** (e.g., core managed datasets vs. supplemental FOCUS datasets), following the existing `OpenDataFunctions_*.kql` split precedent, registered in both `app.bicep` and `.build.config`. The W4 registration-completeness test must cover both files.

## 5. Risks and lessons applied (from the v1_2 rollout)

| Regression (v1_2) | Mitigation here |
|---|---|
| #1777 — `IngestionSetup_v1_2.kql` missing from `.build.config` (Fabric build shipped broken) | `.build.config` updated in W2 itself + W4 test asserts registration completeness |
| #1906 — `Costs_transform_v1_2()` broke on pre-1.2 exports | W2 transform handles every `x_SourceVersion`; manual ADX pass ingests all 5 export versions |
| #1907 — duplicate rows from Services open-data join in `Costs_v1_2()` | W3 review checks join cardinality; ADX pass includes row-count reconciliation raw vs final vs hub function |
| #e036c2cd — stale cross-version references in paired KQL files | W4 version-string consistency test |
| Power BI docs lagged release by months | D7: docs in-band per PR |

## 6. Existing PR dispositions (reviewed 2026-07-15)

Stack order (nothing merged yet; phases 3–5 were closed/superseded): **#2126 (phase1) → #2128 (phase2) → #2135 (phase6) → #2136 (phase7) → #2194 (phase9)**. #2123 (phase0) is independent. Later PRs' diffs currently include all upstream content; retarget each PR's base to its parent branch to shrink review surface.

| PR | Disposition | Blocking fixes |
|---|---|---|
| #2123 → W6a | **Keep + fix** | 5 unaddressed 2026-06-29 comments (`sinc` typo, "into"→"in" ×2, "it"→"them", PR body GA/steps mismatch); decide forward-dated `v1_4` Learn content gating; **rescope as "upgrade procedure process docs"** — column-change tables for `upgrade.md`/`compatibility.md` etc. move to a new W6b docs PR |
| #2126 → W2 | **Keep + fix** | C1 Host/ServiceProviderName fallbacks swapped (L765/783); C2 C360 transforms (`ActualCosts`/`AmortizedCosts`) don't project the 22 new `Costs_raw` columns → transactional update policy breaks C360 ingestion (retrofit v1_0/v1_2 too, per repo convention); C3 v1_2 update policies not disabled + no deprecation docstrings; H1 no native-1.4 `x_SourceVersion` detection; M1 removed columns not always preserved in `x_SourceValues`; 12 unaddressed round-2 comments; D9 file split |
| #2128 → W3 | **Keep + fix** | F1 `Prices/Recommendations/Transactions/CommitmentDiscountUsage_v1_4()` missing `_final_v1_2` union arm (near-total data loss for existing hubs); F2 `HubSetup_v1_0/v1_2.kql` down-convert arms never added; F3 same provider-name swap in both up-convert arms; F4 remove duplicated unversioned tails (v1_4 L644-686 **and** stale v1_2 tail L552-588 — `HubSetup_Latest.kql` is single owner); F5 `dashboard.json` still `Costs_v1_2`; F7 opportunistic `take_any` on CDU Services lookup; 11 unaddressed comments; retarget base to phase1 |
| #2135 → W8 | **Rework** | C1 unresolved merge-conflict markers committed in `HubSetup_v1_4.kql` (~L283-296, from merge `676da5e8` — fix the merge resolution); C2 Service/HostProviderName descriptions swapped in `ftk-database-query.md` (other two files correct); M1 `// FOCUS 1.3+` comments on columns landing in v1_4 schema; M2 "no data yet" caveats for new dataset functions; copilot-studio knowledge files NOT covered — track separately in W8; retarget base to phase2 |
| #2136 → W4 | **Rework** | Missing D6 checks 2 (version-string consistency + allowlist — would have caught the conflict markers) and 3 (exactly-one-enabled-policy-version — would have caught C3); hardcoded v1_4 filenames → glob discovery; tighten substring-match tests (`_v1_0()` alias check, occurrence counts); D3 round-trip mapping untested; red-green validate new checks against current broken state |
| #2194 → W9 | **Keep + fix** | Bicep 131 K size break (CI-verified, → D9 split); 22 of ~23 hub-native recommendation queries silently fall to subcategory `Other` (map them); category/subcategory coherence rule + test; 6 open review comments; PR body test claims contradict CI (2006 passed / 1 failed) |

## 7. Open questions (non-blocking; recommendations applied unless overridden)

1. ~~Q1 (D4)~~ Resolved: new datasets in scope per owner review comments on #2126 (see D4).
2. ~~Q2 (D3)~~ Resolved: derivation confirmed by owner review comments 3309129381/3309175754 on #2126; both PRs currently implement it swapped — fix in W2/W3.
3. **Q3**: Target release for `flanakin/focus14` → `dev` (v14 shipped 2026-07; assume next release). Changelog entries land under "Unreleased" (stack currently uses "FinOps hubs v15.0.0" inside the commented Unreleased block — consistent).
4. ~~Q4~~ Resolved (owner: "just do it", 2026-07-15): `ContractCommitments_raw`/`_final_v1_4` reconciled to the 30 FOCUS 1.4 spec column IDs (12 renames + `ContractCommitmentDescription` + `ServiceProviderName` added), verified against the spec `v1.4` tag; tests, changelog, plugin/copilot docs, and schema docs updated across the stack.

## 8. Progress

- [x] Research: FOCUS 1.2→1.4 spec delta (tags, changelog, errata, migration guides)
- [x] Research: FTK FOCUS-version surface inventory
- [x] Research: v1_0→v1_2 precedent + post-release regressions
- [x] W1: Plan committed; umbrella draft PR opened ([#2207](https://github.com/microsoft/finops-toolkit/pull/2207))
- [x] Review 6 existing PRs; dispositions recorded in §6
- [x] W2: Ingestion v1_4 — #2126 fixed (`30f926d3`: provider mapping, C360 retrofit, v1_2 policies disabled, 1.4 detection, D9 file split; build green) — **awaiting review**
- [x] W3: Hub functions v1_4 — #2128 fixed (`cd2873b7`+`7181c9aa`: v1_2 union arms, v1_0/v1_2 down-convert arms, mapping consistency, tails removed, dashboard repoint; build green; base retargeted to phase1) — **awaiting review**
- [x] W4: KQL test harness — #2136 reworked (`778080f2`+`9eb79cad`: 207 static tests, D6 checks 1-4, all red-green validated; full suite 2047/0) — **awaiting review**
- [x] W5: Power BI — new [#2209](https://github.com/microsoft/finops-toolkit/pull/2209) (kql repoint + 22 model columns, storage `Has14` normalization, ProviderName/PublisherName kept as derived columns to protect visuals/DAX; 2 `.pbix` binaries flagged for release-time regen) — **awaiting review**
- [x] W6: Core docs — W6a #2123 fixed (`463c2735`); W6b new [#2211](https://github.com/microsoft/finops-toolkit/pull/2211) (upgrade/compatibility/data-processing/data-dictionary; 111/0 column cross-check) — **awaiting review**
- [x] W7: Conformance — new [#2208](https://github.com/microsoft/finops-toolkit/pull/2208) (`Build-FocusConformance.ps1` fixed for 1.3+ spec layout + curation preservation; 1,021 new 1.3/1.4 requirements marked Not Evaluated, no invented claims) — **awaiting review**
- [x] W8: AI/agent surfaces — #2135 reworked (`968207f4`+`0824600c`: conflict markers removed, provider semantics fixed, no-data caveats); W8b new [#2210](https://github.com/microsoft/finops-toolkit/pull/2210) (copilot-studio knowledge 175/175 column check, query catalog + removed-column migration) — **awaiting review**
- [x] W9: Recommendations enrichment — #2194 fixed (`503d3a63`+`a6c91087`+`47b406ed`: 22/23 queries mapped to real subcategories, taxonomy coherence datatable + tests, symmetric defaults; suite 2093/0) — **awaiting review**
- [x] Dev sync: `origin/dev` merged through the entire stack (merge commits only) — brings PR-environment workflows (#2033) and dev's KQL/PBI fixes; dev's v1_2-era fixes (#2151 strcat OOM, #2189 price-lookup max()) ported into the v1_4 transforms with a version-normalized parity diff
- [ ] ADX validation via **PR environments** (replaces the manual pass): "Hubs + ADX (managed)" checked on #2194 (full stack) and #2207 (umbrella); deploys queue for `ftk-pr` environment approval. Validate: ingest samples for all 5 export versions, row-count/cardinality reconciliation raw → final → hub functions
- [ ] Remove this plan file; mark umbrella PR ready
- [ ] *Blocked*: W10 export-side registration (awaiting Cost Management FOCUS 1.4 export)

### Recommended review/merge order

1. [#2123](https://github.com/microsoft/finops-toolkit/pull/2123) (independent process docs)
2. Stack, in order: [#2126](https://github.com/microsoft/finops-toolkit/pull/2126) → [#2128](https://github.com/microsoft/finops-toolkit/pull/2128) → [#2135](https://github.com/microsoft/finops-toolkit/pull/2135) → [#2136](https://github.com/microsoft/finops-toolkit/pull/2136) → [#2194](https://github.com/microsoft/finops-toolkit/pull/2194) (bases auto-retarget as parents merge)
3. Stacked on phase7: [#2209](https://github.com/microsoft/finops-toolkit/pull/2209) (Power BI), [#2210](https://github.com/microsoft/finops-toolkit/pull/2210) (copilot-studio/queries), [#2211](https://github.com/microsoft/finops-toolkit/pull/2211) (schema docs). Note: #2194, #2209 all append to `changelog.md` from the same base — merge conflicts there are additive; keep both sides per repo convention.
4. [#2208](https://github.com/microsoft/finops-toolkit/pull/2208) (conformance, independent)
