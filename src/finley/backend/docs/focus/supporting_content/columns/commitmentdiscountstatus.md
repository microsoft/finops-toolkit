# Column: CommitmentDiscountStatus

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                | Column                                                                 |
| --------- | ----------------------- | ---------------------------------------------------------------------- |
| AWS       | CUR                     | `lineItem/LineItemType` (SavingsPlanCoveredUsage, SavingsPlanNegation) |
| GCP       | BigQuery Billing Export | None                                                                   |
| Microsoft | Cost details            | `ChargeType` (Usage, UnusedReservation, UnusedSavingsPlan)             |

## Discussion / Scratch space

- Moved from ChargeSubcategory that was defined in 1.0-preview.
- Alternative values discussed:
  - Used, Usage, Consumption
  - Unused, Not Used, Waste, Wastage
