# Discount Types

## Example implementation of the Discount Handling attribute

Let's say you have 3 discounts:

1. **10% negotiated** discount
2. **10% bundled** discount
3. **$1/hour spend commitment** purchased for **$0.50/hour**

For the sake of this example, let's say the negotiated and bundled discounts cap out and don't apply to all resources to demonstrate what happens with a partially undiscounted amount.

All examples are $0.05/minute for hourly data...

| Scenario | Resource | Qty | List | OnDemand | Billed | Effective |
|-----------|-----------|------|-----|--------------|-------|-----------|
| No discounts | Foo0 | 60 | $3.00 | $3.00 | $3.00 | $3.00 |
| Negotiated only | Foo1 |  60 | $3.00 | $2.70 | $2.70 | $2.70 |
| Commitment only | Foo2 |  20 | $1.00 | $1.00 | $0.00 | $0.50 |
| Uncommitted part | Foo2 | 40 | $2.00 | $2.00 | $2.00 | $2.00 |
| Commitment only | Foo3 | 10 | $0.50 | $0.50 | $0.00 | $0.25 |
| Unused commitment | | | $0.00 | $0.00 | $0.00 | $0.25 |
| Negotiated +&nbsp;committed | Foo4 | 22.22 | $1.11 | $1.00 | $0.00 | $0.50 |
| Negotiated +&nbsp;uncommitted | Foo4 | 37.78 | $1.89 | $1.70 | $1.70 | $1.70 |
| All discounts<sup>1</sup> | Foo5 | 24.69 | $1.11 | $1.00 | $0.00 | $0.50 |
| Negotiated +&nbsp;bundled | Foo5 | 5.31 | $0.24 | $2.15 | $2.15 | $2.15 |
| Negotiated only | Foo5 | 15 | $0.75 | $0.67 | $0.67 | $0.67 |
| All discounts capped out | Foo5 | 15 | $0.75 | $0.75 | $0.75 | $0.75 |

<sup>_1. As we've defined SKUs, bundled discounts would be applied to the list price, so that's why it doesn't look like there's a discount applied compared to Foo4._</sup>

Explanation of the unused commitment row:

1. The **Foo3** resource only used **10min @ $0.05/min**.
2. This is **$0.50** list _and_ on-demand since the negotiated discount doesn't apply on this row for the sake of the example (see Foo5 for stacked discounts).
3. The billed cost is nothing, since this $0.50 was covered by the spend commitment.
4. Since the spend commitment was for $1/hour, this means there's $0.50 left that was not used.
5. The "Unused commitment" row is for that unused amount.
   - List, billed, and on-demand costs are nothing since there was no usage and nothing was billed.
   - Effective cost is the unused amount of the spend commitment ($0.50 in this case).
   - Since spend commitments don't have a unit or a price, they won't have a quantity, so the unused amount doesn't have a quantity.
   - The only thing it has is the unused amount, which is the effective price per hour ($0.50), minus the used portion ($0.25).
   - **_Why $0.25?_**
     - The commitment was $1/hour with a 50% discount per hour.
     - This means the effective/amortized cost per hour is $0.50.
     - The on-demand cost was $0.50. After applying the amortized price, it's 50% off or $0.25.
     - Since the on-demand cost was only $0.50, there's still another $0.50 left unused.
     - And when you apply the 50% discount on the unused portion, you get $0.25.
     
Providers offer various discounting schemes for their service offerings. These discounts typically fall into common types such as:

- Commitment discounts
- Tier-based discounts
- Negotiated discounts
- Promotional discounts
- Usage-based discounts
- Partner discounts

## Commitment discounts

- Usage-based commitment discounts
- Spend-based commitment discounts

## Tier-based discounts

Provider partners usually receive discounts (along with other benefits) based on the partnership tier.

- AWS
  - Select Tier
  - Advanced Tier
  - Premier Tier

- Microsoft
  - Service
    - Member
    - Action Pack
    - Solutions Partner
    - Specialist
  - ISV
    - Member
    - Founders Hub
    - ISV Success

- GCP
  - Partner Level
  - Premier Level

## Negotiated discounts

TBD

## Promotional discounts

