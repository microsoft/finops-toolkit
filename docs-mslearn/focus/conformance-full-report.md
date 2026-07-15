---
title: FOCUS conformance report
description: Comprehensive analysis of the Microsoft Cost Management FOCUS dataset's adherence to FOCUS requirements.
author: flanakin
ms.author: micflan
ms.date: 07/15/2026
ms.topic: reference
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
---

# FOCUS conformance full report

This document provides a detailed list of all FOCUS 1.4 requirements and indicates the level of support provided by the Microsoft Cost Management FOCUS dataset. Requirements that were added or revised in FOCUS 1.3 and 1.4 are marked as "Not Evaluated" until they're formally assessed. To learn more about FOCUS, refer to the [FOCUS overview](./what-is-focus.md).

<br>

## How conformance is measured

FOCUS requirements fall into four groups:

- **MUST** requirements are mandatory for all data providers.
- **SHOULD** requirements are strong recommendations.
- **RECOMMENDED** requirements are suggested best practices.
- **MAY** requirements are optional and used to prepare FinOps practitioners for edge cases.

While there's no official measurement for FOCUS conformance, we calculate a conformance score of **96%**, which accounts for all fully supported and half of the partially supported requirements. Requirements marked as not applicable or not evaluated aren't included in the score. The following table summarizes requirements by level of support.

| Type            | Supported | Partial support | Not supported | Not applicable | Not evaluated |
| :-------------- | :-------: | :-------------: | :-----------: | :------------: | :-----------: |
| **MUST**        |    168    |       10        |       1       |       59       |      909      |
| **SHOULD**      |     9     |        2        |       1       |       10       |      73       |
| **MAY**         |    10     |                 |               |       7        |      39       |
| Summary         |   93.0%   |      6.0%       |     1.0%      |                |               |

<br>

## How this document is organized

The following sections list each FOCUS requirement, the level of support in the Microsoft Cost Management FOCUS dataset, and any relevant notes. For a high-level summary of the gaps, refer to the [FOCUS conformance summary](./conformance-summary.md). Requirement IDs are for reference purposes only. IDs aren't defined as part of FOCUS.

