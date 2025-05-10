# Date/Time Format

Columns that provide date and time information conforming to specified rules and formatting requirements ensure clarity, accuracy, and ease of interpretation for both humans and systems.

All columns capturing a date/time value, defined in the FOCUS specification, MUST follow the formatting requirements listed below. Custom date/time-related columns SHOULD also follow the same formatting requirements.

## Attribute ID

DateTimeFormat

## Attribute Name

Date/Time Format

## Description

Rules and formatting requirements for date/time-related columns appearing in a [*FOCUS dataset*](#glossary:FOCUS-dataset).

## Requirements

* Date/time values MUST be in UTC (Coordinated Universal Time) to avoid ambiguity and ensure consistency across different time zones.
* Date/time values format MUST be aligned with ISO 8601 standard, which provides a globally recognized format for representing dates and times (see [ISO 8601-1:2019](https://www.iso.org/standard/70907.html) governing document for details).
* Values providing information about a specific moment in time MUST be represented in the extended ISO 8601 format with UTC offset ('YYYY-MM-DDTHH:mm:ssZ') and conform to the following guidelines:
  * Include the date and time components, separated with the letter 'T'
  * Use two-digit hours (HH), minutes (mm), and seconds (ss).
  * End with the 'Z' indicator to denote UTC (Coordinated Universal Time)

## Exceptions

None

## Introduced (version)

0.5
