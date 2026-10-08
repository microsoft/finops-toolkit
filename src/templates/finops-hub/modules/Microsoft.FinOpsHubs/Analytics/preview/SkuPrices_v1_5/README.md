# FOCUS 1.5 SkuPrices (preview, draft)

Draft FinOps hubs implementation of the FOCUS 1.5 **SKU Price** dataset ([FOCUS PR 2424](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/pull/2424)), built from `Prices_final_v1_2`, with a comparison layout and scenarios to choose between them. Not wired into `app.bicep` or `.build.config` yet. Run manually against a hub.

## Files

| File | Purpose |
|---|---|
| `SkuPrices_v1_5.kql` | Functions + build commands for `SkuPrices_v1_5`, `SkuPricesWide_v1_5`, `CostsWithSkuPriceIdv2`, and helper tables (`SkuPrices_v1_5_runs_table`, `SkuPriceIdv2_map`) |
| `Build-SkuPrices.ps1` | Creates the functions and builds all tables in small steps (key partitions, months, price types) |
| `Test-SkuPrices.ps1` | Validation: duplicates, overlaps, current rows vs. latest sheet, rows vs. runs, price match, required columns, ranges |
| `SkuPrices_v1_5_scenarios.kql` | 14 scenarios, each with the most efficient query found for each layout (plus today's monthly table for cost joins) |
| `Test-SkuPriceScenarios.ps1` | Runs each query 3x, compares results, scores simplicity, time, CPU, memory, rows scanned, x_ usage, correctness |
| `Render-SkuPriceReport.ps1` + `SkuPrices_v1_5_report.template.html` | Renders the side-by-side HTML report from scenario results and live table sizes |

Scripts default to the `ftk-dev.westus` cluster, `Ingestion` database, and `fh-dev` Az context. Override with `-Cluster`, `-Database`, `-Context`.

```powershell
./Build-SkuPrices.ps1          # ~45 min on ftk-dev
./Test-SkuPrices.ps1
./Test-SkuPriceScenarios.ps1   # writes results JSON to the temp folder
./Render-SkuPriceReport.ps1
```

## Layouts

All three hold the same 14 months of prices.

| | Today `Prices_final_v1_2` | Rows `SkuPrices_v1_5` | Columns `SkuPricesWide_v1_5` |
|---|---|---|---|
| Grain | Price per month | Price type per run of unchanged months | Price per contract per run of unchanged months |
| Prices | Columns | `UnitPrice` + `x_UnitPriceType` (List, Base, Contracted, Effective) | `ListUnitPrice`, `ContractedUnitPrice`, `x_BaseUnitPrice`, `x_EffectiveUnitPrice` |
| Dates | Month | Effective start/end per price type | One start/end per row (new row when any price changes) |
| List price scope | n/a | Public: no contract, global eligibility | Scoped to the contract with the rest of the row |
| Rows | 18.78M | 4.17M (3.89M current) | 1.79M (1.63M current) |
| Extent | 2.34 GB | 0.64 GB | 0.33 GB |

Rows by type (all / current): List 1,348,812 / 1,236,379; Contracted 1,326,353 / 1,236,379 (98% = List); Base 1,056,500 / 1,023,491 (94% = List); Effective 438,723 / 388,900.

## Mapping decisions

* `SkuPriceId` = `SkuPriceIdv2` (unique per price); source `SkuPriceId` kept as `x_SkuPriceIdv1`
* `ContractId` = `/providers/microsoft.billing/billingaccounts/{x_BillingAccountId}` (EA enrollment / MCA billing account, not the profile)
* Savings plan rows carry only the Effective price (list/base/contracted on those rows are copies of the on-demand meter's prices)
* Effective dates are month-level runs of unchanged prices across monthly loads; current prices have no end
* `PricingRegionId` = region name (`x_SkuRegion`); `PricingServiceName` = meter category; `SkuPriceCreated`/`LastUpdated` = first/last ingestion
* `PurchaseDurationType` from `x_SkuTerm`; `PurchasePaymentModel` empty (not in price sheet)
* Non-SKU Price source columns get an `x_` prefix; `CommitmentDiscountCategory` kept as a filter label; columns sorted alphabetically

## Cost and Usage join

Costs `SkuPriceId` doesn't match the price sheet's, and Costs lacks `x_SkuProductId`/`x_SkuMeterType`, so `SkuPriceIdv2` can't be rebuilt from Costs columns. `CostsWithSkuPriceIdv2` is a copy of `Costs_final_v1_2` with `SkuPriceIdv2` looked up from prices by price type + meter + offer + term:

| Cost type | Price used | Rows matched | Cost matched |
|---|---|---|---|
| On-demand usage | On-demand | 100% | 100% |
| Reservation-covered usage | On-demand (no reservation usage price) | 90.2% | 74.7% |
| Savings-plan-covered usage | Savings plan for the term | 83.1% (68 rows have no meter) | 100% |
| Reservation purchase | Reservation for the term (only when unique) | 16/16 | n/a |
| Adjustment | None | 0% | 0% |

Effective-dated prices have no range lookup in KQL. Scenarios spread each price over the months it was in effect and look up on `SkuPriceId` + `ContractId` + `PricingCurrency` + month: no range join and no duplicated cost rows. Today's monthly table needs no spreading.

## Scenarios

| Id | Scenario | Simpler | Faster | CPU | Memory | Rows scanned | FOCUS-only | Correct |
|---|---|---|---|---|---|---|---|---|
| S01 | List price on a date | Tie | Tie | Tie | Tie | Columns | Columns | Tie |
| S02 | Negotiated discount by service | Columns | Columns | Columns | Columns | Columns | Columns | Tie |
| S03 | Base price drift from list | Columns | Columns | Columns | Columns | Columns | Tie | Tie |
| S04 | Reservation price vs. on-demand | Tie | Columns | Columns | Tie | Columns | Columns | Tie |
| S05 | Savings plan rate vs. on-demand | Tie | Tie | Columns | Tie | Columns | Tie | Tie |
| S06 | Price changes since July | Rows | Tie | Tie | Rows | Columns | Rows | Tie |
| S07 | Cheapest region for a VM size | Tie | Tie | Tie | Tie | Columns | Columns | Tie |
| S08 | Verify billed unit prices (+Monthly) | Tie | Tie | Tie | Tie | Columns | Columns | Tie |
| S09 | Savings plan what-if for on-demand usage (+Monthly) | Tie | Monthly | Monthly | Tie | Columns | Tie | Tie |
| S10 | All prices for one SKU | Tie | Tie | Tie | Tie | Columns | Rows | Tie |
| S11 | Estimate a planned workload | Tie | Tie | Tie | Tie | Columns | Columns | Tie |
| S12 | Public prices visible to each account | Tie | Rows | Rows | Tie | Columns | Columns | Rows |
| S13 | Usage rates vs. purchase fees | Rows | Tie | Tie | Tie | Columns | Rows | Tie |
| S14 | Backfill missing prices on cost data (+Monthly) | Monthly | Tie | Tie | Tie | Columns | Columns | Tie |
| | **Wins (Rows / Columns / Monthly)** | 2 / 2 / 1 | 1 / 3 / 1 | 1 / 4 / 1 | 1 / 2 / 0 | 0 / 14 / 0 | 3 / 8 / 0 | 1 / 0 / 0 |

Scores: winner per measure, or Tie within 15% of the runner-up. Simpler = operators + 2x joins + lets; Faster/CPU/Memory/Rows scanned = median of 3 server-measured runs; FOCUS-only = fewer distinct x_ columns referenced; Correct = which layout returns the right answer when they differ (S12: columns hide the public list price from accounts outside the agreement).

Covers 9 of 13 FOCUS PR 2595 queries plus 5 more (S03, S05, S06, S10, S14). Not testable with this data: announced price changes, public vs. negotiated at a quantity, tier resolution, next tier (no future prices or tiers in EA price sheets), negotiated savings plan discount, multiple currencies, consumption currency. Cost scenarios use a price only when its block unit matches the charge's `PricingUnit`.

## Gaps / TODO

* [ ] `PricingUnit` and `x_PricingBlockSize` empty: `PricingUnits` open data table has 0 rows on ftk-dev, so `UnitPrice` is per block (e.g., per 10 hours); scenarios parse the block size from `x_PricingUnitDescription`
* [ ] Savings plan list price ("list effective") is lost on ingestion: `Prices_transform_v1_2` nulls the SP `MarketPrice` and backfills on-demand prices; needed to measure negotiated SP discounts
* [ ] Decide whether to skip Base/Contracted rows equal to List (lookups fall back to List)
* [ ] MCA untested (collapses billing profiles into the billing account; check for profile-specific prices); latest month is global, not per account
* [ ] Decide final layout once FOCUS settles the price type column (planned for 1.6)
* [ ] Add `SkuPriceIdv2` to `Costs_transform_v1_2` (replaces `CostsWithSkuPriceIdv2`); find a reservation-covered usage price
* [ ] Wire into `IngestionSetup_v1_5.kql` / `HubSetup_v1_5.kql`, `app.bicep`, `.build.config`; add `SkuPrices()` hub function, docs, changelog