- Free Trial
- Promotion discounts given by sales representatives to onboard customers.

## Usage-based discounts

- An example of this is GCP's [Sustained use discounts](https://cloud.google.com/compute/docs/sustained-use-discounts) which are still usage-based but not associated to any commitments.
- AWS' RI Volume discounts?

## Partner discounts

- Private Rate Discounts
- Enterprise Discount Program
- Solution Provider Program
- RESELLER_MARGIN

# Links to documentation

- AWS
  - Reserved Instances - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html
  - Savings Plans - https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html
  - Bundled discounts - https://aws.amazon.com/blogs/aws-cloud-financial-management/bundled-discounts-in-aws-cost-and-usage-report/
  - AWS partner tiers - https://aws.amazon.com/partners/services-tiers/

- GCP
  - Committed use discounts - https://cloud.google.com/compute/docs/instances/committed-use-discounts-overview
  - Resource-based CUDs - https://cloud.google.com/compute/docs/instances/signing-up-committed-use-discounts
  - Spend-based CUDs - https://cloud.google.com/docs/cuds-spend-based
  - Sustained use discounts - https://cloud.google.com/compute/docs/sustained-use-discounts
  - Credit types - https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage#standard-usage-cost-data-schema
  - GCP Partner Advantage - https://cloud.google.com/partners/become-a-partner

- Microsoft
  - Reservations - https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations
  - Savings Plans - https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview
  - Azure Hybrid Benefit - https://azure.microsoft.com/en-us/pricing/hybrid-benefit/#overview
  - Azure Dev/Test Pricing - https://azure.microsoft.com/en-us/pricing/offers/dev-test/
  - Microsoft Partnership - https://partner.microsoft.com/en-us/partnership/compare-programs

# Discussion / Scratch space

- AWS discount types include:
  - DiscountedUsage - discounts covered by Reserved Instances
  - SavingsPlanCoveredUsage - discounts covered by SavingsPlans
  - EdpDiscount - Enterprise Discount Program
  - SppDiscount - Solutions Provider Program
  - RiVolumeDiscount
  - BundledDiscount - discounted usage on a specific product/service based on the usage of another product/service.

- GCP discount types include:
  - DISCOUNT - credits earned after a contractual spending threshold is reached.
  - COMMITTED_USAGE_DISCOUNT - resource-based commitment discounts.
  - COMMITTED_USAGE_DISCOUNT_DOLLAR_BASE - Spend-based commitment discounts.
  - SUSTAINED_USAGE_DISCOUNT - automatic discount earned for prolonged usage.
    > [!NOTE]
    > Sustained Use Discounts (SUDs) are handled as after-the-fact adjustments (aka credits) and do not apply to the Discount Handling attribute since this attribute requires that discounts be applied directly to the row they're discounting.
  - FREE_TIER - free resource usage up to specified limits.
  - PROMOTION - includes free tial, marketing campaign credits, or other grants to use GCP.
  - RESELLER_MARGIN - indicates the Reseller Program Discounts earned on every eligible line item.
  - SUBSCRIPTION_BENEFIT - credits earned by purchasing long-term subscriptions to services in exchange for discounts.

- Where does spot pricing discount fall under? Should there be a **Usage-based discounts** type?
  - We decided to handle spot as PricingCategory = `Dynamic` and PricingSubcategory = `Spot`.
  - We have not yet discussed if there are any special nuances to how spot pricing works that should be explicitly incorporated into Discount Handling beyond identification of spot-priced charges.

- Where does GCP's sustained usage discount fall under? Maybe the same as spot instance, in which case, **Usage-based discounts**?
  - Since GCP SUDs are an after-the-fact discount that includes a negative charge, they're being tracked as ChargeCategory = `Credit`.
  - In the main spec content, SUDs are covered by the "Any price or cost reductions that are awarded after the fact are identified as a `Credit` Charge Category" sentence.

- Microsoft discounts include:
  - Azure consumption discounts
  - Reservations and Savings Plans
  - CSP software subscriptions
  - Office 365, Dynamics 365, Microsoft 365 discounts
  - Azure Hybrid Benefit
  - Azure Dev/Test Pricing
