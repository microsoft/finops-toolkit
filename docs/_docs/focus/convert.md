---
layout: default
parent: FOCUS
title: Convert to FOCUS
nav_order: 2
description: 'Convert existing Cost Management datasets to FOCUS.'
permalink: /focus/convert
---

<span class="fs-9 d-block mb-4">Convert Cost Management data to FOCUS</span>
Convert existing Cost Management actual and amortized datasets to FOCUS.
{: .fs-6 .fw-300 }

<!--
[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#-v01){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [➡️ How to convert Cost Management data to FOCUS](#️-how-to-convert-cost-management-data-to-focus)
- [🙋‍♀️ Feedback about FOCUS columns](#️-feedback-about-focus-columns)
- [🧐 See also](#-see-also)
- [🧰 Related tools](#-related-tools)

</details>

---

This document provides guidance for converting Cost Management actual and amortized datasets to the FinOps Open Cost and Usage Specification (FOCUS). To learn more about FOCUS, refer to the [FOCUS overview](./README.md).

<br>

## ➡️ How to convert Cost Management data to FOCUS

In order to convert cost and usage data to FOCUS, you will need both the actual and amortized cost datasets:

1. Keep all rows from the amortized cost data.
2. Filter the actual cost data to only include rows where ChargeType == "Purchase" or "Refund" and PricingModel == "Reservation" or "SavingsPlan".

Apply the following logic to all of the rows:

| FOCUS column               | Cost Management column                              | Transform                                                                                                                                                             |
| -------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BilledCost                 | CostInBillingCurrency                               | If ChargeType == "Usage" and PricingModel == "Reservation" or "SavingsPlan", then `0`; otherwise, use CostInBillingCurrency                                           |
| BillingAccountId           | EA: BillingAccountId<br>MCA: BillingProfileId       | None                                                                                                                                                                  |
| BillingAccountName         | EA: BillingAccountName<br>MCA: BillingProfileName   | None                                                                                                                                                                  |
| BillingCurrency            | EA: BillingCurrencyCode<br>MCA: BillingCurrency     | None                                                                                                                                                                  |
| BillingPeriodEnd           | BillingPeriodEndDate                                | Add 1 day for the exclusive end date                                                                                                                                  |
| BillingPeriodStart         | BillingPeriodStartDate                              | None                                                                                                                                                                  |
| ChargeCategory             | ChargeType                                          | If "Usage", "Purchase", "Credit", or "Tax", same value; if "UnusedReservation" or "UnusedSavingsPlan", then `Usage`; if "Refund", "Purchase"; otherwise, `Adjustment` |
| ChargeClass                | ChargeType                                          | If "Refund", then use `Correction`                                                                                                                                    |
| ChargeDescription          | ProductName                                         | None                                                                                                                                                                  |
| ChargeFrequency            | Frequency                                           | If "OneTime", `One-Time`; if "Recurring", `Recurring`; if "UsageBased", `Usage-Based`; otherwise, `Other`                                                             |
| ChargePeriodEnd            | Date                                                | Add 1 day for the exclusive end date                                                                                                                                  |
| ChargePeriodStart          | Date                                                | None                                                                                                                                                                  |
| CommitmentDiscountCategory | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Usage`; if contains "/microsoft.billingbenefits/", use `Spend`; otherwise, null                     |
| CommitmentDiscountId       | BenefitId                                           | None                                                                                                                                                                  |
| CommitmentDiscountName     | BenefitName                                         | None                                                                                                                                                                  |
| CommitmentDiscountStatus   | ChargeType                                          | If "UnusedReservation" or "UnusedSavingsPlan", then `Unused`; else if PricingModel == "Reservation" or "SavingsPlan", then `Used`; otherwise, null                    |
| CommitmentDiscountType     | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Reservation`; if contains "/microsoft.billingbenefits/", `Savings Plan`; otherwise, null            |
| ConsumedQuantity           | Quantity                                            | If ChargeType == "Usage", then Quantity; otherwise, null                                                                                                              |
| ConsumedUnit               | UnitOfMeasure                                       | If ChargeType == "Usage", then map using [Pricing units data file](../../_reporting/data/README.md#-pricing-units); otherwise, null                                   |
| ContractedCost             | UnitPrice * Quantity / focus:x_PricingBlockSize | Note that x_PricingBlockSize requires a mapping. See column notes for details. |
| ContractedUnitPrice        | UnitPrice                                           | None                                                                                                                                                                  |
| EffectiveCost              | CostInBillingCurrency                               | If ChargeType == "Purchase" or "Refund" and PricingModel == "Reservation" or "SavingsPlan", then `0`; otherwise, use CostInBillingCurrency                            |
| InvoiceIssuerName          | PartnerName                                         | If PartnerName is empty, use `Microsoft`                                                                                                                              |
| ListCost                   | EA: Not available<br>MCA: PaygCostInBillingCurrency | None                                                                                                                                                                  |
| ListUnitPrice              | EA: PayGPrice<br>MCA: PayGPrice \* ExchangeRate     | None                                                                                                                                                                  |
| PricingCategory            | PricingModel                                        | If "OnDemand", then `Standard`; if "Spot", then `Dynamic`; if "Reservation" or "Savings Plan", then `Committed`; otherwise, null                                      |
| PricingQuantity            | Quantity / focus:x_PricingBlockSize | Note that x_PricingBlockSize requires a mapping. See column notes for details. |
| PricingUnit                | DistinctUnits (lookup)                              | Map UnitOfMeasure to DistinctUnits using [Pricing units data file](../../_reporting/data/README.md#-pricing-units)                                                    |
| ProviderName               | `Microsoft`                                         | None                                                                                                                                                                  |
| PublisherName              | PublisherName                                       | None                                                                                                                                                                  |
| RegionId                   | focus:RegionName                                    | Lowercase and remove spaces                                                                                                                                           |
| RegionName                 | ResourceLocation                                    | Map ResourceLocation (OriginalValue) to RegionName using [Regions data file](../../_reporting/data/README.md#-regions)<sup>2</sup> |
| ResourceId                 | ResourceId                                          | None                                                                                                                                                                  |
| ResourceName               | EA: ResourceName<br>MCA: last(split(ResourceId, "/")) | Azure resource names include multiple levels (e.g., "SqlServerName/SqlDbName"), which requires more processing. This is a simplified approach to only use the last, most-specific segment. |
| ResourceType               | SingularDisplayName (lookup)                        | Map ResourceType to SingularDisplayName using [Resource types data file](../../_reporting/data/README.md#-resource-types)                                             |
| ServiceCategory            | ServiceCategory (lookup)                            | Map ConsumedService and ResourceType to SerivceCategory using [Services data file](../../_reporting/data/README.md#-services)                                         |
| ServiceName                | ServiceName (lookup)                                | Map ConsumedService and ResourceType to SerivceName using [Services data file](../../_reporting/data/README.md#-services)                                             |
| SkuId                      | EA: Not available<br>MCA: ProductId                 | None                                                                                                                                                                  |
| SkuPriceId                 | Not available                                       | None                                                                                                                                                                  |
| SubAccountId               | SubscriptionId                                      | None                                                                                                                                                                  |
| SubAccountName             | SubscriptionName                                    | None                                                                                                                                                                  |
| Tags                       | Tags                                                | Wrap in `{` and `}` if needed                                                                                                                                         |

_<sup>1. Quantity in Cost Management is the consumed (usage) quantity.</sup>_

_<sup>2. While RegionName is a direct mapping of ResourceLocation, Cost Management and FinOps toolkit reports do additional data cleansing to ensure consistency in values based on the [Regions data file](../../_reporting/data/README.md#-regions).</sup>_

<br>

## 🙋‍♀️ Feedback about FOCUS columns

<!-- markdownlint-disable-line --> {% include focus_feedback.md %}

<br>

## 🧐 See also

- [How to update existing reports to FOCUS](./mapping.md)
- [How to compare FOCUS with actual/amortized cost](./validate.md)
- [Data dictionary](../../_resources/data-dictionary.md)
- [Generating a unique ID](../../_resources/data-dictionary.md#-generating-a-unique-id)
- [Known issues](../../_resources/data-dictionary.md#-known-issues)
- [Common terms](../../_resources/terms.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
