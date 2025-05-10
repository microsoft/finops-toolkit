# SKU Meter

The SKU Meter describes the functionality being metered or measured by a particular SKU in a charge.

Providers often have billing models in which multiple SKUs exist for a given service to describe and bill for different functionalities for that service. For example, an object storage service may have separate SKUs for functionalities such as object storage, API requests, data transfer, encryption, and object management. This field helps practitioners understand which functionalities are being metered by the different SKUs that appear in a [*FOCUS dataset*](#glossary:FOCUS-dataset).

The SkuMeter column adheres to the following requirements:

* SkuMeter MUST be present in a *FOCUS dataset* when when the provider includes a [SkuId](#skuid).
* SkuMeter MUST be of type String.
* SkuMeter MUST be null when SkuId is null.
* SkuMeter SHOULD NOT be null when SkuId is not null.
* SkuMeter SHOULD remain consistent over time for a given SkuId.

## Examples

Compute Usage, Block Volume Usage, Data Transfer, API Requests

## Column ID

SkuMeter

## Display Name

SKU Meter

## Description

Describes the functionality being metered or measured by a particular SKU in a charge.

## Content Constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | String           |
| Value format    | \<not specified> |

## Introduced (version)

1.1
