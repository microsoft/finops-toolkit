# Billing Period End

Billing Period End represents the [*exclusive*](#glossary:exclusivebound) end date and time of a [*billing period*](#glossary:billing-period). For example, a time period where [BillingPeriodStart](#glossary:billingperiodstart) is '2024-01-01T00:00:00Z' and BillingPeriodEnd is '2024-02-01T00:00:00Z' includes charges for January, since BillingPeriodStart is [*inclusive*](#glossary:inclusivebound), but does not include charges for February since BillingPeriodEnd is *exclusive*.

The BillingPeriodEnd column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset). This column MUST be of type [Date/Time Format](#date/timeformat), MUST be an *exclusive* value, and MUST NOT contain null values. The sum of the [BilledCost](#billedcost) column for [*rows*](#glossary:row) in a given *billing period* MUST match the sum of the invoices received for that *billing period* for a [*billing account*](#glossary:billing-account).

## Column ID

BillingPeriodEnd

## Display Name

Billing Period End

## Description

The [*exclusive*](#glossary:exclusivebound) end date and time of a [*billing period*](#glossary:billing-period).

## Content Constraints

| Constraint      | Value                                |
|:----------------|:-------------------------------------|
| Column type     | Dimension                            |
| Feature level   | Mandatory                            |
| Allows nulls    | False                                |
| Data type       | Date/Time                            |
| Value format    | [Date/Time Format](#date/timeformat) |

## Introduced (version)

0.5
