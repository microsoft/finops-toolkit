---
title: Convert cost and usage data to FOCUS
description: This document provides guidance for converting existing Cost Management datasets to the FinOps Open Cost and Usage Specification (FOCUS).
author: flanakin
ms.author: micflan
ms.date: 06/16/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to convert existing Cost Management datasets to the FinOps Open Cost and Usage Specification (FOCUS).
---

<!-- markdownlint-disable-next-line MD025 -->
# Convert Cost Management data to FOCUS

This document provides guidance for converting Cost Management actual and amortized datasets to the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, refer to the [FOCUS overview](what-is-focus.md).

<br>

## How to convert Cost Management data to FOCUS

In order to convert cost and usage data to FOCUS, you will need both the actual and amortized cost datasets:

- Keep all rows from the amortized cost data.
- Filter the actual cost data to only include rows where ChargeType == "Purchase" or "Refund" and PricingModel == "Reservation" or "SavingsPlan".

Apply the following logic to all of the rows:

| FOCUS column               | Cost Management column                                                                             | Transform                                                                                                                                                                                                                                                                                 |
| -------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BilledCost                 | CostInBillingCurrency                                                                              | If ChargeType == "Usage" and PricingModel == "Reservation" or "SavingsPlan", then `0`; otherwise, use CostInBillingCurrency.                                                                                                                                                              |
| BillingAccountId           | Enterprise Agreement: BillingAccountId<br><br>Microsoft Customer Agreement: BillingProfileId       | None                                                                                                                                                                                                                                                                                      |
| BillingAccountName         | Enterprise Agreement: BillingAccountName<br><br>Microsoft Customer Agreement: BillingProfileName   | None                                                                                                                                                                                                                                                                                      |
| BillingAccountType         | Enterprise Agreement: `Billing Account`<br><br>Microsoft Customer Agreement: `Billing Profile`     | None                                                                                                                                                                                                                                                                                      |
| BillingCurrency            | Enterprise Agreement: BillingCurrencyCode<br><br>Microsoft Customer Agreement: BillingCurrency     | None                                                                                                                                                                                                                                                                                      |
| BillingPeriodEnd           | BillingPeriodEndDate                                                                               | Add one day for the exclusive end date.                                                                                                                                                                                                                                                   |
| BillingPeriodStart         | BillingPeriodStartDate                                                                             | None                                                                                                                                                                                                                                                                                      |
| CapacityReservationId      | AdditionalInfo.VMCapacityReservationId                                                             | None                                                                                                                                                                                                                                                                                      |
| CapacityReservationStatus  | AdditionalInfo.VMCapacityReservationId                                                             | If AdditionalInfo.VMCapacityReservationId is null or empty, null; if x_ResourceType == `microsoft.compute/capacityreservationgroups/capacityreservations`, `Unused`; otherwise, `Used`.                                                                                                   |
| ChargeCategory             | ChargeType                                                                                         | If `Usage`, `Purchase`, `Credit`, or `Tax`, same value; if `UnusedReservation` or `UnusedSavingsPlan`, then `Usage`; if `Refund`, `Purchase`; otherwise, `Adjustment`.                                                                                                                    |
| ChargeClass                | ChargeType                                                                                         | If `Refund`, then use `Correction`.                                                                                                                                                                                                                                                       |
| ChargeDescription          | ProductName                                                                                        | None                                                                                                                                                                                                                                                                                      |
| ChargeFrequency            | Frequency                                                                                          | If `OneTime`, `One-Time`; if `Recurring`, `Recurring`; if `UsageBased`, `Usage-Based`; otherwise, `Other`.                                                                                                                                                                                |
| ChargePeriodEnd            | Date                                                                                               | Add one day for the exclusive end date.                                                                                                                                                                                                                                                   |
| ChargePeriodStart          | Date                                                                                               | None                                                                                                                                                                                                                                                                                      |
| CommitmentDiscountCategory | BenefitId                                                                                          | If BenefitId contains `/microsoft.capacity/` (case-insensitive), `Usage`; if it contains `/microsoft.billingbenefits/`, use `Spend`; otherwise, null.                                                                                                                                     |
| CommitmentDiscountId       | BenefitId                                                                                          | None                                                                                                                                                                                                                                                                                      |
| CommitmentDiscountName     | BenefitName                                                                                        | None                                                                                                                                                                                                                                                                                      |
| CommitmentDiscountStatus   | ChargeType                                                                                         | If `UnusedReservation` or `UnusedSavingsPlan`, then `Unused`; else if PricingModel == `Reservation` or `SavingsPlan`, then `Used`; otherwise, null.                                                                                                                                       |
| CommitmentDiscountType     | BenefitId                                                                                          | If BenefitId contains `/microsoft.capacity/` (case-insensitive), `Reservation`; if it contains `/microsoft.billingbenefits/`, `Savings Plan`; otherwise, null.                                                                                                                            |
| CommitmentDiscountQuantity | Not available                                                                                      | If focus:CommitmentDiscountCategory == `Spend`, focus:EffectiveCost / focus:x_BillingExchangeRate; if focus:CommitmentDiscountCategory == `Usage`, (focus:PricingQuantity / focus:x_PricingBlockSize) * (normalized ratio); otherwise, null.                                              |
| CommitmentDiscountUnit     | Not available                                                                                      | If focus:CommitmentDiscountCategory == `Spend`, focus:PricingCurrency; if focus:CommitmentDiscountCategory == `Usage` and the SKU uses instance size flexibility, `Normalized {focus:ConsumedUnit}`; if focus:CommitmentDiscountCategory == `Usage`, focus:ConsumedUnit; otherwise, null. |
| ConsumedQuantity           | Quantity                                                                                           | If ChargeType == `Usage`, then Quantity; otherwise, null.                                                                                                                                                                                                                                 |
| ConsumedUnit               | UnitOfMeasure                                                                                      | If ChargeType == `Usage`, then map using  [Pricing units data file](../toolkit/open-data.md#pricing-units)  ; otherwise, null.                                                                                                                                                            |
| ContractedCost             | UnitPrice * Quantity / focus:x_PricingBlockSize                                                    | Note that x_PricingBlockSize requires a mapping. See column notes for details.                                                                                                                                                                                                            |
| ContractedUnitPrice        | UnitPrice                                                                                          | None                                                                                                                                                                                                                                                                                      |
| EffectiveCost              | CostInBillingCurrency                                                                              | If ChargeType == "Purchase" or "Refund" and PricingModel == "Reservation" or "SavingsPlan", then `0`; otherwise, use CostInBillingCurrency.                                                                                                                                               |
| InvoiceId                  | InvoiceId                                                                                          | None                                                                                                                                                                                                                                                                                      |
| InvoiceIssuerName          | PartnerName                                                                                        | If PartnerName is empty, use `Microsoft`                                                                                                                                                                                                                                                  |
| ListCost                   | Enterprise Agreement: Not available<br><br>Microsoft Customer Agreement: PaygCostInBillingCurrency | None                                                                                                                                                                                                                                                                                      |
| ListUnitPrice              | Enterprise Agreement: PayGPrice<br><br>Microsoft Customer Agreement: PayGPrice \* ExchangeRate     | None                                                                                                                                                                                                                                                                                      |
| PricingCategory            | PricingModel                                                                                       | If `OnDemand`, then `Standard`; if `Spot`, then `Dynamic`; if `Reservation` or `Savings Plan`, then `Committed`; otherwise, null.                                                                                                                                                         |
| PricingCurrency            | Enterprise Agreement: BillingCurrencyCode<br><br>Microsoft Customer Agreement: PricingCurrency     | None                                                                                                                                                                                                                                                                                      |
| PricingQuantity            | Quantity / focus:x_PricingBlockSize                                                                | Note that x_PricingBlockSize requires a mapping. See column notes for details.                                                                                                                                                                                                            |
| PricingUnit                | DistinctUnits (lookup)                                                                             | Map UnitOfMeasure to DistinctUnits using [Pricing units data file](../toolkit/open-data.md#pricing-units).                                                                                                                                                                                |
| ProviderName               | `Microsoft`                                                                                        | None                                                                                                                                                                                                                                                                                      |
| PublisherName              | PublisherName                                                                                      | None                                                                                                                                                                                                                                                                                      |
| RegionId                   | focus:RegionName                                                                                   | Lowercase and remove spaces.                                                                                                                                                                                                                                                              |
| RegionName                 | ResourceLocation                                                                                   | Map ResourceLocation (OriginalValue) to RegionName using [Regions data file](../toolkit/open-data.md#regions)<sup>2</sup>.                                                                                                                                                                |
| ResourceId                 | ResourceId                                                                                         | None                                                                                                                                                                                                                                                                                      |
| ResourceName               | EA: ResourceName<br>MCA: last(split(ResourceId, "/"))                                              | Azure resource names include multiple levels (for example, "SqlServerName/SqlDbName"), which requires more processing. This is a simplified approach to only use the last, most-specific segment.                                                                                         |
| ResourceType               | SingularDisplayName (lookup)                                                                       | Map ResourceType to SingularDisplayName using [Resource types data file](../toolkit/open-data.md#resource-types).                                                                                                                                                                         |
| ServiceCategory            | ServiceCategory (lookup)                                                                           | Map ConsumedService and ResourceType to ServiceCategory using [Services data file](../toolkit/open-data.md#services).                                                                                                                                                                     |
| ServiceName                | ServiceName (lookup)                                                                               | Map ConsumedService and ResourceType to ServiceName using [Services data file](../toolkit/open-data.md#services).                                                                                                                                                                         |
| ServiceSubcategory         | ServiceSubcategory (lookup)                                                                        | Map ConsumedService and ResourceType to ServiceSubcategory using [Services data file](../toolkit/open-data.md#services).                                                                                                                                                                  |
| SkuId                      | Enterprise Agreement: Not available<br><br>Microsoft Customer Agreement: ProductId                 | None                                                                                                                                                                                                                                                                                      |
| SkuMeter                   | MeterName                                                                                          | None                                                                                                                                                                                                                                                                                      |
| SkuPriceDetails            | AdditionalInfo                                                                                     | Prefix all property names with `x_`.                                                                                                                                                                                                                                                      |
| SkuPriceId                 | Not available                                                                                      | None                                                                                                                                                                                                                                                                                      |
| SubAccountId               | SubscriptionId                                                                                     | None                                                                                                                                                                                                                                                                                      |
| SubAccountName             | SubscriptionName                                                                                   | None                                                                                                                                                                                                                                                                                      |
| SubAccountType             | `Subscription`                                                                                     | None                                                                                                                                                                                                                                                                                      |
| Tags                       | Tags                                                                                               | Wrap in `{` and `}` if needed.                                                                                                                                                                                                                                                            |

_¹ Quantity in Cost Management is the consumed (usage) quantity._

_² While RegionName is a direct mapping of ResourceLocation, Cost Management and FinOps toolkit reports do additional data cleansing to ensure consistency in values based on the [Regions data file](../toolkit/open-data.md#regions)._

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK/bladeName/Guide.FOCUS/featureName/Convert)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [How to update existing reports to FOCUS](mapping.md)
- [How to compare FOCUS with actual/amortized cost](validate.md)
- [FinOps toolkit data dictionary](../toolkit/help/data-dictionary.md)
- [Generating a unique ID](../toolkit/help/data-dictionary.md#generating-a-unique-id)
- [FinOps toolkit common terms](../toolkit/help/terms.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../toolkit/powershell/powershell-commands.md)

<br>
