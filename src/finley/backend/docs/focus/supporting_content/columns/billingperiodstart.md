# Column: BillingPeriodStart

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                      |
|:----------|:-------------------------|:----------------------------|
| AWS       | CUR                      | bill/BillingPeriodStartDate |
| GCP       | BigQuery Billing Export  | invoice.month               |
| Microsoft | Cost details             | BillingPeriodStartDate      |
| OCI       | Usage proxy BillingScheduleSummary API | timeStart |

## Example usage scenarios

| Provider  | Data set                | Scenario                           | Value                    |
|:----------|:------------------------|:-----------------------------------|:-------------------------|
| AWS       | CUR                     | Not available                      | 2023-05-01T00:00:00.000Z |
| GCP       | BigQuery Billing Export | Not available                      | 202304                   |
| Microsoft | Cost details            | via Consumption API (usageDetails) | 2022-10-11T00:00:00Z     |
| Microsoft | Cost details            | via Cost export file               | 02/13/2023               |
| OCI       | Usage proxy BillingScheduleSummary API            | via [API](https://docs.oracle.com/en-us/iaas/api/#/en/usage-proxy/20190111/BillingScheduleSummary/)               | NA        |

## Discussion Topics

* Can multiple invoices be generated for a billing period for a billing account? Yes. e.g. AWS might send multiple invoices for a month for support, usage and adjustments
* Are billing periods always a month? Can it start from a middle of a month? Yes, commonly done monthly but can be quarterly, yearly etc.
