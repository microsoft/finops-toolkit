# Column: PricingQuantity

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                     | Column                   |
|:----------|:-----------------------------|:-------------------------|
| AWS       | Cost and Usage Report        | lineItem/UsageAmount (NOTE: how to handle reservation/TotalReservedUnits|
| GCP       | BigQuery Billing Export      | usage.amount_in_pricing_units (NOTE: usage.amount provides UsageQuantity) |
| Microsoft | Cost Details                 | Not available (NOTE: While Quantity is the closest, it provides UsageQuantity and not PricingQuantity) |
| OCI       | Cost and Usage Report        | usage/billedQuantity  Note: usage/billedQuantity preferred over usage/billedQuantityOverage since the latter does not include the quantity covered by Universal Credits (commitment discounts) |

## References and Resources

### AWS

* [Pricing details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/pricing-columns.html)

### GCP

* [Structure of Detailed data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage)

### Microsoft

* [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)

### OCI

* [Cost and Usage Reports Overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)

## Discussion / Scratch space

* Do we need to support negative values in the case of credits / refunds? (currently assumed yes)
* AWS issue “For size-flexible Reserved Instances, use the reservation/TotalReservedUnits column instead.”
* OCI seems to support separate billed quantities with an overage calculation… needs investigation.
* How will this apply for marketplace transactions…. What behavior do we expect for prices and quantities for marketplace purchases (and refunds)

### Current billing data for charges where ChargeCategory 'Tax'

#### GCP - Tax

* Couldn’t find tax-related cost records in case of one small GCP account
* HS Data provided samples:
  * usage.amount_in_pricing_units values: 1.0, 2.0, 4.0
  * usage.pricing_unit: count

#### AWS - Tax

* Tax-related records contain:
  * lineItem/UsageAmount: 1
  * pricing/unit: null

#### Azure - Tax

* Tax-related record are not available in billing data

##### OCI - Tax

* Tax-related record are not available in billing data

### Example PricingQuantity values for charges where ChargeCategory is "Tax"

Example A
| Description          | Pricing Quantity          | Unit Price   | Billed Cost |
|:---------------------|:--------------------------|:-------------|-------------|
| Compute Usage        | 100                       | 1.0          | $100        |
| Tax on Compute Usage | 100                       | 0.2          | $20         |
|:---------------------|:--------------------------|:-------------|-------------|
| TOTAL                | 200                       | NA           | $120        |
NOTE: Double counting of hours

Example B
| Description          | Pricing Quantity          | Unit Price   | Billed Cost |
|:---------------------|:--------------------------|:-------------|-------------|
| Compute Usage        | 100                       | 1.0          | $100        |
| Tax on Compute Usage | 1                         | 20           | $20         |
|:---------------------|:--------------------------|:-------------|-------------|
| TOTAL                | 101                       | NA           | $120        |
NOTE: Incorrect counting of hours

Example C
| Description          | Pricing Quantity          | Unit Price   | Billed Cost |
|:---------------------|:--------------------------|:-------------|-------------|
| Compute Usage        | 100                       | 1.0          | $100        |
| Tax on Compute Usage | NULL                      | NULL         | $20         |
|:---------------------|:--------------------------|:-------------|-------------|
| TOTAL                | 100                       | NA           | $120        |
NOTE: Preferred option?

## Example usage scenarios

* See [Appendix: Quantity-Driven Pricing strategies](../appendix/quantity_driven_pricing_strategies.md) section for more information on
  * Quantity-Driven Pricing strategies (such as flat-rate, volume-based rates and tier-based rating)
  * related UC scenarios
* See [Pricing Support – UCs and Data samples Spreadsheet](https://docs.google.com/spreadsheets/d/1AZ-vtkKeKwYc8rqhxP1zMTnAVAS-svmWQQmr8cpv-IM/edit#gid=117987709) for various UC scenarios and sample data.
