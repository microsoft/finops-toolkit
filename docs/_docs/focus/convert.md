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

The following mapping is assuming you have all amortized cost rows and only commitment purchases and refunds from the actual cost dataset.

| FOCUS column               | Cost Management column                              | Transform                                                                                                                                                                                                                                                            |
| -------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BilledCost                 | CostInBillingCurrency                               | Use `0` for amortized commitment usage<sup>1</sup>                                                                                                                                                                                                                   |
| BillingAccountId           | EA: BillingAccountId<br>MCA: BillingProfileId       | None                                                                                                                                                                                                                                                                 |
| BillingAccountName         | EA: BillingAccountName<br>MCA: BillingProfileName   | None                                                                                                                                                                                                                                                                 |
| BillingCurrency            | EA: BillingCurrencyCode<br>MCA: BillingCurrency     | None                                                                                                                                                                                                                                                                 |
| BillingPeriodEnd           | BillingPeriodEndDate                                | Add 1 day for the exclusive end date                                                                                                                                                                                                                                 |
| BillingPeriodStart         | BillingPeriodStartDate                              | None                                                                                                                                                                                                                                                                 |
| ChargeCategory             | ChargeType                                          | If "Usage", "Purchase", or "Tax", same value; if "UnusedReservation" or "UnusedSavingsPlan", `Usage`; otherwise, `Adjustment`                                                                                                                                        |
| ChargeDescription          | ProductName                                         | None                                                                                                                                                                                                                                                                 |
| ChargeFrequency            | Frequency                                           | If "OneTime", `One-Time`; if "Recurring", `Recurring`; if "UsageBased", `Usage-Based`; otherwise, `Other`                                                                                                                                                            |
| ChargePeriodEnd            | Date                                                | Add 1 day for the exclusive end date                                                                                                                                                                                                                                 |
| ChargePeriodStart          | Date                                                | None                                                                                                                                                                                                                                                                 |
| ChargeSubcategory          | ChargeType                                          | If "Usage" and PricingModel is "Reservation" or "SavingsPlan", `Used Commitment`; if "UnusedReservation" or "UnusedSavingsPlan", `Unused Commitment`; if "Usage", `On-Demand`; if "Refund", `Refund`; if "RoundingAdjustment", `Rounding Error`; otherwise, `Other`. |
| CommitmentDiscountCategory | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Usage`; if contains "/microsoft.billingbenefits/", use `Spend`; otherwise, null                                                                                                                    |
| CommitmentDiscountId       | BenefitId                                           | None                                                                                                                                                                                                                                                                 |
| CommitmentDiscountName     | BenefitName                                         | None                                                                                                                                                                                                                                                                 |
| CommitmentDiscountType     | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Reservation`; if contains "/microsoft.billingbenefits/", `Savings Plan`; otherwise, null                                                                                                           |
| EffectiveCost              | CostInBillingCurrency                               | Use `0` for commitment purchases and refunds<sup>1</sup>.                                                                                                                                                                                                            |
| InvoiceIssuerName          | PartnerName                                         | If PartnerName is empty, use `Microsoft`.                                                                                                                                                                                                                            |
| ListCost                   | EA: Not available<br>MCA: PaygCostInBillingCurrency | None                                                                                                                                                                                                                                                                 |
| ListUnitPrice              | EA: PayGPrice<br>MCA: PayGPrice \* ExchangeRate     | None                                                                                                                                                                                                                                                                 |
| PricingCategory            | PricingModel                                        | If "OnDemand", `On-Demand`; if "Spot", `Dynamic`; if "Reservation" or "Savings Plan", `Commitment Discount`; otherwise, `Other`                                                                                                                                      |
| PricingQuantity            | Quantity                                            | Map UnitOfMeasure using [Pricing units data file](../../_reporting/data/README.md#-pricing-units) and divide Quantity by the PricingBlockSize                                                                                                                        |
| PricingUnit                | UnitOfMeasure                                       | Map using [Pricing units data file](../../_reporting/data/README.md#-pricing-units)                                                                                                                                                                                  |
| ProviderName               | `Microsoft`                                         | None                                                                                                                                                                                                                                                                 |
| PublisherName              | PublisherName                                       | None                                                                                                                                                                                                                                                                 |
| Region                     | ResourceLocation                                    | Map using [Regions data file](../../_reporting/data/README.md#-regions)<sup>3</sup>                                                                                                                                                                                  |
| ResourceId                 | ResourceId                                          | None                                                                                                                                                                                                                                                                 |
| ResourceName               | ResourceName                                        | None                                                                                                                                                                                                                                                                 |
| ResourceType               | ResourceType                                        | Map using [Resource types data file](../../_reporting/data/README.md#-resource-types)                                                                                                                                                                                |
| ServiceCategory            | ResourceType                                        | Map using [Services data file](../../_reporting/data/README.md#-services)                                                                                                                                                                                            |
| ServiceName                | ResourceType                                        | Map using [Services data file](../../_reporting/data/README.md#-services)                                                                                                                                                                                            |
| SkuId                      | EA: Not available<br>MCA: ProductId                 | None                                                                                                                                                                                                                                                                 |
| SkuPriceId                 | Not available                                       | None                                                                                                                                                                                                                                                                 |
| SubAccountId               | SubscriptionId                                      | None                                                                                                                                                                                                                                                                 |
| SubAccountName             | SubscriptionName                                    | None                                                                                                                                                                                                                                                                 |
| Tags                       | Tags                                                | Wrap in `{` and `}` if needed                                                                                                                                                                                                                                        |
| UsageQuantity              | Quantity                                            | None                                                                                                                                                                                                                                                                 |
| UsageUnit                  | UnitOfMeasure                                       | Map using [Pricing units data file](../../_reporting/data/README.md#-pricing-units)                                                                                                                                                                                  |

_<sup>1. BilledCost should copy cost from all rows **except** commitment usage that has a PricingModel of "Reservation" or "SavingsPlan" which should be `0`. EffectiveCost should copy cost from all amortized dataset rows; commitment purchases and refunds from the actual cost dataset should be `0`.</sup>_

_<sup>2. Quantity in Cost Management is the usage quantity.</sup>_

_<sup>3. While Region is a direct mapping of ResourceLocation, Cost Management and FinOps toolkit reports do additional data cleansing to ensure consistency in values based on the [Regions data file](../../_reporting/data/README.md#-regions).</sup>_

<br>

## 🙋‍♀️ Feedback about FOCUS columns

<!-- markdownlint-disable-line --> {% include_relative _feedback.md %}

<br>

## 🧐 See also

- [How to update existing reports to FOCUS](./mapping.md)
- [Data dictionary](../resources/data-dictionary.md)
- [Generating a unique ID](../resources/data-dictionary.md#-generating-a-unique-id)
- [Known issues](../resources/data-dictionary.md#-known-issues)
- [Common terms](../resources/terms.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
