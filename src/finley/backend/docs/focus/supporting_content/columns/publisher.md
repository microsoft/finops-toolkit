# Column: Publisher

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                                                                                         |
| --------- | ------------------------ | -------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR                      | Not available (closest is lineItem/LegalEntity, for non-marketplace rows this will equal the AWS Legal Entity) |
| GCP       | Big Query Billing Export | Exists in product_taxonomy, but not in a consistent location (e.g. GCP > Marketplace Services > MongoDB Inc.)  |
| Microsoft | Cost details             | PublisherName                                                                                                  |

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

| Provider  | Scenario                                                   | Pattern                                                                                                                                                     |
| --------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR provides lineItem/LegalEntity for non-marketplace rows | Not equivalent to a publisher. Following values are supported:<ul><li>Amazon Web Services, Inc.</li><li>Amazon Web Services India Private Limited</li></ul> |
| GCP       | ?                                                          |                                                                                                                                                             |
| Microsoft | ?                                                          |                                                                                                                                                             |

See [Appendix: Origination of cost data](../appendix/origination_of_cost_data.md) section for potential scenarios and proposed values for the Publisher dimension.

## Discussion / Scratch space

### Naming Pros/Cons

- Publisher is used by Microsoft because it's used to identify companies who "publish" services to the marketplace. This is synonymous with companies who publish books that are available for purchase at a bookstore. The company who created the book is known as the "publisher".
- ~~Service provider (instead of Publisher):~~
  - ~~Q&A:~~
    - ~~Who built, published and is providing the thing that I'm paying for? Service provider~~
  - ~~Notes from the table:~~
    - ~~The entity providing services (IaaS, PaaS, SaaS or professional services).~~
    - ~~Company that offers the software or professional services~~
    - ~~Company providing the software or services~~
    - ~~Infrastructure and services provider~~
    - ~~Etc.~~