The rest of this document lists the FOCUS requirements grouped by attribute, dataset, and column. [Datasets](#datasets) define the collections of data elements a provider publishes, [columns](#columns) define the specific data elements in each dataset, and [attributes](#attributes) define how columns and rows should behave. High-level descriptions and a link to the original requirements document are included at the top of each section.

<br>

## Attributes

### Correction handling

Defines how corrections to previously delivered FOCUS dataset artifacts are represented in subsequent deliveries.

Source: [attributes/correction_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/correction_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CH1 | MUST | Dataset conforming to CorrectionHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| CH1.1 | MUST | FOCUS dataset MUST have its styles for representing corrections in dataset artifacts documented and accessible to practitioners (including whether Replacement, Delta, or Ledger style is used and under which conditions each style applies). | Not Evaluated |  |
| CH1.2 | MUST | FOCUS dataset MUST represent a complete snapshot of data for the affected delivery scope when using Replacement correction style. | Not Evaluated |  |
| CH1.3 | MUST | FOCUS dataset MUST include additive records representing corrections within the same delivery scope when using Delta correction style. | Not Evaluated |  |
| CH1.4 | MUST | FOCUS dataset MUST include explicit reversal and re-entry additive records representing corrections within the same delivery scope when using Ledger correction style. | Not Evaluated |  |

### Currency format

Formatting for currency columns appearing in a FOCUS dataset.

Source: [attributes/currency_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/currency_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CF1 | MUST | Column conforming to CurrencyFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| CF1.1 | MUST | FOCUS dataset column MUST conform to ISO 4217:2015 standard. | Not Evaluated |  |
| CF1.2 | MUST | FOCUS dataset column MUST use the three-letter alphabetic code defined in ISO 4217:2015 (e.g., USD, EUR). | Not Evaluated |  |

### Custom column handling

Column ID naming, formatting, and value requirements for custom columns appearing in a FOCUS dataset.

Source: [attributes/custom_column_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/custom_column_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CCH1 | MUST | Column conforming to CustomColumnHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| CCH1.1 | MUST | Custom column MUST adhere to the following Column ID naming requirements: | Not Evaluated |  |
| CCH1.1.1 | MUST | Custom column MUST include the `x_` prefix in the Column ID to identify it as an external custom column and to distinguish it from FOCUS columns to avoid conflicts in future releases. | Not Evaluated |  |
| CCH1.1.2 | SHOULD | Custom column SHOULD use Pascal case in the portion of the Column ID following the required `x_` prefix. | Not Evaluated |  |
| CCH1.1.3 | SHOULD | Custom column SHOULD use only alphanumeric characters in the portion of the Column ID following the required `x_` prefix. | Not Evaluated |  |
| CCH1.1.4 | SHOULD | Custom column SHOULD NOT include special characters other than the underscore in the required `x_` prefix. | Not Evaluated |  |
| CCH1.1.5 | SHOULD | Custom column SHOULD NOT use abbreviations other than `Id` in the Column ID. | Not Evaluated |  |
| CCH1.1.6 | SHOULD | Custom column SHOULD NOT use acronyms other than `Sku` in the Column ID. | Not Evaluated |  |
| CCH1.1.7 | SHOULD | Custom column SHOULD NOT exceed 50 characters in the Column ID to accommodate column length restrictions of various data repositories. | Not Evaluated |  |
| CCH1.1.8 | SHOULD | Custom column SHOULD include the `Id` suffix in the Column ID when the custom column represents an identifier. | Not Evaluated |  |
| CCH1.1.9 | SHOULD | Custom column SHOULD include the `Name` suffix in the Column ID when the custom column represents a name. | Not Evaluated |  |
| CCH1.2 | SHOULD | Custom column SHOULD conform to DataGeneratorCalculatedSplitCostAllocationHandling requirements when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CCH1.3 | SHOULD | Custom column SHOULD conform to NullHandling requirements. | Not Evaluated |  |
| CCH1.4 | SHOULD | Custom column containing date/time values SHOULD conform to DateTimeFormat requirements. | Not Evaluated |  |
| CCH1.5 | MUST | Custom column containing JSON objects MUST have its object schema documented by the data generator and accessible to practitioners. | Not Evaluated |  |
| CCH1.6 | MUST | Custom column containing numeric values MUST contain a single numeric value. | Not Evaluated |  |
| CCH1.7 | SHOULD | Custom column containing numeric values SHOULD conform to NumericFormat requirements. | Not Evaluated |  |
| CCH1.8 | SHOULD | Custom column containing string values SHOULD conform to StringHandling requirements. | Not Evaluated |  |
| CCH1.9 | SHOULD | Custom column representing a national currency SHOULD conform to CurrencyFormat requirements. | Not Evaluated |  |
| CCH1.10 | SHOULD | Custom column representing a measurement unit SHOULD conform to UnitFormat requirements. | Not Evaluated |  |

### Data generator-calculated split cost allocation handling

An attribute that allows data generators to offer more detailed cost and usage information based on a method defined and documented by the data generator, including support for allocating costs in cases where the usage of a resource might not match the units the resource is measured in.

Source: [attributes/data_generator_calculated_split_cost_allocation_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/data_generator_calculated_split_cost_allocation_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| DGCSCAH1 | MUST | Column conforming to DataGeneratorCalculatedSplitCostAllocationHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| DGCSCAH1.1 | MUST | FOCUS dataset column representing a dimension MUST match the corresponding value in the origin charge when present in an allocated charge. | Not Evaluated |  |
| DGCSCAH1.2 | MUST | FOCUS dataset column representing a non-summable metric (e.g., unit prices) MUST match the corresponding value in the origin charge when present in an allocated charge. | Not Evaluated |  |
| DGCSCAH1.1 | MUST | The sum of FOCUS dataset column across allocated charges MUST match the FOCUS dataset column in the corresponding origin charge when the FOCUS dataset column represents a summable metric (e.g., costs and quantities). | Not Evaluated |  |

### Dataset completeness

Defines requirements for a FOCUS dataset to include custom columns for native dataset columns not represented in FOCUS columns.

Source: [attributes/dataset_completeness.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/dataset_completeness.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| DC1 | MUST | Dataset conforming to DatasetCompleteness attribute MUST adhere to the following requirements: | Not Evaluated |  |
| DC1.1 | MUST | FOCUS dataset MUST adhere to the following custom column presence requirements: | Not Evaluated |  |
| DC1.1.1 | MUST | FOCUS dataset MUST include custom columns (e.g., `x_ChargeSubType`) needed to support invoice reconciliation when the invoice issuer supports payable invoices, and when FOCUS columns are not sufficient. | Not Evaluated |  |
| DC1.1.2 | MUST | FOCUS dataset MUST include custom columns corresponding to native dataset columns, except those explicitly listed as exclusions with justification in publicly-available documentation, provided those excluded columns are unrelated to invoice reconciliation. | Not Evaluated |  |
| DC1.1.3 | MUST | FOCUS dataset MUST have all included custom columns documented in publicly-available documentation, including description, purpose, and relationship to native dataset columns. | Not Evaluated |  |
| DC1.1.4 | SHOULD | FOCUS dataset SHOULD include custom columns that enable correlation between FOCUS dataset records and native dataset records (e.g., native charge identifiers), even when they meet the criteria for exclusion. | Not Evaluated |  |
| DC1.1.5 | SHOULD | FOCUS dataset SHOULD exclude custom columns that duplicate information already captured in FOCUS columns, except during a transitional period as defined in publicly-available documentation, to enable migration without breaking changes. | Not Evaluated |  |
| DC1.2 | MUST | FOCUS dataset MUST retain the fidelity of corresponding native dataset values within custom columns without lossy transformations (e.g., rounding or truncation). | Not Evaluated |  |
| DC1.3 | MUST | FOCUS dataset MUST NOT alter the aggregated values of summable metrics (e.g., costs and quantities) due to the inclusion of custom columns. | Not Evaluated |  |
| DC1.4 | SHOULD | FOCUS dataset SHOULD sort all FOCUS columns alphabetically first, then all custom columns alphabetically second. | Not Evaluated |  |

### Dataset configuration

Defines configuration options for controlling the structure and content of a FOCUS dataset.

Source: [attributes/dataset_configuration.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/dataset_configuration.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| DaC1 | MUST | Dataset conforming to DatasetConfiguration attribute MUST adhere to the following requirements: | Not Evaluated |  |
| DaC1.1 | MUST | FOCUS dataset MUST be configurable to include only a user-defined selection of columns. | Not Evaluated |  |
| DaC1.2 | MUST | FOCUS dataset MUST adhere to all column-level specifications defined in the FOCUS schema, regardless of the user's chosen configuration (e.g., column selection). | Not Evaluated |  |
| DaC1.3 | MAY | FOCUS dataset MAY offer a default column set. | Not Evaluated |  |
| DaC1.4 | MUST | FOCUS dataset default column set MUST include all applicable FOCUS columns when a default column set is offered. | Not Evaluated |  |

### Date/Time format

Rules and formatting requirements for date/time-related columns appearing in a FOCUS dataset.

Source: [attributes/datetime_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/datetime_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| DTF1 | MUST | Column conforming to DateTimeFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| DTF1.1 | MUST | FOCUS dataset column MUST be expressed in UTC (Coordinated Universal Time) to avoid ambiguity and ensure consistency across different time zones. | Not Evaluated |  |
| DTF1.2 | MUST | FOCUS dataset column MUST conform to the ISO 8601 standard, which provides a globally recognized format for representing dates and times (see ISO 8601-1:2019 governing document for details). | Not Evaluated |  |
| DTF1.1 | MUST | When FOCUS dataset column represents a specific moment in time, it MUST adhere to the following requirements: | Not Evaluated |  |
| DTF1.1.1 | MUST | FOCUS dataset column MUST use the extended ISO 8601 format with UTC offset (`YYYY-MM-DDTHH:mm:ssZ`). | Not Evaluated |  |
| DTF1.1.2 | MUST | FOCUS dataset column MUST include both the date and time components, separated with the letter `T`. | Not Evaluated |  |
| DTF1.1.3 | MUST | FOCUS dataset column MUST use two-digit hours (`HH`), minutes (`mm`), and seconds (`ss`). | Not Evaluated |  |
| DTF1.1.4 | MUST | FOCUS dataset column MUST end with the ISO 8601 UTC designator `Z`. | Not Evaluated |  |

### Delivery handling

Defines how a data generator delivers a FOCUS dataset to a customer.

Source: [attributes/delivery_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/delivery_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| DH1 | MUST | Dataset conforming to DeliveryHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| DH1.1 | MUST | FOCUS dataset MUST NOT require practitioners to deduplicate records within or across delivered dataset artifacts. | Not Evaluated |  |
| DH1.1 | MUST | When using Overwrite delivery mechanism, FOCUS dataset MUST adhere to the following additional requirements: | Not Evaluated |  |
| DH1.1.1 | MUST | FOCUS dataset MUST represent a complete snapshot for a given delivery scope. | Not Evaluated |  |
| DH1.1.2 | MUST | FOCUS dataset MUST supersede all previously delivered dataset artifacts for the same delivery scope. | Not Evaluated |  |
| DH1.1.1 | MUST | FOCUS dataset MUST preserve all previously delivered dataset artifacts when using Append delivery mechanism. | Not Evaluated |  |
| DH1.1.2 | SHOULD | FOCUS dataset SHOULD have delivered dataset artifacts accompanied by corresponding FOCUS Metadata. | Not Evaluated |  |
| DH1.1.3 | MUST | FOCUS dataset delivery mechanism documentation MUST adhere to the following requirements: | Not Evaluated |  |
| DH1.1.3.1 | MUST | FOCUS dataset delivery mechanism documentation MUST include the delivery mechanism used (Overwrite or Append). | Not Evaluated |  |
| DH1.1.3.2 | MUST | FOCUS dataset delivery mechanism documentation MUST include the conditions under which each delivery mechanism applies when more than one delivery mechanism is used. | Not Evaluated |  |
| DH1.1.3.3 | MUST | FOCUS dataset delivery mechanism documentation MUST include the mechanism for correlating dataset artifacts with the FOCUS Metadata Schema object when the Metadata is delivered. | Not Evaluated |  |
| DH1.1.3.4 | MUST | FOCUS dataset delivery mechanism documentation MUST be accessible to practitioners. | Not Evaluated |  |

### FOCUS column handling

Naming conventions for FOCUS columns appearing in a FOCUS dataset.

Source: [attributes/focus_column_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/focus_column_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| FCH1 | MUST | Column conforming to FocusColumnHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| FCH1.1 | MUST | FOCUS column MUST use a Display Name consistent with the Column ID, with spaces inserted between words (e.g., Column ID `BillingAccountName` and Display Name `Billing Account Name`, Column ID `BillingAccountId` and Display Name `Billing Account ID`). | Not Evaluated |  |
| FCH1.2 | MUST | FOCUS column MUST use Pascal case in the Column ID. | Not Evaluated |  |
| FCH1.3 | MUST | FOCUS column MUST use only alphanumeric characters in the Column ID. | Not Evaluated |  |
| FCH1.4 | MUST | FOCUS column MUST NOT include special characters in the Column ID. | Not Evaluated |  |
| FCH1.5 | MUST | FOCUS column MUST NOT use abbreviations other than `Id` in the Column ID. | Not Evaluated |  |
| FCH1.6 | SHOULD | FOCUS column SHOULD NOT use acronyms other than `Sku` in the Column ID. | Not Evaluated |  |
| FCH1.7 | SHOULD | FOCUS column SHOULD NOT exceed 50 characters in the Column ID to accommodate column length restrictions of various data repositories. | Not Evaluated |  |
| FCH1.8 | MUST | FOCUS column representing an identifier MUST include the `Id` suffix in the Column ID. | Not Evaluated |  |
| FCH1.9 | MUST | FOCUS column representing a name MUST include the `Name` suffix in the Column ID. | Not Evaluated |  |
| FCH1.10 | MUST | FOCUS column representing a product offering that incurred a charge MUST include `Sku` in the Column ID. | Not Evaluated |  |
| FCH1.11 | MUST | FOCUS column that includes the `Category` suffix in the Column ID and is not null MUST contain one of the FOCUS-defined allowed values. | Not Evaluated |  |

### JSON object format

Rules and formatting requirements for columns appearing in a FOCUS dataset that convey data as complex, hierarchical objects.

Source: [attributes/json_object_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/json_object_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| JOF1 | MUST | Column conforming to JsonObjectFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| JOF1.1 | MUST | FOCUS dataset column MUST contain a serialized JSON string, consistent with the ECMA 404 definition of an object. | Not Evaluated |  |
| JOF1.2 | MUST | FOCUS dataset column MUST conform to all requirements of the corresponding column definition, which may specify or restrict the shape or contents of the object. | Not Evaluated |  |
| JOF1.1 | SHOULD | Object in FOCUS dataset column SHOULD NOT exceed 3 levels of nesting. | Not Evaluated |  |
| JOF1.2 | MUST | Key in Object in FOCUS dataset column MUST be unique. | Not Evaluated |  |
| JOF1.3 | MUST | Key value in Object in FOCUS dataset column MUST be of type number, string, boolean (`true` or `false`), array, object, or `null`. | Not Evaluated |  |
| JOF1.4 | MUST | Object in array in FOCUS dataset column MUST adhere to the following requirements: | Not Evaluated |  |
| JOF1.4.1 | MUST | Object in array in FOCUS dataset column MUST be of a consistent type. | Not Evaluated |  |
| JOF1.4.2 | MUST | Object in array in FOCUS dataset column MUST NOT be repeated. | Not Evaluated |  |
| JOF1.4.3 | MUST | Object in array in FOCUS dataset column MUST NOT be null. | Not Evaluated |  |

### Key-Value format

Rules and formatting requirements for columns appearing in a FOCUS dataset that convey data as key-value pairs.

Source: [attributes/key_value_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/key_value_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| KVF1 | MUST | Column conforming to KeyValueFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| KVF1.1 | MUST | FOCUS dataset column MUST be a serialized JSON string, consistent with the ECMA 404 definition of an object. | Not Evaluated |  |
| KVF1.1 | MUST | Keys in FOCUS dataset column MUST be unique within the object. | Not Evaluated |  |
| KVF1.2 | MUST | Key values in FOCUS dataset column MUST be of type number, string, boolean (`true` or `false`), or `null`. | Not Evaluated |  |
| KVF1.3 | MUST | Key values in FOCUS dataset column MUST NOT be objects or arrays. | Not Evaluated |  |

### Null handling

Indicates how to handle columns that don't have a value.

Source: [attributes/null_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/null_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| NH1 | MUST | Column conforming to NullHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| NH1.1 | MUST | FOCUS dataset column MUST use `null` for absent values when the FOCUS dataset column is defined as nullable. | Not Evaluated |  |
| NH1.2 | MUST | FOCUS dataset column MUST NOT contain empty strings or placeholder strings (e.g., `Not Applicable`) for absent values when the FOCUS dataset column contains string values. | Not Evaluated |  |
| NH1.3 | MUST | FOCUS dataset column MUST NOT contain placeholder numeric values (e.g., `0`) for absent values when the FOCUS dataset column contains numeric values. | Not Evaluated |  |

### Numeric format

Rules and formatting requirements for numeric columns appearing in a FOCUS dataset.

Source: [attributes/numeric_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/numeric_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| NF1 | MUST | Column conforming to NumericFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| NF1.1 | MUST | FOCUS dataset column MUST contain a single numeric value. | Not Evaluated |  |
| NF1.2 | MUST | FOCUS dataset column MUST have values of type integer, decimal, or scientific notation. | Not Evaluated |  |
| NF1.3 | MUST | FOCUS dataset column MUST contain values that, when not null, conform to one of the allowed Data Types defined in the table below. | Not Evaluated |  |
| NF1.4 | MUST | FOCUS dataset column MUST contain values that, when not null, conform to one of the allowed precision levels (and scale, where applicable) defined in the table below. | Not Evaluated |  |
| NF1.5 | MUST | FOCUS dataset column MUST NOT use mathematical symbols, functions, or operators, except for a negative sign (-) to indicate a negative value or a negative exponent in scientific notation. | Not Evaluated |  |
| NF1.6 | MUST | FOCUS dataset column MUST NOT include additional characters or qualifiers (e.g., currency symbols, units of measure). | Not Evaluated |  |
| NF1.7 | MUST | FOCUS dataset column MUST NOT contain commas or punctuation marks, except for a single decimal point when required for a decimal value. | Not Evaluated |  |
| NF1.8 | MUST | FOCUS dataset column MUST use a negative sign (-) to indicate a negative value. | Not Evaluated |  |
| NF1.9 | MUST | FOCUS dataset column MUST NOT include a positive sign (+) for a positive value. | Not Evaluated |  |
| NF1.1 | MUST | When FOCUS dataset column contains numeric values expressed in scientific notation, it MUST adhere to the following requirements: | Not Evaluated |  |
| NF1.1.1 | MUST | FOCUS dataset column MUST use E notation "mEn", where m is a real number and n is an integer exponent. | Not Evaluated |  |
| NF1.1.2 | MUST | FOCUS dataset column MUST use a negative sign (-) to indicate a negative exponent. | Not Evaluated |  |
| NF1.1.3 | MUST | FOCUS dataset column MUST NOT include a positive sign (+) for a positive exponent. | Not Evaluated |  |

### String handling

Requirements for string-capturing columns appearing in a FOCUS dataset.

Source: [attributes/string_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/string_handling.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| SH1 | MUST | Column conforming to StringHandling attribute MUST adhere to the following requirements: | Not Evaluated |  |
| SH1.1 | MUST | FOCUS dataset column MUST preserve the original casing of string values. | Not Evaluated |  |
| SH1.2 | MUST | FOCUS dataset column MUST preserve the original spacing of string values. | Not Evaluated |  |
| SH1.3 | MUST | FOCUS dataset column MUST preserve other relevant consistency factors as specified by the data generator or end-user. | Not Evaluated |  |
| SH1.4 | MUST | FOCUS dataset column MUST remain consistent across all billing periods when the FOCUS dataset column contains immutable string values (e.g., resource identifier, region identifier). | Not Evaluated |  |
| SH1.1 | MUST | When FOCUS dataset column contains mutable string values (e.g., resource name, region name), it MUST adhere to the following requirements: | Not Evaluated |  |
| SH1.1.1 | MUST | FOCUS dataset column MUST reflect the altered value in all records pertaining to a period after the change. | Not Evaluated |  |
| SH1.1.2 | MUST | FOCUS dataset column MUST reflect the string value as it existed prior to the change in all records pertaining to a period prior to the change when the record does not represent a correction to a previously closed billing period. | Not Evaluated |  |
| SH1.1.3 | MAY | FOCUS dataset column MAY reflect the altered value in records pertaining to a period prior to the change when the record represents a correction to a previously closed billing period. | Not Evaluated |  |
| SH1.2 | MUST | When FOCUS dataset column contains not-nullable string values, it MUST adhere to the following requirements: | Not Evaluated |  |
| SH1.2.1 | SHOULD | FOCUS dataset column SHOULD NOT contain empty strings. | Not Evaluated |  |
| SH1.2.2 | SHOULD | FOCUS dataset column SHOULD NOT contain strings consisting solely of whitespace characters. | Not Evaluated |  |

### Unit format

Indicates standards for expressing measurement units in columns appearing in a FOCUS dataset.

Source: [attributes/unit_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/attributes/unit_format.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| UF1 | MUST | Column conforming to UnitFormat attribute MUST adhere to the following requirements: | Not Evaluated |  |
| UF1.1 | MUST | FOCUS dataset column MUST adhere to the following base unit requirements: | Not Evaluated |  |
| UF1.1.1 | MUST | FOCUS dataset column MUST include at least one base unit. | Not Evaluated |  |
| UF1.1.2 | MUST | FOCUS dataset column MUST use one of the allowed data size unit abbreviations listed below for data size base units. | Not Evaluated |  |
| UF1.1.3 | MUST | FOCUS dataset column MUST use the allowed data size unit abbreviations in the same form for both singular and plural units. | Not Evaluated |  |
| UF1.1.4 | MUST | FOCUS dataset column MUST use the allowed abbreviation for exabit, exabyte, exbibit, or exbibyte when representing values exceeding 10^18. | Not Evaluated |  |
| UF1.1.5 | MUST | FOCUS dataset column MUST use the allowed abbreviation for bit or byte when representing values smaller than one byte. | Not Evaluated |  |
| UF1.1.6 | MUST | FOCUS dataset column MUST use one of the allowed time-based unit names listed below for time-based base units. | Not Evaluated |  |
| UF1.1.7 | SHOULD | FOCUS dataset column SHOULD use one of the recommended count-based unit names listed below for count-based base units. | Not Evaluated |  |
| UF1.1.8 | SHOULD | FOCUS dataset column SHOULD use capitalized nouns for base units that do not correspond to any of the allowed base unit names listed below. | Not Evaluated |  |
| UF1.1.9 | MAY | FOCUS dataset column MAY include a count-based base unit that is not listed as one of the allowed values. | Not Evaluated |  |
| UF1.2 | MAY | FOCUS dataset column MAY include a unit quantity expressed as a positive integer. | Not Evaluated |  |
| UF1.3 | MUST | FOCUS dataset column expressing a compound unit MUST use a hyphen (`-`) to separate base units (e.g., `GB-Hours`). | Not Evaluated |  |
| UF1.4 | SHOULD | FOCUS dataset column expressing a compound unit SHOULD use the `<singular-base-unit>-<plural-base-unit>` format (e.g., `GB-Hours`, `MB-Days`, `Request-Tokens`). | Not Evaluated |  |
| UF1.5 | MUST | FOCUS dataset column expressing a ratio unit MUST use a slash (`/`) to separate the numerator and denominator (e.g., `GB/Hour` to signify gigabytes per hour). | Not Evaluated |  |
| UF1.6 | MAY | FOCUS dataset column expressing a ratio unit MAY include a denominator quantity expressed as a positive integer. | Not Evaluated |  |
| UF1.7 | SHOULD | FOCUS dataset column expressing a ratio unit and including a denominator quantity SHOULD use the `<plural-units>/<denominator-quantity> <plural-time-units>` format (e.g., `Units/3 Months`). | Not Evaluated |  |
| UF1.8 | SHOULD | FOCUS dataset column expressing a ratio unit with a compound unit numerator SHOULD use the `<compound-unit>/<singular-time-unit>` format (e.g., `Core-Hours/Day`). | Not Evaluated |  |
| UF1.9 | SHOULD | FOCUS dataset column expressing a ratio unit with a time denominator SHOULD use the `<plural-units>/<singular-time-unit>` format (e.g., `GB/Hour`, `PB/Day`). | Not Evaluated |  |
| UF1.10 | SHOULD | FOCUS dataset column expressing a simple unit SHOULD use the `<plural-units>` format (e.g., `GB`, `Seconds`). | Not Evaluated |  |
| UF1.11 | SHOULD | FOCUS dataset column including a unit quantity SHOULD use the `<unit-quantity> <plural-units>` format (e.g., `1000 Tokens`, `1000 Characters`). | Not Evaluated |  |

<br>

## Datasets

### Billing period

Describes the time intervals and statuses associated with an invoice issuer's billing cycles.

Source: [datasets/billing_period/dataset.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/dataset.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP1 | MUST | BillingPeriod MUST adhere to the following requirements: | Not Evaluated |  |
| BP1.1 | MUST | BillingPeriod MUST be present when the invoice issuer supports payable invoices. | Not Evaluated |  |
| BP1.2 | MUST | The presence of columns in BillingPeriod MUST adhere to the following requirements: | Not Evaluated |  |
| BP1.2.1 | MUST | BillingPeriod MUST include BillingPeriodCreated. | Not Evaluated |  |
| BP1.2.2 | MUST | BillingPeriod MUST include BillingPeriodEnd. | Not Evaluated |  |
| BP1.2.3 | MUST | BillingPeriod MUST include BillingPeriodLastUpdated. | Not Evaluated |  |
| BP1.2.4 | MUST | BillingPeriod MUST include BillingPeriodStart. | Not Evaluated |  |
| BP1.2.5 | MUST | BillingPeriod MUST include BillingPeriodStatus. | Not Evaluated |  |
| BP1.2.6 | MUST | BillingPeriod MUST include InvoiceIssuerName. | Not Evaluated |  |
| BP1.3 | MUST | BillingPeriod MUST conform to CorrectionHandling requirements. | Not Evaluated |  |
| BP1.4 | MUST | BillingPeriod MUST conform to DatasetCompleteness requirements. | Not Evaluated |  |
| BP1.5 | MUST | BillingPeriod MUST conform to DatasetConfiguration requirements. | Not Evaluated |  |
| BP1.6 | MUST | BillingPeriod MUST conform to DeliveryHandling requirements. | Not Evaluated |  |
| BP1.7 | MUST | BillingPeriod FOCUS columns MUST conform to FocusColumnHandling requirements. | Not Evaluated |  |
| BP1.8 | MUST | BillingPeriod FOCUS columns MUST conform to NullHandling requirements. | Not Evaluated |  |
| BP1.9 | MUST | BillingPeriod custom columns MUST conform to CustomColumnHandling requirements. | Not Evaluated |  |

### Contract commitment

Describes the terms of contracts agreed between a service provider and a customer.

Source: [datasets/contract_commitment/dataset.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/dataset.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC1 | MUST | ContractCommitment MUST adhere to the following requirements: | Not Evaluated |  |
| CC1.1 | MUST | ContractCommitment MUST be present when the service provider supports contract commitments. | Not Evaluated |  |
| CC1.2 | MUST | ContractCommitment column presence MUST adhere to the following requirements: | Not Evaluated |  |
| CC1.2.1 | MUST | ContractCommitment MUST include BillingCurrency. | Not Evaluated |  |
| CC1.2.2 | MUST | ContractCommitment MUST include ContractCommitmentApplicability. | Not Evaluated |  |
| CC1.2.3 | MUST | ContractCommitment MUST include ContractCommitmentBenefitCategory. | Not Evaluated |  |
| CC1.2.4 | MUST | ContractCommitment MUST include ContractCommitmentCategory. | Not Evaluated |  |
| CC1.2.5 | MUST | ContractCommitment MUST include ContractCommitmentCost. | Not Evaluated |  |
| CC1.2.6 | MUST | ContractCommitment MUST include ContractCommitmentCreated. | Not Evaluated |  |
| CC1.2.7 | MUST | ContractCommitment MUST include ContractCommitmentDescription. | Not Evaluated |  |
| CC1.2.8 | MUST | ContractCommitment MUST include ContractCommitmentDiscountPercentage. | Not Evaluated |  |
| CC1.2.9 | MUST | ContractCommitment MUST include ContractCommitmentDurationType. | Not Evaluated |  |
| CC1.2.10 | MUST | ContractCommitment MUST include ContractCommitmentFulfillmentInterval. | Not Evaluated |  |
| CC1.2.11 | MUST | ContractCommitment MUST include ContractCommitmentId. | Not Evaluated |  |
| CC1.2.12 | MUST | ContractCommitment MUST include ContractCommitmentLastUpdated. | Not Evaluated |  |
| CC1.2.13 | MUST | ContractCommitment MUST include ContractCommitmentLifecycleStatus. | Not Evaluated |  |
| CC1.2.14 | MUST | ContractCommitment MUST include ContractCommitmentModel. | Not Evaluated |  |
| CC1.2.15 | MUST | ContractCommitment MUST include ContractCommitmentOfferCategory. | Not Evaluated |  |
| CC1.2.16 | MUST | ContractCommitment MUST include ContractCommitmentPaymentInterval. | Not Evaluated |  |
| CC1.2.17 | MUST | ContractCommitment MUST include ContractCommitmentPaymentModel. | Not Evaluated |  |
| CC1.2.18 | MUST | ContractCommitment MUST include ContractCommitmentPaymentUpfrontPercentage when the service provider offers "Partial Upfront" payment models. | Not Evaluated |  |
| CC1.2.19 | MUST | ContractCommitment MUST include ContractCommitmentPeriodEnd. | Not Evaluated |  |
| CC1.2.20 | MUST | ContractCommitment MUST include ContractCommitmentPeriodStart. | Not Evaluated |  |
| CC1.2.21 | MUST | ContractCommitment MUST include ContractCommitmentQuantity. | Not Evaluated |  |
| CC1.2.22 | MUST | ContractCommitment MUST include ContractCommitmentType. | Not Evaluated |  |
| CC1.2.23 | MUST | ContractCommitment MUST include ContractCommitmentUnit. | Not Evaluated |  |
| CC1.2.24 | MUST | ContractCommitment MUST include ContractId. | Not Evaluated |  |
| CC1.2.25 | MUST | ContractCommitment MUST include ContractPeriodEnd. | Not Evaluated |  |
| CC1.2.26 | MUST | ContractCommitment MUST include ContractPeriodStart. | Not Evaluated |  |
| CC1.2.27 | MUST | ContractCommitment MUST include InvoiceIssuerName. | Not Evaluated |  |
| CC1.2.28 | MUST | ContractCommitment MUST include PricingCurrency when the service provider supports pricing and billing in different currencies. | Not Evaluated |  |
| CC1.2.29 | MUST | ContractCommitment MUST include PricingCurrencyContractCommitmentCost when the service provider supports pricing and billing in different currencies. | Not Evaluated |  |
| CC1.2.30 | MUST | ContractCommitment MUST include ServiceProviderName. | Not Evaluated |  |
| CC1.3 | MUST | ContractCommitment MUST conform to CorrectionHandling requirements. | Not Evaluated |  |
| CC1.4 | MUST | ContractCommitment MUST conform to DatasetCompleteness requirements. | Not Evaluated |  |
| CC1.5 | MUST | ContractCommitment MUST conform to DatasetConfiguration requirements. | Not Evaluated |  |
| CC1.6 | MUST | ContractCommitment MUST conform to DeliveryHandling requirements. | Not Evaluated |  |
| CC1.7 | MUST | ContractCommitment FOCUS columns MUST conform to FocusColumnHandling requirements. | Not Evaluated |  |
| CC1.8 | MUST | ContractCommitment FOCUS columns MUST conform to NullHandling requirements. | Not Evaluated |  |
| CC1.9 | MUST | ContractCommitment custom columns MUST conform to CustomColumnHandling requirements. | Not Evaluated |  |

### Cost and usage

Describes the cost and usage incurred through using or purchasing a service provider's resources or services.

Source: [datasets/cost_and_usage/dataset.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/dataset.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CAU1 | MUST | CostAndUsage MUST adhere to the following requirements: | Not Evaluated |  |
| CAU1.1 | MUST | CostAndUsage MUST be present. | Not Evaluated |  |
| CAU1.2 | MUST | CostAndUsage column presence MUST adhere to the following requirements: | Not Evaluated |  |
| CAU1.2.1 | SHOULD | CostAndUsage SHOULD include AllocatedMethodDetails when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.2.2 | MUST | CostAndUsage MUST include AllocatedMethodId when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.2.3 | MUST | CostAndUsage MUST include AllocatedResourceId when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.2.4 | MUST | CostAndUsage MUST include AllocatedResourceName when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.2.5 | MUST | CostAndUsage MUST include AllocatedTags when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.2.6 | SHOULD | CostAndUsage SHOULD include AvailabilityZone when the host provider supports deploying resources or services within an availability zone. | Not Evaluated |  |
| CAU1.2.7 | MUST | CostAndUsage MUST include BilledCost. | Not Evaluated |  |
| CAU1.2.8 | MUST | CostAndUsage MUST include BillingAccountId. | Not Evaluated |  |
| CAU1.2.9 | MUST | CostAndUsage MUST include BillingAccountName. | Not Evaluated |  |
| CAU1.2.10 | MUST | CostAndUsage MUST include BillingAccountType when the invoice issuer supports more than one possible BillingAccountType value. | Not Evaluated |  |
| CAU1.2.11 | MUST | CostAndUsage MUST include BillingCurrency. | Not Evaluated |  |
| CAU1.2.12 | MUST | CostAndUsage MUST include BillingPeriodEnd. | Not Evaluated |  |
| CAU1.2.13 | MUST | CostAndUsage MUST include BillingPeriodStart. | Not Evaluated |  |
| CAU1.2.14 | MUST | CostAndUsage MUST include CapacityReservationId when the service provider supports capacity reservations. | Not Evaluated |  |
| CAU1.2.15 | MUST | CostAndUsage MUST include CapacityReservationStatus when the service provider supports capacity reservations. | Not Evaluated |  |
| CAU1.2.16 | MUST | CostAndUsage MUST include ChargeCategory. | Not Evaluated |  |
| CAU1.2.17 | MUST | CostAndUsage MUST include ChargeClass. | Not Evaluated |  |
| CAU1.2.18 | MUST | CostAndUsage MUST include ChargeDescription. | Not Evaluated |  |
| CAU1.2.19 | SHOULD | CostAndUsage SHOULD include ChargeFrequency. | Not Evaluated |  |
| CAU1.2.20 | MUST | CostAndUsage MUST include ChargePeriodEnd. | Not Evaluated |  |
| CAU1.2.21 | MUST | CostAndUsage MUST include ChargePeriodStart. | Not Evaluated |  |
| CAU1.2.22 | MUST | CostAndUsage MUST include CommitmentDiscountCategory when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.23 | MUST | CostAndUsage MUST include CommitmentDiscountId when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.24 | MUST | CostAndUsage MUST include CommitmentDiscountName when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.25 | MUST | CostAndUsage MUST include CommitmentDiscountQuantity when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.26 | MUST | CostAndUsage MUST include CommitmentDiscountStatus when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.27 | MUST | CostAndUsage MUST include CommitmentDiscountType when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.28 | MUST | CostAndUsage MUST include CommitmentDiscountUnit when the service provider supports commitment discounts. | Not Evaluated |  |
| CAU1.2.29 | MUST | CostAndUsage MUST include CommitmentProgramEligibilityDetails when the service provider supports at least one commitment program. | Not Evaluated |  |
| CAU1.2.30 | MUST | CostAndUsage MUST include ConsumedQuantity when the service provider supports the measurement of usage. | Not Evaluated |  |
| CAU1.2.31 | MUST | CostAndUsage MUST include ConsumedUnit when the service provider supports the measurement of usage. | Not Evaluated |  |
| CAU1.2.32 | MUST | CostAndUsage MUST include ContractApplied when the service provider supports contract commitments. | Not Evaluated |  |
| CAU1.2.33 | MUST | CostAndUsage MUST include ContractedCost. | Not Evaluated |  |
| CAU1.2.34 | MUST | CostAndUsage MUST include ContractedUnitPrice when the service provider supports negotiated pricing concepts. | Not Evaluated |  |
| CAU1.2.35 | MUST | CostAndUsage MUST include EffectiveCost. | Not Evaluated |  |
| CAU1.2.36 | MUST | CostAndUsage MUST include HostProviderName. | Not Evaluated |  |
| CAU1.2.37 | MUST | CostAndUsage MUST include InvoiceDetailId when the invoice issuer supports payable invoices. | Not Evaluated |  |
| CAU1.2.38 | MUST | CostAndUsage MUST include InvoiceId when the invoice issuer supports payable invoices. | Not Evaluated |  |
| CAU1.2.39 | MUST | CostAndUsage MUST include InvoiceIssuerName. | Not Evaluated |  |
| CAU1.2.40 | MUST | CostAndUsage MUST include ListCost. | Not Evaluated |  |
| CAU1.2.41 | MUST | CostAndUsage MUST include ListUnitPrice when the service provider publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.42 | MUST | CostAndUsage MUST include PricingCategory when the service provider supports more than one pricing category across all SKUs. | Not Evaluated |  |
| CAU1.2.43 | MUST | CostAndUsage MUST include PricingCurrency when the service provider supports pricing and billing in different currencies. | Not Evaluated |  |
| CAU1.2.44 | MUST | CostAndUsage MUST adhere to the following PricingCurrencyContractedUnitPrice presence requirements: | Not Evaluated |  |
| CAU1.2.44.1 | MUST | CostAndUsage MUST include PricingCurrencyContractedUnitPrice when the service provider supports prices in virtual currency and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.44.2 | SHOULD | CostAndUsage SHOULD include PricingCurrencyContractedUnitPrice when the service provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.44.3 | MAY | CostAndUsage MAY include PricingCurrencyContractedUnitPrice in all other cases. | Not Evaluated |  |
| CAU1.2.45 | MUST | CostAndUsage MUST adhere to the following PricingCurrencyEffectiveCost presence requirements: | Not Evaluated |  |
| CAU1.2.45.1 | MUST | CostAndUsage MUST include PricingCurrencyEffectiveCost when the service provider supports prices in virtual currency and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.45.2 | SHOULD | CostAndUsage SHOULD include PricingCurrencyEffectiveCost when the service provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.45.3 | MAY | CostAndUsage MAY include PricingCurrencyEffectiveCost in all other cases. | Not Evaluated |  |
| CAU1.2.46 | MUST | CostAndUsage MUST adhere to the following PricingCurrencyListUnitPrice presence requirements: | Not Evaluated |  |
| CAU1.2.46.1 | MUST | CostAndUsage MUST include PricingCurrencyListUnitPrice when the service provider supports prices in virtual currency and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.46.2 | SHOULD | CostAndUsage SHOULD include PricingCurrencyListUnitPrice when the service provider supports pricing and billing in different currencies and publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CAU1.2.46.3 | MAY | CostAndUsage MAY include PricingCurrencyListUnitPrice in all other cases. | Not Evaluated |  |
| CAU1.2.47 | MUST | CostAndUsage MUST include PricingQuantity. | Not Evaluated |  |
| CAU1.2.48 | MUST | CostAndUsage MUST include PricingUnit. | Not Evaluated |  |
| CAU1.2.49 | MUST | CostAndUsage MUST include RegionId when the host provider supports deploying resources or services within a region. | Not Evaluated |  |
| CAU1.2.50 | MUST | CostAndUsage MUST include RegionName when the host provider supports deploying resources or services within a region. | Not Evaluated |  |
| CAU1.2.51 | MUST | CostAndUsage MUST include ResourceId when the service provider supports billing based on provisioned resources. | Not Evaluated |  |
| CAU1.2.52 | MUST | CostAndUsage MUST include ResourceName when the service provider supports billing based on provisioned resources. | Not Evaluated |  |
| CAU1.2.53 | MUST | CostAndUsage MUST include ResourceType when the service provider supports billing based on provisioned resources and supports assigning types to resources. | Not Evaluated |  |
| CAU1.2.54 | MUST | CostAndUsage MUST include ServiceCategory. | Not Evaluated |  |
| CAU1.2.55 | MUST | CostAndUsage MUST include ServiceName. | Not Evaluated |  |
| CAU1.2.56 | MUST | CostAndUsage MUST include ServiceProviderName. | Not Evaluated |  |
| CAU1.2.57 | SHOULD | CostAndUsage SHOULD include ServiceSubcategory. | Not Evaluated |  |
| CAU1.2.58 | MUST | CostAndUsage MUST include SkuId when the service provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Not Evaluated |  |
| CAU1.2.59 | MUST | CostAndUsage MUST include SkuMeter when the service provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Not Evaluated |  |
| CAU1.2.60 | MUST | CostAndUsage MUST include SkuPriceDetails when the service provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Not Evaluated |  |
| CAU1.2.61 | MUST | CostAndUsage MUST include SkuPriceId when the service provider supports unit pricing concepts and publishes price lists, publicly or as part of contracting. | Not Evaluated |  |
| CAU1.2.62 | MUST | CostAndUsage MUST include SubAccountId when the service provider supports a sub account construct. | Not Evaluated |  |
| CAU1.2.63 | MUST | CostAndUsage MUST include SubAccountName when the service provider supports a sub account construct. | Not Evaluated |  |
| CAU1.2.64 | MUST | CostAndUsage MUST include SubAccountType when the service provider supports more than one possible SubAccountType value. | Not Evaluated |  |
| CAU1.2.65 | MUST | CostAndUsage MUST include Tags when the data generator supports setting user or provider-defined tags. | Not Evaluated |  |
| CAU1.2.66 | SHOULD | CostAndUsage SHOULD include custom columns needed to identify all applied discounts when FOCUS columns are not sufficient. | Not Evaluated |  |
| CAU1.3 | MUST | CostAndUsage MUST conform to CorrectionHandling requirements. | Not Evaluated |  |
| CAU1.4 | MUST | CostAndUsage MUST conform to DatasetCompleteness requirements. | Not Evaluated |  |
| CAU1.5 | MUST | CostAndUsage MUST conform to DatasetConfiguration requirements. | Not Evaluated |  |
| CAU1.6 | MUST | CostAndUsage MUST conform to DeliveryHandling requirements. | Not Evaluated |  |
| CAU1.7 | MUST | CostAndUsage MUST include charges representing unused portions of a commitment when the commitment is not fully utilized. | Not Evaluated |  |
| CAU1.8 | MUST | CostAndUsage MUST include separate charges representing discounted and non-discounted portions when a discount applies to only a portion of the originally incurred charge. | Not Evaluated |  |
| CAU1.9 | MUST | When the data generator supports data generator-calculated split cost allocation, CostAndUsage MUST adhere to the following requirements: | Not Evaluated |  |
| CAU1.9.1 | MUST | CostAndUsage MUST have its data generator-calculated split cost allocation method documented and accessible to practitioners. | Not Evaluated |  |
| CAU1.9.2 | SHOULD | CostAndUsage SHOULD offer data generator-calculated split cost allocation on an opt-in basis. | Not Evaluated |  |
| CAU1.9.3 | MAY | CostAndUsage MAY contain records for concepts not related to resource usage, when it aligns with the documented data generator-calculated split cost allocation method. | Not Evaluated |  |
| CAU1.9.4 | MAY | CostAndUsage MAY contain records for unused or unallocated usage from the origin charge as separate allocated charges, when it aligns with the documented data generator-calculated split cost allocation method. | Not Evaluated |  |
| CAU1.9.5 | MAY | CostAndUsage MAY contain allocated charges with apportioned costs for unused or unallocated usage, when it aligns with the documented data generator-calculated split cost allocation method. | Not Evaluated |  |
| CAU1.10 | SHOULD | CostAndUsage SHOULD reflect all applied discounts in charges they pertain to. | Not Evaluated |  |
| CAU1.11 | SHOULD | CostAndUsage SHOULD NOT represent applied discounts as separate negating or offsetting charges. | Not Evaluated |  |
| CAU1.12 | MUST | CostAndUsage FOCUS columns MUST conform to DataGeneratorCalculatedSplitCostAllocationHandling requirements when the data generator supports data generator-calculated split cost allocation. | Not Evaluated |  |
| CAU1.13 | MUST | CostAndUsage FOCUS columns MUST conform to FocusColumnHandling requirements. | Not Evaluated |  |
| CAU1.14 | MUST | CostAndUsage FOCUS columns MUST conform to NullHandling requirements. | Not Evaluated |  |
| CAU1.15 | MUST | CostAndUsage custom columns MUST conform to CustomColumnHandling requirements. | Not Evaluated |  |

### Invoice detail

The financial record of charges as they appear on invoices provided by an invoice issuer.

Source: [datasets/invoice_detail/dataset.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/dataset.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID1 | MUST | InvoiceDetail MUST adhere to the following requirements: | Not Evaluated |  |
| ID1.1 | MUST | InvoiceDetail MUST be present when the invoice issuer supports payable invoices. | Not Evaluated |  |
| ID1.2 | MUST | The presence of columns in InvoiceDetail MUST adhere to the following requirements: | Not Evaluated |  |
| ID1.2.1 | MUST | InvoiceDetail MUST include BilledCost. | Not Evaluated |  |
| ID1.2.2 | MUST | InvoiceDetail MUST include BillingAccountId. | Not Evaluated |  |
| ID1.2.3 | MUST | InvoiceDetail MUST include BillingCurrency. | Not Evaluated |  |
| ID1.2.4 | MUST | InvoiceDetail MUST include BillingPeriodEnd. | Not Evaluated |  |
| ID1.2.5 | MUST | InvoiceDetail MUST include BillingPeriodStart. | Not Evaluated |  |
| ID1.2.6 | MUST | InvoiceDetail MUST include ChargeCategory. | Not Evaluated |  |
| ID1.2.7 | MUST | InvoiceDetail MUST include InvoiceDetailCreated. | Not Evaluated |  |
| ID1.2.8 | MUST | InvoiceDetail MUST include InvoiceDetailDescription. | Not Evaluated |  |
| ID1.2.9 | MUST | InvoiceDetail MUST include InvoiceDetailGrain. | Not Evaluated |  |
| ID1.2.10 | MUST | InvoiceDetail MUST include InvoiceDetailId. | Not Evaluated |  |
| ID1.2.11 | MUST | InvoiceDetail MUST include InvoiceDetailLastUpdated. | Not Evaluated |  |
| ID1.2.12 | MUST | InvoiceDetail MUST include InvoiceId. | Not Evaluated |  |
| ID1.2.13 | MUST | InvoiceDetail MUST include InvoiceIssueDate. | Not Evaluated |  |
| ID1.2.14 | MUST | InvoiceDetail MUST include InvoiceIssueStatus. | Not Evaluated |  |
| ID1.2.15 | MUST | InvoiceDetail MUST include InvoiceIssuerName. | Not Evaluated |  |
| ID1.2.16 | MUST | InvoiceDetail MUST include PaymentCurrency when the invoice issuer supports billing and payment in different currencies. | Not Evaluated |  |
| ID1.2.17 | MUST | InvoiceDetail MUST include PaymentCurrencyBilledCost when the invoice issuer supports billing and payment in different currencies. | Not Evaluated |  |
| ID1.2.18 | MUST | InvoiceDetail MUST include PaymentCurrencyInvoiceDetailId when the invoice issuer represents billing currency and payment currency at different aggregation levels on payable invoices. | Not Evaluated |  |
| ID1.2.19 | MUST | InvoiceDetail MUST include PaymentDueDate. | Not Evaluated |  |
| ID1.2.20 | MUST | InvoiceDetail MUST include PaymentTerms. | Not Evaluated |  |
| ID1.2.21 | MUST | InvoiceDetail MUST include PurchaseOrderNumber when the invoice issuer supports customer input of purchase order numbers. | Not Evaluated |  |
| ID1.2.22 | MUST | InvoiceDetail MUST include ReferenceInvoiceId. | Not Evaluated |  |
| ID1.2.23 | MUST | InvoiceDetail MUST include custom columns to represent any monetary metric that appears on an invoice issued to a BillingAccountId when there is no equivalent FOCUS column. | Not Evaluated |  |
| ID1.3 | MUST | InvoiceDetail MUST conform to CorrectionHandling requirements. | Not Evaluated |  |
| ID1.4 | MUST | InvoiceDetail MUST conform to DatasetCompleteness requirements. | Not Evaluated |  |
| ID1.5 | MUST | InvoiceDetail MUST conform to DatasetConfiguration requirements. | Not Evaluated |  |
| ID1.6 | MUST | InvoiceDetail MUST conform to DeliveryHandling requirements. | Not Evaluated |  |
| ID1.7 | MUST | InvoiceDetail MUST represent all invoice line items with a non-zero BilledCost on any invoice associated with a BillingAccountId. | Not Evaluated |  |
| ID1.8 | MUST | InvoiceDetail FOCUS columns MUST conform to FocusColumnHandling requirements. | Not Evaluated |  |
| ID1.9 | MUST | InvoiceDetail FOCUS columns MUST conform to NullHandling requirements. | Not Evaluated |  |
| ID1.10 | MUST | InvoiceDetail custom columns MUST conform to CustomColumnHandling requirements. | Not Evaluated |  |
| ID1.11 | MUST | InvoiceDetail documentation MUST adhere to the following requirements: | Not Evaluated |  |
| ID1.11.1 | MUST | InvoiceDetail documentation MUST specify how InvoiceDetail records correspond to invoice line items. | Not Evaluated |  |
| ID1.11.2 | MUST | InvoiceDetail documentation MUST specify whether invoice line items with BilledCost of 0 are excluded from InvoiceDetail. | Not Evaluated |  |
| ID1.11.3 | MUST | InvoiceDetail documentation MUST describe how columns in the CostAndUsage and InvoiceDetail dataset instances represent the invoice issuer's invoice reconciliation process. | Not Evaluated |  |
| ID1.11.4 | MUST | InvoiceDetail documentation MUST be freely accessible to FOCUS consumers. | Not Evaluated |  |

<br>

## Columns

### Billing period created (Billing period)

The timestamp when the Billing Period record was first created.

Source: [datasets/billing_period/columns/billingperiodcreated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/billingperiodcreated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-BPC1 | MUST | BillingPeriodCreated MUST adhere to the following requirements: | Not Evaluated |  |
| BP-BPC1.1 | MUST | BillingPeriodCreated MUST be of type Date/Time. | Not Evaluated |  |
| BP-BPC1.2 | MUST | BillingPeriodCreated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| BP-BPC1.3 | MUST | BillingPeriodCreated MUST NOT be null. | Not Evaluated |  |
| BP-BPC1.4 | MUST | BillingPeriodCreated MUST represent the moment in time the Billing Period record was instantiated. | Not Evaluated |  |

### Billing period end (Billing period)

The exclusive end bound of a billing period.

Source: [datasets/billing_period/columns/billingperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/billingperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-BPE1 | MUST | BillingPeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| BP-BPE1.1 | MUST | BillingPeriodEnd MUST be of type Date/Time. | Not Evaluated |  |
| BP-BPE1.2 | MUST | BillingPeriodEnd MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| BP-BPE1.3 | MUST | BillingPeriodEnd MUST NOT be null. | Not Evaluated |  |
| BP-BPE1.4 | MUST | BillingPeriodEnd MUST be the exclusive end bound of the billing period. | Not Evaluated |  |

### Billing period last updated (Billing period)

The timestamp when the Billing Period record was last updated.

Source: [datasets/billing_period/columns/billingperiodlastupdated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/billingperiodlastupdated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-BPLU1 | MUST | BillingPeriodLastUpdated MUST adhere to the following requirements: | Not Evaluated |  |
| BP-BPLU1.1 | MUST | BillingPeriodLastUpdated MUST be of type Date/Time. | Not Evaluated |  |
| BP-BPLU1.2 | MUST | BillingPeriodLastUpdated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| BP-BPLU1.3 | MUST | BillingPeriodLastUpdated MUST NOT be null. | Not Evaluated |  |
| BP-BPLU1.4 | MUST | BillingPeriodLastUpdated MUST represent the most recent moment in time when any column value of the Billing Period record was created or modified. | Not Evaluated |  |
| BP-BPLU1.5 | MUST | BillingPeriodLastUpdated MUST be greater than or equal to BillingPeriodCreated. | Not Evaluated |  |

### Billing period start (Billing period)

The inclusive start bound of a billing period.

Source: [datasets/billing_period/columns/billingperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/billingperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-BPS1 | MUST | BillingPeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| BP-BPS1.1 | MUST | BillingPeriodStart MUST be of type Date/Time. | Not Evaluated |  |
| BP-BPS1.2 | MUST | BillingPeriodStart MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| BP-BPS1.3 | MUST | BillingPeriodStart MUST NOT be null. | Not Evaluated |  |
| BP-BPS1.4 | MUST | BillingPeriodStart MUST be the inclusive start bound of the billing period. | Not Evaluated |  |

### Billing period status (Billing period)

The state of the billing period (i.e., "Open" or "Closed"), indicating whether the delivered data for the period is preliminary, or if all anticipated invoices have been issued and the delivered data is finalized.

Source: [datasets/billing_period/columns/billingperiodstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/billingperiodstatus.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-BiPS1 | MUST | BillingPeriodStatus MUST adhere to the following requirements: | Not Evaluated |  |
| BP-BiPS1.1 | MUST | BillingPeriodStatus MUST be of type String. | Not Evaluated |  |
| BP-BiPS1.2 | MUST | BillingPeriodStatus MUST NOT be null. | Not Evaluated |  |
| BP-BiPS1.3 | MUST | BillingPeriodStatus MUST be one of the allowed values. | Not Evaluated |  |
| BP-BiPS1.4 | MUST | BillingPeriodStatus MUST represent the state of the billing period identified by BillingPeriodStart and BillingPeriodEnd. | Not Evaluated |  |
| BP-BiPS1.5 | MUST | BillingPeriodStatus MUST NOT be "Open" following a previous status of "Closed", except when explicitly requested or approved by the customer. | Not Evaluated |  |

### Invoice issuer name (Billing period)

The name of the entity responsible for invoicing for the resources or services consumed.

Source: [datasets/billing_period/columns/invoiceissuername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/billing_period/columns/invoiceissuername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| BP-IIN1 | MUST | InvoiceIssuerName MUST adhere to the following requirements: | Not Evaluated |  |
| BP-IIN1.1 | MUST | InvoiceIssuerName MUST be of type String. | Not Evaluated |  |
| BP-IIN1.2 | MUST | InvoiceIssuerName MUST conform to StringHandling requirements. | Not Evaluated |  |
| BP-IIN1.3 | MUST | InvoiceIssuerName MUST NOT be null. | Not Evaluated |  |
| BP-IIN1.4 | MUST | InvoiceIssuerName MUST represent the entity that issues invoices. | Not Evaluated |  |

### Billing currency (Contract commitment)

Represents the currency of a contract commitment.

Source: [datasets/contract_commitment/columns/billingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/billingcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-BC1 | MUST | BillingCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| CC-BC1.1 | MUST | BillingCurrency MUST be of type String. | Not Evaluated |  |
| CC-BC1.2 | MUST | BillingCurrency MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-BC1.3 | MUST | BillingCurrency MUST conform to CurrencyFormat requirements. | Not Evaluated |  |
| CC-BC1.4 | MUST | BillingCurrency MUST NOT be null when ContractCommitmentCategory is "Spend". | Not Evaluated |  |
| CC-BC1.5 | MUST | BillingCurrency MUST match the currency used in the invoice generated by the invoice issuer. | Not Evaluated |  |
| CC-BC1.6 | MUST | BillingCurrency MUST be expressed in national currency (e.g., USD, EUR). | Not Evaluated |  |

### Contract commitment applicability (Contract commitment)

A structured definition of the specific entities to which a contract commitment applies, including inclusion/exclusion logic and applicability percentages.

Source: [datasets/contract_commitment/columns/contractcommitmentapplicability.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentapplicability.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCA1 | MUST | ContractCommitmentApplicability MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCA1.1 | MUST | ContractCommitmentApplicability MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CC-CCA1.2 | MUST | ContractCommitmentApplicability MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCA1.3 | MUST | ContractCommitmentApplicability MUST conform to JsonObjectFormat requirements. | Not Evaluated |  |
| CC-CCA1.4 | MUST | ContractCommitmentApplicability MUST conform to ContractCommitmentApplicabilityObject requirements. | Not Evaluated |  |
| CC-CCA1.5 | MUST | ContractCommitmentApplicability MUST NOT be null. | Not Evaluated |  |
| CC-CCA2 | MUST | ContractCommitmentApplicabilityObject MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCA2.1 | MUST | ContractCommitmentApplicabilityObject MUST conform to the ContractCommitmentApplicabilityObjectSchema JSON Schema. | Not Evaluated |  |
| CC-CCA2.2 | MUST | ContractCommitmentApplicabilityObject.IsGlobalScope MUST be `true` when the contract commitment applies to all entities. | Not Evaluated |  |
| CC-CCA2.3 | MUST | ContractCommitmentApplicabilityObject.IsComplexScope MUST be `true` when the contract commitment's applicability logic exceeds schema capabilities. | Not Evaluated |  |
| CC-CCA2.4 | MUST | ContractCommitmentApplicabilityObject.Applicability.Cost MUST represent the fraction of an eligible charge's cost that is applicable to the commitment (0.0 to 1.0). | Not Evaluated |  |
| CC-CCA2.5 | MUST | ContractCommitmentApplicabilityObject.Applicability.Usage MUST represent the fraction of an eligible charge's usage that is applicable to the commitment (0.0 to 1.0). | Not Evaluated |  |
| CC-CCA2.6 | MUST | ContractCommitmentApplicabilityObject.Inclusions[\].Applicability.Cost MUST represent the fraction of an eligible charge's cost that is applicable to the commitment (0.0 to 1.0). | Not Evaluated |  |
| CC-CCA2.7 | MUST | ContractCommitmentApplicabilityObject.Inclusions[\].Applicability.Usage MUST represent the fraction of an eligible charge's usage that is applicable to the commitment (0.0 to 1.0). | Not Evaluated |  |
| CC-CCA2.8 | SHOULD | ContractCommitmentApplicabilityObject.Inclusions[\].Dimension SHOULD represent a column in Cost and Usage. | Not Evaluated |  |
| CC-CCA2.9 | SHOULD | ContractCommitmentApplicabilityObject.Exclusions[\].Dimension SHOULD represent a column in Cost and Usage. | Not Evaluated |  |
| CC-CCA2.10 | MUST | ContractCommitmentApplicabilityObject.Inclusions[\].Values MUST contain only the single string "" when the wildcard is present. | Not Evaluated |  |
| CC-CCA2.11 | MUST | ContractCommitmentApplicabilityObject.Exclusions[\].Values MUST contain only the single string "" when the wildcard is present. | Not Evaluated |  |

### Contract commitment benefit category (Contract commitment)

Defines the primary value or advantage received for a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentbenefitcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentbenefitcategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCBC1 | MUST | ContractCommitmentBenefitCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCBC1.1 | MUST | ContractCommitmentBenefitCategory MUST be of type String. | Not Evaluated |  |
| CC-CCBC1.2 | MUST | ContractCommitmentBenefitCategory MUST NOT be null. | Not Evaluated |  |
| CC-CCBC1.3 | MUST | ContractCommitmentBenefitCategory MUST be one of the allowed values. | Not Evaluated |  |

### Contract commitment category (Contract commitment)

Represents the highest-level classification of a contract commitment based on the nature of how it is applied to a charge.

Source: [datasets/contract_commitment/columns/contractcommitmentcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentcategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCC1 | MUST | ContractCommitmentCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCC1.1 | MUST | ContractCommitmentCategory MUST be of type String. | Not Evaluated |  |
| CC-CCC1.2 | MUST | ContractCommitmentCategory MUST NOT be null. | Not Evaluated |  |
| CC-CCC1.3 | MUST | ContractCommitmentCategory MUST be one of the allowed values. | Not Evaluated |  |

### Contract commitment cost (Contract commitment)

The monetary value of the contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CoCC1 | MUST | ContractCommitmentCost MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CoCC1.1 | MUST | ContractCommitmentCost MUST be of type Decimal. | Not Evaluated |  |
| CC-CoCC1.2 | MUST | ContractCommitmentCost MUST conform to NumericFormat requirements. | Not Evaluated |  |
| CC-CoCC1.3 | MUST | ContractCommitmentCost MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CC-CoCC1.3.1 | MUST | ContractCommitmentCost MUST NOT be null when ContractCommitmentCategory is "Spend". | Not Evaluated |  |
| CC-CoCC1.3.2 | MAY | ContractCommitmentCost MAY be null when ContractCommitmentCategory is "Usage". | Not Evaluated |  |
| CC-CoCC1.4 | MUST | ContractCommitmentCost MUST be denominated in the BillingCurrency. | Not Evaluated |  |

### Contract commitment created (Contract commitment)

The timestamp when the contract commitment record was first created.

Source: [datasets/contract_commitment/columns/contractcommitmentcreated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentcreated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCoC1 | MUST | ContractCommitmentCreated MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCoC1.1 | MUST | ContractCommitmentCreated MUST be of type Date/Time. | Not Evaluated |  |
| CC-CCoC1.2 | MUST | ContractCommitmentCreated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CCoC1.3 | MUST | ContractCommitmentCreated MUST NOT be null. | Not Evaluated |  |
| CC-CCoC1.4 | MUST | ContractCommitmentCreated MUST represent the moment in time the Contract Commitment record was instantiated. | Not Evaluated |  |

### Contract commitment description (Contract commitment)

The self-contained summary of the contract commitment's terms.

Source: [datasets/contract_commitment/columns/contractcommitmentdescription.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentdescription.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCD1 | MUST | ContractCommitmentDescription MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCD1.1 | MUST | ContractCommitmentDescription MUST be of type String. | Not Evaluated |  |
| CC-CCD1.2 | MUST | ContractCommitmentDescription MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCD1.3 | SHOULD | ContractCommitmentDescription SHOULD NOT be null. | Not Evaluated |  |
| CC-CCD1.4 | SHOULD | ContractCommitmentDescription maximum length SHOULD be provided in the corresponding FOCUS Metadata Schema. | Not Evaluated |  |

### Contract commitment discount percentage (Contract commitment)

The effective percentage reduction applied to the list price of resources or services covered by a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentdiscountpercentage.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentdiscountpercentage.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCDP1 | MUST | ContractCommitmentDiscountPercentage MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCDP1.1 | MUST | ContractCommitmentDiscountPercentage MUST be of type Decimal. | Not Evaluated |  |
| CC-CCDP1.2 | MUST | ContractCommitmentDiscountPercentage MUST conform to NumericFormat requirements. | Not Evaluated |  |
| CC-CCDP1.3 | MUST | ContractCommitmentDiscountPercentage MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CC-CCDP1.3.1 | MUST | ContractCommitmentDiscountPercentage MUST NOT be null when ContractCommitmentBenefitCategory is "Discount". | Not Evaluated |  |
| CC-CCDP1.3.2 | MUST | ContractCommitmentDiscountPercentage MUST be null when ContractCommitmentBenefitCategory is "Availability". | Not Evaluated |  |
| CC-CCDP1.4 | MUST | ContractCommitmentDiscountPercentage MUST be a value between 0.0 and 1.0, inclusive. | Not Evaluated |  |
| CC-CCDP1.5 | MUST | For contracts with multiple tiers (e.g., 5% discount up to 1M, 10% above 1M), ContractCommitmentDiscountPercentage MUST adhere to the following additional requirements: | Not Evaluated |  |
| CC-CCDP1.5.1 | MUST | ContractCommitmentDiscountPercentage MUST reflect the discount percentage defined for the specific pricing tier represented by the Contract Commitment row. | Not Evaluated |  |
| CC-CCDP1.5.2 | MUST | ContractCommitmentDiscountPercentage MUST correspond to only one pricing tier per Contract Commitment row. | Not Evaluated |  |
| CC-CCDP1.6 | SHOULD | ContractCommitmentDiscountPercentage SHOULD represent the net effective discount when multiple contractual layers are applicable (e.g., a negotiated discount on top of a standard commitment). | Not Evaluated |  |

### Contract commitment duration type (Contract commitment)

Represents the categorical length of the contract commitment offering.

Source: [datasets/contract_commitment/columns/contractcommitmentdurationtype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentdurationtype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCDT1 | MUST | ContractCommitmentDurationType MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCDT1.1 | MUST | ContractCommitmentDurationType MUST be of type String. | Not Evaluated |  |
| CC-CCDT1.2 | MUST | ContractCommitmentDurationType MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCDT1.3 | MUST | ContractCommitmentDurationType MUST NOT be null. | Not Evaluated |  |
| CC-CCDT1.4 | SHOULD | ContractCommitmentDurationType SHOULD be expressed with a quantity and time unit, where quantity is a positive integer, and time-unit is a standardized unit of time, either singular or plural (e.g., "1 Day", "1 Year", "3 Months", "3 Years"). | Not Evaluated |  |
| CC-CCDT1.5 | SHOULD | ContractCommitmentDurationType SHOULD present the unit of time as one of the allowed values. | Not Evaluated |  |
| CC-CCDT1.6 | SHOULD | ContractCommitmentDurationType SHOULD correspond to the standard duration of the purchased offering (e.g., "1 Year", "3 Years") rather than a precise calculation of days or hours. | Not Evaluated |  |
| CC-CCDT1.7 | MAY | ContractCommitmentDurationType MAY differ from the actual duration calculated between ContractCommitmentPeriodStart and ContractCommitmentPeriodEnd (e.g., if a 3-year commitment is exchanged in its final month, the resulting record may have a short lifespan but retains a value of "3 Years"). | Not Evaluated |  |

### Contract commitment fulfillment interval (Contract commitment)

Represents the specific period used to measure and reset the fulfillment of a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentfulfillmentinterval.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentfulfillmentinterval.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCFI1 | MUST | ContractCommitmentFulfillmentInterval MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCFI1.1 | MUST | ContractCommitmentFulfillmentInterval MUST be of type String. | Not Evaluated |  |
| CC-CCFI1.2 | MUST | ContractCommitmentFulfillmentInterval MUST NOT be null. | Not Evaluated |  |
| CC-CCFI1.3 | MUST | ContractCommitmentFulfillmentInterval MUST be one of the allowed values. | Not Evaluated |  |
| CC-CCFI1.4 | MUST | ContractCommitmentFulfillmentInterval MUST NOT be "Full Period" when ContractCommitmentModel is "Continuous". | Not Evaluated |  |

### Contract commitment ID (Contract commitment)

A service-provider-assigned identifier describing a single contract term agreed between a service provider and a customer.

Source: [datasets/contract_commitment/columns/contractcommitmentid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCI1 | MUST | ContractCommitmentId MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCI1.1 | MUST | ContractCommitmentId MUST be of type String. | Not Evaluated |  |
| CC-CCI1.2 | MUST | ContractCommitmentId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCI1.3 | MUST | ContractCommitmentId MUST NOT be null. | Not Evaluated |  |
| CC-CCI1.4 | MUST | ContractCommitmentId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CC-CCI1.5 | SHOULD | ContractCommitmentId SHOULD be a fully-qualified identifier. | Not Evaluated |  |
| CC-CCI1.6 | MUST | ContractCommitmentId MUST have one and only one parent ContractId. | Not Evaluated |  |
| CC-CCI1.7 | MAY | ContractCommitmentId MAY match ContractId. | Not Evaluated |  |

### Contract commitment last updated (Contract commitment)

The timestamp when the contract commitment record was last updated.

Source: [datasets/contract_commitment/columns/contractcommitmentlastupdated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentlastupdated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCLU1 | MUST | ContractCommitmentLastUpdated MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCLU1.1 | MUST | ContractCommitmentLastUpdated MUST be of type Date/Time. | Not Evaluated |  |
| CC-CCLU1.2 | MUST | ContractCommitmentLastUpdated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CCLU1.3 | MUST | ContractCommitmentLastUpdated MUST NOT be null. | Not Evaluated |  |
| CC-CCLU1.4 | MUST | ContractCommitmentLastUpdated MUST represent the most recent moment in time when any column value of the Contract Commitment record was created or modified. | Not Evaluated |  |
| CC-CCLU1.5 | MUST | ContractCommitmentLastUpdated MUST be greater than or equal to ContractCommitmentCreated. | Not Evaluated |  |

### Contract commitment lifecycle status (Contract commitment)

The current lifecycle state of a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentlifecyclestatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentlifecyclestatus.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCLS1 | MUST | ContractCommitmentLifecycleStatus MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCLS1.1 | MUST | ContractCommitmentLifecycleStatus MUST be of type String. | Not Evaluated |  |
| CC-CCLS1.2 | MUST | ContractCommitmentLifecycleStatus MUST NOT be null. | Not Evaluated |  |
| CC-CCLS1.3 | MUST | ContractCommitmentLifecycleStatus MUST be one of the allowed values. | Not Evaluated |  |
| CC-CCLS1.4 | MUST | When a contract commitment record is modified in a way that requires a new ContractCommitmentID, ContractCommitmentLifecycleStatus for the previous record MUST be "Superseded". | Not Evaluated |  |

### Contract commitment model (Contract commitment)

Represents the operational behavior and consumption flexibility of a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentmodel.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentmodel.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCM1 | MUST | ContractCommitmentModel MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCM1.1 | MUST | ContractCommitmentModel MUST be of type String. | Not Evaluated |  |
| CC-CCM1.2 | MUST | ContractCommitmentModel MUST NOT be null. | Not Evaluated |  |
| CC-CCM1.3 | MUST | ContractCommitmentModel MUST be one of the allowed values. | Not Evaluated |  |
| CC-CCM1.4 | MUST | ContractCommitmentModel MUST be "Discontinuous" when ContractCommitmentFulfillmentInterval is "Full Period". | Not Evaluated |  |

### Contract commitment offer category (Contract commitment)

Indicates whether the pricing and terms of a contract commitment are based on a standard, publicly accessible offering or have been specifically brokered through private negotiation.

Source: [datasets/contract_commitment/columns/contractcommitmentoffercategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentoffercategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CoCOC1 | MUST | ContractCommitmentOfferCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CoCOC1.1 | MUST | ContractCommitmentOfferCategory MUST be of type String. | Not Evaluated |  |
| CC-CoCOC1.2 | MUST | ContractCommitmentOfferCategory MUST NOT be null. | Not Evaluated |  |
| CC-CoCOC1.3 | MUST | ContractCommitmentOfferCategory MUST be one of the allowed values. | Not Evaluated |  |

### Contract commitment payment interval (Contract commitment)

Represents the frequency by which a contract commitment is invoiced.

Source: [datasets/contract_commitment/columns/contractcommitmentpaymentinterval.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentpaymentinterval.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCPI1 | MUST | ContractCommitmentPaymentInterval MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCPI1.1 | MUST | ContractCommitmentPaymentInterval MUST be of type String. | Not Evaluated |  |
| CC-CCPI1.2 | MUST | ContractCommitmentPaymentInterval MUST NOT be null. | Not Evaluated |  |
| CC-CCPI1.3 | MUST | ContractCommitmentPaymentInterval MUST be one of the allowed values. | Not Evaluated |  |
| CC-CCPI1.4 | MUST | ContractCommitmentPaymentInterval MUST be "One-Time" when ContractCommitmentPaymentModel is "All Upfront". | Not Evaluated |  |
| CC-CCPI1.5 | SHOULD | ContractCommitmentPaymentInterval SHOULD represent a time granularity equal to or lesser than the time granularity represented by ContractCommitmentDurationType. | Not Evaluated |  |

### Contract commitment payment model (Contract commitment)

Defines the financial settlement structure of a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentpaymentmodel.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentpaymentmodel.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCPM1 | MUST | ContractCommitmentPaymentModel MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCPM1.1 | MUST | ContractCommitmentPaymentModel MUST be of type String. | Not Evaluated |  |
| CC-CCPM1.2 | MUST | ContractCommitmentPaymentModel MUST NOT be null. | Not Evaluated |  |
| CC-CCPM1.3 | MUST | ContractCommitmentPaymentModel MUST be one of the allowed values. | Not Evaluated |  |

### Contract commitment payment upfront percentage (Contract commitment)

Represents the portion of the total Contract Commitment Cost paid at the start of the duration of a contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentpaymentupfrontpercentage.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentpaymentupfrontpercentage.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCPUP1 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCPUP1.1 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST be of type Decimal. | Not Evaluated |  |
| CC-CCPUP1.2 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST conform to NumericFormat requirements. | Not Evaluated |  |
| CC-CCPUP1.3 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST NOT be null. | Not Evaluated |  |
| CC-CCPUP1.4 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST be a value between 0.0 and 1.0, inclusive. | Not Evaluated |  |
| CC-CCPUP1.5 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST be 1.0 when ContractCommitmentPaymentModel is "All Upfront". | Not Evaluated |  |
| CC-CCPUP1.6 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST be 0.0 when ContractCommitmentPaymentModel is "No Upfront". | Not Evaluated |  |
| CC-CCPUP1.7 | MUST | ContractCommitmentPaymentUpfrontPercentage MUST be greater than 0.0 and less than 1.0 when ContractCommitmentPaymentModel is "Partial Upfront". | Not Evaluated |  |

### Contract commitment period end (Contract commitment)

The exclusive end bound of a contract commitment period.

Source: [datasets/contract_commitment/columns/contractcommitmentperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCPE1 | MUST | ContractCommitmentPeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCPE1.1 | MUST | ContractCommitmentPeriodEnd MUST be of type Date/Time. | Not Evaluated |  |
| CC-CCPE1.2 | MUST | ContractCommitmentPeriodEnd MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CCPE1.3 | MUST | ContractCommitmentPeriodEnd MUST NOT be null. | Not Evaluated |  |
| CC-CCPE1.4 | MUST | ContractCommitmentPeriodEnd MUST be the exclusive end bound of the effective period of the contract commitment. | Not Evaluated |  |

### Contract commitment period start (Contract commitment)

The inclusive start bound of a contract commitment period.

Source: [datasets/contract_commitment/columns/contractcommitmentperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCPS1 | MUST | ContractCommitmentPeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCPS1.1 | MUST | ContractCommitmentPeriodStart MUST be of type Date/Time. | Not Evaluated |  |
| CC-CCPS1.2 | MUST | ContractCommitmentPeriodStart MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CCPS1.3 | MUST | ContractCommitmentPeriodStart MUST NOT be null. | Not Evaluated |  |
| CC-CCPS1.4 | MUST | ContractCommitmentPeriodStart MUST be the inclusive start bound of the effective period of the contract commitment. | Not Evaluated |  |

### Contract commitment quantity (Contract commitment)

The amount associated with the contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmentquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentquantity.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCQ1 | MUST | ContractCommitmentQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCQ1.1 | MUST | ContractCommitmentQuantity MUST be of type Decimal. | Not Evaluated |  |
| CC-CCQ1.2 | MUST | ContractCommitmentQuantity MUST conform to NumericFormat requirements. | Not Evaluated |  |
| CC-CCQ1.3 | MUST | ContractCommitmentQuantity MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CC-CCQ1.3.1 | MUST | ContractCommitmentQuantity MUST NOT be null when ContractCommitmentCategory is "Usage". | Not Evaluated |  |
| CC-CCQ1.3.2 | MAY | ContractCommitmentQuantity MAY be null when ContractCommitmentCategory is "Spend". | Not Evaluated |  |

### Contract commitment type (Contract commitment)

A service-provider-assigned name to identify the type of contract commitment.

Source: [datasets/contract_commitment/columns/contractcommitmenttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmenttype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCT1 | MUST | ContractCommitmentType MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCT1.1 | MUST | ContractCommitmentType MUST be of type String. | Not Evaluated |  |
| CC-CCT1.2 | MUST | ContractCommitmentType MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCT1.3 | MUST | ContractCommitmentType MUST NOT be null. | Not Evaluated |  |
| CC-CCT1.4 | MUST | ContractCommitmentType MUST be a consistent, readable display value. | Not Evaluated |  |

### Contract commitment unit (Contract commitment)

A service-provider-specified measurement unit for the amount declared in Contract Commitment Quantity.

Source: [datasets/contract_commitment/columns/contractcommitmentunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractcommitmentunit.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CCU1 | MUST | ContractCommitmentUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CCU1.1 | MUST | ContractCommitmentUnit MUST be of type String. | Not Evaluated |  |
| CC-CCU1.2 | MUST | ContractCommitmentUnit MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CCU1.3 | SHOULD | ContractCommitmentUnit SHOULD conform to UnitFormat requirements. | Not Evaluated |  |
| CC-CCU1.4 | MUST | ContractCommitmentUnit MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CC-CCU1.4.1 | MUST | ContractCommitmentUnit MUST be null when ContractCommitmentQuantity is null. | Not Evaluated |  |
| CC-CCU1.4.2 | MUST | ContractCommitmentUnit MUST NOT be null when ContractCommitmentQuantity is not null. | Not Evaluated |  |

### Contract ID (Contract commitment)

A service-provider-assigned identifier for a contract describing the agreed terms between a service provider and a customer.

Source: [datasets/contract_commitment/columns/contractid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CI1 | MUST | ContractId MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CI1.1 | MUST | ContractId MUST be of type String. | Not Evaluated |  |
| CC-CI1.2 | MUST | ContractId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-CI1.3 | MUST | ContractId MUST NOT be null. | Not Evaluated |  |
| CC-CI1.4 | MUST | When ContractId is not null, ContractId MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CI1.4.1 | MUST | ContractId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CC-CI1.4.2 | SHOULD | ContractId SHOULD be a fully-qualified identifier. | Not Evaluated |  |

### Contract period end (Contract commitment)

The exclusive end bound of a contract period.

Source: [datasets/contract_commitment/columns/contractperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CPE1 | MUST | ContractPeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CPE1.1 | MUST | ContractPeriodEnd MUST be of type Date/Time. | Not Evaluated |  |
| CC-CPE1.2 | MUST | ContractPeriodEnd MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CPE1.3 | MUST | ContractPeriodEnd MUST NOT be null. | Not Evaluated |  |
| CC-CPE1.4 | MUST | ContractPeriodEnd MUST be the exclusive end bound of the effective period of the contract. | Not Evaluated |  |

### Contract period start (Contract commitment)

The inclusive start bound of a contract period.

Source: [datasets/contract_commitment/columns/contractperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/contractperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-CPS1 | MUST | ContractPeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| CC-CPS1.1 | MUST | ContractPeriodStart MUST be of type Date/Time. | Not Evaluated |  |
| CC-CPS1.2 | MUST | ContractPeriodStart MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| CC-CPS1.3 | MUST | ContractPeriodStart MUST NOT be null. | Not Evaluated |  |
| CC-CPS1.4 | MUST | ContractPeriodStart MUST be the inclusive start bound of the effective period of the contract. | Not Evaluated |  |

### Invoice issuer name (Contract commitment)

The name of the entity responsible for invoicing for the contract commitment.

Source: [datasets/contract_commitment/columns/invoiceissuername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/invoiceissuername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-IIN1 | MUST | InvoiceIssuerName MUST adhere to the following requirements: | Not Evaluated |  |
| CC-IIN1.1 | MUST | InvoiceIssuerName MUST be of type String. | Not Evaluated |  |
| CC-IIN1.2 | MUST | InvoiceIssuerName MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-IIN1.3 | MUST | InvoiceIssuerName MUST NOT be null. | Not Evaluated |  |
| CC-IIN1.4 | MUST | InvoiceIssuerName MUST represent the entity that issues invoices. | Not Evaluated |  |

### Pricing currency (Contract commitment)

The national or virtual currency denomination that the Contract Commitment Cost was priced in.

Source: [datasets/contract_commitment/columns/pricingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/pricingcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-PC1 | MUST | PricingCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| CC-PC1.1 | MUST | PricingCurrency MUST be of type String. | Not Evaluated |  |
| CC-PC1.2 | MUST | PricingCurrency MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-PC1.3 | MUST | PricingCurrency MUST conform to CurrencyFormat requirements. | Not Evaluated |  |
| CC-PC1.4 | MUST | PricingCurrency MUST NOT be null. | Not Evaluated |  |

### Pricing currency contract commitment cost (Contract commitment)

The monetary value of the contract commitment in the Pricing Currency.

Source: [datasets/contract_commitment/columns/pricingcurrencycontractcommitmentcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/pricingcurrencycontractcommitmentcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-PCCCC1 | MUST | PricingCurrencyContractCommitmentCost MUST adhere to the following requirements: | Not Evaluated |  |
| CC-PCCCC1.1 | MUST | PricingCurrencyContractCommitmentCost MUST be of type Decimal. | Not Evaluated |  |
| CC-PCCCC1.2 | MUST | PricingCurrencyContractCommitmentCost MUST conform to NumericFormat requirements. | Not Evaluated |  |
| CC-PCCCC1.3 | MUST | PricingCurrencyContractCommitmentCost MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CC-PCCCC1.3.1 | MUST | PricingCurrencyContractCommitmentCost MUST NOT be null when ContractCommitmentCategory is "Spend" and PricingCurrency is provided. | Not Evaluated |  |
| CC-PCCCC1.3.2 | MAY | PricingCurrencyContractCommitmentCost MAY be null when ContractCommitmentCategory is "Usage". | Not Evaluated |  |
| CC-PCCCC1.4 | MUST | PricingCurrencyContractCommitmentCost MUST be denominated in the PricingCurrency. | Not Evaluated |  |

### Service provider name (Contract commitment)

The name of the entity that provides the contract commitment.

Source: [datasets/contract_commitment/columns/serviceprovidername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/contract_commitment/columns/serviceprovidername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CC-SPN1 | MUST | ServiceProviderName MUST adhere to the following requirements: | Not Evaluated |  |
| CC-SPN1.1 | MUST | ServiceProviderName MUST be of type String. | Not Evaluated |  |
| CC-SPN1.2 | MUST | ServiceProviderName MUST conform to StringHandling requirements. | Not Evaluated |  |
| CC-SPN1.3 | MUST | ServiceProviderName MUST NOT be null. | Not Evaluated |  |

### Allocated method details (Cost and usage)

A set of properties describing how resources are allocated in data generator-defined split cost allocation.

Source: [datasets/cost_and_usage/columns/allocatedmethoddetails.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/allocatedmethoddetails.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-AMD1 | MUST | AllocatedMethodDetails MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AMD1.1 | MUST | AllocatedMethodDetails MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-AMD1.2 | MUST | AllocatedMethodDetails MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-AMD1.3 | MUST | AllocatedMethodDetails MUST conform to JsonObjectFormat requirements. | Not Evaluated |  |
| CU-AMD1.4 | MUST | AllocatedMethodDetails MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-AMD1.4.1 | MUST | AllocatedMethodDetails MUST be null when a charge is not related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-AMD1.4.2 | SHOULD | AllocatedMethodDetails SHOULD NOT be null when a charge is related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-AMD1.5 | MUST | AllocatedMethodDetails MUST conform to AllocatedMethodDetailsObject requirements when AllocatedMethodDetails is not null. | Not Evaluated |  |
| CU-AMD2 | MUST | The AllocatedMethodDetailsObject MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AMD2.1 | MUST | AllocatedMethodDetailsObject MUST conform to the AllocatedMethodDetailsObjectSchema JSON Schema. | Not Evaluated |  |
| CU-AMD2.2 | MUST | AllocatedMethodDetailsObject.Elements[\].AllocatedRatio MUST represent the allocated charge's percentage of the origin charge. | Not Evaluated |  |
| CU-AMD2.3 | MUST | The sum of AllocatedMethodDetailsObject.Elements[\].AllocatedRatio across all allocated charges related to a single origin charge MUST be equal to 1 (100%). | Not Evaluated |  |
| CU-AMD2.4 | SHOULD | AllocatedMethodDetailsObject.Elements[\].UsageUnit SHOULD conform to UnitFormat requirements. | Not Evaluated |  |
| CU-AMD2.5 | MUST | AllocatedMethodDetailsObject.Elements[\].UsageUnit MUST represent the unit or component of data generator's documented AllocationMethod which was used to determine the AllocatedMethodDetailsObject.Elements[\].AllocatedRatio value. | Not Evaluated |  |
| CU-AMD2.6 | SHOULD | AllocatedMethodDetailsObject.Elements[\].UsageQuantity SHOULD capture the quantity or volume of the AllocatedMethodDetailsObject.Elements[\].UsageUnit measured by the data generator that was used to determine the AllocatedMethodDetailsObject.Elements[\].AllocatedRatio value. | Not Evaluated |  |

### Allocated method ID (Cost and usage)

A unique identifier defining the method of data generator-calculated split cost allocation.

Source: [datasets/cost_and_usage/columns/allocatedmethodid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/allocatedmethodid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-AMI1 | MUST | AllocatedMethodId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AMI1.1 | MUST | AllocatedMethodId MUST be of type String. | Not Evaluated |  |
| CU-AMI1.2 | MUST | AllocatedMethodId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-AMI1.3 | MUST | AllocatedMethodId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-AMI1.3.1 | MUST | AllocatedMethodId MUST be null when a charge is not related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-AMI1.3.2 | MUST | AllocatedMethodId MUST NOT be null when a charge is related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-AMI1.4 | MUST | Data generator-calculated split cost allocation method documentation MUST reference a single AllocatedMethodId value. | Not Evaluated |  |

### Allocated resource ID (Cost and usage)

The identifier of the object to which cost is allocated in data generator-calculated split cost allocation.

Source: [datasets/cost_and_usage/columns/allocatedresourceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/allocatedresourceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-ARI1 | MUST | AllocatedResourceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ARI1.1 | MUST | AllocatedResourceId MUST be of type String. | Not Evaluated |  |
| CU-ARI1.2 | MUST | AllocatedResourceId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-ARI1.3 | MUST | AllocatedResourceId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-ARI1.3.1 | MUST | AllocatedResourceId MUST be null when a charge is not related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-ARI1.3.2 | MUST | AllocatedResourceId MUST be null when a charge represents the unallocated portion of the origin charge after split cost allocation. | Not Evaluated |  |
| CU-ARI1.3.3 | MUST | AllocatedResourceId MUST NOT be null when a charge represents the allocated portion of the origin charge. | Not Evaluated |  |
| CU-ARI1.4 | MUST | When AllocatedResourceId is not null, AllocatedResourceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ARI1.4.1 | SHOULD | AllocatedResourceId SHOULD be a locally unique identifier within the associated ResourceId and ChargePeriod. | Not Evaluated |  |
| CU-ARI1.4.2 | MAY | AllocatedResourceId MAY NOT be unique across ResourceId or ChargePeriod values. | Not Evaluated |  |

### Allocated resource name (Cost and usage)

The display name of the object to which cost is allocated in data generator-calculated split cost allocation.

Source: [datasets/cost_and_usage/columns/allocatedresourcename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/allocatedresourcename.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-ARN1 | MUST | AllocatedResourceName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ARN1.1 | MUST | AllocatedResourceName MUST be of type String. | Not Evaluated |  |
| CU-ARN1.2 | MUST | AllocatedResourceName MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-ARN1.3 | MUST | AllocatedResourceName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-ARN1.3.1 | MUST | AllocatedResourceName MUST be null when AllocatedResourceId is null. | Not Evaluated |  |
| CU-ARN1.3.2 | MUST | AllocatedResourceName MUST NOT be null when AllocatedResourceId is not null. | Not Evaluated |  |
| CU-ARN1.4 | MAY | AllocatedResourceName MAY duplicate AllocatedResourceId when a separate display name is not applicable. | Not Evaluated |  |

### Allocated tags (Cost and usage)

A set of tags assigned to tag sources that are applicable to allocated charges in data generator-calculated split cost allocation.

Source: [datasets/cost_and_usage/columns/allocatedtags.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/allocatedtags.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-AT1 | MUST | AllocatedTags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AT1.1 | MUST | AllocatedTags MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-AT1.2 | MUST | AllocatedTags MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-AT1.3 | MUST | AllocatedTags MUST conform to KeyValueFormat requirements. | Not Evaluated |  |
| CU-AT1.4 | MUST | AllocatedTags MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-AT1.4.1 | MUST | AllocatedTags MUST be null when a charge is not related to a data generator-calculated split cost allocation. | Not Evaluated |  |
| CU-AT1.4.2 | MAY | AllocatedTags MAY be null in all other cases. | Not Evaluated |  |
| CU-AT1.5 | MUST | When AllocatedTags is not null, AllocatedTags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AT1.5.1 | MUST | AllocatedTags MUST NOT include resource tags already present in Tags. | Not Evaluated |  |
| CU-AT1.5.2 | MUST | AllocatedTags MUST include all applicable user-defined and data generator-defined tags for the AllocatedResourceId. | Not Evaluated |  |
| CU-AT1.5.3 | MUST | Tag keys that do not support corresponding values MUST have a corresponding true (boolean) value set. | Not Evaluated |  |
| CU-AT1.5.4 | MUST | Tag values MUST match the provided values unless true (boolean) is applied to valueless tags. | Not Evaluated |  |
| CU-AT1.6 | MUST | Data generator-defined tags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AT1.6.1 | MUST | Data generator-defined tag keys MUST be prefixed with a predetermined, data generator-specified tag key prefix that is unique to each corresponding provider-specified tag scheme. | Not Evaluated |  |
| CU-AT1.6.2 | SHOULD | Data generator-specified tag key prefixes SHOULD be publicly documented. | Not Evaluated |  |
| CU-AT1.7 | MUST | User-defined tag keys in all user-defined tag schemes MUST include a predetermined, data generator-specified tag key prefix that is unique to each corresponding user-defined tag scheme when the data generator has more than one user-defined tag scheme. | Not Evaluated |  |

### Availability zone (Cost and usage)

A host-provider-assigned identifier for a physically separated and isolated area within a Region that provides high availability and fault tolerance.

Source: [datasets/cost_and_usage/columns/availabilityzone.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/availabilityzone.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-AZ1 | MUST | AvailabilityZone MUST adhere to the following requirements: | Not Evaluated |  |
| CU-AZ1.1 | MUST | AvailabilityZone MUST be of type String. | Not Applicable |  |
| CU-AZ1.2 | MUST | AvailabilityZone MUST conform to StringHandling requirements. | Not Applicable |  |
| CU-AZ1.3 | MUST | AvailabilityZone MUST be null when a charge is not specific to an availability zone. | Not Applicable |  |

### Billed cost (Cost and usage)

Cost of a charge as invoiced by the invoice issuer in a given billing period.

Source: [datasets/cost_and_usage/columns/billedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billedcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BC1 | MUST | BilledCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BC1.1 | MUST | BilledCost MUST be of type Decimal. | Supports |  |
| CU-BC1.2 | MUST | BilledCost MUST conform to NumericFormat requirements. | Supports |  |
| CU-BC1.3 | MUST | BilledCost MUST NOT be null. | Supports |  |
| CU-BC1.4 | MUST | BilledCost MUST be denominated in the BillingCurrency. | Supports |  |
| CU-BC1.5 | MUST | BilledCost MUST reflect all applicable pricing adjustments, including but not limited to negotiated discounts, commitment discounts, and other applicable discount programs. | Not Evaluated |  |
| CU-BC1.6 | MUST | BilledCost MUST NOT include any portion of a covered charge that is offset by a covering charge. | Not Evaluated |  |
| CU-BC1.7 | MUST | BilledCost MUST be 0 for charges that are fully covered by one or more covering charges. | Not Evaluated |  |
| CU-BC1.8 | MUST | BilledCost MUST reflect amounts as invoiced by the InvoiceIssuerName, not estimated or inferred values. | Not Evaluated |  |
| CU-BC1.9 | MUST | BilledCost MUST be 0 for charges generated by entities that are not responsible or authorized for invoicing, to avoid double-counting when merging multiple dataset instances. | Not Evaluated |  |
| CU-BC1.10 | MUST | The sum of BilledCost for a given InvoiceId and InvoiceIssuerName MUST NOT differ from the payable amount provided on the corresponding invoice by more than the Rounding Variance Tolerance when the corresponding invoice has been issued. | Not Evaluated |  |
| CU-BC1.11 | MAY | The sum of BilledCost MAY differ from preliminary or estimated invoiced amounts when the corresponding invoice has not yet been issued. | Not Evaluated |  |

### Billing account ID (Cost and usage)

The identifier assigned to a billing account by the invoice issuer.

Source: [datasets/cost_and_usage/columns/billingaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingaccountid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BAI1 | MUST | BillingAccountId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BAI1.1 | MUST | BillingAccountId MUST be of type String. | Supports |  |
| CU-BAI1.2 | MUST | BillingAccountId MUST conform to StringHandling requirements. | Supports |  |
| CU-BAI1.3 | MUST | BillingAccountId MUST NOT be null. | Supports |  |
| CU-BAI1.4 | MUST | BillingAccountId MUST be a unique identifier within an invoice issuer. | Not Evaluated |  |
| CU-BAI1.5 | SHOULD | BillingAccountId SHOULD be a fully-qualified identifier. | Supports | `BillingAccountId` uses the fully qualified Azure Resource Manager ID instead of the simple enrollment number or billing profile ID. This ensures the scope is obvious and programmatically accessible. |

### Billing account name (Cost and usage)

The display name assigned to a billing account.

Source: [datasets/cost_and_usage/columns/billingaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingaccountname.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BAN1 | MUST | BillingAccountName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BAN1.1 | MUST | BillingAccountName MUST be of type String. | Supports |  |
| CU-BAN1.2 | MUST | BillingAccountName MUST conform to StringHandling requirements. | Supports |  |
| CU-BAN1.3 | MUST | BillingAccountName MUST NOT be null when the invoice issuer supports assigning a display name for the billing account. | Not Evaluated |  |

### Billing account type (Cost and usage)

An invoice-issuer-assigned name to identify the type of billing account.

Source: [datasets/cost_and_usage/columns/billingaccounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingaccounttype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BAT1 | MUST | BillingAccountType MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BAT1.1 | MUST | BillingAccountType MUST be of type String. | Supports |  |
| CU-BAT1.2 | MUST | BillingAccountType MUST conform to StringHandling requirements. | Supports |  |
| CU-BAT1.3 | MUST | BillingAccountType MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-BAT1.3.1 | MUST | BillingAccountType MUST be null when BillingAccountId is null. | Supports |  |
| CU-BAT1.3.2 | MUST | BillingAccountType MUST NOT be null when BillingAccountId is not null. | Supports |  |
| CU-BAT1.4 | MUST | BillingAccountType MUST be a consistent, readable display value. | Supports |  |

### Billing currency (Cost and usage)

Represents the currency that a charge was billed in.

Source: [datasets/cost_and_usage/columns/billingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BiC1 | MUST | BillingCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BiC1.1 | MUST | BillingCurrency MUST be of type String. | Supports |  |
| CU-BiC1.2 | MUST | BillingCurrency MUST conform to StringHandling requirements. | Supports |  |
| CU-BiC1.3 | MUST | BillingCurrency MUST conform to CurrencyFormat requirements. | Supports |  |
| CU-BiC1.4 | MUST | BillingCurrency MUST NOT be null. | Supports |  |
| CU-BiC1.5 | MUST | BillingCurrency MUST match the currency used in the invoice generated by the invoice issuer. | Supports |  |
| CU-BiC1.6 | MUST | BillingCurrency MUST be expressed in national currency (e.g., USD, EUR). | Supports |  |

### Billing period end (Cost and usage)

The exclusive end bound of a billing period.

Source: [datasets/cost_and_usage/columns/billingperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BPE1 | MUST | BillingPeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BPE1.1 | MUST | BillingPeriodEnd MUST be of type Date/Time. | Supports |  |
| CU-BPE1.2 | MUST | BillingPeriodEnd MUST conform to DateTimeFormat requirements. | Supports |  |
| CU-BPE1.3 | MUST | BillingPeriodEnd MUST NOT be null. | Supports |  |
| CU-BPE1.4 | MUST | BillingPeriodEnd MUST be the exclusive end bound of the billing period. | Supports |  |

### Billing period start (Cost and usage)

The inclusive start bound of a billing period.

Source: [datasets/cost_and_usage/columns/billingperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/billingperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-BPS1 | MUST | BillingPeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| CU-BPS1.1 | MUST | BillingPeriodStart MUST be of type Date/Time. | Supports |  |
| CU-BPS1.2 | MUST | BillingPeriodStart MUST conform to DateTimeFormat requirements. | Supports |  |
| CU-BPS1.3 | MUST | BillingPeriodStart MUST NOT be null. | Supports |  |
| CU-BPS1.4 | MUST | BillingPeriodStart MUST be the inclusive start bound of the billing period. | Supports |  |

### Capacity reservation ID (Cost and usage)

The identifier assigned to a capacity reservation by the service provider.

Source: [datasets/cost_and_usage/columns/capacityreservationid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/capacityreservationid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CRI1 | MUST | CapacityReservationId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CRI1.1 | MUST | CapacityReservationId MUST be of type String. | Not Applicable |  |
| CU-CRI1.2 | MUST | CapacityReservationId MUST conform to StringHandling requirements. | Not Applicable |  |
| CU-CRI1.3 | MUST | CapacityReservationId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CRI1.3.1 | MUST | CapacityReservationId MUST be null when a charge is not related to a capacity reservation. | Not Applicable |  |
| CU-CRI1.3.2 | MUST | CapacityReservationId MUST NOT be null when a charge represents the unused portion of a capacity reservation. | Not Applicable |  |
| CU-CRI1.3.3 | SHOULD | CapacityReservationId SHOULD NOT be null when a charge is related to a capacity reservation. | Not Applicable |  |
| CU-CRI1.4 | MUST | When CapacityReservationId is not null, CapacityReservationId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CRI1.4.1 | MUST | CapacityReservationId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CU-CRI1.4.2 | SHOULD | CapacityReservationId SHOULD be a fully-qualified identifier. | Not Applicable |  |

### Capacity reservation status (Cost and usage)

Indicates whether the charge represents either the consumption of a capacity reservation or when a capacity reservation is unused.

Source: [datasets/cost_and_usage/columns/capacityreservationstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/capacityreservationstatus.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CRS1 | MUST | CapacityReservationStatus MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CRS1.1 | MUST | CapacityReservationStatus MUST be of type String. | Not Applicable |  |
| CU-CRS1.2 | MUST | CapacityReservationStatus MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CRS1.2.1 | MUST | CapacityReservationStatus MUST be null when CapacityReservationId is null. | Not Applicable |  |
| CU-CRS1.2.2 | MUST | CapacityReservationStatus MUST NOT be null when CapacityReservationId is not null and ChargeCategory is "Usage". | Not Applicable |  |
| CU-CRS1.3 | MUST | When CapacityReservationStatus is not null, CapacityReservationStatus MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CRS1.3.1 | MUST | CapacityReservationStatus MUST be one of the allowed values. | Not Applicable |  |
| CU-CRS1.3.2 | MUST | CapacityReservationStatus MUST be "Unused" when the charge represents the unused portion of a capacity reservation. | Not Applicable |  |
| CU-CRS1.3.3 | MUST | CapacityReservationStatus MUST be "Used" when the charge represents the used portion of a capacity reservation. | Not Applicable |  |

### Charge category (Cost and usage)

Represents the highest-level classification of a charge based on the nature of how it is billed.

Source: [datasets/cost_and_usage/columns/chargecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargecategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CC1 | MUST | ChargeCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CC1.1 | MUST | ChargeCategory MUST be of type String. | Supports |  |
| CU-CC1.2 | MUST | ChargeCategory MUST NOT be null. | Supports |  |
| CU-CC1.3 | MUST | ChargeCategory MUST be one of the allowed values. | Supports |  |
| CU-CC1.4 | MUST | ChargeCategory MUST be "Usage" when the charge represents consumption of a service or resource. | Not Evaluated |  |
| CU-CC1.5 | MUST | ChargeCategory MUST be "Purchase" when the charge represents acquisition of a service, resource, or commitment. | Not Evaluated |  |
| CU-CC1.6 | MUST | ChargeCategory MUST be "Tax" when the charge represents taxes levied by the relevant authorities. | Not Evaluated |  |
| CU-CC1.7 | MUST | ChargeCategory MUST be "Credit" when the charge represents a financial incentive or allowance unrelated to other charges. | Not Evaluated |  |
| CU-CC1.8 | MUST | ChargeCategory MUST be "Adjustment" when the charge represents a billing modification that does not fall into other ChargeCategories. | Not Evaluated |  |

### Charge class (Cost and usage)

Indicates whether a charge represents a correction to a previously closed billing period.

Source: [datasets/cost_and_usage/columns/chargeclass.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargeclass.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-ChC1 | MUST | ChargeClass MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ChC1.1 | MUST | ChargeClass MUST be of type String. | Supports |  |
| CU-ChC1.2 | MUST | ChargeClass MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-ChC1.2.1 | MUST | ChargeClass MUST be null when the charge does not represent a correction to a previously closed billing period. | Not Evaluated |  |
| CU-ChC1.2.2 | MUST | ChargeClass MUST NOT be null when the charge represents a correction to a previously closed billing period. | Not Evaluated |  |
| CU-ChC1.3 | MUST | ChargeClass MUST be "Correction" when ChargeClass is not null. | Supports |  |

### Charge description (Cost and usage)

Self-contained summary of the charge's purpose and price.

Source: [datasets/cost_and_usage/columns/chargedescription.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargedescription.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CD1 | MUST | ChargeDescription MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CD1.1 | MUST | ChargeDescription MUST be of type String. | Supports |  |
| CU-CD1.2 | MUST | ChargeDescription MUST conform to StringHandling requirements. | Supports |  |
| CU-CD1.3 | SHOULD | ChargeDescription SHOULD NOT be null. | Partially Supports | `ChargeDescription` may be null for savings plan unused charges, Marketplace charges, and other charges that aren't directly associated with a product SKU. |
| CU-CD1.4 | SHOULD | ChargeDescription maximum length SHOULD be provided in the corresponding FOCUS Metadata Schema. | Does Not Support |  |

### Charge frequency (Cost and usage)

Indicates how often a charge will occur.

Source: [datasets/cost_and_usage/columns/chargefrequency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargefrequency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CF1 | MUST | ChargeFrequency MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CF1.1 | MUST | ChargeFrequency MUST be of type String. | Supports |  |
| CU-CF1.2 | MUST | ChargeFrequency MUST NOT be null. | Supports |  |
| CU-CF1.3 | MUST | ChargeFrequency MUST be one of the allowed values. | Supports |  |
| CU-CF1.4 | MUST | ChargeFrequency MUST NOT be "Usage-Based" when ChargeCategory is "Purchase". | Supports |  |

### Charge period end (Cost and usage)

The exclusive end bound of a charge period.

Source: [datasets/cost_and_usage/columns/chargeperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargeperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CPE1 | MUST | ChargePeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CPE1.1 | MUST | ChargePeriodEnd MUST be of type Date/Time. | Supports |  |
| CU-CPE1.2 | MUST | ChargePeriodEnd MUST conform to DateTimeFormat requirements. | Supports |  |
| CU-CPE1.3 | MUST | ChargePeriodEnd MUST NOT be null. | Supports |  |
| CU-CPE1.4 | MUST | ChargePeriodEnd MUST be the exclusive end bound of the effective period of the charge. | Supports |  |

### Charge period start (Cost and usage)

The inclusive start bound of a charge period.

Source: [datasets/cost_and_usage/columns/chargeperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/chargeperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CPS1 | MUST | ChargePeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CPS1.1 | MUST | ChargePeriodStart MUST be of type Date/Time. | Supports |  |
| CU-CPS1.2 | MUST | ChargePeriodStart MUST conform to DateTimeFormat requirements. | Supports |  |
| CU-CPS1.3 | MUST | ChargePeriodStart MUST NOT be null. | Supports |  |
| CU-CPS1.4 | MUST | ChargePeriodStart MUST be the inclusive start bound of the effective period of the charge. | Supports |  |

### Commitment discount category (Cost and usage)

Indicates whether the commitment discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka "spend").

Source: [datasets/cost_and_usage/columns/commitmentdiscountcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountcategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDC1 | MUST | CommitmentDiscountCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDC1.1 | MUST | CommitmentDiscountCategory MUST be of type String. | Supports |  |
| CU-CDC1.2 | MUST | CommitmentDiscountCategory MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDC1.2.1 | MUST | CommitmentDiscountCategory MUST be null when CommitmentDiscountId is null. | Supports |  |
| CU-CDC1.2.2 | MUST | CommitmentDiscountCategory MUST NOT be null when CommitmentDiscountId is not null. | Supports |  |
| CU-CDC1.3 | MUST | CommitmentDiscountCategory MUST be one of the allowed values. | Supports |  |

### Commitment discount ID (Cost and usage)

The identifier assigned to a commitment discount by the service provider.

Source: [datasets/cost_and_usage/columns/commitmentdiscountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDI1 | MUST | CommitmentDiscountId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDI1.1 | MUST | CommitmentDiscountId MUST be of type String. | Supports |  |
| CU-CDI1.2 | MUST | CommitmentDiscountId MUST conform to StringHandling requirements. | Supports |  |
| CU-CDI1.3 | MUST | CommitmentDiscountId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDI1.3.1 | MUST | CommitmentDiscountId MUST be null when a charge is not related to a commitment discount. | Supports |  |
| CU-CDI1.3.2 | MUST | CommitmentDiscountId MUST NOT be null when a charge is related to a commitment discount. | Supports |  |
| CU-CDI1.4 | MUST | When CommitmentDiscountId is not null, CommitmentDiscountId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDI1.4.1 | MUST | CommitmentDiscountId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CU-CDI1.4.2 | MUST | CommitmentDiscountId MUST be equal to ResourceId when ChargeCategory is "Purchase" and the charge represents a purchase of that commitment discount. | Not Evaluated |  |
| CU-CDI1.4.3 | MUST | CommitmentDiscountId MUST be equal to ResourceId when ChargeCategory is "Usage" and the charge represents an unused portion of that commitment discount. | Not Evaluated |  |
| CU-CDI1.4.4 | SHOULD | CommitmentDiscountId SHOULD be a fully-qualified identifier. | Supports |  |

### Commitment discount name (Cost and usage)

The display name assigned to a commitment discount.

Source: [datasets/cost_and_usage/columns/commitmentdiscountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountname.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDN1 | MUST | CommitmentDiscountName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDN1.1 | MUST | CommitmentDiscountName MUST be of type String. | Supports |  |
| CU-CDN1.2 | MUST | CommitmentDiscountName MUST conform to StringHandling requirements. | Supports |  |
| CU-CDN1.3 | MUST | CommitmentDiscountName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDN1.3.1 | MUST | CommitmentDiscountName MUST be null when CommitmentDiscountId is null. | Supports |  |
| CU-CDN1.3.2 | MUST | When CommitmentDiscountId is not null, CommitmentDiscountName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDN1.3.2.1 | MUST | CommitmentDiscountName MUST NOT be null when a display name can be assigned to a commitment discount. | Supports |  |
| CU-CDN1.3.2.2 | MAY | CommitmentDiscountName MAY be null when a display name cannot be assigned to a commitment discount. | Supports |  |

### Commitment discount quantity (Cost and usage)

The amount of a commitment discount purchased or accounted for in commitment discount related rows that is denominated in Commitment Discount Units.

Source: [datasets/cost_and_usage/columns/commitmentdiscountquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountquantity.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDQ1 | MUST | CommitmentDiscountQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDQ1.1 | MUST | CommitmentDiscountQuantity MUST be of type Decimal. | Not Applicable |  |
| CU-CDQ1.2 | MUST | CommitmentDiscountQuantity MUST conform to NumericFormat requirements. | Not Applicable |  |
| CU-CDQ1.3 | MUST | CommitmentDiscountQuantity MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDQ1.3.1 | MUST | CommitmentDiscountQuantity MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-CDQ1.3.2 | MUST | When ChargeCategory is "Usage" or "Purchase" and CommitmentDiscountId is not null, CommitmentDiscountQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDQ1.3.2.1 | MUST | CommitmentDiscountQuantity MUST NOT be null when ChargeClass is not "Correction". | Not Applicable |  |
| CU-CDQ1.3.2.2 | MAY | CommitmentDiscountQuantity MAY be null when ChargeClass is "Correction". | Not Applicable |  |
| CU-CDQ1.3.3 | MUST | CommitmentDiscountQuantity MUST be null in all other cases. | Not Applicable |  |
| CU-CDQ1.4 | MUST | When CommitmentDiscountQuantity is not null and ChargeCategory is "Purchase", CommitmentDiscountQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDQ1.4.1 | MUST | CommitmentDiscountQuantity MUST be the quantity of CommitmentDiscountUnit, paid fully or partially upfront, that is eligible for consumption over the commitment discount's term when ChargeFrequency is "One-Time". | Not Applicable |  |
| CU-CDQ1.4.2 | MUST | CommitmentDiscountQuantity MUST be the quantity of CommitmentDiscountUnit that is eligible for consumption for each charge period that corresponds with the purchase when ChargeFrequency is "Recurring". | Not Applicable |  |
| CU-CDQ1.5 | MUST | When CommitmentDiscountQuantity is not null and ChargeCategory is "Usage", CommitmentDiscountQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDQ1.5.1 | MUST | CommitmentDiscountQuantity MUST be the metered quantity of CommitmentDiscountUnit that is consumed in a given charge period when CommitmentDiscountStatus is "Used". | Not Applicable |  |
| CU-CDQ1.5.2 | MUST | CommitmentDiscountQuantity MUST be the remaining, unused quantity of CommitmentDiscountUnit in a given charge period when CommitmentDiscountStatus is "Unused". | Not Applicable |  |

### Commitment discount status (Cost and usage)

Indicates whether the charge corresponds with the consumption of a commitment discount or the unused portion of the committed amount.

Source: [datasets/cost_and_usage/columns/commitmentdiscountstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountstatus.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDS1 | MUST | CommitmentDiscountStatus MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDS1.1 | MUST | CommitmentDiscountStatus MUST be of type String. | Supports |  |
| CU-CDS1.2 | MUST | CommitmentDiscountStatus MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDS1.2.1 | MUST | CommitmentDiscountStatus MUST be null when CommitmentDiscountId is null. | Supports |  |
| CU-CDS1.2.2 | MUST | CommitmentDiscountStatus MUST NOT be null when CommitmentDiscountId is not null and ChargeCategory is "Usage". | Not Evaluated |  |
| CU-CDS1.3 | MUST | CommitmentDiscountStatus MUST be one of the allowed values. | Supports |  |
| CU-CDS1.4 | MUST | CommitmentDiscountStatus MUST be "Used" when the charge utilizes a specific amount of a given CommitmentDiscountId. | Not Evaluated |  |
| CU-CDS1.5 | MUST | CommitmentDiscountStatus MUST be "Unused" when the charge represents the unused portion of the given CommitmentDiscountId. | Not Evaluated |  |

### Commitment discount type (Cost and usage)

A service-provider-assigned identifier for the type of commitment discount applied to the row.

Source: [datasets/cost_and_usage/columns/commitmentdiscounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscounttype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDT1 | MUST | CommitmentDiscountType MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDT1.1 | MUST | CommitmentDiscountType MUST be of type String. | Supports |  |
| CU-CDT1.2 | MUST | CommitmentDiscountType MUST conform to StringHandling requirements. | Supports |  |
| CU-CDT1.3 | MUST | CommitmentDiscountType MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDT1.3.1 | MUST | CommitmentDiscountType MUST be null when CommitmentDiscountId is null. | Supports |  |
| CU-CDT1.3.2 | MUST | CommitmentDiscountType MUST NOT be null when CommitmentDiscountId is not null. | Supports |  |

### Commitment discount unit (Cost and usage)

The service-provider-specified measurement unit indicating how a service provider measures the Commitment Discount Quantity of a commitment discount.

Source: [datasets/cost_and_usage/columns/commitmentdiscountunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentdiscountunit.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CDU1 | MUST | CommitmentDiscountUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDU1.1 | MUST | CommitmentDiscountUnit MUST be of type String. | Not Applicable |  |
| CU-CDU1.2 | MUST | CommitmentDiscountUnit MUST conform to StringHandling requirements. | Not Applicable |  |
| CU-CDU1.3 | SHOULD | CommitmentDiscountUnit SHOULD conform to UnitFormat requirements. | Not Applicable |  |
| CU-CDU1.4 | MUST | CommitmentDiscountUnit MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CDU1.4.1 | MUST | CommitmentDiscountUnit MUST be null when CommitmentDiscountQuantity is null. | Not Applicable |  |
| CU-CDU1.4.2 | MUST | CommitmentDiscountUnit MUST NOT be null when CommitmentDiscountQuantity is not null. | Not Applicable |  |
| CU-CDU1.5 | MUST | When CommitmentDiscountUnit is not null, CommitmentDiscountUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CDU1.5.1 | MUST | CommitmentDiscountUnit MUST remain consistent over time for a given CommitmentDiscountId. | Not Applicable |  |
| CU-CDU1.5.2 | MUST | CommitmentDiscountUnit MUST represent the unit used to measure the commitment discount. | Not Applicable |  |
| CU-CDU1.5.3 | SHOULD | When accounting for commitment discount flexibility, the CommitmentDiscountUnit value SHOULD reflect this consideration. | Not Applicable |  |

### Commitment program eligibility details (Cost and usage)

The types of commitment programs available for a specific usage row.

Source: [datasets/cost_and_usage/columns/commitmentprogrameligibilitydetails.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/commitmentprogrameligibilitydetails.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CPED1 | MUST | CommitmentProgramEligibilityDetails MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CPED1.1 | MUST | CommitmentProgramEligibilityDetails MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-CPED1.2 | MUST | CommitmentProgramEligibilityDetails MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-CPED1.3 | MUST | CommitmentProgramEligibilityDetails MUST conform to JsonObjectFormat requirements. | Not Evaluated |  |
| CU-CPED1.4 | MUST | CommitmentProgramEligibilityDetails MUST NOT be null when a charge is eligible for a commitment program, regardless of whether a commitment was actually applied to the charge. | Not Evaluated |  |
| CU-CPED1.5 | MUST | CommitmentProgramEligibilityDetails MUST NOT reflect restrictions (e.g., transient account configurations, quotas) that might temporarily prevent purchase or participation in a commitment program. | Not Evaluated |  |
| CU-CPED1.6 | MUST | CommitmentProgramEligibilityDetails MUST include all publicly available commitment programs for which the usage is eligible. | Not Evaluated |  |
| CU-CPED1.7 | MAY | CommitmentProgramEligibilityDetails MAY include negotiated commitment programs when the usage is eligible and the program is not broadly applicable across the service provider's service catalog. | Not Evaluated |  |
| CU-CPED1.8 | MUST | CommitmentProgramEligibilityDetails MUST NOT include data related to commitment periods or payment options. | Not Evaluated |  |
| CU-CPED1.9 | MUST | CommitmentProgramEligibilityDetails MUST conform to CommitmentProgramEligibilityDetailsObject requirements when CommitmentProgramEligibilityDetails is not null. | Not Evaluated |  |
| CU-CPED2 | MUST | CommitmentProgramEligibilityDetailsObject MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CPED2.1 | MUST | CommitmentProgramEligibilityDetailsObject MUST conform to the CommitmentProgramEligibilityDetailsObjectSchema JSON Schema. | Not Evaluated |  |
| CU-CPED2.2 | MUST | CommitmentProgramEligibilityDetailsObject.CommitmentPrograms[\].ProgramType MUST correspond to a commitment program type supported by the service provider. | Not Evaluated |  |
| CU-CPED2.3 | MUST | CommitmentProgramEligibilityDetailsObject.CommitmentPrograms[\].ProgramType MUST match CommitmentDiscountType for one object in CommitmentProgramEligibilityDetailsObject.CommitmentPrograms when CommitmentDiscountType is not null. | Not Evaluated |  |
| CU-CPED2.4 | SHOULD | CommitmentProgramEligibilityDetailsObject.CommitmentPrograms[\].ProgramType SHOULD correspond to terminology disclosed by the service provider in public documentation. | Not Evaluated |  |

### Consumed quantity (Cost and usage)

The volume of a metered SKU associated with a resource or service used, based on the Consumed Unit.

Source: [datasets/cost_and_usage/columns/consumedquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/consumedquantity.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CQ1 | MUST | ConsumedQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CQ1.1 | MUST | ConsumedQuantity MUST be of type Decimal. | Supports |  |
| CU-CQ1.2 | MUST | ConsumedQuantity MUST conform to NumericFormat requirements. | Supports |  |
| CU-CQ1.3 | MUST | ConsumedQuantity MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CQ1.3.1 | MUST | ConsumedQuantity MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-CQ1.3.2 | MUST | ConsumedQuantity MUST be null when ChargeCategory is not "Usage", or when ChargeCategory is "Usage" and CommitmentDiscountStatus is "Unused". | Supports |  |
| CU-CQ1.3.3 | MUST | When ChargeCategory is "Usage" and CommitmentDiscountStatus is not "Unused", ConsumedQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CQ1.3.3.1 | MUST | ConsumedQuantity MUST NOT be null when ChargeClass is not "Correction". | Supports |  |
| CU-CQ1.3.3.2 | MAY | ConsumedQuantity MAY be null when ChargeClass is "Correction". | Supports |  |

### Consumed unit (Cost and usage)

Service-provider-specified measurement unit indicating how a service provider measures usage of a metered SKU associated with a resource or service.

Source: [datasets/cost_and_usage/columns/consumedunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/consumedunit.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CU1 | MUST | ConsumedUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CU1.1 | MUST | ConsumedUnit MUST be of type String. | Supports |  |
| CU-CU1.2 | MUST | ConsumedUnit MUST conform to StringHandling requirements. | Supports |  |
| CU-CU1.3 | SHOULD | ConsumedUnit SHOULD conform to UnitFormat requirements. | Supports |  |
| CU-CU1.4 | MUST | ConsumedUnit MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CU1.4.1 | MUST | ConsumedUnit MUST be null when ConsumedQuantity is null. | Supports |  |
| CU-CU1.4.2 | MUST | ConsumedUnit MUST NOT be null when ConsumedQuantity is not null. | Supports |  |

### Contract applied (Cost and usage)

A set of properties that associate a charge with one or more contract commitments.

Source: [datasets/cost_and_usage/columns/contractapplied.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/contractapplied.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CA1 | MUST | ContractApplied MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CA1.1 | MUST | ContractApplied MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-CA1.2 | MUST | ContractApplied MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-CA1.3 | MUST | ContractApplied MUST conform to JsonObjectFormat requirements. | Not Evaluated |  |
| CU-CA1.4 | MUST | ContractApplied MUST NOT be null when one or more contract commitments are applied to the charge. | Not Evaluated |  |
| CU-CA1.5 | MUST | ContractApplied MUST conform to ContractAppliedObject requirements when ContractApplied is not null. | Not Evaluated |  |
| CU-CA2 | MUST | ContractAppliedObject MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CA2.1 | MUST | ContractAppliedObject MUST conform to the ContractAppliedObjectSchema JSON Schema. | Not Evaluated |  |
| CU-CA2.2 | MUST | ContractAppliedObject.Elements[\].ContractId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CU-CA2.3 | SHOULD | ContractAppliedObject.Elements[\].ContractId SHOULD be a fully-qualified identifier. | Not Evaluated |  |
| CU-CA2.4 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CU-CA2.5 | SHOULD | ContractAppliedObject.Elements[\].ContractCommitmentId SHOULD be a fully-qualified identifier. | Not Evaluated |  |
| CU-CA2.6 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentId MUST have one and only one parent ContractAppliedObject.Elements[\].ContractId. | Not Evaluated |  |
| CU-CA2.7 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentId MUST match ResourceId when ChargeCategory is "Purchase" and the charge represents a purchase of that contract commitment. | Not Evaluated |  |
| CU-CA2.8 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentId MUST match ResourceId when ChargeCategory is "Usage" and the charge represents an unused portion of that contract commitment. | Not Evaluated |  |
| CU-CA2.9 | MAY | ContractAppliedObject.Elements[\].ContractCommitmentId MAY match ContractAppliedObject.Elements[\].ContractId. | Not Evaluated |  |
| CU-CA2.10 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentAppliedCost MUST be denominated in the BillingCurrency. | Not Evaluated |  |
| CU-CA2.11 | MUST | ContractAppliedObject.Elements[\].ContractCommitmentAppliedQuantity MUST be denominated in the ContractAppliedObject.Elements[\].ContractCommitmentAppliedUnit. | Not Evaluated |  |
| CU-CA2.12 | SHOULD | ContractAppliedObject.Elements[\].ContractCommitmentAppliedUnit SHOULD conform to UnitFormat requirements. | Not Evaluated |  |

### Contracted cost (Cost and usage)

Cost calculated by multiplying contracted unit price and the corresponding Pricing Quantity.

Source: [datasets/cost_and_usage/columns/contractedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/contractedcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CoC1 | MUST | ContractedCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CoC1.1 | MUST | ContractedCost MUST be of type Decimal. | Supports |  |
| CU-CoC1.2 | MUST | ContractedCost MUST conform to NumericFormat requirements. | Supports |  |
| CU-CoC1.3 | MUST | ContractedCost MUST NOT be null. | Partially Supports | `ContractedCost` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CU-CoC1.4 | MUST | ContractedCost MUST be denominated in the BillingCurrency. | Supports |  |
| CU-CoC1.5 | MUST | When ContractedUnitPrice is null, ContractedCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CoC1.5.1 | MUST | ContractedCost of a charge calculated based on other charges (e.g., when the ChargeCategory is "Tax") MUST be calculated based on the ContractedCost of those related charges. | Not Evaluated |  |
| CU-CoC1.5.2 | MUST | ContractedCost of a charge unrelated to other charges (e.g., when the ChargeCategory is "Credit") MUST be equal to the BilledCost. | Not Evaluated |  |
| CU-CoC1.6 | MUST | ContractedCost MUST equal the product of ContractedUnitPrice and PricingQuantity when ContractedUnitPrice is not null and PricingQuantity is not null. | Not Evaluated |  |

### Contracted unit price (Cost and usage)

The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment discounts or any other discounts.

Source: [datasets/cost_and_usage/columns/contractedunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/contractedunitprice.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-CUP1 | MUST | ContractedUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CUP1.1 | MUST | ContractedUnitPrice MUST be of type Decimal. | Supports |  |
| CU-CUP1.2 | MUST | ContractedUnitPrice MUST conform to NumericFormat requirements. | Supports |  |
| CU-CUP1.3 | MUST | ContractedUnitPrice MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-CUP1.3.1 | MUST | ContractedUnitPrice MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-CUP1.3.2 | MUST | ContractedUnitPrice MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-CUP1.3.3 | MUST | ContractedUnitPrice MUST NOT be null when SkuPriceId is not null. | Not Evaluated |  |
| CU-CUP1.3.4 | MUST | ContractedUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Partially Supports | `ContractedUnitPrice` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CU-CUP1.3.5 | MAY | ContractedUnitPrice MAY be null in all other cases. | Supports |  |
| CU-CUP1.4 | MUST | When ContractedUnitPrice is not null, ContractedUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-CUP1.4.1 | MUST | ContractedUnitPrice MUST be a non-negative decimal value. | Not Evaluated |  |
| CU-CUP1.4.2 | MUST | ContractedUnitPrice MUST be denominated in the BillingCurrency. | Not Evaluated |  |

### Effective cost (Cost and usage)

Cost of a charge based on the resources used, services used, or contract commitments recognized in a given charge period.

Source: [datasets/cost_and_usage/columns/effectivecost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/effectivecost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-EC1 | MUST | EffectiveCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-EC1.1 | MUST | EffectiveCost MUST be of type Decimal. | Supports |  |
| CU-EC1.2 | MUST | EffectiveCost MUST conform to NumericFormat requirements. | Supports |  |
| CU-EC1.3 | MUST | EffectiveCost MUST NOT be null. | Supports |  |
| CU-EC1.4 | MUST | EffectiveCost MUST be denominated in the BillingCurrency. | Supports |  |
| CU-EC1.5 | MUST | EffectiveCost MUST reflect all applicable pricing adjustments, including but not limited to negotiated discounts, commitment discounts, and other applicable discount programs. | Not Evaluated |  |
| CU-EC1.6 | MUST | EffectiveCost MUST equal BilledCost when ChargeCategory is "Usage" and the charge is not covered by other eligible charges. | Not Evaluated |  |
| CU-EC1.7 | MUST | EffectiveCost MUST equal BilledCost when ChargeCategory is "Purchase" and the charge is neither intended to cover other eligible charges nor covered by other eligible charges. | Not Evaluated |  |
| CU-EC1.8 | MUST | EffectiveCost MUST equal BilledCost when ChargeCategory is "Tax" or "Credit". | Not Evaluated |  |
| CU-EC1.9 | MAY | EffectiveCost MAY differ from BilledCost when ChargeCategory is "Adjustment". | Not Evaluated |  |
| CU-EC1.10 | MUST | EffectiveCost MUST include any portion of the BilledCost of covering purchase charges (i.e., ChargeCategory is "Purchase") that is applied to this charge. | Not Evaluated |  |
| CU-EC1.11 | MUST | EffectiveCost MUST be 0 when ChargeCategory is "Purchase" and the purchase is intended to cover related eligible charges. | Not Evaluated |  |
| CU-EC1.12 | MUST | EffectiveCost MUST be 0 for charges generated by entities that do not originate the cost and usage data, to avoid double-counting when merging multiple dataset instances. | Not Evaluated |  |
| CU-EC1.13 | MUST | The sum of EffectiveCost across all related covering and covered charges MUST equal the sum of BilledCost across the same set of charges, within the charge period of the covering charges, when both the covering and covered charges are present in the dataset instance. | Not Evaluated |  |
| CU-EC1.14 | MAY | The sum of EffectiveCost for a given billing period MAY differ from the sum of BilledCost when covered and covering charges span multiple billing periods or billing accounts, or when only one side of a covering relationship is present in the dataset instance. | Not Evaluated |  |

### Host provider name (Cost and usage)

The name of the entity whose resources are used by the Service Provider to make their resources or services available.

Source: [datasets/cost_and_usage/columns/hostprovidername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/hostprovidername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-HPN1 | MUST | HostProviderName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-HPN1.1 | MUST | HostProviderName MUST be of type String. | Not Evaluated |  |
| CU-HPN1.2 | MUST | HostProviderName MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-HPN1.3 | MUST | HostProviderName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-HPN1.3.1 | MAY | HostProviderName MAY be NULL when the associated ServiceName does not involve deployment on any underlying infrastructure (e.g., professional services, software licenses). | Not Evaluated |  |
| CU-HPN1.3.2 | MAY | HostProviderName MAY be NULL when the information about the entity providing the underlying infrastructure cannot be uniquely determined (e.g., when the ChargeCategory is "Tax" or "Adjustment"). | Not Evaluated |  |
| CU-HPN1.3.3 | MUST | HostProviderName MUST NOT be null in all other cases. | Not Evaluated |  |
| CU-HPN1.4 | MUST | When HostProviderName is not null, HostProviderName values MUST adhere to the following requirements: | Not Evaluated |  |
| CU-HPN1.4.1 | MUST | HostProviderName MUST reflect the name of the host provider when explicitly selected by the customer. | Not Evaluated |  |
| CU-HPN1.4.2 | MUST | HostProviderName MUST reflect the name of the host provider when the service provider exposes the underlying hosting provider. | Not Evaluated |  |
| CU-HPN1.4.3 | MUST | HostProviderName MUST match ServiceProviderName in all other cases. | Not Evaluated |  |

### Invoice detail ID (Cost and usage)

The invoice-issuer-assigned identifier for an Invoice Detail record encapsulating charges in the corresponding billing period for a given billing account.

Source: [datasets/cost_and_usage/columns/invoicedetailid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/invoicedetailid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-IDI1 | MUST | InvoiceDetailId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-IDI1.1 | MUST | InvoiceDetailId MUST be of type String. | Not Evaluated |  |
| CU-IDI1.2 | MUST | InvoiceDetailId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-IDI1.3 | MUST | InvoiceDetailId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-IDI1.3.1 | MUST | InvoiceDetailId MUST be null when the charge is not associated either with an invoice or with a pre-generated provisional invoice. | Not Evaluated |  |
| CU-IDI1.3.2 | MUST | InvoiceDetailId MUST NOT be null when the charge is associated with either an issued invoice or a pre-generated provisional invoice. | Not Evaluated |  |
| CU-IDI1.4 | MAY | InvoiceDetailId MAY be generated prior to an invoice being issued. | Not Evaluated |  |
| CU-IDI1.5 | MUST | InvoiceDetailId MUST uniquely identify a specific record within a given InvoiceId. | Not Evaluated |  |

### Invoice ID (Cost and usage)

The invoice-issuer-assigned identifier for an invoice encapsulating charges in the corresponding billing period for a given billing account.

Source: [datasets/cost_and_usage/columns/invoiceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/invoiceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-II1 | MUST | InvoiceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-II1.1 | MUST | InvoiceId MUST be of type String. | Supports |  |
| CU-II1.2 | MUST | InvoiceId MUST conform to StringHandling requirements. | Supports |  |
| CU-II1.3 | MUST | InvoiceId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-II1.3.1 | MUST | InvoiceId MUST be null when the charge is not associated either with an invoice or with a pre-generated provisional invoice. | Supports |  |
| CU-II1.3.2 | MUST | InvoiceId MUST NOT be null when the charge is associated with either an issued invoice or a pre-generated provisional invoice. | Partially Supports | Supported for Microsoft Customer Agreement accounts but not for Enterprise Agreement accounts. |
| CU-II1.4 | MAY | InvoiceId MAY be generated prior to an invoice being issued. | Not Applicable |  |
| CU-II1.5 | MUST | InvoiceId MUST be associated with the related charge and BillingAccountId when a pre-generated invoice or provisional invoice exists. | Supports |  |

### Invoice issuer name (Cost and usage)

The name of the entity responsible for invoicing for the resources or services consumed.

Source: [datasets/cost_and_usage/columns/invoiceissuername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/invoiceissuername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-IIN1 | MUST | InvoiceIssuerName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-IIN1.1 | MUST | InvoiceIssuerName MUST be of type String. | Supports |  |
| CU-IIN1.2 | MUST | InvoiceIssuerName MUST conform to StringHandling requirements. | Supports |  |
| CU-IIN1.3 | MUST | InvoiceIssuerName MUST NOT be null. | Supports |  |
| CU-IIN1.4 | MUST | InvoiceIssuerName MUST represent the entity that issues invoices. | Not Evaluated |  |

### List cost (Cost and usage)

Cost calculated by multiplying List Unit Price and the corresponding Pricing Quantity.

Source: [datasets/cost_and_usage/columns/listcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/listcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-LC1 | MUST | ListCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-LC1.1 | MUST | ListCost MUST be of type Decimal. | Supports |  |
| CU-LC1.2 | MUST | ListCost MUST conform to NumericFormat requirements. | Supports |  |
| CU-LC1.3 | MUST | ListCost MUST NOT be null. | Partially Supports | `ListCost` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| CU-LC1.4 | MUST | ListCost MUST be denominated in the BillingCurrency. | Supports |  |
| CU-LC1.5 | MUST | When ListUnitPrice is null, ListCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-LC1.5.1 | MUST | ListCost of a charge calculated based on other charges (e.g., when the ChargeCategory is "Tax") MUST be calculated based on the ListCost of those related charges. | Not Evaluated |  |
| CU-LC1.5.2 | MUST | ListCost of a charge unrelated to other charges (e.g., when the ChargeCategory is "Credit") MUST be equal to the BilledCost. | Not Evaluated |  |
| CU-LC1.6 | MUST | ListCost MUST equal the product of ListUnitPrice and PricingQuantity when ListUnitPrice is not null and PricingQuantity is not null. | Not Evaluated |  |

### List unit price (Cost and usage)

The suggested service-provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts.

Source: [datasets/cost_and_usage/columns/listunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/listunitprice.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-LUP1 | MUST | ListUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-LUP1.1 | MUST | ListUnitPrice MUST be of type Decimal. | Supports |  |
| CU-LUP1.2 | MUST | ListUnitPrice MUST conform to NumericFormat requirements. | Supports |  |
| CU-LUP1.3 | MUST | ListUnitPrice MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-LUP1.3.1 | MUST | ListUnitPrice MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-LUP1.3.2 | MUST | ListUnitPrice MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-LUP1.3.3 | MUST | ListUnitPrice MUST NOT be null when SkuPriceId is not null. | Not Evaluated |  |
| CU-LUP1.3.4 | MUST | ListUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Partially Supports | `ListUnitPrice` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| CU-LUP1.3.5 | MAY | ListUnitPrice MAY be null in all other cases. | Supports |  |
| CU-LUP1.4 | MUST | When ListUnitPrice is not null, ListUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-LUP1.4.1 | MUST | ListUnitPrice MUST be a non-negative decimal value. | Not Evaluated |  |
| CU-LUP1.4.2 | MUST | ListUnitPrice MUST be denominated in the BillingCurrency. | Not Evaluated |  |

### Pricing category (Cost and usage)

Describes the pricing model used for a charge at the time of use or purchase.

Source: [datasets/cost_and_usage/columns/pricingcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingcategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PC1 | MUST | PricingCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PC1.1 | MUST | PricingCategory MUST be of type String. | Supports |  |
| CU-PC1.2 | MUST | PricingCategory MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-PC1.2.1 | MUST | PricingCategory MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-PC1.2.2 | MUST | PricingCategory MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-PC1.2.3 | MUST | PricingCategory MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Supports |  |
| CU-PC1.2.4 | MAY | PricingCategory MAY be null in all other cases. | Supports |  |
| CU-PC1.3 | MUST | When PricingCategory is not null, PricingCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PC1.3.1 | MUST | PricingCategory MUST be one of the allowed values. | Supports |  |
| CU-PC1.3.2 | MUST | PricingCategory MUST be "Standard" when pricing is predetermined at the agreed upon rate for the billing account. | Supports |  |
| CU-PC1.3.3 | MUST | PricingCategory MUST be "Committed" when the charge is subject to an existing commitment discount and is not the purchase of the commitment discount. | Supports |  |
| CU-PC1.3.4 | MUST | PricingCategory MUST be "Dynamic" when pricing is determined by the service provider and may change over time, regardless of predetermined agreement pricing. | Not Evaluated |  |
| CU-PC1.3.5 | MUST | PricingCategory MUST be "Other" when there is a pricing model but none of the allowed values apply. | Supports |  |

### Pricing currency (Cost and usage)

The national or virtual currency denomination that a resource or service was priced in.

Source: [datasets/cost_and_usage/columns/pricingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PrC1 | MUST | PricingCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PrC1.1 | MUST | PricingCurrency MUST be of type String. | Supports |  |
| CU-PrC1.2 | MUST | PricingCurrency MUST conform to StringHandling requirements. | Supports |  |
| CU-PrC1.3 | MUST | PricingCurrency MUST conform to CurrencyFormat requirements. | Supports |  |
| CU-PrC1.4 | MUST | PricingCurrency MUST NOT be null. | Supports |  |

### Pricing currency contracted unit price (Cost and usage)

The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment discounts or any other discounts, and expressed in Pricing Currency.

Source: [datasets/cost_and_usage/columns/pricingcurrencycontractedunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingcurrencycontractedunitprice.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PCCUP1 | MUST | PricingCurrencyContractedUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PCCUP1.1 | MUST | PricingCurrencyContractedUnitPrice MUST be of type Decimal. | Not Applicable |  |
| CU-PCCUP1.2 | MUST | PricingCurrencyContractedUnitPrice MUST conform to NumericFormat requirements. | Not Applicable |  |
| CU-PCCUP1.3 | MUST | PricingCurrencyContractedUnitPrice MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-PCCUP1.3.1 | MUST | PricingCurrencyContractedUnitPrice MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-PCCUP1.3.2 | MUST | PricingCurrencyContractedUnitPrice MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-PCCUP1.3.3 | MUST | PricingCurrencyContractedUnitPrice MUST NOT be null when SkuPriceId is not null. | Not Evaluated |  |
| CU-PCCUP1.3.4 | MUST | PricingCurrencyContractedUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Not Applicable |  |
| CU-PCCUP1.3.5 | MAY | PricingCurrencyContractedUnitPrice MAY be null in all other cases. | Not Applicable |  |
| CU-PCCUP1.4 | MUST | When PricingCurrencyContractedUnitPrice is not null, PricingCurrencyContractedUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PCCUP1.4.1 | MUST | PricingCurrencyContractedUnitPrice MUST be a non-negative decimal value. | Not Applicable |  |
| CU-PCCUP1.4.2 | MUST | PricingCurrencyContractedUnitPrice MUST be denominated in the PricingCurrency. | Not Applicable |  |

### Pricing currency effective cost (Cost and usage)

The PricingCurrency-denominated equivalent of Effective Cost, representing the cost of a charge based on the resources used, services used, or contract commitments recognized in a given charge period.

Source: [datasets/cost_and_usage/columns/pricingcurrencyeffectivecost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingcurrencyeffectivecost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PCEC1 | MUST | PricingCurrencyEffectiveCost MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PCEC1.1 | MUST | PricingCurrencyEffectiveCost MUST be of type Decimal. | Not Applicable |  |
| CU-PCEC1.2 | MUST | PricingCurrencyEffectiveCost MUST conform to NumericFormat requirements. | Not Applicable |  |
| CU-PCEC1.3 | MUST | PricingCurrencyEffectiveCost MUST NOT be null. | Not Applicable |  |
| CU-PCEC1.4 | MUST | PricingCurrencyEffectiveCost MUST be denominated in the PricingCurrency. | Not Applicable |  |
| CU-PCEC1.5 | MUST | PricingCurrencyEffectiveCost MUST be the PricingCurrency-denominated equivalent of EffectiveCost. | Not Evaluated |  |

### Pricing currency list unit price (Cost and usage)

The suggested service-provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts and expressed in Pricing Currency.

Source: [datasets/cost_and_usage/columns/pricingcurrencylistunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingcurrencylistunitprice.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PCLUP1 | MUST | PricingCurrencyListUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PCLUP1.1 | MUST | PricingCurrencyListUnitPrice MUST be of type Decimal. | Not Applicable |  |
| CU-PCLUP1.2 | MUST | PricingCurrencyListUnitPrice MUST conform to NumericFormat requirements. | Not Applicable |  |
| CU-PCLUP1.3 | MUST | PricingCurrencyListUnitPrice MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-PCLUP1.3.1 | MUST | PricingCurrencyListUnitPrice MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-PCLUP1.3.2 | MUST | PricingCurrencyListUnitPrice MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-PCLUP1.3.3 | MUST | PricingCurrencyListUnitPrice MUST NOT be null when SkuPriceId is not null. | Not Evaluated |  |
| CU-PCLUP1.3.4 | MUST | PricingCurrencyListUnitPrice MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Not Applicable |  |
| CU-PCLUP1.3.5 | MAY | PricingCurrencyListUnitPrice MAY be null in all other cases. | Not Applicable |  |
| CU-PCLUP1.4 | MUST | When PricingCurrencyListUnitPrice is not null, PricingCurrencyListUnitPrice MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PCLUP1.4.1 | MUST | PricingCurrencyListUnitPrice MUST be a non-negative decimal value. | Not Applicable |  |
| CU-PCLUP1.4.2 | MUST | PricingCurrencyListUnitPrice MUST be denominated in the PricingCurrency. | Not Applicable |  |

### Pricing quantity (Cost and usage)

The volume of a given SKU associated with a resource or service used or purchased, based on the Pricing Unit.

Source: [datasets/cost_and_usage/columns/pricingquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingquantity.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PQ1 | MUST | PricingQuantity MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PQ1.1 | MUST | PricingQuantity MUST be of type Decimal. | Supports |  |
| CU-PQ1.2 | MUST | PricingQuantity MUST conform to NumericFormat requirements. | Supports |  |
| CU-PQ1.3 | MUST | PricingQuantity MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-PQ1.3.1 | MUST | PricingQuantity MUST be null when SkuPriceId is null. | Not Evaluated |  |
| CU-PQ1.3.2 | MUST | PricingQuantity MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-PQ1.3.3 | MUST | PricingQuantity MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Supports |  |
| CU-PQ1.3.4 | MAY | PricingQuantity MAY be null in all other cases. | Supports |  |
| CU-PQ1.4 | MUST | Cost metric (e.g., ContractedCost) MUST equal the product of the corresponding unit price (e.g., ContractedUnitPrice) and PricingQuantity when the unit price is not null and PricingQuantity is not null. | Not Evaluated |  |

### Pricing unit (Cost and usage)

Service-provider-specified measurement unit for determining unit prices, indicating how the service provider rates measured usage and purchase quantities after applying pricing rules like block pricing.

Source: [datasets/cost_and_usage/columns/pricingunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/pricingunit.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-PU1 | MUST | PricingUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PU1.1 | MUST | PricingUnit MUST be of type String. | Supports |  |
| CU-PU1.2 | MUST | PricingUnit MUST conform to StringHandling requirements. | Supports |  |
| CU-PU1.3 | SHOULD | PricingUnit SHOULD conform to UnitFormat requirements. | Supports |  |
| CU-PU1.4 | MUST | PricingUnit MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-PU1.4.1 | MUST | PricingUnit MUST be null when PricingQuantity is null. | Supports |  |
| CU-PU1.4.2 | MUST | PricingUnit MUST NOT be null when PricingQuantity is not null. | Supports |  |
| CU-PU1.5 | MUST | When PricingUnit is not null, PricingUnit MUST adhere to the following requirements: | Not Evaluated |  |
| CU-PU1.5.1 | MUST | PricingUnit MUST be semantically equal to the corresponding pricing measurement unit provided in service-provider-published price list. | Not Evaluated |  |
| CU-PU1.5.2 | MUST | PricingUnit MUST be semantically equal to the corresponding pricing measurement unit provided in invoice, when the invoice includes a pricing measurement unit. | Supports |  |

### Region ID (Cost and usage)

Host-provider-assigned identifier for an isolated geographic area where a resource is provisioned or a service is provided.

Source: [datasets/cost_and_usage/columns/regionid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/regionid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-RI1 | MUST | RegionId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-RI1.1 | MUST | RegionId MUST be of type String. | Supports |  |
| CU-RI1.2 | MUST | RegionId MUST conform to StringHandling requirements. | Supports |  |
| CU-RI1.3 | MUST | RegionId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-RI1.3.1 | MUST | RegionId MUST NOT be null when a resource or service is operated in or managed from a distinct region. | Supports |  |
| CU-RI1.3.2 | MAY | RegionId MAY be null when a resource or service is not operated in or managed from a distinct region. | Supports |  |

### Region name (Cost and usage)

The name of an isolated geographic area where a resource is provisioned or a service is provided.

Source: [datasets/cost_and_usage/columns/regionname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/regionname.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-RN1 | MUST | RegionName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-RN1.1 | MUST | RegionName MUST be of type String. | Supports |  |
| CU-RN1.2 | MUST | RegionName MUST conform to StringHandling requirements. | Supports |  |
| CU-RN1.3 | MUST | RegionName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-RN1.3.1 | MUST | RegionName MUST be null when RegionId is null. | Supports |  |
| CU-RN1.3.2 | MUST | RegionName MUST NOT be null when RegionId is not null. | Supports |  |

### Resource ID (Cost and usage)

Identifier assigned to a resource by the service provider.

Source: [datasets/cost_and_usage/columns/resourceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/resourceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-ReI1 | MUST | ResourceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ReI1.1 | MUST | ResourceId MUST be of type String. | Supports |  |
| CU-ReI1.2 | MUST | ResourceId MUST conform to StringHandling requirements. | Supports |  |
| CU-ReI1.3 | MUST | ResourceId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-ReI1.3.1 | MUST | ResourceId MUST be null when a charge is not related to a resource. | Supports | Purchases may not have an assigned resource ID. |
| CU-ReI1.3.2 | MUST | ResourceId MUST NOT be null when a charge is related to a resource. | Supports | `ResourceId` may be null when a resource is indirectly related to the charges. If you feel it's missing, file a support request for the service that owns the resource type. |
| CU-ReI1.4 | MUST | When ResourceId is not null, ResourceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ReI1.4.1 | MUST | ResourceId MUST be a unique identifier within the service provider. | Not Evaluated |  |
| CU-ReI1.4.2 | SHOULD | ResourceId SHOULD be a fully-qualified identifier. | Supports |  |
| CU-ReI1.4.3 | MUST | ResourceId MUST be the identifier of the resource that received the commitment discount when CommitmentDiscountStatus is "Used". | Not Evaluated |  |

### Resource name (Cost and usage)

Display name assigned to a resource.

Source: [datasets/cost_and_usage/columns/resourcename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/resourcename.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-ReN1 | MUST | ResourceName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-ReN1.1 | MUST | ResourceName MUST be of type String. | Supports |  |
| CU-ReN1.2 | MUST | ResourceName MUST conform to StringHandling requirements. | Supports |  |
| CU-ReN1.3 | MUST | ResourceName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-ReN1.3.1 | MUST | ResourceName MUST be null when ResourceId is null or when the resource does not have an assigned display name. | Supports |  |
| CU-ReN1.3.2 | MUST | ResourceName MUST NOT be null when ResourceId is not null and the resource has an assigned display name. | Supports |  |
| CU-ReN1.4 | MUST | ResourceName MUST NOT duplicate ResourceId when the resource is not provisioned interactively or only has a system-generated ResourceId. | Supports |  |

### Resource type (Cost and usage)

The kind of resource the charge applies to.

Source: [datasets/cost_and_usage/columns/resourcetype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/resourcetype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-RT1 | MUST | ResourceType MUST adhere to the following requirements: | Not Evaluated |  |
| CU-RT1.1 | MUST | ResourceType MUST be of type String. | Supports |  |
| CU-RT1.2 | MUST | ResourceType MUST conform to StringHandling requirements. | Supports |  |
| CU-RT1.3 | MUST | ResourceType MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-RT1.3.1 | MUST | ResourceType MUST be null when ResourceId is null. | Supports |  |
| CU-RT1.3.2 | MUST | ResourceType MUST NOT be null when ResourceId is not null. | Supports |  |

### Service category (Cost and usage)

Highest-level classification of a service based on the core function of the service.

Source: [datasets/cost_and_usage/columns/servicecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/servicecategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SC1 | MUST | ServiceCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SC1.1 | MUST | ServiceCategory MUST be of type String. | Supports |  |
| CU-SC1.2 | MUST | ServiceCategory MUST NOT be null. | Supports |  |
| CU-SC1.3 | MUST | ServiceCategory MUST be one of the allowed values. | Supports |  |

### Service name (Cost and usage)

An offering that can be purchased from a service provider (e.g., cloud virtual machine, SaaS database, professional services from a systems integrator).

Source: [datasets/cost_and_usage/columns/servicename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/servicename.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SN1 | MUST | ServiceName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SN1.1 | MUST | ServiceName MUST be of type String. | Supports |  |
| CU-SN1.2 | MUST | ServiceName MUST conform to StringHandling requirements. | Supports |  |
| CU-SN1.3 | MUST | ServiceName MUST NOT be null. | Partially Supports | `ServiceName` may be empty for some purchases and adjustments. |
| CU-SN1.4 | MUST | The relationship between ServiceName and ServiceCategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SN1.4.1 | MUST | ServiceName MUST have one and only one ServiceCategory that best aligns with its primary purpose, except when no suitable ServiceCategory is available. | Supports |  |
| CU-SN1.4.2 | MUST | ServiceName MUST be associated with the ServiceCategory "Other" when no suitable ServiceCategory is available. | Supports |  |
| CU-SN1.5 | MUST | The relationship between ServiceName and ServiceSubcategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SN1.5.1 | SHOULD | ServiceName SHOULD have one and only one ServiceSubcategory that best aligns with its primary purpose, except when no suitable ServiceSubcategory is available. | Supports |  |
| CU-SN1.5.2 | SHOULD | ServiceName SHOULD be associated with the ServiceSubcategory "Other" when no suitable ServiceSubcategory is available. | Supports |  |

### Service provider name (Cost and usage)

The name of the entity that made the resources or services available for purchase or consumption.

Source: [datasets/cost_and_usage/columns/serviceprovidername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/serviceprovidername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SPN1 | MUST | ServiceProviderName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPN1.1 | MUST | ServiceProviderName MUST be of type String. | Not Evaluated |  |
| CU-SPN1.2 | MUST | ServiceProviderName MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-SPN1.3 | MUST | ServiceProviderName MUST NOT be null. | Not Evaluated |  |

### Service subcategory (Cost and usage)

Secondary classification of the Service Category for a service based on its core function.

Source: [datasets/cost_and_usage/columns/servicesubcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/servicesubcategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SS1 | MUST | ServiceSubcategory MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SS1.1 | MUST | ServiceSubcategory MUST be of type String. | Supports |  |
| CU-SS1.2 | MUST | ServiceSubcategory MUST NOT be null. | Supports |  |
| CU-SS1.3 | MUST | ServiceSubcategory MUST be one of the allowed values. | Supports |  |
| CU-SS1.4 | MUST | ServiceSubcategory MUST have one and only one parent ServiceCategory as specified in the allowed values below. | Supports |  |

### SKU ID (Cost and usage)

Service-provider-specified unique identifier that represents a specific SKU (e.g., a quantifiable good or service offering).

Source: [datasets/cost_and_usage/columns/skuid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/skuid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SI1 | MUST | SkuId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SI1.1 | MUST | SkuId MUST be of type String. | Supports |  |
| CU-SI1.2 | MUST | SkuId MUST conform to StringHandling requirements. | Supports |  |
| CU-SI1.3 | MUST | SkuId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SI1.3.1 | MUST | SkuId MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-SI1.3.2 | MUST | SkuId MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Partially Supports | `SkuId` may be null for some rows like savings plan unused charges and Marketplace charges. |
| CU-SI1.3.3 | MAY | SkuId MAY be null in all other cases. | Supports |  |
| CU-SI1.4 | MUST | SkuId for a given SKU MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SI1.4.1 | MUST | SkuId MUST remain consistent across billing accounts or contracts. | Supports |  |
| CU-SI1.4.2 | MUST | SkuId MUST remain consistent across PricingCategory values. | Partially Supports | `SkuId` may be different for some `PricingCategory` values. |
| CU-SI1.4.3 | MUST | SkuId MUST remain consistent regardless of any other factors that might impact the price but do not affect the functionality of the SKU. | Partially Supports | `SkuId` may be different for some SKUs that offer the same functionality. |
| CU-SI1.5 | MUST | SkuId MUST be associated with a given resource or service when ChargeCategory is "Usage" or "Purchase". | Supports |  |
| CU-SI1.6 | MAY | SkuId MAY match SkuPriceId. | Not Evaluated |  |

### SKU meter (Cost and usage)

Describes the functionality being metered or measured by a particular SKU in a charge.

Source: [datasets/cost_and_usage/columns/skumeter.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/skumeter.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SM1 | MUST | SkuMeter MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SM1.1 | MUST | SkuMeter MUST be of type String. | Supports |  |
| CU-SM1.2 | MUST | SkuMeter MUST conform to StringHandling requirements. | Supports |  |
| CU-SM1.3 | MUST | SkuMeter MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SM1.3.1 | MUST | SkuMeter MUST be null when SkuId is null. | Supports |  |
| CU-SM1.3.2 | SHOULD | SkuMeter SHOULD NOT be null when SkuId is not null. | Supports |  |
| CU-SM1.4 | SHOULD | SkuMeter SHOULD remain consistent over time for a given SkuId. | Partially Supports | `SkuMeter` may be different for a given `SkuId`. |

### SKU price details (Cost and usage)

A set of properties of a SKU Price ID which are meaningful and common to all instances of that SKU Price ID.

Source: [datasets/cost_and_usage/columns/skupricedetails.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/skupricedetails.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SPD1 | MUST | SkuPriceDetails MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPD1.1 | MUST | SkuPriceDetails MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-SPD1.2 | MUST | SkuPriceDetails MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-SPD1.3 | MUST | SkuPriceDetails MUST conform to KeyValueFormat requirements. | Not Applicable |  |
| CU-SPD1.4 | SHOULD | SkuPriceDetails property keys SHOULD conform to PascalCase format. | Not Applicable |  |
| CU-SPD1.5 | MUST | SkuPriceDetails MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SPD1.5.1 | MUST | SkuPriceDetails MUST be null when SkuPriceId is null. | Not Applicable |  |
| CU-SPD1.5.2 | MAY | SkuPriceDetails MAY be null when SkuPriceId is not null. | Not Applicable |  |
| CU-SPD1.6 | MUST | When SkuPriceDetails is not null, SkuPriceDetails MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPD1.6.1 | MUST | SkuPriceDetails MUST be associated with a given SkuPriceId. | Not Applicable |  |
| CU-SPD1.6.2 | MUST | SkuPriceDetails MUST include the FOCUS-defined SKU Price property when an equivalent property is included as a custom property. | Not Evaluated |  |
| CU-SPD1.6.3 | MUST | SkuPriceDetails MUST NOT include properties that are not applicable to the corresponding SkuPriceId. | Not Applicable |  |
| CU-SPD1.6.4 | SHOULD | SkuPriceDetails SHOULD include all FOCUS-defined SKU Price properties listed below that are applicable to the corresponding SkuPriceId. | Not Applicable |  |
| CU-SPD1.6.5 | SHOULD | SkuPriceDetails SHOULD include all custom SKU Price properties that are applicable to the corresponding SkuPriceId when there is no equivalent FOCUS-defined property. | Not Evaluated |  |
| CU-SPD1.6.6 | MAY | SkuPriceDetails MAY include properties that are already captured in other dedicated columns. | Not Applicable |  |
| CU-SPD1.6.7 | MUST | SkuPriceDetails properties for a given SkuPriceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPD1.6.7.1 | SHOULD | Existing SkuPriceDetails properties SHOULD remain consistent over time. | Not Applicable |  |
| CU-SPD1.6.7.2 | SHOULD | Existing SkuPriceDetails properties SHOULD NOT be removed. | Not Applicable |  |
| CU-SPD1.6.7.3 | MAY | Additional SkuPriceDetails properties MAY be added over time. | Not Applicable |  |
| CU-SPD1.6.8 | SHOULD | Property key SHOULD remain consistent across comparable SKUs having that property, and the values for this key SHOULD remain in a consistent format. | Not Applicable |  |
| CU-SPD1.6.9 | SHOULD | Property key SHOULD remain consistent across comparable SKUs having that property, and the values for this key SHOULD remain in a consistent format. | Not Applicable |  |
| CU-SPD1.6.10 | MUST | Property key MUST begin with the string "x_" unless it is a FOCUS-defined property. | Not Applicable |  |
| CU-SPD1.6.11 | MUST | Property value MUST represent the value for a single PricingUnit when the property holds a numeric value. | Not Applicable |  |
| CU-SPD1.7 | MUST | FOCUS-defined SKU Price properties MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPD1.7.1 | MUST | Property key MUST match the spelling and casing specified for the FOCUS-defined property. | Not Applicable |  |
| CU-SPD1.7.2 | MUST | Property value MUST be of the type specified for that property. | Not Applicable |  |
| CU-SPD1.7.3 | MUST | Property value MUST represent the value for a single PricingUnit, denominated in the unit of measure specified for that property when the property holds a numeric value. | Not Applicable |  |

### SKU price ID (Cost and usage)

A service-provider-specified unique identifier that represents a specific SKU Price associated with a resource or service used or purchased.

Source: [datasets/cost_and_usage/columns/skupriceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/skupriceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SPI1 | MUST | SkuPriceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPI1.1 | MUST | SkuPriceId MUST be of type String. | Supports |  |
| CU-SPI1.2 | MUST | SkuPriceId MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-SPI1.3 | MUST | SkuPriceId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SPI1.3.1 | MUST | SkuPriceId MUST be null when ChargeCategory is "Tax". | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| CU-SPI1.3.2 | MUST | SkuPriceId MUST NOT be null when ChargeCategory is "Usage" or "Purchase" and ChargeClass is not "Correction". | Partially Supports | `SkuPriceId` may be null for some rows like savings plan unused charges and Marketplace charges. |
| CU-SPI1.3.3 | MAY | SkuPriceId MAY be null in all other cases. | Supports |  |
| CU-SPI1.4 | MUST | When SkuPriceId is not null, SkuPriceId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SPI1.4.1 | MUST | SkuPriceId MUST have one and only one parent SkuId. | Not Evaluated |  |
| CU-SPI1.4.2 | MUST | SkuPriceId MUST remain consistent over time. | Not Evaluated |  |
| CU-SPI1.4.3 | MUST | SkuPriceId MUST remain consistent across billing accounts or contracts. | Not Evaluated |  |
| CU-SPI1.4.4 | MAY | SkuPriceId MAY match SkuId. | Not Evaluated |  |
| CU-SPI1.4.5 | MUST | SkuPriceId MUST be associated with a given resource or service when ChargeCategory is "Usage" or "Purchase". | Not Evaluated |  |
| CU-SPI1.4.6 | MUST | SkuPriceId MUST reference a SKU Price in a service-provider-supplied price list, enabling the lookup of detailed information about the SKU Price. | Not Evaluated |  |
| CU-SPI1.4.7 | MUST | SkuPriceId MUST be a valid reference to the ListUnitPrice when the service provider publishes unit prices exclusive of discounts. | Not Evaluated |  |
| CU-SPI1.4.8 | MUST | SkuPriceId MUST be a valid reference to the ContractedUnitPrice when the service provider supports negotiated pricing concepts. | Not Evaluated |  |

### Sub account ID (Cost and usage)

An ID assigned to a grouping of resources or services, often used to manage access and/or cost.

Source: [datasets/cost_and_usage/columns/subaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/subaccountid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SAI1 | MUST | SubAccountId MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SAI1.1 | MUST | SubAccountId MUST be of type String. | Supports |  |
| CU-SAI1.2 | MUST | SubAccountId MUST conform to StringHandling requirements. | Supports |  |
| CU-SAI1.3 | MUST | SubAccountId MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SAI1.3.1 | MUST | SubAccountId MUST be null when a charge is not related to a sub account. | Supports | `SubAccountId` may be null for MCA purchases and refunds. |
| CU-SAI1.3.2 | MUST | SubAccountId MUST NOT be null when a charge is related to a sub account. | Supports |  |

### Sub account name (Cost and usage)

A name assigned to a grouping of resources or services, often used to manage access and/or cost.

Source: [datasets/cost_and_usage/columns/subaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/subaccountname.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SAN1 | MUST | SubAccountName MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SAN1.1 | MUST | SubAccountName MUST be of type String. | Supports |  |
| CU-SAN1.2 | MUST | SubAccountName MUST conform to StringHandling requirements. | Supports |  |
| CU-SAN1.3 | MUST | SubAccountName MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SAN1.3.1 | MUST | SubAccountName MUST be null when SubAccountId is null. | Supports |  |
| CU-SAN1.3.2 | MUST | SubAccountName MUST NOT be null when SubAccountId is not null. | Supports |  |

### Sub account type (Cost and usage)

A service-provider-assigned name to identify the type of sub account.

Source: [datasets/cost_and_usage/columns/subaccounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/subaccounttype.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-SAT1 | MUST | SubAccountType MUST adhere to the following requirements: | Not Evaluated |  |
| CU-SAT1.1 | MUST | SubAccountType MUST be of type String. | Supports |  |
| CU-SAT1.2 | MUST | SubAccountType MUST conform to StringHandling requirements. | Supports |  |
| CU-SAT1.3 | MUST | SubAccountType MUST adhere to the following nullability requirements: | Not Evaluated |  |
| CU-SAT1.3.1 | MUST | SubAccountType MUST be null when SubAccountId is null. | Supports |  |
| CU-SAT1.3.2 | MUST | SubAccountType MUST NOT be null when SubAccountId is not null. | Supports |  |
| CU-SAT1.4 | MUST | SubAccountType MUST be a consistent, readable display value. | Supports |  |

### Tags (Cost and usage)

The set of tags assigned to tag sources that account for potential provider-defined or user-defined tag evaluations.

Source: [datasets/cost_and_usage/columns/tags.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/cost_and_usage/columns/tags.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| CU-T1 | MUST | Tags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-T1.1 | MUST | Tags MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| CU-T1.2 | MUST | Tags MUST conform to StringHandling requirements. | Not Evaluated |  |
| CU-T1.3 | MUST | Tags MUST conform to KeyValueFormat requirements. | Supports |  |
| CU-T1.4 | MAY | Tags MAY be null. | Supports |  |
| CU-T1.5 | MUST | When Tags is not null, Tags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-T1.5.1 | MUST | Tags MUST include all user-defined and provider-defined tags. | Supports |  |
| CU-T1.5.2 | MUST | Tags MUST only include finalized tags. | Supports |  |
| CU-T1.5.3 | SHOULD | Tags SHOULD include tag keys with corresponding non-null values for a given resource. | Supports |  |
| CU-T1.5.4 | MAY | Tags MAY include tag keys with a null value for a given resource depending on the data generator's tag finalization process. | Not Evaluated |  |
| CU-T1.5.5 | MUST | Tag keys that do not support corresponding values, MUST have a corresponding true (boolean) value set. | Not Applicable | Microsoft Cloud tags support both keys and values. |
| CU-T1.5.6 | MUST | Tag values MUST match the provided values unless true (boolean) is applied to valueless tags. | Not Evaluated |  |
| CU-T1.6 | MUST | Provider-defined tags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-T1.6.1 | MUST | Provider-defined tag keys MUST be prefixed with a predetermined, provider-specified tag key prefix that is unique to each corresponding provider-specified tag scheme. | Does Not Support | Provider-specified tags can't be differentiated from user-defined tags. Tags aren't modified to support backwards compatibility. |
| CU-T1.6.2 | SHOULD | Provider-specified tag key prefixes SHOULD be publicly documented. | Not Evaluated |  |
| CU-T1.7 | MUST | User-defined tags MUST adhere to the following requirements: | Not Evaluated |  |
| CU-T1.7.1 | MUST | User-defined tag keys in all but one user-defined tag scheme MUST include a predetermined, provider-specified tag key prefix that is unique to each corresponding user-defined tag scheme when the data generator has more than one user-defined tag scheme. | Not Evaluated |  |
| CU-T1.7.2 | MUST | User-defined tag keys MUST NOT include a tag scheme-specific prefix when the data generator has only one user-defined tag scheme. | Not Evaluated |  |
| CU-T1.7.3 | MUST | Reserved tag key prefixes MUST be prevented from being used as prefixes for any user-defined tag keys within a prefixless user-defined tag scheme. | Not Evaluated |  |
| CU-T1.8 | MUST | Tag finalization documentation MUST adhere to the following requirements: | Not Evaluated |  |
| CU-T1.8.1 | SHOULD | Tag finalization documentation SHOULD include tag finalization methods and semantics. | Not Evaluated |  |
| CU-T1.8.2 | SHOULD | Tag finalization documentation SHOULD be accessible to practitioners. | Not Evaluated |  |

### Billed cost (Invoice detail)

Cost of a charge as invoiced by the invoice issuer in a given billing period.

Source: [datasets/invoice_detail/columns/billedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/billedcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-BC1 | MUST | BilledCost MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BC1.1 | MUST | BilledCost MUST be of type Decimal. | Not Evaluated |  |
| ID-BC1.2 | MUST | BilledCost MUST conform to NumericFormat requirements. | Not Evaluated |  |
| ID-BC1.3 | MUST | BilledCost MUST NOT be null. | Not Evaluated |  |
| ID-BC1.4 | MUST | BilledCost MUST be denominated in the BillingCurrency. | Not Evaluated |  |
| ID-BC1.5 | MUST | BilledCost MUST reflect all applicable pricing adjustments, including but not limited to negotiated discounts, commitment discounts, and other applicable discount programs. | Not Evaluated |  |
| ID-BC1.6 | MUST | BilledCost MUST NOT include any portion of a covered charge that is offset by a covering charge. | Not Evaluated |  |
| ID-BC1.7 | MUST | BilledCost MUST be 0 for charges that are fully covered by one or more covering charges. | Not Evaluated |  |
| ID-BC1.8 | MUST | The sum of BilledCost for a given InvoiceDetailId, InvoiceId, and InvoiceIssuerName MUST be equal to the payable amount provided in the corresponding entries on the issued invoice when InvoiceIssueStatus is "Issued". | Not Evaluated |  |
| ID-BC1.9 | MUST | When comparing BilledCost aggregated by InvoiceId and InvoiceIssuerName with CostAndUsage.BilledCost aggregated by CostAndUsage.InvoiceId and CostAndUsage.InvoiceIssuerName, BilledCost MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BC1.9.1 | MUST | When ChargeCategory is not "Tax" and InvoiceIssueStatus is not "Open", the sum of BilledCost MUST NOT differ from the sum of CostAndUsage.BilledCost by more than `MAX(100 × Subunit, (SQRT(Rows) × 0.5) × Subunit)` as defined in Rounding Variance Tolerance. | Not Evaluated |  |
| ID-BC1.9.2 | MAY | When ChargeCategory is "Tax" or InvoiceIssueStatus is "Open", the sum of BilledCost MAY differ from the sum of CostAndUsage.BilledCost. | Not Evaluated |  |
| ID-BC1.10 | MUST | When comparing BilledCost aggregated by InvoiceDetailId, InvoiceId, and InvoiceIssuerName with CostAndUsage.BilledCost aggregated by CostAndUsage.InvoiceDetailId, CostAndUsage.InvoiceId, and CostAndUsage.InvoiceIssuerName, BilledCost MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BC1.10.1 | MUST | When InvoiceIssueStatus is not "Open", the sum of BilledCost MUST NOT differ from the sum of CostAndUsage.BilledCost by more than `MAX(100 × Subunit, (SQRT(Rows) × 0.5) × Subunit)` as defined in Rounding Variance Tolerance. | Not Evaluated |  |
| ID-BC1.10.2 | MAY | When InvoiceIssueStatus is "Open", the sum of BilledCost MAY differ from the sum of CostAndUsage.BilledCost. | Not Evaluated |  |

### Billing account ID (Invoice detail)

The identifier assigned to a billing account by the invoice issuer.

Source: [datasets/invoice_detail/columns/billingaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/billingaccountid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-BAI1 | MUST | BillingAccountId MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BAI1.1 | MUST | BillingAccountId MUST be of type String. | Not Evaluated |  |
| ID-BAI1.2 | MUST | BillingAccountId MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-BAI1.3 | MUST | BillingAccountId MUST NOT be null. | Not Evaluated |  |
| ID-BAI1.4 | MUST | BillingAccountId MUST be a unique identifier within an invoice issuer. | Not Evaluated |  |
| ID-BAI1.5 | SHOULD | BillingAccountId SHOULD be a fully-qualified identifier. | Not Evaluated |  |

### Billing currency (Invoice detail)

Represents the currency that a charge was billed in.

Source: [datasets/invoice_detail/columns/billingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/billingcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-BiC1 | MUST | BillingCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BiC1.1 | MUST | BillingCurrency MUST be of type String. | Not Evaluated |  |
| ID-BiC1.2 | MUST | BillingCurrency MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-BiC1.3 | MUST | BillingCurrency MUST conform to CurrencyFormat requirements. | Not Evaluated |  |
| ID-BiC1.4 | MUST | BillingCurrency MUST NOT be null. | Not Evaluated |  |
| ID-BiC1.5 | MUST | BillingCurrency MUST match the currency used in the invoice generated by the invoice issuer. | Not Evaluated |  |
| ID-BiC1.6 | MUST | BillingCurrency MUST be expressed in national currency (e.g., USD, EUR). | Not Evaluated |  |

### Billing period end (Invoice detail)

The exclusive end bound of a billing period.

Source: [datasets/invoice_detail/columns/billingperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/billingperiodend.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-BPE1 | MUST | BillingPeriodEnd MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BPE1.1 | MUST | BillingPeriodEnd MUST be of type Date/Time. | Not Evaluated |  |
| ID-BPE1.2 | MUST | BillingPeriodEnd MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-BPE1.3 | MUST | BillingPeriodEnd MUST NOT be null. | Not Evaluated |  |
| ID-BPE1.4 | MUST | BillingPeriodEnd MUST be the exclusive end bound of the billing period. | Not Evaluated |  |
| ID-BPE1.5 | MUST | BillingPeriodEnd for a given InvoiceId and InvoiceIssuerName MUST match CostAndUsage.BillingPeriodEnd for the same CostAndUsage.InvoiceId and CostAndUsage.InvoiceIssuerName. | Not Evaluated |  |

### Billing period start (Invoice detail)

The inclusive start bound of a billing period.

Source: [datasets/invoice_detail/columns/billingperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/billingperiodstart.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-BPS1 | MUST | BillingPeriodStart MUST adhere to the following requirements: | Not Evaluated |  |
| ID-BPS1.1 | MUST | BillingPeriodStart MUST be of type Date/Time. | Not Evaluated |  |
| ID-BPS1.2 | MUST | BillingPeriodStart MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-BPS1.3 | MUST | BillingPeriodStart MUST NOT be null. | Not Evaluated |  |
| ID-BPS1.4 | MUST | BillingPeriodStart MUST be the inclusive start bound of the billing period. | Not Evaluated |  |
| ID-BPS1.5 | MUST | BillingPeriodStart for a given InvoiceId and InvoiceIssuerName MUST match CostAndUsage.BillingPeriodStart for the same CostAndUsage.InvoiceId and CostAndUsage.InvoiceIssuerName. | Not Evaluated |  |

### Charge category (Invoice detail)

Represents the highest-level classification of a charge based on the nature of how it is billed.

Source: [datasets/invoice_detail/columns/chargecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/chargecategory.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-CC1 | MUST | ChargeCategory MUST adhere to the following requirements: | Not Evaluated |  |
| ID-CC1.1 | MUST | ChargeCategory MUST be of type String. | Not Evaluated |  |
| ID-CC1.2 | MUST | ChargeCategory MUST NOT be null. | Not Evaluated |  |
| ID-CC1.3 | MUST | ChargeCategory MUST be one of the allowed values. | Not Evaluated |  |
| ID-CC1.4 | MUST | When the charge does not aggregate multiple classifications, ChargeCategory MUST adhere to the following requirements: | Not Evaluated |  |
| ID-CC1.4.1 | MUST | ChargeCategory MUST be "Usage" when the charge represents consumption of a service or resource. | Not Evaluated |  |
| ID-CC1.4.2 | MUST | ChargeCategory MUST be "Purchase" when the charge represents acquisition of a service, resource, or commitment. | Not Evaluated |  |
| ID-CC1.4.3 | MUST | ChargeCategory MUST be "Tax" when the charge represents taxes levied by the relevant authorities. | Not Evaluated |  |
| ID-CC1.4.4 | MUST | ChargeCategory MUST be "Credit" when the charge represents a financial incentive or allowance unrelated to other charges. | Not Evaluated |  |
| ID-CC1.4.5 | MUST | ChargeCategory MUST be "Adjustment" when the charge represents a billing modification that does not fall into other ChargeCategories. | Not Evaluated |  |
| ID-CC1.5 | MUST | When the charge aggregates multiple classifications, ChargeCategory MUST adhere to the following requirements: | Not Evaluated |  |
| ID-CC1.5.1 | MAY | ChargeCategory MAY be "Usage" when the record aggregates charges across multiple allowed values other than "Tax" (e.g., aggregation of "Usage" and "Credit" is allowed, but not "Usage" and "Tax"). | Not Evaluated |  |

### Invoice detail created (Invoice detail)

The timestamp when the Invoice Detail record was first created.

Source: [datasets/invoice_detail/columns/invoicedetailcreated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoicedetailcreated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IDC1 | MUST | InvoiceDetailCreated MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDC1.1 | MUST | InvoiceDetailCreated MUST be of type Date/Time. | Not Evaluated |  |
| ID-IDC1.2 | MUST | InvoiceDetailCreated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-IDC1.3 | MUST | InvoiceDetailCreated MUST NOT be null. | Not Evaluated |  |
| ID-IDC1.4 | MUST | InvoiceDetailCreated MUST represent the moment in time the Invoice Detail record was instantiated. | Not Evaluated |  |
| ID-IDC1.5 | MUST | InvoiceDetailCreated for a given BillingPeriodStart and InvoiceIssuerName MUST be earlier than or equal to BillingPeriod.BillingPeriodLastUpdated for the same BillingPeriod.BillingPeriodStart and BillingPeriod.InvoiceIssuerName when BillingPeriod.BillingPeriodStatus is "Closed". | Not Evaluated |  |

### Invoice detail description (Invoice detail)

The invoice-issuer-provided description of an invoice line item.

Source: [datasets/invoice_detail/columns/invoicedetaildescription.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoicedetaildescription.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IDD1 | MUST | InvoiceDetailDescription MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDD1.1 | MUST | InvoiceDetailDescription MUST be of type String. | Not Evaluated |  |
| ID-IDD1.2 | MUST | InvoiceDetailDescription MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-IDD1.3 | SHOULD | InvoiceDetailDescription SHOULD NOT be null. | Not Evaluated |  |
| ID-IDD1.4 | SHOULD | InvoiceDetailDescription maximum length SHOULD be provided in the corresponding FOCUS Metadata Schema. | Not Evaluated |  |
| ID-IDD1.5 | MUST | InvoiceDetailDescription MUST describe the charges represented by the InvoiceDetailId. | Not Evaluated |  |

### Invoice detail grain (Invoice detail)

The set of key-value pairs that defines the granularity of the invoice line item.

Source: [datasets/invoice_detail/columns/invoicedetailgrain.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoicedetailgrain.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IDG1 | MUST | InvoiceDetailGrain MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDG1.1 | MUST | InvoiceDetailGrain MUST be of type JSON Object (serialized as a String where necessary). | Not Evaluated |  |
| ID-IDG1.2 | MUST | InvoiceDetailGrain MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-IDG1.3 | MUST | InvoiceDetailGrain MUST conform to KeyValueFormat requirements. | Not Evaluated |  |
| ID-IDG1.4 | MUST | InvoiceDetailGrain MUST NOT be null when one or more properties uniquely define the granularity of the invoice line item. | Not Evaluated |  |
| ID-IDG1.5 | MUST | InvoiceDetailGrain MUST contain the set of all properties that uniquely define the granularity of the invoice line item. | Not Evaluated |  |
| ID-IDG1.6 | SHOULD | InvoiceDetailGrain SHOULD use the applicable FOCUS-defined Invoice Detail Grain properties listed below to represent the granularity of the invoice line item. | Not Evaluated |  |
| ID-IDG1.7 | MUST | InvoiceDetailGrain MUST include all custom Invoice Detail Grain properties that are applicable to the granularity of the invoice line item when there is no equivalent FOCUS-defined property. | Not Evaluated |  |
| ID-IDG1.8 | SHOULD | InvoiceDetailGrain property keys SHOULD conform to PascalCase format. | Not Evaluated |  |
| ID-IDG1.9 | MUST | InvoiceDetailGrain property keys MUST begin with the string "x_" unless it is a FOCUS-defined property. | Not Evaluated |  |
| ID-IDG1.10 | MUST | FOCUS-defined InvoiceDetailGrain properties MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDG1.10.1 | MUST | Property key MUST match the spelling and casing specified for the FOCUS-defined property. | Not Evaluated |  |
| ID-IDG1.10.2 | MUST | Property value MUST be of the type specified for that property. | Not Evaluated |  |

### Invoice detail ID (Invoice detail)

The invoice-issuer-assigned identifier for an Invoice Detail record encapsulating charges in the corresponding billing period for a given billing account.

Source: [datasets/invoice_detail/columns/invoicedetailid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoicedetailid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IDI1 | MUST | InvoiceDetailId MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDI1.1 | MUST | InvoiceDetailId MUST be of type String. | Not Evaluated |  |
| ID-IDI1.2 | MUST | InvoiceDetailId MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-IDI1.3 | MUST | InvoiceDetailId MUST NOT be null. | Not Evaluated |  |
| ID-IDI1.4 | MUST | InvoiceDetailId MUST uniquely identify a record within a given InvoiceId. | Not Evaluated |  |

### Invoice detail last updated (Invoice detail)

The timestamp when the Invoice Detail record was last updated.

Source: [datasets/invoice_detail/columns/invoicedetaillastupdated.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoicedetaillastupdated.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IDLU1 | MUST | InvoiceDetailLastUpdated MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IDLU1.1 | MUST | InvoiceDetailLastUpdated MUST be of type Date/Time. | Not Evaluated |  |
| ID-IDLU1.2 | MUST | InvoiceDetailLastUpdated MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-IDLU1.3 | MUST | InvoiceDetailLastUpdated MUST NOT be null. | Not Evaluated |  |
| ID-IDLU1.4 | MUST | InvoiceDetailLastUpdated MUST represent the most recent moment in time when any column value of the record identified by InvoiceDetailId was created or modified. | Not Evaluated |  |
| ID-IDLU1.5 | MUST | InvoiceDetailLastUpdated MUST be greater than or equal to InvoiceDetailCreated. | Not Evaluated |  |

### Invoice ID (Invoice detail)

The invoice-issuer-assigned identifier for an invoice encapsulating charges in the corresponding billing period for a given billing account.

Source: [datasets/invoice_detail/columns/invoiceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoiceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-II1 | MUST | InvoiceId MUST adhere to the following requirements: | Not Evaluated |  |
| ID-II1.1 | MUST | InvoiceId MUST be of type String. | Not Evaluated |  |
| ID-II1.2 | MUST | InvoiceId MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-II1.3 | MUST | InvoiceId MUST NOT be null. | Not Evaluated |  |
| ID-II1.4 | MAY | InvoiceId MAY be generated prior to an invoice being issued. | Not Evaluated |  |
| ID-II1.5 | MUST | InvoiceId MUST uniquely identify the invoice as provided by the invoice issuer. | Not Evaluated |  |

### Invoice issue date (Invoice detail)

The date the invoice was issued by the invoice issuer.

Source: [datasets/invoice_detail/columns/invoiceissuedate.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoiceissuedate.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IID1 | MUST | InvoiceIssueDate MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IID1.1 | MUST | InvoiceIssueDate MUST be of type Date/Time. | Not Evaluated |  |
| ID-IID1.2 | MUST | InvoiceIssueDate MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-IID1.3 | MAY | InvoiceIssueDate MAY be null. | Not Evaluated |  |
| ID-IID1.4 | MUST | InvoiceIssueDate MUST represent the official date of issuance for the corresponding InvoiceId. | Not Evaluated |  |

### Invoice issuer name (Invoice detail)

The name of the entity responsible for invoicing for the resources or services consumed.

Source: [datasets/invoice_detail/columns/invoiceissuername.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoiceissuername.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IIN1 | MUST | InvoiceIssuerName MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IIN1.1 | MUST | InvoiceIssuerName MUST be of type String. | Not Evaluated |  |
| ID-IIN1.2 | MUST | InvoiceIssuerName MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-IIN1.3 | MUST | InvoiceIssuerName MUST NOT be null. | Not Evaluated |  |
| ID-IIN1.4 | MUST | InvoiceIssuerName MUST represent the entity that issues invoices. | Not Evaluated |  |

### Invoice issue status (Invoice detail)

The publication state of the invoice and the reliability of its associated delivered data, indicating if it is provisional ("Open"), issued ("Issued"), or voided ("Voided").

Source: [datasets/invoice_detail/columns/invoiceissuestatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/invoiceissuestatus.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-IIS1 | MUST | InvoiceIssueStatus MUST adhere to the following requirements: | Not Evaluated |  |
| ID-IIS1.1 | MUST | InvoiceIssueStatus MUST be of type String. | Not Evaluated |  |
| ID-IIS1.2 | MUST | InvoiceIssueStatus MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-IIS1.3 | MUST | InvoiceIssueStatus MUST NOT be null. | Not Evaluated |  |
| ID-IIS1.4 | MUST | InvoiceIssueStatus MUST be one of the allowed values. | Not Evaluated |  |
| ID-IIS1.5 | MUST | InvoiceIssueStatus MUST represent the current publication state of the invoice. | Not Evaluated |  |
| ID-IIS1.6 | MUST | InvoiceIssueStatus MUST NOT be "Open" following a previous status of "Issued", except when explicitly requested or approved by the customer. | Not Evaluated |  |

### Payment currency (Invoice detail)

The currency in which the invoice is paid.

Source: [datasets/invoice_detail/columns/paymentcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/paymentcurrency.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PC1 | MUST | PaymentCurrency MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PC1.1 | MUST | PaymentCurrency MUST be of type String. | Not Evaluated |  |
| ID-PC1.2 | MUST | PaymentCurrency MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-PC1.3 | MUST | PaymentCurrency MUST NOT be null. | Not Evaluated |  |
| ID-PC1.4 | MUST | PaymentCurrency MUST represent the currency in which the invoice payment was made or expected to be made. | Not Evaluated |  |
| ID-PC1.5 | MUST | PaymentCurrency MUST be expressed in national currency (e.g., USD, EUR). | Not Evaluated |  |

### Payment currency billed cost (Invoice detail)

The Billed Cost as expressed in Payment Currency.

Source: [datasets/invoice_detail/columns/paymentcurrencybilledcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/paymentcurrencybilledcost.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PCBC1 | MUST | PaymentCurrencyBilledCost MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PCBC1.1 | MUST | PaymentCurrencyBilledCost MUST be of type Decimal. | Not Evaluated |  |
| ID-PCBC1.2 | MUST | PaymentCurrencyBilledCost MUST conform to NumericFormat requirements. | Not Evaluated |  |
| ID-PCBC1.3 | MUST | PaymentCurrencyBilledCost MUST NOT be null. | Not Evaluated |  |
| ID-PCBC1.4 | MUST | PaymentCurrencyBilledCost MUST be denominated in the PaymentCurrency. | Not Evaluated |  |
| ID-PCBC1.5 | MUST | PaymentCurrencyBilledCost MUST be the PaymentCurrency-denominated equivalent of BilledCost. | Not Evaluated |  |
| ID-PCBC1.6 | MAY | PaymentCurrencyBilledCost MAY be non-zero while BilledCost is 0 when PaymentCurrencyBilledCost represents the aggregation of BilledCost amounts (denominated in PaymentCurrency) stated in other records. | Not Evaluated |  |
| ID-PCBC1.7 | MAY | PaymentCurrencyBilledCost MAY be 0 while BilledCost is non-zero when BilledCost (denominated in PaymentCurrency) is represented in a separate aggregate record. | Not Evaluated |  |

### Payment currency invoice detail ID (Invoice detail)

The identifier linking a granular record to the specific Invoice Detail record where its Payment Currency Billed Cost is represented or aggregated.

Source: [datasets/invoice_detail/columns/paymentcurrencyinvoicedetailid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/paymentcurrencyinvoicedetailid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PCIDI1 | MUST | PaymentCurrencyInvoiceDetailId MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PCIDI1.1 | MUST | PaymentCurrencyInvoiceDetailId MUST be of type String. | Not Evaluated |  |
| ID-PCIDI1.2 | MUST | PaymentCurrencyInvoiceDetailId MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-PCIDI1.3 | MUST | PaymentCurrencyInvoiceDetailId MUST NOT be null. | Not Evaluated |  |
| ID-PCIDI1.4 | MUST | PaymentCurrencyInvoiceDetailId MUST match the InvoiceDetailId of the record representing the PaymentCurrencyBilledCost aggregation for the current row. | Not Evaluated |  |
| ID-PCIDI1.5 | MUST | PaymentCurrencyInvoiceDetailId MUST match InvoiceDetailId of the current record when PaymentCurrencyBilledCost is non-zero. | Not Evaluated |  |

### Payment due date (Invoice detail)

The date by which the payment for an invoice is expected to be received by the invoice issuer.

Source: [datasets/invoice_detail/columns/paymentduedate.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/paymentduedate.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PDD1 | MUST | PaymentDueDate MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PDD1.1 | MUST | PaymentDueDate MUST be of type Date/Time. | Not Evaluated |  |
| ID-PDD1.2 | MUST | PaymentDueDate MUST conform to DateTimeFormat requirements. | Not Evaluated |  |
| ID-PDD1.3 | MAY | PaymentDueDate MAY be null. | Not Evaluated |  |
| ID-PDD1.4 | MUST | PaymentDueDate MUST be the date specified by the invoice issuer as the deadline for payment for the corresponding InvoiceId. | Not Evaluated |  |

### Payment terms (Invoice detail)

The terms (typically focused on timeframe) by which the invoice issuer expects to receive payment for an invoice.

Source: [datasets/invoice_detail/columns/paymentterms.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/paymentterms.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PT1 | MUST | PaymentTerms MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PT1.1 | MUST | PaymentTerms MUST be of type String. | Not Evaluated |  |
| ID-PT1.2 | MUST | PaymentTerms MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-PT1.3 | MUST | PaymentTerms MUST NOT be null. | Not Evaluated |  |
| ID-PT1.4 | MUST | PaymentTerms MUST represent the payment terms (e.g., "Net 30") as defined on the corresponding invoice. | Not Evaluated |  |

### Purchase order number (Invoice detail)

The unique customer-issued identifier for tracking the lifecycle of a purchase.

Source: [datasets/invoice_detail/columns/purchaseordernumber.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/purchaseordernumber.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-PON1 | MUST | PurchaseOrderNumber MUST adhere to the following requirements: | Not Evaluated |  |
| ID-PON1.1 | MUST | PurchaseOrderNumber MUST be of type String. | Not Evaluated |  |
| ID-PON1.2 | MUST | PurchaseOrderNumber MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-PON1.3 | MAY | PurchaseOrderNumber MAY be null. | Not Evaluated |  |
| ID-PON1.4 | MUST | PurchaseOrderNumber MUST represent the identifier used by the customer to uniquely identify the purchase order responsible for the charge. | Not Evaluated |  |

### Reference invoice ID (Invoice detail)

The invoice-issuer-assigned identifier for an invoice that affects charges as stated on a previous invoice.

Source: [datasets/invoice_detail/columns/referenceinvoiceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.4/specification/datasets/invoice_detail/columns/referenceinvoiceid.md)

| ID | Type | Criteria | Status | Notes |
|----|------|----------|--------|-------|
| ID-RII1 | MUST | ReferenceInvoiceId MUST adhere to the following requirements: | Not Evaluated |  |
| ID-RII1.1 | MUST | ReferenceInvoiceId MUST be of type String. | Not Evaluated |  |
| ID-RII1.2 | MUST | ReferenceInvoiceId MUST conform to StringHandling requirements. | Not Evaluated |  |
| ID-RII1.3 | MUST | ReferenceInvoiceId MUST NOT be null. | Not Evaluated |  |
| ID-RII1.4 | MUST | ReferenceInvoiceId MUST match the InvoiceId of the original invoice when it adjusts another invoice. | Not Evaluated |  |
| ID-RII1.5 | MUST | ReferenceInvoiceId MUST match the InvoiceId of the current invoice when it does not adjust another invoice. | Not Evaluated |  |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.FOCUS/featureName/Conformance.Report)
<!-- prettier-ignore-end -->

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

<!-- prettier-ignore-start -->
> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)
<!-- prettier-ignore-end -->

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
