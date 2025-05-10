# Billed Cost

The [*billed cost*](#glossary:billed-cost) represents a charge serving as the basis for invoicing, inclusive of the impacts of all reduced rates and discounts while excluding the [*amortization*](#glossary:amortization) of relevant purchases (one-time or recurring) paid to cover future eligible charges. This cost is denominated in the [Billing Currency](#billingcurrency). The Billed Cost is commonly used to perform FinOps capabilities that require cash-basis accounting such as cost allocation, budgeting, and invoice reconciliation.

The BilledCost column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) and MUST NOT be null. This column MUST be of type Decimal, MUST conform to [Numeric Format](#numericformat), and be denominated in the BillingCurrency. The sum of the BilledCost for [*rows*](#glossary:row) in a given [*billing period*](#glossary:billing-period) MUST match the sum of the invoices received for that *billing period* for a [*billing account*](#glossary:billing-account).

## Column ID

BilledCost

## Display Name

Billed Cost

## Description

A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the *amortization* of upfront charges (one-time or recurring).

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
