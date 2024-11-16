---
title: Convert to FOCUS
description: This document provides guidance for converting existing Cost Management datasets to the FinOps Open Cost and Usage Specification (FOCUS).
author: bandersmsft
ms.author: banders
ms.date: 10/29/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how to convert existing Cost Management datasets to the FinOps Open Cost and Usage Specification (FOCUS).
---

<!-- markdownlint-disable-next-line MD025 -->
# Convert Cost Management data to FOCUS

This document provides guidance for converting Cost Management actual and amortized datasets to the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, refer to the [FOCUS overview](what-is-focus.md).

<br>

## How to convert Cost Management data to FOCUS

The following mapping is assuming you have all amortized cost rows and only commitment purchases and refunds from the actual cost dataset.

| FOCUS column               | Cost Management column                                                                                  | Transform                                                                                                                                                             |
| -------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BilledCost                 | CostInBillingCurrency                                                                                   | Use `0` for amortized commitment usage¹                                                                                                                               |
| BillingAccountId           | • Enterprise Agreement: BillingAccountId<br><br>• Microsoft Customer Agreement: BillingProfileId        | None                                                                                                                                                                  |
| BillingAccountName         | • Enterprise Agreement: BillingAccountName<br><br>• Microsoft Customer Agreement: BillingProfileName    | None                                                                                                                                                                  |
| BillingCurrency            | • Enterprise Agreement: BillingCurrencyCode<br><br>• Microsoft Customer Agreement: BillingCurrency      | None                                                                                                                                                                  |
| BillingPeriodEnd           | BillingPeriodEndDate                                                                                    | Add one day for the exclusive end date                                                                                                                                |
| BillingPeriodStart         | BillingPeriodStartDate                                                                                  | None                                                                                                                                                                  |
| ChargeCategory             | ChargeType                                                                                              | If `Usage`, `Purchase`, `Credit`, or `Tax`, same value; if `UnusedReservation` or `UnusedSavingsPlan`, then `Usage`; if `Refund`, `Purchase`; otherwise, `Adjustment` |
| ChargeClass                | ChargeType                                                                                              | If `Refund`, then use `Correction`                                                                                                                                    |
| ChargeDescription          | ProductName                                                                                             | None                                                                                                                                                                  |
| ChargeFrequency            | Frequency                                                                                               | If `OneTime`, `One-Time`; if `Recurring`, `Recurring`; if `UsageBased`, `Usage-Based`; otherwise, `Other`                                                             |
| ChargePeriodEnd            | Date                                                                                                    | Add one day for the exclusive end date                                                                                                                                |
| ChargePeriodStart          | Date                                                                                                    | None                                                                                                                                                                  |
| CommitmentDiscountCategory | BenefitId                                                                                               | If BenefitId contains `/microsoft.capacity/` (case-insensitive), `Usage`; if it contains `/microsoft.billingbenefits/`, use `Spend`; otherwise, null                  |
| CommitmentDiscountId       | BenefitId                                                                                               | None                                                                                                                                                                  |
| CommitmentDiscountName     | BenefitName                                                                                             | None                                                                                                                                                                  |
| CommitmentDiscountStatus   | ChargeType                                                                                              | If `UnusedReservation` or `UnusedSavingsPlan`, then `Unused`; else if PricingModel == `Reservation` or `SavingsPlan`, then `Used`; otherwise, null                    |
| CommitmentDiscountType     | BenefitId                                                                                               | If BenefitId contains `/microsoft.capacity/` (case-insensitive), `Reservation`; if it contains `/microsoft.billingbenefits/`, `Savings Plan`; otherwise, null         |
| ConsumedQuantity           | Quantity                                                                                                | If ChargeType == `Usage`, then Quantity; otherwise, null                                                                                                              |
| ConsumedUnit               | UnitOfMeasure                                                                                           | If ChargeType == `Usage`, then map using  [Pricing units data file](../toolkit/open-data.md#pricing-units)  ; otherwise, null                                         |
| ContractedCost             | UnitPrice * Quantity                                                                                    | Map UnitOfMeasure using [Pricing units data file]( ../toolkit/open-data.md#pricing-units) and divide Quantity by the PricingBlockSize                                 |
| ContractedUnitPrice        | UnitPrice                                                                                               | None                                                                                                                                                                  |
| EffectiveCost              | CostInBillingCurrency                                                                                   | Use `0` for commitment purchases and refunds¹.                                                                                                                        |
| InvoiceIssuerName          | PartnerName                                                                                             | If PartnerName is empty, use `Microsoft`.                                                                                                                             |
| ListCost                   | • Enterprise Agreement: Not available<br><br> • Microsoft Customer Agreement: PaygCostInBillingCurrency | None                                                                                                                                                                  |
| ListUnitPrice              | • Enterprise Agreement: PayGPrice<br><br> • Microsoft Customer Agreement: PayGPrice \* ExchangeRate     | None                                                                                                                                                                  |
| PricingCategory            | PricingModel                                                                                            | If `OnDemand`, then `Standard`; if `Spot`, then `Dynamic`; if `Reservation` or `Savings Plan`, then `Committed`; otherwise, null                                      |
| PricingQuantity            | Quantity                                                                                                | Map UnitOfMeasure using [Pricing units data file](../toolkit/open-data.md#pricing-units) and divide Quantity by the PricingBlockSize²                                 |
| PricingUnit                | UnitOfMeasure                                                                                           | Map using [Pricing units data file](../toolkit/open-data.md#pricing-units)                                                                                            |
| ProviderName               | `Microsoft`                                                                                             | None                                                                                                                                                                  |
| PublisherName              | PublisherName                                                                                           | None                                                                                                                                                                  |
| RegionId                   | focus:RegionName                                                                                        | Lowercase and remove spaces                                                                                                                                           |
| RegionName                 | ResourceLocation                                                                                        | Map using [Regions data file](../toolkit/open-data.md#regions)³                                                                                                       |
| ResourceId                 | ResourceId                                                                                              | None                                                                                                                                                                  |
| ResourceName               | ResourceName                                                                                            | None                                                                                                                                                                  |
| ResourceType               | ResourceType                                                                                            | Map using [Resource types data file](../toolkit/open-data.md#resource-types)                                                                                          |
| ServiceCategory            | ResourceType                                                                                            | Map using [Services data file](../toolkit/open-data.md#services)                                                                                                      |
| ServiceName                | ResourceType                                                                                            | Map using [Services data file](../toolkit/open-data.md#services)                                                                                                      |
| SkuId                      | • Enterprise Agreement: Not available<br><br>• Microsoft Customer Agreement: ProductId                  | None                                                                                                                                                                  |
| SkuPriceId                 | Not available                                                                                           | None                                                                                                                                                                  |
| SubAccountId               | SubscriptionId                                                                                          | None                                                                                                                                                                  |
| SubAccountName             | SubscriptionName                                                                                        | None                                                                                                                                                                  |
| Tags                       | Tags                                                                                                    | Wrap in `{` and `}` if needed                                                                                                                                         |

_¹ BilledCost should copy cost from all rows **except** commitment usage that has a PricingModel of `Reservation` or `SavingsPlan` which should be `0`. EffectiveCost should copy cost from all amortized dataset rows; commitment purchases and refunds from the actual cost dataset should be `0`._

_² Quantity in Cost Management is the consumed (usage) quantity._

_³ While RegionName is a direct mapping of ResourceLocation, Cost Management and FinOps toolkit reports do more data cleansing to ensure consistency in values based on the [Regions data file](../toolkit/open-data.md#regions)._

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Related content

Related resources:

- [How to update existing reports to FOCUS](mapping.md)
- [How to compare FOCUS with actual/amortized cost](validate.md)

<!--
TODO: Add these after we bring in the rest of the toolkit content
- [Data dictionary](../../_resources/data-dictionary.md)
- [Generating a unique ID](../../_resources/data-dictionary.md#-generating-a-unique-id)
- [Known issues](../../_resources/data-dictionary.md#-known-issues)
- [Common terms](../../_resources/terms.md)
-->

Related products:

- [Cost Management](/azure/cost-management-billing/costs)

Related solutions:

- [FinOps toolkit Power BI reports](../toolkit/power-bi/reports.md)
- [FinOps hubs](../toolkit/hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../toolkit/powershell/powershell-commands.md)

<br>
