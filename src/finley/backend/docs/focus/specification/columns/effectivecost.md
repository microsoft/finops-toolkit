# Effective Cost

Effective Cost represents the [*amortized*](#glossary:amortization) cost of the [*charge*](#glossary:charge) after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge. The *amortized* portion included should be proportional to the [Pricing Quantity](#pricingquantity) and the time granularity of the data. Since amortization breaks down and spreads the cost of a prepaid purchase, to subsequent eligible charges, the Effective Cost of the original prepaid charge is set to 0. Effective Cost does not mix or "blend" costs across multiple charges of the same service. This cost is denominated in the [Billing Currency](#billingcurrency). The Effective Cost is commonly utilized to track and analyze spending trends.

This column resolves two challenges that are faced by practitioners:

1. Practitioners need to *amortize* relevant purchases, such as upfront fees, throughout the *commitment* and distribute them to the appropriate reporting groups (e.g. [*tags*](#glossary:tag), [*resources*](#glossary:resource)).
2. Many [*commitment discount*](#glossary:commitment-discount) constructs include a recurring expense for the *commitment* for every [*billing period*](#glossary:billing-period) and must distribute this cost to the *resources* using the *commitment*. This forces reconciliation between the initial *commitment* [*row*](#glossary:row) per period and the actual usage *rows*.

The EffectiveCost column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) and MUST NOT be null. This column MUST be of type Decimal, MUST conform to [Numeric Format](#numericformat) requirements, and be denominated in the BillingCurrency. EffectiveCost MUST be 0 when ChargeCategory is "Purchase" and the purchase is intended to cover future eligible charges. The aggregated EffectiveCost for a billing period may not match the charge received on the invoice for the same *billing period*.

In cases where the [ChargeCategory](#chargecategory) is not "Usage" or "Purchase", the following applies:

* The EffectiveCost MUST be calculated based on the EffectiveCost of the related charges if the charge is calculated based on other charges (e.g. [ChargeCategory](#chargecategory) is "Tax").
* The EffectiveCost MUST match the [BilledCost](#billedcost) if the charge is unrelated to other charges (e.g. [ChargeCategory](#chargecategory) is "Credit").
* When CommitmentDiscountStatus is "Unused", the EffectiveCost MUST be the total committed cost consumed for the given charge period minus related usage charges.

## Column ID

EffectiveCost

## Display Name

Effective Cost

## Description

The *amortized* cost of the *charge* after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge.

### Concerning Granularity and Distribution of Recurring Fee

Providers should distribute the *commitment* purchase amount instead of including a *row* at the beginning of a period so practitioners do not need to manually distribute the fee themselves.

### Concerning Amortization Approaches

Eligible purchases should be *amortized* using a methodology determined by the provider that reflects the needs of their customer base and is proportional to the Pricing Quantity and the time granularity of the *row*. Should a practitioner desire to *amortize* relevant purchases using a different approach, the practitioner can do so using the [Billed Cost](#billedcost) for the line item representing the initial purchase.

## Content constraints

|    Constraint   |      Value              |
|:----------------|:------------------------|
| Column type     | Metric                  |
| Feature level   | Mandatory               |
| Allows nulls    | False                   |
| Data type       | Decimal                 |
| Value format    | [Numeric Format](#numericformat) |
| Number range    | Any valid decimal value |

## Introduced (version)

0.5
