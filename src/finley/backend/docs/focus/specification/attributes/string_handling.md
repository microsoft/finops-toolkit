# String Handling

Columns that capture string values conforming to specified requirements foster data integrity, interoperability, and consistency, improve data analysis and reporting, and support reliable data-driven decision-making.

All columns capturing a string value, defined in the FOCUS specification, MUST follow the requirements listed below. Custom string value capturing columns SHOULD adopt the same requirements over time.

## Attribute ID

StringHandling

## Attribute Name

String Handling

## Description

Requirements for string-capturing columns appearing in a [*FOCUS dataset*](#glossary:FOCUS-dataset).

## Requirements

* String values MUST maintain the original casing, spacing, and other relevant consistency factors as specified by providers and end-users.
* [*Charges*](#glossary:charge) to mutable entities (e.g., resource names) MUST be accurately reflected in corresponding *charges* incurred after the change and MUST NOT alter *charges* incurred before the change, preserving data integrity and auditability for all *charge* records.
* Immutable string values that refer to the same entity (e.g., resource identifiers, region identifiers, etc.) MUST remain consistent and unchanged across all [*billing periods*](#glossary:billing-period).
* Empty strings and strings consisting solely of spaces SHOULD NOT be used in not-nullable string columns.

## Exceptions

* When a record is provided after a change to a mutable string value and the [ChargeClass](#chargeclass) is "Correction", the record MAY contain the altered value.

## Introduced (version)

1.0
