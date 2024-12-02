---
layout: default
parent: FOCUS
title: Metadata
nav_order: 99
description: 'General information about the FOCUS dataset including the data generator, schema version, and columns included in the dataset.'
permalink: /focus/metadata
---

<span class="fs-9 d-block mb-4">Details about the FOCUS dataset</span>
General information about the FOCUS dataset including the data generator, schema version, and columns included in the dataset.
{: .fs-6 .fw-300 }

<!--
[Download the latest release](https://github.com/microsoft/finops-toolkit/releases/latest){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[See changes](#-v01){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }
-->

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [FocusCost 1.0](#focuscost-10)
- [FocusCost 1.0-preview(v1)](#focuscost-10-previewv1)
- [🙋‍♀️ Feedback about FOCUS columns](#️-feedback-about-focus-columns)
- [🧐 See also](#-see-also)
- [🧰 Related tools](#-related-tools)

</details>

---

This document describes what's included in the FOCUS cost and usage details dataset (aka FocusCost). The details provided below are also available as a JSON file as defined by the FOCUS specification. To learn more about FOCUS, refer to the [FOCUS overview](./README.md).

<br>

## FocusCost 1.0

- Data generator: Microsoft
- Schema ID: `1.0`
- FOCUS version: `1.0`
- Creation date: June 20, 2023
- String encoding: UTF-8

Columns include:

| ColumnName                   | DataType | Description                                                                                                                                                                                                         |
| ---------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BilledCost`                 | Decimal  | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring).                                              |
| `BillingAccountId`           | String   | Unique identifier assigned to a billing account by the provider.                                                                                                                                                    |
| `BillingAccountName`         | String   | Display name assigned to a billing account.                                                                                                                                                                         |
| `BillingAccountType`         | String   | Provider label for the kind of entity the BillingAccountId represents.                                                                                                                                              |
| `BillingCurrency`            | String   | Currency that a charge was billed in.                                                                                                                                                                               |
| `BillingPeriodEnd`           | DateTime | Exclusive end date and time of the billing period.                                                                                                                                                                  |
| `BillingPeriodStart`         | DateTime | Inclusive start date and time of the billing period.                                                                                                                                                                |
| `ChargeCategory`             | String   | Highest-level classification of a charge based on the nature of how it is billed.                                                                                                                                   |
| `ChargeClass`                | String   | Indicates whether the row represents a correction to one or more charges invoiced in a previous billing period.                                                                                                     |
| `ChargeDescription`          | String   | Self-contained summary of the charge's purpose and price.                                                                                                                                                           |
| `ChargeFrequency`            | String   | Indicates how often a charge will occur.                                                                                                                                                                            |
| `ChargePeriodEnd`            | DateTime | Exclusive end date and time of a charge period.                                                                                                                                                                     |
| `ChargePeriodStart`          | DateTime | Inclusive start date and time of a charge period.                                                                                                                                                                   |
| `CommitmentDiscountCategory` | String   | Indicates whether the commitment-based discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka spend).                                                                       |
| `CommitmentDiscountId`       | String   | Unique identifier assigned to a commitment-based discount by the provider.                                                                                                                                          |
| `CommitmentDiscountName`     | String   | Display name assigned to a commitment-based discount.                                                                                                                                                               |
| `CommitmentDiscountStatus`   | String   | Indicates whether the charge corresponds with the consumption of a commitment-based discount or the unused portion of the committed amount.                                                                         |
| `CommitmentDiscountType`     | String   | Label assigned by the provider to describe the type of commitment-based discount applied to the row.                                                                                                                |
| `ConsumedQuantity`           | Decimal  | Volume of a given SKU associated with a resource or service used, based on the Consumed Unit.                                                                                                                       |
| `ConsumedUnit`               | Decimal  | Provider-specified measurement unit indicating how a provider measures usage of a given SKU associated with a resource or service.                                                                                  |
| `ContractedCost`             | Decimal  | Cost calculated by multiplying contracted unit price and the corresponding Pricing Quantity.                                                                                                                        |
| `ContractedUnitPrice`        | Decimal  | The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment-based discounts or any other discounts.            |
| `EffectiveCost`              | Decimal  | The amortized cost of the charge after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge.                           |
| `InvoiceIssuerName`          | String   | The name of the entity responsible for invoicing for the resources or services consumed.                                                                                                                            |
| `ListCost`                   | Decimal  | Cost calculated by multiplying List Unit Price and the corresponding Pricing Quantity.                                                                                                                              |
| `ListUnitPrice`              | Decimal  | Suggested provider-published unit price for a single Pricing Unit of the associated SKU, exclusive of any discounts.                                                                                                |
| `PricingCategory`            | String   | Describes the pricing model used for a charge at the time of use or purchase.                                                                                                                                       |
| `PricingQuantity`            | Decimal  | Volume of a given SKU associated with a resource or service used or purchased, based on the Pricing Unit.                                                                                                           |
| `PricingUnit`                | String   | Provider-specified measurement unit for determining unit prices, indicating how the provider rates measured usage and purchase quantities after applying pricing rules like block pricing.                          |
| `ProviderName`               | String   | Name of the entity that made the resources and/or services available for purchase.                                                                                                                                  |
| `PublisherName`              | String   | Name of the entity that produced the resources and/or services that were purchased.                                                                                                                                 |
| `RegionId`                   | String   | Provider-assigned identifier for an isolated geographic area where a resource is provisioned or a service is provided.                                                                                              |
| `RegionName`                 | String   | Name of an isolated geographic area where a resource is provisioned or a service is provided.                                                                                                                       |
| `ResourceId`                 | String   | Unique identifier assigned to a resource by the provider.                                                                                                                                                           |
| `ResourceName`               | String   | Display name assigned to a resource.                                                                                                                                                                                |
| `ResourceType`               | String   | The kind of resource for which you are being charged.                                                                                                                                                               |
| `ServiceCategory`            | String   | Highest-level classification of a service based on the core function of the service.                                                                                                                                |
| `ServiceName`                | String   | An offering that can be purchased from a provider (e.g., cloud virtual machine, SaaS database, professional services from a systems integrator).                                                                    |
| `SkuId`                      | String   | Unique identifier that defines a provider-supported construct for organizing properties that are common across one or more SKU Prices.                                                                              |
| `SkuPriceId`                 | String   | Unique identifier that defines the unit price used to calculate the charge.                                                                                                                                         |
| `SubAccountId`               | String   | Unique identifier assigned to a grouping of resources and/or services, often used to manage access and/or cost.                                                                                                     |
| `SubAccountName`             | String   | Name assigned to a grouping of resources and/or services, often used to manage access and/or cost.                                                                                                                  |
| `SubAccountType`             | String   | Provider label for the kind of entity the SubAccountId represents.                                                                                                                                                  |
| `Tags`                       | JSON     | List of custom key-value pairs applied to a charge defined as a JSON object.                                                                                                                                        |
| `x_AccountId`                | String   | Unique identifier for the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                            |
| `x_AccountName`              | String   | Name of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                          |
| `x_AccountOwnerId`           | String   | Email address of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                 |
| `x_BilledCostInUsd`          | Decimal  | BilledCost in USD.                                                                                                                                                                                                  |
| `x_BilledUnitPrice`          | Decimal  | Unit price for a single Pricing Unit of the associated SKU that was charged per unit.                                                                                                                               |
| `x_BillingAccountId`         | String   | Unique identifier for the Microsoft billing account. Same as BillingAccountId for EA.                                                                                                                               |
| `x_BillingAccountName`       | String   | Name of the Microsoft billing account. Same as BillingAccountName for EA.                                                                                                                                           |
| `x_BillingExchangeRate`      | Decimal  | Exchange rate to multiply by when converting from the pricing currency to the billing currency.                                                                                                                     |
| `x_BillingExchangeRateDate`  | DateTime | Date the exchange rate was determined.                                                                                                                                                                              |
| `x_BillingProfileId`         | String   | Unique identifier for the Microsoft billing profile. Same as BillingAccountId for MCA.                                                                                                                              |
| `x_BillingProfileName`       | String   | Name of the Microsoft billing profile. Same as BillingAccountName for MCA.                                                                                                                                          |
| `x_ContractedCostInUsd`      | Decimal  | ContractedCost in USD.                                                                                                                                                                                              |
| `x_CostAllocationRuleName`   | String   | Name of the Microsoft Cost Management cost allocation rule that generated this charge. Cost allocation is used to move or split shared charges.                                                                     |
| `x_CostCenter`               | String   | Custom value defined by a billing admin for internal chargeback.                                                                                                                                                    |
| `x_CustomerId`               | String   | Unique identifier for the Cloud Solution Provider (CSP) customer tenant.                                                                                                                                            |
| `x_CustomerName`             | String   | Display name for the Cloud Solution Provider (CSP) customer tenant.                                                                                                                                                 |
| `x_EffectiveCostInUsd`       | Decimal  | EffectiveCost in USD.                                                                                                                                                                                               |
| `x_EffectiveUnitPrice`       | Decimal  | Unit price for a single Pricing Unit of the associated SKU after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge. |
| `x_InvoiceId`                | String   | Unique identifier for the invoice this charge was billed on.                                                                                                                                                        |
| `x_InvoiceIssuerId`          | String   | Unique identifier for the Cloud Solution Provider (CSP) partner.                                                                                                                                                    |
| `x_InvoiceSectionId`         | String   | Unique identifier for the MCA invoice section or EA department.                                                                                                                                                     |
| `x_InvoiceSectionName`       | String   | Display name for the MCA invoice section or EA department.                                                                                                                                                          |
| `x_ListCostInUsd`            | Decimal  | ListCost in USD.                                                                                                                                                                                                    |
| `x_PartnerCreditApplied`     | String   | Indicates when the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) was applied for a charge.                                                                                                              |
| `x_PartnerCreditRate`        | String   | Rate earned based on the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) applied.                                                                                                                         |
| `x_PricingBlockSize`         | Decimal  | Indicates the number of usage units grouped together for block pricing. This number is usually a part of the PricingUnit. Divide UsageQuantity by PricingBlockSize to get the PricingQuantity.                      |
| `x_PricingCurrency`          | String   | Currency used for all price columns.                                                                                                                                                                                |
| `x_PricingSubcategory`       | String   | Describes the kind of pricing model used for a charge within a specific Pricing Category.                                                                                                                           |
| `x_PricingUnitDescription`   | String   | Indicates what measurement type is used by the PricingQuantity, including pricing block size. This is what is used in the price list and/or on the invoice.                                                         |
| `x_PublisherCategory`        | String   | Indicates whether a charge is from a cloud provider or third-party Marketplace vendor.                                                                                                                              |
| `x_PublisherId`              | String   | Unique identifier of the entity that produced the resources and/or services that were purchased.                                                                                                                    |
| `x_ResellerId`               | String   | Unique identifier for the Cloud Solution Provider (CSP) reseller.                                                                                                                                                   |
| `x_ResellerName`             | String   | Name of the Cloud Solution Provider (CSP) reseller.                                                                                                                                                                 |
| `x_ResourceGroupName`        | String   | Grouping of resources that make up an application or set of resources that share the same lifecycle (e.g., created and deleted together).                                                                           |
| `x_ResourceType`             | String   | Azure Resource Manager resource type.                                                                                                                                                                               |
| `x_ServicePeriodEnd`         | DateTime | Exclusive end date of the service period applicable for the charge.                                                                                                                                                 |
| `x_ServicePeriodStart`       | DateTime | Start date of the service period applicable for the charge.                                                                                                                                                         |
| `x_SkuDescription`           | String   | Description of the SKU that was used or purchased.                                                                                                                                                                  |
| `x_SkuDetails`               | JSON     | Additional information about the SKU. This column is formatted as a JSON object.                                                                                                                                    |
| `x_SkuIsCreditEligible`      | Boolean  | Indicates if the charge is eligible for Azure credits.                                                                                                                                                              |
| `x_SkuMeterCategory`         | String   | Name of the service the SKU falls within.                                                                                                                                                                           |
| `x_SkuMeterId`               | String   | Unique identifier (sometimes a GUID, but not always) for the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price.                                                          |
| `x_SkuMeterName`             | String   | Name of the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price. Not applicable for purchases.                                                                             |
| `x_SkuMeterSubcategory`      | String   | Group of SKU Classes that address the same core need within the SKU Group.                                                                                                                                          |
| `x_SkuOfferId`               | String   | Microsoft Cloud subscription type.                                                                                                                                                                                  |
| `x_SkuOrderId`               | String   | Unique identifier of the entitlement product for this charge. Same as MCA ProductOrderId. Not applicable for EA.                                                                                                    |
| `x_SkuOrderName`             | String   | Display name of the entitlement product for this charge. Same as MCA ProductOrderId. Not applicable for EA.                                                                                                         |
| `x_SkuPartNumber`            | String   | Identifier to help break down specific usage meters.                                                                                                                                                                |
| `x_SkuRegion`                | String   | Region that the SKU operated in. This may be different from the resource region.                                                                                                                                    |
| `x_SkuServiceFamily`         | String   | Highest-level classification of a SKU based on the core function of the SKU.                                                                                                                                        |
| `x_SkuTerm`                  | Number   | Number of months a purchase covers.                                                                                                                                                                                 |
| `x_SkuTier`                  | String   | Pricing tier for the SKU when that SKU supports tiered or graduated pricing.                                                                                                                                        |

<br>

## FocusCost 1.0-preview(v1)

- Data generator: Microsoft
- Schema ID: `1.0-preview(v1)`
- FOCUS version: `1.0-preview`
- Creation date: November 15, 2023
- String encoding: UTF-8

Columns include:

| ColumnName                   | DataType | Description                                                                                                                                                                                    |
| ---------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AvailabilityZone`           | String   | Provider assigned identifier for a physically separated and isolated area within a Region that provides high availability and fault tolerance.                                                 |
| `BilledCost`                 | Decimal  | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring).                         |
| `BillingAccountId`           | String   | Unique identifier assigned to a billing account by the provider.                                                                                                                               |
| `BillingAccountName`         | String   | Display name assigned to a billing account.                                                                                                                                                    |
| `BillingAccountType`         | String   | Provider label for the kind of entity the BillingAccountId represents.                                                                                                                         |
| `BillingCurrency`            | String   | Currency that a charge was billed in.                                                                                                                                                          |
| `BillingPeriodEnd`           | DateTime | End date and time of the billing period.                                                                                                                                                       |
| `BillingPeriodStart`         | DateTime | Beginning date and time of the billing period.                                                                                                                                                 |
| `ChargeCategory`             | String   | Indicates whether the row represents an upfront or recurring fee, cost of usage that already occurred, an after-the-fact adjustment (e.g., credits), or taxes.                                 |
| `ChargeDescription`          | String   | Brief, human-readable summary of a row.                                                                                                                                                        |
| `ChargeFrequency`            | String   | Indicates how often a charge will occur.                                                                                                                                                       |
| `ChargePeriodEnd`            | DateTime | End date and time of a charge period.                                                                                                                                                          |
| `ChargePeriodStart`          | DateTime | Beginning date and time of a charge period.                                                                                                                                                    |
| `ChargeSubcategory`          | String   | Indicates the kind of usage or adjustment the row represents.                                                                                                                                  |
| `CommitmentDiscountCategory` | String   | Indicates whether the commitment-based discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka spend).                                                  |
| `CommitmentDiscountId`       | String   | Unique identifier assigned to a commitment-based discount by the provider.                                                                                                                     |
| `CommitmentDiscountName`     | String   | Display name assigned to a commitment-based discount.                                                                                                                                          |
| `CommitmentDiscountType`     | String   | Label assigned by the provider to describe the type of commitment-based discount applied to the row.                                                                                           |
| `EffectiveCost`              | Decimal  | The cost inclusive of amortized upfront fees, amortized recurring fees, and the usage cost of the row.                                                                                         |
| `InvoiceIssuerName`          | String   | Name of the entity responsible for invoicing for the resources and/or services consumed.                                                                                                       |
| `ListCost`                   | Decimal  | The cost without any discounts or amortized charges based on the public retail or market prices.                                                                                               |
| `ListUnitPrice`              | Decimal  | Unit price for the SKU without any discounts or amortized charges based on the public retail or market prices that a consumer would be charged per unit.                                       |
| `PricingCategory`            | String   | Indicates how the charge was priced.                                                                                                                                                           |
| `PricingQuantity`            | Decimal  | Amount of a particular service that was used or purchased based on the PricingUnit. PricingQuantity is the same as UsageQuantity divided by PricingBlocksize.                                  |
| `PricingUnit`                | String   | Indicates what measurement type is used by the PricingQuantity.                                                                                                                                |
| `ProviderName`               | String   | Name of the entity that made the resources and/or services available for purchase.                                                                                                             |
| `PublisherName`              | String   | Name of the entity that produced the resources and/or services that were purchased.                                                                                                            |
| `Region`                     | String   | Isolated geographic area where a resource is provisioned in and/or a service is provided from.                                                                                                 |
| `ResourceId`                 | String   | Unique identifier assigned to a resource by the provider.                                                                                                                                      |
| `ResourceName`               | String   | Display name assigned to a resource.                                                                                                                                                           |
| `ResourceType`               | String   | The kind of resource for which you are being charged.                                                                                                                                          |
| `ServiceCategory`            | String   | Highest-level classification of a service based on the core function of the service.                                                                                                           |
| `ServiceName`                | String   | An offering that can be purchased from a provider (e.g., cloud virtual machine, SaaS database, professional services from a systems integrator).                                               |
| `SkuId`                      | String   | Unique identifier for the SKU that was used or purchased.                                                                                                                                      |
| `SkuPriceId`                 | String   | Unique identifier for the SKU inclusive of additional pricing variations, like tiering and discounts.                                                                                          |
| `SubAccountId`               | String   | Unique identifier assigned to a grouping of resources or services, often used to manage access or cost.                                                                                        |
| `SubAccountName`             | String   | Name assigned to a grouping of resources or services, often used to manage access or cost.                                                                                                     |
| `SubAccountType`             | String   | Provider label for the kind of entity the SubAccountId represents.                                                                                                                             |
| `Tags`                       | JSON     | List of custom key-value pairs applied to a charge defined as a JSON object.                                                                                                                   |
| `UsageQuantity`              | Decimal  | Number of units of a resource or service that was used or purchased based on the UsageUnit.                                                                                                    |
| `UsageUnit`                  | String   | Indicates what measurement type is used by the UsageQuantity.                                                                                                                                  |
| `x_AccountName`              | String   | Name of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                     |
| `x_AccountOwnerId`           | String   | Email address of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                            |
| `x_BilledCostInUsd`          | Decimal  | BilledCost in USD.                                                                                                                                                                             |
| `x_BilledUnitPrice`          | Decimal  | Unit price for the SKU ... that a consumer would be charged per unit.                                                                                                                          |
| `x_BillingAccountId`         | String   | Unique identifier for the Microsoft billing account. Same as BillingAccountId for EA.                                                                                                          |
| `x_BillingAccountName`       | String   | Name of the Microsoft billing account. Same as BillingAccountName for EA.                                                                                                                      |
| `x_BillingExchangeRate`      | Decimal  | Exchange rate to multiply by when converting from the pricing currency to the billing currency.                                                                                                |
| `x_BillingExchangeRateDate`  | DateTime | Date the exchange rate was determined.                                                                                                                                                         |
| `x_BillingProfileId`         | String   | Unique identifier for the Microsoft billing profile. Same as BillingAccountId for MCA.                                                                                                         |
| `x_BillingProfileName`       | String   | Name of the Microsoft billing profile. Same as BillingAccountName for MCA.                                                                                                                     |
| `x_ChargeId`                 | String   | Not used.                                                                                                                                                                                      |
| `x_CostAllocationRuleName`   | String   | Name of the Microsoft Cost Management cost allocation rule that generated this charge. Cost allocation is used to move or split shared charges.                                                |
| `x_CostCenter`               | String   | Custom value defined by a billing admin for internal chargeback.                                                                                                                               |
| `x_CustomerId`               | String   | Unique identifier for the Cloud Solution Provider (CSP) customer tenant.                                                                                                                       |
| `x_CustomerName`             | String   | Display name for the Cloud Solution Provider (CSP) customer tenant.                                                                                                                            |
| `x_EffectiveCostInUsd`       | Decimal  | EffectiveCost in USD.                                                                                                                                                                          |
| `x_EffectiveUnitPrice`       | Decimal  | Unit price for the SKU inclusive of amortized upfront fees, amortized recurring fees, and the usage cost that a consumer would be charged per unit.                                            |
| `x_InvoiceId`                | String   | Unique identifier for the invoice this charge was billed on.                                                                                                                                   |
| `x_InvoiceIssuerId`          | String   | Unique identifier for the Cloud Solution Provider (CSP) partner.                                                                                                                               |
| `x_InvoiceSectionId`         | String   | Unique identifier for the MCA invoice section or EA department.                                                                                                                                |
| `x_InvoiceSectionName`       | String   | Display name for the MCA invoice section or EA department.                                                                                                                                     |
| `x_OnDemandCost`             | Decimal  | A charge inclusive of negotiated discounts that a consumer would be charged for each billing period.                                                                                           |
| `x_OnDemandCostInUsd`        | Decimal  | OnDemandCost in USD.                                                                                                                                                                           |
| `x_OnDemandUnitPrice`        | Decimal  | Unit price for the SKU after negotiated discounts that a consumer would be charged per unit.                                                                                                   |
| `x_PartnerCreditApplied`     | String   | Indicates when the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) was applied for a charge.                                                                                         |
| `x_PartnerCreditRate`        | String   | Rate earned based on the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) applied.                                                                                                    |
| `x_PricingBlockSize`         | Decimal  | Indicates the number of usage units grouped together for block pricing. This number is usually a part of the PricingUnit. Divide UsageQuantity by PricingBlockSize to get the PricingQuantity. |
| `x_PricingCurrency`          | String   | Currency used for all price columns.                                                                                                                                                           |
| `x_PricingSubcategory`       | String   | Describes the kind of pricing model used for a charge within a specific Pricing Category.                                                                                                      |
| `x_PricingUnitDescription`   | String   | Indicates what measurement type is used by the PricingQuantity, including pricing block size. This is what is used in the price list and/or on the invoice.                                    |
| `x_PublisherCategory`        | String   | Indicates whether a charge is from a cloud provider or third-party Marketplace vendor.                                                                                                         |
| `x_PublisherId`              | String   | Unique identifier of the entity that produced the resources and/or services that were purchased.                                                                                               |
| `x_ResellerId`               | String   | Unique identifier for the Cloud Solution Provider (CSP) reseller.                                                                                                                              |
| `x_ResellerName`             | String   | Name of the Cloud Solution Provider (CSP) reseller.                                                                                                                                            |
| `x_ResourceGroupName`        | String   | Grouping of resources that make up an application or set of resources that share the same lifecycle (e.g., created and deleted together).                                                      |
| `x_ResourceType`             | String   | Azure Resource Manager resource type.                                                                                                                                                          |
| `x_ServicePeriodEnd`         | DateTime | Exclusive end date of the service period applicable for the charge.                                                                                                                            |
| `x_ServicePeriodStart`       | DateTime | Start date of the service period applicable for the charge.                                                                                                                                    |
| `x_SkuDescription`           | String   | Description of the SKU that was used or purchased.                                                                                                                                             |
| `x_SkuDetails`               | JSON     | Additional information about the SKU. This column is formatted as a JSON object.                                                                                                               |
| `x_SkuIsCreditEligible`      | Boolean  | Indicates if the charge is eligible for Azure credits                                                                                                                                          |
| `x_SkuMeterCategory`         | String   | Name of the service the SKU falls within.                                                                                                                                                      |
| `x_SkuMeterId`               | String   | Unique identifier (sometimes a GUID, but not always) for the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price.                                     |
| `x_SkuMeterName`             | String   | Name of the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price. Not applicable for purchases.                                                        |
| `x_SkuMeterSubcategory`      | String   | Group of SKU Classes that address the same core need within the SKU Group.                                                                                                                     |
| `x_SkuOfferId`               | String   | Microsoft Cloud subscription type.                                                                                                                                                             |
| `x_SkuOrderId`               | String   | Unique identifier of the entitlement product for this charge. Same as MCA ProductOrderId. Not applicable for EA.                                                                               |
| `x_SkuOrderName`             | String   | Display name of the entitlement product for this charge. Same as MCA ProductOrderId. Not applicable for EA.                                                                                    |
| `x_SkuPartNumber`            | String   | Identifier to help break down specific usage meters.                                                                                                                                           |
| `x_SkuRegion`                | String   | Region that the SKU operated in. This may be different from the resource region.                                                                                                               |
| `x_SkuServiceFamily`         | String   | Highest-level classification of a SKU based on the core function of the SKU.                                                                                                                   |
| `x_SkuTerm`                  | Number   | Number of months a purchase covers.                                                                                                                                                            |
| `x_SkuTier`                  | String   | Pricing tier for the SKU when that SKU supports tiered or graduated pricing.                                                                                                                   |

<br>

## 🙋‍♀️ Feedback about FOCUS columns

<!-- markdownlint-disable-line --> {% include focus_feedback.md %}

<br>

## 🧐 See also

- [Microsoft Cost Management FOCUS dataset](https://learn.microsoft.com/azure/cost-management-billing/dataset-schema/cost-usage-details-focus)
- [Data dictionary](../../_resources/data-dictionary.md)
- [Generating a unique ID](../../_resources/data-dictionary.md#-generating-a-unique-id)
- [Known issues](../../_resources/data-dictionary.md#-known-issues)
- [Common terms](../../_resources/terms.md)

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
