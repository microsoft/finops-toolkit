# Currency Code Format

## Example provider mappings

Current column mappings found in available data sets:

| Provider | Data set                 | Column         |
|:---------|:-------------------------|:---------------|
| AWS      | CUR                      | CurrencyCode   |
| GCP      | Big Query Billing Export | Currency       |
| Azure    | Cost details             | BilledCurrency |
| OCI      | Cost reports             | cost/currencyCode |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider | Data set                 | Example Value |
|:---------|:-------------------------|:--------------|
| AWS      | CUR                      | USD           |
| GCP      | Big Query Billing Export | EUR           |
| Azure    | Cost details             | JPY           |
| OCI      | Cost reports             | USD           |

## Requirements

* For monetary values representing the amount charged for an invoice or for an overall charge, the underlying charge to be formatted should be represented as a decimal or string format
* Prices and charges will be returned in currency set on the billing account unless a specific currency is included on the request
* The character used as the thousands or decimal separator will be determined by the underlying currency being returned, based on industry standards

References:

AWS: [Currency Code](https://docs.aws.amazon.com/cur/latest/userguide/Lineitem-columns.html)

GCP: [Currency](https://cloud.google.com/billing/docs/resources/currency)

Azure: [Pricing FAQ](https://azure.microsoft.com/en-us/pricing/faq/)

OCI: [OCI Price List](https://www.oracle.com/cloud/price-list/)

## Discussion / Scratch space

There is a dimension of currency rate conversions for billing data with multiple currencies. See [Currency](https://cloud.google.com/billing/docs/resources/currency). We may need to consider adding currency conversion rates to future versions of the specification
