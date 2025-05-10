# Column: Billed Cost

## Example provider mappings

Current column mappings found in available data sets:

| **Provider** | **Data set**             | **Column**                                                                                                                                                                                  |
| ------------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS          | CUR                      | lineItem/NetUnblendedCost (If you have an EDP, otherwise ​​line_item_unblended_cost)                                                                                                        |
| GCP          | Big Query Billing Export | credits + cost (The cost of the usage before any credits, to a precision of up to six decimal places. To get the total cost including credits, any credits.amount should be added to cost.) |
| Microsoft    | Cost details             | Cost, CostInBillingCurrency, CostInPricingCurrency, EffectivePrice                                                                                                                          |
| OCI          | Cost reports             | cost/myCostOverage (The cost billed for overage usage of a resource)                                                                                                                        |

## Example usage scenarios

See [Cost Metrics Examples Spreadsheet](https://docs.google.com/spreadsheets/d/1bhRELDgf3LTSfQJRrCyovTt65g4ElimYHq6fmKOz83E) for examples of billing data for various scenarios.

## Discussion / Scratch space

- Aggregations can capture billed cost across different charge types.

  - The cost shown in a single row may not be the final billed cost of a given resource for a billing period as taxes, discounts and other adjustments for the same resource will be in other rows.
  - It's important to understand that providers may not spread some charges (like Tax, Credits) to a line-item level. Those rows may be available at a higher granularity which means they can't easily be spread accurately to each usage row. Example, Tax may not come at a resource level. This means you will need to spread tax cost down to individual teams/resources but that assumes all usage would have gotten taxed at the same rate (which is not the case). However, this is likely the best most practitioners will be able to do to spread taxes, fees etc.

- Variable cost discounts are applied in Billed Cost.

  - Examples are GCP SUD or equivalent. Ultimately, the spec can't define if these discounts show up as a single line or as multiple as long as negotiated discounts are applied AND the aggregation of rows at charge type (e.g. Usage) provides the correct sum.

- Accuracy / format of values:

  - What's the precision for the decimal values? This will be defined as a new attribute
  - Tim will take a look at open standards to define a valid decimal / precision

- Must have a currency always with cost data (similar to time needs a timezone)

- Do we use the billed currency or the pricing currency or both?

  - Should the following 4 columns be provided: billed cost, billing currency, pricing currency cost?, pricing currency
  - Pricing cost/currency naming also needs to be 0.5 \@udam
  - What about conversion rates? As columns? as Metadata? Skip for now
  - Clear downside here is that a unified data set across providers OR even a dataset for a single multi-currency provider will have cost data in a billed or pricing currency cost that cannot be aggregated (sum, average etc.)
  - Should there be a column that allows normalization to a single currency across providers
    - USD would be the logical choice but this would impose USD on non-USD consumers

- Should a minimum precision be defined in the spec?
  - They should be consistent within provider
  - Focus on the outcome not necessarily the specifics on precision.

| **BilledCost** | **BilledCurrency** | **PricedCost** | **PricedCurrency** |
| -------------- | ------------------ | -------------- | ------------------ |
| 123.45         | USD                | 123.45         | USD                |
| 246.80         | USD                | 246.80         | USD                |
| 1234567890     | JPY                | 89.08          | USD                |
| 369.15         | CNY                | 369.15         | CNY                |

_Do we just need a THIRD option - CostInBase, BaseCurrency - which is like UTC - it could be USD? OR are we assuming that PricedCurrency is always USD?_
