# Column: ChargeCategory

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                | Column                                                                                                                                                                                                                                                        |
| --------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR                     | `bill/BillType` (Anniversary, Purchase, Refund)<br>`lineItem/LineItemType` (Usage, Tax, BundledDiscount, Credit, Discount, DiscountedUsage, Fee, Refund, RIFee, SavingsPlanUpfrontFee, SavingsPlanRecurringFee, SavingsPlanCoveredUsage, SavingsPlanNegation) |
| GCP       | BigQuery Billing Export | `Cost type` (regular, tax, adjustment, or rounding error)                                                                                                                                                                                                     |
| Microsoft | Cost details            | `ChargeType` (Purchase, Usage, Refund, Adjustment, Tax?)<br><br>Related:<br>`PricingModel` (OnDemand, Reservation, SavingsPlan, Spot)<br>`Frequency` (OneTime, Recurring)                                                                                     |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Current value                      | ChargeCategory | Scenario                                                                                                                                                                                                                                                                                                                                                   |
| --------- | ---------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | Anniversary / Usage                | Usage      | Usage charged at on-demand rate for resources with resource id (EC2, EBS, RDS, RedShift)                                                                                                                                                                                                                                                                   |
| AWS       | Anniversary / Usage                | Usage      | Usage charged at on-demand rate for resources with "no resource id" (Support, CloudWatch, DataTransfer)                                                                                                                                                                                                                                                    |
| AWS       | Anniversary / Tax                  | Tax        | US sales tax or VAT with "no resource id"                                                                                                                                                                                                                                                                                                                  |
| AWS       | Purchase / Fee                     | Purchase   | All upfront and partial upfront fees for RI purchase                                                                                                                                                                                                                                                                                                       |
| AWS       | Purchase / RIFee                   | Purchase   | Monthly recurring RI amount for partial upfront and no upfront                                                                                                                                                                                                                                                                                             |
| AWS       | Purchase / SavingsPlanUpfrontFee   | Purchase   | All upfront and partial upfront fees for SP purchase                                                                                                                                                                                                                                                                                                       |
| AWS       | Purchase / SavingsPlanRecurringFee | Purchase   | Monthly recurring SP amount for partial upfront and no upfront                                                                                                                                                                                                                                                                                             |
| AWS       | Adjustments / SavingsPlanNegation  | Usage      | Used to negate the on-demand cost covered by SP                                                                                                                                                                                                                                                                                                            |
| AWS       | Anniversary / BundledDiscount      | Usage      | Usage based discount for free or discounted price. If a customer uses X units of product/service A, this customer gets Y units of product/service B at a discounted price (with a discount Z%).                                                                                                                                                            |
| AWS       | Refund                             | Adjustment |
| GCP       | regular                            | Usage      | These show up as rows that contain data of usage and costs                                                                                                                                                                                                                                                                                                 |
| GCP       | tax                                | Tax        | These show up as monthly rows without a project as a credit and with a project with a debit.                                                                                                                                                                                                                                                               |
| GCP       | adjustment                         | Adjustment | ![Screenshot of GCP cost details with type and mode columns.](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/assets/399533/af90e4cd-f3c0-448a-bb0f-0249bcf7135c)<br>Example 1:<br>Description: "Billing correction - Adjustment for project X for incorrect Flexible CUD charge"<br>Mode: "MANUAL_ADJUSTMENT"<br>Type: "GENERAL_ADJUSTMENT" |
| GCP       | rounding_error                     | Adjustment | These show up as monthly rows without a project as a credit                                                                                                                                                                                                                                                                                                |
| GCP       | credit                             | Adjustment | Fields: type, name, amount, full_name, id<br>![Screenshot of a table with a type column and 5 rows of example values](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/assets/399533/15bcc210-5a36-473b-aeac-c1d2682dfdc8)                                                                                                                    |
| Microsoft | Purchase                           | Purchase   | Upfront or recurring fee for Marketplace offers or commitment discounts.                                                                                                                                                                                                                                                                             |
| Microsoft | Usage                              | Usage      | Consumption-based usage of deployed resources.                                                                                                                                                                                                                                                                                                             |
| Microsoft | Refund                             | Adjustment | Refund provided by support.                                                                                                                                                                                                                                                                                                                                |
| Microsoft | Adjustment                         | Adjustment | Rounding errors.                                                                                                                                                                                                                                                                                                                                           |
| Microsoft | Tax                                | Tax        | US sales tax or VAT.                                                                                                                                                                                                                                                                                                                                       |

