# Billing Period Start

Billing Period Start represents the [*inclusive*](#glossary:inclusivebound) start date and time of a [*billing period*](#glossary:billing-period). For example, a time period where BillingPeriodStart is '2024-01-01T00:00:00Z' and [BillingPeriodEnd](#billingperiodend) is '2024-02-01T00:00:00Z' includes charges for January, since BillingPeriodStart is inclusive, but does not include charges for February since BillingPeriodEnd is [*exclusive*](#glossary:exclusivebound).

The BillingPeriodStart column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset), MUST be of type [Date/Time Format](#date/timeformat), MUST be an *inclusive* value, and MUST NOT contain null values. The sum of the [BilledCost](#billedcost) metric for [*rows*](#glossary:row) in a given *billing period* MUST match the sum of the invoices received for that *billing period* for a [*billing account*](#glossary:billing-account).

## Column ID

BillingPeriodStart

## Display Name

Billing Period Start

## Description

The [*inclusive*](#glossary:inclusivebound) start date and time of a [*billing period*](#glossary:billing-period).

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
