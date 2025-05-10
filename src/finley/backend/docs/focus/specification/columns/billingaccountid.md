# Billing Account ID

A Billing Account ID is a provider-assigned identifier for a [*billing account*](#glossary:billing-account). *Billing accounts* are commonly used for scenarios like grouping based on organizational constructs, invoice reconciliation and cost allocation strategies.

The BillingAccountId column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset). This column MUST be of type String and MUST NOT contain null values. BillingAccountId MUST be a globally unique identifier within a provider.

See [Appendix: Grouping constructs for resources or services](#groupingconstructsforresourcesorservices) for details and examples of the different grouping constructs supported by FOCUS.

## Column ID

BillingAccountId

## Display Name

Billing Account ID

## Description

The identifier assigned to a *billing account* by the provider.

## Content constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Mandatory        |
| Allows nulls    | False            |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

0.5
