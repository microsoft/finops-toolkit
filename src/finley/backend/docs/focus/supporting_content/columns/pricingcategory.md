# Column: PricingCategory

## Example provider mappings

Current column mappings found in available data sets:

| Provider     | Data set                | Column                 | Example Values                                                 |
| ------------ | ----------------------- | ---------------------- | -------------------------------------------------------------- |
| AWS          | CUR                     | product/PurchaseOption | On-Demand, Reserved Instances, Spot Instances, Dedicated Hosts |
| Google Cloud | BigQuery Billing Export | (None)                 | (None)                                                         |
| Microsoft    | Cost Details            | PricingModel           | OnDemand, Spot, Reservation, SavingsPlan                       |

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                    | Provider value     | PricingCategory | PricingSubcategory |
| --------- | --------------------------- | ------------------ | --------------- | ------------------ |
| AWS       | CUR (PurchaseOption)        | On-Demand          | Standard        | (depends on usage) |
| AWS       | CUR (PurchaseOption)        | Reserved Instances | Committed       | Committed Usage    |
| AWS       | CUR (PurchaseOption)        | Spot Instances     | Dynamic         | Spot               |
| AWS       | CUR (PurchaseOption)        | Dedicated Hosts    | Standard        | (depends on usage) |
| Microsoft | Cost Details (PricingModel) | OnDemand           | Standard        |                    |
| Microsoft | Cost Details (PricingModel) | SavingsPlan        | Committed       | Committed Spend    |
| Microsoft | Cost Details (PricingModel) | Reservation        | Committed       | Committed Usage    |
| Microsoft | Cost Details (PricingModel) | Spot               | Reservation     |                    |

## Documentation

* AWS: https://docs.aws.amazon.com/cur/latest/userguide/product-columns.html
* GCP
* Microsoft: https://learn.microsoft.com/azure/cost-management-billing/automate/understand-usage-details-fields

## Discussion Topics

* Goal of the column is to enable practitioners to identify charges that have reduced prices vs. not.
  * The most common question for this column is to identify commitment discounts and spot separate from on-demand.
* In 0.5, we didn't have enough time to close on how spot would be included:
  * Someone mentioned that "spot" was a marketing term, so we tried to avoid it.
  * We discussed values like "Preemptible" (confusing), "Interruptible" (not a pricing model), "Market-Based", "Variable", and "Dynamic". Ultimately, we agreed on "Dynamic".
  * Then we questioned whether it "Dynamic" would be clear enough to practitioners who are looking for spot usage.
* In 1.0:
  * We brought PricingModel back into discussion and had the same issues with "spot" being clearly understood as "Dynamic" so we decided to focus on other columns first.
  * Over time, we got several requests to add a "PricingModel" column (that name explicitly), so we brought it back into discussion again.
  * We agreed to add PricingModel as-is (with spot showing as "Dynamic").
* While in PR, one member shared a link to IBM's documentation about how you're charged: https://cloud.ibm.com/docs/billing-usage?topic=billing-usage-charges
  * IBM talks about Fixed, Metered, Tiered, and Reserved values.
  * We discussed this and decided that this was too detailed for PricingModel and would look at it in the future in another column.
  * The main concern about bringing these values in is that to get the on-demand costs, you'd have to look at 2 values, which makes it more complicated for practitioners.
* There was a poll with all members to determine if we should merge "Fixed" and "On-Demand" pricing options since they sounded near identical.
  * 8 preferred merging and 3 preferred keeping them separate, so we decided to merge them.
  * This was also discussed in the weekly member meeting, where people questioned using "On-Demand" for things that don't have a "pricing" model.
  * We decided to use null when there is no price (SkuPriceId is null).
  * As a note, multiple people have commented on nulls being more difficult for data analysis (since there's no clear meaning to why it's null). We did not have time to discuss this in the meeting, but it's something we should discuss in the future as it applies to all columns.
  * The group also asked to add an "Other" option to account for any new pricing model that may come up in the future.
* Later, while still in PR, there was a concern about "dynamic on-demand pricing":
  * This brought the IBM values of Fixed, Metered, Tiered, and Reserved back into the discussion as those were a more detailed version of what we were trying to do.
  * We discussed this and decided that this was too detailed for PricingModel and would look at it in the future in another column.
  * A few weeks before this, we as a group decided to use the term "Category" for normalized types and we also introduced a ChargeSubcategory column as the next level grouping.
  * Based on this Category/Subcategory pattern, we decided to break PricingModel into PricingCategory and PricingSubcategory, adding a more detailed breakdown of each category.
  * Regarding "dynamic on-demand", this isn't possible given our current definitions (always-changing price vs. predetermined set price).
  * As part of these discussions, we also discussed whether "On-Demand" was the right term.
    * We discussed "Standard" as a replacement, but agreed "On-Demand" is more common and clear for the pricing model of pricing that is based on the published price for the billing account. (Note: Tiered pricing (aka volume-based discounts) are also predetermined and published, so they are also "On-Demand" by our definition.)
    * We felt "Standard" was more clear as a differentiator from "Tiered" pricing. Another alternative was "Flat Rate".
  * We also discussed whether to use "Commitment-Based" or "Discounted".
    * If we use "Discounted", then any future discounting strategy could get rolled into a single column without the need to change values.
    * The main downside of this is that, given how important commitment discounts are (and the fact that they are one of the primary reasons for adding this column), we felt it was important to call them out explicitly.
    * Additionally, given different discount strategies will price things differently, it's also important that we distinguish the separate pricing models at the top level.
    * We also didn't have any other clear examples that would fall into "Discounted" pricing that would be meaningfully grouped together in a way that practitioners would want to see together and not distinguished separately from their committed costs.
  * We also discussed the term "Dynamic" and whether it was clear enough.
    * During this, we discovered that "spot" is not a marketing term and is in fact a pricing construct for an always-changing price that a good or service can be immediately sold at.
    * We discussed replacing "Dynamic" with "Spot", but agreed that "Dynamic" is more inclusive of other types of dynamic pricing models that may be introduced in the future and would likely be desirable to be grouped together.
  * Given we cannot predict all pricing models that will be introduced in the future, we decided to also add "Other" in each subcategory.
* Unfortunately, we didn't think we had enough time to close PricingSubcategory, so we decided to hold that for after 1.0.
* On April 3, 2024, we agreed to change "On-Demand" to "Standard" and "Commitment-Based" to "Committed".

Open issues:

* Issues with null values (e.g., usability, dimensional modeling).
* Define PricingSubcategory column.
* Define principles to support PricingCategory values (similar to ServiceCategory).
* Consider defining an attribute that applies to all Category/Subcategory columns (e.g., must have principles, "Other" value).
