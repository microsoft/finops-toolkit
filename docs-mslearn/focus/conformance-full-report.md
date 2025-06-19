---
title: FOCUS conformance report
description: Comprehensive analysis of the Microsoft Cost Management FOCUS dataset's adherence to FOCUS requirements.
author: flanakin
ms.author: micflan
ms.date: 06/18/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# FOCUS conformance full report

This document provides a detailed list of all FOCUS 1.2 requirements and indicates the level of support provided by the Microsoft Cost Management FOCUS 1.2-preview dataset. To learn more about FOCUS, refer to the [FOCUS overview](./what-is-focus.md).

<br>

## How conformance is measured

FOCUS requirements fall into four groups:

- **MUST** requirements are mandatory for all data providers.
- **SHOULD** requirements are strong recommendations.
- **RECOMMENDED** requirements are suggested best practices.
- **MAY** requirements are optional and used to prepare FinOps practitioners for edge cases.

While there's no official measurement for FOCUS conformance, we calculate a conformance score of **94%**, which accounts for all fully and partially supported requirements. The following table summarizes requirements by level of support.

| Type            | Supported | Partial support | Not supported | Not applicable |
| :-------------- | :-------: | :-------------: | :-----------: | :------------: |
| **MUST**        |    325    |       16        |       8       |       69       |
| **SHOULD**      |    28     |        5        |       1       |       11       |
| **RECOMMENDED** |     3     |                 |       4       |                |
| **MAY**         |    24     |                 |               |       12       |
| Summary         |   91.7%   |      5.1%       |     3.1%      |                |

<br>

## How this document is organized

The following sections list each FOCUS requirement, the level of support in the Microsoft Cost Management FOCUS 1.2-preview dataset, and any relevant notes. For a high-level summary of the gaps, refer to the [FOCUS conformance summary](./conformance-summary.md). Requirement IDs are for reference purposes only. IDs aren't defined as part of FOCUS.

