# SKU Price ID

A SKU Price ID is a unique identifier that defines the unit price used to calculate the charge. SKU Price ID can be referenced on a [*price list*](#glossary:price-list) published by a provider to look up detailed information, including a corresponding list unit price. The composition of the properties associated with the SKU Price ID may differ across providers. SKU Price ID is commonly used for analyzing cost based on pricing properties such as Terms and Tiers.

The SkuPriceId column adheres to the following requirements:

* SkuPriceId MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider publishes a SKU price list and MUST be of type String.
* SkuPriceId MUST define a single unit price used for calculating the charge.
* [ListUnitPrice](#listunitprice) MUST be associated with the SkuPriceId in the provider published price list.
* SkuPriceId MUST NOT be null when [ChargeClass](#chargeclass) is not "Correction" and [ChargeCategory](#chargecategory) is "Usage" or "Purchase", MUST be null when ChargeCategory is "Tax", and MAY be null for all other combinations of ChargeClass and ChargeCategory.
* A given value of SkuPriceId MUST be associated with one and only one [SkuId](#skuid), except in cases of [commitment discount flexibility](#glossary:commitment-discount-flexibility).
* If a provider does not have a SkuPriceId and wants to include information in columns linked to SkuPriceId such as ListUnitPrice or [SkuPriceDetails](#skupricedetails), the SkuId MAY be used in the SkuPriceId column as long as it adheres to the above conditions.

## Column ID

SkuPriceId

## Display Name

SKU Price ID

## Description

A unique identifier that defines the unit price used to calculate the charge.

## Content constraints

| Constraint       | Value          |
| :--------------- | :------------- |
| Column type      | Dimension      |
| Feature level    | Conditional    |
| Allows nulls     | True           |
| Data type        | String         |
| Value format     | \<not specified> |

## Introduced (version)

1.0-preview