Current scenarios considered include:

### Option 1

| Value      | Description                          |
| :--------- | :------------------------------------|
| Refund     | Any adjustments that are applied after the original usage or purchase row. Adjustments may be related to multiple charges. (NOTE: Tax excluded)   |
| Credit     | Credits assoicated with promotional usage or incentives   |
| Purchase   | Charges for the acquisition of a service or resource bought upfront or on a recurring basis.              |
| Tax        | Applicable taxes that are levied by the relevant authorities. Tax charges may vary depending on factors such as the location, jurisdiction, and local or federal regulations. |
| Usage      | Charges based on the quantity of a service or resource that was consumed over a given period of time.     |

ISSUE: Tax cannot be classified correctly, assuming refunds and purchases have a tax implication then we would need to look for negative tax values matching the refund line in order ot acertain the total value of the refund.

### Option 2:

| Value      | Description                          |
| :--------- | :------------------------------------|
| Purchase   | Charges for the acquisition of a service or resource bought upfront or on a recurring basis.              |
| Tax        | Applicable taxes that are levied by the relevant authorities. Tax charges may vary depending on factors such as the location, jurisdiction, and local or federal regulations. |
| Usage      | Charges based on the quantity of a service or resource that was consumed over a given period of time.     |


New Column: Adjustment Category

| Value      | Description                          |
| :--------- | :------------------------------------|
| NULL       | Default value for all incomming charges.             |
| Refund     | Refunded related to usage or purchase specific activities (expects a matching 'tax' transaction) |
| Credit     | Promotional / negotiated / incentive credits provided at providers discression (does NOT expect a matching 'tax' transaction)       |

Permutations:

| Charge Category     | Adjustment Category         | Example usage                 |
| :--------- | :------------------------------------|:------------------------------|
|Usage       | NULL                                 | general usage                                                                                |
|Usage       | Refund                               | service specific refunds /..e.g miss billing                                                 |
|Usage       | Credit                               | service specific incentives                                                                  |
|Purchase    | NULL                                 | general marketplace or 3rd party purchase                                                    |
|Purchase    | Refund                               | bulk / general refunds                                                                       |
|Purchase    | Credit                               | Non-service / usage specific credits                                                         |
|Tax         | NULL                                 | general tax                                                                                  |
|Tax         | Refund                               | tax refund for usage or purchase refunded                                                    |
|Tax         | Credit                               | NOT APPLICABLE                                                                               |

### Option 3:

| Value      | Description                          |
| :--------- | :------------------------------------|
| Credit     | Credits assoicated with promotional usage or incentives   |
| Purchase   | Charges for the acquisition of a service or resource bought upfront or on a recurring basis.              |
| Tax        | Applicable taxes that are levied by the relevant authorities. Tax charges may vary depending on factors such as the location, jurisdiction, and local or federal regulations. |
| Usage      | Charges based on the quantity of a service or resource that was consumed over a given period of time.     |

New Column: Adjustment Category

| Value      | Description                          |
| :--------- | :------------------------------------|
| NULL       | Default value for all incomming charges.             |
| Refund     | Refunded related to usage or purchase specific activities (expects a matching 'tax' transaction) |
| Bulk Refund     | General refund (expects a matching 'tax' transaction) |
| Rounding Error     | Small corrections - Applicable to current billing period only |
| Other    | Catch all       |

Permutations:

