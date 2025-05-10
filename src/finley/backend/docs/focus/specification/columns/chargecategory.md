# Charge Category

Charge Category represents the highest-level classification of a charge based on the nature of how it is billed. Charge Category is commonly used to identify and distinguish between types of charges that may require different handling.

The ChargeCategory column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) and MUST NOT be null. This column is of type String and MUST be one of the allowed values.

## Column ID

ChargeCategory

## Display Name

Charge Category

## Description

Represents the highest-level classification of a charge based on the nature of how it is billed.

## Content Constraints

| Constraint      | Value          |
| :-------------- | :------------- |
| Column type     | Dimension      |
| Feature level   | Mandatory      |
| Allows nulls    | False          |
| Data type       | String         |
| Value format    | Allowed values |

Allowed values:

| Value      | Description                          |
| :--------- | :------------------------------------|
| Usage      | Positive or negative charges based on the quantity of a service or resource that was consumed over a given period of time including refunds.     |
| Purchase   | Positive or negative charges for the acquisition of a service or resource bought upfront or on a recurring basis including refunds.              |
| Tax        | Positive or negative applicable taxes that are levied by the relevant authorities including refunds. Tax charges may vary depending on factors such as the location, jurisdiction, and local or federal regulations. |
| Credit      | Positive or negative charges granted by the provider for various scenarios e.g promotional credits or corrections to promotional credits.     |
| Adjustment      | Positive or negative charges the provider applies that do not fall into other category values.    |

## Introduced (version)

0.5
