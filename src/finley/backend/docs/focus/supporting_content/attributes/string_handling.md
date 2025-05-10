# String Handling

## Example usage scenarios

Sample known issues observed in billing data and other data sources for various scenarios:

| Provider  | Data set                 | Scenario                                                                                    |
| --------- | ------------------------ | ------------------------------------------------------------------------------------------- |
| AWS       | CUR                      | ?                                                                                           |
| GCP       | Big Query Billing Export | ?                                                                                           |
| Microsoft | Cost Details             | Known issue with ResourceId casing                                                          |
| OCI       | Cost reports             | Known issue with PricingUnits casing - Cost reports vs CustomPriceSheet vs PublicPriceSheet |

## Discussion / Scratch space

### Attribute scope

#### Consistency regardless of who controls the String value

* Provider-controlled columns: Initial discussion revolved around consistent casing for provider-specified String values.
* End-user-controlled columns: Recognized the need to establish consistency-related requirements for end-user-controlled String columns.
* FOCUS-controlled columns: Noted that these requirements also apply to FOCUS-controlled String value-capturing columns.

#### String columns and Value format options

* Current Value format options for String columns are:
  * `currency code format`,
  * `unit format`,
  * `allowed values`,
  * and `not specified`.

* **Addressing String columns with `Value format`: `not specified` is our primary goal**, given the other Value formats already address consistency concerns.

### Attribute name alternatives and reference to the attribute

* Name alternatives:
  * String Format
  * String Handling **<-- selected by the group**
  * String Consistency Handling
  * Other suggestions?

* How should we reference the attribute?
  * Explicitly within individual column specs (in normative paragraph and constraint table, similar to e.g. Unit and Value)?
  * Implicitly applicable to all String columns without explicitly referencing it in individual column specs (similar to null-handing)? **<-- selected by the group**

* To avoid unintentionally suggesting a higher priority for these specific columns, current references to value-format consistency requirements were removed from the following columns:
  * RegionId
  * RegionName
  * ResourceType
  * CommitmentDiscountType

### Requirements and Exceptions

#### Requirements and Exceptions - v1.3

* Requirements:
  * String values MUST maintain the original casing, spacing, and other relevant consistency factors as specified by providers and/or end-users.
  * Changes to mutable string values (e.g., resource names) MUST be accurately reflected in charges related to subsequent costs incurred after the string value change and MUST NOT alter the original values in historical records, preserving data integrity and auditability for past billing periods.
  * Immutable string values that refer to the same entity (e.g., resource identifiers) MUST remain consistent and unchanged across all billing periods.

* Exceptions:
  * None

#### Requirements and Exceptions - v1.2

* Requirements:
  * **String values appearing in the billing data MUST maintain the original casing, spacing, and other pertinent consistency factors.**
  * **String values referring to the same entity SHOULD be consistent within a provider's context.**
    * FOCUS scope is limited to billing data therefor SHOULD opposed to MUST
  * **The provider SHOULD ensure that both provider-defined and user-input String values do not contain multiple consecutive spaces or leading/trailing spaces.**
    * Include in the spec or only mention in the supporting content?
  * **String-formatted columns MUST also adhere to null handling requirements.**
    * Should null handling requirements be limited to provider-defined String values? For instance, is it ok to impose null if a provider didn't ensure the prevention of empty Strings at input?

* Exceptions:
  * None

#### Requirements and Exceptions - v1.1

* Requirements:
  * String values that refer to the same entity MUST be consistent (e.g., casing and spacing) within the context of the provider.
  * String values MUST be provided with the original casing.
  * Multiple consecutive spaces within a String MUST be reduced to a single space.
  * String values MUST NOT contain leading or trailing spaces.
  * String-formatted columns MUST also adhere to null handling requirements.

* Exceptions:
  * User-controlled columns MAY contain multiple consecutive spaces and/or leading or trailing spaces.