The rest of this document lists the FOCUS requirements grouped by attribute and column. [Columns](#columns) define the specific data elements in the dataset and [attributes](#attributes) define how columns and rows should behave. High-level descriptions and a link to the original requirements document are included at the top of each section.

<br>

## Attributes

### Column handling

Naming and ordering convention for columns appearing in a FOCUS dataset.

Source: [attributes/column_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/column_handling.md)

| ID      | Type   | Criteria                                                                                                                                                                                  | Status             | Notes                                                                                                      |
| ------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------- |
| CH1     | MUST   | All columns defined in the FOCUS specification MUST follow the naming and ordering requirements listed below.                                                                             | Supports           |                                                                                                            |
| CH2     | MUST   | All columns defined by FOCUS MUST follow the following rules:                                                                                                                             | Supports           |                                                                                                            |
| CH2.1   | MUST   | Column IDs MUST use Pascal case.                                                                                                                                                          | Supports           |                                                                                                            |
| CH2.2   | MUST   | Column IDs MUST NOT use abbreviations.                                                                                                                                                    | Supports           |                                                                                                            |
| CH2.3   | MUST   | Column IDs MUST be alphanumeric with no special characters.                                                                                                                               | Supports           |                                                                                                            |
| CH2.4   | SHOULD | Column IDs SHOULD NOT use acronyms.                                                                                                                                                       | Supports           |                                                                                                            |
| CH2.5   | SHOULD | Column IDs SHOULD NOT exceed 50 characters to accommodate column length restrictions of various data repositories.                                                                        | Supports           |                                                                                                            |
| CH2.6   | MUST   | Columns that have an ID and a Name MUST have the `Id` or `Name` suffix in the Column ID.                                                                                                  | Supports           |                                                                                                            |
| CH2.7   | MAY    | Column display names MAY avoid the `Name` suffix if there are no other columns with the same name prefix.                                                                                 | Supports           | We don't recommend this practice as it introduces confusion when column IDs and display names don't match. |
| CH2.8   | MUST   | Columns with the `Category` suffix MUST be normalized.                                                                                                                                    | Supports           |                                                                                                            |
| CH3.1   | MUST   | Custom (e.g., provider-defined) columns that are not defined by FOCUS but included in a FOCUS dataset MUST follow the following rules:                                                    | Supports           |                                                                                                            |
| CH3.1.1 | MUST   | Custom columns MUST be prefixed with a consistent `x_` prefix to identify them as external, custom columns and distinguish them from FOCUS columns to avoid conflicts in future releases. | Supports           |                                                                                                            |
| CH3.1.2 | SHOULD | Custom columns SHOULD follow the same rules listed above for FOCUS columns.                                                                                                               | Partially Supports | `x_SkuMeterCategory` and `x_SkuMeterSubcategory` are not normalized.                                       |
| CH1.3   | SHOULD | All FOCUS columns SHOULD be first in the provided dataset.                                                                                                                                | Supports           |                                                                                                            |
| CH1.4.1 | SHOULD | Custom columns SHOULD be listed after all FOCUS columns...                                                                                                                                | Supports           |                                                                                                            |
| CH1.4.2 | SHOULD | ...\[Custom columns and FOCUS columns] SHOULD NOT be intermixed.                                                                                                                          | Supports           |                                                                                                            |
| CH1.5.1 | MAY    | Columns MAY be sorted alphabetically...                                                                                                                                                   | Supports           | Columns are sorted alphabetically for ease of use.                                                         |
| CH1.5.2 | SHOULD | ...custom columns SHOULD be after all FOCUS columns.                                                                                                                                      | Supports           | Columns are sorted alphabetically for ease of use.                                                         |

### Currency format

Formatting for currency columns appearing in a FOCUS dataset.

Source: [attributes/currency_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/currency_format.md)

| ID     | Type   | Criteria                                                                                                                                                                                              | Status         | Notes |
| ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ----- |
| CuF1   | MUST   | All columns capturing a currency value, defined in the FOCUS specification, MUST follow the requirements listed below.                                                                                | Supports       |       |
| CuF2   | SHOULD | Custom currency-related columns SHOULD also follow the same formatting requirements.                                                                                                                  | Supports       |       |
| CuF2.1 | MUST   | Currency-related columns MUST be represented as a three-letter alphabetic code as dictated in the governing document ISO 4217:2015 when the value is presented in national currency (e.g., USD, EUR). | Supports       |       |
| CuF2.2 | MUST   | Currency-related columns MUST conform to StringHandling requirements when the value is presented in virtual currency (e.g., credits, tokens).                                                         | Not Applicable |       |

### Date/time format

Rules and formatting requirements for date/time-related columns appearing in a FOCUS dataset.

Source: [attributes/datetime_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/datetime_format.md)

| ID   | Type   | Criteria                                                                                                                                                                                                                                                                                                                                                                                                 | Status   | Notes |
| ---- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| DTF1 | MUST   | All columns capturing a date/time value, defined in the FOCUS specification, MUST follow the formatting requirements listed below.                                                                                                                                                                                                                                                                       | Supports |       |
| DTF2 | SHOULD | Custom date/time-related columns SHOULD also follow the same formatting requirements.                                                                                                                                                                                                                                                                                                                    | Supports |       |
| DTF3 | MUST   | Date/time values MUST be in UTC (Coordinated Universal Time) to avoid ambiguity and ensure consistency across different time zones.                                                                                                                                                                                                                                                                      | Supports |       |
| DTF4 | MUST   | Date/time values format MUST be aligned with ISO 8601 standard, which provides a globally recognized format for representing dates and times (see ISO 8601-1:2019 governing document for details).                                                                                                                                                                                                       | Supports |       |
| DTF5 | MUST   | Values providing information about a specific moment in time MUST be represented in the extended ISO 8601 format with UTC offset ('YYYY-MM-DDTHH:mm:ssZ') and conform to the following guidelines: Include the date and time components, separated with the letter 'T'; Use two-digit hours (HH), minutes (mm), and seconds (ss); End with the 'Z' indicator to denote UTC (Coordinated Universal Time). | Supports |       |

### Discount handling

Indicates how to include and apply discounts to usage charges or rows in a FOCUS dataset.

Source: [attributes/discount_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/discount_handling.md)

| ID      | Type   | Criteria                                                                                                                                                                                                                                     | Status             | Notes                                                                                                                                                                                                                                                                            |
| ------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DH1     | MUST   | All rows defined in FOCUS MUST follow the discount handling requirements listed below.                                                                                                                                                       | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.1   | SHOULD | All applicable discounts SHOULD be applied to each row they pertain to...                                                                                                                                                                    | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.2   | SHOULD | All applicable discounts... SHOULD NOT be negated in a separate row.                                                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3     | MUST   | All discounts applied to a row MUST apply to the entire charge.                                                                                                                                                                              | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.1.1 | MAY    | Multiple discounts MAY apply to a row...                                                                                                                                                                                                     | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.1.2 | MUST   | Multiple discounts... \[on a row] MUST apply to the entire charge covered by that row.                                                                                                                                                       | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.2   | MUST   | If a discount only applies to a portion of a charge, then the discounted portion of the charge MUST be split into a separate row.                                                                                                            | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.3   | MUST   | Each discount MUST be identifiable using existing FOCUS columns.                                                                                                                                                                             | Supports           | `CommitmentDiscountId` is the only FOCUS column that identifies discounts.                                                                                                                                                                                                       |
| DH3.3.1 | MUST   | Rows with a commitment discount applied to them MUST include a CommitmentDiscountId.                                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.3.2 | SHOULD | If a provider applies a discount that cannot be represented by a FOCUS column, they SHOULD include additional columns to identify the source of the discount.                                                                                | Partially Supports | Negotiated discounts can be identified by comparing `ListCost` and `ContractedCost`.                                                                                                                                                                                             |
| DH4     | MUST   | Purchased discounts (e.g., commitment discounts) MUST be amortized.                                                                                                                                                                          | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.1   | MUST   | The BilledCost MUST be 0 for any row where the commitment covers the entire cost for the charge period.                                                                                                                                      | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.2   | MUST   | The EffectiveCost MUST include the portion of the amortized purchase cost that applies to this row.                                                                                                                                          | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.3   | MUST   | The sum of the EffectiveCost for all rows where CommitmentDiscountStatus is "Used" or "Unused" for each CommitmentDiscountId over the entire duration of the commitment MUST be the same as the total BilledCost of the commitment discount. | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.4.1 | MUST   | The CommitmentDiscountId and ResourceId MUST be set to the ID assigned to the commitment discount.                                                                                                                                           | Supports           | To facilitate splitting commitment discounts, commitment discount purchases and refunds use the commitment discount order while commitment discount usage uses the instance within the order. Use `x_SkuOrderId` to identify the commitment discount order ID for usage charges. |
| DH4.4.2 | MUST   | ChargeCategory MUST be set to "Purchase" on rows that represent a purchase of a commitment discount.                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.5.1 | MUST   | CommitmentDiscountStatus MUST be "Used" for ChargeCategory "Usage" rows that received a reduced price from a commitment.                                                                                                                     | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.5.2 | MUST   | CommitmentDiscountId MUST be set to the ID assigned to the discount.                                                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.5.3 | MUST   | ResourceId MUST be set to the ID of the resource that received the discount.                                                                                                                                                                 | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.6.1 | MUST   | If a commitment is not fully utilized, the provider MUST include a row that represents the unused portion of the commitment for that charge period.                                                                                          | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.6.2 | MUST   | These rows MUST be represented with CommitmentDiscountStatus set to "Unused" and ChargeCategory set to "Usage".                                                                                                                              | Supports           |                                                                                                                                                                                                                                                                                  |
| DH4.6.3 | MUST   | Such rows MUST have their CommitmentDiscountId and ResourceId set to the ID assigned to the commitment discount.                                                                                                                             | Supports           |                                                                                                                                                                                                                                                                                  |
| DH5     | MUST   | Credits that are applied after the fact MUST use a ChargeCategory of "Credit".                                                                                                                                                               | Not Applicable     | Credits aren't included in any Cost Management cost and usage dataset.                                                                                                                                                                                                           |

### Key value format

Rules and formatting requirements for columns appearing in a FOCUS dataset that convey data as key-value pairs.

Source: [attributes/key_value_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/key_value_format.md)

| ID     | Type | Criteria                                                                                                                         | Status   | Notes |
| ------ | ---- | -------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| KVF1   | MUST | All key-value related columns defined in the FOCUS specification MUST follow the key-value formatting requirements listed below. | Supports |       |
| KVF1.1 | MUST | Key-Value Format columns MUST contain a serialized JSON string, consistent with the ECMA 404 definition of an object.            | Supports |       |
| KVF1.2 | MUST | Keys in a key-value pair MUST be unique within an object.                                                                        | Supports |       |
| KVF1.3 | MUST | Values in a key-value pair MUST be one of the following types: number, string, `true`, `false`, or `null`.                       | Supports |       |
| KVF1.4 | MUST | Values in a key-value pair MUST NOT be an object or an array.                                                                    | Supports |       |

### Null handling

Indicates how to handle columns that don't have a value.

Source: [attributes/null_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/null_handling.md)

| ID  | Type   | Criteria                                                                                                                                                                                                                       | Status             | Notes                                                                           |
| --- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ------------------------------------------------------------------------------- |
| NH1 | MUST   | All columns defined in the FOCUS specification MUST follow the null handling requirements listed below.                                                                                                                        | Partially Supports | Price and cost columns may use 0 when data is not available in Cost Management. |
| NH2 | SHOULD | Custom columns SHOULD also follow the same formatting requirements.                                                                                                                                                            | Partially Supports | Price and cost columns may use 0 when data is not available in Cost Management. |
| NH3 | MUST   | Columns MUST use NULL when there isn't a value that can be specified for a nullable column.                                                                                                                                    | Partially Supports | Price and cost columns may use 0 when data is not available in Cost Management. |
| NH4 | MUST   | Columns MUST NOT use empty strings or placeholder values such as 0 for numeric columns or "Not Applicable" for string columns to represent a null or not having a value, regardless of whether the column allows nulls or not. | Partially Supports | Price and cost columns may use 0 when data is not available in Cost Management. |

### Numeric format

Rules and formatting requirements for numeric columns appearing in a FOCUS dataset.

Source: [attributes/numeric_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/numeric_format.md)

| ID    | Type   | Criteria                                                                                                                                                                 | Status   | Notes |
| ----- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| NF1   | MUST   | All columns capturing a numeric value, defined in the FOCUS specification, MUST follow the formatting requirements listed below.                                         | Supports |       |
| NF2   | SHOULD | Custom numeric value capturing columns SHOULD adopt the same format requirements over time.                                                                              | Supports |       |
| NF2.1 | MUST   | Columns with a Numeric value format MUST contain a single numeric value.                                                                                                 | Supports |       |
| NF2.2 | MUST   | Numeric values MUST be expressed as an integer value, a decimal value, or a value expressed in scientific notation.                                                      | Supports |       |
| NF3   | MUST   | Fractional notation MUST NOT be used.                                                                                                                                    | Supports |       |
| NF3.1 | MUST   | Numeric values expressed using scientific notation MUST be expressed using E notation "mEn" with a real number m and an integer n indicating a value of "m x 10^n".      | Supports |       |
| NF3.2 | MUST   | The sign of the exponent MUST only be expressed as part of the exponent value if n is negative.                                                                          | Supports |       |
| NF3.3 | MUST   | Numeric values MUST NOT be expressed with mathematical symbols, functions, or operators.                                                                                 | Supports |       |
| NF3.4 | MUST   | Numeric values MUST NOT contain qualifiers or additional characters (e.g., currency symbols, units of measure, etc.).                                                    | Supports |       |
| NF3.5 | MUST   | Numeric values MUST NOT contain commas or punctuation marks except for a single decimal point (".") if required to express a decimal value.                              | Supports |       |
| NF3.6 | MUST   | Numeric values MUST NOT include a character to represent a sign for a positive value.                                                                                    | Supports |       |
| NF4   | MUST   | A negative sign (-) MUST indicate a negative value.                                                                                                                      | Supports |       |
| NF4.1 | MUST   | Columns with a Numeric value format MUST present one of the following values as the "Data type" in the column definition.                                                | Supports |       |
| NF4.2 | SHOULD | Providers SHOULD define precision and scale for Numeric Format columns using one of the following precision values in a data definition document that providers publish. | Supports |       |

### String handling

Requirements for string-capturing columns appearing in a FOCUS dataset.

Source: [attributes/string_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/string_handling.md)

| ID    | Type   | Criteria                                                                                                                                                                      | Status             | Notes                                                                                                                                                                                                                            |
| ----- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SH1   | MUST   | All columns capturing a string value, defined in the FOCUS specification, MUST follow the requirements listed below.                                                          | Supports           |                                                                                                                                                                                                                                  |
| SH2   | SHOULD | Custom string value capturing columns SHOULD adopt the same requirements over time.                                                                                           | Supports           |                                                                                                                                                                                                                                  |
| SH3   | MUST   | String values MUST maintain the original casing, spacing, and other relevant consistency factors as specified by providers and end-users.                                     | Partially Supports | `ResourceName` may be changed to lower or upper case by the resource provider. If you see this, file a support request on the service team responsible for the SKU/meter. `ResourceId` is lowercased to meet FOCUS requirements. |
| SH4.1 | MUST   | Charges to mutable entities (e.g., resource names) MUST be accurately reflected in corresponding charges incurred after the change...                                         | Supports           |                                                                                                                                                                                                                                  |
| SH4.2 | MUST   | Charges to mutable entities (e.g., resource names)... MUST NOT alter charges incurred before the change, preserving data integrity and auditability for all charge records.   | Supports           |                                                                                                                                                                                                                                  |
| SH5   | MUST   | Immutable string values that refer to the same entity (e.g., resource identifiers, region identifiers, etc.) MUST remain consistent and unchanged across all billing periods. | Supports           |                                                                                                                                                                                                                                  |
| SH6   | SHOULD | Empty strings and strings consisting solely of spaces SHOULD NOT be used in not-nullable string columns.                                                                      | Supports           |                                                                                                                                                                                                                                  |
| SH7   | MAY    | When a record is provided after a change to a mutable string value and the ChargeClass is "Correction", the record MAY contain the altered value.                             | Supports           |                                                                                                                                                                                                                                  |

### Unit format

Indicates standards for expressing measurement units in columns appearing in a FOCUS dataset.

Source: [attributes/unit_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/attributes/unit_format.md)

| ID      | Type   | Criteria                                                                                                                                                                                                                                                                                   | Status   | Notes                                                                                                                                 |
| ------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| UF1     | MUST   | All columns defined in FOCUS specifying Unit Format as a value format MUST follow the requirements listed below.                                                                                                                                                                           | Supports |                                                                                                                                       |
| UF1.1   | SHOULD | Units SHOULD be expressed as a single unit of measure adhering to one of the following three formats.                                                                                                                                                                                      | Supports | While valid based on rule UF2, the following units are exceptions to this rule: `Units/10 Days`, `Units/3 Months`, `Units/6 Months`.  |
| UF1.2   | MAY    | Units MAY be expressed with a unit quantity or time interval.                                                                                                                                                                                                                              | Supports | See UF1.1.                                                                                                                            |
| UF1.1   | MUST   | If a unit quantity or time interval is used, the unit quantity or time interval MUST be expressed as a whole number.                                                                                                                                                                       | Supports |                                                                                                                                       |
| UF1.1.1 | MUST   | Unit values and components of columns using the Unit Format MUST use a capitalization scheme that is consistent with the capitalization scheme used in this attribute if that term is listed in this section.                                                                              | Supports |                                                                                                                                       |
| UF1.1.2 | SHOULD | Units SHOULD be composed of the list of recommended units listed in this section unless the unit value covers a dimension not listed in the recommended unit set, or if the unit covers a count-based unit distinct from recommended values in the count dimension listed in this section. | Supports |                                                                                                                                       |
| UF2     | MUST   | Data size unit names MUST be abbreviated using one of the abbreviations in the following table.                                                                                                                                                                                            | Supports |                                                                                                                                       |
| UF2.1   | MUST   | Values that exceed 10^18 MUST use the abbreviation for exabit, exabyte, exbibit, and exbibyte...                                                                                                                                                                                           | Supports |                                                                                                                                       |
| UF2.2   | MUST   | ...values smaller than a byte MUST use the abbreviation for bit or byte.                                                                                                                                                                                                                   | Supports |                                                                                                                                       |
| UF3     | MAY    | If the following list of recommended values does not cover a count-based unit, a provider MAY introduce a new noun representing a count-based unit.                                                                                                                                        | Supports | All supported unit values are documented in the [Pricing units](../toolkit/open-data.md#pricing-units) dataset in the FinOps toolkit. |
| UF3.1   | MUST   | All nouns appearing in units that are not listed in the recommended values table will be considered count-based units.  A new count-based unit value MUST be capitalized.                                                                                                                  | Supports |                                                                                                                                       |
| UF3.2   | MUST   | Time-based units can be used to measure consumption over a time interval or in combination with another unit to capture a rate of consumption.  Time-based units MUST match one of the values listed in the following table.                                                               | Supports |                                                                                                                                       |
| UF4     | MUST   | If the unit value is a composite value made from combinations of one or more units, each component MUST also align with the set of recommended values.                                                                                                                                     | Supports |                                                                                                                                       |
| UF5.1   | MUST   | Instead of "per" or "-" to denote a Composite Unit, slash ("/") and space(" ") MUST be used as a common convention.                                                                                                                                                                        | Supports |                                                                                                                                       |
| UF5.2   | SHOULD | Count-based units like requests, instances, and tokens SHOULD be expressed using a value listed in the count dimension.                                                                                                                                                                    | Supports |                                                                                                                                       |
| UF5.3   | SHOULD | For example, if a usage unit is measured as a rate of requests or instances over a period of time, the unit SHOULD be listed as "Requests/Day" to signify the number of requests per day.                                                                                                  | Supports |                                                                                                                                       |

<br>

## Columns

### Availability zone

A provider-assigned identifier for a physically separated and isolated area within a Region that provides high availability and fault tolerance.

Source: [columns/availabilityzone.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/availabilityzone.md)

| ID  | Type        | Criteria                                                                                                                                                 | Status           | Notes                                                                              |
| --- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------- |
| AZ1 | RECOMMENDED | AvailabilityZone is RECOMMENDED to be present in a FOCUS dataset when the provider supports deploying resources or services within an availability zone. | Does Not Support | Availability zones aren't available in any Cost Management cost and usage dataset. |
| AZ2 | MUST        | AvailabilityZone MUST be of type String.                                                                                                                 | Not Applicable   |                                                                                    |
| AZ3 | MUST        | AvailabilityZone MUST conform to StringHandling requirements.                                                                                            | Not Applicable   |                                                                                    |
| AZ4 | MUST        | AvailabilityZone MUST be null when a charge is not specific to an availability zone.                                                                     | Not Applicable   |                                                                                    |

### Billed cost

A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring).

Source: [columns/billedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billedcost.md)

| ID   | Type | Criteria                                                                                                                                                                        | Status   | Notes |
| ---- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| BCo1 | MUST | BilledCost MUST be present in a FOCUS dataset.                                                                                                                                  | Supports |       |
| BCo2 | MUST | BilledCost MUST be of type Decimal.                                                                                                                                             | Supports |       |
| BCo3 | MUST | BilledCost MUST conform to NumericFormat requirements.                                                                                                                          | Supports |       |
| BCo4 | MUST | BilledCost MUST NOT be null.                                                                                                                                                    | Supports |       |
| BCo5 | MUST | BilledCost MUST be a valid decimal value.                                                                                                                                       | Supports |       |
| BCo6 | MUST | BilledCost MUST be 0 for charges where payments are received by a third party (e.g., marketplace transactions).                                                                 | Supports |       |
| BCo7 | MUST | BilledCost MUST be denominated in the BillingCurrency.                                                                                                                          | Supports |       |
| BCo8 | MUST | The sum of the BilledCost for a given InvoiceId MUST match the sum of the payable amount provided in the corresponding invoice with the same id generated by the InvoiceIssuer. | Supports |       |

### Billing account ID

The identifier assigned to a billing account by the provider.

FOCUS billing account represents the scope at which invoices are generated, which is an Enterprise Agreement billing account (also known as enrollment) or a Microsoft Customer Agreement billing profile.                                                |

Source: [columns/billingaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingaccountid.md)

| ID   | Type   | Criteria                                                        | Status   | Notes                                                                                                                                                                                                                                                     |
| ---- | ------ | --------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BAI1 | MUST   | BillingAccountId MUST be present in a FOCUS dataset.            | Supports |                                                                                                                                                                                                                                                           |
| BAI2 | MUST   | BillingAccountId MUST be of type String.                        | Supports |                                                                                                                                                                                                                                                           |
| BAI3 | MUST   | BillingAccountId MUST conform to StringHandling requirements.   | Supports |                                                                                                                                                                                                                                                           |
| BAI4 | MUST   | BillingAccountId MUST NOT be null.                              | Supports |                                                                                                                                                                                                                                                           |
| BAI5 | MUST   | BillingAccountId MUST be a unique identifier within a provider. | Supports |                                                                                                                                                                                                                                                           |
| BAI6 | SHOULD | BillingAccountId SHOULD be a fully-qualified identifier.        | Supports | `BillingAccountId` uses the fully-qualified Azure Resource Manager ID and not the simple enrollment number or billing profile ID for consistency and to ensure the scope being identified is obvious and programmatically accessible via this identifier. |

### Billing account name

The display name assigned to a billing account.

FOCUS billing account represents the scope at which invoices are generated, which is an Enterprise Agreement billing account (also known as enrollment) or a Microsoft Customer Agreement billing profile.

Source: [columns/billingaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingaccountname.md)

| ID   | Type | Criteria                                                                                                         | Status   | Notes |
| ---- | ---- | ---------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| BAN1 | MUST | BillingAccountName MUST be present in a FOCUS dataset.                                                           | Supports |       |
| BAN2 | MUST | BillingAccountName MUST be of type String.                                                                       | Supports |       |
| BAN3 | MUST | BillingAccountName MUST conform to StringHandling requirements.                                                  | Supports |       |
| BAN4 | MUST | BillingAccountName MUST NOT be null when the provider supports assigning a display name for the billing account. | Supports |       |

### Billing account type

A provider-assigned name to identify the type of billing account.

FOCUS billing account represents the scope at which invoices are generated, which is an Enterprise Agreement billing account (also known as enrollment) or a Microsoft Customer Agreement billing profile.

Source: [columns/billingaccounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingaccounttype.md)

| ID     | Type | Criteria                                                                                                                          | Status   | Notes |
| ------ | ---- | --------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| BAT1   | MUST | BillingAccountType MUST be present in a FOCUS dataset when the provider supports more than one possible BillingAccountType value. | Supports |       |
| BAT2   | MUST | BillingAccountType MUST be of type String.                                                                                        | Supports |       |
| BAT3   | MUST | BillingAccountType MUST conform to StringHandling requirements.                                                                   | Supports |       |
| BAT3.1 | MUST | BillingAccountType MUST be null when BillingAccountId is null.                                                                    | Supports |       |
| BAT3.2 | MUST | BillingAccountType MUST NOT be null when BillingAccountId is not null.                                                            | Supports |       |
| BAT4   | MUST | BillingAccountType MUST be a consistent, readable display value.                                                                  | Supports |       |

### Billing currency

Represents the currency that a charge was billed in.

Source: [columns/billingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingcurrency.md)

| ID   | Type | Criteria                                                                                     | Status   | Notes |
| ---- | ---- | -------------------------------------------------------------------------------------------- | -------- | ----- |
| BCu1 | MUST | BillingCurrency MUST be present in a FOCUS dataset.                                          | Supports |       |
| BCu2 | MUST | BillingCurrency MUST be of type String.                                                      | Supports |       |
| BCu3 | MUST | BillingCurrency MUST conform to StringHandling requirements.                                 | Supports |       |
| BCu4 | MUST | BillingCurrency MUST conform to CurrencyFormat requirements.                                 | Supports |       |
| BCu5 | MUST | BillingCurrency MUST NOT be null.                                                            | Supports |       |
| BCu6 | MUST | BillingCurrency MUST match the currency used in the invoice generated by the invoice issuer. | Supports |       |
| BCu7 | MUST | BillingCurrency MUST be expressed in national currency (e.g., USD, EUR).                     | Supports |       |

### Billing period end

The exclusive end bound of a billing period.

Source: [columns/billingperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingperiodend.md)

| ID   | Type | Criteria                                                                | Status   | Notes |
| ---- | ---- | ----------------------------------------------------------------------- | -------- | ----- |
| BPE1 | MUST | BillingPeriodEnd MUST be present in a FOCUS dataset.                    | Supports |       |
| BPE2 | MUST | BillingPeriodEnd MUST be of type Date/Time.                             | Supports |       |
| BPE3 | MUST | BillingPeriodEnd MUST conform to DateTimeFormat requirements.           | Supports |       |
| BPE4 | MUST | BillingPeriodEnd MUST NOT be null.                                      | Supports |       |
| BPE5 | MUST | BillingPeriodEnd MUST be the exclusive end bound of the billing period. | Supports |       |

### Billing period start

The inclusive start bound of a billing period.

Source: [columns/billingperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/billingperiodstart.md)

| ID   | Type | Criteria                                                                    | Status   | Notes |
| ---- | ---- | --------------------------------------------------------------------------- | -------- | ----- |
| BPS1 | MUST | BillingPeriodStart MUST be present in a FOCUS dataset.                      | Supports |       |
| BPS2 | MUST | BillingPeriodStart MUST be of type Date/Time.                               | Supports |       |
| BPS3 | MUST | BillingPeriodStart MUST conform to DateTimeFormat requirements.             | Supports |       |
| BPS4 | MUST | BillingPeriodStart MUST NOT be null.                                        | Supports |       |
| BPS5 | MUST | BillingPeriodStart MUST be the inclusive start bound of the billing period. | Supports |       |

### Capacity reservation ID

The identifier assigned to a capacity reservation by the provider.

Source: [columns/capacityreservationid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/capacityreservationid.md)

| ID     | Type   | Criteria                                                                                                      | Status           | Notes                                                                                      |
| ------ | ------ | ------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------ |
| CRI1   | MUST   | CapacityReservationId MUST be present in a FOCUS dataset when the provider supports capacity reservations.    | Does Not Support | `CapacityReservationId` is not specified in the Cost Management FOCUS 1.2-preview dataset. |
| CRI2   | MUST   | CapacityReservationId MUST be of type String.                                                                 | Not Applicable   |                                                                                            |
| CRI3   | MUST   | CapacityReservationId MUST conform to StringHandling requirements.                                            | Not Applicable   |                                                                                            |
| CRI3.1 | MUST   | CapacityReservationId MUST be null when a charge is not related to a capacity reservation.                    | Not Applicable   |                                                                                            |
| CRI3.2 | MUST   | CapacityReservationId MUST NOT be null when a charge represents the unused portion of a capacity reservation. | Not Applicable   |                                                                                            |
| CRI3.3 | SHOULD | CapacityReservationId SHOULD NOT be null when a charge is related to a capacity reservation.                  | Not Applicable   |                                                                                            |
| CRI3.4 | MUST   | CapacityReservationId MUST be a unique identifier within the provider.                                        | Not Applicable   |                                                                                            |
| CRI3.5 | SHOULD | CapacityReservationId SHOULD be a fully-qualified identifier.                                                 | Not Applicable   |                                                                                            |

### Capacity reservation status

Indicates whether the charge represents either the consumption of a capacity reservation or when a capacity reservation is unused.

Source: [columns/capacityreservationstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/capacityreservationstatus.md)

| ID     | Type | Criteria                                                                                                            | Status           | Notes                                                                                          |
| ------ | ---- | ------------------------------------------------------------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------- |
| CRS1   | MUST | CapacityReservationStatus MUST be present in a FOCUS dataset when the provider supports capacity reservations.      | Does Not Support | `CapacityReservationStatus` is not specified in the Cost Management FOCUS 1.2-preview dataset. |
| CRS2   | MUST | CapacityReservationStatus MUST be of type String.                                                                   | Not Applicable   |                                                                                                |
| CRS2.1 | MUST | CapacityReservationStatus MUST be null when CapacityReservationId is null.                                          | Not Applicable   |                                                                                                |
| CRS2.2 | MUST | CapacityReservationStatus MUST NOT be null when CapacityReservationId is not null and ChargeCategory is "Usage".    | Not Applicable   |                                                                                                |
| CRS2.3 | MUST | CapacityReservationStatus MUST be one of the allowed values.                                                        | Not Applicable   |                                                                                                |
| CRS2.4 | MUST | CapacityReservationStatus MUST be "Unused" when the charge represents the unused portion of a capacity reservation. | Not Applicable   |                                                                                                |
| CRS2.5 | MUST | CapacityReservationStatus MUST be "Used" when the charge represents the used portion of a capacity reservation.     | Not Applicable   |                                                                                                |

### Charge category

Represents the highest-level classification of a charge based on the nature of how it is billed.

Source: [columns/chargecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargecategory.md)

| ID   | Type | Criteria                                           | Status   | Notes |
| ---- | ---- | -------------------------------------------------- | -------- | ----- |
| CCa1 | MUST | ChargeCategory MUST be present in a FOCUS dataset. | Supports |       |
| CCa2 | MUST | ChargeCategory MUST be of type String.             | Supports |       |
| CCa3 | MUST | ChargeCategory MUST NOT be null.                   | Supports |       |
| CCa4 | MUST | ChargeCategory MUST be one of the allowed values.  | Supports |       |

### Charge class

Indicates whether the row represents a correction to a previously invoiced billing period.

Source: [columns/chargeclass.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargeclass.md)

| ID     | Type | Criteria                                                                                                                                    | Status   | Notes |
| ------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CCl1   | MUST | ChargeClass MUST be present in a FOCUS dataset.                                                                                             | Supports |       |
| CCl2   | MUST | ChargeClass MUST be of type String.                                                                                                         | Supports |       |
| CCl2.1 | MUST | ChargeClass MUST be null when the row does not represent a correction or when it represents a correction within the current billing period. | Supports |       |
| CCl2.2 | MUST | ChargeClass MUST NOT be null when the row represents a correction to a previously invoiced billing period.                                  | Supports |       |
| CCl3   | MUST | ChargeClass MUST be "Correction" when ChargeClass is not null.                                                                              | Supports |       |

### Charge description

Self-contained summary of the charge's purpose and price.

Source: [columns/chargedescription.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargedescription.md)

| ID  | Type   | Criteria                                                                                        | Status             | Notes                                                                                                                                                       |
| --- | ------ | ----------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CD1 | MUST   | ChargeDescription MUST be present in a FOCUS dataset.                                           | Supports           |                                                                                                                                                             |
| CD2 | MUST   | ChargeDescription MUST be of type String.                                                       | Supports           |                                                                                                                                                             |
| CD3 | MUST   | ChargeDescription MUST conform to StringHandling requirements.                                  | Supports           |                                                                                                                                                             |
| CD4 | SHOULD | ChargeDescription SHOULD NOT be null.                                                           | Partially Supports | `ChargeDescription` may be null for savings plan unused charges, Marketplace charges, and other charges that aren't directly associated with a product SKU. |
| CD5 | SHOULD | ChargeDescription maximum length SHOULD be provided in the corresponding FOCUS Metadata Schema. | Does Not Support   |                                                                                                                                                             |

### Charge frequency

Indicates how often a charge will occur.

Source: [columns/chargefrequency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargefrequency.md)

| ID   | Type        | Criteria                                                                     | Status   | Notes |
| ---- | ----------- | ---------------------------------------------------------------------------- | -------- | ----- |
| CFr1 | RECOMMENDED | ChargeFrequency is RECOMMENDED to be present in a FOCUS dataset.             | Supports |       |
| CFr2 | MUST        | ChargeFrequency MUST be of type String.                                      | Supports |       |
| CFr3 | MUST        | ChargeFrequency MUST NOT be null.                                            | Supports |       |
| CFr4 | MUST        | ChargeFrequency MUST be one of the allowed values.                           | Supports |       |
| CFr5 | MUST        | ChargeFrequency MUST NOT be "Usage-Based" when ChargeCategory is "Purchase". | Supports |       |

### Charge period end

The exclusive end bound of a charge period.

Source: [columns/chargeperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargeperiodend.md)

| ID   | Type | Criteria                                                                               | Status   | Notes |
| ---- | ---- | -------------------------------------------------------------------------------------- | -------- | ----- |
| CPE1 | MUST | ChargePeriodEnd MUST be present in a FOCUS dataset.                                    | Supports |       |
| CPE2 | MUST | ChargePeriodEnd MUST be of type Date/Time.                                             | Supports |       |
| CPE3 | MUST | ChargePeriodEnd MUST conform to DateTimeFormat requirements.                           | Supports |       |
| CPE4 | MUST | ChargePeriodEnd MUST NOT be null.                                                      | Supports |       |
| CPE5 | MUST | ChargePeriodEnd MUST be the exclusive end bound of the effective period of the charge. | Supports |       |

### Charge period start

The inclusive start bound of a charge period.

Source: [columns/chargeperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/chargeperiodstart.md)

| ID   | Type | Criteria                                                                                   | Status   | Notes |
| ---- | ---- | ------------------------------------------------------------------------------------------ | -------- | ----- |
| CPS1 | MUST | ChargePeriodStart MUST be present in a FOCUS dataset.                                      | Supports |       |
| CPS2 | MUST | ChargePeriodStart MUST be of type Date/Time.                                               | Supports |       |
| CPS3 | MUST | ChargePeriodStart MUST conform to DateTimeFormat requirements.                             | Supports |       |
| CPS4 | MUST | ChargePeriodStart MUST NOT be null.                                                        | Supports |       |
| CPS5 | MUST | ChargePeriodStart MUST be the inclusive start bound of the effective period of the charge. | Supports |       |

### Commitment discount category

Indicates whether the commitment discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka "spend").

