# Invoice Issuer

An Invoice Issuer is an entity responsible for invoicing for the [*resources*](#glossary:resource) or [*services*](#glossary:service) consumed. It is commonly
used for cost analysis and reporting scenarios.

The InvoiceIssuer column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset). This column MUST be of type String and MUST NOT contain null values.

See [Appendix: Origination of cost data](#originationofcostdata) section for examples of [Provider](#provider), [Publisher](#publisher) and
Invoice Issuer values that can be used for various purchasing scenarios.

## Column ID

InvoiceIssuerName

## Display Name

Invoice Issuer

## Description

The name of the entity responsible for invoicing for the *resources* or *services* consumed.

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
