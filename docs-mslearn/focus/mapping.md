---
title: Updating reports
description: 'Update existing reports from Cost Management actual or amortized datasets to use FOCUS columns.'
author: bandersmsft
ms.author: banders
ms.date: 07/15/2024
ms.topic: how-to
ms.service: finops
ms.reviewer: micflan
---

<!-- markdownlint-disable-next-line MD025 -->
# Updating reports to use FOCUS columns

This document provides guidance for updating existing reports to use the columns defined by the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, refer to the [FOCUS overview](./what-is-focus.md).

<br>

## How to update existing reports to FOCUS

Use the following table to update existing automation and reporting solutions to use FOCUS.

| Column                       | Value(s)                   | How to update                                                                                                                                                      |
| ---------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AccountName                  | (All)                      | Use **x_AccountName**                                                                                                                                              |
| AccountOwnerId               | (All)                      | Use **x_AccountOwnerId**                                                                                                                                           |
| AdditionalInfo               | (All)                      | Use **x_SkuDetails**                                                                                                                                               |
| CostInBillingCurrency        | (All)                      | For actual cost, use **BilledCost**; otherwise, use **EffectiveCost**                                                                                              |
| BenefitId                    | (All)                      | Use **CommitmentDiscountId**                                                                                                                                       |
| BenefitName                  | (All)                      | Use **CommitmentDiscountName**                                                                                                                                     |
| BillingAccountId             | (All)                      | EA: Use **BillingAccountId**<br>MCA: Use **x_BillingAccountId**                                                                                                    |
| BillingAccountName           | (All)                      | EA: Use **BillingAccountName**<br>MCA: Use **x_BillingAccountName**                                                                                                |
| BillingCurrencyCode          | (All)                      | Use **BillingCurrency**                                                                                                                                            |
| BillingProfileId             | (All)                      | EA: Use **x_BillingProfileId**<br>MCA: Use **BillingAccountId**                                                                                                    |
| BillingProfileName           | (All)                      | EA: Use **x_BillingProfileName**<br>MCA: Use **BillingAccountName**                                                                                                |
| BillingPeriodEndDate         | (All)                      | Use **BillingPeriodEnd** and change comparisons to use less than (`<`) rather than less than or equal to (`<=`)                                                    |
| BillingPeriodStartDate       | (All)                      | Use **BillingPeriodStart**                                                                                                                                         |
| ChargeType                   | "Usage", "Purchase", "Tax" | Use **ChargeCategory**                                                                                                                                             |
| ChargeType                   | "UnusedReservation"        | Use **CommitmentDiscountStatus** = "Unused" and **CommitmentDiscountType** = "Reservation"                                                                         |
| ChargeType                   | "UnusedSavingsPlan"        | Use **CommitmentDiscountStatus** = "Unused" and **CommitmentDiscountType** = "Savings Plan"                                                                        |
| ChargeType                   | "Refund"                   | Use **ChargeClass** = "Correction"                                                                                                                                 |
| ChargeType                   | "RoundingAdjustment"       | Use **ChargeCategory** = "Adjustment" (may include other charges)                                                                                                  |
| CostAllocationRuleName       | (All)                      | Use **x_CostAllocationRuleName**                                                                                                                                   |
| CostCenter                   | (All)                      | Use **x_CostCenter**                                                                                                                                               |
| CostInUsd                    | (All)                      | For actual cost, use **x_BilledCostInUsd**; otherwise, use **x_EffectiveCostInUsd**                                                                                |
| CustomerName                 | (All)                      | Use **x_CustomerName**                                                                                                                                             |
| CustomerTenantId             | (All)                      | Use **x_CustomerId**                                                                                                                                               |
| Date                         | (All)                      | Use **ChargePeriodStart**                                                                                                                                          |
| DepartmentName               | (All)                      | Use **x_InvoiceSectionName**                                                                                                                                       |
| EffectivePrice               | (All)                      | Use **x_EffectiveUnitPrice**                                                                                                                                       |
| ExchangeRatePricingToBilling | (All)                      | Use **x_BillingExchangeRate**                                                                                                                                      |
| ExchangeRateDate             | (All)                      | Use **x_BillingExchangeRateDate**                                                                                                                                  |
| Frequency                    | "OneTime"                  | Use **ChargeFrequency** = "One-Time"                                                                                                                               |
| Frequency                    | "Recurring"                | Use **ChargeFrequency** = "Recurring"                                                                                                                              |
| Frequency                    | "UsageBased"               | Use **ChargeFrequency** = "Usage-Based"                                                                                                                            |
| InvoiceId                    | (All)                      | Use **x_InvoiceId**                                                                                                                                                |
| InvoiceSectionId             | (All)                      | Use **x_InvoiceSectionId**                                                                                                                                         |
| InvoiceSectionName           | (All)                      | Use **x_InvoiceSectionName**                                                                                                                                       |
| IsAzureCreditEligible        | (All)                      | Use **x_SkuIsCreditEligible**                                                                                                                                      |
| Location                     | (All)                      | Use **RegionName** or **RegionId**                                                                                                                                 |
| MeterCategory                | (All)                      | To group resources, use **ServiceName**; to group meters, use **x_SkuMeterCategory**                                                                               |
| MeterId                      | (All)                      | Use **x_SkuMeterId**                                                                                                                                               |
| MeterName                    | (All)                      | Use **x_SkuMeterName**                                                                                                                                             |
| MeterRegion                  | (All)                      | Use **x_SkuRegion**                                                                                                                                                |
| MeterSubcategory             | (All)                      | Use **x_SkuMeterSubcategory**                                                                                                                                      |
| OfferId                      | (All)                      | Use **x_SkuOfferId**                                                                                                                                               |
| PartnerEarnedCreditApplied   | (All)                      | Use **x_PartnerCreditApplied**                                                                                                                                     |
| PartnerEarnedCreditRate      | (All)                      | Use **x_PartnerCreditRate**                                                                                                                                        |
| PartnerName                  | (All)                      | Use **InvoiceIssuerName** or **x_PartnerName**                                                                                                                     |
| PartnerTenantId              | (All)                      | Use **x_InvoiceIssuerId**                                                                                                                                          |
| PartNumber                   | (All)                      | Use **x_SkuPartNumber**                                                                                                                                            |
| ProductName                  | (All)                      | Use **ChargeDescription**                                                                                                                                          |
| ProductOrderId               | (All)                      | Use **x_SkuOrderId**                                                                                                                                               |
| ProductOrderName             | (All)                      | Use **x_SkuOrderName**                                                                                                                                             |
| PaygCostInBillingCurrency    | (All)                      | Use **ListCost**                                                                                                                                                   |
| PayGPrice                    | (All)                      | Use **ListUnitPrice** / **x_BillingExchangeRate**                                                                                                                  |
| PricingCurrency              | (All)                      | Use **x_PricingCurrency**                                                                                                                                          |
| PricingModel                 | "OnDemand"                 | Use **PricingCategory** = "Standard"                                                                                                                               |
| PricingModel                 | "Reservation"              | For all commitments, use **PricingCategory** = "Committed"; for reservations only, use **CommitmentDiscountCategory** = "Usage"                                    |
| PricingModel                 | "SavingsPlan"              | For all commitments, use **PricingCategory** = "Committed"; for savings plans only, use **CommitmentDiscountCategory** = "Spend"                                   |
| PricingModel                 | "Spot"                     | Use **PricingCategory** = "Dynamic" or **x_PricingSubcategory** = "Spot"                                                                                           |
| ProductId                    | (All)                      | Use **SkuId**                                                                                                                                                      |
| Quantity                     | (All)                      | For the usage amount, use **ConsumedQuantity**; for the amount you were charged for after accounting for pricing block size, use **PricingQuantity**               |
| ResellerMpnId                | (All)                      | Use **x_ResellerId**                                                                                                                                               |
| ResellerName                 | (All)                      | Use **x_ResellerName**                                                                                                                                             |
| ReservationId                | (All)                      | Use **CommitmentDiscountId**; split by "/" and use last segment for the reservation GUID                                                                           |
| ReservationName              | (All)                      | Use **CommitmentDiscountName**                                                                                                                                     |
| ResourceGroupName            | (All)                      | Use **x_ResourceGroupName**                                                                                                                                        |
| ResourceLocationNormalized   | (All)                      | Use **RegionName** or **RegionId**                                                                                                                                 |
| ResourceType                 | (All)                      | For friendly names, use **ResourceType**; otherwise, use **x_ResourceType**                                                                                        |
| ServiceFamily                | (All)                      | To group resources, use **ServiceCategory**; to group meters, use **x_SkuServiceFamily**                                                                           |
| ServicePeriodEnd             | (All)                      | Use **x_ServicePeriodEnd**                                                                                                                                         |
| ServicePeriodStart           | (All)                      | Use **x_ServicePeriodStart**                                                                                                                                       |
| SubscriptionId               | (All)                      | For a unique value, use **SubAccountId**; for the subscription GUID, use **x_SubscriptionId**                                                                      |
| SubscriptionName             | (All)                      | Use **SubAccountName** or **x_SubscriptionName**                                                                                                                   |
| Tags                         | (All)                      | Use **Tags** but don't wrap in curly braces (`{}`)                                                                                                                 |
| Term                         | (All)                      | Use **x_SkuTerm**                                                                                                                                                  |
| UnitOfMeasure                | (All)                      | For the exact value, use **x_PricingUnitDescription**; for distinct units, use **PricingUnit** or **ConsumedUnit**; for the block size, use **x_PricingBlockSize** |
| UnitPrice                    | (All)                      | Use **ContractedUnitPrice** or **ContractedCost**                                                                                                                  |

<br>

## Feedback about FOCUS columns

[!INCLUDE _focus_feedback.md]

<br>

## Related content

Related resources:

- [How to convert Cost Management data to FOCUS](./convert.md)
- [How to compare FOCUS with actual/amortized cost](./validate.md)

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

- [FinOps toolkit Power BI reports](https://aka.ms/ftk/pbi)
- [FinOps hubs](https://aka.ms/finops/hubs)
- [FinOps toolkit PowerShell module](https://aka.ms/ftk/ps)

<br>
