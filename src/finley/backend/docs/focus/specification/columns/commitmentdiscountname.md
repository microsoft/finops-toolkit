# Commitment Discount Name

A Commitment Discount Name is the display name assigned to a [*commitment discount*](#glossary:commitment-discount). The CommitmentDiscountName column is only applicable to *commitment discounts* and not [*negotiated discounts*](#glossary:negotiated-discount).

The CommitmentDiscountName column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports *commitment discounts*. This column MUST be of type String. The CommitmentDiscountName value MUST be null if the charge is not related to a *commitment discount* and MAY be null if a display name cannot be assigned to a *commitment discount*. CommitmentDiscountName MUST NOT be null if a display name can be assigned to a *commitment discount*.

## Column ID

CommitmentDiscountName

## Display Name

Commitment Discount Name

## Description

The display name assigned to a *commitment discount*.

## Content constraints

| Constraint      | Value            |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

1.0-preview
