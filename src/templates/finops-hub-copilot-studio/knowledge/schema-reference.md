# KQL column reference for Costs_v1_4()

This document lists all columns available in the `Costs_v1_4()` function in the FinOps Hub database.

**IMPORTANT: This is a SCHEMA REFERENCE for constructing KQL queries. Do NOT use values from this document to answer questions. Always EXECUTE a KQL query to get actual data.**

Based on FOCUS 1.4 (FinOps Open Cost and Usage Specification). Columns with `x_` prefix are Azure extensions.

## Time

| Column | Type | Usage |
|--------|------|-------|
| ChargePeriodStart | datetime | Primary time filter. Daily granularity. |
| ChargePeriodEnd | datetime | Exclusive end of charge period. |
| BillingPeriodStart | datetime | Always 1st of month. Calendar-month filtering. |
| BillingPeriodEnd | datetime | Exclusive end. Use `<` not `<=`. |

## Cost metrics

| Column | Type | Usage |
|--------|------|-------|
| EffectiveCost | real | DEFAULT metric. Amortized cost after all discounts. |
| BilledCost | real | Actual invoice amount. Cash flow / accounts payable. |
| ListCost | real | Full retail, no discounts. |
| ContractedCost | real | Negotiated rate, before commitment discounts. |

Relationship: `ListCost >= ContractedCost >= EffectiveCost` for discounted usage.

### When BilledCost and EffectiveCost diverge

| Scenario | BilledCost | EffectiveCost |
|----------|------------|---------------|
| On-demand usage (no discounts) | Same | Same |
| RI/SP covered usage | $0 | Daily amortized portion of prepayment |
| RI/SP unused portion | $0 | Daily amortized portion (waste) |
| RI/SP purchase (one-time) | Full purchase price | $0 (amortized to usage rows) |
| RI/SP purchase (monthly) | Monthly payment | $0 (amortized to usage rows) |

## Organization hierarchy

| Column | Type | Usage |
|--------|------|-------|
| BillingAccountId | string | Full ARM path of billing account. |
| BillingAccountName | string | Billing account display name. |
| BillingAccountType | string | e.g. "Billing Account". |
| BillingCurrency | string | Currency code (e.g. CAD, USD, EUR). |
| x_BillingAccountAgreement | string | Agreement type: "EA", "MCA", "MOSP". |
| x_BillingAccountId | string | Numeric billing account ID. |
| x_BillingAccountName | string | Numeric billing account display name (source value before FOCUS normalization). |
| x_BillingProfileId | string | MCA billing profile ID. Not used for EA. |
| x_BillingProfileName | string | MCA billing profile name. |
| x_AccountId | string | EA enrollment account ID. |
| x_AccountName | string | EA enrollment account name. |
| x_AccountOwnerId | string | Email of EA enrollment account owner. |
| x_CustomerId | string | CSP customer tenant ID. |
| x_CustomerName | string | CSP customer name. |
| SubAccountId | string | Subscription ARM path. |
| SubAccountName | string | Subscription display name. |
| SubAccountType | string | e.g. "Subscription". |
| x_ResourceGroupName | string | Azure resource group name. |
| x_CostCenter | string | Custom chargeback value from EA/MCA. |
| x_CostAllocationRuleName | string | Cost allocation rule name. |
| x_CostCategories | dynamic | Cost categories from allocation rules. |
| x_Project | string | Project label from allocation or tags. |
| AllocatedResourceId | string | (FOCUS 1.3+) ARM path of the resource the cost was allocated to, if split-allocated. Null for hubs today (no Cost Management source). |
| AllocatedResourceName | string | (FOCUS 1.3+) Display name of the allocated-to resource. Null for hubs today. |
| AllocatedMethodId | string | (FOCUS 1.3+) Identifier of the allocation method/rule applied. Null for hubs today. |
| AllocatedMethodDetails | dynamic | (FOCUS 1.3+) JSON metadata describing the allocation method. Null for hubs today. |
| AllocatedTags | dynamic | (FOCUS 1.3+) Tags associated with the allocation target (JSON). Null for hubs today. |

## Resource

| Column | Type | Usage |
|--------|------|-------|
| ResourceId | string | Globally unique ARM path. Use for grouping/joins. |
| ResourceName | string | Display only — NOT unique across subscriptions. |
| ResourceType | string | Friendly type (e.g. "Virtual machine"). |
| x_ResourceType | string | ARM type (e.g. "Microsoft.Compute/virtualMachines"). |
| x_InstanceID | string | Legacy CM resource ID. Prefer ResourceId. |

## Service hierarchy

Service hierarchy: ServiceCategory > ServiceSubcategory > ServiceName > x_SkuMeterCategory > x_SkuMeterSubcategory > SkuMeter. FOCUS levels (first 3) don't align 1:1 with Azure meter levels (last 3).