Source: [columns/commitmentdiscountcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountcategory.md)

| ID     | Type | Criteria                                                                                                       | Status   | Notes |
| ------ | ---- | -------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDC1   | MUST | CommitmentDiscountCategory MUST be present in a FOCUS dataset when the provider supports commitment discounts. | Supports |       |
| CDC2   | MUST | CommitmentDiscountCategory MUST be of type String.                                                             | Supports |       |
| CDC2.1 | MUST | CommitmentDiscountCategory MUST be null when CommitmentDiscountId is null.                                     | Supports |       |
| CDC2.2 | MUST | CommitmentDiscountCategory MUST NOT be null when CommitmentDiscountId is not null.                             | Supports |       |
| CDC3   | MUST | CommitmentDiscountCategory MUST be one of the allowed values.                                                  | Supports |       |

### Commitment discount ID

The identifier assigned to a commitment discount by the provider.

Source: [columns/commitmentdiscountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountid.md)

| ID     | Type   | Criteria                                                                                                 | Status   | Notes |
| ------ | ------ | -------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDI1   | MUST   | CommitmentDiscountId MUST be present in a FOCUS dataset when the provider supports commitment discounts. | Supports |       |
| CDI2   | MUST   | CommitmentDiscountId MUST be of type String.                                                             | Supports |       |
| CDI3   | MUST   | CommitmentDiscountId MUST conform to StringHandling requirements.                                        | Supports |       |
| CDI3.1 | MUST   | CommitmentDiscountId MUST be null when a charge is not related to a commitment discount.                 | Supports |       |
| CDI3.2 | MUST   | CommitmentDiscountId MUST NOT be null when a charge is related to a commitment discount.                 | Supports |       |
| CDI3.3 | MUST   | CommitmentDiscountId MUST be a unique identifier within the provider.                                    | Supports |       |
| CDI3.4 | SHOULD | CommitmentDiscountId SHOULD be a fully-qualified identifier.                                             | Supports |       |

