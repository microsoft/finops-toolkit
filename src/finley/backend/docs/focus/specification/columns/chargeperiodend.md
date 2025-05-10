# Charge Period End

Charge Period End represents the [*exclusive*](#glossary:exclusivebound) end date and time of a [*charge period*](#glossary:chargeperiod). For example, a time period where [ChargePeriodStart](#chargeperiodstart) is '2024-01-01T00:00:00Z' and ChargePeriodEnd is '2024-01-02T00:00:00Z' includes charges for January 1, since ChargePeriodStart is [*inclusive*](#glossary:inclusivebound), but does not include charges for January 2 since ChargePeriodEnd is *exclusive*.

ChargePeriodEnd MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset), MUST be of type Date/Time, MUST be an *exclusive* value, and MUST NOT contain null values. ChargePeriodEnd MUST match the ending date and time boundary of the effective period of the charge.

## Column ID

ChargePeriodEnd

## Display Name

Charge Period End

## Description

The [*exclusive*](#glossary:exclusivebound) end date and time of a charge period.

## Content constraints

| Constraint      | Value                                |
|:----------------|:-------------------------------------|
| Column type     | Dimension                            |
| Feature level   | Mandatory                            |
| Allows nulls    | False                                |
| Data type       | Date/Time                            |
| Value format    | [Date/Time Format](#date/timeformat) |

## Introduced (version)

0.5
