---
title: FOCUS conformance report
description: Comprehensive analysis of the Microsoft Cost Management FOCUS dataset's adherence to FOCUS requirements.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: reference
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# FOCUS conformance full report

This document provides a detailed list of all FOCUS 1.0 requirements and indicates the level of support provided by the Microsoft Cost Management FOCUS dataset. To learn more about FOCUS, refer to the [FOCUS overview](./what-is-focus.md).

<br>

## How conformance is measured

FOCUS requirements fall into four groups:

- **MUST** requirements are mandatory for all data providers.
- **SHOULD** requirements are strong recommendations.
- **RECOMMENDED** requirements are suggested best practices.
- **MAY** requirements are optional and used to prepare FinOps practitioners for edge cases.

While there's no official measurement for FOCUS conformance, we calculate a conformance score of **96%**, which accounts for all fully and partially supported requirements. The following table summarizes requirements by level of support.

| Type            | Supported | Partial support | Not supported | Not applicable |
| :-------------- | :-------: | :-------------: | :-----------: | :------------: |
| **MUST**        |    238    |       13        |       2       |       10       |
| **SHOULD**      |    22     |        3        |       1       |       1        |
| **RECOMMENDED** |     0     |        1        |       1       |       0        |
| **MAY**         |    22     |        0        |       0       |       1        |
| Summary         |   93.1%   |      5.6%       |     1.3%      |                |

<br>

## How this document is organized

The following sections list each FOCUS requirement, the level of support in the Microsoft Cost Management FOCUS 1.0 dataset, and any relevant notes. For a high-level summary of the gaps, refer to the [FOCUS conformance summary](./conformance-summary.md). Requirement IDs are for reference purposes only. IDs aren't defined as part of FOCUS.

