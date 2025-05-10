# SKU ID

A SKU ID is a unique identifier that defines a provider-supported construct for organizing properties that are common across one or more [*SKU Prices*](#glossary:sku-price). SKU ID can be referenced on a catalog or [*price list*](#glossary:price-list) published by a provider to look up detailed information about the SKU. The composition of the properties associated with the SKU ID may differ across providers. Some providers may not support the [*SKU*](#glossary:sku) construct and instead associate all such properties directly with the *SKU Price*. SKU ID is commonly used for analyzing cost based on *SKU*-related properties above the pricing constructs.

The SkuId column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider publishes a SKU list. This column MUST be of type String. It MUST NOT be null when [ChargeClass](#chargeclass) is not "Correction" and [ChargeCategory](#chargecategory) is "Usage" or "Purchase", MUST be null when ChargeCategory is "Tax", and MAY be null for all other combinations of ChargeClass and ChargeCategory. SkuId MUST equal SkuPriceId when a provider does not support an overarching SKU ID construct.

## Column ID

SkuId

## Display Name

SKU ID

## Description

A unique identifier that defines a provider-supported construct for organizing properties that are common across one or more *SKU Prices*.

## Content constraints

| Constraint      | Value            |
| :-------------- | :--------------- |
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

1.0-preview
