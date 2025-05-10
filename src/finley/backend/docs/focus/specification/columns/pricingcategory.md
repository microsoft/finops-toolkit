# Pricing Category

Pricing Category describes the pricing model used for a charge at the time of use or purchase. It can be useful for distinguishing between charges incurred at the [*list unit price*](#glossary:list-unit-price) or a reduced price and exposing optimization opportunities, like increasing [*commitment discount*](#glossary:commitment-discount) coverage.

The PricingCategory column adheres to the following requirements:

* PricingCategory MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports more than one pricing category across all SKUs and MUST be of type String.
* PricingCategory MUST NOT be null when [ChargeClass](#chargeclass) is not "Correction" and [ChargeCategory](#chargecategory) is "Usage" or "Purchase", MUST be null when ChargeCategory is "Tax", and MAY be null for all other combinations of ChargeClass and ChargeCategory.
* PricingCategory MUST be one of the allowed values.
* PricingCategory MUST be "Standard" when pricing is predetermined at the agreed upon rate for the [billing account](#glossary:billing-account).
* PricingCategory MUST be "Committed" when the charge is subject to an existing *commitment discount* and is not the purchase of the *commitment discount*.
* PricingCategory MUST be "Dynamic" when pricing is determined by the provider and may change over time, regardless of predetermined agreement pricing.
* PricingCategory MUST be "Other" when there is a pricing model but none of the allowed values apply.

## Column ID

PricingCategory

## Display Name

Pricing Category

## Description

Describes the pricing model used for a charge at the time of use or purchase.

## Content constraints

| Constraint      | Value          |
| :-------------- | :------------- |
| Column type     | Dimension      |
| Feature level   | Conditional    |
| Allows nulls    | True           |
| Data type       | String         |
| Value format    | Allowed values |

Allowed values:

| Value     | Description                                                                                                                                                                                                              |
| :-------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Standard  | Charges priced at the agreed upon rate for the billing account, including [*negotiated discounts*](#glossary:negotiated-discount). This pricing includes any flat rate and volume/tiered pricing but does not include dynamic pricing or reduced pricing due to the application of a *commitment discount*. This does include the purchase of a commitment discount at agreed upon rates. |
| Dynamic   | Charges priced at a variable rate determined by the provider. This includes any product or service with a unit price the provider can change without notice, like interruptible or low priority resources.               |
| Committed | Charges with reduced pricing due to the application of the *commitment discount* specified by the Commitment Discount ID.                                                                                                |
| Other     | Charges priced in a way not covered by another pricing category.                                                                                                                                                         |

## Introduced (version)

1.0-preview