### Commitment discount name

The display name assigned to a commitment discount.

Source: [columns/commitmentdiscountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountname.md)

| ID       | Type | Criteria                                                                                                   | Status   | Notes |
| -------- | ---- | ---------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDN1     | MUST | CommitmentDiscountName MUST be present in a FOCUS dataset when the provider supports commitment discounts. | Supports |       |
| CDN2     | MUST | CommitmentDiscountName MUST be of type String.                                                             | Supports |       |
| CDN3     | MUST | CommitmentDiscountName MUST conform to StringHandling requirements.                                        | Supports |       |
| CDN3.1   | MUST | CommitmentDiscountName MUST be null when CommitmentDiscountId is null.                                     | Supports |       |
| CDN3.1.1 | MUST | CommitmentDiscountName MUST NOT be null when a display name can be assigned to a commitment discount.      | Supports |       |
| CDN3.1.2 | MAY  | CommitmentDiscountName MAY be null when a display name cannot be assigned to a commitment discount.        | Supports |       |

### Commitment discount quantity

The amount of a commitment discount purchased or accounted for in commitment discount related rows that is denominated in Commitment Discount Units.

Source: [columns/commitmentdiscountquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountquantity.md)

| ID       | Type | Criteria                                                                                                                                                                                                             | Status           | Notes                                                                                           |
| -------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| CDQ1     | MUST | CommitmentDiscountQuantity MUST be present in a FOCUS dataset when the provider supports commitment discounts.                                                                                                       | Does Not Support | `CommitmentDiscountQuantity` is not specified in the Cost Management FOCUS 1.2-preview dataset. |
| CDQ2     | MUST | CommitmentDiscountQuantity MUST be of type Decimal.                                                                                                                                                                  | Not Applicable   |                                                                                                 |
| CDQ3     | MUST | CommitmentDiscountQuantity MUST conform to NumericFormat requirements.                                                                                                                                               | Not Applicable   |                                                                                                 |
| CDQ3.1   | MUST | CommitmentDiscountQuantity MUST NOT be null when ChargeClass is not "Correction".                                                                                                                                    | Not Applicable   |                                                                                                 |
| CDQ3.2   | MAY  | CommitmentDiscountQuantity MAY be null when ChargeClass is "Correction".                                                                                                                                             | Not Applicable   |                                                                                                 |
| CDQ3.1   | MUST | CommitmentDiscountQuantity MUST be null in all other cases.                                                                                                                                                          | Not Applicable   |                                                                                                 |
| CDQ3.2   | MUST | CommitmentDiscountQuantity MUST be a valid decimal value.                                                                                                                                                            | Not Applicable   |                                                                                                 |
| CDQ3.2.1 | MUST | CommitmentDiscountQuantity MUST be the quantity of CommitmentDiscountUnit, paid fully or partially upfront, that is eligible for consumption over the commitment discount's term when ChargeFrequency is "One-Time". | Not Applicable   |                                                                                                 |
| CDQ3.2.2 | MUST | CommitmentDiscountQuantity MUST be the quantity of CommitmentDiscountUnit that is eligible for consumption for each charge period that corresponds with the purchase when ChargeFrequency is "Recurring".            | Not Applicable   |                                                                                                 |
| CDQ3.2.3 | MUST | CommitmentDiscountQuantity MUST be the metered quantity of CommitmentDiscountUnit that is consumed in a given charge period when CommitmentDiscountStatus is "Used".                                                 | Not Applicable   |                                                                                                 |
| CDQ3.2.4 | MUST | CommitmentDiscountQuantity MUST be the remaining, unused quantity of CommitmentDiscountUnit in a given charge period when CommitmentDiscountStatus is "Unused".                                                      | Not Applicable   |                                                                                                 |

### Commitment discount status

Indicates whether the charge corresponds with the consumption of a commitment discount or the unused portion of the committed amount.

Source: [columns/commitmentdiscountstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountstatus.md)

| ID   | Type | Criteria                                                                                                        | Status   | Notes |
| ---- | ---- | --------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| C1   | MUST | CommitmentDiscountStatus MUST be present in a FOCUS dataset when the provider supports commitment discounts.    | Supports |       |
| C2   | MUST | CommitmentDiscountStatus MUST be of type String.                                                                | Supports |       |
| C2.1 | MUST | CommitmentDiscountStatus MUST be null when CommitmentDiscountId is null.                                        | Supports |       |
| C2.2 | MUST | CommitmentDiscountStatus MUST NOT be null when CommitmentDiscountId is not null and Charge Category is "Usage". | Supports |       |
| C3   | MUST | CommitmentDiscountStatus MUST be one of the allowed values.                                                     | Supports |       |

### Commitment discount type

A provider-assigned identifier for the type of commitment discount applied to the row.

Source: [columns/commitmentdiscounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscounttype.md)

| ID     | Type | Criteria                                                                                                   | Status   | Notes |
| ------ | ---- | ---------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDT1   | MUST | CommitmentDiscountType MUST be present in a FOCUS dataset when the provider supports commitment discounts. | Supports |       |
| CDT2   | MUST | CommitmentDiscountType MUST be of type String.                                                             | Supports |       |
| CDT3   | MUST | CommitmentDiscountType MUST conform to StringHandling requirements.                                        | Supports |       |
| CDT3.1 | MUST | CommitmentDiscountType MUST be null when CommitmentDiscountId is null.                                     | Supports |       |
| CDT3.2 | MUST | CommitmentDiscountType MUST NOT be null when CommitmentDiscountId is not null.                             | Supports |       |

### Commitment discount unit

The provider-specified measurement unit indicating how a provider measures the Commitment Discount Quantity of a commitment discount.

Source: [columns/commitmentdiscountunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/commitmentdiscountunit.md)

| ID     | Type   | Criteria                                                                                                                 | Status           | Notes                                                                                        |
| ------ | ------ | ------------------------------------------------------------------------------------------------------------------------ | ---------------- | -------------------------------------------------------------------------------------------- |
| CDU1   | MUST   | CommitmentDiscountUnit MUST be present in a FOCUS dataset when the provider supports commitment discounts.               | Does Not Support | `CommitmentDiscountUnit`  is not specified in the Cost Management FOCUS 1.2-preview dataset. |
| CDU2   | MUST   | CommitmentDiscountUnit MUST be of type String.                                                                           | Not Applicable   |                                                                                              |
| CDU3   | MUST   | CommitmentDiscountUnit MUST conform to StringHandling requirements.                                                      | Not Applicable   |                                                                                              |
| CDU4   | SHOULD | CommitmentDiscountUnit SHOULD conform to UnitFormat requirements.                                                        | Not Applicable   |                                                                                              |
| CDU4.1 | MUST   | CommitmentDiscountUnit MUST be null when CommitmentDiscountQuantity is null.                                             | Not Applicable   |                                                                                              |
| CDU4.2 | MUST   | CommitmentDiscountUnit MUST NOT be null when CommitmentDiscountQuantity is not null.                                     | Not Applicable   |                                                                                              |
| CDU4.3 | MUST   | CommitmentDiscountUnit MUST remain consistent over time for a given CommitmentDiscountId.                                | Not Applicable   |                                                                                              |
| CDU4.4 | MUST   | CommitmentDiscountUnit MUST represent the unit used to measure the commitment discount.                                  | Not Applicable   |                                                                                              |
| CDU4.5 | SHOULD | When accounting for commitment discount flexibility, the CommitmentDiscountUnit value SHOULD reflect this consideration. | Not Applicable   |                                                                                              |

### Consumed quantity

The volume of a metered SKU associated with a resource or service used, based on the Consumed Unit.

Source: [columns/consumedquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/consumedquantity.md)

| ID      | Type | Criteria                                                                                                                                      | Status   | Notes |
| ------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CQ1     | MUST | ConsumedQuantity MUST be present in a FOCUS dataset when the provider supports the measurement of usage.                                      | Supports |       |
| CQ2     | MUST | ConsumedQuantity MUST be of type Decimal.                                                                                                     | Supports |       |
| CQ3     | MUST | ConsumedQuantity MUST conform to NumericFormat requirements.                                                                                  | Supports |       |
| CQ3.1   | MUST | ConsumedQuantity MUST be null when ChargeCategory is not "Usage", or when ChargeCategory is "Usage" and CommitmentDiscountStatus is "Unused". | Supports |       |
| CQ3.1.1 | MUST | ConsumedQuantity MUST NOT be null when ChargeClass is not "Correction".                                                                       | Supports |       |
| CQ3.1.2 | MAY  | ConsumedQuantity MAY be null when ChargeClass is "Correction".                                                                                | Supports |       |
| CQ4     | MUST | ConsumedQuantity MUST be a valid decimal value when not null.                                                                                 | Supports |       |

### Consumed unit

Provider-specified measurement unit indicating how a provider measures usage of a metered SKU associated with a resource or service.

Source: [columns/consumedunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/consumedunit.md)

| ID    | Type   | Criteria                                                                                             | Status   | Notes |
| ----- | ------ | ---------------------------------------------------------------------------------------------------- | -------- | ----- |
| CU1   | MUST   | ConsumedUnit MUST be present in a FOCUS dataset when the provider supports the measurement of usage. | Supports |       |
| CU2   | MUST   | ConsumedUnit MUST be of type String.                                                                 | Supports |       |
| CU3   | MUST   | ConsumedUnit MUST conform to StringHandling requirements.                                            | Supports |       |
| CU4   | SHOULD | ConsumedUnit SHOULD conform to UnitFormat requirements.                                              | Supports |       |
| CU4.1 | MUST   | ConsumedUnit MUST be null when ConsumedQuantity is null.                                             | Supports |       |
| CU4.2 | MUST   | ConsumedUnit MUST NOT be null when ConsumedQuantity is not null.                                     | Supports |       |

### Contracted cost

Cost calculated by multiplying contracted unit price and the corresponding Pricing Quantity.

Source: [columns/contractedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/contractedcost.md)