| Column | Type | Usage |
|--------|------|-------|
| ServiceCategory | string | FOCUS standard categories: AI and Machine Learning, Analytics, Business Applications, Compute, Containers, Databases, Developer Tools, Identity, Integration, Internet of Things, Management and Governance, Multicloud, Networking, Other, Security, Storage, Web. |
| ServiceSubcategory | string | FOCUS mid-level. Currently blank in Microsoft data. |
| ServiceName | string | FOCUS-mapped service name. |
| x_SkuMeterCategory | string | Best for service-level grouping. **Can be blank** — see below. |
| x_SkuMeterSubcategory | string | e.g. "Easv5 Series", "Standard SSD Managed Disks". |
| SkuMeter | string | Specific meter name. |
| x_SkuMeterId | string | Meter GUID. |
| ChargeDescription | string | Human-readable charge description. |
| x_ServiceCode | string | Internal Azure service code. |
| x_ServiceId | string | Internal Azure service ID. |
| x_ServiceModel | string | Deployment model: "IaaS", "PaaS", "SaaS". |

### Blank x_SkuMeterCategory — expected, not a data issue

| Charge type | Why blank |
|-------------|-----------|
| Savings Plan unused | SP is flexible, not tied to a specific service |
| Third-party vendor (`x_PublisherCategory == "Vendor"`) | Marketplace products lack Azure meter categorization |
| Azure Support | Account-level charge, no meter |

To handle in queries, use a synthetic category:

```kusto
| extend Category = iif(isempty(x_SkuMeterCategory),
    iif(x_PublisherCategory == "Vendor", strcat("Vendor: ", ServiceProviderName),
    iif(CommitmentDiscountStatus == "Unused" and CommitmentDiscountType == "Savings Plan", "Savings Plan Unused",
    iif(isnotempty(ServiceName), ServiceName,
    "Uncategorized"))),
    x_SkuMeterCategory)
```

## Commitment discounts

| Column | Type | Usage |
|--------|------|-------|
| CommitmentDiscountType | string | "Reservation" or "Savings Plan". |
| CommitmentDiscountStatus | string | "Used" or "Unused". |
| CommitmentDiscountCategory | string | "Usage" (reservations) or "Spend" (savings plans). |
| CommitmentDiscountId | string | ARM path of reservation or savings plan. |
| CommitmentDiscountName | string | Display name. |
| CommitmentDiscountQuantity | real | Committed quantity. |
| CommitmentDiscountUnit | string | Unit for CommitmentDiscountQuantity. |
| x_CommitmentDiscountSavings | real | Savings vs on-demand price for this row. |
| x_CommitmentDiscountPercent | real | Discount percentage vs on-demand. |
| x_CommitmentDiscountNormalizedRatio | real | Normalization factor across VM sizes. |
| x_CommitmentDiscountSpendEligibility | string | Savings Plan eligibility. |
| x_CommitmentDiscountUsageEligibility | string | Reservation eligibility. |
| x_CommitmentDiscountUtilizationAmount | real | Utilized amount. |
| x_CommitmentDiscountUtilizationPotential | real | Maximum potential utilization. |
| x_AmortizationClass | string | "Amortized Charge" or "Principal". |
| CommitmentProgramEligibilityDetails | dynamic | (FOCUS 1.4+) JSON metadata describing eligibility for provider commitment programs. Null for hubs today (no Cost Management source). |

## Contracts

| Column | Type | Usage |
|--------|------|-------|
| ContractApplied | dynamic | (FOCUS 1.3+) JSON array of contract commitments applied to this row. Null for hubs today (no Cost Management source). See `ContractCommitments()` for the referenced metadata — no data until a FOCUS 1.4 export ships. |
| ContractCommitmentBenefitCategory | string | (FOCUS 1.4+) Category of benefit granted by the contract commitment. Null for hubs today. |
| ContractCommitmentCreated | datetime | (FOCUS 1.4+) When the contract commitment was created. Null for hubs today. |
| ContractCommitmentDiscountPercentage | real | (FOCUS 1.4+) Discount percentage granted by the contract commitment. Null for hubs today. |
| ContractCommitmentDurationType | string | (FOCUS 1.4+) Duration type of the contract commitment (e.g. fixed, recurring). Null for hubs today. |
| ContractCommitmentFulfillmentInterval | string | (FOCUS 1.4+) Interval over which the commitment is fulfilled. Null for hubs today. |
| ContractCommitmentLastUpdated | datetime | (FOCUS 1.4+) When the contract commitment was last updated. Null for hubs today. |
| ContractCommitmentLifecycleStatus | string | (FOCUS 1.4+) Lifecycle status of the contract commitment. Null for hubs today. |
| ContractCommitmentModel | string | (FOCUS 1.4+) Commitment model (e.g. spend-based, usage-based). Null for hubs today. |
| ContractCommitmentOfferCategory | string | (FOCUS 1.4+) Offer category for the contract commitment. Null for hubs today. |
| ContractCommitmentPaymentInterval | string | (FOCUS 1.4+) Payment interval for the contract commitment. Null for hubs today. |
| ContractCommitmentPaymentModel | string | (FOCUS 1.4+) Payment model for the contract commitment. Null for hubs today. |
| ContractCommitmentPaymentUpfrontPercentage | real | (FOCUS 1.4+) Percentage of the contract commitment paid upfront. Null for hubs today. |

