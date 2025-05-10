# Column: ContractedCost

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                | Column                                                                                     |
|:----------|:------------------------|:-------------------------------------------------------------------------------------------|
| AWS       | CUR                     | Not available                                                                              |
| GCP       | BigQuery Billing Export | Not available? or **cost** (the closest match);<br>*see Discussion / Scratch space - GCP column mappings for more details*        |
| Microsoft | Cost details (actual/amortized) | Not available<br>Can calculate using UnitPrice * Quantity<br>*see Discussion / Scratch space - Microsoft column mappings related issues for more details* |
| Microsoft | Cost details (FOCUS `1.0-preview(v1)`) | x_OnDemandCost |
| OCI       | Cost and Usage Report   | **cost/myCost**<br>*see Discussion / Scratch space - OCI column mappings for more details* |

## References and Resources

### AWS

* [Data dictionary - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/data-dictionary.html)

### GCP

* [Structure of Standard data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage)

### Microsoft

* [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)

### OCI

* [Cost and Usage Reports Overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)

## Example usage scenarios

* *TODO*

## Discussion / Scratch space

* April 20, 2024 update: Double counting issue was discussed in github issue [#424](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/424). Options discussed were:
  * Enhance the description about excluding ListCost and ContractedCost from purchases and related charges (e.g. Tax for the purchase) from aggregations related to savings calculations to avoid double counting
  * Update the description to require purchases that cover future eligible charges to have a ContractedCost of 0$
  * Update the description to require the covered rows to have a ContractedCost of 0$
* Based on discussions, we determined that it was useful at a row-level to have the ContractedCost specified but call out the need to exclude the purchase or usage rows to avoid double counting when aggregated. For accrual basis analysis, the purchase might be excluded. For cash-basis analysis, the usage charges may be excluded.

### GCP column mappings

* **cost** - The cost of the usage before any credits, to a precision of up to six decimal places. To get the total cost including credits, any credits.amount should be added to cost.

### Microsoft column mappings related issues

* TODO

### OCI column mappings

* Cost and usage reports contain cost/myCost and cost/myCostOverage columns.
  * **cost/myCost** - The cost charged for this line of usage. `myCost` is equal to `usage/billedQuanty * cost/unitPrice`. Note: billedQuantity, myCost, and unitPrice are inclusive of Overage numbers.
  * **cost/myCostOverage** - The cost billed for overage usage of a resource.
* Conclusion: Mapping **cost/myCost** to Contracted Cost and cost/myCostOverage to Billed Cost
