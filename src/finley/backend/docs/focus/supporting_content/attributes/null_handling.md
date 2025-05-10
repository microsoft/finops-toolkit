# Null handling

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                 | Scenario                                                                                                                                             |
| --------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR                      | Product_operation shows the type of operation used by a consumer.<br>However, in scenarios where the row represents tax, this column is set to null. |
| GCP       | Big Query Billing Export | Credits.name is null when a credit is not applied.                                                                                                   |
| Microsoft | Cost Details             | ResourceGroup is null when a charge is not from a resource deployed to a resource group.                                                             |
| OCI       | Cost reports             | product/availabilityDomain is null when resource is an Object Store bucket                                                                           |

## Discussion / Scratch space

- Two main classes - user-controlled columns and provider-controlled columns
- [*Tags*](#glossary:tag) are user defined and may include empty strings
  - User may not set a value here - where it would be null
  - If *tags* come in a single column serialized as a map or something equivalent, then the empty *tag* value issue may not be an issue
  - If no *tags* were defined, it should be set to null OR an empty JSON object<br>
    `TODO:` In appropriate place, define how *tags* should be provided in the billing data by providers
- Outside of *tags*, every value should be null where it can't be specified as opposed to placeholder values.
  - Is there a case where on a required column that doesn't allow nulls, and a provider doesn't have a valid value that applies, we may need to come up with a placeholder value
  - We don't have a good use case for this right now, so punt on that for now and only allow nulls or 'valid values'
- May require  thinking about cost outside of cloud/SaaS space
- Is there a difference between qualitative and quantitative columns<br>
  `TODO:` come back after metrics and other quantitative columns are defined so we can specify if dimensions should have separate null handling compared to metrics/measures columns
  - Many data analytics solutions will ignore NULL values when using aggregation functions. Aggregation functions are frequently used on quantitative columns
- Cost data generators shouldn't intentionally convert data (e.g. convert empty *tag* -> null or the reverse null -> 'Not Set')
  - There were arguments on both sides of this
