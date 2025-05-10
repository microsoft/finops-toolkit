# Column: BillingCurrency

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                   | Column                   |
|-----------|----------------------------|--------------------------|
| AWS       | CUR                        | CurrencyCode             |
| Google Cloud | Big Query Billing Export   | Currency                 |
| Microsoft | Cost details               | EA: BillingCurrency      |
| OCI       | Cost reports               | cost/currencyCode        |


## Requirements

- For monetary values representing the amount charged for an invoice or for an overall charge, the underlying charge to be formatted should be represented as a decimal or string format.
- Prices and charges will be returned in currency set on the billing account unless a specific currency is included on the request.
- The character used as the thousands or decimal separator will be determined by the underlying currency being returned, based on industry standards.


## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                   | Scenario                   |
|-----------|----------------------------|----------------------------|
| AWS       | CUR                        | USD                        |
| Google Cloud | Big Query Billing Export   | INR                        |
| Microsoft | Cost details               | USD                        |
| OCI       | Cost reports               | USD                        |


## References

AWS: https://docs.aws.amazon.com/cur/latest/userguide/Lineitem-columns.html#l-C

Google Cloud: https://cloud.google.com/billing/docs/resources/currency

Azure: https://azure.microsoft.com/en-us/pricing/faq/

OCI: https://www.oracle.com/cloud/price-list/
