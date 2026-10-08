# FOCUS 1.5 SkuPrices (preview, draft)

Draft FinOps hubs implementation of the FOCUS 1.5 **SKU Price** dataset ([FOCUS PR 2424](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/pull/2424)), built from `Prices_final_v1_2`. Not wired into `app.bicep` or `.build.config` yet. Run manually against a hub.

## Files

| File | Purpose |
|---|---|
| `SkuPrices_v1_5.kql` | Functions + build commands for `SkuPrices_v1_5`, `SkuPricesWide_v1_5`, and the `SkuPrices_v1_5_starts_table` helper |
| `Build-SkuPrices.ps1` | Creates the functions and builds all tables, one price type at a time |
| `Test-SkuPrices.ps1` | Validation: duplicates, row counts vs. source, price/discount match, required columns, ranges |
| `SkuPrices_v1_5_scenarios.kql` | 10 scenarios, each with a query for both layouts |
| `Test-SkuPriceScenarios.ps1` | Runs both queries per scenario, compares results, times them, writes JSON |

Scripts default to the `ftk-dev.westus` cluster, `Ingestion` database, and `fh-dev` Az context. Override with `-Cluster`, `-Database`, `-Context`.

```powershell
./Build-SkuPrices.ps1      # ~10 min on ftk-dev
./Test-SkuPrices.ps1
./Test-SkuPriceScenarios.ps1
```

## Layouts

| | `SkuPrices_v1_5` (rows) | `SkuPricesWide_v1_5` (columns) |
|---|---|---|
| Grain | SkuPriceId x price type x contract x currency | SkuPriceId x contract x currency |
| Price | `UnitPrice` + `x_UnitPriceType` (List, Base, Contracted, Effective) | `ListUnitPrice`, `ContractedUnitPrice`, `x_BaseUnitPrice`, `x_EffectiveUnitPrice` |
| ContractId | Empty for List; agreement for others | Agreement on every row |
| Eligibility | Global for List; agreement (+ MCA profiles) for others | Agreement on every row (list price mis-scoped) |
| Effective start | Per price type | Latest change of any price on the row |

## Mapping decisions

* `SkuPriceId` = `SkuPriceIdv2` (unique per price); source `SkuPriceId` kept as `x_SkuPriceIdv1`
* `ContractId` = `/providers/microsoft.billing/billingaccounts/{x_BillingAccountId}` (EA enrollment / MCA billing account, not the profile)
* Savings plan rows carry only the Effective price (list/base/contracted on those rows are copies of the on-demand meter's prices)
* `SkuPriceEffectiveStart` = first month of the current unchanged price across all monthly loads; `SkuPriceEffectiveEnd` = null (current price)
* `PricingRegionId` = region name (`x_SkuRegion`); `PricingServiceName` = meter category; `SkuPriceCreated`/`LastUpdated` = first/last ingestion
* `PurchaseDurationType` from `x_SkuTerm`; `PurchasePaymentModel` empty (not in price sheet)
* Non-SKU Price source columns get an `x_` prefix; `CommitmentDiscountCategory` kept as a filter label; columns sorted alphabetically

## Results on ftk-dev (EA, Oct 2026 price sheet, 14 months of history)

| | Rows | Extent size |
|---|---|---|
| `Prices_final_v1_2` (14 monthly copies) | 18,778,328 | 2.51 GB |
| `Prices_final_v1_2` (latest month) | 1,625,302 | 217 MB |
| `SkuPrices_v1_5` (current prices) | 3,885,217 | 656 MB |
| `SkuPricesWide_v1_5` (current prices, columns layout) | 1,625,302 | 329 MB |
| `SkuPrices_v1_5` with full history (est.) | ~4.17M | ~0.70 GB |
| ...skipping Base/Contracted rows equal to List (est.) | ~1.88M | ~0.32 GB |

* Rows by type: List 1,236,402; Contracted 1,236,402 (98.0% = List); Base 1,023,513 (94.0% = List); Effective 388,900
* Validation: 18/19 checks pass; `PricingUnit` empty (see gaps)
* Scenarios: 10/10 return the same answer in both layouts, except S06 (expected: wide rows can't tell which price changed)

## Scenarios

| Id | Scenario | Rows: lines / joins | Columns: lines / joins |
|---|---|---|---|
| S01 | List price for a SKU | 4 / 0 | 3 / 0 |
| S02 | Negotiated discount by service | 11 / 1 | 6 / 0 |
| S03 | Base price drift from list | 10 / 1 | 5 / 0 |
| S04 | Reservation price vs. on-demand | 11 / 1 | 11 / 1 |
| S05 | Savings plan rate vs. on-demand | 10 / 1 | 10 / 1 |
| S06 | Recent price changes by price type | 4 / 0 | 7 / 0 (less precise) |
| S07 | Cheapest region for a VM size | 9 / 1 | 9 / 1 |
| S08 | Verify billed unit prices | 8 / 1 | 8 / 1 |
| S09 | Savings plan what-if for on-demand usage | 12 / 1 | 12 / 1 |
| S10 | All prices for one SKU | 9 / 0 | 4 / 0 |

Not testable with this data: negotiated savings plan discount, quantity tiers (EA has no tier minimums), multiple currencies, consumption currency, price as of a past date.

## Gaps / TODO

* [ ] `PricingUnit` and `x_PricingBlockSize` empty: `PricingUnits` open data table has 0 rows on ftk-dev, so `UnitPrice` is per block (e.g., per 10 hours), not per unit
* [ ] Savings plan list price ("list effective") is lost on ingestion: `Prices_transform_v1_2` nulls the SP `MarketPrice` and backfills on-demand prices; needed to measure negotiated SP discounts
* [ ] Store replaced prices (full history), not only current prices
* [ ] Decide whether to skip Base/Contracted rows equal to List (lookups fall back to List)
* [ ] MCA untested (collapses billing profiles into the billing account; check for profile-specific prices)
* [ ] Decide final layout once FOCUS settles the price type column (planned for 1.6)
* [ ] Wire into `IngestionSetup_v1_5.kql` / `HubSetup_v1_5.kql`, `app.bicep`, `.build.config`; add `SkuPrices()` hub function, docs, changelog
