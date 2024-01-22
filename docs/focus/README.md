---
layout: default
title: FOCUS
nav_order: zzz
description: 'About FOCUS, the FinOps Open Cost + Usage Specification.'
permalink: /focus
---

<span class="fs-9 d-block mb-4">FinOps Open Cost + Usage Specification</span>
Learn about the new billing data specification that will make it easier to understand and optimize cost and usage across any cloud, SaaS, or on-prem provider.
{: .fs-6 .fw-300 }

<!--
[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#-v01){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [🤔 Why FOCUS?](#-why-focus)
- [🌟 Benefits](#-benefits)
- [▶️ Getting started](#️-getting-started)
- [🔀 Mapping to FOCUS](#-mapping-to-focus)
- [⚠️ Important notes about FOCUS support](#️-important-notes-about-focus-support)
- [🧰 Related tools](#-related-tools)

</details>

---

The FinOps Open Cost and Usage Specification (FOCUS) is a groundbreaking initiative to define a common format for billing data that empowers organizations to better understand cost and usage patterns and optimize spending and performance across multiple cloud, SaaS, and even on-premises service offerings.

FOCUS will provide organizations with a consistent, clear, and accessible view of their cost data explicitly designed for FinOps needs such as allocation, analytics, monitoring, and optimization. As the new “language” of FinOps, FOCUS will enable practitioners to collaborate more efficiently and effectively with peers throughout the organization and even maximize transferability and onboarding for new team members, getting people up and running quicker. Paired with the FinOps Framework, practitioners will be armed with the tools needed to build a streamlined FinOps practice that maximizes the value of the cloud.

## 🤔 Why FOCUS?

### Why organizations need FOCUS

The variety and flexibility of Microsoft cloud services allows you to build amazing things while only paying for what you need, when you need it. And with this flexibility comes varying operational models where services are billed and can be tuned differently based on a variety of factors. When services are billed differently, their cost and usage data tends to differ as well, making it challenging to allocate, analyze, monitor, and optimize consistently. Of course, this goes beyond just Microsoft’s cloud services. Organizations often rely on software as a service (SaaS) products, licensed software, on-premises infrastructure, or even other clouds, exacerbating the problem with each provider sharing data in proprietary formats.

FOCUS solves this problem by establishing a provider and service agnostic data specification that addresses some of the biggest challenges organizations face in managing the value of their cloud investments—understanding and quantifying the business value of their spending. FOCUS will enable organizations to spend more time driving value and less struggling to understand data caused by inconsistencies between and unfamiliarity with different services and providers.

### Why Microsoft believes in FOCUS

But why would Microsoft want to join other cloud providers and SaaS vendors to promote a common billing data specification? Because consistent cloud billing promotes the innovation and experimentation that Azure is built to provide. Building and optimizing applications in Azure in an iterative way using modern architectures is easier when you clearly understand how you’re billed and can weigh cost equally amongst other business priorities in building those systems. Better collaboration between business, technical, and finance teams will make your organization more productive overall, which maps back to our core mission to empower every person and every organization on the planet to achieve more.

Widespread adoption of FOCUS will make allocating, analyzing, monitoring, and optimizing costs across providers as easy as using a single provider, enabling you to do more with less. FinOps skills become more portable than ever, and practitioners, vendors, and consultants will become more efficient and effective when moving to an organization that uses different clouds or SaaS products. Without having to spend time learning proprietary data formats, organizations can focus on value-added FinOps capabilities that help deliver real value.

Our adoption of FOCUS removes a barrier to cloud adoption and helps organizations make better data-driven decisions about their cloud use that translates to business value on top of the Microsoft cloud.

<br>

## 🌟 Benefits

FOCUS is the **best** version of cost and usage data you can get from Cost Management. Some of the benefits you'll see with FOCUS compared to actual and amortized cost data include:

- 💰 **Save 30% on storage and compute costs**

  > FOCUS combines billed (actual) and amortized costs in a single row, which results in 49% fewer rows compared to actual and amortized datasets together. Factoring in new FOCUS columns, the total data size is ~30% smaller than actual and amortized datasets, which is a direct savings on storage costs. You'll also save on compute costs since you'll be processing fewer rows. Exact compute savings will vary depending on your solution.

- 🔀 **Designed to handle multiple accounts and clouds**

  > Whether you're using multiple clouds or you have multiple account types in a single cloud (e.g., EA and MCA), FOCUS aligns your cost data into a single schema with consistent terminology that makes it easy to understand and optimize your costs across all your accounts.

- 🍎 **Easier to learn and aligned with the FinOps Framework**

  > FOCUS is the new "language" of FinOps. All FinOps Framework guidance will be updated to use FOCUS terminology and also include FOCUS queries and examples. This will make it easier to understand and implement FinOps best practices without requiring an extra layer of translation from cloud-agnostic guidance to cloud-specific implementation details. FOCUS enables cloud-agnostic patterns and guidance to go deeper and help you accomplish more with less effort.

- 🪪 **Clean, human-readable display names**

  > FOCUS uses clean, human-readable display names for all names, types, and categories. Friendly display names are available for services, resource types, regions, pricing, commitment discounts, and more.

- 💲 **Uniquely identify the exact price-point**

  > FOCUS includes an identifier for the specific SKU price-point used for each charge (SkuPriceId). This is a unique identifier for the SKU inclusive of all pricing variations, like tiering and discounts, which is not currently available in actual or amortized datasets. Each charge also includes the unit prices you need to understand how you are or could be charged. List (or retail) unit price is what you would pay per unit without any negotiated discounts, your on-demand unit price is after negotiated discounts are applied, your effective (or amortized) unit price shows the conceptual price after pre-purchase commitment discounts were applied, and your billed unit price represents what was or will be invoiced.

- 💹 **Easier to quantify cost savings**

  > In addition to unit prices, FOCUS also includes columns to identify the specific pricing model used for each charge with list, on-demand, effective, and billed cost which makes it easier to quantify cost savings from negotiated and commitment discounts.

- 💎 **All prices and costs in a consistent currency**

  > FOCUS uses the billing currency for all prices and costs, which makes it easier to verify costs within the cost and usage data. Note this will differ from the prices in the native Cost Management datasets, which use the pricing currency.

- 🔡 **Organize and differentiate costs by service, resource, and SKU**

  > FOCUS clearly delineates between services, resources, and SKUs, which makes it easier to organize and differentiate costs. Service categorization is consistent across providers and offers a new perspective as it groups all resources consumed for a specific service together, regardless of the underlying product or SKU (e.g., bandwidth and compute costs both fall under the Virtual Machines service).

- 🌏 **More consistent regions**

  > The FOCUS dataset in Cost Management provides an extra layer of data cleansing to ensure regions are consistent with Azure Resource Manager. This means you'll see the same region names in FOCUS as you do in the Azure portal and Azure Resource Manager APIs.

- 📅 **Simpler date logic**

  > FOCUS uses exclusive end dates and industry standard ISO 8601 date formats for billing and charge periods, which makes it easier to filter and compare dates. This is especially useful when comparing to other dates, like the current date, since you don't have to guess about time zones or time of day.

- 🏷️ **Tags and SKU details are provided in a consistent JSON format**

  > If you have an Enterprise Agreement account, you may know that tags are not formatted as JSON in actual and amortized datasets. FOCUS fixes this by providing tags and SKU details (AdditionalInfo) in a consistent JSON format.

- 🎛️ **Identify and break usage down to discrete units**

  > FOCUS provides discrete pricing and usage units for each charge to help you understand how you're being charged compared to real-world usage units. This accounts for different pricing strategies like block pricing and makes it easier to verify pricing and usage quantities by providing data in separate columns.

<br>

## ▶️ Getting started

FOCUS 1.0 preview covers the resources you deployed, the internal SKUs each resource used, the type of charge, how much you used or purchased, how it was priced, and the specific

- Billing details related to invoicing, like the provider you used, who generated the invoice (invoice issuer), and the billing period for the invoice.
- Resource details about what you deployed with the provider, like the service, resource type, region, and tags.
- SKU details about the product you used or purchased, like the publisher and SKU identifiers.
- Charge details that describe and categorize the charge, like the type, description, frequency, and amount used or purchased.
- Discount details that summarize the pricing model, like the pricing category and commitment discount details.
- Pricing + costs that include the raw details about how each charge is priced, like the pricing quantity, unit price, and cost.

Resources are identified by a **ResourceId** and **ResourceName** and organized into their respective **ServiceName** and **ServiceCategory**. **ServiceCategory** enables you to organize your costs into a top-level set of categories consistent across cloud providers, which makes it especially interesting. You can also see additional details, like a friendly **ResourceType** label, the **Region** a resource was deployed to, and any **Tags** that were applied to the resource.

Behind the scenes, resources use one or more products to enable their core capabilities. FOCUS refers to these as SKUs. Use of these SKUs is ultimately what you are charged for. Each SKU has a **PublisherName** of the company who developed the SKU, a **SkuId** that identifies the SKU that was used, and a **SkuPriceId** that identifies the specific price-point for the SKU, inclusive of all pricing variations like tiering and discounts.

All charges include a **ChargeCategory** and **ChargeSubcategory** to describe what kind of charge it is (such as usage or purchase), the **ChargePeriodStart** and **ChargePeriodEnd** dates the charge applied to, the **ChargeFrequency** to know how often you can expect to see this charge, and a high-level **ChargeDescription** to explain what the row represents. They also include a specific **UsageQuantity** and **UsageUnit** in distinct units based on what was used or purchased.

Each charge has a **PricingCategory** that indicates how the charge was priced and, if a commitment discount was applied, they include **CommitmentDiscountCategory** and **CommitmentDiscountType** for friendly provider-agnostic and provider-specific labels for the type of commitment discount, **CommitmentDiscountId** to identify which commitment discount was applied to usage, and the **CommitmentDiscountName** of that instance.

Since prices are determined based on the billing relationship, you can also find the **BillingAccountId** and **BillingAccountName** that invoices are generated against, the **BillingPeriodStart** and **BillingPeriodEnd** dates the invoice applies to, the **InvoiceIssuerName** for the company responsible for invoicing, and the **ProviderName** of the cloud, SaaS, on-prem, or other provider you used. Please note the "billing account" term in FOCUS refers to the scope at which an invoice is generated and not the top-level, root account. For organizations with a Microsoft Customer Agreement (MCA) account, this maps to your billing profile and not your Microsoft billing account. Within each billing account, you also have a **SubAccountId** and **SubAccountName** for the subscription within the billing account.

Last but not least you also have the price and cost details. Each charge has a **BillingCurrency** that all prices and costs use, which may be different than how the provider prices charges. As an example, most MCA accounts are priced in USD and may be billed in another currency like Yen or Euros.

<blockquote class="warning" markdown="1">
   _Please note that since FOCUS relies on the billing currency, the prices shown in FOCUS datasets may not match native Cost Management schemas._
</blockquote>

Each charge includes the **PricingQuantity** and **PricingUnit** based on how the SKU was priced (which may be in chunks or "blocks" of units) and a set of unit prices for the cost of each individual pricing unit (based on the **SkuPriceId**) and the total cost based on the pricing quantity. Currently, FOCUS includes the **ListUnitPrice** and **ListCost** for the public retail or market prices without discounts, **EffectiveCost** after commitment discount purchases have been amortized, and **BilledCost** that was or will be invoiced.

<blockquote class="important" markdown="1">
   _Perhaps the biggest difference between FOCUS and native schemas is that FOCUS combines "actual" and "amortized" cost into a single datasets. This saves you time and money with a smaller dataset size compared to managing both datasets separately. Data size is on par with the amortized cost data except with less than 100 more rows for commitment discount purchases and refunds._
</blockquote>

Beyond these, each provider can include additional columns prefixed with **x\_** to denote them as external columns that are not part of the FOCUS schema but provide useful details about your cost and usage. Microsoft Cost Management provides the same details within its FOCUS dataset as the native schemas by utilizing this prefix. FinOps toolkit reports add to these columns with additional details to facilitate reporting and optimization goals.

<br>

## 🔀 Mapping to FOCUS

Use the following sections to either generate FOCUS-compliant data from existing datasets or to update existing reporting to leverage FOCUS columns.

### How to convert Cost Management data to FOCUS

The following mapping is assuming you have all amortized cost rows and only commitment purchases and refunds from the actual cost dataset.

| FOCUS column               | Cost Management column                              | Transform                                                                                                                                                                                                                                   |
| -------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BilledCost                 | CostInBillingCurrency                               | Use `0` for amortized commitment usage<sup>1</sup>                                                                                                                                                                                          |
| BillingAccountId           | EA: BillingAccountId<br>MCA: BillingProfileId       | None                                                                                                                                                                                                                                        |
| BillingAccountName         | EA: BillingAccountName<br>MCA: BillingProfileName   | None                                                                                                                                                                                                                                        |
| BillingCurrency            | EA: BillingCurrencyCode<br>MCA: BillingCurrency     | None                                                                                                                                                                                                                                        |
| BillingPeriodEnd           | BillingPeriodEndDate                                | Add 1 day for the exclusive end date                                                                                                                                                                                                        |
| BillingPeriodStart         | BillingPeriodStartDate                              | None                                                                                                                                                                                                                                        |
| ChargeCategory             | ChargeType                                          | If "Usage", "Purchase", or "Tax", same value; if "UnusedReservation" or "UnusedSavingsPlan", `Usage`; otherwise, `Adjustment`                                                                                                               |
| ChargeDescription          | ProductName                                         | None                                                                                                                                                                                                                                        |
| ChargeFrequency            | Frequency                                           | If "OneTime", `One-Time`; if "Recurring", `Recurring`; if "UsageBased", `Usage-Based`; otherwise, `Other`                                                                                                                                   |
| ChargePeriodEnd            | Date                                                | Add 1 day for the exclusive end date                                                                                                                                                                                                        |
| ChargePeriodStart          | Date                                                | None                                                                                                                                                                                                                                        |
| ChargeSubcategory          | ChargeType                                          | If "Usage" and PricingModel is "Reservation" or "SavingsPlan", `Used Commitment`; if "UnusedReservation" or "UnusedSavingsPlan", `Unused Commitment`; if "Refund", `Refund`; if "RoundingAdjustment", `Rounding Error`; otherwise, `Other`. |
| CommitmentDiscountCategory | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Usage`; if contains "/microsoft.billingbenefits/", use `Spend`; otherwise, null                                                                                           |
| CommitmentDiscountId       | BenefitId                                           | None                                                                                                                                                                                                                                        |
| CommitmentDiscountName     | BenefitName                                         | None                                                                                                                                                                                                                                        |
| CommitmentDiscountType     | BenefitId                                           | If BenefitId contains "/microsoft.capacity/" (case-insensitive), `Reservation`; if contains "/microsoft.billingbenefits/", `Savings Plan`; otherwise, null                                                                                  |
| EffectiveCost              | CostInBillingCurrency                               | Use `0` for commitment purchases and refunds<sup>1</sup>.                                                                                                                                                                                   |
| InvoiceIssuerName          | PartnerName                                         | If PartnerName is empty, use `Microsoft`.                                                                                                                                                                                                   |
| ListCost                   | EA: Not available<br>MCA: PaygCostInBillingCurrency | None                                                                                                                                                                                                                                        |
| ListUnitPrice              | EA: PayGPrice<br>MCA: PayGPrice \* ExchangeRate     | None                                                                                                                                                                                                                                        |
| PricingCategory            | PricingModel                                        | If "OnDemand", `On-Demand`; if "Spot", `Dynamic`; if "Reservation" or "Savings Plan", `Commitment Discount`; otherwise, `Other`                                                                                                             |
| PricingQuantity            | Quantity                                            | Map UnitOfMeasure using [Pricing units data file](../open-data/README.md#-pricing-units) and divide Quantity by the PricingBlockSize                                                                                                        |
| PricingUnit                | UnitOfMeasure                                       | Map using [Pricing units data file](../open-data/README.md#-pricing-units)                                                                                                                                                                  |
| ProviderName               | `Microsoft`                                         | None                                                                                                                                                                                                                                        |
| PublisherName              | PublisherName                                       | None                                                                                                                                                                                                                                        |
| Region                     | ResourceLocation                                    | Map using [Regions data file](../open-data/README.md#-regions)<sup>3</sup>                                                                                                                                                                  |
| ResourceId                 | ResourceId                                          | None                                                                                                                                                                                                                                        |
| ResourceName               | ResourceName                                        | None                                                                                                                                                                                                                                        |
| ResourceType               | ResourceType                                        | Map using [Resource types data file](../open-data/README.md#-resource-types)                                                                                                                                                                |
| ServiceCategory            | ResourceType                                        | Map using [Services data file](../open-data/README.md#-services)                                                                                                                                                                            |
| ServiceName                | ResourceType                                        | Map using [Services data file](../open-data/README.md#-services)                                                                                                                                                                            |
| SkuId                      | EA: Not available<br>MCA: ProductId                 | None                                                                                                                                                                                                                                        |
| SkuPriceId                 | Not available                                       | None                                                                                                                                                                                                                                        |
| SubAccountId               | SubscriptionId                                      | None                                                                                                                                                                                                                                        |
| SubAccountName             | SubscriptionName                                    | None                                                                                                                                                                                                                                        |
| Tags                       | Tags                                                | Wrap in `{` and `}` if needed                                                                                                                                                                                                               |
| UsageQuantity              | Quantity                                            | None                                                                                                                                                                                                                                        |
| UsageUnit                  | UnitOfMeasure                                       | Map using [Pricing units data file](../open-data/README.md#-pricing-units)                                                                                                                                                                  |

_<sup>1. BilledCost should copy cost from all rows **except** commitment usage that has a PricingModel of "Reservation" or "SavingsPlan" which should be `0`. EffectiveCost should copy cost from all amortized dataset rows; commitment purchases and refunds from the actual cost dataset should be `0`.</sup>_

_<sup>2. Quantity in Cost Management is the usage quantity.</sup>_

_<sup>3. While Region is a direct mapping of ResourceLocation, Cost Management and FinOps toolkit reports do additional data cleansing to ensure consistency in values based on the [Regions data file](../open-data/README.md#-regions).</sup>_

### How to update existing reports to FOCUS

Use the following table to update existing automation and reporting solutions to use FOCUS.

| Column                       | Value(s)                   | How to update                                                                                                                                                   |
| ---------------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AccountName                  | (All)                      | Use **x_AccountName**                                                                                                                                           |
| AccountOwnerId               | (All)                      | Use **x_AccountOwnerId**                                                                                                                                        |
| AdditionalInfo               | (All)                      | Use **x_SkuDetails**                                                                                                                                            |
| CostInBillingCurrency        | (All)                      | For actual cost, use **BilledCost**; otherwise, use **EffectiveCost**                                                                                           |
| BenefitId                    | (All)                      | Use **CommitmentDiscountId**                                                                                                                                    |
| BenefitName                  | (All)                      | Use **CommitmentDiscountName**                                                                                                                                  |
| BillingAccountId             | (All)                      | EA: Use **BillingAccountId**<br>MCA: Use **x_BillingAccountId**                                                                                                 |
| BillingAccountName           | (All)                      | EA: Use **BillingAccountName**<br>MCA: Use **x_BillingAccountName**                                                                                             |
| BillingCurrencyCode          | (All)                      | Use **BillingCurrency**                                                                                                                                         |
| BillingProfileId             | (All)                      | EA: Use **x_BillingProfileId**<br>MCA: Use **BillingAccountId**                                                                                                 |
| BillingProfileName           | (All)                      | EA: Use **x_BillingProfileName**<br>MCA: Use **BillingAccountName**                                                                                             |
| BillingPeriodEndDate         | (All)                      | Use **BillingPeriodEnd** and change comparisons to use less than (`<`) rather than less than or equal to (`<=`)                                                 |
| BillingPeriodStartDate       | (All)                      | Use **BillingPeriodStart**                                                                                                                                      |
| ChargeType                   | "Usage", "Purchase", "Tax" | Use **ChargeCategory**                                                                                                                                          |
| ChargeType                   | "UnusedReservation"        | Use **ChargeSubcategory** = "Unused Commitment" and **CommitmentDiscountType** = "Reservation"                                                                  |
| ChargeType                   | "UnusedSavingsPlan"        | Use **ChargeSubcategory** = "Unused Commitment" and **CommitmentDiscountType** = "Savings Plan"                                                                 |
| ChargeType                   | "Refund"                   | Use **ChargeSubcategory** = "Refund"                                                                                                                            |
| ChargeType                   | "RoundingAdjustment"       | Use **ChargeSubcategory** = "Rounding Error"                                                                                                                    |
| CostAllocationRuleName       | (All)                      | Use **x_CostAllocationRuleName**                                                                                                                                |
| CostCenter                   | (All)                      | Use **x_CostCenter**                                                                                                                                            |
| CostInUsd                    | (All)                      | For actual cost, use **x_BilledCostInUsd**; otherwise, use **x_EffectiveCostInUsd**                                                                             |
| CustomerName                 | (All)                      | Use **x_CustomerName**                                                                                                                                          |
| CustomerTenantId             | (All)                      | Use **x_CustomerId**                                                                                                                                            |
| Date                         | (All)                      | Use **ChargePeriodStart**                                                                                                                                       |
| DepartmentName               | (All)                      | Use **x_InvoiceSectionName**                                                                                                                                    |
| EffectivePrice               | (All)                      | Use **x_EffectiveUnitPrice**                                                                                                                                    |
| ExchangeRatePricingToBilling | (All)                      | Use **x_BillingExchangeRate**                                                                                                                                   |
| ExchangeRateDate             | (All)                      | Use **x_BillingExchangeRateDate**                                                                                                                               |
| Frequency                    | "OneTime"                  | Use **ChargeFrequency** = "One-Time"                                                                                                                            |
| Frequency                    | "Recurring"                | Use **ChargeFrequency** = "Recurring"                                                                                                                           |
| Frequency                    | "UsageBased"               | Use **ChargeFrequency** = "Usage-Based"                                                                                                                         |
| InvoiceId                    | (All)                      | Use **x_InvoiceId**                                                                                                                                             |
| InvoiceSectionId             | (All)                      | Use **x_InvoiceSectionId**                                                                                                                                      |
| InvoiceSectionName           | (All)                      | Use **x_InvoiceSectionName**                                                                                                                                    |
| IsAzureCreditEligible        | (All)                      | Use **x_SkuIsCreditEligible**                                                                                                                                   |
| Location                     | (All)                      | Use **Region**                                                                                                                                                  |
| MeterCategory                | (All)                      | To group resources, use **ServiceName**; to group meters, use **x_SkuMeterCategory**                                                                            |
| MeterId                      | (All)                      | Use **x_SkuMeterId**                                                                                                                                            |
| MeterName                    | (All)                      | Use **x_SkuMeterName**                                                                                                                                          |
| MeterRegion                  | (All)                      | Use **x_SkuRegion**                                                                                                                                             |
| MeterSubcategory             | (All)                      | Use **x_SkuMeterSubcategory**                                                                                                                                   |
| OfferId                      | (All)                      | Use **x_SkuOfferId**                                                                                                                                            |
| PartnerEarnedCreditApplied   | (All)                      | Use **x_PartnerCreditApplied**                                                                                                                                  |
| PartnerEarnedCreditRate      | (All)                      | Use **x_PartnerCreditRate**                                                                                                                                     |
| PartnerName                  | (All)                      | Use **InvoiceIssuerName** or **x_PartnerName**                                                                                                                  |
| PartnerTenantId              | (All)                      | Use **x_InvoiceIssuerId**                                                                                                                                       |
| PartNumber                   | (All)                      | Use **x_SkuPartNumber**                                                                                                                                         |
| ProductName                  | (All)                      | Use **ChargeDescription**                                                                                                                                       |
| ProductOrderId               | (All)                      | Use **x_SkuOrderId**                                                                                                                                            |
| ProductOrderName             | (All)                      | Use **x_SkuOrderName**                                                                                                                                          |
| PaygCostInBillingCurrency    | (All)                      | Use **ListCost**                                                                                                                                                |
| PayGPrice                    | (All)                      | Use **ListUnitPrice** / **x_BillingExchangeRate**                                                                                                               |
| PricingCurrency              | (All)                      | Use **x_PricingCurrency**                                                                                                                                       |
| PricingModel                 | "OnDemand"                 | Use **PricingCategory** = "On-Demand"                                                                                                                           |
| PricingModel                 | "Reservation"              | For all commitments, use **PricingCategory** = "Commitment Discount"; for savings plan only, use **CommitmentDiscountCategory** = "Usage"                       |
| PricingModel                 | "SavingsPlan"              | For all commitments, use **PricingCategory** = "Commitment Discount"; for savings plan only, use **CommitmentDiscountCategory** = "Spend"                       |
| PricingModel                 | "Spot"                     | Use **PricingCategory** = "Dynamic" or **x_PricingSubcategory** = "Spot"                                                                                        |
| ProductId                    | (All)                      | Use **SkuId**                                                                                                                                                   |
| Quantity                     | (All)                      | Use **UsageQuantity**                                                                                                                                           |
| ResellerMpnId                | (All)                      | Use **x_ResellerId**                                                                                                                                            |
| ResellerName                 | (All)                      | Use **x_ResellerName**                                                                                                                                          |
| ReservationId                | (All)                      | Use **CommitmentDiscountId**; split by "/" and use last segment for the reservation GUID                                                                        |
| ReservationName              | (All)                      | Use **CommitmentDiscountName**                                                                                                                                  |
| ResourceGroupName            | (All)                      | Use **x_ResourceGroupName**                                                                                                                                     |
| ResourceLocationNormalized   | (All)                      | Use **Region**                                                                                                                                                  |
| ResourceType                 | (All)                      | For friendly names, use **ResourceType**; otherwise, use **x_ResourceType**                                                                                     |
| ServiceFamily                | (All)                      | To group resources, use **ServiceCategory**; to group meters, use **x_SkuServiceFamily**                                                                        |
| ServicePeriodEnd             | (All)                      | Use **x_ServicePeriodEnd**                                                                                                                                      |
| ServicePeriodStart           | (All)                      | Use **x_ServicePeriodStart**                                                                                                                                    |
| SubscriptionId               | (All)                      | For a unique value, use **SubAccountId**; for the subscripion GUID, use **x_SubscriptionId**                                                                    |
| SubscriptionName             | (All)                      | Use **SubAccountName** or **x_SubscriptionName**                                                                                                                |
| Tags                         | (All)                      | Use **Tags** but don't wrap in curly braces (`{}`)                                                                                                              |
| Term                         | (All)                      | Use **x_SkuTerm**                                                                                                                                               |
| UnitOfMeasure                | (All)                      | For the exact value, use **x_PricingUnitDescription**; for distinct units, use **PricingUnit** or **UsageUnit**; for the block size, use **x_PricingBlockSize** |

### Generating a unique ID per row

Use the following columns in the Cost Management FOCUS dataset to generate a unique ID:

1. BillingAccountId
2. ChargePeriodStart
3. CommitmentDiscountId
4. Region
5. ResourceId
6. SkuPriceId
7. SubAccountId
8. Tags
9. x_AccountId
10. x_CostCenter
11. x_InvoiceSectionId
12. x_SkuDetails
13. x_SkuMeterId
14. x_SkuOfferId
15. x_SkuPartNumber

<br>

## ⚠️ Important notes about FOCUS support

Please note the following when using FinOps toolkit reports that align to the FOCUS schema:

1. For FinOps hubs, `BilledCost` is missing reservation and savings plan purchases and refunds and cannot be used for invoice reconciliation.
   - FinOps hubs v0.0.1 only supports amortized cost data. Support for actual (billed) cost data will be added in a future release.
2. `BillingAccountId` and `BillingAccountName` may be confusing for Microsoft Customer Agreement accounts, where the billing profile is used.
   - We are looking for feedback about this to understand if it is a problem and determine the best way to address it.
3. `BillingPeriodEnd` and `ChargePeriodEnd` are exclusive, which is ideal for filtering, but may be confusing.
   - We are looking for feedback about this to understand if it is a problem and determine the best way to address it.
4. `InvoiceIssuerName` is not accounting for Cloud Solution Provider partners.
   - FinOps hubs v0.0.1 only supports Enterprise Agreement accounts. Support for Microsoft Customer Agreement and Microsoft Partner Agreement accounts will be added in a future release.
5. For the Cost Management connector, `PricingUnit` and `UsageUnit` both include the pricing block size.
6. `Region` can include values that are not regions, such as `Unassigned`.
   - This is an underlying service issue and must be resolved by the service that is referencing invalid Azure locations in their usage data.
7. `Region` uses `Global` to indicate a global service.
   - FOCUS is considering whether to use `Global` or not. This will be finalized by FOCUS 1.0.
8. `ServiceName` and `ServiceCategory` are using a custom mapping that may not account for all services yet.
   - We will update this list to account for all services soon. This will require ongoing work to keep up with the pace at which Microsoft is enabling new services.
   - Please let us know if you find any missed services or if you have any feedback about the mapping.
9. `ServiceName` uses `Azure Savings Plan for Compute` for savings plan records due to missing service details.
   - This is an underlying data issue and must be resolved by the service that generates the data.
10. `ServiceName` attempts to map Azure Kubernetes Service (AKS) charges based on a simple resource group name check, which may catch false positives.
    - We will update the resource group check to be more targeted soon.
    - Please let us know if you find any false positives.
    - If we find we are unable to accurately identify AKS charges, we will fall back to the service name for the actual resource (e.g., Load Balancer).
11. For the Cost Management connector, `SkuPriceId` is not set due to the connector not having the data to populate the value.

If you have feedback about our mappings or about our full FOCUS support plans, please leave a comment within the [FOCUS schema release discussion](https://github.com/microsoft/finops-toolkit/discussions/61). If you believe you've found a bug, please [create an issue](https://github.com/microsoft/finops-toolkit/issues/new/choose).

If you have feedback about FOCUS, please consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make this the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