> All `ContractCommitment*` columns above are null for hubs today (no Cost Management source) and are duplicated as row-level fields per FOCUS 1.4. For full contract commitment metadata, use `ContractCommitments()` — no data until Microsoft Cost Management ships a FOCUS 1.4 export (not yet available).

## Capacity reservation

| Column | Type | Usage |
|--------|------|-------|
| CapacityReservationId | string | ARM path of capacity reservation. |
| CapacityReservationStatus | string | "Used" or "Unused". |

## Charge classification

| Column | Type | Usage |
|--------|------|-------|
| ChargeCategory | string | Usage, Purchase, Adjustment, Tax, Credit. |
| ChargeClass | string | Empty = normal. "Correction" = adjusts prior period. |
| ChargeFrequency | string | Usage-Based, Recurring, One-Time. |

## Pricing

| Column | Type | Usage |
|--------|------|-------|
| PricingCategory | string | Standard (on-demand), Committed, Dynamic (spot), Other. |
| x_PricingSubcategory | string | Standard, Tiered, Committed Usage, Committed Spend, Spot. |
| ConsumedQuantity | real | Amount consumed in ConsumedUnit. |
| ConsumedUnit | string | Unit of measure for ConsumedQuantity. |
| PricingQuantity | real | Quantity used for pricing. |
| PricingUnit | string | FOCUS-normalized unit. |
| PricingCurrency | string | Currency used for pricing. |
| ListUnitPrice | real | Published retail price per PricingUnit. |
| ContractedUnitPrice | real | Negotiated price per PricingUnit. |
| x_EffectiveUnitPrice | real | Actual unit price after all discounts. |
| x_BilledUnitPrice | real | Unit price on invoice. |
| x_PricingBlockSize | real | Block size for pricing. |
| x_PricingUnitDescription | string | Original CM unit description with block size. |

## Provider

| Column | Type | Usage |
|--------|------|-------|
| x_PublisherCategory | string | "Cloud Provider" (first-party) or "Vendor" (marketplace). |
| ServiceProviderName | string | Vendor that makes the service available (Marketplace publisher or Microsoft). Never null. Replaces the removed `PublisherName`/`ProviderName`. |
| HostProviderName | string | Infrastructure provider that hosts the resource. Always "Microsoft" for Cost Management data. Replaces the removed `ProviderName`. |
| x_PublisherId | string | Publisher as billed by. |
| InvoiceIssuerName | string | Entity that issued the invoice. |

> **Removed in FOCUS 1.4**: `ProviderName` and `PublisherName` no longer exist in `Costs_v1_4()`. Use `ServiceProviderName` and `HostProviderName` instead — see above. Original source values are preserved in `x_SourceValues` for auditing.

## Geography

| Column | Type | Usage |
|--------|------|-------|
| RegionId | string | e.g. "canadacentral". |
| RegionName | string | e.g. "Canada Central". |
| AvailabilityZone | string | Availability zone, if applicable. |
| x_SkuRegion | string | SKU region from CM. Different format than RegionId. |
| x_Location | string | Original location string (GCP source data). Blank for Azure. |

## Tags

| Column | Type | Usage |
|--------|------|-------|
| Tags | dynamic | JSON key-value pairs. Access: `Tags['env']`. |

## SKU details

