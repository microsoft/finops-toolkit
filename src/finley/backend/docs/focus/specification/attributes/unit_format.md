# Unit Format

Billing data frequently captures data measured in units related to data size, count, time, and other [*dimensions*](#glossary:dimension). The Unit Format attribute provides a standard for expressing units of measure in columns appearing in a [*FOCUS dataset*](#glossary:FOCUS-dataset).

All columns defined in FOCUS specifying Unit Format as a value format MUST follow the requirements listed below.

## Attribute ID

UnitFormat

## Attribute Name

Unit Format

## Description

Indicates standards for expressing measurement units in columns appearing in a *FOCUS dataset*.

## Requirements

* Units SHOULD be expressed as a single unit of measure adhering to one of the following three formats.
  * `<plural-units>` - "GB", "Seconds"
  * `<singular-unit>-<plural-time-units>` - "GB-Hours", "MB-Days"
  * `<plural-units>/<singular-time-unit>` - "GB/Hour", "PB/Day"
* Units MAY be expressed with a unit quantity or time interval.  If a unit quantity or time interval is used, the unit quantity or time interval MUST be expressed as a whole number.  The following formats are valid:
  * `<quantity> <plural-units>` - "1000 Tokens", "1000 Characters"
  * `<plural-units>/<interval> <plural-time-units>` - "Units/3 Months"
* Unit values and components of columns using the Unit Format MUST use a capitalization scheme that is consistent with the capitalization scheme used in this attribute if that term is listed in this section. For example, a value of "gigabyte-seconds" would not be compliant with this specification as the terms "gigabyte" and "second" are listed in this section with the appropriate capitalization.  If the unit is not listed in the table, it is to be used over a functional equivalent with a similar meaning with the same capitalization scheme.
* Units SHOULD be composed of the list of recommended units listed in this section unless the unit value covers a *dimension* not listed in the recommended unit set, or if the unit covers a count-based unit distinct from recommended values in the count *dimension* listed in this section.  

### Data Size Unit Names

Data size unit names MUST be abbreviated using one of the abbreviations in the following table.  For example, a unit name of "TB" is a valid unit name, and a unit name of "terabyte" is an invalid unit name. Data size abbreviations can be considered both the singular and plural form of the unit.  For example, "GB" is both the singular and plural form of the unit "gigabyte", and "GBs" would be an invalid unit name.  Values that exceed 10^18 MUST use the abbreviation for exabit, exabyte, exbibit, and exbibyte, and values smaller than a byte MUST use the abbreviation for bit or byte.   For example, the abbreviation "YB" for "yottabyte" is not a valid data size unit name as it represents a value larger than what is listed in the following table.

The following table lists the valid abbreviations for data size units from a single bit or byte to 10^18 bits or bytes.

| Data size in bits    | Data size in bytes    |
| :------------------- | :-------------------- |
| b (bit) = 10^1       | B (byte = 10^1)       |
| Kb (kilobit = 10^3)  | KB (kilobyte = 10^3)  |
| Mb (megabit = 10^6)  | MB (megabyte = 10^6)  |
| Gb (gigabit = 10^9)  | GB (gigabyte = 10^9)  |
| Tb (terabit = 10^12) | TB (terabyte = 10^12) |
| Pb (petabit = 10^15) | PB (petabyte = 10^15) |
| Eb (exabit = 10^18)  | EB (exabyte = 10^18)  |
| Kib (kibibit = 2^10) | KiB (kibibyte = 2^10) |
| Mib (mebibit = 2^20) | MiB (mebibyte = 2^20) |
| Gib (gibibit = 2^30) | GiB (gibibyte = 2^30) |
| Tib (tebibit = 2^40) | TiB (tebibyte = 2^40) |
| Pib (pebibit = 2^50) | PiB (pebibyte = 2^50) |
| Eib (exbibit = 2^60) | EiB (exbibyte = 2^60) |

### Count-based Unit Names

A count-based unit is a noun that represents a discrete number of items, events, or actions.  For example, a count-based unit can be used to represent the number of requests, instances, tokens, or connections.  

If the following list of recommended values does not cover a count-based unit, a provider MAY introduce a new noun representing a count-based unit.  All nouns appearing in units that are not listed in the recommended values table will be considered count-based units.  A new count-based unit value MUST be capitalized.

| Count        |
|:-------------|
| Count        |
| Unit         |
| Request      |
| Token        |
| Connection   |
| Certificate  |
| Domain       |
| Core         |

### Time-based Unit Names

A time-based unit is a noun that represents a time interval.  Time-based units can be used to measure consumption over a time interval or in combination with another unit to capture a rate of consumption.  Time-based units MUST match one of the values listed in the following table.

| Time         |
|:-------------|
| Year         |
| Month        |
| Day          |
| Hour         |
| Minute       |
| Second       |

### Composite Units

If the unit value is a composite value made from combinations of one or more units, each component MUST also align with the set of recommended values.

Instead of "per" or "-" to denote a Composite Unit, slash ("/") and space(" ") MUST be used as a common convention.  Count-based units like requests, instances, and tokens SHOULD be expressed using a value listed in the count *dimension*.  For example, if a usage unit is measured as a rate of requests or instances over a period of time, the unit SHOULD be listed as "Requests/Day" to signify the number of requests per day.

## Exceptions

None

## Introduced (version)

1.0-preview
