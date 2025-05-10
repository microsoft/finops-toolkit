# Column: ListUnitPrice

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                                           | Column                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| :-------- | :------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR;<br>AWS Price List API                         | the closest match - pricing/publicOnDemandRate: The public On-Demand Instance rate in this billing period for the specific row of usage. If there are SKUs with multiple On-Demand public rates, the equivalent rate for the highest tier is displayed. For example, services offering free-tiers or tiered pricing.<br>_Note: Since currently only pricing/publicOnDemandRate definition includes note regarding highest tier, it is unclear whether volume-based pricing applies to all unit prices (rates) in CUR files. If it's not consistent, the practitioner might have to rely on the AWS Price List API._ |
| GCP       | BigQuery Pricing Data Export;<br>Cloud Billing API | Not available in BigQuery Billing Export but can be resolved from both the list_price Struct in BigQuery Pricing Data Export and the Cloud Billing API                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Microsoft | Cost details;<br>Azure Retail Prices REST API      | pay-as-you-goPrice/PayGPrice: Retail price for the resource                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| OCI       | List Pricing REST API                              | Not available in Cost and Usage Report but can be resolved from the List Pricing REST API                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

## References and Resources

### AWS

* [Pricing details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/pricing-columns.html)
* [Using the AWS Price List API - AWS Billing](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-changes.html)

### GCP

* [Structure of pricing data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/pricing-data)
* [Get Google Cloud pricing information | Cloud Billing (GCP Cloud Billing API)](https://cloud.google.com/billing/docs/how-to/get-pricing-information-api)
* [Structure of Detailed data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage)

### Microsoft

* [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)
* [Azure Retail Prices REST API overview | Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)

### OCI

* [Cost and Usage Reports Overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)
* [Estimate Your Monthly Cost (List Pricing REST API)](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup_topic-Estimating_Costs.htm#accessing_list_pricing)

## Example usage scenarios

* See [Appendix: Quantity-Driven Pricing strategies](../appendix/quantity_driven_pricing_strategies.md) section for more information on
  * Quantity-Driven Pricing strategies (such as flat-rate, volume-based rates and tier-based rating)
  * related UC scenarios
  * Current values observed in billing data for various scenarios
  * Alternative data sources for various scenarios
* See [Pricing Support – UCs and Data samples Spreadsheet](https://docs.google.com/spreadsheets/d/1AZ-vtkKeKwYc8rqhxP1zMTnAVAS-svmWQQmr8cpv-IM/edit#gid=117987709) for additional UC scenarios and sample data.

## Discussion / Scratch space

### Prices and Currencies

* We deliberated on whether to specify both BillingCurrency and PricingCurrency and decided to enforce a single currency, specifically BillingCurrency. This approach provides consistency and simplifies invoice reconciliation. Since some providers don't include List Unit Prices in BillingCurrency in their public price sheets, the inclusion of a CurrencyExchangeRate dimension in the billing data becomes imperative (name subject to change). This is necessary to ensure we can accurately compare and match ListUnitPrices provided in billing data with those published in public price sheets.

### Current data sources and SkuPriceId

* For GCP and OCI, Pricing Data serves as the sole data source for ListUnitPrice, while for AWS, it is the preferred data source due to concerns related to volume/tier-based pricing. To determine the relevant price in Pricing Data for a specific charge record, the billing data must include the SkuPriceId. * Considering that providers publish not only list/on-demand prices but also unit prices inclusive of commitment discounts (and perhaps more), we can't directly associate ListUnitPrice with the SkuPriceId.
* How to resolve the ListUnitPrice from the Price Sheet or Pricing API based on SkuPriceId? Consider introducing an additional column that would contain the ID of the corresponding List/On-Demand SKU Price ID, instead of providing guidelines and expecting practitioners to resolve it.
* As previously mentioned, when BillingCurrency and PricingCurrency differ, the exchange rate must also be considered.

### Free-tier, volume/tier-based, BYOL-based and dynamically-priced SKU rates

* For the definition of the ListUnitPrice, we considered the following versions:
  * OPTION A: The List Unit Price represents a suggested provider-published unit price for a single [Pricing Unit](#pricingunit) of the associated SKU, which incorporates free-tier, volume/tier-based, BYOL-based and dynamically priced SKU rates, while excluding any discounts.
    * The list of included reduced-rates based on Cloud FinOps - Rate optimization chapter
    * Is it ok to assume that rates of interruptible resources and services (spare capacity, spot) fall into category of dynamically priced SKU rates? (do we plan to cover this in the glossary?)
  * OPTION B: The List Unit Price represents a suggested provider-published unit price for a single [Pricing Unit](#pricingunit) of the associated SKU, exclusive of any discounts.
    * Is it ok to assume that practitioners perceive mentioned rates as reduced rates rather than discounts?
  * OPTION C: The List Unit Price represents a suggested provider-published unit price for a single [Pricing Unit](#pricingunit) of the associated SKU, exclusive of any negotiated or commitment discounts.
    * Is it ok to assume that those are the only two discounts?
* Being inclusive of free-tier, volume/tier-based, BYOL-based and dynamically priced SKU rates, the List Unit Price cannot be used for calculating savings based on volume/tier-based pricing, the use of pre-owned software licenses (BYOL - Bring Your Own License), leveraging interruptible resources and/or services, or optimizing usage to take advantage of dynamic pricing models.

### Naming challenges

Two naming challenges were resolved through polls, giving signed members the chance to voice their preferences.

* POLL 1: Please select the term you prefer to use when referring to the published rate and corresponding cost without any discounts:
  * Retail - 3 votes
  * List - 13 votes
  * Market - 1 vote
  * PAYG - 1 vote
  * Public - 5 votes
* POLL 2: Please select the term you prefer to use when referring to the price for a single unit of measure:
  * Rate - 2 votes
  * Unit Price - 13 votes
  * Price - 2 votes

The following dimensions and metrics names were influenced by these decisions:

* List Cost
* Billed Unit Price
* Negotiated Unit Price
* List Unit Price