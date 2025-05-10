# SKU Price Details

The SKU Price Details column represents a list of relevant properties shared by all charges with the same [SKU Price ID](#skupriceid). These properties provide qualitative and quantitative details about the service represented by a SKU Price ID. This can enable practitioners to calculate metrics such as total units of a service when it is not directly billed in those units (e.g. cores) and thus enables FinOps capabilities such as unit economics. These properties can also help a practitioner understand the specifics of a SKU Price ID and differentiate it other SKU Price IDs.

The SkuPriceDetails column adheres to the following requirements:

* The SkuPriceDetails column MUST be in [KeyValueFormat](#key-valueformat).
* The key for a property SHOULD be formatted in [PascalCase](#glossary:pascalcase).
* The properties (both keys and values) contained in the SkuPriceDetails column MUST be shared across all charges having the same SkuPriceId, subject to the below provisions.
  * Additional properties (key-value pairs) MAY be added to SkuPriceDetails going forward for a given SkuPriceId.
  * Properties SHOULD NOT be removed from SkuPriceDetails for a given SkuPriceId, once they have been included.
  * Individual properties (key-value pairs) SHOULD NOT be modified for a given SkuPriceId and SHOULD remain consistent over time.
* The key for a property SHOULD remain consistent across comparable SKUs having that property and the values for this key SHOULD remain in a consistent format.
* The SkuPriceDetails column MUST NOT contain properties which are not applicable to the corresponding SkuPriceId.
* The SkuPriceDetails column MAY contain properties which are already captured in other dedicated columns.
* If a property has a numeric value, it MUST represent the value for a single [PricingUnit](#pricingunit).
* The SkuPriceDetails column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider includes a SkuPriceId.
  * The SkuPriceDetails column MAY be null when SkuPriceId is not null.
  * The SkuPriceDetails column MUST be null when SkuPriceId is null.

## Examples

```json
{
    "OperationClass": "A",
    "PricingTier": 2,
    "CoreHours": 4,
    "PreimumProcessing": true,
}
```

## Column ID

SkuPriceDetails

## Display Name

SKU Price Details

## Description

A set of properties of a SKU Price ID which are meaningful and common to all instances of that SKU Price ID.

## Content Constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | JSON             |
| Value format    | [Key-Value Format](#key-valueformat) |

## Introduced (version)

1.1
