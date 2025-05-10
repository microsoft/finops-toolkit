# Column: InvoiceIssuer

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column               |
|-----------|--------------------------|----------------------|
| AWS       | CUR                      | bill/InvoicingEntity |
| GCP       | Big Query Billing Export | Not available        |
| Microsoft | Cost details             | Enterprise Agreement (EA): Not available<br>Cloud Solution Provider (CSP): PartnerId / PartnerName |

### Documentation

AWS:
> [Billing details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/billing-columns.html)

GCP:  
No dimensions providing this data either in the billing or in the pricing sheet.

Microsoft:
> [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Scenario                                                                   | Pattern       |
|-----------|----------------------------------------------------------------------------|---------------|
| AWS       | CUR provides the entity responsible for invoicing via bill/InvoicingEntity | Following values are supported:<ul><li>Amazon Web Services, Inc.</li><li>Amazon Web Services India Private Limited</li><li>Amazon Web Services South Africa Proprietary Limited</li></ul> |
| GCP       | Not available                                                              |               |
| Microsoft | ?                                                                          |               |

- Where do you get the following Azure Invoice Issuer values today?
  - Azure China scenario, is that in the CSP data under PartnerId/PartnerName?

See [Appendix: Origination of cost data](../appendix/origination_of_cost_data.md) section for potential scenarios and proposed values for the Invoice Issuer dimension.

## Discussion / Scratch space

- Within a single well known cloud provider, there may be different entities that do invoicing for usage. For example, in some cases a region may be operated by a different entity / partner even though the overall product is sold as AWS or Azure.
- Google invoices may show invoice entities such as Google France SarL and Google, Inc. USA (though not available in the BigQuery billing export).