The rest of this document lists the FOCUS requirements grouped by attribute and column. [Columns](#columns) define the specific data elements in the dataset and [attributes](#attributes) define how columns and rows should behave. High-level descriptions and a link to the original requirements document are included at the top of each section.

<br>

## Attributes

### Column naming and ordering

<sup>Source: [attributes/column_naming_and_ordering.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/column_naming_and_ordering.md)</sup>

| ID     | Type   | Criteria                                                                                                                                                                                      | Status             | Notes                                                                                                                                                                                                                                                                                                                                     |
| ------ | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CNO1   | MUST   | All columns defined by FOCUS MUST follow the following rules:                                                                                                                                 | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.1 | MUST   | Column IDs MUST use Pascal case.                                                                                                                                                              | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.2 | MUST   | Column IDs MUST NOT use abbreviations.                                                                                                                                                        | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.3 | MUST   | Column IDs MUST be alphanumeric with no special characters.                                                                                                                                   | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.4 | MUST   | Columns that have an ID and a Name MUST have the `Id` or `Name` suffix in the Column ID.                                                                                                      | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.5 | MAY    | Display Name for a Column MAY avoid the `Name` suffix if there are no other columns with the same name prefix.                                                                                | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.6 | SHOULD | Column IDs SHOULD NOT use acronyms.                                                                                                                                                           | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO1.7 | SHOULD | Column IDs SHOULD NOT exceed 50 characters to accommodate column length restrictions of various data repositories.                                                                            | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO2   | MUST   | All custom columns MUST be prefixed with a consistent `x_` prefix to identify them as external, custom columns and distinguish them from FOCUS columns to avoid conflicts in future releases. | Partially Supports | `BillingAccountType` and `SubAccountType` were unintentionally introduced in Microsoft's FOCUS 1.0 preview dataset version without the `x_` prefix. Both columns are documented in a pending FOCUS pull request. Non-prefixed column names are maintained for backwards compatibility until an official determination is made about them. |
| CNO3.1 | MUST   | Columns that have an ID and a Name MUST have the `Id` or `Name` suffix in the Column ID.                                                                                                      | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO3.2 | MAY    | Display Name for a Column MAY avoid the Name suffix if it is considered superfluous.                                                                                                          | Supports           | We don't recommend this practice as it introduces confusion when column IDs and display names don't match.                                                                                                                                                                                                                                |
| CNO4   | MUST   | Columns with the `Category` suffix MUST be normalized.                                                                                                                                        | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO5   | SHOULD | Custom (for example, provider-defined) columns SHOULD follow the same rules listed above for FOCUS columns.                                                                                   | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO6   | SHOULD | All FOCUS columns SHOULD be first in the provided dataset.                                                                                                                                    | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO7   | SHOULD | Custom columns SHOULD be listed after all FOCUS columns and SHOULD NOT be intermixed.                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                                                                           |
| CNO8.1 | MAY    | Columns MAY be sorted alphabetically...                                                                                                                                                       | Supports           | Columns are sorted alphabetically for ease of use.                                                                                                                                                                                                                                                                                        |
| CNO8.2 | SHOULD | ...custom columns SHOULD be after all FOCUS columns.                                                                                                                                          | Supports           | Columns are sorted alphabetically for ease of use.                                                                                                                                                                                                                                                                                        |

### Currency code format

<sup>Source: [attributes/currency_code_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/currency_code_format.md)</sup>

| ID   | Type   | Criteria                                                                                                                            | Status   | Notes |
| ---- | ------ | ----------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CCF1 | MUST   | All columns capturing a currency value, defined in the FOCUS specification, MUST follow the requirements listed below.              | Supports |       |
| CCF2 | SHOULD | Custom currency-related columns SHOULD also follow the same formatting requirements.                                                | Supports |       |
| CCF3 | MUST   | Currency-related columns MUST be represented as a three-letter alphabetic code as dictated in the governing document ISO 4217:2015. | Supports |       |

### Date/time format

<sup>Source: [attributes/datetime_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/datetime_format.md)</sup>

| ID   | Type   | Criteria                                                                                                                                                                                                                                                                                                                                                                                                 | Status             | Notes                                                                                                        |
| ---- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------ |
| DTF1 | MUST   | All columns capturing a date/time value, defined in the FOCUS specification, MUST follow the formatting requirements listed below.                                                                                                                                                                                                                                                                       | Supports           |                                                                                                              |
| DTF2 | SHOULD | Custom date/time-related columns SHOULD also follow the same formatting requirements.                                                                                                                                                                                                                                                                                                                    | Supports           |                                                                                                              |
| DTF3 | MUST   | Date/time values MUST be in UTC (Coordinated Universal Time) to avoid ambiguity and ensure consistency across different time zones.                                                                                                                                                                                                                                                                      | Supports           |                                                                                                              |
| DTF4 | MUST   | Date/time values format MUST be aligned with ISO 8601 standard, which provides a globally recognized format for representing dates and times (see ISO 8601-1:2019 governing document for details).                                                                                                                                                                                                       | Supports           |                                                                                                              |
| DTF5 | MUST   | Values providing information about a specific moment in time MUST be represented in the extended ISO 8601 format with UTC offset ('YYYY-MM-DDTHH:mm:ssZ') and conform to the following guidelines: Include the date and time components, separated with the letter 'T'; Use two-digit hours (HH), minutes (mm), and seconds (ss); End with the 'Z' indicator to denote UTC (Coordinated Universal Time). | Partially Supports | Date columns all follow the ISO 8601 standard, but don't include seconds (for example, "2024-01-01T00:00Z"). |

### Discount handling

<sup>Source: [attributes/discount_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/discount_handling.md)</sup>

| ID      | Type   | Criteria                                                                                                                                                                                                                                           | Status             | Notes                                                                                                                                                                                                                                                                            |
| ------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DH1     | SHOULD | All applicable discounts SHOULD be applied to each row they pertain to and SHOULD NOT be negated in a separate row.                                                                                                                                | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2     | MUST   | All discounts applied to a row MUST apply to the entire charge.                                                                                                                                                                                    | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.1   | MAY    | Multiple discounts MAY apply to a row...                                                                                                                                                                                                           | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.2   | MUST   | Multiple discounts \[applied to a row\]... MUST apply to the entire charge covered by that row.                                                                                                                                                    | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.3   | MUST   | If a discount only applies to a portion of a charge, then the discounted portion of the charge MUST be split into a separate row.                                                                                                                  | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.4   | MUST   | Each discount MUST be identifiable using existing FOCUS columns.                                                                                                                                                                                   | Supports           | `CommitmentDiscountId` is the only FOCUS column that identifies discounts.                                                                                                                                                                                                       |
| DH2.4.1 | MUST   | Rows with a commitment-based discount applied to them MUST include a CommitmentDiscountId.                                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH2.4.2 | SHOULD | If a provider applies a discount that cannot be represented by a FOCUS column, they SHOULD include additional columns to identify the source of the discount.                                                                                      | Partial Support    | Negotiated discounts can be identified by comparing `ListCost` and `ContractedCost`.                                                                                                                                                                                             |
| DH3.1   | MUST   | Purchased discounts (for example, commitment-based discounts) MUST be amortized.                                                                                                                                                                   | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.2   | MUST   | The BilledCost MUST be 0 for any row where the commitment covers the entire cost for the charge period.                                                                                                                                            | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.3   | MUST   | The EffectiveCost MUST include the portion of the amortized purchase cost that applies to this row.                                                                                                                                                | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.4   | MUST   | The sum of the EffectiveCost for all rows where CommitmentDiscountStatus is "Used" or "Unused" for each CommitmentDiscountId over the entire duration of the commitment MUST be the same as the total BilledCost of the commitment-based discount. | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.5   | MUST   | The CommitmentDiscountId and ResourceId MUST be set to the ID assigned to the commitment-based discount.                                                                                                                                           | Supports           | To facilitate splitting commitment discounts, commitment discount purchases and refunds use the commitment discount order while commitment discount usage uses the instance within the order. Use `x_SkuOrderId` to identify the commitment discount order ID for usage charges. |
| DH3.6   | MUST   | ChargeCategory MUST be set to "Purchase" on rows that represent a purchase of a commitment-based discount.                                                                                                                                         | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.7   | MUST   | CommitmentDiscountStatus MUST be "Used" for ChargeCategory "Usage" rows that received a reduced price from a commitment.                                                                                                                           | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.8   | MUST   | CommitmentDiscountId MUST be set to the ID assigned to the discount \[for commitment discount usage\].                                                                                                                                             | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.9   | MUST   | ResourceId MUST be set to the ID of the resource that received the discount \[for commitment discount usage\].                                                                                                                                     | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.10  | MUST   | If a commitment is not fully utilized, the provider MUST include a row that represents the unused portion of the commitment for that charge period.                                                                                                | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.11  | MUST   | These rows MUST be represented with CommitmentDiscountStatus set to "Unused" and ChargeCategory set to "Usage".                                                                                                                                    | Supports           |                                                                                                                                                                                                                                                                                  |
| DH3.12  | MUST   | Such rows MUST have their CommitmentDiscountId and ResourceId set to the ID assigned to the commitment-based discount.                                                                                                                             | Partially Supports | CommitmentDiscountId logically matches ResourceId, but they differ in case.                                                                                                                                                                                                      |
| DH4     | MUST   | Credits that are applied after the fact MUST use a ChargeCategory of "Credit".                                                                                                                                                                     | Not Applicable     | Credits aren't included in any Cost Management cost and usage dataset.                                                                                                                                                                                                           |

### Key value format

<sup>Source: [attributes/key_value_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/key_value_format.md)</sup>

| ID   | Type | Criteria                                                                                                              | Status   | Notes |
| ---- | ---- | --------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| KVF1 | MUST | Key-Value Format columns MUST contain a serialized JSON string, consistent with the ECMA 404 definition of an object. | Supports |       |
| KVF2 | MUST | Keys in a key-value pair MUST be unique within an object.                                                             | Supports |       |
| KVF3 | MUST | Values in a key-value pair MUST be one of the following types: number, string, `true`, `false`, or `null`.            | Supports |       |
| KVF4 | MUST | Values in a key-value pair MUST NOT be an object or an array.                                                         | Supports |       |

### Null handling

<sup>Source: [attributes/null_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/null_handling.md)</sup>

| ID  | Type   | Criteria                                                                                                                                                                                                                       | Status             | Notes                                                                                                                                                                                                                                                                                                                                                                                                                      |
| --- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NH1 | SHOULD | Custom columns SHOULD also follow the same formatting requirements.                                                                                                                                                            | Partially Supports | The following columns may be "-2" when there's no value: `SkuPriceId`, `x_AccountId`, `x_InvoiceSectionId`. The following columns may be "Unassigned" when there's no value: `SubAccountName`, `x_AccountName`, `x_AccountOwnerId`, `x_InvoiceSectionName`, `x_PricingUnitDescription`. The following columns may be 0 when a value isn't available: `ContractedCost`, `ContractedUnitPrice`, `ListCost`, `ListUnitPrice`. |
| NH2 | MUST   | Columns MUST use NULL when there isn't a value that can be specified for a nullable column.                                                                                                                                    | Partially Supports | (See previous notes)                                                                                                                                                                                                                                                                                                                                                                                                       |
| NH3 | MUST   | Columns MUST NOT use empty strings or placeholder values such as 0 for numeric columns or "Not Applicable" for string columns to represent a null or not having a value, regardless of whether the column allows nulls or not. | Partially Supports | (See previous notes)                                                                                                                                                                                                                                                                                                                                                                                                       |

### Numeric format

<sup>Source: [attributes/numeric_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/numeric_format.md)</sup>

| ID   | Type   | Criteria                                                                                                                                                                                                                                               | Status   | Notes |
| ---- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| NF1  | SHOULD | Custom numeric value capturing columns SHOULD adopt the same format requirements over time.                                                                                                                                                            | Supports |       |
| NF2  | MUST   | Columns with a Numeric value format MUST contain a single numeric value.                                                                                                                                                                               | Supports |       |
| NF3  | MUST   | Numeric values MUST be expressed as an integer value, a decimal value, or a value expressed in scientific notation.                                                                                                                                    | Supports |       |
| NF4  | MUST   | Fractional notation MUST NOT be used.                                                                                                                                                                                                                  | Supports |       |
| NF5  | MUST   | Numeric values expressed using scientific notation MUST be expressed using E notation "mEn" with a real number m and an integer n indicating a value of "m x 10^n".                                                                                    | Supports |       |
| NF6  | MUST   | The sign of the exponent MUST only be expressed as part of the exponent value if n is negative.                                                                                                                                                        | Supports |       |
| NF7  | MUST   | Numeric values MUST NOT be expressed with mathematical symbols, functions, or operators.                                                                                                                                                               | Supports |       |
| NF8  | MUST   | Numeric values MUST NOT contain qualifiers or additional characters (for example, currency symbols, units of measure, etc.).                                                                                                                           | Supports |       |
| NF9  | MUST   | Numeric values MUST NOT contain commas or punctuation marks except for a single decimal point (".") if required to express a decimal value.                                                                                                            | Supports |       |
| NF10 | MUST   | Numeric values MUST NOT include a character to represent a sign for a positive value.                                                                                                                                                                  | Supports |       |
| NF11 | MUST   | A negative sign (-) MUST indicate a negative value.                                                                                                                                                                                                    | Supports |       |
| NF12 | MUST   | Columns with a Numeric value format MUST present one of the following values as the "Data type" in the column definition: `Integer`, `Decimal`.                                                                                                        | Supports |       |
| NF13 | SHOULD | Providers SHOULD define precision and scale for Numeric Format columns using one of the following precision values in a data definition document that providers publish: Integers `Short`, `Long`, `Extended`; Decimal `Single`, `Double`, `Extended`. | Supports |       |

### String handling

<sup>Source: [attributes/string_handling.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/string_handling.md)</sup>

| ID    | Type   | Criteria                                                                                                                                                                               | Status             | Notes                                                                                                                                                                                                                            |
| ----- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SH1   | SHOULD | Custom string value capturing columns SHOULD adopt the same requirements over time.                                                                                                    | Supports           |                                                                                                                                                                                                                                  |
| SH2   | MUST   | String values MUST maintain the original casing, spacing, and other relevant consistency factors as specified by providers and end-users.                                              | Partially Supports | `ResourceName` may be changed to lower or upper case by the resource provider. If you see this, file a support request on the service team responsible for the SKU/meter. `ResourceId` is lowercased to meet FOCUS requirements. |
| SH3.1 | MUST   | Charges to mutable entities (for example, resource names) MUST be accurately reflected in corresponding charges incurred after the change...                                           | Supports           |                                                                                                                                                                                                                                  |
| SH3.2 | MUST   | Charges to mutable entities... MUST NOT alter charges incurred before the change, preserving data integrity and auditability for all charge records.                                   | Supports           |                                                                                                                                                                                                                                  |
| SH4   | MUST   | Immutable string values that refer to the same entity (for example, resource identifiers, region identifiers, etc.) MUST remain consistent and unchanged across all *billing periods*. | Supports           |                                                                                                                                                                                                                                  |
| SH5   | SHOULD | Empty strings and strings consisting solely of spaces SHOULD NOT be used in not-nullable string columns.                                                                               | Supports           |                                                                                                                                                                                                                                  |
| SH6   | MAY    | When a record is provided after a change to a mutable string value and the ChargeClass is "Correction", the record MAY contain the altered value.                                      | Supports           |                                                                                                                                                                                                                                  |

### Unit format

<sup>Source: [attributes/unit_format.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/attributes/unit_format.md)</sup>

| ID     | Type   | Criteria                                                                                                                                                                                                                                                                                   | Status   | Notes                                                                                                                                  |
| ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| UF1    | SHOULD | Units SHOULD be expressed as a single unit of measure adhering to one of the following three formats: `<plural-units>`, `<singular-unit>-<plural-time-units>`, `<plural-units>/<singular-time-unit>`.                                                                                      | Supports | While valid based on rule UF2, the following units are exceptions to this rule: `Units/10 Days`, `Units/3 Months`, `Units/6 Months`.   |
| UF2.1  | MAY    | Units MAY be expressed with a unit quantity (`<quantity> <plural-units>`) or time interval (`<plural-units>/<interval> <plural-time-units>`).                                                                                                                                              | Supports | See UF1.                                                                                                                               |
| UF2.2  | MUST   | If a unit quantity or time interval is used, the unit quantity or time interval MUST be expressed as a whole number.                                                                                                                                                                       | Supports |                                                                                                                                        |
| UF3    | MUST   | Unit values and components of columns using the Unit Format MUST use a capitalization scheme that is consistent with the capitalization scheme used in this attribute if that term is listed in this section.                                                                              | Supports |                                                                                                                                        |
| UF4    | SHOULD | Units SHOULD be composed of the list of recommended units listed in this section unless the unit value covers a dimension not listed in the recommended unit set, or if the unit covers a count-based unit distinct from recommended values in the count dimension listed in this section. | Supports |                                                                                                                                        |
| UF5.1  | MUST   | Data size unit names MUST be abbreviated using one of the abbreviations in the following table.                                                                                                                                                                                            | Supports |                                                                                                                                        |
| UF5.2  | MUST   | Values that exceed 10^18 MUST use the abbreviation for exabit, exabyte, exbibit, and exbibyte...                                                                                                                                                                                           | Supports |                                                                                                                                        |
| UF5.3  | MUST   | ...values smaller than a byte MUST use the abbreviation for bit or byte.                                                                                                                                                                                                                   | Supports |                                                                                                                                        |
| UF6    | MAY    | If the following list of recommended values does not cover a count-based unit, a provider MAY introduce a new noun representing a count-based unit.                                                                                                                                        | Supports | All supported unit values are documented in the [Pricing units](https://aka.ms/ftk/data#-pricing-units) dataset in the FinOps toolkit. |
| UF7    | MUST   | All nouns appearing in units that are not listed in the recommended values table will be considered count-based units. A new count-based unit value MUST be capitalized.                                                                                                                   | Supports |                                                                                                                                        |
| UF8    | MUST   | Time-based units can be used to measure consumption over a time interval or in combination with another unit to capture a rate of consumption. Time-based units MUST match one of the values listed in the following table: `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second`.            | Supports |                                                                                                                                        |
| UF9    | MUST   | If the unit value is a composite value made from combinations of one or more units, each component MUST also align with the set of recommended values.                                                                                                                                     | Supports |                                                                                                                                        |
| UF10.1 | MUST   | Instead of "per" or "-" to denote a Composite Unit, slash ("/") and space(" ") MUST be used as a common convention.                                                                                                                                                                        | Supports |                                                                                                                                        |
| UF10.2 | SHOULD | Count-based units like requests, instances, and tokens SHOULD be expressed using a value listed in the count dimension.                                                                                                                                                                    | Supports |                                                                                                                                        |
| UF10.3 | SHOULD | For example, if a usage unit is measured as a rate of requests or instances over a period of time, the unit SHOULD be listed as "Requests/Day" to signify the number of requests per day.                                                                                                  | Supports |                                                                                                                                        |

<br>

## Columns

### Availability zone

<sup>Source: [columns/availabilityzone.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/availabilityzone.md)</sup>

| ID    | Type        | Criteria                                                                                                                                                             | Status           | Notes                                                                                                               |
| ----- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| AZ0   | Description | A provider-assigned identifier for a physically separated and isolated area within a Region that provides high availability and fault tolerance.                     | Supports         | Microsoft supports the availability zone concept but does not include it in Cost Management cost and usage dataset. |
| AZ1   | RECOMMENDED | The AvailabilityZone column is RECOMMENDED to be present in the billing data when the provider supports deploying resources or services within an availability zone. | Does Not Support | Availability zones aren't available in any Cost Management cost and usage dataset.                                  |
| AZ2.1 | MUST        | \[AvailabilityZone\] MUST be of type String...                                                                                                                       | Not Applicable   |                                                                                                                     |
| AZ2.2 | MAY         | \[AvailabilityZone\]... MAY contain null values when a charge is not specific to an *availability zone*.                                                             | Not Applicable   |                                                                                                                     |

### Billed cost

<sup>Source: [columns/billedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billedcost.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                                 | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| BCo0   | Description | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the *amortization* of upfront charges (one-time or recurring). | Supports |       |
| BCo1.1 | MUST        | The BilledCost column MUST be present in the billing data...                                                                                                             | Supports |       |
| BCo1.2 | MUST        | The BilledCost column... MUST NOT be null.                                                                                                                               | Supports |       |
| BCo2.1 | MUST        | \[BilledCost\] MUST be of type Decimal...                                                                                                                                | Supports |       |
| BCo2.2 | MUST        | \[BilledCost\]... MUST conform to [Numeric Format](#numeric-format)...                                                                                                   | Supports |       |
| BCo2.3 | MUST        | \[BilledCost\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                        | Supports |       |
| BCo2.4 | MUST        | The sum of the BilledCost for rows in a given billing period MUST match the sum of the invoices received for that billing period for a billing account.                  | Supports |       |

### Billing account ID

<sup>Source: [columns/billingaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billingaccountid.md)</sup>

| ID   | Type        | Criteria                                                                 | Status   | Notes                                                                                                                                                                                                                                                     |
| ---- | ----------- | ------------------------------------------------------------------------ | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BAI0 | Description | The identifier assigned to a billing account by the provider.            | Supports | FOCUS billing account represents the scope at which invoices are generated, which is an Enterprise Agreement billing account (also known as enrollment) or a Microsoft Customer Agreement billing profile.                                                |
| BAI1 | MUST        | The BillingAccountId column MUST be present in the billing data.         | Supports |                                                                                                                                                                                                                                                           |
| BAI2 | MUST        | \[BillingAccountId\] MUST be of type String...                           | Supports |                                                                                                                                                                                                                                                           |
| BAI3 | MUST        | \[BillingAccountId\]... MUST NOT contain null values.                    | Supports |                                                                                                                                                                                                                                                           |
| BAI4 | MUST        | BillingAccountId MUST be a globally unique identifier within a provider. | Supports | `BillingAccountId` uses the fully-qualified Azure Resource Manager ID and not the simple enrollment number or billing profile ID for consistency and to ensure the scope being identified is obvious and programmatically accessible via this identifier. |

### Billing account name

<sup>Source: [columns/billingaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billingaccountname.md)</sup>

| ID     | Type        | Criteria                                                                                                                       | Status           | Notes                                                                                                                                                                                                      |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------ | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BAN0   | Description | The display name assigned to a billing account.                                                                                | Supports         | FOCUS billing account represents the scope at which invoices are generated, which is an Enterprise Agreement billing account (also known as enrollment) or a Microsoft Customer Agreement billing profile. |
| BAN1.1 | MUST        | The BillingAccountName column MUST be present in the billing data...                                                           | Supports         |                                                                                                                                                                                                            |
| BAN1.2 | MUST        | The BillingAccountName column... MUST NOT be null when the provider supports assigning a display name for the billing account. | Supports         |                                                                                                                                                                                                            |
| BAN2   | MUST        | \[BillingAccountName\] MUST be of type String.                                                                                 | Supports         |                                                                                                                                                                                                            |
| BAN3   | MUST        | BillingAccountName MUST be unique within a customer when a customer has more than one billing account.                         | Does Not Support | Billing account owners control the `BillingAccountName`. Microsoft does not change this value, even if they choose to use the same name as another billing account.                                        |

### Billing currency

<sup>Source: [columns/billingcurrency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billingcurrency.md)</sup>

| ID     | Type        | Criteria                                                                                     | Status   | Notes |
| ------ | ----------- | -------------------------------------------------------------------------------------------- | -------- | ----- |
| BCu0   | Description | Represents the currency that a charge was billed in.                                         | Supports |       |
| BCu1   | MUST        | The BillingCurrency column MUST be present in the billing data.                              | Supports |       |
| BCu2   | MUST        | BillingCurrency MUST match the currency used in the invoice generated by the invoice issuer. | Supports |       |
| BCu3.1 | MUST        | \[BillingCurrency\] MUST be of type String...                                                | Supports |       |
| BCu3.2 | MUST        | \[BillingCurrency\]... MUST NOT contain null values.                                         | Supports |       |
| BCu5   | MUST        | BillingCurrency MUST conform to Currency Code Format requirements.                           | Supports |       |

### Billing period end

<sup>Source: [columns/billingperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billingperiodend.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                       | Status   | Notes |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| BPE0   | Description | The exclusive end date and time of a billing period.                                                                                                           | Supports |       |
| BPE1   | MUST        | The BillingPeriodEnd column MUST be present in the billing data.                                                                                               | Supports |       |
| BPE2.1 | MUST        | \[BillingPeriodEnd\] MUST be of type [Date/Time Format](#datetime-format)...                                                                                   | Supports |       |
| BPE2.2 | MUST        | \[BillingPeriodEnd\]... MUST be an exclusive value...                                                                                                          | Supports |       |
| BPE2.3 | MUST        | \[BillingPeriodEnd\]... MUST NOT contain null values.                                                                                                          | Supports |       |
| BPE3   | MUST        | The sum of the BilledCost column for rows in a given billing period MUST match the sum of the invoices received for that billing period for a billing account. | Supports |       |

### Billing period start

<sup>Source: [columns/billingperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/billingperiodstart.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                           | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| BPS0   | Description | The inclusive start date and time of a billing period.                                                                                                             | Supports |       |
| BPS1.1 | MUST        | The BillingPeriodStart column MUST be present in the billing data...                                                                                               | Supports |       |
| BPS1.2 | MUST        | The BillingPeriodStart column... MUST be of type [Date/Time Format](#datetime-format)...                                                                           | Supports |       |
| BPS1.3 | MUST        | The BillingPeriodStart column... MUST be an inclusive value...                                                                                                     | Supports |       |
| BPS1.4 | MUST        | The BillingPeriodStart column... MUST NOT contain null values.                                                                                                     | Supports |       |
| BPS2   | MUST        | The sum of the BilledCost metric for rows in a given *billing period* MUST match the sum of the invoices received for that *billing period* for a billing account. | Supports |       |

### Charge category

<sup>Source: [columns/chargecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargecategory.md)</sup>

| ID      | Type        | Criteria                                                                                         | Status   | Notes |
| ------- | ----------- | ------------------------------------------------------------------------------------------------ | -------- | ----- |
| ChCt0   | Description | Represents the highest-level classification of a charge based on the nature of how it is billed. | Supports |       |
| ChCt1.1 | MUST        | The ChargeCategory column MUST be present in the billing data...                                 | Supports |       |
| ChCt1.2 | MUST        | The ChargeCategory column... MUST NOT be null.                                                   | Supports |       |
| ChCt2   | MUST        | \[ChargeCategory\] is of type String and MUST be one of the allowed values.                      | Supports |       |

### Charge class

<sup>Source: [columns/chargeclass.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargeclass.md)</sup>

| ID      | Type        | Criteria                                                                                                                                   | Status   | Notes |
| ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| ChCl0   | Description | Indicates whether the row represents a correction to one or more *charges* invoiced in a previous billing period.                          | Supports |       |
| ChCl1   | MUST        | The ChargeClass column MUST be present in the billing data.                                                                                | Supports |       |
| ChCl2.1 | MUST        | \[ChargeClass\] MUST be of type String...                                                                                                  | Supports |       |
| ChCl2.2 | MUST        | \[ChargeClass\]... MUST be "Correction" when the row represents a correction to one or more charges invoiced in a previous billing period. | Supports |       |
| ChCl3   | MUST        | ChargeClass MUST be null when it is not a correction or when it is a correction within the current billing period.                         | Supports |       |

### Charge description

<sup>Source: [columns/chargedescription.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargedescription.md)</sup>

| ID  | Type        | Criteria                                                                                                | Status             | Notes                                                                                                                                                       |
| --- | ----------- | ------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CD0 | Description | Self-contained summary of the charge's purpose and price.                                               | Supports           |                                                                                                                                                             |
| CD1 | MUST        | The ChargeDescription column MUST be present in the billing data...                                     | Supports           |                                                                                                                                                             |
| CD2 | MUST        | The ChargeDescription column... MUST be of type String...                                               | Supports           |                                                                                                                                                             |
| CD3 | SHOULD      | The ChargeDescription column... SHOULD NOT be null.                                                     | Partially Supports | `ChargeDescription` may be null for savings plan unused charges, Marketplace charges, and other charges that aren't directly associated with a product SKU. |
| CD4 | SHOULD      | Providers SHOULD specify the length of \[ChargeDescription\] in their publicly available documentation. | Does Not Support   |                                                                                                                                                             |

### Charge frequency

<sup>Source: [columns/chargefrequency.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargefrequency.md)</sup>

| ID    | Type        | Criteria                                                                      | Status   | Notes |
| ----- | ----------- | ----------------------------------------------------------------------------- | -------- | ----- |
| CF0   | Description | Indicates how often a charge will occur.                                      | Supports |       |
| CF1.1 | RECOMMENDED | The ChargeFrequency column is RECOMMENDED be present in the billing data...   | Supports |       |
| CF1.2 | MUST        | The ChargeFrequency column... MUST NOT be null.                               | Supports |       |
| CF2   | MUST        | \[ChargeFrequency\] is of type String and MUST be one of the allowed values.  | Supports |       |
| CF3   | MUST        | When ChargeCategory is "Purchase", ChargeFrequency MUST NOT be "Usage-Based". | Supports |       |

### Charge period end

<sup>Source: [columns/chargeperiodend.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargeperiodend.md)</sup>

| ID     | Type        | Criteria                                                                                            | Status   | Notes |
| ------ | ----------- | --------------------------------------------------------------------------------------------------- | -------- | ----- |
| CPE0   | Description | The exclusive end date and time of a charge period.                                                 | Supports |       |
| CPE1.1 | MUST        | ChargePeriodEnd MUST be present in the billing data...                                              | Supports |       |
| CPE1.2 | MUST        | ChargePeriodEnd... MUST be of type [Date/Time](#datetime-format)...                                 | Supports |       |
| CPE1.3 | MUST        | ChargePeriodEnd... MUST be an exclusive value...                                                    | Supports |       |
| CPE1.4 | MUST        | ChargePeriodEnd... MUST NOT contain null values.                                                    | Supports |       |
| CPE2   | MUST        | ChargePeriodEnd MUST match the ending date and time boundary of the effective period of the charge. | Supports |       |

### Charge period start

<sup>Source: [columns/chargeperiodstart.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/chargeperiodstart.md)</sup>

| ID     | Type        | Criteria                                                                                                 | Status   | Notes |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CPS0   | Description | The inclusive start date and time within a charge period.                                                | Supports |       |
| CPS1.1 | MUST        | ChargePeriodStart MUST be present in the billing data...                                                 | Supports |       |
| CPS1.2 | MUST        | ChargePeriodStart... MUST be of type [Date/Time](#datetime-format)...                                    | Supports |       |
| CPS1.3 | MUST        | ChargePeriodStart... MUST be an inclusive value...                                                       | Supports |       |
| CPS1.4 | MUST        | ChargePeriodStart... MUST NOT contain null values.                                                       | Supports |       |
| CPS2   | MUST        | ChargePeriodStart MUST match the beginning date and time boundary of the effective period of the charge. | Supports |       |

### Commitment discount category

<sup>Source: [columns/commitmentdiscountcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/commitmentdiscountcategory.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                  | Status   | Notes |
| ------ | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDC0   | Description | Indicates whether the commitment-based discount identified in the CommitmentDiscountId column is based on usage quantity or cost (also known as "spend"). | Supports |       |
| CDC1   | MUST        | The CommitmentDiscountCategory column MUST be present in the billing data when the provider supports commitment-based discounts.                          | Supports |       |
| CDC2.1 | MUST        | \[CommitmentDiscountCategory\] MUST be of type String...                                                                                                  | Supports |       |
| CDC2.2 | MUST        | \[CommitmentDiscountCategory\]... MUST be null when CommitmentDiscountId is null...                                                                       | Supports |       |
| CDC2.3 | MUST        | \[CommitmentDiscountCategory\]... MUST NOT be null when CommitmentDiscountId is not null.                                                                 | Supports |       |
| CDC3   | MUST        | The CommitmentDiscountCategory MUST be one of the allowed values.                                                                                         | Supports |       |

### Commitment discount ID

<sup>Source: [columns/commitmentdiscountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/commitmentdiscountid.md)</sup>

| ID     | Type        | Criteria                                                                                                                   | Status   | Notes |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDI0   | Description | The identifier assigned to a commitment-based discount by the provider.                                                    | Supports |       |
| CDI1   | MUST        | The CommitmentDiscountId column MUST be present in the billing data when the provider supports commitment-based discounts. | Supports |       |
| CDI2.1 | MUST        | \[CommitmentDiscountId\] MUST be of type String...                                                                         | Supports |       |
| CDI2.2 | MUST        | \[CommitmentDiscountId\]... MUST NOT contain null values when a charge is related to a commitment-based discount.          | Supports |       |
| CDI3   | MUST        | When a charge is not associated with a commitment-based discount, the column MUST be null.                                 | Supports |       |
| CDI4   | MUST        | CommitmentDiscountId MUST be unique within the provider.                                                                   | Supports |       |

### Commitment discount name

<sup>Source: [columns/commitmentdiscountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/commitmentdiscountname.md)</sup>

| ID     | Type        | Criteria                                                                                                                     | Status   | Notes |
| ------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDN0   | Description | The display name assigned to a commitment-based discount.                                                                    | Supports |       |
| CDN1   | MUST        | The CommitmentDiscountName column MUST be present in the billing data when the provider supports commitment-based discounts. | Supports |       |
| CDN2   | MUST        | \[CommitmentDiscountName\] MUST be of type String.                                                                           | Supports |       |
| CDN3.1 | MUST        | The CommitmentDiscountName value MUST be null if the charge is not related to a commitment-based discount...                 | Supports |       |
| CDN3.2 | MAY         | The CommitmentDiscountName value... MAY be null if a display name cannot be assigned to a commitment-based discount.         | Supports |       |
| CDN4   | MUST        | CommitmentDiscountName MUST NOT be null if a display name can be assigned to a commitment-based discount.                    | Supports |       |

### Commitment discount status

<sup>Source: [columns/commitmentdiscountstatus.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/commitmentdiscountstatus.md)</sup>

| ID     | Type        | Criteria                                                                                                                                    | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDS0   | Description | Indicates whether the charge corresponds with the consumption of a commitment-based discount or the unused portion of the committed amount. | Supports |       |
| CDS1   | MUST        | The CommitmentDiscountStatus column MUST be present in the billing data when the provider supports commitment-based discounts.              | Supports |       |
| CDS2   | MUST        | \[CommitmentDiscountStatus\] MUST be of type String...                                                                                      | Supports |       |
| CDS3.1 | MUST        | \[CommitmentDiscountStatus\]... MUST be null when CommitmentDiscountId is null...                                                           | Supports |       |
| CDS3.2 | MUST        | \[CommitmentDiscountStatus\]... MUST NOT be null when CommitmentDiscountId is not null and Charge Category is "Usage".                      | Supports |       |
| CDS4   | MUST        | The CommitmentDiscountCategory MUST be one of the allowed values.                                                                           | Supports |       |

### Commitment discount type

<sup>Source: [columns/commitmentdiscounttype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/commitmentdiscounttype.md)</sup>

| ID     | Type        | Criteria                                                                                                                     | Status   | Notes |
| ------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CDT0   | Description | A provider-assigned identifier for the type of commitment-based discount applied to the row.                                 | Supports |       |
| CDT1   | MUST        | The CommitmentDiscountType column MUST be present in the billing data when the provider supports commitment-based discounts. | Supports |       |
| CDT2.1 | MUST        | \[CommitmentDiscountType\] MUST be of type String...                                                                         | Supports |       |
| CDT2.2 | MUST        | \[CommitmentDiscountType\]... MUST be null when CommitmentDiscountId is null...                                              | Supports |       |
| CDT2.3 | MUST        | \[CommitmentDiscountType\]... MUST NOT be null when CommitmentDiscountId is not null.                                        | Supports |       |

### Consumed quantity

<sup>Source: [columns/consumedquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/consumedquantity.md)</sup>

| ID    | Type        | Criteria                                                                                                         | Status   | Notes |
| ----- | ----------- | ---------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| CQ0   | Description | The volume of a given SKU associated with a resource or service used, based on the Consumed Unit.                | Supports |       |
| CQ1   | MUST        | ConsumedQuantity column MUST be present in the billing data when the provider supports the measurement of usage. | Supports |       |
| CQ2   | MUST        | \[ConsumedQuantity\] MUST NOT be null if ChargeCategory is "Usage" and  ChargeClass is not "Correction".         | Supports |       |
| CQ3   | MUST        | \[ConsumedQuantity\] MUST be null for other ChargeCategory values.                                               | Supports |       |
| CQ4.1 | MUST        | \[ConsumedQuantity\] MUST be of type Decimal...                                                                  | Supports |       |
| CQ4.2 | MUST        | \[ConsumedQuantity\]... MUST conform to [Numeric Format](#numeric-format) requirements.                          | Supports |       |
| CQ5   | MAY         | The value MAY be negative in cases where ChargeClass is "Correction".                                            | Supports |       |

### Consumed unit

<sup>Source: [columns/consumedunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/consumedunit.md)</sup>

| ID  | Type        | Criteria                                                                                                                                         | Status   | Notes |
| --- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| CU0 | Description | Provider-specified measurement unit indicating how a provider measures usage of a given SKU associated with a resource or service.               | Supports |       |
| CU1 | MUST        | The ConsumedUnit column MUST be present in the billing data when the provider supports the measurement of usage.                                 | Supports |       |
| CU2 | MUST        | \[ConsumedUnit\] MUST be of type String.                                                                                                         | Supports |       |
| CU3 | MUST        | ConsumedUnit MUST NOT be null if ChargeCategory is "Usage" and ChargeClass is not "Correction".                                                  | Supports |       |
| CU4 | MUST        | \[ConsumedUnit\] MUST be null for other ChargeCategory values.                                                                                   | Supports |       |
| CU5 | SHOULD      | Units of measure used in ConsumedUnit SHOULD adhere to the values and format requirements specified in the [UnitFormat attribute](#unit-format). | Supports |       |
| CU6 | MUST        | The ConsumedUnit column MUST NOT be used to determine values related to any pricing or cost metrics.                                             | Supports |       |

### Contracted cost

<sup>Source: [columns/contractedcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/contractedcost.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                                                                                                                          | Status             | Notes                                                                                                                                                  |
| ------ | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CnC0   | Description | Cost calculated by multiplying *contracted unit price* and the corresponding Pricing Quantity.                                                                                                                                                                    | Supports           |                                                                                                                                                        |
| CnC1.1 | MUST        | The ContractedCost column MUST be present in the billing data...                                                                                                                                                                                                  | Supports           |                                                                                                                                                        |
| CnC1.2 | MUST        | The ContractedCost column... MUST NOT be null.                                                                                                                                                                                                                    | Partially Supports | `ContractedCost` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CnC2.1 | MUST        | \[ContractedCost\] MUST be of type Decimal...                                                                                                                                                                                                                     | Supports           |                                                                                                                                                        |
| CnC2.2 | MUST        | \[ContractedCost\]... MUST conform to [Numeric Format](#numeric-format) requirements...                                                                                                                                                                           | Supports           |                                                                                                                                                        |
| CnC2.3 | MUST        | \[ContractedCost\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                                                                                                             | Supports           |                                                                                                                                                        |
| CnC3   | MUST        | When ContractedUnitPrice is present and not null, multiplying the ContractedUnitPrice by PricingQuantity MUST produce the ContractedCost, except in cases of ChargeClass "Correction", which may address PricingQuantity or any cost discrepancies independently. | Supports           | `ContractedCost` may be off by less than 0.0000000001 due to rounding errors.                                                                          |
| CnC4   | MUST        | The ContractedCost of a charge calculated based on other charges (for example, when the ChargeCategory is "Tax") MUST be calculated based on the ContractedCost of those related charges.                                                                         | Supports           |                                                                                                                                                        |
| CnC5   | MUST        | The ContractedCost of a charge unrelated to other charges (for example, when the ChargeCategory is "Credit") MUST match the BilledCost.                                                                                                                           | Supports           | `ContractedCost` may be off by less than 0.00001 due to rounding errors.                                                                               |

### Contracted unit price

<sup>Source: [columns/contractedunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/contractedunitprice.md)</sup>

| ID      | Type        | Criteria                                                                                                                                                                                                                                                | Status             | Notes                                                                                                                                                       |
| ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CnUP0   | Description | The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment-based discounts or any other discounts.                                                | Supports           |                                                                                                                                                             |
| CnUP1   | MUST        | The ContractedUnitPrice column MUST be present in the billing data when the provider supports negotiated pricing concept.                                                                                                                               | Supports           |                                                                                                                                                             |
| CnUP2.1 | MUST        | \[ContractedUnitPrice\] MUST be a Decimal within the range of non-negative decimal values...                                                                                                                                                            | Supports           |                                                                                                                                                             |
| CnUP2.3 | MUST        | \[ContractedUnitPrice\]... MUST conform to [Numeric Format](#numeric-format) requirements...                                                                                                                                                            | Supports           |                                                                                                                                                             |
| CnUP2.3 | MUST        | \[ContractedUnitPrice\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                                                                                              | Supports           |                                                                                                                                                             |
| CnUP3.1 | MUST        | It MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                                                                                                                                 | Partially Supports | `ContractedUnitPrice` is never null, but may be 0 for: EA Marketplace charges, EA reservation usage when cost allocation is enabled, MCA reservation usage. |
| CnUP3.2 | MUST        | It... MUST be null when ChargeCategory is "Tax"...                                                                                                                                                                                                      | Not Applicable     | Taxes aren't included in Cost Management cost and usage dataset.                                                                                            |
| CnUP3.3 | MAY         | It... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                                                                                                                                         | Supports           |                                                                                                                                                             |
| CnUP4   | MUST        | When ContractedUnitPrice is present and not null, multiplying ContractedUnitPrice by PricingQuantity MUST equal ContractedCost, except in cases of ChargeClass "Correction", which may address PricingQuantity or any cost discrepancies independently. | Supports           | `ContractedCost` may be off by less than 0.00001 due to rounding errors.                                                                                    |

### Effective cost

<sup>Source: [columns/effectivecost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/effectivecost.md)</sup>

| ID    | Type        | Criteria                                                                                                                                                                                  | Status   | Notes |
| ----- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| EC0   | Description | The amortized cost of the charge after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge. | Supports |       |
| EC1.1 | MUST        | The EffectiveCost column MUST be present in the billing data...                                                                                                                           | Supports |       |
| EC1.2 | MUST        | The EffectiveCost column... MUST NOT be null.                                                                                                                                             | Supports |       |
| EC2.1 | MUST        | \[EffectiveCost\] MUST be of type Decimal...                                                                                                                                              | Supports |       |
| EC2.2 | MUST        | \[EffectiveCost\]... MUST conform to [Numeric Format](#numeric-format) requirements...                                                                                                    | Supports |       |
| EC2.3 | MUST        | \[EffectiveCost\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                                      | Supports |       |
| EC4   | MUST        | EffectiveCost MUST be 0 when ChargeCategory is "Purchase" and the purchase is intended to cover future eligible charges.                                                                  | Supports |       |
| EC5   | MUST        | The EffectiveCost MUST be calculated based on the EffectiveCost of the related charges if the charge is calculated based on other charges (e.g. ChargeCategory is "Tax").                 | Supports |       |
| EC6   | MUST        | The EffectiveCost MUST match the BilledCost if the charge is unrelated to other charges (e.g. ChargeCategory is "Credit").                                                                | Supports |       |

### Invoice issuer name

<sup>Source: [columns/invoiceissuer.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/invoiceissuer.md)</sup>

| ID   | Type        | Criteria                                                                                 | Status   | Notes                                                                                                                                                                                                                                                                                                                                                                       |
| ---- | ----------- | ---------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IIN0 | Description | The name of the entity responsible for invoicing for the resources or services consumed. | Supports | For CSP accounts, `InvoiceIssuerName` is set to the name of the Cloud Solution Provider (CSP) distributor that has a direct relationship with Microsoft and may not represent the organization that directly invoices the end customer. For all other account types, the value is "Microsoft", even if there's an intermediary organization that invoices the end customer. |
| IIN1 | MUST        | The InvoiceIssuer column MUST be present in the billing data.                            | Supports |                                                                                                                                                                                                                                                                                                                                                                             |
| IIN2 | MUST        | \[InvoiceIssuerName\] MUST be of type String...                                          | Supports |                                                                                                                                                                                                                                                                                                                                                                             |
| IIN3 | MUST        | \[InvoiceIssuerName\]... MUST NOT contain null values.                                   | Supports |                                                                                                                                                                                                                                                                                                                                                                             |

### List cost

<sup>Source: [columns/listcost.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/listcost.md)</sup>

| ID    | Type        | Criteria                                                                                                                                                                                                                                        | Status             | Notes                                                                                  |
| ----- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------- |
| LC0   | Description | Cost calculated by multiplying List Unit Price and the corresponding Pricing Quantity.                                                                                                                                                          | Supports           |                                                                                        |
| LC1.1 | MUST        | The ListCost column MUST be present in the billing data...                                                                                                                                                                                      | Supports           |                                                                                        |
| LC1.2 | MUST        | The ListCost column... MUST NOT be null.                                                                                                                                                                                                        | Partially Supports | `ListCost` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| LC2.1 | MUST        | \[ListCost\] MUST be of type Decimal...                                                                                                                                                                                                         | Supports           |                                                                                        |
| LC2.2 | MUST        | \[ListCost\]... MUST conform to [Numeric Format](#numeric-format) requirements.                                                                                                                                                                 | Supports           |                                                                                        |
| LC2.3 | MUST        | \[ListCost\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                                                                                                 | Supports           |                                                                                        |
| LC3   | MUST        | When ListUnitPrice is present and not null, multiplying the ListUnitPrice by PricingQuantity MUST produce the ListCost, except in cases of ChargeClass "Correction", which may address PricingQuantity or any cost discrepancies independently. | Supports           | `ListCost` may be off by less than 0.0000000001 due to rounding errors.                |
| LC4   | MUST        | The ListCost of a charge calculated based on other charges (for example, when the ChargeCategory is "Tax") MUST be calculated based on the ListCost of those related charges.                                                                   | Supports           |                                                                                        |
| LC5   | MUST        | The ListCost of a charge unrelated to other charges (for example, when the ChargeCategory is "Credit") MUST match the BilledCost.                                                                                                               | Supports           | ListCost may be off by less than 0.0000000001 due to rounding errors.                  |

### List unit price

<sup>Source: [columns/listunitprice.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/listunitprice.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                                                                                                 | Status             | Notes                                                                                       |
| ------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| LUP0   | Description | The suggested provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts.                                                                                                                 | Supports           |                                                                                             |
| LUP1   | MUST        | The ListUnitPrice column MUST be present in the billing data when the provider publishes unit prices exclusive of discounts.                                                                                                             | Supports           |                                                                                             |
| LUP2.1 | MUST        | \[ListUnitPrice\] MUST be a Decimal within the range of non-negative decimal values...                                                                                                                                                   | Supports           |                                                                                             |
| LUP2.2 | MUST        | \[ListUnitPrice\]... MUST conform to [Numeric Format](#numeric-format) requirements...                                                                                                                                                   | Supports           |                                                                                             |
| LUP2.3 | MUST        | \[ListUnitPrice\]... \[MUST\] be denominated in the BillingCurrency.                                                                                                                                                                     | Supports           |                                                                                             |
| LUP3.1 | MUST        | It MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                                                                                                                  | Partially Supports | `ListUnitPrice` is never null, but may be 0 for: Marketplace charges and reservation usage. |
| LUP3.2 | MUST        | It... MUST be null when ChargeCategory is "Tax"...                                                                                                                                                                                       | Not Applicable     | Tax isn't included in any Cost Management cost and usage dataset.                           |
| LUP3.3 | MAY         | It... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                                                                                                                          | Supports           |                                                                                             |
| LUP4   | MUST        | When ListUnitPrice is present and is not null, multiplying ListUnitPrice by PricingQuantity MUST equal ListCost, except in cases of ChargeClass "Correction", which may address PricingQuantity or any cost discrepancies independently. | Supports           |                                                                                             |

### Pricing category

<sup>Source: [columns/pricingcategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/pricingcategory.md)</sup>

| ID    | Type        | Criteria                                                                                                                                              | Status         | Notes                                                                |
| ----- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| PC0   | Description | Describes the pricing model used for a charge at the time of use or purchase.                                                                         | Supports       |                                                                      |
| PC1.1 | MUST        | PricingCategory MUST be present in the billing data when the provider supports more than one pricing category across all SKUs...                      | Supports       |                                                                      |
| PC1.2 | MUST        | PricingCategory... MUST be of type String.                                                                                                            | Supports       |                                                                      |
| PC2.1 | MUST        | PricingCategory MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                  | Supports       |                                                                      |
| PC2.2 | MUST        | PricingCategory... MUST be null when ChargeCategory is "Tax"...                                                                                       | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| PC2.3 | MAY         | PricingCategory... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                          | Supports       |                                                                      |
| PC3   | MUST        | PricingCategory MUST be one of the allowed values.                                                                                                    | Supports       |                                                                      |
| PC4   | MUST        | PricingCategory MUST be "Standard" when pricing is predetermined at the agreed upon rate for the billing account.                                     | Supports       |                                                                      |
| PC5   | MUST        | PricingCategory MUST be "Committed" when CommitmentDiscountId is not null.                                                                            | Supports       |                                                                      |
| PC6   | MUST        | PricingCategory MUST be "Dynamic" when pricing is determined by the provider and may change over time, regardless of predetermined agreement pricing. | Supports       |                                                                      |
| PC7   | MUST        | PricingCategory MUST be "Other" when there is a pricing model but none of the allowed values apply.                                                   | Supports       |                                                                      |

### Pricing quantity

<sup>Source: [columns/pricingquantity.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/pricingquantity.md)</sup>

| ID    | Type        | Criteria                                                                                                                                                                                                                                                         | Status         | Notes                                                                |
| ----- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| PQ0   | Description | The volume of a given SKU associated with a resource or service used or purchased, based on the Pricing Unit.                                                                                                                                                    | Supports       |                                                                      |
| PQ1   | MUST        | The PricingQuantity column MUST be present in the billing data.                                                                                                                                                                                                  | Supports       |                                                                      |
| PQ2.1 | MUST        | \[PricingQuantity\] MUST be of type Decimal...                                                                                                                                                                                                                   | Supports       |                                                                      |
| PQ2.2 | MUST        | \[PricingQuantity\]... MUST conform to [Numeric Format](#numeric-format) requirements.                                                                                                                                                                           | Supports       |                                                                      |
| PQ3   | MAY         | The value MAY be negative in cases where ChargeClass is "Correction".                                                                                                                                                                                            | Supports       |                                                                      |
| PQ4.1 | MUST        | \[PricingQuantity\] MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                                                                                                                         | Supports       |                                                                      |
| PQ4.2 | MUST        | \[PricingQuantity\]... MUST be null when ChargeCategory is "Tax"...                                                                                                                                                                                              | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| PQ4.3 | MAY         | \[PricingQuantity\]... and MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                                                                                                                             | Supports       |                                                                      |
| PQ5   | MUST        | When unit prices are not null, multiplying PricingQuantity by a unit price MUST produce a result equal to the corresponding cost metric, except in cases of ChargeClass "Correction", which may address PricingQuantity or any cost discrepancies independently. | Supports       |                                                                      |

### Pricing unit

<sup>Source: [columns/pricingunit.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/pricingunit.md)</sup>

| ID    | Type        | Criteria                                                                                                                                                                                                             | Status         | Notes                                                                |
| ----- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| PU0   | Description | Provider-specified measurement unit for determining unit prices, indicating how the provider rates measured usage and purchase quantities after applying pricing rules like block pricing.                           | Supports       |                                                                      |
| PU1   | MUST        | The PricingUnit column MUST be present in the billing data.                                                                                                                                                          | Supports       |                                                                      |
| PU2   | MUST        | \[PricingUnit\] MUST be of type String.                                                                                                                                                                              | Supports       |                                                                      |
| PU3.1 | MUST        | It MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                                                                                              | Supports       |                                                                      |
| PU3.2 | MUST        | It... MUST be null when ChargeCategory is "Tax"...                                                                                                                                                                   | Not Applicable | Taxes aren't included in any Cost Management cost and usage dataset. |
| PU3.3 | MAY         | It... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                                                                                                      | Supports       |                                                                      |
| PU4   | SHOULD      | Units of measure used in PricingUnit SHOULD adhere to the values and format requirements specified in the [UnitFormat attribute](#unit-format).                                                                      | Supports       |                                                                      |
| PU5   | MUST        | The PricingUnit value MUST be semantically equal to the corresponding pricing measurement unit value provided in the provider-published price list or invoice, when the invoice includes a pricing measurement unit. | Supports       |                                                                      |

### Provider name

<sup>Source: [columns/provider.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/provider.md)</sup>

| ID     | Type        | Criteria                                                                           | Status   | Notes |
| ------ | ----------- | ---------------------------------------------------------------------------------- | -------- | ----- |
| PrN0   | Description | The name of the entity that made the resources or services available for purchase. | Supports |       |
| PrN1   | MUST        | The Provider column MUST be present in the billing data.                           | Supports |       |
| PrN2.1 | MUST        | \[ProviderName\] MUST be of type String...                                         | Supports |       |
| PrN2.2 | MUST        | \[ProviderName\]... MUST NOT contain null values.                                  | Supports |       |

### Publisher name

<sup>Source: [columns/publisher.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/publisher.md)</sup>

| ID     | Type        | Criteria                                                                            | Status             | Notes                                                                                             |
| ------ | ----------- | ----------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------- |
| PbN0   | Description | The name of the entity that produced the resources or services that were purchased. | Supports           |                                                                                                   |
| PbN1   | MUST        | The Publisher column MUST be present in the billing data.                           | Supports           |                                                                                                   |
| PbN2.1 | MUST        | \[PublisherName\] MUST be of type String...                                         | Supports           |                                                                                                   |
| PbN2.2 | MUST        | \[PublisherName\]... MUST NOT contain null values.                                  | Partially Supports | `PublisherName` may be null for reservation usage and purchases, and savings plan unused charges. |

### Region ID

<sup>Source: [columns/regionid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/regionid.md)</sup>

| ID     | Type        | Criteria                                                                                                                              | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RgI0   | Description | Provider-assigned identifier for an isolated geographic area where a resource is provisioned or a service is provided.                | Supports |       |
| RgI1.1 | MUST        | The RegionId column MUST be present in the billing data when the provider supports deploying resources or services within a region... | Supports |       |
| RgI1.2 | MUST        | The RegionId column... MUST be of type String.                                                                                        | Supports |       |
| RgI2.1 | MUST        | RegionId MUST NOT be null when a resource or service is operated in or managed from a distinct region by the Provider...              | Supports |       |
| RgI2.2 | MAY         | RegionId... MAY contain null values when a resource or service is not restricted to an isolated geographic area.                      | Supports |       |

### Region name

<sup>Source: [columns/regionname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/regionname.md)</sup>

| ID   | Type        | Criteria                                                                                                                                | Status   | Notes |
| ---- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RgN0 | Description | The name of an isolated geographic area where a resource is provisioned or a service is provided.                                       | Supports |       |
| RgN1 | MUST        | The RegionName column MUST be present in the billing data when the provider supports deploying resources or services within a region... | Supports |       |
| RgN2 | MUST        | The RegionName... MUST be of type String.                                                                                               | Supports |       |
| RgN3 | MUST        | RegionName MUST NOT be null when a resource or service is operated in or managed from a distinct region by the Provider...              | Supports |       |
| RgN4 | MAY         | RegionName... MAY contain null values when a resource or service is not restricted to an isolated geographic area.                      | Supports |       |

### Resource ID

<sup>Source: [columns/resourceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/resourceid.md)</sup>

| ID   | Type        | Criteria                                                                                                                     | Status   | Notes                                                                                                                                                                        |
| ---- | ----------- | ---------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RsI0 | Description | Identifier assigned to a resource by the provider.                                                                           | Supports |                                                                                                                                                                              |
| RsI1 | MUST        | The ResourceId column MUST be present in the billing data when the provider supports billing based on provisioned resources. | Supports |                                                                                                                                                                              |
| RsI2 | MUST        | \[ResourceId\] MUST be of type String.                                                                                       | Supports |                                                                                                                                                                              |
| RsI3 | MAY         | The ResourceId value MAY be a nullable column as some cost data rows may not be associated with a resource.                  | Supports | Purchases may not have an assigned resource ID.                                                                                                                              |
| RsI4 | MUST        | ResourceId MUST appear in the cost data if an identifier is assigned to a resource by the provider.                          | Supports | `ResourceId` may be null when a resource is indirectly related to the charges. If you feel it's missing, file a support request for the service that owns the resource type. |
| RsI5 | SHOULD      | ResourceId SHOULD be a fully-qualified identifier that ensures global uniqueness within the provider.                        | Supports |                                                                                                                                                                              |

### Resource name

<sup>Source: [columns/resourcename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/resourcename.md)</sup>

| ID   | Type        | Criteria                                                                                                                                                                 | Status   | Notes                                                                                                                                                                          |
| ---- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| RsN0 | Description | Display name assigned to a resource.                                                                                                                                     | Supports |                                                                                                                                                                                |
| RsN1 | MUST        | The ResourceName column MUST be present in the billing data when the provider supports billing based on provisioned resources.                                           | Supports |                                                                                                                                                                                |
| RsN2 | MUST        | \[ResourceName\] MUST be of type String.                                                                                                                                 | Supports |                                                                                                                                                                                |
| RsN3 | MAY         | The ResourceName value MAY be a nullable column as some cost data rows may not be associated with a resource or because a display name cannot be assigned to a resource. | Supports | Purchases may not have an assigned resource name.                                                                                                                              |
| RsN4 | MUST        | ResourceName MUST NOT be null if a display name can be assigned to a resource.                                                                                           | Supports | `ResourceName` may be null when a resource is indirectly related to the charges. If you feel it's missing, file a support request for the service that owns the resource type. |
| RsN5 | MUST        | Resources not provisioned interactively or only have a system-generated ResourceId MUST NOT duplicate the same value as the ResourceName.                                | Supports |                                                                                                                                                                                |

### Resource type

<sup>Source: [columns/resourcetype.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/resourcetype.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                                   | Status   | Notes |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| RsT0   | Description | The kind of resource the charge applies to.                                                                                                                                | Supports |       |
| RsT1   | MUST        | The ResourceType column MUST be present in the billing data when the provider supports billing based on provisioned resources and supports assigning a type for resources. | Supports |       |
| RsT2.1 | MUST        | \[ResourceType\] MUST be of type String...                                                                                                                                 | Supports |       |
| RsT2.2 | MUST        | \[ResourceType\]... MUST NOT be null when a corresponding ResourceId is not null.                                                                                          | Supports |       |
| RsT3   | MUST        | When a corresponding ResourceId value is null, the ResourceType column value MUST also be null.                                                                            | Supports |       |

### Service category

<sup>Source: [columns/servicecategory.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/servicecategory.md)</sup>

| ID     | Type        | Criteria                                                                             | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------ | -------- | ----- |
| SvC0   | Description | Highest-level classification of a service based on the core function of the service. | Supports |       |
| SvC1.1 | MUST        | The ServiceCategory column MUST be present...                                        | Supports |       |
| SvC1.2 | MUST        | The ServiceCategory... MUST NOT be null.                                             | Supports |       |
| SvC2   | MUST        | \[ServiceCategory\] is of type String and MUST be one of the allowed values.         | Supports |       |

### Service name

<sup>Source: [columns/servicename.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/servicename.md)</sup>

| ID     | Type        | Criteria                                                                                                                                                | Status   | Notes |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| SvN0   | Description | An offering that can be purchased from a provider (for example, cloud virtual machine, SaaS database, professional services from a systems integrator). | Supports |       |
| SvN1   | MUST        | The ServiceName column MUST be present in the cost data.                                                                                                | Supports |       |
| SvN2.1 | MUST        | \[ServiceName\] MUST be of type String...                                                                                                               | Supports |       |
| SvN2.2 | MUST        | \[ServiceName\]... MUST NOT contain null values.                                                                                                        | Partially supports | ServiceName may be empty for some purchases and adjustments. |

### SKU ID

<sup>Source: [columns/skuid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/skuid.md)</sup>

| ID     | Type        | Criteria                                                                                                                                 | Status             | Notes                                                                                       |
| ------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| SkI0   | Description | A unique identifier that defines a provider-supported construct for organizing properties that are common across one or more SKU Prices. | Supports           |                                                                                             |
| SkI1   | MUST        | The SkuId column MUST be present in the billing data when the provider publishes a SKU list.                                             | Supports           |                                                                                             |
| SkI2   | MUST        | \[SkuId\] MUST be of type String.                                                                                                        | Supports           |                                                                                             |
| SkI3.1 | MUST        | It MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...                                  | Partially Supports | `SkuId` may be null for some rows like savings plan unused charges and Marketplace charges. |
| SkI3.2 | MUST        | It... MUST be null when ChargeCategory is "Tax"...                                                                                       | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                        |
| SkI3.3 | MAY         | It... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                                          | Supports           |                                                                                             |
| SkI4   | MUST        | SkuId MUST equal SkuPriceId when a provider does not support an overarching SKU ID construct.                                            | Supports           |                                                                                             |

### SKU price ID

<sup>Source: [columns/skupriceid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/skupriceid.md)</sup>

| ID      | Type        | Criteria                                                                                                                        | Status             | Notes                                                                                                                                                                                                                   |
| ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SkPI0   | Description | A unique identifier that defines the unit price used to calculate the charge.                                                   | Supports           |                                                                                                                                                                                                                         |
| SkPI1   | MUST        | The SkuPriceId column MUST be present in the billing data when the provider publishes a SKU price list.                         | Supports           |                                                                                                                                                                                                                         |
| SkPI2   | MUST        | \[SkuPriceId\] MUST be of type String.                                                                                          | Supports           |                                                                                                                                                                                                                         |
| SkPI3   | MUST        | SkuPriceId MUST define a single unit price used for calculating the charge.                                                     | Supports           |                                                                                                                                                                                                                         |
| SkPI4   | MUST        | The ListUnitPrice MUST be associated with the SkuPriceId in the provider published price list.                                  | Partially Supports | For EA, `SkuPriceId` represents an individual SKU price but isn't available in the price sheet dataset. For MCA, `SkuPriceId` is a combination of the following price sheet columns: `{ProductId}_{SkuId}_{MeterType}`. |
| SkPI5.1 | MUST        | \[SkuPriceId\] MUST NOT be null when ChargeClass is not "Correction" and ChargeCategory is "Usage" or "Purchase"...             | Supports           |                                                                                                                                                                                                                         |
| SkPI5.2 | MUST        | \[SkuPriceId\]... MUST be null when ChargeCategory is "Tax"....                                                                 | Not Applicable     | Taxes aren't included in any Cost Management cost and usage dataset.                                                                                                                                                    |
| SkPI5.3 | MAY         | \[SkuPriceId\]... MAY be null for all other combinations of ChargeClass and ChargeCategory.                                     | Supports           |                                                                                                                                                                                                                         |
| SkPI6   | MUST        | A given value of SkuPriceId MUST be associated with one and only one SkuId, except in cases of commitment discount flexibility. | Supports           |                                                                                                                                                                                                                         |

### Sub account ID

<sup>Source: [columns/subaccountid.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/subaccountid.md)</sup>

| ID   | Type        | Criteria                                                                                                        | Status   | Notes                                                    |
| ---- | ----------- | --------------------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------------- |
| SAI0 | Description | An ID assigned to a grouping of resources or services, often used to manage access and/or cost.                 | Supports | FOCUS subaccount maps to a Microsoft Cloud subscription. |
| SAI1 | MUST        | The SubAccountId column MUST be present in the billing data when the provider supports a sub account construct. | Supports |                                                          |
| SAI2 | MUST        | \[SubAccountId\] MUST be of type String.                                                                        | Supports |                                                          |
| SAI3 | MUST        | If a charge does not apply to a sub account, the SubAccountId column MUST be null.                              | Supports | `SubAccountId` is null for MCA purchases and refunds.    |

### Sub account name

<sup>Source: [columns/subaccountname.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/subaccountname.md)</sup>

| ID   | Type        | Criteria                                                                                                          | Status             | Notes                                                                                                               |
| ---- | ----------- | ----------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| SAN0 | Description | A name assigned to a grouping of resources or services, often used to manage access and/or cost.                  | Supports           | FOCUS subaccount maps to a Microsoft Cloud subscription.                                                            |
| SAN1 | MUST        | The SubAccountName column MUST be present in the billing data when the provider supports a sub account construct. | Supports           |                                                                                                                     |
| SAN2 | MUST        | \[SubAccountName\] MUST be of type String.                                                                        | Supports           |                                                                                                                     |
| SAN3 | MUST        | If a charge does not apply to a sub account, the SubAccountName column MUST be null.                              | Partially Supports | `SubAccountName` may be "Unassigned" when there's no value. `SubAccountName` is null for MCA purchases and refunds. |

### Tags

<sup>Source: [columns/tags.md](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/blob/v1.0/specification/columns/tags.md)</sup>

| ID  | Type        | Criteria                                                                                                                                  | Status           | Notes                                                                                                                            |
| --- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| T0  | Description | The set of tags assigned to tag sources that account for potential provider-defined or user-defined tag evaluations.                      | Supports         |                                                                                                                                  |
| T1  | MUST        | The Tags column MUST be present in the billing data when the provider supports setting user or provider-defined tags.                     | Supports         |                                                                                                                                  |
| T2  | MUST        | The Tags column MUST contain user-defined and provider-defined tags.                                                                      | Supports         |                                                                                                                                  |
| T3  | MUST        | The Tags column MUST only contain finalized tags.                                                                                         | Supports         |                                                                                                                                  |
| T4  | MUST        | The Tags column MUST be in [Key-Value Format](#key-value-format).                                                                         | Supports         |                                                                                                                                  |
| T5  | SHOULD      | A Tag key with a non-null value for a given resource SHOULD be included in the tags column.                                               | Supports         |                                                                                                                                  |
| T6  | MAY         | A Tag key with a null value for a given resource MAY be included in the tags column depending on the provider's tag finalization process. | Supports         |                                                                                                                                  |
| T7  | MUST        | A Tag key that does not support a corresponding value, MUST have a corresponding true (boolean) value set.                                | Not Applicable   | Microsoft Cloud tags support both keys and values.                                                                               |
| T8  | MUST        | If Tag finalization is supported, providers MUST publish tag finalization methods and semantics within their respective documentation.    | Supports         | See [Group and allocate costs using tag inheritance](/azure/cost-management-billing/costs/enable-tag-inheritance).               |
| T9  | MUST        | Providers MUST NOT alter user-defined Tag keys or values.                                                                                 | Supports         |                                                                                                                                  |
| T10 | MUST        | Provider-defined tags MUST be prefixed with a provider-specified tag key prefix.                                                          | Does Not Support | Provider-specified tags can't be differentiated from user-defined tags. Tags aren't modified to support backwards compatibility. |
| T11 | SHOULD      | Providers SHOULD publish all provider-specified tag key prefixes within their respective documentation.                                   | Not Applicable   | Provider prefixes aren't currently specified.                                                                                    |

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.FOCUS/featureName/Conformance.Report)

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

- [FinOps toolkit Power BI reports](https://aka.ms/ftk/pbi)
- [FinOps hubs](https://aka.ms/finops/hubs)
- [FinOps toolkit PowerShell module](https://aka.ms/ftk/ps)

<br>
