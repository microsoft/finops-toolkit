# Commitment Discount Quantity

Commitment Discount Quantity is the amount of a [*commitment discount*](#glossary:commitment-discount) purchased or accounted for in *commitment discount* related [*rows*](#glossary:row) that is denominated in [Commitment Discount Units](#commitmentdiscountunit). The aggregated Commitment Discount Quantity across purchase records, pertaining to a particular [Commitment Discount ID](#commitmentdiscountid) during its [*term*](#glossary:term), represents the total Commitment Discount Units acquired with that commitment discount. For committed usage, the Commitment Discount Quantity is either the number of Commitment Discount Units consumed by a *row* that is covered by a *commitment discount* or is the unused portion of a *commitment discount* over a *charge period*. Commitment Discount Quantity is commonly used in *commitment discount* analysis and optimization use cases and only applies to *commitment discounts*, not [*negotiated discounts*](#glossary:negotiated-discount).

When [CommitmentDiscountCategory](#commitmentdiscountcategory) is "Usage" (usage-based *commitment discounts*), the Commitment Discount Quantity reflects the predefined amount of usage purchased or consumed. If [*commitment discount flexibility*](#glossary:commitment-discount-flexibility) is applicable, this value may be further transformed based on additional, provider-specific requirements. When CommitmentDiscountCategory is "Spend" (spend-based *commitment discounts*), the Commitment Discount Quantity reflects the predefined amount of spend purchased or consumed.

The CommitmentDiscountQuantity column adheres to the following requirements:

* CommitmentDiscountQuantity MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports *commitment discounts*.
* CommitmentDiscountQuantity MUST be of type Decimal and MUST conform to [Numeric Format](#numericformat) requirements.
* CommitmentDiscountQuantity MAY be null or any valid decimal value if [*CommitmentDiscountId*](#commitmentdiscountid) is not null and [*ChargeClass*](#chargeclass) is "Correction".

In cases where the ChargeCategory is "Purchase", CommitmentDiscountId is not null, and ChargeClass is not "Correction", the following applies:

* When [ChargeFrequency](#chargefrequency) is "One-Time", and CommitmentDiscountId is not null, CommitmentDiscountQuantity MUST be the positive quantity of CommitmentDiscountUnits, paid fully or partially upfront, that is eligible for consumption over the *commitment discount's* *term*.
* When ChargeFrequency is "Recurring", and CommitmentDiscountId is not null, CommitmentDiscountQuantity MUST be the positive quantity of CommitmentDiscountUnits that is eligible for consumption for each *charge period* that corresponds with the purchase.

In cases where the ChargeCategory is "Usage", CommitmentDiscountId is not null, and ChargeClass is not "Correction", the following applies:

* When [CommitmentDiscountStatus](#commitmentdiscountstatus) is "Used", CommitmentDiscountQuantity MUST be the positive, metered quantity of CommitmentDiscountUnits that is consumed over the *row's* *charge period*.
* When CommitmentDiscountStatus is "Unused", CommitmentDiscountQuantity MUST be the remaining, positive, unused quantity of CommitmentDiscountUnits for the *row's* *charge period*.

CommitmentDiscountQuantity MUST be null in all other cases.

## Column ID

CommitmentDiscountQuantity

## Display Name

Commitment Discount Quantity

## Description

The amount of a *commitment discount* purchased or accounted for in *commitment discount* related *rows* that is denominated in Commitment Discount Units.

## Usability Constraints

**Aggregation:** When aggregating Commitment Discount Quantity for commitment utilization calculations, it's important to exclude *commitment discount* purchases (i.e. when ChargeCategory is "Purchase") that are paid to cover future eligible charges (e.g., *commitment discount*). Otherwise, when accounting for all upfront or accrued purchases, it's important to exclude *commitment discount* usage (i.e. when ChargeCategory is "Usage"). This exclusion helps prevent double counting of these quantities in the aggregation.

## Content constraints

| Constraint      | Value            |
|:----------------|:-----------------|
| Column type     | Metric           |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | Decimal          |
| Value format    | [Numeric Format](#numericformat) |
| Number range    | Any valid decimal value |

## Introduced (version)

1.1
