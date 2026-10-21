# FOCUS 1.5 implementation plan

> **Temporary working document** for the FOCUS 1.5 delta stacked on `flanakin/focus14`. Remove before the umbrella merges. Release: v16 (not v15). Details: spec delta from `origin/working_draft` vs tag `v1.4`.

## Decision

Keep `v1_4` as is. Add `v1_5` as a stacked delta on top (1.5 builds on 1.4; no rename). 1.4 stays released and supported.

## Spec status (as of 2026-10-21)

- 1.5 release PR (FOCUS_Spec 2755) is still a draft. Static scope; 1.5 ships as a Preview release.
- **Merged on `working_draft`:** Cost and Usage columns `AllocatedServiceName`, `PrincipalId`, `CredentialId`, `RequesterDetails`; ListCost/ContractedCost/ListUnitPrice/ContractedUnitPrice rewrites; token and AI-model properties in `SkuPriceDetails`; cached-token `ConsumedQuantity` rule; `ContractCommitmentDurationType` canonical unit form; `CurrencyFormat` allows consumption currency; `UnitFormat` additions; AI Model Billing feature; 24 operating model conditions.
- **Open (not merged):** SkuPrice dataset (2424) and related 2748/2749/2753; Preview definition (2762, previews are excluded from conformance); Recommendation dataset (2444); AllocatedServiceName requirements model (2554); feature-level changes (2374, 2375).
- SkuPrice ships as a separate dataset; the current `SkuPrices` dataset stays unchanged until SkuPrice is GA.

## Work breakdown (one draft PR each, stacked on `flanakin/focus14`)

| # | Area | Scope | Blocked on |
|---|---|---|---|
| 1 | Ingestion | `IngestionSetup_v1_5.kql`: 4 new Costs columns, `Costs_transform_v1_5`, `_final_v1_5` | none |
| 2 | Hubs | `HubSetup_v1_5.kql`: `Costs_v1_5()` unions; repoint `Costs()` | 1 |
| 3 | SkuPrice | new `SkuPrice` dataset (separate; Preview) | spec 2424 merge |
| 4 | Power BI | `v1_5` schema, reports | 2 |
| 5 | Docs/schema | upgrade, compatibility, data dictionary, conformance | 2 |
| 6 | Plugin/Copilot | knowledge + query catalog refresh | 2 |
| 7 | Tests/changelog | schema tests, changelog (v16) | 1-2 |
| 8 | Export-side | `focuscost_1.5` schemas, `New-FinOpsCostExport` default | Cost Management 1.5 export |

## Cannot move yet

Recommendation dataset, SkuPrice, feature-level changes (spec PRs open); export schemas (no Cost Management 1.5 export); conformance report (1.5 not published).
