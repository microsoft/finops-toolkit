# Capacity Reservation ID

A Capacity Reservation ID is the identifier assigned to a [*capacity reservation*](#glossary:capacity-reservation) by the provider. Capacity Reservation ID is commonly used for scenarios to allocate charges for capacity reservation usage.

The CapacityReservationId column adheres to the following requirements:

* CapacityReservationId MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports *capacity reservations* and MUST be of type String.
* CapacityReservationId SHOULD NOT be null when a charge is related to a capacity reservation.
* CapacityReservationId MUST NOT be null when a charge represents the unused portion of a *capacity reservation*.
* CapacityReservationId MUST be null when a charge is not related to a *capacity reservation*.
* CapacityReservationId MUST ensure global uniqueness within the provider and SHOULD be a fully-qualified identifier.

## Column ID

CapacityReservationId

## Display Name

Capacity Reservation ID

## Description

The identifier assigned to a *capacity reservation* by the provider.

## Content constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

1.1
