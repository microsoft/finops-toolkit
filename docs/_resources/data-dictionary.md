---
layout: default
title: Data dictionary
nav_order: 20
description: "Column names you'll find in FinOps toolkit solutions."
permalink: /resources/data-dictionary
---

<span class="fs-9 d-block mb-4">Data dictionary</span>
Familiarize yourself with the columns used in FinOps hubs, Power BI, and PowerShell solutions.
{: .fs-6 .fw-300 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

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

See also:

- [Generating a unique ID](#%EF%B8%8F⃣-generating-a-unique-id)
- [Known issues](#%EF%B8%8F-known-issues)
- [What is FOCUS?](../_docs/focus/README.md)
- [How to convert Cost Management data to FOCUS](../_docs/focus/convert.md)
- [How to update existing reports to FOCUS](../_docs/focus/mapping.md)
- [Feedback about FOCUS columns](#%EF%B8%8F-feedback-about-focus-columns)
- [Common terms](./terms.md)
- [Cost Management data dictionary](https://learn.microsoft.com/azure/cost-management-billing/automate/understand-usage-details-fields)

</details>

---

Most of the columns in FinOps toolkit solutions originate in Cost Management or the FinOps Open Cost and Usage Specification (FOCUS). Below is a list of all columns you can expect to see in our solutions. For simplicity, the data dictionary does not include the `x_` prefix used to denote "external" or non-FOCUS columns, so `x_AccountName` is listed under `AccountName`.

<!--
Columns to add:
- BillingAccountType
- CommitmentDiscountType - Derived. Indicates what is being committed (i.e., `Usage`, `Spend`).
- CostRunningTotal
- CostVariance
- PartnerCreditAmount
-->

| Name                                              | Description                                                                                                                                                                                                                                                            |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="a"></a>AccountName                       | Name of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                             |
| AccountOwnerId                                    | Email address of the identity responsible for billing for this subscription. This is your EA enrollment account owner or MOSA account admin. Not applicable to MCA.                                                                                                    |
| AccountType                                       | Derived. Indicates the type of account. Allowed values: EA, MCA, MG, MOSA, MPA.                                                                                                                                                                                        |
| AvailabilityZone                                  | Area within a resource location used for high availability. Not available for all services. Not included in Microsoft Cloud cost data.                                                                                                                                 |
| <a name="b"></a>BilledCost                        | Amount owed for the charge after any applied discounts. If using FinOps hubs, you will need to include the Cost Management connector to see all billed costs. Maps to CostInBillingCurrency for actual cost in Cost Management.                                        |
| BilledCostInUsd                                   | BilledCost in USD.                                                                                                                                                                                                                                                     |
| BilledPricingCost                                 | BilledCost in the pricing currency.                                                                                                                                                                                                                                    |
| BillingAccountId                                  | Unique identifier for the billing account. "BillingAccount" columns map to the EA billing account and MCA billing profile. "x_BillingAccount" is the same as Cost Management.                                                                                          |
| BillingAccountName                                | Name of the billing account. "BillingAccount" columns map to the EA billing account and MCA billing profile. "x_BillingAccount" is the same as Cost Management.                                                                                                        |
| BillingCurrency                                   | Currency code for all price and cost columns.                                                                                                                                                                                                                          |
| BillingExchangeRate                               | Exchange rate to multiply by when converting from the pricing currency to the billing currency.                                                                                                                                                                        |
| BillingExchangeRateDate                           | Date the exchange rate was determined.                                                                                                                                                                                                                                 |
| BillingPeriodEnd                                  | Exclusive end date of the invoice period. Usually the first of the next month at midnight.                                                                                                                                                                             |
| BillingPeriodStart                                | First day of the invoice period. Usually the first of the month.                                                                                                                                                                                                       |
| BillingProfileId                                  | Unique identifier of the scope that invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                             |
| BillingProfileName                                | Name of the scope that invoices invoices are generated for. EA billing account or MCA billing profile.                                                                                                                                                                 |
| <a name="c"></a>CapacityCommitmentId              | Unique identifier of the capacity commitment, if applicable. Only available for virtual machines.                                                                                                                                                                      |
| ChargeCategory                                    | Indicates whether the row represents an upfront or recurring fee, cost of usage that already occurred, an after-the-fact adjustment (e.g., credits), or taxes. Allowed values: Usage, Purchase, Adjustment, Tax. Maps to ChargeType in Cost Management.                |
| ChargeDescription                                 | Brief, human-readable summary of a row.                                                                                                                                                                                                                                |
| ChargeFrequency                                   | Indicates how often a charge will occur. Allowed values: One-Time, Recurring, Usage-Based. Maps to **Frequency** in Cost Management.                                                                                                                                   |
| ChargeId                                          | Derived. Unique identifier (GUID) of the charge.                                                                                                                                                                                                                       |
| ChargePeriodEnd                                   | End date and time of a charge period.                                                                                                                                                                                                                                  |
| ChargePeriodStart                                 | Beginning date and time of a charge period. Maps to **Date** in Cost Management.                                                                                                                                                                                       |
| ChargeSubcategory                                 | Indicates the kind of usage or adjustment the row represents. Maps to **ChargeType** in Cost Management.                                                                                                                                                               |
| CommitmentDiscountKey                             | Derived. Unique key used to join with instance size flexibility data.                                                                                                                                                                                                  |
| CommitmentDiscountCategory                        | Derived. Indicates whether the commitment-based discount identified in the CommitmentDiscountId column is based on usage quantity or cost (aka "spend"). Allowed values: Usage, Spend.                                                                                 |
| CommitmentDiscountId                              | Unique identifier (GUID) of the commitment-based discount (e.g., reservation, savings plan) this resource utilized. Maps to **BenefitId** in Cost Management.                                                                                                          |
| CommitmentDiscountName                            | Name of the commitment-based discount (e.g., reservation, savings plan) this resource utilized. Maps to **BenefitName** in Cost Management.                                                                                                                            |
| CommitmentDiscountNameUnique                      | Derived. Unique name of the commitment (e.g., reservation, savings plan), including the ID for uniqueness.                                                                                                                                                             |
| CommitmentDiscountType                            | Derived. Label assigned by the provider to describe the type of commitment-based discount applied to the row. Allowed values: Reservation, Savings Plan.                                                                                                               |
| CommitmentCostSavings<sup>⚠️</sup>                 | Derived. Amount saved from commitment discounts only. Does not include savings from negotiated discounts. Formula: `x_OnDemandCost - EffectiveCost`.                                                                                                                   |
| CommitmentCostSavingsRunningTotal<sup>⚠️</sup>     | Derived. Calculates the accumulated or running total of CommitmentCostSavings for the day, including all previous day's values.                                                                                                                                        |
| CommitmentUnitPriceSavings<sup>⚠️</sup>            | Derived. Amount the unit price was reduced for commitment discounts. Does not include negotiated discounts. Formula: `x_OnDemandUnitPrice - x_EffectiveUnitPrice`.                                                                                                     |
| CommitmentUtilization                             | Derived. Calculates the commitment utilization percentage for the period. Calculated as the sum of CommitmentUtilizationAmount divided by the sum of CommitmentUtilizationPotential.                                                                                   |
| CommitmentUtilizationAmount                       | Derived. Amount of utilized commitment for the record, if the charge was associated with a commitment. Uses cost for savings plans and quantity for reservations.                                                                                                      |
| CommitmentUtilizationPotential                    | Derived. Amount that could have been applied to a commitment, but may not have been. This is generally the same as CommitmentUtilizationAmount, except for the unused charges. Uses cost for savings plans and quantity for reservations.                              |
| ConsumedService                                   | Azure Resource Manager resource provider namespace.                                                                                                                                                                                                                    |
| CostAllocationRuleName                            | Name of the Microsoft Cost Management cost allocation rule that generated this charge. Cost allocation is used to move or split shared charges.                                                                                                                        |
| CostCenter                                        | Custom value defined by a billing admin for internal chargeback.                                                                                                                                                                                                       |
| CustomerId                                        | Cloud Solution Provider (CSP) customer tenant ID.                                                                                                                                                                                                                      |
| CustomerName                                      | Cloud Solution Provider (CSP) customer tenant name.                                                                                                                                                                                                                    |
| <a name="d"></a>DataSet                           | Derived. Indicates which Cost Management data source the row was pulled from. Allowed values: Actual, Amortized.                                                                                                                                                       |
| DiscountCostSavings<sup>⚠️</sup>                   | Derived. Total amount saved after negotiated and commitment discounts are applied. Will be negative for unused commitments. Formula: `ListCost - EffectiveCost`.                                                                                                       |
| DiscountCostSavingsRunningTotal<sup>⚠️</sup>       | Derived. Calculates the accumulated or running total of DiscountCostSavings for the day, including all previous day's values.                                                                                                                                          |
| DiscountUnitPriceSavings<sup>⚠️</sup>              | Derived. Amount the unit price was discounted compared to public, list prices. If 0 when there are discounts, this means the list price and cost were not provided by Cost Management. Formula: `ListUnitPrice - x_EffectiveUnitPrice`.                                |
| <a name="e"></a>EffectiveCost                     | BilledCost with commitment purchases spread across the commitment term. See [Amortization](./terms.md#amortization). Maps to CostInBillingCurrency for amortized cost in Cost Management.                                                                              |
| EffectiveCostInUsd                                | EffectiveCost in USD.                                                                                                                                                                                                                                                  |
| EffectivePricingCost                              | EffectiveCost in the pricing currency.                                                                                                                                                                                                                                 |
| EffectiveUnitPrice                                | Amortized price per unit after commitment discounts.                                                                                                                                                                                                                   |
| <a name="i"></a>InvoiceId                         | Unique identifier for the invoice the charge is included in. Only available for closed months after the invoice is published.                                                                                                                                          |
| InvoiceIssuerId                                   | Unique identifier of the organization that generated the invoice.                                                                                                                                                                                                      |
| InvoiceIssuerName<sup>⚠️</sup>                     | Name of the organization that generated the invoice. Only supported for CSP accounts. Not supported for EA or MCA accounts that are managed by a partner due to data not being provided by Cost Management.                                                            |
| InvoiceSectionId                                  | Unique identifier (GUID) of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                       |
| InvoiceSectionName                                | Name of a section within an invoice used for grouping related charges. Represents an EA department. Not applicable for MOSA.                                                                                                                                           |
| IsCreditEligible                                  | Indicates if this charge can be deducted from credits. May be a string (`True` or `False` in legacy datasets). Maps to **IsAzureCreditEligible** in Cost Management.                                                                                                   |
| IsFree                                            | Derived. Indicates if this charge is free and has 0 `BilledCost` and 0 `EffectiveCost`. If the charge should not be free, please contact support as this is likely a inaccurate or incomplete data in Cost Management.                                                 |
| <a name="l"></a>ListCost<sup>⚠️</sup>              | Derived if not available. List (or retail) cost without any discounts applied.                                                                                                                                                                                         |
| ListCostInUsd<sup>⚠️</sup>                         | ListCost in USD.                                                                                                                                                                                                                                                       |
| ListUnitPrice<sup>⚠️</sup>                         | List (or retail) price per unit. If the same as OnDemandUnitPrice when there are discounts, this means list price and cost were not provided by Cost Management.                                                                                                       |
| <a name="m"></a>Month                             | Derived. Month of the charge.                                                                                                                                                                                                                                          |
| <a name="n"></a>NegotiatedCostSavings<sup>⚠️</sup> | Derived. Amount saved after negotiated discounts are applied but excluding commitment discounts. Formula: `ListCost - x_OnDemandCost`.                                                                                                                                 |
| NegotiatedCostSavingsRunningTotal<sup>⚠️</sup>     | Derived. Calculates the accumulated or running total of NegotiatedCostSavings for the day, including all previous day's values.                                                                                                                                        |
| NegotiatedUnitPriceSavings<sup>⚠️</sup>            | Derived. Amount the unit price was reduced after negotiated discounts were applied to public, list prices. Does not include commitment discounts. Formula: `ListUnitPrice - x_OnDemandUnitPrice`.                                                                      |
| <a name="o"></a>OnDemandCost<sup>⚠️</sup>          | Derived. Cost based on UnitPrice (with negotiated discounts applied, but without commitment discounts). Calculated as Quantity multiplied by UnitPrice.                                                                                                                |
| OnDemandUnitPrice<sup>⚠️</sup>                     | Derived. On-demand price per unit without any commitment discounts applied. If the same as EffectivePrice, this means EffectivePrice was not provided by Cost Management.                                                                                              |
| <a name="p"></a>PartnerCreditApplied              | Indicates when the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) was applied for a charge.                                                                                                                                                                 |
| PartnerCreditRate                                 | Rate earned based on the Cloud Solution Provider (CSP) Partner Earned Credit (PEC) applied.                                                                                                                                                                            |
| PartnerId                                         | Unique identifier of the Cloud Solution Provider (CSP) partner.                                                                                                                                                                                                        |
| PartnerName                                       | Name of the Cloud Solution Provider (CSP) partner.                                                                                                                                                                                                                     |
| PricingBlockSize                                  | Derived. Indicates what measurement type is used by the `PricingQuantity`. Extracted from **UnitOfMeasure** in Cost Management.                                                                                                                                        |
| PricingCategory<sup>⚠️</sup>                       | Describes the pricing model used for a charge at the time of use or purchase.                                                                                                                                                                                          |
| PricingCurrency                                   | Currency used for all price columns.                                                                                                                                                                                                                                   |
| PricingQuantity                                   | Derived. Amount of a particular service that was used or purchased based on the PricingUnit. `PricingQuantity` is the same as `UsageQuantity` divided by `x_PricingBlockSize`.                                                                                         |
| PricingSubcategory<sup>⚠️</sup>                    | Describes the kind of pricing model used for a charge within a specific `PricingCategory`.                                                                                                                                                                             |
| PricingUnit                                       | Derived. Indicates what measurement type is used by the `PricingQuantity`. Extracted from **UnitOfMeasure** in Cost Management.                                                                                                                                        |
| PricingUnitDescription                            | Describes the measurement type is used by the `PricingQuantity`. Maps to **UnitOfMeasure** in Cost Management.                                                                                                                                                         |
| PublisherId                                       | Unique identifier for the organization that created the product that was used or purchased.                                                                                                                                                                            |
| PublisherName                                     | Name of the organization that created the product that was used or purchased.                                                                                                                                                                                          |
| PublisherType                                     | Indicates whether a charge is from a cloud provider or third-party Marketplace vendor. Allowed values: Azure, AWS, Marketplace.                                                                                                                                        |
| <a name="r"></a>Region<sup>⚠️</sup>                | Isolated geographic area where a resource is provisioned in and/or a service is provided from.                                                                                                                                                                         |
| ResellerId                                        | Unique identifier for the Cloud Solution Provider (CSP) reseller. Maps to **ResellerMpnId** in Cost Management.                                                                                                                                                        |
| ResellerName                                      | Name of the Cloud Solution Provider (CSP) reseller.                                                                                                                                                                                                                    |
| ResourceGroupId                                   | Derived. Unique identifier for the `ResourceGroupName`.                                                                                                                                                                                                                |
| ResourceGroupName                                 | Grouping of resources that make up an application or set of resources that share the same lifecycle (e.g., created and deleted together).                                                                                                                              |
| ResourceGroupNameUnique                           | Derived. Unique name of the resource, including the subscription name for uniqueness.                                                                                                                                                                                  |
| ResourceId                                        | Unique identifier for the resource. May be empty for purchases.                                                                                                                                                                                                        |
| ResourceMachineName                               | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| ResourceName                                      | Name of the cloud resource. May be empty for purchases.                                                                                                                                                                                                                |
| ResourceNameUnique                                | Derived. Unique name of the resource, including the resource ID for uniqueness.                                                                                                                                                                                        |
| ResourceParentId                                  | Derived. Unique identifier for the logical resource parent as defined by the `cm-resource-parent`, `ms-resource-parent`, and `hidden-managedby` tags.                                                                                                                  |
| ResourceParentName                                | Derived. Name of logical resource parent (`ResourceParentId`).                                                                                                                                                                                                         |
| ResourceParentType                                | Derived. The kind of resource the logical resource parent (`ResourceParentId`) is. Uses the Azure Resource Manager resource type and not the display name.                                                                                                             |
| ResourceType                                      | The kind of resource for which you are being charged. "ResourceType" is a friendly display name. "x_ResourceType" is the Azure Resource Management resource ID.                                                                                                        |
| <a name="s"></a>SchemaVersion                     | Derived. Version of the Cost Management cost details schema that was detected during ingestion.                                                                                                                                                                        |
| ServiceCategory                                   | Top-level category for the `ServiceName`. This column aligns with the FOCUS requirements.                                                                                                                                                                              |
| ServiceName                                       | Name of the service the resource type is a part of. This column aligns with the FOCUS requirements.                                                                                                                                                                    |
| SkuCPUs                                           | Derived. Indicates the number of virtual CPUs used by this resource. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                             |
| SkuDetails                                        | Additional information about the SKU. This column is formatted as a JSON object. Maps to **AdditionalInfo** in Cost Management.                                                                                                                                        |
| SkuId                                             | Unique identifier for the product that was used or purchased. Maps to **ProductId** in Cost Management for MCA.                                                                                                                                                        |
| SkuImageType                                      | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SkuLicenseCPUs                                    | Derived. Indicates the number of virtual CPUs required from on-prem licenses required to use Azure Hybrid Benefit for this resource. Extracted from `x_SkuDetails`.                                                                                                    |
| SkuLicenseStatus                                  | Derived. Indicates whether the charge used or was eligible for Azure Hybrid Benefit. Extracted from `x_SkuDetails`.                                                                                                                                                    |
| SkuMeterCategory                                  | Represents a cloud service, like "Virtual machines" or "Storage".                                                                                                                                                                                                      |
| SkuMeterId                                        | Unique identifier (sometimes a GUID, but not always) for the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price.                                                                                                             |
| SkuMeterName                                      | Name of the usage meter. This usually maps to a specific SKU or range of SKUs that have a specific price. Not applicable for purchases.                                                                                                                                |
| SkuMeterRegion                                    | Geographical area associated with the price. If empty, the price for this charge is not based on region. Note this can be different from `Region`.                                                                                                                     |
| SkuMeterSubCategory                               | Groups service charges of a particular type. Sometimes used to represent a set of SKUs (e.g., VM series) or a different type of charge (e.g., table vs. file storage). Can be empty.                                                                                   |
| SkuName                                           | Product that was used or purchased.                                                                                                                                                                                                                                    |
| SkuOfferId                                        | Microsoft Cloud subscription type.                                                                                                                                                                                                                                     |
| SkuOrderId                                        | Maps to **ProductOrderId** in Cost Management.                                                                                                                                                                                                                         |
| SkuOrderName                                      | Maps to **ProductOrderName** in Cost Management.                                                                                                                                                                                                                       |
| SkuPartNumber                                     | Identifier to help break down specific usage meters.                                                                                                                                                                                                                   |
| SkuPlanName                                       | Represents the pricing plan or SKU.                                                                                                                                                                                                                                    |
| SkuPriceId                                        | Unique identifier for the product that was used or purchased inclusive of additional pricing variations, like tiering and discounts. Maps to **{ProductId}\_{SkuId}_{MeterType}** in the price sheet for MCA.                                                          |
| SkuServiceFamily                                  | Groups service charges based on the core function of the service. Can be used to track the migration of workloads across fundamentally different architectures, like IaaS and PaaS data storage. As of Feb 2023, there is a bug for EA where this is always "Compute". |
| SkuTerm                                           | Number of months a purchase covers. Only applicable to commitments today.                                                                                                                                                                                              |
| SkuTermLabel                                      | Derived. User-friendly display text for `x_SkuTerm`.                                                                                                                                                                                                                   |
| SkuType                                           | Derived. Extracted from `x_SkuDetails` and renamed from **ServiceType**. Used for Azure Hybrid Benefit reports.                                                                                                                                                        |
| SkuUsageType                                      | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SkuVMProperties                                   | Derived. Extracted from `x_SkuDetails`. Used for Azure Hybrid Benefit reports.                                                                                                                                                                                         |
| SubAccountId                                      | See SubscriptionId.                                                                                                                                                                                                                                                    |
| SubAccountName                                    | See SubscriptionName.                                                                                                                                                                                                                                                  |
| SubscriptionId                                    | Unique identifier (GUID) of the Microsoft Cloud subscription.                                                                                                                                                                                                          |
| SubscriptionName                                  | Name of the Microsoft Cloud subscription.                                                                                                                                                                                                                              |
| SubscriptionNameUnique                            | Derived. Unique name of the subscription, including the ID for uniqueness.                                                                                                                                                                                             |
| <a name="t"></a>Tags                              | Derived. Custom metadata (key/value pairs) applied to the resource or product the charge applies to. Formatted as a JavaScript object (JSON). Microsoft Cost Management has a bug where this is missing the outer braces, so that is fixed in Power Query.             |
| TagsDictionary                                    | Derived. Object version of `Tags`.                                                                                                                                                                                                                                     |
| ToolkitTool                                       | Derived. Name of the tool in the FinOps toolkit the resource supports.                                                                                                                                                                                                 |
| ToolkitVersion                                    | Derived. Version of the tool in the FinOps toolkit the resource supports.                                                                                                                                                                                              |
| <a name="u"></a>UsageCPUHours                     | Derived. Total vCPU hours used by this resource. Calculated as vCPUs multiplied by UsageQuantity. Used for Azure Hybrid Benefit reports.                                                                                                                               |
| UsageQuantity                                     | Number of units of a resource or service that was used or purchased based on the UsageUnit.                                                                                                                                                                            |
| UsageUnit                                         | Indicates what measurement type is used by the UsageQuantity.                                                                                                                                                                                                          |

<br>

## #️⃣ Generating a unique ID

<blockquote class="warning" markdown="1">
  _Microsoft Cost Management introduced a change in how data is processed that updates cost and usage data in a lower-latency, more streaming fashion. This means cost and usage data is available in Cost Management ~2 hours after the resource provider submits it into the billing pipeline and budget alerts are able to be triggered significantly faster. Unfortunately, this change may have also introduced cases where data can be split across multiple rows where the only difference is the quantity and cost. Based on this, a unique ID cannot be determined as of February 2, 2024. As of the time of this writing, the issue was just identified. Investigation is underway. If you experience this in your data, please raise a support request._
</blockquote>

Use the following columns in the Cost Management FOCUS dataset to generate a unique ID:

1. BillingAccountId
2. ChargePeriodStart
3. CommitmentDiscountId
4. Region
5. ResourceId
6. SkuPriceId
7. SubAccountId
8. Tags
9. x_AccountOwnerId
10. x_CostCenter
11. x_InvoiceSectionId
12. x_SkuDetails
13. x_SkuMeterId
14. x_SkuOfferId
15. x_SkuPartNumber

<br>

## ⚠️ Known issues

1. Price and cost columns can be 0 when the data is not available in Cost Management. This includes but may not be limited to:
   - `ListCost`
   - `ListUnitPrice`
   - `x_ListCostInUsd`
   - `x_OnDemandCost`
   - `x_OnDemandUnitPrice`
   - `x_EffectiveUnitPrice`
2. Due to missing and inaccurate price and cost columns, price and cost savings columns do not include all realized savings.
3. `InvoiceIssuerName` does not account for indirect EA and MCA partners. The value will show as "Microsoft".
4. `x_OnDemandUnitPrice` and `x_OnDemandCost` do not include the correct value in Cost Management exports.
   - This is a known issue and a fix is in progress.
5. `PricingCategory` shows "On-Demand" and `x_PricingSubcategory` shows "Standard" for unused commitment rows.
   - This is due to a transformation bug that was identified on March 3, 2024. A fix is in progress.
6. `x_PricingSubcategory` may show a value like "Committed /providers/Microsoft..." for historical data before February 28, 2024.
   - This is due to a formatting bug that was resolved on February 28, 2024. If you see these values, please re-export the cost data for that month. If you need to export data for an older month that is not available, please contact support to request the data be exported for you to resolve the data quality issue from the previous export runs.
7. `Region` can include values that are not regions, such as `Unassigned` and `Global`.
   - This is an underlying service issue and must be resolved by the service that is referencing invalid Azure locations in their usage data.
8. For the Cost Management connector, `PricingUnit` and `UsageUnit` both include the pricing block size. Exports (and FinOps hubs) separate the block size into `x_PricingBlockSize`.
9. For the Cost Management connector, `SkuPriceId` is not set due to the connector not having the data to populate the value.

<br>

## 🙋‍♀️ Feedback about FOCUS columns

<!-- markdownlint-disable-line --> {% include focus_feedback.md %}

<br>

---

## 🧰 Related tools

{% include tools.md bicep="0" data="1" gov="0" hubs="1" opt="0" pbi="1" ps="1" %}

<br>
