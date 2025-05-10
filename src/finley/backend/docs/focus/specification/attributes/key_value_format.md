# Key-Value Format

Columns that provide Key-Value information are often used in place of separate columns for enumerating data which would be inherently sparse and/or without predetermined keys. This consolidates related information and provides more consistency in the schema. Key-value pairs are also referred to as name-value pairs, attribute-value pairs, or field-value pairs.

All key-value related columns defined in the FOCUS specification MUST follow the key-value formatting requirements listed below.

## Attribute ID

KeyValueFormat

## Attribute Name

Key-Value Format

## Description

Rules and formatting requirements for columns appearing in a [*FOCUS dataset*](#glossary:FOCUS-dataset) that convey data as key-value pairs.

## Requirements

* Key-Value Format columns MUST contain a serialized JSON string, consistent with the [ECMA 404](https://www.ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf) definition of an object.
* Keys in a key-value pair MUST be unique within an object.
* Values in a key-value pair MUST be one of the following types: number, string, `true`, `false`, or `null`.
* Values in a key-value pair MUST NOT be an object or an array.

## Exceptions

None

## Introduced (version)

1.0-preview
