# Column: SKU ID

## Example provider mappings

Current column mappings found in available data sets:

| Provider     | Data set                    | Column          |
| ------------ | --------------------------- | --------------- |
| AWS          | CUR                         | product/sku     |
| Azure        | Cost details export or API  | PartNumber      |
| GCP          | BigQuery Billing Export     | sku.id          |
| OCI          | Cost Reports                | cost/productSku |

## Example scenarios for current provider data

Current values observed in billing data for various scenarios:

| Provider     | Scenario                   | Pattern          |
| ------------ | -------------------------- | ---------------- |
| AWS          | CUR                        | FFNT87MQSCR328W6 |
| Azure        | Cost Details export or API | ABC-12345       |
| GCP          | BigQuery Billing Export    | F1ED-0732-5BDA   |
| OCI          | Cost Reports               | B91962           |

## Discussion / Scratch space

References

AWS - (<https://docs.aws.amazon.com/cur/latest/userguide/product-columns.html#product-details-P>)

Azure - (<https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields>)

GCP - (<https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage>)
(also, SKU information can be found via the BigQuery Pricing Export)

OCI - (<https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm>)

Potato / Tomato v1 discussion: <https://docs.google.com/document/d/1-flGM09zj3QkjSk8hlJolujZiCzVVmwi3TxDTaFJ7qM/edit#heading=h.u4wfvautplvp>

Potato / Tomato v2 discussion:\
<https://docs.google.com/document/d/18eL6G8WhbmEIHtrjqQlWqckgMRUQSs1aZwmwuRKQfqU/edit#heading=h.swm58hl317f3>
