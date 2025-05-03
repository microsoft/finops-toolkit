---
title: Update reports to use FOCUS columns
description: Learn how to update existing reports from Cost Management actual or amortized datasets to use FOCUS columns.
author: flanakin
ms.author: micflan
ms.date: 04/02/2025
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-learning-resources
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to learn how to update existing reports to use the columns defined by the FinOps Open Cost and Usage Specification (FOCUS).
---

<!-- markdownlint-disable-next-line MD025 -->
# Update reports to use FOCUS columns

This document provides guidance for updating existing reports to use the columns defined by the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, refer to the [FOCUS overview](what-is-focus.md).

<br>

## Update existing reports to FOCUS

Use the following table to update existing automation and reporting solutions to use FOCUS.

| Column                       | Values                     | How to update                                                                                                                                                      |
| ---------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AccountName                  | (All)                      | Use **x_AccountName**                                                                                                                                              |
| AccountOwnerId               | (All)                      | Use **x_AccountOwnerId**                                                                                                                                           |
| AdditionalInfo               | (All)                      | Use **x_SkuDetails**                                                                                                                                               |
| CostInBillingCurrency        | (All)                      | For actual cost, use **BilledCost**; otherwise, use **EffectiveCost**                                                                                              |
| BenefitId                    | (All)                      | Use **CommitmentDiscountId**                                                                                                                                       |
| BenefitName                  | (All)                      | Use **CommitmentDiscountName**                                                                                                                                     |
| BillingAccountId             | (All)                      | • Enterprise Agreement: Use **BillingAccountId**<br><br>• Microsoft Customer Agreement: Use **x_BillingAccountId**                                                 |
| BillingAccountName           | (All)                      | • Enterprise Agreement: Use **BillingAccountName**<br>• Microsoft Customer Agreement: Use **x_BillingAccountName**                                                 |
| BillingCurrencyCode          | (All)                      | Use **BillingCurrency**                                                                                                                                            |
| BillingProfileId             | (All)                      | • Enterprise Agreement: Use **x_BillingProfileId**<br><br>• Microsoft Customer Agreement: Use **BillingAccountId**                                                 |
| BillingProfileName           | (All)                      | • Enterprise Agreement: Use **x_BillingProfileName**<br><br>• Microsoft Customer Agreement: Use **BillingAccountName**                                             |
| BillingPeriodEndDate         | (All)                      | Use **BillingPeriodEnd** and change comparisons to use less than (`<`) rather than less than or equal to (`<=`)                                                    |
| BillingPeriodStartDate       | (All)                      | Use **BillingPeriodStart**                                                                                                                                         |
| ChargeType                   | `Usage`, `Purchase`, `Tax` | Use **ChargeCategory**                                                                                                                                             |
| ChargeType                   | `UnusedReservation`        | Use **CommitmentDiscountStatus** = `Unused` and **CommitmentDiscountType** = `Reservation`                                                                         |
| ChargeType                   | `UnusedSavingsPlan`        | Use **CommitmentDiscountStatus** = `Unused` and **CommitmentDiscountType** = `Savings Plan`                                                                        |
| ChargeType                   | `Refund`                   | Use **ChargeClass** = `Correction`                                                                                                                                 |
| ChargeType                   | `RoundingAdjustment`       | Use **ChargeCategory** = `Adjustment` (might include other charges)                                                                                                |
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
| Frequency                    | `OneTime`                  | Use **ChargeFrequency** = `One-Time`                                                                                                                               |
| Frequency                    | `Recurring`                | Use **ChargeFrequency** = `Recurring`                                                                                                                              |
| Frequency                    | `UsageBased`               | Use **ChargeFrequency** = `Usage-Based`                                                                                                                            |
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
| PricingModel                 | `OnDemand`                 | Use **PricingCategory** = `Standard`                                                                                                                               |
| PricingModel                 | `Reservation`              | For all commitments, use **PricingCategory** = `Committed`; for reservations only, use **CommitmentDiscountCategory** = `Usage`                                    |
| PricingModel                 | `SavingsPlan`              | For all commitments, use **PricingCategory** = `Committed`; for savings plans only, use **CommitmentDiscountCategory** = `Spend`                                   |
| PricingModel                 | `Spot`                     | Use **PricingCategory** = `Dynamic` or **x_PricingSubcategory** = `Spot`                                                                                           |
| ProductId                    | (All)                      | Use **SkuId**                                                                                                                                                      |
| Quantity                     | (All)                      | For the usage amount, use **ConsumedQuantity**; for the amount you were charged for after accounting for pricing block size, use **PricingQuantity**               |
| ResellerMpnId                | (All)                      | Use **x_ResellerId**                                                                                                                                               |
| ResellerName                 | (All)                      | Use **x_ResellerName**                                                                                                                                             |
| ReservationId                | (All)                      | Use **CommitmentDiscountId**; split by `/` and use last segment for the reservation GUID                                                                           |
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

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20toolkit%20tools%20and%20resources%3F/cvaQuestion/How%20valuable%20is%20the%20FinOps%20toolkit%3F/surveyId/FTK0.10/bladeName/Guide.FOCUS/featureName/Mapping)

If you're looking for something specific, vote for an existing or create a new idea. Share ideas with others to get more votes. We focus on ideas with the most votes.

> [!div class="nextstepaction"]
> [Vote on or suggest ideas](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%252B1-desc)

<br>

## Related content

Related resources:

- [How to convert Cost Management data to FOCUS](convert.md)
- [How to compare FOCUS with actual/amortized cost](validate.md)
- [Microsoft Cost Management FOCUS dataset](/azure/cost-management-billing/dataset-schema/cost-usage-details-focus)
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