| ID     | Type | Criteria                                                                                                                                                                                                           | Status             | Notes                                                                                                                                                  |
| ------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CnC1   | MUST | ContractedCost MUST be present in a FOCUS dataset.                                                                                                                                                                 | Supports           |                                                                                                                                                        |
| CnC2   | MUST | ContractedCost MUST be of type Decimal.                                                                                                                                                                            | Supports           |                                                                                                                                                        |
| CnC3   | MUST | ContractedCost MUST conform to NumericFormat requirements.                                                                                                                                                         | Supports           |                                                                                                                                                        |
| CnC4   | MUST | ContractedCost MUST NOT be null.                                                                                                                                                                                   | Partially Supports | `ContractedCost` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CnC5   | MUST | ContractedCost MUST be a valid decimal value.                                                                                                                                                                      | Supports           |                                                                                                                                                        |
| CnC6   | MUST | ContractedCost MUST be denominated in the BillingCurrency.                                                                                                                                                         | Supports           |                                                                                                                                                        |
| CnC7.1 | MUST | When ContractedUnitPrice is null... ContractedCost of a charge calculated based on other charges (e.g., when the ChargeCategory is "Tax") MUST be calculated based on the ContractedCost of those related charges. | Supports           |                                                                                                                                                        |
| CnC7.2 | MUST | When ContractedUnitPrice is null... ContractedCost of a charge unrelated to other charges (e.g., when the ChargeCategory is "Credit") MUST match the BilledCost.                                                   | Supports           | `ContractedCost` may be off by less than 0.00001 due to rounding errors.                                                                               |
| CnC8   | MUST | The product of ContractedUnitPrice and PricingQuantity MUST match the ContractedCost when ContractedUnitPrice is not null, PricingQuantity is not null, and ChargeClass is not "Correction".                       | Supports           | `ContractedCost` may be off by less than 0.00001 due to rounding errors.                                                                               |
| CnC9   | MAY  | Discrepancies in ContractedCost, ContractedUnitPrice, or PricingQuantity MAY exist when ChargeClass is "Correction".                                                                                               | Supports           |                                                                                                                                                        |

### Contracted unit price

The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment discounts or any other discounts.

Source: [columns/contractedunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/contractedunitprice.md)

| ID      | Type | Criteria                                                                                                                                                                                           | Status             | Notes                                                                                                                                                       |
| ------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CnUP1   | MUST | ContractedUnitPrice MUST be present in a FOCUS dataset when the provider supports negotiated pricing concepts.                                                                                     | Supports           |                                                                                                                                                             |
| CnUP2   | MUST | ContractedUnitPrice MUST be of type Decimal.                                                                                                                                                       | Supports           |                                                                                                                                                             |
| CnUP3   | MUST | ContractedUnitPrice MUST conform to NumericFormat requirements.                                                                                                                                    | Supports           |                                                                                                                                                             |
| CnUP4.1 | MUST | ContractedUnitPrice MUST be null when ChargeCategory is "Tax".                                                                                                                                     | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                                                                                        |
| CnUP4.2 | MUST | ContractedUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                                             | Partially Supports | `ContractedUnitPrice` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CnUP4.3 | MAY  | ContractedUnitPrice MAY be null in all other cases.                                                                                                                                                | Supports           |                                                                                                                                                             |
| CnUP5.1 | MUST | When ContractedUnitPrice is not null... ContractedUnitPrice MUST be a non-negative decimal value.                                                                                                  | Supports           |                                                                                                                                                             |
| CnUP5.2 | MUST | When ContractedUnitPrice is not null... ContractedUnitPrice MUST be denominated in the BillingCurrency.                                                                                            | Supports           |                                                                                                                                                             |
| CnUP5.3 | MUST | When ContractedUnitPrice is not null... The product of ContractedUnitPrice and PricingQuantity MUST match the ContractedCost when PricingQuantity is not null and ChargeClass is not "Correction". | Supports           | `ContractedCost` may be off by less than 0.00001 due to rounding errors.                                                                                    |
| CnUP6   | MAY  | Discrepancies in ContractedUnitPrice, ContractedCost, or PricingQuantity MAY exist when ChargeClass is "Correction".                                                                               | Supports           |                                                                                                                                                             |

### Effective cost

The amortized cost of the charge after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge.

Source: [columns/effectivecost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/effectivecost.md)

| ID    | Type | Criteria                                                                                                                                                                                                                                                                     | Status   | Notes |
| ----- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| EC1   | MUST | EffectiveCost MUST be present in a FOCUS dataset.                                                                                                                                                                                                                            | Supports |       |
| EC2   | MUST | EffectiveCost MUST be of type Decimal.                                                                                                                                                                                                                                       | Supports |       |
| EC3   | MUST | EffectiveCost MUST conform to NumericFormat requirements.                                                                                                                                                                                                                    | Supports |       |
| EC4   | MUST | EffectiveCost MUST NOT be null.                                                                                                                                                                                                                                              | Supports |       |
| EC5   | MUST | EffectiveCost MUST be a valid decimal value.                                                                                                                                                                                                                                 | Supports |       |
| EC6   | MUST | EffectiveCost MUST be 0 when ChargeCategory is "Purchase" and the purchase is intended to cover future eligible charges.                                                                                                                                                     | Supports |       |
| EC7   | MUST | EffectiveCost MUST be denominated in the BillingCurrency.                                                                                                                                                                                                                    | Supports |       |
| EC8.1 | MUST | EffectiveCost of a charge calculated based on other charges (e.g., when the ChargeCategory is "Tax") MUST be calculated based on the EffectiveCost of those related charges.                                                                                                 | Supports |       |
| EC8.2 | MUST | EffectiveCost of a charge unrelated to other charges (e.g., when the ChargeCategory is "Credit") MUST match the BilledCost.                                                                                                                                                  | Supports |       |
| EC9.1 | MUST | The sum of EffectiveCost where ChargeCategory is "Usage" MUST equal the sum of BilledCost where ChargeCategory is "Purchase".                                                                                                                                                | Supports |       |
| EC9.2 | MUST | The sum of EffectiveCost where ChargeCategory is "Usage" MUST equal the sum of EffectiveCost where ChargeCategory is "Usage" and CommitmentDiscountStatus is "Used", plus the sum of EffectiveCost where ChargeCategory is "Usage" and CommitmentDiscountStatus is "Unused". | Supports |       |

### Invoice ID

The provider-assigned identifier for an invoice encapsulating some or all charges in the corresponding billing period for a given billing account.

Source: [columns/invoiceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/invoiceid.md)

| ID    | Type        | Criteria                                                                                                                              | Status             | Notes                                                                                                 |
| ----- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------- |
| II1   | RECOMMENDED | InvoiceId is RECOMMENDED to be present in a FOCUS dataset.                                                                            | Supports           |                                                                                                       |
| II2   | MUST        | InvoiceId MUST be of type String.                                                                                                     | Supports           |                                                                                                       |
| II3   | MUST        | InvoiceId MUST conform to StringHandling requirements.                                                                                | Supports           |                                                                                                       |
| II4.1 | MUST        | InvoiceId MUST be null when the charge is not associated either with an invoice or with a pre-generated provisional invoice.          | Supports           |                                                                                                       |
| II4.2 | MUST        | InvoiceId MUST NOT be null when the charge is associated with either an issued invoice or a pre-generated provisional invoice.        | Partially Supports | Supported for Microsoft Customer Agreement accounts. Not supported for Enterprise Agreement accounts. |
| II5   | MAY         | InvoiceId MAY be generated prior to an invoice being issued.                                                                          | Not Applicable     |                                                                                                       |
| II6   | MUST        | InvoiceId MUST be associated with the related charge and BillingAccountId when a pre-generated invoice or provisional invoice exists. | Supports           |                                                                                                       |

### Invoice issuer name

The name of the entity responsible for invoicing for the resources or services consumed.

For Cloud Solution Provider (CSP) accounts, `InvoiceIssuerName` is set to the name of the Cloud Solution Provider (CSP) distributor that has a direct relationship with Microsoft and may not represent the organization that directly invoices the end customer. For all other account types, the value is "Microsoft", even if there's an intermediary organization that invoices the end customer.

Source: [columns/invoiceissuer.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/invoiceissuer.md)

| ID   | Type | Criteria                                                       | Status   | Notes |
| ---- | ---- | -------------------------------------------------------------- | -------- | ----- |
| IIN1 | MUST | InvoiceIssuerName MUST be present in a FOCUS dataset.          | Supports |       |
| IIN2 | MUST | InvoiceIssuerName MUST be of type String.                      | Supports |       |
| IIN3 | MUST | InvoiceIssuerName MUST conform to StringHandling requirements. | Supports |       |
| IIN4 | MUST | InvoiceIssuerName MUST NOT be null.                            | Supports |       |

### List cost

Cost calculated by multiplying List Unit Price and the corresponding Pricing Quantity.

Source: [columns/listcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/listcost.md)

| ID    | Type | Criteria                                                                                                                                                                                         | Status             | Notes                                                                                  |
| ----- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | -------------------------------------------------------------------------------------- |
| LC1   | MUST | ListCost MUST be present in a FOCUS dataset.                                                                                                                                                     | Supports           |                                                                                        |
| LC2   | MUST | ListCost MUST be of type Decimal.                                                                                                                                                                | Supports           |                                                                                        |
| LC3   | MUST | ListCost MUST conform to NumericFormat requirements.                                                                                                                                             | Supports           |                                                                                        |
| LC4   | MUST | ListCost MUST NOT be null.                                                                                                                                                                       | Partially Supports | `ListCost` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| LC5   | MUST | ListCost MUST be a valid decimal value.                                                                                                                                                          | Supports           |                                                                                        |
| LC6   | MUST | ListCost MUST be denominated in the BillingCurrency.                                                                                                                                             | Supports           |                                                                                        |
| LC7.1 | MUST | When ListUnitPrice is null... ListCost of a charge calculated based on other charges (e.g., when the ChargeCategory is "Tax") MUST be calculated based on the ListCost of those related charges. | Supports           |                                                                                        |
| LC7.2 | MUST | When ListUnitPrice is null... ListCost of a charge unrelated to other charges (e.g., when the ChargeCategory is "Credit") MUST match the BilledCost.                                             | Supports           | `ListCost` may be off by less than 0.0000000001 due to rounding errors.                |
| LC8   | MUST | The product of ListUnitPrice and PricingQuantity MUST match the ListCost when ListUnitPrice is not null, PricingQuantity is not null, and ChargeClass is not "Correction".                       | Supports           | `ListCost` may be off by less than 0.0000000001 due to rounding errors.                |
| LC9   | MAY  | Discrepancies in ListCost, ListUnitPrice, or PricingQuantity MAY exist when ChargeClass is "Correction".                                                                                         | Supports           |                                                                                        |

### List unit price

The suggested provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts.

Source: [columns/listunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/listunitprice.md)

| ID     | Type | Criteria                                                                                                                                                                         | Status             | Notes                                                                                       |
| ------ | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| LUP1   | MUST | ListUnitPrice MUST be present in a FOCUS dataset when the provider publishes unit prices exclusive of discounts.                                                                 | Supports           |                                                                                             |
| LUP2   | MUST | ListUnitPrice MUST be of type Decimal.                                                                                                                                           | Supports           |                                                                                             |
| LUP3   | MUST | ListUnitPrice MUST conform to NumericFormat requirements.                                                                                                                        | Supports           |                                                                                             |
| LUP4.1 | MUST | ListUnitPrice MUST be null when ChargeCategory is "Tax".                                                                                                                         | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                        |
| LUP4.2 | MUST | ListUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                                 | Partially Supports | `ListUnitPrice` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| LUP4.3 | MAY  | ListUnitPrice MAY be null in all other cases.                                                                                                                                    | Supports           |                                                                                             |
| LUP5.1 | MUST | When ListUnitPrice is not null... ListUnitPrice MUST be a non-negative decimal value.                                                                                            | Supports           |                                                                                             |
| LUP5.2 | MUST | When ListUnitPrice is not null... ListUnitPrice MUST be denominated in the BillingCurrency.                                                                                      | Supports           |                                                                                             |
| LUP5.3 | MUST | When ListUnitPrice is not null... The product of ListUnitPrice and PricingQuantity MUST match the ListCost when PricingQuantity is not null and ChargeClass is not "Correction". | Supports           |                                                                                             |
| LUP5.4 | MAY  | When ListUnitPrice is not null... Discrepancies in ListUnitPrice, ListCost, or PricingQuantity MAY exist when ChargeClass is "Correction".                                       | Supports           |                                                                                             |

### Pricing category

Describes the pricing model used for a charge at the time of use or purchase.

Source: [columns/pricingcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingcategory.md)