| Charge Category     | Adjustment Category         | Example usage                 |
| :--------- | :------------------------------------|:------------------------------|
|Usage       | NULL                                 | general usage                                                                                |
|Usage       | Refund                               | service specific refunds /..e.g miss billing                                                 |
|Purchase    | NULL                                 | general marketplace or 3rd party purchase                                                    |
|Purchase    | Refund                               | specific / 3rd party refund                                                                  |
|Tax         | NULL                                 | general tax                                                                                  |
|Tax         | Refund                               | tax refund for usage or purchase refunded                                                    |
|Credit      | NULL                                 | service specific incentives                                                                  |
|Credit      | Other                                | vendor specific / non usage related incentives                                               |


## Discussion / Scratch space

- What are the different types of spend that we want to group?
- This work is to group the different values providers use to differentiate the spend. The plan is to introduce a ‘normalized’ dimension for this in v1.0
  - Should this be prefixed with ‘Provider’ since we want to normalize this as well? If not, we have to come up with another name for the normalized column
    - Decided that this should be a normalized column from v0.5.
    - Given the mis-alignment of current vendor data, its not going to be much value to create a dimension where we put different vendor values in a single column so practitioners can use the vendor provided value using a single column rather than doing n different where clauses when looking for the vendor native value (not our normalized value).
- This dimension may be referred to in other contexts - e.g. data granularity requirements (attribute) may change based on if its usage data vs tax or fees. For example, Should ResourceId be required based on if something is a ‘usage’ cost vs a ‘purchase’?
- Use cases:
  - Usage for cost reporting use cases / driving accountability
  - Tax needs to be filterable for special accounting treatments within companies
  - Fees are important for cost allocation / amortization - needs to be isolated from other cost
  - Refunds - $s coming back after the original charge
  - Credits are typically based on agreements for migration of workloads
  - AWS handling for SPs: Anniversary charge (BillType) Savings Plan for $1 and a negation for UsageType (for -0.50)
- Is it Recurring or not? (Attribute about the Purchase?)
- What Charge Category values can BE recurring?
- What Charge Category values for "Free Tier" with usage limits and "Free Trial" offers?
- What adjustment categories do we need to group?
- Do we need to normalize adjustment categories?
- Refunds - $s coming back after the original charge
- Credits are typically based on agreements for migration of workloads, or promotional items negotiated with the provider
- Balance transfers - how do you show what a balance transfer is if in the unliely event you close an account with a positive value and open a new account

### Example mappings for normalized values

| Provider  | Usage                                                                                                | Purchase                                                         | Adjustment               | Tax |
| --------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------ | --- |
| AWS       | DiscountedUsage<br>Discount<br>SavingsPlanCoveredUsage<br>BundledDiscount<br>SavingsPlanNegation (?) | SavingsPlanRecurringFee<br>SavingsPlanUpfrontFee<br>RIFee<br>Fee | Refund<br>Credits        | Tax |
| GCP       | regular                                                                                              |                                                                  | rounding_error<br>credit | tax |
| Microsoft | Usage                                                                                                | Purchase                                                         | Refund<br>Adjustment     | Tax |

### Examples of how Charge Type relates to Pricing Category / Charge Frequency columns

| Scenario                                                     | ChargeCategory | ChargeSubcategory | PricingCategory | ChargeFrequency | CommitmentDisocuntUsage |
| ------------------------------------------------------------ | -------------- | ----------------- | --------------- | --------------- | ----------------------- |
| Upfront discount purchase                                    | Purchase       | NULL              | Standard        | One-time        | NULL                    |
| Partial Upfront discount monthly fee                         | Purchase       | NULL              | Standard        | Recurring       | NULL                    |
| Usage covered by upfront portion of partial upfront discount | Usage          | NULL              | Committed       | Usage-based     | Unused                  |
| Unused commitment of partial upfront discount                | Usage          | NULL              | Committed       | Usage-based     | Used                    |
| Usage not covered by discount                                | Usage          | On-Demand         | Standard        | Usage-based     | NULL                    |
| Refund                                                       | Adjustment     | Refund            | NULL            | One-time        | NULL                    |
| Usage invoice tax charge                                     | Tax            | NULL              | NULL            | Recurring       | NULL                    |
