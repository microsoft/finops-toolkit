# Number Scale

The number scale of the data provides the maximum number of digits after the decimal point in decimal numbers.

NumberScale SHOULD be provided in the FOCUS Metadata schema for Decimal columns. NumberScale MUST be of type Integer and MUST NOT contain null values.

## Metadata ID

NumberScale

## Metadata Name

Number Scale

## Content constraints

| Constraint    | Value                            |
|:--------------|:---------------------------------|
| Feature level | Conditional                      |
| Allows nulls  | False                            |
| Data type     | Integer                          |
| Value format  | [Numeric Format](#numericformat) |

## Introduced (version)

1.0