| ID     | Type | Criteria                                                                                                                                              | Status         | Notes                                                                |
| ------ | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| PCt1   | MUST | PricingCategory MUST be present in a FOCUS dataset when the provider supports more than one pricing category across all SKUs.                         | Supports       |                                                                      |
| PCt2   | MUST | PricingCategory MUST be of type String.                                                                                                               | Supports       |                                                                      |
| PCt2.1 | MUST | PricingCategory MUST be null when ChargeCategory is "Tax".                                                                                            | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| PCt2.2 | MUST | PricingCategory MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                    | Supports       |                                                                      |
| PCt2.3 | MAY  | PricingCategory MAY be null in all other cases.                                                                                                       | Supports       |                                                                      |
| PCt2.4 | MUST | PricingCategory MUST be one of the allowed values.                                                                                                    | Supports       |                                                                      |
| PCt2.5 | MUST | PricingCategory MUST be "Standard" when pricing is predetermined at the agreed upon rate for the billing account.                                     | Supports       |                                                                      |
| PCt2.6 | MUST | PricingCategory MUST be "Committed" when the charge is subject to an existing commitment discount and is not the purchase of the commitment discount. | Supports       |                                                                      |
| PCt2.7 | MUST | PricingCategory MUST be "Dynamic" when pricing is determined by the provider and may change over time, regardless of predetermined agreement pricing. | Supports       |                                                                      |
| PCt2.8 | MUST | PricingCategory MUST be "Other" when there is a pricing model but none of the allowed values apply.                                                   | Supports       |                                                                      |

### Pricing currency

The national or virtual currency denomination that a resource or service was priced in.

Source: [columns/pricingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingcurrency.md)

| ID   | Type | Criteria                                                                                                                   | Status   | Notes |
| ---- | ---- | -------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| PCu1 | MUST | PricingCurrency MUST be present in a FOCUS dataset when the provider supports pricing and billing in different currencies. | Supports |       |
| PCu2 | MUST | PricingCurrency MUST be of type String.                                                                                    | Supports |       |
| PCu3 | MUST | PricingCurrency MUST conform to StringHandling requirements.                                                               | Supports |       |
| PCu4 | MUST | PricingCurrency MUST conform to CurrencyFormat requirements.                                                               | Supports |       |
| PCu5 | MUST | PricingCurrency MUST NOT be null.                                                                                          | Supports |       |

### Pricing currency contracted unit price

The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment discounts or any other discounts, and expressed in Pricing Currency.

Source: [columns/pricingcurrencycontractedunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingcurrencycontractedunitprice.md)

| ID         | Type        | Criteria                                                                                                                                                                                                    | Status           | Notes                                                                   |
| ---------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------- |
| PCuCnUP1   | MUST        | PricingCurrencyContractedUnitPrice MUST be present in a FOCUS dataset when the provider supports prices in virtual currency and publishes unit prices exclusive of discounts.                               | Not Applicable   |                                                                         |
| PCuCnUP2   | RECOMMENDED | PricingCurrencyContractedUnitPrice is RECOMMENDED to be present in a FOCUS dataset when the provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Does Not Support | Not included in the Cost Management dataset based on customer feedback. |
| PCuCnUP3   | MAY         | PricingCurrencyContractedUnitPrice MAY be present in a FOCUS dataset in all other cases.                                                                                                                    | Not Applicable   |                                                                         |
| PCuCnUP1   | MUST        | PricingCurrencyContractedUnitPrice MUST be of type Decimal.                                                                                                                                                 | Not Applicable   |                                                                         |
| PCuCnUP2   | MUST        | PricingCurrencyContractedUnitPrice MUST conform to NumericFormat requirements.                                                                                                                              | Not Applicable   |                                                                         |
| PCuCnUP2.1 | MUST        | PricingCurrencyContractedUnitPrice MUST be null when ChargeCategory is "Tax".                                                                                                                               | Not Applicable   | Taxes aren't included in any Cost Management cost and usage dataset.    |
| PCuCnUP2.2 | MUST        | PricingCurrencyContractedUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                                       | Not Applicable   |                                                                         |
| PCuCnUP2.3 | MAY         | PricingCurrencyContractedUnitPrice MAY be null in all other cases.                                                                                                                                          | Not Applicable   |                                                                         |
| PCuCnUP2.4 | MUST        | PricingCurrencyContractedUnitPrice MUST be a non-negative decimal value.                                                                                                                                    | Not Applicable   |                                                                         |
| PCuCnUP2.5 | MUST        | PricingCurrencyContractedUnitPrice MUST be denominated in the PricingCurrency.                                                                                                                              | Not Applicable   |                                                                         |
| PCuCnUP3   | MAY         | Discrepancies in PricingCurrencyContractedUnitPrice, ContractedCost, or PricingQuantity MAY exist when ChargeClass is "Correction".                                                                         | Not Applicable   |                                                                         |

### Pricing currency effective cost

The cost of the charge after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge, as denominated in Pricing Currency.

Source: [columns/pricingcurrencyeffectivecost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingcurrencyeffectivecost.md)

| ID     | Type        | Criteria                                                                                                                                                                                              | Status           | Notes                                                                   |
| ------ | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------- |
| PCuEC1 | MUST        | PricingCurrencyEffectiveCost MUST be present in a FOCUS dataset when the provider supports prices in virtual currency and publishes unit prices exclusive of discounts.                               | Not Applicable   |                                                                         |
| PCuEC2 | RECOMMENDED | PricingCurrencyEffectiveCost is RECOMMENDED to be present in a FOCUS dataset when the provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Does Not Support | Not included in the Cost Management dataset based on customer feedback. |
| PCuEC3 | MAY         | PricingCurrencyEffectiveCost MAY be present in a FOCUS dataset in all other cases.                                                                                                                    | Not Applicable   |                                                                         |
| PCuEC1 | MUST        | PricingCurrencyEffectiveCost MUST be of type Decimal.                                                                                                                                                 | Not Applicable   |                                                                         |
| PCuEC2 | MUST        | PricingCurrencyEffectiveCost MUST conform to NumericFormat requirements.                                                                                                                              | Not Applicable   |                                                                         |
| PCuEC3 | MUST        | PricingCurrencyEffectiveCost MUST NOT be null.                                                                                                                                                        | Not Applicable   |                                                                         |
| PCuEC4 | MUST        | PricingCurrencyEffectiveCost MUST be a valid decimal value.                                                                                                                                           | Not Applicable   |                                                                         |
| PCuEC5 | MUST        | PricingCurrencyEffectiveCost MUST be 0 in the event of prepaid purchases or purchases that are applicable to previous usage.                                                                          | Not Applicable   |                                                                         |
| PCuEC6 | MUST        | PricingCurrencyEffectiveCost MUST be denominated in the PricingCurrency.                                                                                                                              | Not Applicable   |                                                                         |

### Pricing currency list unit price

The suggested provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts and expressed in Pricing Currency.

Source: [columns/pricingcurrencylistunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingcurrencylistunitprice.md)

| ID        | Type        | Criteria                                                                                                                                                                                              | Status           | Notes                                                                   |
| --------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------- |
| PCuLUP1   | MUST        | PricingCurrencyListUnitPrice MUST be present in a FOCUS dataset when the provider supports prices in virtual currency and publishes unit prices exclusive of discounts.                               | Not Applicable   |                                                                         |
| PCuLUP2   | RECOMMENDED | PricingCurrencyListUnitPrice is RECOMMENDED to be present in a FOCUS dataset when the provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Does Not Support | Not included in the Cost Management dataset based on customer feedback. |
| PCuLUP3   | MAY         | PricingCurrencyListUnitPrice MAY be present in a FOCUS dataset in all other cases.                                                                                                                    | Not Applicable   |                                                                         |
| PCuLUP1   | MUST        | PricingCurrencyListUnitPrice MUST be of type Decimal.                                                                                                                                                 | Not Applicable   |                                                                         |
| PCuLUP2   | MUST        | PricingCurrencyListUnitPrice MUST conform to NumericFormat requirements.                                                                                                                              | Not Applicable   |                                                                         |
| PCuLUP2.1 | MUST        | PricingCurrencyListUnitPrice MUST be null when ChargeCategory is "Tax".                                                                                                                               | Not Applicable   | Taxes aren't included in any Cost Management cost and usage dataset.    |
| PCuLUP2.2 | MUST        | PricingCurrencyListUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                                       | Not Applicable   |                                                                         |
| PCuLUP2.3 | MAY         | PricingCurrencyListUnitPrice MAY be null in all other cases.                                                                                                                                          | Not Applicable   |                                                                         |
| PCuLUP2.4 | MUST        | PricingCurrencyListUnitPrice MUST be a non-negative decimal value.                                                                                                                                    | Not Applicable   |                                                                         |
| PCuLUP2.5 | MUST        | PricingCurrencyListUnitPrice MUST be denominated in the PricingCurrency.                                                                                                                              | Not Applicable   |                                                                         |
| PCuLUP2.6 | MAY         | Discrepancies in PricingCurrencyListUnitPrice, ListCost, or PricingQuantity MAY be addressed independently when ChargeClass is "Correction".                                                          | Not Applicable   |                                                                         |

### Pricing quantity

The volume of a given SKU associated with a resource or service used or purchased, based on the Pricing Unit.

Source: [columns/pricingquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingquantity.md)

| ID    | Type | Criteria                                                                                                                                                                                                         | Status         | Notes                                                                |
| ----- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| PQ1   | MUST | PricingQuantity MUST be present in a FOCUS dataset.                                                                                                                                                              | Supports       |                                                                      |
| PQ2   | MUST | PricingQuantity MUST be of type Decimal.                                                                                                                                                                         | Supports       |                                                                      |
| PQ3   | MUST | PricingQuantity MUST conform to NumericFormat requirements.                                                                                                                                                      | Supports       |                                                                      |
| PQ3.1 | MUST | PricingQuantity MUST be null when ChargeCategory is "Tax".                                                                                                                                                       | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| PQ3.2 | MUST | PricingQuantity MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                                                               | Supports       |                                                                      |
| PQ3.3 | MAY  | PricingQuantity MAY be null in all other cases.                                                                                                                                                                  | Supports       |                                                                      |
| PQ3.4 | MUST | PricingQuantity MUST be a valid decimal value.                                                                                                                                                                   | Supports       |                                                                      |
| PQ3.5 | MUST | The product of PricingQuantity and a unit price (e.g., ContractedUnitPrice) MUST match the corresponding cost metric (e.g., ContractedCost) when the unit price is not null and ChargeClass is not "Correction". | Supports       |                                                                      |
| PQ4   | MAY  | Discrepancies in PricingQuantity, unit prices (e.g., ContractedUnitPrice), or costs (e.g., ContractedCost) MAY exist when ChargeClass is "Correction".                                                           | Supports       |                                                                      |

### Pricing unit

Provider-specified measurement unit for determining unit prices, indicating how the provider rates measured usage and purchase quantities after applying pricing rules like block pricing.

Source: [columns/pricingunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/pricingunit.md)

| ID    | Type   | Criteria                                                                                                                                                        | Status   | Notes |
| ----- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| PU1   | MUST   | PricingUnit MUST be present in a FOCUS dataset.                                                                                                                 | Supports |       |
| PU2   | MUST   | PricingUnit MUST be of type String.                                                                                                                             | Supports |       |
| PU3   | MUST   | PricingUnit MUST conform to StringHandling requirements.                                                                                                        | Supports |       |
| PU4   | SHOULD | PricingUnit SHOULD conform to UnitFormat requirements.                                                                                                          | Supports |       |
| PU4.1 | MUST   | PricingUnit MUST be null when PricingQuantity is null.                                                                                                          | Supports |       |
| PU4.2 | MUST   | PricingUnit MUST NOT be null when PricingQuantity is not null.                                                                                                  | Supports |       |
| PU4.3 | MUST   | PricingUnit MUST be semantically equal to the corresponding pricing measurement unit provided in provider-published price list.                                 | Supports |       |
| PU4.4 | MUST   | PricingUnit MUST be semantically equal to the corresponding pricing measurement unit provided in invoice, when the invoice includes a pricing measurement unit. | Supports |       |

### Provider name

The name of the entity that made the resources or services available for purchase.

Source: [columns/provider.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/provider.md)

| ID   | Type | Criteria                                                  | Status   | Notes |
| ---- | ---- | --------------------------------------------------------- | -------- | ----- |
| PvN1 | MUST | ProviderName MUST be present in a FOCUS dataset.          | Supports |       |
| PvN2 | MUST | ProviderName MUST be of type String.                      | Supports |       |
| PvN3 | MUST | ProviderName MUST conform to StringHandling requirements. | Supports |       |
| PvN4 | MUST | ProviderName MUST NOT be null.                            | Supports |       |

