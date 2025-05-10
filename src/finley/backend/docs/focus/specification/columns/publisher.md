# Publisher

A Publisher is an entity that produces the [*resources*](#glossary:resource) or [*services*](#glossary:service) that were purchased. It is commonly used for cost analysis and reporting scenarios.

The Publisher column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset). This column MUST be of type String and MUST NOT contain null values.

See [Appendix: Origination of cost data](#originationofcostdata) section for examples of [Provider](#provider), Publisher and
[Invoice Issuer](#invoiceissuer) values that can be used for various purchasing scenarios.

## Column ID

PublisherName

## Display Name

Publisher

## Description

The name of the entity that produced the *resources* or *services* that were purchased.

## Content Constraints

| Constraint      | Value           |
|:----------------|:----------------|
| Column type     | Dimension       |
| Feature level   | Mandatory       |
| Allows nulls    | False           |
| Data type       | String          |
| Value format    | \<not specified> |

## Introduced (version)

0.5
