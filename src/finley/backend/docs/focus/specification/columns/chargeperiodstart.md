# Charge Period Start

Charge Period Start represents the [*inclusive*](#glossary:inclusivebound) start date and time within a [*charge period*](#glossary:chargeperiod). For example, a time period where ChargePeriodStart is '2024-01-01T00:00:00Z' and [ChargePeriodEnd](#chargeperiodend) is '2024-01-02T00:00:00Z' includes charges for January 1, since ChargePeriodStart is *inclusive*, but does not include charges for January 2 since ChargePeriodEnd is [*exclusive*](#glossary:exclusivebound).

ChargePeriodStart MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset), MUST be of type Date/Time, MUST be an *inclusive* value, and MUST NOT contain null values. ChargePeriodStart MUST match the beginning date and time boundary of the effective period of the charge.

## Column ID

ChargePeriodStart

## Display Name

Charge Period Start

## Description

The [*inclusive*](#glossary:inclusivebound) start date and time within a [*charge period*](#glossary:chargeperiod).

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
