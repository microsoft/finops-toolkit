# Column Naming and Ordering

Column IDs provided in cost data following a consistent naming and ordering convention reduce friction for FinOps practitioners who consume the data for analysis, reporting, and other use cases.

All columns defined in the FOCUS specification MUST follow the naming and ordering requirements listed below.

## Attribute ID

ColumnNamingAndOrdering

## Attribute Name

Column Naming and Ordering

## Description

Naming and ordering convention for columns appearing in a [*FOCUS dataset*](#glossary:FOCUS-dataset).

## Requirements

### Column Names

* All columns defined by FOCUS MUST follow the following rules:
  * Column IDs MUST use [Pascal case](#glossary:pascalcase).
  * Column IDs MUST NOT use abbreviations.
  * Column IDs MUST be alphanumeric with no special characters.
  * Columns that have an ID and a Name MUST have the `Id` or `Name` suffix in the Column ID. Display Name for a Column MAY avoid the Name suffix if there are no other columns with the same name prefix.
  * Column IDs SHOULD NOT use acronyms.
  * Column IDs SHOULD NOT exceed 50 characters to accommodate column length restrictions of various data repositories.
* All custom columns MUST be prefixed with a consistent `x_` prefix to identify them as external, custom columns and distinguish them from FOCUS columns to avoid conflicts in future releases.
* Columns that have an ID and a Name MUST have the `Id` or `Name` suffix in the Column ID. Display Name for a Column MAY avoid the `Name` suffix if it is considered superfluous.
* Columns with the `Category` suffix MUST be normalized.
* Custom (e.g., provider-defined) columns SHOULD follow the same rules listed above for FOCUS columns.

### Column Order

* All FOCUS columns SHOULD be first in the provided dataset.
* Custom columns SHOULD be listed after all FOCUS columns and SHOULD NOT be intermixed.
* Columns MAY be sorted alphabetically, but custom columns SHOULD be after all FOCUS columns.

## Exceptions

* Identifiers will use the "Id" abbreviation since this is a standard pattern across the industry.
* Product offerings that incur charges will use the "Sku" abbreviation because it is a well-understood term both within and outside the industry.

## Introduced (version)

0.5
