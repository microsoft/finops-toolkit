# Contracted Cost

Contracted Cost represents the cost calculated by multiplying [*contracted unit price*](#glossary:contracted-unit-price) and the corresponding [Pricing Quantity](#pricingquantity). Contracted Cost is denominated in the [Billing Currency](#billingcurrency) and is commonly used for calculating savings based on negotiation activities, by comparing it with [List Cost](#listcost). If [*negotiated discounts*](#glossary:negotiated-discount) are not applicable, the Contracted Cost defaults to the List Cost.

The ContractedCost column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) and MUST NOT be null. This column MUST be of type Decimal, MUST conform to [Numeric Format](#numericformat) requirements, and be denominated in the BillingCurrency. When [ContractedUnitPrice](#contractedunitprice) is present and not null, multiplying the ContractedUnitPrice by PricingQuantity MUST produce the ContractedCost, except in cases of [ChargeClass](#chargeclass) "Correction", which may address PricingQuantity or any cost discrepancies independently.

In cases where the ContractedUnitPrice is present and null, the following applies:

* The ContractedCost of a charge calculated based on other charges (e.g., when the [ChargeCategory](#chargecategory) is "Tax") MUST be calculated based on the ContractedCost of those related charges.
* The ContractedCost of a charge unrelated to other charges (e.g., when the [ChargeCategory](#chargecategory) is "Credit") MUST match the [BilledCost](#billedcost).

## Column ID

ContractedCost

## Display Name

Contracted Cost

## Description

Cost calculated by multiplying *contracted unit price* and the corresponding Pricing Quantity.

## Usability Constraints

**Aggregation:** When aggregating Contracted Cost for savings calculations, it's important to exclude either [Charge Category](#chargecategory) "Purchase" charges (one-time and recurring) that are paid to cover future eligible charges (e.g., [Commitment Discount](#glossary:commitment-discount)) or the covered [Charge Category](#chargecategory) "Usage" charges themselves. This exclusion helps prevent double counting of these charges in the aggregation. Which set of charges to exclude depends on whether cost are aggregated on a billed basis (exclude covered charges) or accrual basis (exclude Purchases for future charges). For instance, charges categorized as [Charge Category](#chargecategory) "Purchase" and their related [Charge Category](#chargecategory) "Tax" charges for a Commitment Discount might be excluded from an accrual basis cost aggregation of Contracted Cost. This is because the "Usage" and "Tax" charge records provided during the term of the commitment discount already specify the Contracted Cost. Purchase charges that cover future eligible charges can be identified by filtering for [Charge Category](#chargecategory) "Purchase" records with a [Billed Cost](#billedcost) greater than 0 and an [Effective Cost](#effectivecost) equal to 0.

## Content Constraints

| Constraint      | Value                   |
|:----------------|:------------------------|
| Column type     | Metric                  |
| Feature level   | Mandatory               |
| Allows nulls    | False                   |
| Data type       | Decimal                 |
| Value format    | [Numeric Format](#numericformat) |
| Number range    | Any valid decimal value |

## Introduced (version)

1.0
