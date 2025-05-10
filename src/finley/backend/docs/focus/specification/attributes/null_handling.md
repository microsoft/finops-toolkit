# Null Handling

Cost data [*rows*](#glossary:row) that don't have a value that can be presented for a column must be handled in a consistent way to reduce friction for FinOps practitioners who consume the data for analysis, reporting, and other use cases.

All columns defined in the FOCUS specification MUST follow the null handling requirements listed below. Custom columns SHOULD also follow the same formatting requirements.

## Attribute ID

NullHandling

## Attribute Name

Null Handling

## Description

Indicates how to handle columns that don't have a value.

## Requirements

* Columns MUST use NULL when there isn't a value that can be specified for a nullable column.
* Columns MUST NOT use empty strings or placeholder values such as 0 for numeric columns or "Not Applicable" for string columns to represent a null or not having a value, regardless of whether the column allows nulls or not.

## Exceptions

None

## Introduced (version)

0.5
