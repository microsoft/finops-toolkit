# Column: Consumed Unit

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                | Provider column        |
|:----------|:------------------------|:-----------------------|
| AWS       | CUR                     | pricing/unit (pricing not usage) |
| GCP       | BigQuery Billing Export | usage.unit             |
| Microsoft | Cost details            | UnitOfMeasure Quantity |

## Example scenarios for current provider data

Current values observed in billing data for various scenarios:

| Provider | Provider Column | Example Value                                          |
|:---------|:----------------|:-------------------------------------------------------|
| AWS      | pricing_unit    | Gigabyte, Month, Requests, GB-MONTH, Hrs, Seconds      |
| GCP      | usage.unit      | Gigabyte, hour, mebibyte, second, month                |
| Azure    | UnitOfMeasure   | 1 GB, 1 GB/Month, 100 Hours, 1/Day, 10K, 1 GiB Second  |

## Discussion Topics

* AWS and Azure Usage Units are not currently meeting the requirements recommended by the UnitFormat attribute. As such values from these providers are not recommended to be used directly. The formatting should be updated on values in Usage and Pricing Unit columns.
* May 6th, 2024: After much discussion, it was agreed upon by the maintainers to rename this column to 'ConsumedUnit' and the related quantity to 'ConsumedQuantity' to reduce confusion between what AWS calls lineitem/UsageAmmount. The modification done to the previous UsageUnit content: Specify that this column applies only to 'Usage' rows - as it was previously written as 'usage or purchase'. That now becomes consistent with the subsequent sentence of the introductory paragraph which describes the column as measuring consumption.
* More details on the May 6th, 2024 decision can be found in (consumedquantity)[../consumedquantity.md] supporting content.