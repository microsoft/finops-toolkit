---
title: FinOps toolkit data dictionary
description: This article describes column names you'll find in FinOps toolkit solutions.
author: bandersmsft
ms.author: banders
ms.date: 10/17/2024
ms.topic: concept-article
ms.service: finops
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand the columns included in FinOps toolkit solutions.
---

<!-- markdownlint-disable-next-line MD025 -->
# FinOps toolkit data dictionary

This article describes column names you'll find in FinOps toolkit solutions.

[A](#a)
&nbsp; [B](#b)
&nbsp; [C](#c)
&nbsp; [D](#d)
&nbsp; [E](#e) <!-- &nbsp; [F](#f) &nbsp; [G](#g) &nbsp; [H](#h) -->
&nbsp; [I](#i) <!-- &nbsp; [J](#j) &nbsp; [K](#k) -->
&nbsp; [L](#l)
&nbsp; [M](#m)
&nbsp; [N](#n)
&nbsp; [O](#o)
&nbsp; [P](#p) <!-- &nbsp; [Q](#q) -->
&nbsp; [R](#r)
&nbsp; [S](#s)
&nbsp; [T](#t)
&nbsp; [U](#u) <!-- &nbsp; [V](#v) &nbsp; [W](#w) &nbsp; [X](#x) &nbsp; [Y](#y) &nbsp; [Z](#z) -->

Most of the columns in FinOps toolkit solutions originate in Cost Management or the FinOps Open Cost and Usage Specification (FOCUS). Below is a list of all columns you can expect to see in our solutions. For simplicity, the data dictionary does not include the `x_` prefix used to denote "external" or non-FOCUS columns, so `x_AccountName` is listed under `AccountName`.

<!--
Columns to add:
- BillingAccountType
- SubAccountType
-->

| Name                                     | Description                                                                                                                                                                                                                                                            |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="a"></a>AccountName              | Name of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                             |
| AccountOwnerId                           | Email address of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                    |
| AccountType                              | Derived. Indicates the type of account. Allowed values: EA, MCA, MG, MOSA, MPA.                                                                                                                                                                                        |
| AvailabilityZone                         | Area within a resource location used for high availability. Not available for all services. Not included in Microsoft Cloud cost data.                                                                                                                                 |
| <a name="b"></a>BilledCost               | Amount owed for the charge after any applied discounts. If using FinOps hubs, you will need to include the Cost Management connector to see all billed costs. Maps to CostInBillingCurrency for actual cost in Cost Management.                                        |
| BilledCostInUsd                          | BilledCost in USD.                                                                                                                                                                                                                                                     |
| BilledPricingCost                        | BilledCost in the pricing currency.                                                                                                                                                                                                                                    |
| BillingAccountId                         | Unique identifier for the billing account. "BillingAccount" columns map to the EA billing account and MCA billing profile. `x_BillingAccount` is the same as Cost Management.                                                                                          |
| BillingAccountName                       | Name of the billing account. "BillingAccount" columns map to the EA billing account and MCA billing profile. `x_BillingAccount` is the same as Cost Management.                                                                                                        |
| BillingAccountType                       | Indicates whether the `BillingAccountId` represents an EA billing account or MCA billing profile.                                                                                                                                                                      |
| BillingCurrency                          | Currency code for all price and cost columns.                                                                                                                                                                                                                          |
| BillingExchangeRate                      | Exchange rate to multiply by when converting from the pricing currency to the billing currency.                                                                                                                                                                        |
| BillingExchangeRateDate                  | Date the exchange rate was determined.                                                                                                                                                                                                                                 |
| BillingPeriodEnd                         | Exclusive end date of the invoice period. Usually the first of the next month at midnight.                                                                                                                                                                             |
| BillingPeriodStart                       | First day of the invoice period. Usually the first of the month.                                                                                                                                                                                                       |
| BillingProfileId                         | Unique identifier of the scope that invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                             |
| BillingProfileName                       | Name of the scope that invoices invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                                 |
| <a name="c"></a>CapacityCommitmentId     | Unique identifier of the capacity commitment, if applicable. Only available for virtual machines.                                                                                                                                                                      |
| ChargeCategory                           | Highest-level classification of a charge based on the nature of how it is billed. Allowed values: Usage, Purchase, Credit, Adjustment, Tax. Maps to ChargeType in Cost Management.                                                                                     |
| ChargeClass                              | Indicates whether the row represents a correction to one or more charges invoiced in a previous billing period. Allowed values: "Correction".                                                                                                                          |
| ChargeDescription                        | Brief, human-readable summary of a row.                                                                                                                                                                                                                                |
| ChargeFrequency                          | Indicates how often a charge will occur. Allowed values: One-Time, Recurring, Usage-Based. Maps to **Frequency** in Cost Management.                                                                                                                                   |
| ChargeId                                 | Derived. Unique identifier (GUID) of the charge.                                                                                                                                                                                                                       |
| ChargePeriodEnd                          | End date and time of a charge period.                                                                                                                                                                                                                                  |
| ChargePeriodStart                        | Beginning date and time of a charge period. Maps to **Date** in Cost Management.                                                                                                                                                                                       |
| ~ChargeSubcategory~ (removed)            | Indicates the kind of usage or adjustment the row represents. Maps to **ChargeType** in Cost Management. Deprecated with in v0.4 to align with FOCUS 1.0. Please use `ChargeCategory`, `ChargeClass`, or `CommitmentDiscountStatus`.                                   |
| CommitmentDiscountKey                    | Derived. Unique key used to join with instance size flexibility data.                                                                                                                                                                                                  |
| CommitmentDiscountCategory               | Derived. Indicates whether the commitment-based discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka "spend"). Allowed values: Usage, Spend.                                                                                 |
| CommitmentDiscountId                     | Unique identifier (GUID) of the commitment-based discount (e.g., reservation, savings plan) this resource utilized. Maps to **BenefitId** in Cost Management.                                                                                                          |
| CommitmentDiscountName                   | Name of the commitment-based discount (e.g., reservation, savings plan) this resource utilized. Maps to **BenefitName** in Cost Management.                                                                                                                            |
| CommitmentDiscountNameUnique             | Derived. Unique name of the commitment (e.g., reservation, savings plan), including the ID for uniqueness.                                                                                                                                                             |
| CommitmentDiscountStatus                 | Indicates whether the charge corresponds with the consumption of a commitment-based discount or the unused portion of the committed amount.                                                                                                                            |
| CommitmentDiscountType                   | Derived. Label assigned by the provider to describe the type of commitment-based discount applied to the row. Allowed values: Reservation, Savings Plan.                                                                                                               |
| CommitmentCostSavings¹                   | Derived. Amount saved from commitment discounts only. Does not include savings from negotiated discounts. Formula: `x_OnDemandCost - EffectiveCost`.                                                                                                                   |
| CommitmentCostSavingsRunningTotal¹       | Derived. Calculates the accumulated or running total of CommitmentCostSavings for the day, including all previous day's values.                                                                                                                                        |
| CommitmentUnitPriceSavings¹              | Derived. Amount the unit price was reduced for commitment discounts. Does not include negotiated discounts. Formula: `x_OnDemandUnitPrice - x_EffectiveUnitPrice`.                                                                                                     |
| CommitmentUtilization                    | Derived. Calculates the commitment utilization percentage for the period. Calculated as the sum of CommitmentUtilizationAmount divided by the sum of CommitmentUtilizationPotential.                                                                                   |
| CommitmentUtilizationAmount              | Derived. Amount of utilized commitment for the record, if the charge was associated with a commitment. Uses cost for savings plans and quantity for reservations.                                                                                                      |
| CommitmentUtilizationPotential           | Derived. Amount that could have been applied to a commitment, but may not have been. This is generally the same as CommitmentUtilizationAmount, except for the unused charges. Uses cost for savings plans and quantity for reservations.                              |
| ConsumedQuantity                         | Volume of a given SKU associated with a resource or service used, based on the Consumed Unit.                                                                                                                                                                          |
| ConsumedUnit                             | Provider-specified measurement unit indicating how a provider measures usage of a given SKU associated with a resource or service. Maps to **UnitOfMeasure** in Cost Management.                                                                                       |
| ConsumedService                          | Azure Resource Manager resource provider namespace.                                                                                                                                                                                                                    |
| ContractedCost¹                          | Cost calculated by multiplying contracted unit price and the corresponding Pricing Quantity.                                                                                                                                                                           |
| ContractedUnitPrice¹                     | The agreed-upon unit price for a single Pricing Unit of the associated SKU, inclusive of negotiated discounts, if present, while excluding negotiated commitment-based discounts or any other discounts.                                                               |
| CostAllocationRuleName                   | Name of the Microsoft Cost Management cost allocation rule that generated this charge. Cost allocation is used to move or split shared charges.                                                                                                                        |
| CostCenter                               | Custom value defined by a billing admin for internal chargeback.                                                                                                                                                                                                       |
| CustomerId                               | Cloud Solution Provider (CSP) customer tenant ID.                                                                                                                                                                                                                      |
| CustomerName                             | Cloud Solution Provider (CSP) customer tenant name.                                                                                                                                                                                                                    |
| <a name="d"></a>DatasetChanges           | Derived. List of codes that indicate changes made to this row to address data quality issues.                                                                                                                                                                          |
| DatasetType                              | Derived. Indicates the type of data exported from Cost Management. Allowed values: ActualCost, AmortizedCost, FocusCost, PriceSheet, ReservationDetails, ReservationRecommendations, ReservationTransactions.                                                          |
| DatasetVersion                           | Derived. Indicates the schema version of the dataset that was exported from Cost Management.                                                                                                                                                                           |
| DiscountCostSavings¹                     | Derived. Total amount saved after negotiated and commitment discounts are applied. Will be negative for unused commitments. Formula: `ListCost - EffectiveCost`.                                                                                                       |
| DiscountCostSavingsRunningTotal¹         | Derived. Calculates the accumulated or running total of DiscountCostSavings for the day, including all previous day's values.                                                                                                                                          |
| DiscountUnitPriceSavings¹                | Derived. Amount the unit price was discounted compared to public, list prices. If 0 when there are discounts, this means the list price and cost were not provided by Cost Management. Formula: `ListUnitPrice - x_EffectiveUnitPrice`.                                |
| <a name="e"></a>EffectiveCost            | BilledCost with commitment purchases spread across the commitment term. See [Amortization](../terms.md#amortization). Maps to CostInBillingCurrency for amortized cost in Cost Management.                                                                             |
| EffectiveCostInUsd                       | `EffectiveCost` in USD.                                                                                                                                                                                                                                                |
| EffectiveCostPerResource                 | Derived. `EffectiveCost` for each unique resource ID. This is a simple average. Formula = `SUM(EffectiveCost) / DCOUNT(ResourceId)`. This does not account for all free resources and may include nested, child resources or deleted resources.                        |
| EffectivePricingCost                     | `EffectiveCost` in the pricing currency.                                                                                                                                                                                                                               |
| EffectiveUnitPrice                       | Amortized price per unit after commitment discounts.                                                                                                                                                                                                                   |
| <a name="i"></a>IncrementalRefreshDate   | Derived. Numeric version of the `ChargePeriodStart` column to simplify setup for incremental refresh.                                                                                                                                                                  |
| InvoiceId                                | Unique identifier for the invoice the charge is included in. Only available for closed months after the invoice is published.                                                                                                                                          |
| InvoiceIssuerId                          | Unique identifier of the organization that generated the invoice.                                                                                                                                                                                                      |
| InvoiceIssuerName¹                       | Name of the organization that generated the invoice. Only supported for CSP accounts. Not supported for EA or MCA accounts that are managed by a partner due to data not being provided by Cost Management.                                                            |
| InvoiceSectionId                         | Unique identifier (GUID) of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                       |
| InvoiceSectionName                       | Name of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                                           |
| IsCreditEligible                         | Indicates if this charge can be deducted from credits. May be a string (`True` or `False` in legacy datasets). Maps to **IsAzureCreditEligible** in Cost Management.                                                                                                   |
| IsFree                                   | Derived. Indicates if this charge is free and has 0 `BilledCost` and 0 `EffectiveCost`. If the charge should not be free, please contact support as this is likely a inaccurate or incomplete data in Cost Management.                                                 |
| <a name="l"></a>ListCost¹                | Derived if not available. List (or retail) cost without any discounts applied.                                                                                                                                                                                         |
| ListCostInUsd¹                           | ListCost in USD.                                                                                                                                                                                                                                                       |
| ListUnitPrice¹                           | List (or retail) price per unit. If the same as OnDemandUnitPrice when there are discounts, this means list price and cost were not provided by Cost Management.                                                                                                       |
| <a name="m"></a>Month                    | Derived. Month of the charge.                                                                                                                                                                                                                                          |
| <a name="n"></a>NegotiatedCostSavings¹   | Derived. Amount saved after negotiated discounts are applied but excluding commitment discounts. Formula: `ListCost - ContractedCost`.                                                                                                                                 |
| NegotiatedCostSavingsRunningTotal¹       | Derived. Calculates the accumulated or running total of NegotiatedCostSavings for the day, including all previous day's values.                                                                                                                                        |
| NegotiatedUnitPriceSavings¹              | Derived. Amount the unit price was reduced after negotiated discounts were applied to public, list prices. Does not include commitment discounts. Formula: `ListUnitPrice - ContractedUnitPrice`.                                                                      |
| <a name="o"></a>~OnDemandCost~ (removed) | Derived. Cost based on UnitPrice (with negotiated discounts applied, but without commitment discounts). Calculated as Quantity multiplied by UnitPrice. Renamed to `ContractedCost` in v0.4 to align with FOCUS 1.0.                                                   |
| ~OnDemandUnitPrice~ (removed)            | Derived. On-demand price per unit without any commitment discounts applied. If the same as EffectivePrice, this means EffectivePrice was not provided by Cost Management. Renamed to `ContractedUnitPrice` in v0.4 to align with FOCUS 1.0.                            |
| <a name="p"></a>PartnerCreditApplied     | Indicates when the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) was applied for a charge.                                                                                                                                                                 |
| PartnerCreditRate                        | Rate earned based on the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) applied.                                                                                                                                                                            |
| PartnerId                                | Unique identifier of the Cloud Solution Provider (CSP) partner.                                                                                                                                                                                                        |
| PartnerName                              | Name of the Cloud Solution Provider (CSP) partner.                                                                                                                                                                                                                     |
| PricingBlockSize                         | Derived. Indicates what measurement type is used by the `PricingQuantity`. Extracted from **UnitOfMeasure** in Cost Management.                                                                                                                                        |
| PricingCategory¹                         | Describes the pricing model used for a charge at the time of use or purchase. Allowed values: "Standard", "Dynamic", "Committed".                                                                                                                                      |
| PricingCurrency                          | Currency used for all price columns.                                                                                                                                                                                                                                   |
| PricingQuantity                          | Derived. Amount of a particular service that was used or purchased based on the PricingUnit. `PricingQuantity` is the same as `UsageQuantity` divided by `x_PricingBlockSize`.                                                                                         |
| PricingSubcategory¹                      | Describes the kind of pricing model used for a charge within a specific `PricingCategory`.                                                                                                                                                                             |
| PricingUnit                              | Derived. Indicates what measurement type is used by the `PricingQuantity`. Extracted from **UnitOfMeasure** in Cost Management.                                                                                                                                        |
| PricingUnitDescription                   | Describes the measurement type is used by the `PricingQuantity`. Maps to **UnitOfMeasure** in Cost Management.                                                                                                                                                         |
| PublisherCategory                        | Indicates whether a charge is from a cloud provider or third-party Marketplace vendor. Allowed values: "Cloud Provider", "Vendor". Maps to PublisherType in Cost Management.                                                                                           |
| PublisherId                              | Unique identifier for the organization that created the product that was used or purchased.                                                                                                                                                                            |
| PublisherName                            | Name of the organization that created the product that was used or purchased.                                                                                                                                                                                          |
| <a name="r"></a>~Region~ (removed)       | Isolated geographic area where a resource is provisioned in and/or a service is provided from. Replaced with `RegionId` and `RegionName` in v0.4 to align with FOCUS 1.0.                                                                                              |
| RegionId¹                                | Provider-assigned identifier for an isolated geographic area where a resource is provisioned or a service is provided.                                                                                                                                                 |
| RegionName¹                              | Name of an isolated geographic area where a resource is provisioned or a service is provided.                                                                                                                                                                          |
| ResellerId                               | Unique identifier for the Cloud Solution Provider (CSP) reseller. Maps to **ResellerMpnId** in Cost Management.                                                                                                                                                        |
| ResellerName                             | Name of the Cloud Solution Provider (CSP) reseller.                                                                                                                                                                                                                    |
| ResourceGroupId                          | Derived. Unique identifier for the `ResourceGroupName`.                                                                                                                                                                                                                |
| ResourceGroupName                        | Grouping of resources that make up an application or set of resources that share the same lifecycle (e.g., created and deleted together).                                                                                                                              |
| ResourceGroupNameUnique                  | Derived. Unique name of the resource, including the subscription name for uniqueness.                                                                                                                                                                                  |
| ResourceId                               | Unique identifier for the resource. May be empty for purchases.                                                                                                                                                                                                        |
| ResourceMachineName                      | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| ResourceName                             | Name of the cloud resource. May be empty for purchases.                                                                                                                                                                                                                |
| ResourceNameUnique                       | Derived. Unique name of the resource, including the resource ID for uniqueness.                                                                                                                                                                                        |
| ResourceParentId                         | Derived. Unique identifier for the logical resource parent as defined by the `cm-resource-parent`, `ms-resource-parent`, and `hidden-managedby` tags.                                                                                                                  |
| ResourceParentName                       | Derived. Name of logical resource parent (`ResourceParentId`).                                                                                                                                                                                                         |
| ResourceParentType                       | Derived. The kind of resource the logical resource parent (`ResourceParentId`) is. Uses the Azure Resource Manager resource type and not the display name.                                                                                                             |
| ResourceType                             | The kind of resource for which you are being charged. `ResourceType` is a friendly display name. `x_ResourceType` is the Azure Resource Manager resource type code.                                                                                                    |
| <a name="s"></a>SchemaVersion            | Derived. Version of the Cost Management cost details schema that was detected during ingestion.                                                                                                                                                                        |
| ServiceCategory                          | Top-level category for the `ServiceName`. This column aligns with the FOCUS requirements.                                                                                                                                                                              |
| ServiceName                              | Name of the service the resource type is a part of. This column aligns with the FOCUS requirements.                                                                                                                                                                    |
| SkuCPUs                                  | Derived. Indicates the number of virtual CPUs used by this resource. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                             |
| SkuDetails                               | Additional information about the SKU. This column is formatted as a JSON object. Maps to **AdditionalInfo** in Cost Management.                                                                                                                                        |
| SkuId                                    | Unique identifier for the product that was used or purchased. Maps to **ProductId** in Cost Management for MCA.                                                                                                                                                        |
| SkuImageType                             | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SkuLicenseCPUs                           | Derived. Indicates the number of virtual CPUs required from on-prem licenses required to use Azure Hybrid Benefit for this resource. Extracted from `x_SkuDetails`.                                                                                                    |
| SkuLicenseStatus                         | Derived. Indicates whether the charge used or was eligible for Azure Hybrid Benefit. Extracted from `x_SkuDetails`.                                                                                                                                                    |
| SkuMeterCategory                         | Represents a cloud service, like "Virtual machines" or "Storage".                                                                                                                                                                                                      |
| SkuMeterId                               | Unique identifier (sometimes a GUID, but not always) for the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price.                                                                                                             |
| SkuMeterName                             | Name of the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price. Not applicable for purchases.                                                                                                                                |
| SkuMeterRegion                           | Geographical area associated with the price. If empty, the price for this charge is not based on region. Note this can be different from `RegionId` and `RegionName`.                                                                                                  |
| SkuMeterSubCategory                      | Groups service charges of a particular type. Sometimes used to represent a set of SKUs (e.g., VM series) or a different type of charge (e.g., table vs. file storage). Can be empty.                                                                                   |
| SkuName                                  | Product that was used or purchased.                                                                                                                                                                                                                                    |
| SkuOfferId                               | Microsoft Cloud subscription type.                                                                                                                                                                                                                                     |
| SkuOrderId                               | Maps to **ProductOrderId** in Cost Management.                                                                                                                                                                                                                         |
| SkuOrderName                             | Maps to **ProductOrderName** in Cost Management.                                                                                                                                                                                                                       |
| SkuPartNumber                            | Identifier to help break down specific usage meters.                                                                                                                                                                                                                   |
| SkuPlanName                              | Represents the pricing plan or SKU.                                                                                                                                                                                                                                    |
| SkuPriceId                               | Unique identifier for the product that was used or purchased inclusive of additional pricing variations, like tiering and discounts. Maps to **{ProductId}\_{SkuId}\_{MeterType}** in the price sheet for MCA.                                                         |
| SkuServiceFamily                         | Groups service charges based on the core function of the service. Can be used to track the migration of workloads across fundamentally different architectures, like IaaS and PaaS data storage. As of Feb 2023, there is a bug for EA where this is always "Compute". |
| SkuTerm                                  | Number of months a purchase covers. Only applicable to commitments today.                                                                                                                                                                                              |
| SkuTermLabel                             | Derived. User-friendly display text for `x_SkuTerm`.                                                                                                                                                                                                                   |
| SkuType                                  | Derived. Extracted from `x_SkuDetails` and renamed from **ServiceType**. Used for Azure Hybrid Benefit reports.                                                                                                                                                        |
| SkuUsageType                             | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SkuVMProperties                          | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SubAccountId                             | See SubscriptionId.                                                                                                                                                                                                                                                    |
| SubAccountName                           | See SubscriptionName.                                                                                                                                                                                                                                                  |
| SubAccountType                           | Indicates the type of `SubAccountId`. Always "Subscription" today.                                                                                                                                                                                                     |
| SubscriptionId                           | Unique identifier (GUID) of the Microsoft Cloud subscription.                                                                                                                                                                                                          |
| SubscriptionName                         | Name of the Microsoft Cloud subscription.                                                                                                                                                                                                                              |
| SubscriptionNameUnique                   | Derived. Unique name of the subscription, including the ID for uniqueness.                                                                                                                                                                                             |
| <a name="t"></a>Tags                     | Derived. Custom metadata (key/value pairs) applied to the resource or product the charge applies to. Formatted as a JavaScript object (JSON). Microsoft Cost Management has a bug where this is missing the outer braces, so that is fixed in Power Query.             |
| TagsDictionary                           | Derived. Object version of `Tags`.                                                                                                                                                                                                                                     |
| ToolkitTool                              | Derived. Name of the tool in the FinOps toolkit the resource supports.                                                                                                                                                                                                 |
| ToolkitVersion                           | Derived. Version of the tool in the FinOps toolkit the resource supports.                                                                                                                                                                                              |
| <a name="u"></a>UsageCPUHours            | Derived. Total vCPU hours used by this resource. Calculated as vCPUs multiplied by `UsageQuantity`. Used for Azure Hybrid Benefit reports.                                                                                                                             |
| UsageQuantity                            | Number of units of a resource or service that was used or purchased based on the `UsageUnit`. Replaced by `ConsumedQuantity` in v0.4 to align with FOCUS 1.0.                                                                                                          |
| UsageUnit                                | Indicates what measurement type is used by the `UsageQuantity`. Replaced by `ConsumedUnit` in v0.4 to align with FOCUS 1.0.                                                                                                                                            |

<sup>¹ See the [known issues](#known-issues) below for additional details about these columns.</sup>

<br>

## Generating a unique ID

Use the following columns in the Cost Management FOCUS dataset to generate a unique ID:

1. BillingAccountId
2. ChargePeriodStart
3. CommitmentDiscountId
4. RegionId
5. ResourceId
6. ResourceName
7. SkuPriceId
8. SubAccountId
9. Tags
10. x_AccountOwnerId
11. x_CostCenter
12. x_InvoiceSectionId
13. x_ResourceGroupName
14. x_SkuDetails
15. x_SkuMeterId
16. x_SkuOfferId
17. x_SkuPartNumber

<br>

## Known issues

1. Price and cost columns can be 0 when the data is not available in Cost Management. This includes but may not be limited to:
   - `ListCost`
   - `ListUnitPrice`
   - `x_ListCostInUsd`
   - `ContractedCost`
   - `ContractedUnitPrice`
   - `EffectiveCost`
   - `x_EffectiveUnitPrice`
2. Price and cost savings may be incomplete if not specified in Cost Management.
3. For the Cost Management connector, `PricingUnit` and `UsageUnit` both include the pricing block size. Exports (and FinOps hubs) separate the block size into `x_PricingBlockSize`.
4. For the Cost Management connector, `SkuPriceId` is not set due to the connector not having the data to populate the value.

> [!NOTE]
> If you notice any oddities in historical cost data obtained via Cost Management exports (including FinOps hubs), re-export cost data for the month in question before filing a support request.

<br>

## Feedback about FOCUS columns

If you have feedback about our mappings or about our full FOCUS support plans, start a thread in [FinOps toolkit discussions](https://aka.ms/ftk/discuss). If you believe you have a bug, [create an issue](https://aka.ms/ftk/ideas).

If you have feedback about FOCUS, [create an issue in the FOCUS repository](https://github.com/FinOps-Open-Cost-and-Usage-Spec/FOCUS_Spec/issues/new/choose). We also encourage you to consider contributing to the FOCUS project. The project is looking for more practitioners to help bring their experience to help guide efforts and make it the most useful spec it can be. To learn more about FOCUS or to contribute to the project, visit [focus.finops.org](https://focus.finops.org).

<br>

## Related content

Related resources:

- [Generating a unique ID](#generating-a-unique-id)
- [Known issues](#known-issues)
- [Feedback about FOCUS columns](#feedback-about-focus-columns)
- [Related content](#related-content)

Related FinOps capabilities:

- [Reporting and analytics](../../framework/understand/reporting.md)
- [Rate optimization](../../framework/optimize/rates.md)
- [Workload optimization](../../framework/optimize/workloads.md)
- [Cloud policy and governance](../../framework/manage/governance.md)

Related products:

- [Cost Management](/azure/cost-management-billing/costs/)
- [Azure Advisor](/azure/advisor/)
- [Azure Resource Graph](/azure/governance/resource-graph/)

Related solutions:

- [FinOps toolkit Power BI reports](../power-bi/reports.md)
- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [FinOps toolkit PowerShell module](../powershell/README.md)
- [Optimization engine](../optimization-engine/optimization-engine-overview.md)
- [FinOps toolkit open data](../open-data.md)

<br>