| Column | Type | Usage |
|--------|------|-------|
| SkuId | string | FOCUS-normalized SKU identifier. |
| SkuPriceDetails | dynamic | FOCUS-normalized pricing metadata (JSON). |
| SkuPriceId | string | FOCUS-normalized price sheet identifier. |
| x_SkuDetails | dynamic | Original CM SKU metadata (JSON). |
| x_SkuTerm | int | Purchase term in months (e.g. 12, 36). |
| x_SkuTier | string | Pricing tier level. |
| x_SkuCoreCount | int | Number of vCPUs for compute SKUs. |
| x_SkuDescription | string | Human-readable SKU description. |
| x_SkuInstanceType | string | VM size (e.g. "Standard_E4as_v5"). |
| x_SkuIsCreditEligible | bool | Whether eligible for Azure credits. |
| x_SkuLicenseQuantity | int | Number of licenses included. |
| x_SkuLicenseStatus | string | License status. |
| x_SkuLicenseType | string | e.g. "Windows_Server", "RHEL". |
| x_SkuLicenseUnit | string | e.g. "vCPU", "Core". |
| x_SkuOfferId | string | Azure offer ID (e.g. "MS-AZR-0017P"). |
| x_SkuOperatingSystem | string | OS (e.g. "Windows", "Linux"). |
| x_SkuOrderId | string | Reservation/SP order ID. |
| x_SkuOrderName | string | Reservation/SP order name. |
| x_SkuPartNumber | string | Azure part number. |
| x_SkuPlanName | string | Marketplace plan name. |
| x_SkuServiceFamily | string | Service family (e.g. "Compute", "Storage"). |

## Invoice

| Column | Type | Usage |
|--------|------|-------|
| InvoiceId | string | FOCUS invoice identifier. |
| InvoiceDetailId | string | (FOCUS 1.4+) Identifier of the invoice line item associated with this row. Null for hubs today (no Cost Management source). Join to `InvoiceDetails()` — no data until a FOCUS 1.4 export ships. |
| x_InvoiceIssuerId | string | Invoice issuer ID. |
| x_InvoiceSectionId | string | MCA invoice section / EA department ID. |
| x_InvoiceSectionName | string | MCA invoice section / EA department name. |
| x_BillingExchangeRate | real | Exchange rate: PricingCurrency to BillingCurrency. |
| x_BillingExchangeRateDate | datetime | Date exchange rate was determined. |
| x_BillingItemCode | string | Internal billing line item code. |
| x_BillingItemName | string | Internal billing line item name. |

## USD equivalents

| Column | Type | Usage |
|--------|------|-------|
| x_BilledCostInUsd | real | BilledCost converted to USD. |
| x_EffectiveCostInUsd | real | EffectiveCost converted to USD. |
| x_ListCostInUsd | real | ListCost converted to USD. |
| x_ContractedCostInUsd | real | ContractedCost converted to USD. |

## Discounts and savings

| Column | Type | Usage |
|--------|------|-------|
| x_Credits | dynamic | Credit adjustments (JSON). |
| x_Discount | dynamic | Discount details (JSON). |
| x_NegotiatedDiscountPercent | real | EA/MCA negotiated discount percentage. |
| x_NegotiatedDiscountSavings | real | Savings from negotiated rates. |
| x_TotalDiscountPercent | real | Total discount % (negotiated + commitment). |
| x_TotalSavings | real | Total savings vs list price. |
| x_CurrencyConversionRate | real | Currency conversion rate. |

## Service period

| Column | Type | Usage |
|--------|------|-------|
| x_ServicePeriodStart | datetime | Start of service consumption period. |
| x_ServicePeriodEnd | datetime | End of service consumption period. |

## Partner

| Column | Type | Usage |
|--------|------|-------|
| x_ResellerId | string | CSP reseller tenant ID. |
| x_ResellerName | string | CSP reseller name. |
| x_PartnerCreditApplied | string | Whether partner earned credit was applied. |
| x_PartnerCreditRate | string | PEC discount rate. |
| x_OwnerAccountID | string | Account owner for CSP scenarios. |

## Commodity

| Column | Type | Usage |
|--------|------|-------|
| x_CommodityCode | string | Internal commodity code. |
| x_CommodityName | string | Internal commodity name. |
| x_ComponentName | string | Sub-resource component name. |
| x_ComponentType | string | Sub-resource component type. |
| x_SubproductName | string | Sub-product within the service. |

## Usage

| Column | Type | Usage |
|--------|------|-------|
| x_ConsumedCoreHours | real | Total vCPU-hours consumed (compute only). |
| x_CostType | string | Internal cost type classification. |
| x_Operation | string | Specific operation or API action. |
| x_UsageType | string | Internal usage type identifier. |

## Pipeline / ingestion

| Column | Type | Usage |
|--------|------|-------|
| x_ChargeId | string | Unique identifier for this charge row. |
| x_ExportTime | datetime | When data was exported from Cost Management. |
| x_IngestionTime | datetime | When data was ingested into FinOps Hub. |
| x_SourceName | string | Data source/export name. |
| x_SourceProvider | string | Data provider. |
| x_SourceType | string | Type of data source. |
| x_SourceVersion | string | Schema version of source data. |
| x_SourceChanges | string | Changes applied during ingestion. |
| x_SourceValues | dynamic | Original source values before transformation (JSON), including removed columns like `ProviderName`/`PublisherName`. |
