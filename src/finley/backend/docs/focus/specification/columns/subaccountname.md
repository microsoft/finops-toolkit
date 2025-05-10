# Sub Account Name

A Sub Account Name is a display name assigned to a [*sub account*](#glossary:sub-account). Sub account Name is commonly used for scenarios like grouping based on organizational constructs, access management needs, and cost allocation strategies.

The SubAccountName column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports a *sub account* construct. This column MUST be of type String. If a charge does not apply to a *sub account*, the SubAccountName column MUST be null.

See [Appendix: Grouping constructs for resources or services](#groupingconstructsforresourcesorservices) for details and examples of the different grouping constructs supported by FOCUS.

## Column ID

SubAccountName

## Display Name

Sub Account Name

## Description

A name assigned to a grouping of [*resources*](#glossary:resource) or [*services*](#glossary:service), often used to manage access and/or cost.

## Content constraints

| Constraint      | Value           |
|:----------------|:----------------|
| Column type     | Dimension       |
| Feature level   | Conditional     |
| Allows nulls    | True            |
| Data type       | String          |
| Value format    | \<not specified> |

## Introduced (version)

0.5