### Publisher name

The name of the entity that produced the resources or services that were purchased.

Source: [columns/publisher.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/publisher.md)

| ID   | Type | Criteria                                                   | Status             | Notes                                                                                             |
| ---- | ---- | ---------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------- |
| PbN1 | MUST | PublisherName MUST be present in a FOCUS dataset.          | Supports           |                                                                                                   |
| PbN2 | MUST | PublisherName MUST be of type String.                      | Supports           |                                                                                                   |
| PbN3 | MUST | PublisherName MUST conform to StringHandling requirements. | Supports           |                                                                                                   |
| PbN4 | MUST | PublisherName MUST NOT be null.                            | Partially Supports | `PublisherName` may be null for reservation usage and purchases, and savings plan unused charges. |

### Region ID

Provider-assigned identifier for an isolated geographic area where a resource is provisioned or a service is provided.

Source: [columns/regionid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/regionid.md)

| ID     | Type | Criteria                                                                                                                | Status   | Notes |
| ------ | ---- | ----------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RgI1   | MUST | RegionId MUST be present in a FOCUS dataset when the provider supports deploying resources or services within a region. | Supports |       |
| RgI2   | MUST | RegionId MUST be of type String.                                                                                        | Supports |       |
| RgI3   | MUST | RegionId MUST conform to StringHandling requirements.                                                                   | Supports |       |
| RgI3.1 | MUST | RegionId MUST NOT be null when a resource or service is operated in or managed from a distinct region.                  | Supports |       |
| RgI3.2 | MAY  | RegionId MAY be null when a resource or service is not operated in or managed from a distinct region.                   | Supports |       |

### Region name

The name of an isolated geographic area where a resource is provisioned or a service is provided.

Source: [columns/regionname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/regionname.md)

| ID     | Type | Criteria                                                                                                                  | Status   | Notes |
| ------ | ---- | ------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RgN1   | MUST | RegionName MUST be present in a FOCUS dataset when the provider supports deploying resources or services within a region. | Supports |       |
| RgN2   | MUST | RegionName MUST be of type String.                                                                                        | Supports |       |
| RgN3   | MUST | RegionName MUST conform to StringHandling requirements.                                                                   | Supports |       |
| RgN3.1 | MUST | RegionName MUST be null when RegionId is null.                                                                            | Supports |       |
| RgN3.2 | MUST | RegionName MUST NOT be null when RegionId is not null.                                                                    | Supports |       |

### Resource ID

Identifier assigned to a resource by the provider.

Source: [columns/resourceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/resourceid.md)

| ID     | Type   | Criteria                                                                                                         | Status   | Notes                                                                                                                                                                        |
| ------ | ------ | ---------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RsI1   | MUST   | ResourceId MUST be present in a FOCUS dataset when the provider supports billing based on provisioned resources. | Supports |                                                                                                                                                                              |
| RsI2   | MUST   | ResourceId MUST be of type String.                                                                               | Supports |                                                                                                                                                                              |
| RsI3   | MUST   | ResourceId MUST conform to StringHandling requirements.                                                          | Supports |                                                                                                                                                                              |
| RsI3.1 | MUST   | ResourceId MUST be null when a charge is not related to a resource.                                              | Supports | Purchases may not have an assigned resource ID.                                                                                                                              |
| RsI3.2 | MUST   | ResourceId MUST NOT be null when a charge is related to a resource.                                              | Supports | `ResourceId` may be null when a resource is indirectly related to the charges. If you feel it's missing, file a support request for the service that owns the resource type. |
| RsI3.3 | MUST   | ResourceId MUST be a unique identifier within the provider.                                                      | Supports |                                                                                                                                                                              |
| RsI3.4 | SHOULD | ResourceId SHOULD be a fully-qualified identifier.                                                               | Supports |                                                                                                                                                                              |

### Resource name

Display name assigned to a resource.

Source: [columns/resourcename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/resourcename.md)

| ID     | Type | Criteria                                                                                                                                 | Status   | Notes |
| ------ | ---- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RsN1   | MUST | ResourceName MUST be present in a FOCUS dataset when the provider supports billing based on provisioned resources.                       | Supports |       |
| RsN2   | MUST | ResourceName MUST be of type String.                                                                                                     | Supports |       |
| RsN3   | MUST | ResourceName MUST conform to StringHandling requirements.                                                                                | Supports |       |
| RsN3.1 | MUST | ResourceName MUST be null when ResourceId is null or when the resource does not have an assigned display name.                           | Supports |       |
| RsN3.2 | MUST | ResourceName MUST NOT be null when ResourceId is not null and the resource has an assigned display name.                                 | Supports |       |
| RsN4   | MUST | ResourceName MUST NOT duplicate ResourceId when the resource is not provisioned interactively or only has a system-generated ResourceId. | Supports |       |

### Resource type

The kind of resource the charge applies to.

Source: [columns/resourcetype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/resourcetype.md)

| ID     | Type | Criteria                                                                                                                                                     | Status   | Notes |
| ------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| RsT1   | MUST | ResourceType MUST be present in a FOCUS dataset when the provider supports billing based on provisioned resources and supports assigning types to resources. | Supports |       |
| RsT2   | MUST | ResourceType MUST be of type String.                                                                                                                         | Supports |       |
| RsT3   | MUST | ResourceType MUST conform to StringHandling requirements.                                                                                                    | Supports |       |
| RsT3.1 | MUST | ResourceType MUST be null when ResourceId is null.                                                                                                           | Supports |       |
| RsT3.2 | MUST | ResourceType MUST NOT be null when ResourceId is not null.                                                                                                   | Supports |       |

### Service category

Highest-level classification of a service based on the core function of the service.

