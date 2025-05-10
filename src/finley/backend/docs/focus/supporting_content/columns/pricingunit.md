# Column: PricingUnit

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                                        | Column                                    |
|:----------|:------------------------------------------------|:------------------------------------------|
| AWS       | CUR                                             | pricing/unit is closest match             |
| GCP       | BigQuery Billing Export                         | usage.pricing_unit is closest match       |
| Microsoft | Cost details                                    | UnitOfMeasure is closest match            |
| OCI       | Cost and Usage Report;<br>List Pricing REST API | cost/billingUnitReadable is closest match<br>*Note: The values in this column are similar but not identical to those in the List Pricing REST API; therefore, it may be preferable to rely on the List Pricing REST API, which we already plan to use for ListUnitPrice.* |

*Note: Where applicable, normalization should take place, as the column is specified as semi-normalized, adhering to the values and format requirements specified in the Unit Format attribute.*

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Scenario                | Pattern                                                                                                                              |
|-----------|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| AWS       | CUR                     | hours; Hrs; Queries; GB; Secrets; vCPU-Hours; API Requests; Keys; Alarms etc.                                                        |
| GCP       | BigQuery Billing Export | tebibyte; count; gibibyte; tebibyte; hour; gibibyte hour; gibibyte month; gibibyte hour; gibibyte; hour; count; gibibyte month; etc. |
| Microsoft | Cost details            | 1 Hour; 10 Hours; 1/Month; 1 GB; 10K; 1 GB-Month; etc.                                                                               |
| OCI       | Cost and Usage Report   | ONE GiB HOURS STORAGE_SIZE; ONE GiB HOURS MEMORY; etc.                                                                               |
| OCI       | List Pricing REST API   | Gigabyte Per Hour; etc.<br>*Note: Gigabyte Per Hour corresponds to both ONE GiB HOURS STORAGE_SIZE and ONE GiB HOURS MEMORY*         |

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

### PricingUnit - non-normalized vs semi-normalized/normalized

* After several discussions, the team has decided to use PricingUnit, which represents a semi-normalized version and should adhere to the values and format requirements specified in the [Unit Format]((../../specification/attributes/unitformat.md)) attribute, as opposed to the earlier proposed non-normalized version (retaining, i.e., merely mapping as-is values provided by providers, which are typically already present in current billing data).

* PricingUnit is commonly used for scenarios like validating unit prices against the price sheet and invoices (when the invoice includes that level of detail) and thus MUST be semantically equal to the corresponding value provided in the price list and invoice (when the invoice includes that level of detail). Since price sheets and invoices fall outside the scope of FOCUS, we cannot impose values that are identical but only semantically equal. To facilitate programmatic validation over time, providers SHOULD adopt and use the same unit format requirements in their metering, pricing, and invoicing systems.

* In certain cases, PricingUnit may even encompass both quantifiers and actual measurement units. In the future (post 1.0), we will consider the introduction of additional columns to facilitate:
  * Identification of charge records with block-pricing applied and the actual block-price size.
  * Potentially, even improved comparability of pricing quantities across different entities being measured, priced, and charged, both within a single provider's offerings and across various providers, by differentiating quantifiers from base measurement units.

* Note: In preparation for formulating guidelines and recommended values for the semi-normalized measurement unit, it is essential to gain insight into as many distinct pricing and usage measurement unit values currently used by providers in their pricing and usage systems.
  * List of all distinct Microsoft/Azure EA unit of measure values is available at this [link](https://github.com/microsoft/finops-toolkit/pull/348).

### Add into an appendix that describes pricing units, tiers, strategies

The most basic math for calculating costs of cloud or SaaS services is Unit Price * Quantity = Cost.  Because different services require measuring different fundamental usage units while using a common billing format, the quantity column’s meaning or scale is unclear without specifying the unit of measure.
