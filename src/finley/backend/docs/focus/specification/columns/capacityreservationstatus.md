# Capacity Reservation Status

Capacity Reservation Status indicates whether the charge represents either the consumption of the [*capacity reservation*](#glossary:capacity-reservation) identified in the CapacityReservationId column or when the *capacity reservation* is unused.

The CapacityReservationStatus column adheres to the following requirements:

* CapacityReservationStatus MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports *capacity reservations* and MUST be of type String.
* CapacityReservationStatus MUST be null when CapacityReservationId is null.
* CapacityReservationStatus MUST NOT be null when CapacityReservationId is not null and [ChargeCategory](#chargecategory) is "Usage".
* CapacityReservationStatus MUST be one of the allowed values.
* CapacityReservationStatus MUST label all unused *capacity reservation* charges and MUST label used *capacity reservation* charges if the provider supports it.

## Column ID

CapacityReservationStatus

## Display Name

Capacity Reservation Status

## Description

Indicates whether the charge represents either the consumption of a *capacity reservation* or when a *capacity reservation* is unused.

## Content constraints

| Constraint      | Value          |
| :-------------- | :------------- |
| Column type     | Dimension      |
| Feature level   | Conditional    |
| Allows nulls    | True           |
| Data type       | String         |
| Value format    | Allowed Values |

Allowed values:

| Value  | Description                                                                 |
| :----- | :-------------------------------------------------------------------------- |
| Used   | Charges that utilized a specific amount of a capacity reservation.          |
| Unused | Charges that represent the unused portion of a capacity reservation.        |

## Introduced (version)

1.1
