# Consumed Unit

The Consumed Unit represents a provider-specified measurement unit indicating how a provider measures usage of a metered SKU associated with a [*resource*](#glossary:resource) or [*service*](#glossary:service). Consumed Unit complements the [Consumed Quantity](#consumedquantity) metric. It is often listed at a finer granularity or over a different time interval when compared to [Pricing Unit](#pricingunit) (complementary to [Pricing Quantity](#pricingquantity)), and focuses on *resource* and *service* consumption, not pricing and cost.

The ConsumedUnit column adheres to the following requirements:

* ConsumedUnit MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports the measurement of usage.
* ConsumedUnit MUST be of type String, and the units of measure used in ConsumedUnit SHOULD adhere to the values and format requirements specified in the [UnitFormat](#unitformat) attribute.
* ConsumedUnit MUST NOT be null if [ChargeCategory](#chargecategory) is "Usage", [CommitmentDiscountStatus](#commitmentdiscountstatus) is not "Unused", and [ChargeClass](#chargeclass) is not "Correction".
* ConsumedUnit MAY be null if ChargeCategory is "Usage", CommitmentDiscountStatus is not "Unused", and ChargeClass is "Correction".
* ConsumedUnit MUST be null in all other cases.

## Column ID

ConsumedUnit

## Display Name

Consumed Unit

## Description

Provider-specified measurement unit indicating how a provider measures usage of a metered SKU associated with a *resource* or *service*.

## Content constraints

|    Constraint   |      Value      |
|:----------------|:----------------|
| Column type     | Dimension       |
| Feature level   | Conditional     |
| Allows nulls    | True            |
| Data type       | String          |
| Value format    | [Unit Format](#unitformat) recommended |

## Introduced (version)

1.0
