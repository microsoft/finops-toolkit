# Charge Description

A Charge Description provides a high-level context of a [*row*](#glossary:row) without requiring additional discovery. This column is a self-contained summary of the charge's purpose and price. It typically covers a select group of corresponding details across a billing dataset or provides information not otherwise available.

The ChargeDescription column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset), MUST be of type String, and SHOULD NOT be null. Providers SHOULD specify the length of this column in their publicly available documentation.

## Column ID

ChargeDescription

## Display Name

Charge Description

## Description

Self-contained summary of the charge's purpose and price.

## Content Constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Mandatory        |
| Allows nulls    | True             |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

1.0-preview
