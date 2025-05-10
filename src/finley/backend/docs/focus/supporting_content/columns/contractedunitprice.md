# Column: ContractedUnitPrice

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                     | Column                   |
|:----------|:-----------------------------|:-------------------------|
| AWS       | CUR                          | Not available            |
| GCP       | BigQuery Billing Export;<br>BigQuery Pricing Data Export;<br>Cloud Billing API | Not available in BigQuery Billing Export<br>**price.effective_price** available only in detail export, i.e. available for a subset of resources/services<br>*see Discussion / Scratch space - GCP column mappings related issues for more details* |
| Microsoft | Cost details (actual/amortized) | UnitPrice<br>*see Discussion / Scratch space - Microsoft column mappings related issues for more details* |
| Microsoft | Cost details (FOCUS `1.0-preview(v1)`) | x_OnDemandUnitPrice |
| OCI       | Cost and Usage Report        | **cost/unitPrice** is the best match<br>*see Discussion / Scratch space - OCI column mappings related issues for more details* |

## References and Resources

### AWS

* [Line item details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/Lineitem-columns.html)

### GCP

* [Structure of Detailed data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage)
* [Structure of pricing data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/pricing-data)
* [Get Google Cloud pricing information | Cloud Billing (GCP Cloud Billing API)](https://cloud.google.com/billing/docs/how-to/get-pricing-information-api)

### Microsoft

* [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)
* [Azure Billing Enterprise APIs - PriceSheet | Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/enterprise/billing-enterprise-api-pricesheet)
  * Applies only to EA
  * *TODO: Check if there is a Microsoft Custom Prices REST API, which might provide custom prices for all account types*

### OCI

* [Cost and Usage Reports Overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)

## Example usage scenarios

* *TODO*

## Discussion / Scratch space

### GCP column mappings related issues

* **price.effective_price** is present only in detail export and thus available only for small subset of services/resources. In order to resolve this information we should rely on **BigQuery Pricing Data Export** and/or **Cloud Billing API**, which provide price related structs (out-of-scope of this document).
* Similar to cost, regardless of the data source we use, the resolved price does not include reductions provided in credits, which aligns with the definition of ContractedUnitPrice.

### Microsoft column mappings related issues

* [Azure Billing Enterprise APIs - PriceSheet | Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/enterprise/ provides information for EA.
* TODO: Check if there is a Microsoft Custom Prices REST API, which might provide custom/negotiated prices for all account types.
* **unitPrice** (The price per unit for the charge.) includes commitment discounts and thus is not applicable for all use cases. Furthermore,  
  * According to  documentation, it is available only for EA and PAYG.
  * It is unclear if it's denominated in Billing or Pricing currency. Noticed that for different accounts types different relations apply
    * In one case `unitPrice * quantity = costInBillingCurrency`
    * In another `unitPrice * quantity = costInUSD`

### OCI column mappings related issues

* Cost and usage reports contain **cost/unitPrice** (The cost billed to you for each unit of the resource used.) and **cost/unitPriceOverage** (The cost per unit of usage for overage usage of a resource.) columns.
* Analysis of sample billing data sets revealed the following:
  * Encountered records with NULL values in the cost/unitPriceOverage column, even when usage/billedQuantityOverage is not NULL and != 0. This discrepancy is not observed with the cost/unitPrice column.
  * Additionally, found records where usage/billedQuantityOverage is NOT NULL and slightly differs from cost/unitPrice. This suggests that the discounted price continues to apply even when the customer exceeds their annual commitment during the commitment/contract period (consistent with OCI documentation).
* Conclusion: we currently **prefer cost/unitPrice** over cost/unitPriceOverage
