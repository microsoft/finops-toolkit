# Column: Provider

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                               |
|-----------|--------------------------|------------------------------------------------------|
| AWS       | CUR                      | Not available (closest is bill/BillingEntity)        |
| GCP       | Big Query Billing Export | Not available (closest is join with pricing export on sku.id to get business_entity_name) |
| Microsoft | Cost details             | EA and MCA: Not available (closest is provider or PublisherType)<br>Management group: Provider |

### Documentation

AWS:
> [Billing details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/billing-columns.html)

GCP:  
> [Structure of pricing data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/pricing-data)

No dimensions providing this data in billing, but can map based on SKU from the pricing sheet.

Microsoft:
> [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Scenario      | Pattern                      |
|-----------|---------------|------------------------------|
| AWS       | Not available |                              |
| GCP       | Not available |                              |
| Microsoft | Cost details  | Management group: Azure, AWS |

See [Appendix: Origination of cost data](../appendix/origination_of_cost_data.md) section for potential scenarios and proposed values for the Provider dimension.

## Discussion / Scratch space

- What about marketplace type cases where you're buying through a CSP?
  - Provider vs Publisher?
  - You buy DataDog on marketplace, the publisher would be Datadog and Provider would be CSP
  - Split to 3:
    - Who made it available for purchase - provider
    - who did I pay - Invoicing Entity (who's billing you)
    - who built the thing that I bought - Publisher
- Are we referring to these as 'Vendors' or 'Providers'? Would 'vendor' be confused with cost management vendors?
  - Use provider
- Regarding Provider support/mappings:
  - AWS bill_billing_entity (supported values: AWS, AWS Marketplace) is more similar to Microsoft publisherType (supported values: Microsoft/Azure, Marketplace, AWS)?
- Need to determine what field we use to differentiate branded services (e.g. GCP vs. Google Workspace or Microsoft Azure vs. Microsoft 365)
  - Should Publisher only be a Company name?
  - Discussion: it should be based on how massive the product lines are - the columns more detailed than Publisher would guide whether you might do something like split Microsoft into Microsoft Azure and Microsoft 365.
  - To be revisited in governance pass. Also, ultimately, this is up to each provider/publisher/Invoice Entity to decide how they want their naming to appear (not a normalized field).
- Need to determine what field we use to differentiate native services from third-party marketplace services.

### Naming Pros/Cons

- Vendor - Can be confusing since we're talking about 3 different things (provider, invoicing entity, publisher)
- 'Cloud' in naming: decided it would not be generic to prefix with cloud e.g. Cloud Provider
