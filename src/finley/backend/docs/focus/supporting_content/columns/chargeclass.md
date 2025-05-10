# Column: Charge Class

## Discussion / Scratch space

### Discussion on column nullability and allowed values

* Initially, ChargeClass was defined as a non-nullable column with two allowed values: Regular and Correction.
* Various alternative names for Regular charges were discussed, including Regular, Standard, Original, and Direct.
* Eventually, the team decided on a nullable column approach, where Correction is the sole allowed value, representing corrections to a previously invoiced billing period.

### Impacts of 1.0 ChargeCategory and ChargeClass cleanup

The following table serves as the basis for reviewing the SkuPriceId spec, as well as price, cost, quantity metrics, etc., impacted by the ChargeCategory and ChargeClass columns cleanup.

| ChargeCategory | ChargeClass | perSku/bulk                    | SkuId            | SkuPriceId       |
|----------------|-------------|--------------------------------|------------------|------------------|
| Usage          | (null)      | MUST be perSku and perSkuPrice | MUST not be null | MUST not be null |
| Usage          | Correction  | MAY be bulk                    | MAY be null      | MAY be null      |
| Purchase       | (null)      | MUST be perSku and perSkuPrice | MUST not be null | MUST not be null |
| Purchase       | Correction  | MAY be bulk                    | MAY be null      | MAY be null      |
| Credit         | (null)      | MAY be bulk                    | MAY be null      | MAY be null      |
| Credit         | Correction  | MAY be bulk                    | MAY be null      | MAY be null      |
| Adjustment     | (null)      | MAY be bulk                    | MAY be null      | MAY be null      |
| Adjustment     | Correction  | MAY be bulk                    | MAY be null      | MAY be null      |
| Tax            | (null)      | MUST be bulk                   | MUST be null     | MUST be null     |
| Tax            | Correction  | MUST be bulk                   | MUST be null     | MUST be null     |
