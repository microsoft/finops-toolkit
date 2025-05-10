# Column: Consumed Quantity

## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set                | Column               |
|----------|-------------------------|----------------------|
| AWS      | CUR                     | lineItem/UsageAmount |
| Azure    | Cost Details            | quantity             |
| GCP      | BigQuery Billing Export | usage.amount               |

## Discussion Topics

* May 6th, 2024: After much discussion, it was agreed upon by the maintainers to rename this column to 'ConsumedQuantity' and the related unit to 'ConsumedUnit' to reduce confusion between what AWS calls lineitem/UsageAmmount. The modification done to the previous UsageUnit content: Specify that this column applies only to 'Usage' rows - as it was previously written as 'usage or purchase'. That now becomes consistent with the subsequent sentence of the introductory paragraph which describes the column as measuring consumption.
* The examples in "Rows  per Scenario V2" sheet in [this google sheet](https://docs.google.com/spreadsheets/d/1zA0brhrEntfWlzt5VNcNLBFnKPEiarajTF84o4ATeEw/edit#gid=1134244055) were helpful in understanding the need for a separate 'Consumed Quantity' as opposed to a single 'FooQuantity' (which later was voted to be 'ActualQuantity'). Rows 30/31/52/54/22 were helpful in showing the need to understand both the 'used' quantity and the quantity that you were charged for.
* Consensus was reached based on needing to support Staircase pricing - where you maybe charged for a quantity based on the 'stair' but you use less than that. It leads to the classic usage-optimization scenario in FinOps. For example, Slot usage in GCP BigQuery is charged based on a one minute minimum and per second granularity beyond that. Snowflake has similar scenario for warehouses. If you run a bunch of queries that use one-second, you're being charged for 60 seconds each time. Practitioners want to identify these and optimize their usage patterns to better utilize what they're paying for. To correctly identify the potential optimization opportunity, you need both pieces of data to show up in the data. ConsumedQuantity allows for the used amount to be presented in a consistent manner and is easily understood.
* The second column needed for the staircase pricing scenario above, a potential 'DistinctPricingQuantity' column, could be introduced in the future to identify the 60 seconds that you were 'charged' for in singular units. Today, you may have to use pricing quantity - which may have block pricing - therefore you may may need to do math to get 'distinct' units). Alternatively, we could introduce a 'factor' to remove the block portion of the pricing unit. This need was discussed and determined to be something that needs to be thought through and evaluated in detail post v1.0.