`ServiceCategory` is set based on a resource type mapping that uses the [Services](../toolkit/open-data.md#services) dataset in the FinOps toolkit. If you see gaps, please [submit a change request](https://aka.ms/ftk/ideas).

Source: [columns/servicecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/servicecategory.md)

| ID   | Type | Criteria                                            | Status   | Notes |
| ---- | ---- | --------------------------------------------------- | -------- | ----- |
| SvC1 | MUST | ServiceCategory MUST be present in a FOCUS dataset. | Supports |       |
| SvC2 | MUST | ServiceCategory MUST be of type String.             | Supports |       |
| SvC3 | MUST | ServiceCategory MUST NOT be null.                   | Supports |       |
| SvC4 | MUST | ServiceCategory MUST be one of the allowed values.  | Supports |       |

### Service name

An offering that can be purchased from a provider (e.g., cloud virtual machine, SaaS database, professional services from a systems integrator).

`ServiceName` is set based on a resource type mapping that uses the [Services](../toolkit/open-data.md#services) dataset in the FinOps toolkit. If you see gaps, please [submit a change request](https://aka.ms/ftk/ideas).

Source: [columns/servicename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/servicename.md)

| ID     | Type   | Criteria                                                                                                                                                        | Status             | Notes                                                          |
| ------ | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------- |
| SvN1   | MUST   | ServiceName MUST be present in a FOCUS dataset.                                                                                                                 | Supports           |                                                                |
| SvN2   | MUST   | ServiceName MUST be of type String.                                                                                                                             | Supports           |                                                                |
| SvN3   | MUST   | ServiceName MUST conform to StringHandling requirements.                                                                                                        | Supports           |                                                                |
| SvN4   | MUST   | ServiceName MUST NOT be null.                                                                                                                                   | Partially supports | `ServiceName` may be empty for some purchases and adjustments. |
| SvN5.1 | MUST   | ServiceName MUST have one and only one ServiceCategory that best aligns with its primary purpose, except when no suitable ServiceCategory is available.         | Supports           |                                                                |
| SvN5.2 | MUST   | ServiceName MUST be associated with the ServiceCategory "Other" when no suitable ServiceCategory is available.                                                  | Supports           |                                                                |
| SvN6.1 | SHOULD | ServiceName SHOULD have one and only one ServiceSubcategory that best aligns with its primary purpose, except when no suitable ServiceSubcategory is available. | Supports           |                                                                |
| SvN6.2 | SHOULD | ServiceName SHOULD be associated with the ServiceSubcategory "Other" when no suitable ServiceSubcategory is available.                                          | Supports           |                                                                |

### Service subcategory

Secondary classification of the Service Category for a service based on its core function.

`ServiceSubcategory` is set based on a resource type mapping that uses the [Services](../toolkit/open-data.md#services) dataset in the FinOps toolkit. If you see gaps, please [submit a change request](https://aka.ms/ftk/ideas).

Source: [columns/servicesubcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/servicesubcategory.md)

| ID   | Type        | Criteria                                                                                                       | Status   | Notes |
| ---- | ----------- | -------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| SvS1 | RECOMMENDED | ServiceSubcategory is RECOMMENDED to be present in a FOCUS dataset.                                            | Supports |       |
| SvS2 | MUST        | ServiceSubcategory MUST be of type String.                                                                     | Supports |       |
| SvS3 | MUST        | ServiceSubcategory MUST NOT be null.                                                                           | Supports |       |
| SvS4 | MUST        | ServiceSubcategory MUST be one of the allowed values.                                                          | Supports |       |
| SvS5 | MUST        | ServiceSubcategory MUST have one and only one parent ServiceCategory as specified in the allowed values below. | Supports |       |

### SKU ID

Provider-specified unique identifier that represents a specific SKU (e.g., a quantifiable good or service offering).

Source: [columns/skuid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/skuid.md)

| ID     | Type | Criteria                                                                                                                                                 | Status             | Notes                                                                                       |
| ------ | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| SkI1   | MUST | SkuId MUST be present in a FOCUS dataset when the provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Supports           |                                                                                             |
| SkI2   | MUST | SkuId MUST be of type String.                                                                                                                            | Supports           |                                                                                             |
| SkI3   | MUST | SkuId MUST conform to StringHandling requirements.                                                                                                       | Supports           |                                                                                             |
| SkI4.1 | MUST | SkuId MUST be null when ChargeCategory is "Tax".                                                                                                         | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                        |
| SkI4.2 | MUST | SkuId MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                 | Partially Supports | `SkuId` may be null for some rows like savings plan unused charges and Marketplace charges. |
| SkI4.3 | MAY  | SkuId MAY be null in all other cases.                                                                                                                    | Supports           |                                                                                             |
| SkI5.1 | MUST | SkuId MUST remain consistent across billing accounts or contracts.                                                                                       | Supports           |                                                                                             |
| SkI5.2 | MUST | SkuId MUST remain consistent across PricingCategory values.                                                                                              | Partially Supports | `SkuId` may be different for some `PricingCategory` values.                                 |
| SkI5.3 | MUST | SkuId MUST remain consistent regardless of any other factors that might impact the price but do not affect the functionality of the SKU.                 | Partially Supports | `SkuId` may be different for some SKUs that offer the same functionality.                   |
| SkI6   | MUST | SkuId MUST be associated with a given resource or service when ChargeCategory is "Usage" or "Purchase".                                                  | Supports           |                                                                                             |
| SkI7   | MAY  | SkuId MAY equal SkuPriceId.                                                                                                                              | Supports           |                                                                                             |

### SKU meter

Describes the functionality being metered or measured by a particular SKU in a charge.

Source: [columns/skumeter.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/skumeter.md)

| ID     | Type   | Criteria                                                                                                                                                    | Status             | Notes                                            |
| ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------ |
| SkM1   | MUST   | SkuMeter MUST be present in a FOCUS dataset when the provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Supports           |                                                  |
| SkM2   | MUST   | SkuMeter MUST be of type String.                                                                                                                            | Supports           |                                                  |
| SkM3   | MUST   | SkuMeter MUST conform to StringHandling requirements.                                                                                                       | Supports           |                                                  |
| SkM4.1 | MUST   | SkuMeter MUST be null when SkuId is null.                                                                                                                   | Supports           |                                                  |
| SkM4.2 | SHOULD | SkuMeter SHOULD NOT be null when SkuId is not null.                                                                                                         | Supports           |                                                  |
| SkM5   | SHOULD | SkuMeter SHOULD remain consistent over time for a given SkuId.                                                                                              | Partially Supports | `SkuMeter` may be different for a given `SkuId`. |

### SKU price details

A set of properties of a SKU Price ID which are meaningful and common to all instances of that SKU Price ID.

Source: [columns/skupricedetails.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/skupricedetails.md)

| ID        | Type   | Criteria                                                                                                                                                                  | Status           | Notes                                                                                |
| --------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------ |
| SkPD1     | MUST   | SkuPriceDetails MUST be present in a FOCUS dataset when the provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting.        | Does Not Support | `SkuPriceDetails` is not specified in the Cost Management FOCUS 1.2-preview dataset. |
| SkPD2     | MUST   | SkuPriceDetails MUST conform to KeyValueFormat requirements.                                                                                                              | Not Applicable   |                                                                                      |
| SkPD3     | SHOULD | SkuPriceDetails property keys SHOULD conform to PascalCase format.                                                                                                        | Not Applicable   |                                                                                      |
| SkPD3.1   | MUST   | SkuPriceDetails MUST be null when SkuPriceId is null.                                                                                                                     | Not Applicable   |                                                                                      |
| SkPD3.2   | MAY    | SkuPriceDetails MAY be null when SkuPriceId is not null.                                                                                                                  | Not Applicable   |                                                                                      |
| SkPD3.3   | MUST   | SkuPriceDetails MUST be associated with a given SkuPriceId.                                                                                                               | Not Applicable   |                                                                                      |
| SkPD3.4   | MUST   | SkuPriceDetails MUST NOT include properties that are not applicable to the corresponding SkuPriceId.                                                                      | Not Applicable   |                                                                                      |
| SkPD3.5   | SHOULD | SkuPriceDetails SHOULD include all FOCUS-defined SKU Price properties listed below that are applicable to the corresponding SkuPriceId.                                   | Not Applicable   |                                                                                      |
| SkPD3.6   | MUST   | SkuPriceDetails MUST include the FOCUS-defined SKU Price property when an equivalent property is included as a Provider-defined property.                                 | Not Applicable   |                                                                                      |
| SkPD3.7   | MAY    | SkuPriceDetails MAY include properties that are already captured in other dedicated columns.                                                                              | Not Applicable   |                                                                                      |
| SkPD3.7.1 | SHOULD | Existing SkuPriceDetails properties SHOULD remain consistent over time.                                                                                                   | Not Applicable   |                                                                                      |
| SkPD3.7.2 | SHOULD | Existing SkuPriceDetails properties SHOULD NOT be removed.                                                                                                                | Not Applicable   |                                                                                      |
| SkPD3.7.3 | MAY    | Additional SkuPriceDetails properties MAY be added over time.                                                                                                             | Not Applicable   |                                                                                      |
| SkPD3.8   | SHOULD | Property key SHOULD remain consistent across comparable SKUs having that property, and the values for this key SHOULD remain in a consistent format.                      | Not Applicable   |                                                                                      |
| SkPD3.9   | SHOULD | Property key SHOULD remain consistent across comparable SKUs having that property, and the values for this key SHOULD remain in a consistent format.                      | Not Applicable   |                                                                                      |
| SkPD3.10  | MUST   | Property key MUST begin with the string "x_" unless it is a FOCUS-defined property.                                                                                       | Not Applicable   |                                                                                      |
| SkPD3.11  | MUST   | Property value MUST represent the value for a single PricingUnit when the property holds a numeric value.                                                                 | Not Applicable   |                                                                                      |
| SkPD3.12  | MUST   | Property key MUST match the spelling and casing specified for the FOCUS-defined property.                                                                                 | Not Applicable   |                                                                                      |
| SkPD3.13  | MUST   | Property value MUST be of the type specified for that property.                                                                                                           | Not Applicable   |                                                                                      |
| SkPD3.14  | MUST   | Property value MUST represent the value for a single PricingUnit, denominated in the unit of measure specified for that property when the property holds a numeric value. | Not Applicable   |                                                                                      |

### SKU price ID

A provider-specified unique identifier that represents a specific SKU Price associated with a resource or service used or purchased.

Source: [columns/skupriceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/skupriceid.md)

| ID      | Type | Criteria                                                                                                                                                                 | Status             | Notes                                                                                                                                                                                                                                                                                              |
| ------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SkPI1   | MUST | SkuPriceId MUST be present in a FOCUS dataset when the provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting.            | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI2   | MUST | SkuPriceId MUST be of type String.                                                                                                                                       | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI3   | MUST | SkuPriceId MUST conform to String Handling requirements.                                                                                                                 | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI4.1 | MUST | SkuPriceId MUST be null when ChargeCategory is "Tax".                                                                                                                    | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                                                                                                                                                                                                                               |
| SkPI4.2 | MUST | SkuPriceId MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction".                                                            | Partially Supports | `SkuPriceId` may be null for some rows like savings plan unused charges and Marketplace charges.                                                                                                                                                                                                   |
| SkPI4.3 | MAY  | SkuPriceId MAY be null in all other cases.                                                                                                                               | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.1 | MUST | When SkuPriceId is not null... SkuPriceId MUST have one and only one parent SkuId.                                                                                       | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.2 | MUST | When SkuPriceId is not null... SkuPriceId MUST remain consistent over time.                                                                                              | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.3 | MUST | When SkuPriceId is not null... SkuPriceId MUST remain consistent across billing accounts or contracts.                                                                   | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.4 | MAY  | When SkuPriceId is not null... SkuPriceId MAY equal SkuId.                                                                                                               | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.5 | MUST | When SkuPriceId is not null... SkuPriceId MUST be associated with a given resource or service when ChargeCategory is "Usage" or "Purchase".                              | Supports           |                                                                                                                                                                                                                                                                                                    |
| SkPI5.6 | MUST | When SkuPriceId is not null... SkuPriceId MUST reference a SKU Price in a provider-supplied price list, enabling the lookup of detailed information about the SKU Price. | Does Not Support   | `SkuPriceId` cannot be directly mapped to a single SKU in the price sheet. For EA, `SkuPriceId` represents an individual SKU price but isn't available in the price sheet dataset. For MCA, `SkuPriceId` is a combination of the following price sheet columns: `{ProductId}_{SkuId}_{MeterType}`. |
| SkPI5.7 | MUST | When SkuPriceId is not null... SkuPriceId MUST support the lookup of the ListUnitPrice when the provider publishes unit prices exclusive of discounts.                   | Does Not Support   | See SkPI5.6.                                                                                                                                                                                                                                                                                       |
| SkPI5.8 | MUST | When SkuPriceId is not null... SkuPriceId MUST support the verification of the given ContractedUnitPrice when the provider supports negotiated pricing concepts.         | Partially Supports | `ContractedUnitPrice` may not be set or may be 0 for some rows, like reservation usage.                                                                                                                                                                                                            |

### Sub account ID

An ID assigned to a grouping of resources or services, often used to manage access and/or cost.

FOCUS subaccount maps to a Microsoft Cloud subscription.

Source: [columns/subaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/subaccountid.md)

| ID      | Type | Criteria                                                                                            | Status   | Notes                                                     |
| ------- | ---- | --------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------- |
| SbAI1   | MUST | SubAccountId MUST be present in a FOCUS dataset when the provider supports a sub account construct. | Supports |                                                           |
| SbAI2   | MUST | SubAccountId MUST be of type String.                                                                | Supports |                                                           |
| SbAI3   | MUST | SubAccountId MUST conform to StringHandling requirements.                                           | Supports |                                                           |
| SbAI3.1 | MUST | SubAccountId MUST be null when a charge is not related to a sub account.                            | Supports | `SubAccountId` may be null for MCA purchases and refunds. |
| SbAI3.2 | MUST | SubAccountId MUST NOT be null when a charge is related to a sub account.                            | Supports |                                                           |

### Sub account name

A name assigned to a grouping of resources or services, often used to manage access and/or cost.

FOCUS subaccount maps to a Microsoft Cloud subscription.

Source: [columns/subaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/subaccountname.md)

| ID      | Type | Criteria                                                                                              | Status   | Notes |
| ------- | ---- | ----------------------------------------------------------------------------------------------------- | -------- | ----- |
| SbAN1   | MUST | SubAccountName MUST be present in a FOCUS dataset when the provider supports a sub account construct. | Supports |       |
| SbAN2   | MUST | SubAccountName MUST be of type String.                                                                | Supports |       |
| SbAN3   | MUST | SubAccountName MUST conform to StringHandling requirements.                                           | Supports |       |
| SbAN3.1 | MUST | SubAccountName MUST be null when SubAccountId is null.                                                | Supports |       |
| SbAN3.2 | MUST | SubAccountName MUST NOT be null when SubAccountId is not null.                                        | Supports |       |

### Sub account type

A provider-assigned name to identify the type of sub account.

FOCUS subaccount maps to a Microsoft Cloud subscription.

Source: [columns/subaccounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/subaccounttype.md)

| ID      | Type | Criteria                                                                                                                  | Status   | Notes |
| ------- | ---- | ------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| SbAT1   | MUST | SubAccountType MUST be present in a FOCUS dataset when the provider supports more than one possible SubAccountType value. | Supports |       |
| SbAT2   | MUST | SubAccountType MUST be of type String.                                                                                    | Supports |       |
| SbAT3   | MUST | SubAccountType MUST conform to StringHandling requirements.                                                               | Supports |       |
| SbAT3.1 | MUST | SubAccountType MUST be null when SubAccountId is null.                                                                    | Supports |       |
| SbAT3.2 | MUST | SubAccountType MUST NOT be null when SubAccountId is not null.                                                            | Supports |       |
| SbAT4   | MUST | SubAccountType MUST be a consistent, readable display value.                                                              | Supports |       |

### Tags

The set of tags assigned to tag sources that account for potential provider-defined or user-defined tag evaluations.

Source: [columns/tags.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.2/specification/columns/tags.md)

| ID   | Type   | Criteria                                                                                                                                                                                                                                   | Status           | Notes                                                                                                                            |
| ---- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| T1   | MUST   | Tags MUST be present in a FOCUS dataset when the provider supports setting user or provider-defined tags.                                                                                                                                  | Supports         |                                                                                                                                  |
| T2   | MUST   | Tags MUST conform to KeyValueFormat requirements.                                                                                                                                                                                          | Supports         |                                                                                                                                  |
| T3   | MAY    | Tags MAY be null.                                                                                                                                                                                                                          | Supports         |                                                                                                                                  |
| T4.1 | MUST   | Tags MUST include all user-defined and provider-defined tags.                                                                                                                                                                              | Supports         |                                                                                                                                  |
| T4.2 | MUST   | Tags MUST only include finalized tags.                                                                                                                                                                                                     | Supports         |                                                                                                                                  |
| T4.3 | SHOULD | Tags SHOULD include tag keys with corresponding non-null values for a given resource.                                                                                                                                                      | Supports         |                                                                                                                                  |
| T4.4 | MAY    | Tags MAY include tag keys with a null value for a given resource depending on the provider's tag finalization process.                                                                                                                     | Supports         |                                                                                                                                  |
| T4.5 | MUST   | Tag keys that do not support corresponding values, MUST have a corresponding true (boolean) value set.                                                                                                                                     | Not Applicable   | Microsoft Cloud tags support both keys and values.                                                                               |
| T4.6 | SHOULD | Provider SHOULD publish tag finalization methods and semantics within their respective documentation.                                                                                                                                      | Supports         |                                                                                                                                  |
| T4.7 | MUST   | Provider MUST NOT alter tag values unless applying true (boolean) to valueless tags.                                                                                                                                                       | Supports         |                                                                                                                                  |
| T5.1 | MUST   | Provider-defined tag keys MUST be prefixed with a predetermined, provider-specified tag key prefix that is unique to each corresponding provider-specified tag scheme.                                                                     | Does Not Support | Provider-specified tags can't be differentiated from user-defined tags. Tags aren't modified to support backwards compatibility. |
| T5.2 | SHOULD | Provider SHOULD publish all provider-specified tag key prefixes within their respective documentation.                                                                                                                                     | Not Applicable   | Provider prefixes aren't currently specified.                                                                                    |
| T6.1 | MUST   | Provider MUST prefix all but one user-defined tag scheme with a predetermined, provider-specified tag key prefix that is unique to each corresponding user-defined tag scheme when the provider has more than one user-defined tag scheme. | Supports         |                                                                                                                                  |
| T6.2 | MUST   | Provider MUST NOT prefix tag keys when the provider has only one user-defined tag scheme.                                                                                                                                                  | Supports         |                                                                                                                                  |
| T6.3 | MUST   | Provider MUST NOT allow reserved tag key prefixes to be used as prefixes for any user-defined tag keys within a prefixless user-defined tag scheme.                                                                                        | Supports         |                                                                                                                                  |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.11/bladeName/Guide.FOCUS/featureName/Conformance.Report)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [FOCUS conformance summary](./conformance-summary.md)
- [Microsoft Cost Management FOCUS dataset](/azure/cost-management-billing/dataset-schema/cost-usage-details-focus)

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../toolkit/powershell/powershell-commands.md)
- [FinOps toolkit open data](../toolkit/open-data.md)

<br>
