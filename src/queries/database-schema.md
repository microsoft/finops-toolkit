# FinOps Hubs Database Schema
#
# Version History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0     | 2025-05-16 | FinOps Toolkit Team | Initial comprehensive schema documentation |


_Last updated: May 16, 2025_

This document provides a comprehensive overview of the FinOps Hubs database schema, including managed datasets, key tables, KQL functions, and Power BI integration. The schema is based on the FinOps Open Cost and Usage Specification (FOCUS) and is designed for extensibility and compatibility across cloud providers.

## Table of Contents
- [Overview](#overview)
- [Managed Datasets](#managed-datasets)
  - [Costs](#costs-managed-dataset)
  - [CommitmentDiscountUsage](#commitmentdiscountusage-managed-dataset)
  - [Prices](#prices-managed-dataset)
  - [Recommendations](#recommendations-managed-dataset)
  - [Transactions](#transactions-managed-dataset)
- [Key Tables](#key-tables)
- [KQL Functions](#kql-functions)
- [Power BI Integration](#power-bi-integration)
- [Open Data Tables](#open-data-tables)
- [References](#references)

---

## Overview


FinOps Hubs are a platform for cost analytics, insights, and optimization. The core is a data pipeline that ingests, cleans, and normalizes data into a standardized data model built on FOCUS. The database is typically deployed on Azure Data Explorer (Kusto) and integrates with Power BI for reporting.

> **Important:**
> Always use the `CostsPlus` dataset as your primary entry point for analytics, reporting, and automation in the FinOps Hub. The `CostsPlus` view provides a normalized, enriched, and future-proof schema that includes all base cost data and toolkit enhancements. Using `CostsPlus` ensures you benefit from the latest schema updates, enrichment logic, and FinOps best practices.

- **Primary Database:** Hub (Azure Data Explorer)
- **Ingestion Database:** Ingestion (Azure Data Explorer)
- **Power BI:** Connects to Hub database functions and tables

---

## Managed Datasets

Each managed dataset consists of:
- A storage folder (e.g., `ingestion/Costs`)
- Raw, transform, and final tables/functions in the Ingestion database
- Versioned and unversioned functions in the Hub database
- Power BI table

### Costs Managed Dataset
- **Storage Folder:** ingestion/Costs
- **Ingestion DB:**
  - `Costs_raw` (raw data)
  - `Costs_transform_v1_0()` (transformation function)
  - `Costs_final_v1_0` (final table)
- **Hub DB:**
  - `Costs_v1_0()` (versioned function)
  - `Costs()` (unversioned function)
- **Power BI:** Costs table
- **Supported Clouds:** Microsoft, AWS, GCP, OCI (custom columns supported)

### CommitmentDiscountUsage Managed Dataset
- **Storage Folder:** ingestion/CommitmentDiscountUsage
- **Ingestion DB:**
  - `CommitmentDiscountUsage_raw`
  - `CommitmentDiscountUsage_transform_v1_0()`
  - `CommitmentDiscountUsage_final_v1_0`
- **Hub DB:**
  - `CommitmentDiscountUsage_v1_0()`
  - `CommitmentDiscountUsage()`
- **Power BI:** CommitmentDiscountUsage table
- **Supported:** Microsoft Cost Management reservation details (EA, MCA)

### Prices Managed Dataset
- **Storage Folder:** ingestion/Prices
- **Ingestion DB:**
  - `Prices_raw`
  - `Prices_transform_v1_0()`
  - `Prices_final_v1_0`
- **Hub DB:**
  - `Prices_v1_0()`
  - `Prices()`
- **Power BI:** Prices table
- **Supported:** Microsoft Cost Management export schemas (EA, MCA)

### Recommendations Managed Dataset
- **Storage Folder:** ingestion/Recommendations
- **Ingestion DB:**
  - `Recommendations_raw`
  - `Recommendations_transform_v1_0()`
  - `Recommendations_final_v1_0`
- **Hub DB:**
  - `Recommendations_v1_0()`
  - `Recommendations()`
- **Power BI:** Recommendations table
- **Supported:** Microsoft Cost Management reservation recommendations (EA, MCA)

### Transactions Managed Dataset
- **Storage Folder:** ingestion/Transactions
- **Ingestion DB:**
  - `Transactions_raw`
  - `Transactions_transform_v1_0()`
  - `Transactions_final_v1_0`
- **Hub DB:**
  - `Transactions_v1_0()`
  - `Transactions()`
- **Power BI:** Transactions table
- **Supported:** Microsoft Cost Management reservation transactions (EA, MCA)

---

## Key Tables

The following tables are available in Power BI and/or Data Explorer:

- **HubScopes**: Summarizes ingested scopes
- **HubSettings**: Configuration settings for the hub instance
- **PricingUnits**: Normalizes prices ([open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#pricing-units))
- **Regions**: Region normalization ([open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#regions))
- **ReservationRecommendations**: Filtered from Recommendations
- **ResourceTypes**: Resource type normalization ([open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#resource-types))
- **Services**: Service normalization ([open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#services))


---

## KQL Functions

The following KQL functions are available in the Hub database for querying and reporting:

- **arraystring(arr: dynamic)**: Returns comma-delimited string for array elements
- **datestring(start: datetime, [end: datetime])**: Formats date or date range
- **delta(oldValue: double, newValue: double)**: Percentage change between values
- **deltastring(oldValue: double, newValue: double, [places: int], [useArrows: bool])**: Percentage difference as string
- **diffstring(oldValue: double, newValue: double, [places: int])**: Difference as string
- **ifempty(value: dynamic, defaultValue: dynamic)**: Returns default if value is empty
- **monthstring(date: datetime, [length: int])**: Returns month name
- **numberstring(num: double, [abbrev: bool])**: Formats number (e.g., 1.23K)
- **parse_resourceid(resourceId: string)**: Parses Azure resource ID
- **percent(table: (Count: long))**: Calculates percent of total
- **percentOfTotal(table: (Count: long), total: long)**: Adds Percent column
- **percentstring(num: double, [total: double], [places: int])**: Formats as percent string
- **plusminus(val: string)**: Adds +/- sign
- **resource_type(resourceType: string)**: Returns resource type details
- **updown(value: string)**: Returns up/down arrow

---


## Open Data Tables

Several tables are populated from open data files to support normalization and cleansing:
- **PricingUnits**: [Pricing units open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#pricing-units)
- **Regions**: [Regions open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#regions)
- **ResourceTypes**: [Resource types open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#resource-types)
- **Services**: [Services open data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data#services)

---

## References
- [FinOps Hubs Data Model Documentation](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/data-model)
- [FinOps Toolkit Open Data](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data)
- [How data is processed in FinOps hubs](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/data-processing)

---

For the latest schema and updates, always refer to the [official documentation](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/data-model).

---

## FinOps Hub Database Schema
The FinOps Hub database schema is designed to be extensible and compatible with multiple cloud providers. The core schema is based on the FinOps Open Cost and Usage Specification (FOCUS) and includes managed datasets for cost and usage data, commitment discounts, prices, recommendations, and transactions.

### CostsPlus Query

The `CostsPlus` query is an extensible, normalized view over the `Costs` managed dataset, providing enriched, FinOps-ready cost and usage data. It is implemented in [`src/queries/costsplus.kql`](costsplus.kql) and is the recommended entry point for analytics, reporting, and automation.

---


## Time Range Filters

Add these `let` statements to your KQL script under the `CostsPlus` query to filter the dataset by time range.

### CostsThisMonth
**Description:** Filter to current month.

```kusto
let CostsThisMonth = CostsPlus
  | where startofmonth(BillingPeriodStart) == startofmonth(now());
```


### CostsLastMonth
**Description:** Filter to previous month.

```kusto
let CostsLastMonth = CostsPlus
  | where startofmonth(BillingPeriodStart) == startofmonth(startofmonth(now()) - 1d);
```

### CostsByMonth
**Description:** Summarize by month.

```kusto
let CostsByMonth = CostsPlus
  | where startofmonth(ChargePeriodStart) >= startofmonth(now(), -numberOfMonths)
  | extend ChargePeriodStart = startofmonth(ChargePeriodStart)
  | extend BillingPeriodStart = startofmonth(BillingPeriodStart);
```

### CostsByDay
**Description:** Summarize by day.

```kusto
let CostsByDay = CostsPlus
  | where ChargePeriodStart >= ago(numberOfDays * 1d) - 1d and ChargePeriodStart < ago(1d)
  | extend ChargePeriodStart = startofday(ChargePeriodStart);
```

### CostsByDayAHB
**Description:** Azure Hybrid Benefit details.

```kusto
let CostsByDayAHB = CostsPlus;
```

### Combined Output Schema

The following table lists all columns output by the `CostsPlus` query, including both the base `Costs` table and all enrichment columns, sorted alphabetically. The `Source` column indicates whether a field is from the FOCUS standard, toolkit enrichment, or cloud-specific/custom. The `Example` column provides a sample value for complex or ambiguous fields.

| Dataset Name| Column Name | Type | Source | Example | Description |
|--------------|--------|------|--------|---------|-------------|
| CostsPlus    | AccountName | string | FOCUS | "Contoso-Prod-Sub" | Account name (cloud provider account/subscription) |
| CostsPlus    | AccountOwnerId | string | FOCUS | "user@contoso.com" | Account owner ID |
| CostsPlus    | AccountType | string | FOCUS | "Subscription" | Account type (e.g., Subscription, Billing Account) |
| CostsPlus    | BillingCurrency | string | FOCUS | "USD" | Billing currency code |
| CostsPlus    | BillingPeriodEnd | datetime | FOCUS | 2025-05-01 | End of the billing period |
| CostsPlus    | BillingPeriodStart | datetime | FOCUS | 2025-04-01 | Start of the billing period |
| CostsPlus    | ChargeCategory | string | FOCUS | "Usage" | Charge category (e.g., Usage, Purchase, Refund) |
| CostsPlus    | ChargePeriodEnd | datetime | FOCUS | 2025-05-01 | End of the charge period |
| CostsPlus    | ChargePeriodStart | datetime | FOCUS | 2025-04-01 | Start of the charge period (month, day, or hour granularity) |
| CostsPlus    | CommitmentDiscountCategory | string | FOCUS | "Reserved Instance" | Commitment discount category |
| CostsPlus    | CommitmentDiscountCurrency | string | FOCUS | "USD" | Currency for commitment discount |
| CostsPlus    | CommitmentDiscountId | string | FOCUS | "ri-1234" | Commitment discount ID |
| CostsPlus    | CommitmentDiscountName | string | FOCUS | "RI-VMs-EastUS" | Commitment discount name |
| CostsPlus    | CommitmentDiscountNameUnique | string | Toolkit | "RI-VMs-EastUS (Reserved Instance)" | Unique commitment discount name (with type) |
| CostsPlus    | CommitmentDiscountPercent | real | Toolkit | 0.25 | Percent savings from commitment discount |
| CostsPlus    | CommitmentDiscountRegion | string | FOCUS | "eastus" | Region for commitment discount |
| CostsPlus    | CommitmentDiscountResourceId | string | FOCUS | "/subscriptions/..." | Resource ID for commitment discount |
| CostsPlus    | CommitmentDiscountResourceType | string | FOCUS | "Microsoft.Compute/virtualMachines" | Resource type for commitment discount |
| CostsPlus    | CommitmentDiscountSavings | real | Toolkit | 100.00 | Savings from commitment discount |
| CostsPlus    | CommitmentDiscountScope | string | FOCUS | "Shared" | Scope of commitment discount |
| CostsPlus    | CommitmentDiscountStart | datetime | FOCUS | 2025-04-01 | Start date of commitment discount |
| CostsPlus    | CommitmentDiscountStatus | string | FOCUS | "Used" | Status of commitment discount (e.g., Used, Unused) |
| CostsPlus    | CommitmentDiscountTerm | int | FOCUS | 12 | Term of commitment discount (months) |
| CostsPlus    | CommitmentDiscountType | string | FOCUS | "Reserved Instance" | Type of commitment discount (e.g., Reserved Instance, Savings Plan) |
| CostsPlus    | CommitmentDiscountUnit | string | FOCUS | "hours" | Unit of commitment discount (e.g., hours, cores) |
| CostsPlus    | CommitmentDiscountUnitPrice | real | FOCUS | 0.05 | Unit price for commitment discount |
| CostsPlus    | CommitmentDiscountUtilizationAmount | real | Toolkit | 100 | Actual utilization for commitment discount |
| CostsPlus    | CommitmentDiscountUtilizationPotential | real | Toolkit | 120 | Potential utilization for commitment discount |
| CostsPlus    | ConsumedQuantity | real | FOCUS | 720 | Quantity consumed (usage) |
| CostsPlus    | ContractedCost | real | FOCUS | 900.00 | Contracted cost (after negotiated discounts) |
| CostsPlus    | ContractedUnitPrice | real | FOCUS | 0.10 | Contracted unit price |
| CostsPlus    | CostCenter | string | FOCUS | "CC-123" | Cost center (from tags or provider) |
| CostsPlus    | Currency | string | FOCUS | "USD" | Currency code |
| CostsPlus    | DepartmentId | string | FOCUS | "DPT-001" | Department ID |
| CostsPlus    | DepartmentName | string | FOCUS | "Engineering" | Department name |
| CostsPlus    | EffectiveCost | real | FOCUS | 800.00 | Effective cost after all discounts |
| CostsPlus    | InvoiceSection | string | FOCUS | "SectionA" | Invoice section |
| CostsPlus    | InvoiceSectionId | string | FOCUS | "SEC-001" | Invoice section ID |
| CostsPlus    | IsForecast | bool | Toolkit | false | True if row is a forecasted cost |
| CostsPlus    | IsProrated | bool | Toolkit | true | True if cost is prorated |
| CostsPlus    | ListCost | real | FOCUS | 1000.00 | List price cost (before discounts) |
| CostsPlus    | ListUnitPrice | real | FOCUS | 0.12 | List unit price |
| CostsPlus    | MeterCategory | string | FOCUS | "Compute" | Meter category (e.g., Compute, Storage) |
| CostsPlus    | MeterId | string | FOCUS | "meter-123" | Meter ID |
| CostsPlus    | MeterName | string | FOCUS | "D2_v3" | Meter name |
| CostsPlus    | MeterRegion | string | FOCUS | "eastus" | Meter region |
| CostsPlus    | MeterSubcategory | string | FOCUS | "Standard" | Meter subcategory |
| CostsPlus    | NegotiatedDiscountPercent | real | Toolkit | 0.10 | Percent savings from negotiated discount |
| CostsPlus    | NegotiatedDiscountSavings | real | Toolkit | 50.00 | Savings from negotiated discount |
| CostsPlus    | PricingCategory | string | FOCUS | "Pay-As-You-Go" | Pricing category (e.g., Committed, Pay-As-You-Go) |
| CostsPlus    | PricingQuantity | real | FOCUS | 720 | Pricing quantity |
| CostsPlus    | Product | string | FOCUS | "Virtual Machines" | Product name |
| CostsPlus    | ProductId | string | FOCUS | "prod-001" | Product ID |
| CostsPlus    | ProductOrderId | string | FOCUS | "order-001" | Product order ID |
| CostsPlus    | ProductOrderName | string | FOCUS | "VM Order" | Product order name |
| CostsPlus    | ProviderName | string | FOCUS | "Microsoft" | Cloud provider name (e.g., Microsoft, AWS, GCP, OCI) |
| CostsPlus    | PublisherId | string | Toolkit | "pub-001" | Publisher ID (cloud-specific, may not be present for all providers) |
| CostsPlus    | PublisherType | string | Toolkit | "FirstParty" | Publisher type (cloud-specific, may not be present for all providers) |
| CostsPlus    | ResourceId | string | FOCUS | "/subscriptions/..." | Resource ID |
| CostsPlus    | ResourceLocation | string | Toolkit | "eastus" | Resource location/region (may be cloud-specific) |
| CostsPlus    | ResourceName | string | FOCUS | "vm-prod-01" | Resource name |
| CostsPlus    | ResourceNameUnique | string | Toolkit | "vm-prod-01 (Microsoft.Compute/virtualMachines)" | Unique resource name (with type) |
| CostsPlus    | ServiceFamily | string | FOCUS | "Compute" | Service family (e.g., Compute, Storage) |
| CostsPlus    | ServiceName | string | FOCUS | "Virtual Machines" | Service name |
| CostsPlus    | ServiceTier | string | FOCUS | "Standard" | Service tier/level |
| CostsPlus    | ServiceType | string | FOCUS | "IaaS" | Service type |
| CostsPlus    | SubAccountId | string | FOCUS | "sub-001" | Subaccount ID |
| CostsPlus    | SubAccountName | string | FOCUS | "Contoso Subaccount" | Subaccount name |
| CostsPlus    | SubAccountNameUnique | string | Toolkit | "Contoso Subaccount (sub-001)" | Unique subaccount name (with ID) |
| CostsPlus    | x_AmortizationCategory | string | Toolkit | "Amortized Charge" | Amortization category for the charge (e.g., Principal, Amortized Charge) |
| CostsPlus    | x_CapacityReservationId | string | Toolkit | "cr-1234" | Capacity reservation ID (cloud-specific) |
| CostsPlus    | x_ChargeMonth | datetime | Toolkit | 2025-04-01 | Start of the charge month |
| CostsPlus    | x_CommitmentDiscountKey | string | Toolkit | "IaaS12345" | Unique key for commitment discount utilization |
| CostsPlus    | x_ConsumedCoreHours | real | Toolkit | 720 | Consumed core hours (if applicable) |
| CostsPlus    | x_FreeReason | string | Toolkit | "Trial" | Reason why cost is zero (e.g., Trial, Preview, Low Usage, No Usage) |
| CostsPlus    | x_ResourceGroupNameUnique | string | Toolkit | "rg-prod (Contoso Subaccount)" | Unique resource group name (with subaccount) |
| CostsPlus    | x_ResourceParentId | string | Toolkit | "/subscriptions/..." | Parent resource ID (if available) |
| CostsPlus    | x_ResourceParentName | string | Toolkit | "contoso-parent" | Parent resource name (if available) |
| CostsPlus    | BilledCost | real | FOCUS | 800.00 | A charge serving as the basis for invoicing, inclusive of all reduced rates and discounts while excluding the amortization of upfront charges (one-time or recurring). |
| CostsPlus    | BillingAccountType | string | FOCUS | "MCA" | Provider label for the kind of entity the BillingAccountId represents. |
| CostsPlus    | ChargeClass | string | FOCUS | "Regular" | Correction/regular charge indicator. |
| CostsPlus    | ChargeDescription | string | FOCUS | "Compute usage for VM" | Description of the charge. |
| CostsPlus    | ChargeFrequency | string | FOCUS | "Monthly" | How often a charge occurs. |
| CostsPlus    | ConsumedUnit | string | FOCUS | "Hours" | Unit for ConsumedQuantity. |
| CostsPlus    | InvoiceIssuerName | string | FOCUS | "Microsoft" | Name of the entity responsible for invoicing. |
| CostsPlus    | PricingUnit | string | FOCUS | "Hours" | Unit for PricingQuantity. |
| CostsPlus    | RegionId | string | FOCUS | "eastus" | Region identifier. |
| CostsPlus    | RegionName | string | FOCUS | "East US" | Region name. |
| CostsPlus    | ServiceCategory | string | FOCUS | "Compute" | High-level service category. |
| CostsPlus    | SkuId | string | FOCUS | "D2_v3" | SKU identifier. |
| CostsPlus    | SkuPriceId | string | FOCUS | "D2_v3-123" | SKU price identifier. |
| CostsPlus    | SubAccountType | string | FOCUS | "Subscription" | Type of subaccount. |
| CostsPlus    | Tags | json | FOCUS | {"env":"prod"} | Tags as a JSON object. |
| CostsPlus    | x_AccountId | string | FOCUS | "acc-001" | Unique identifier for the identity responsible for billing for the subscription. |
| CostsPlus    | x_AccountName | string | FOCUS | "Contoso Account" | Name of the identity responsible for billing for this subscription. |
| CostsPlus    | x_AccountOwnerId | string | FOCUS | "owner@contoso.com" | Email address of the identity responsible for billing for this subscription. |
| CostsPlus    | x_BilledCostInUsd | real | FOCUS | 800.00 | BilledCost in USD. |
| CostsPlus    | x_BilledUnitPrice | real | FOCUS | 1.11 | Unit price for a single Pricing Unit of the associated SKU that was charged per unit. |
| CostsPlus    | x_BillingAccountId | string | FOCUS | "123456" | Unique identifier for the Microsoft billing account. Same as BillingAccountId for EA. |
| CostsPlus    | x_BillingAccountName | string | FOCUS | "Contoso Billing" | Name of the Microsoft billing account. Same as BillingAccountName for EA. |
| CostsPlus    | x_BillingExchangeRate | real | FOCUS | 1.0 | Exchange rate to multiply by when converting from the pricing currency to the billing currency. |
| CostsPlus    | x_BillingExchangeRateDate | datetime | FOCUS | 2025-04-01 | Date the exchange rate was determined. |
| CostsPlus    | x_BillingProfileId | string | FOCUS | "bp-001" | Unique identifier for the Microsoft billing profile. Same as BillingAccountId for MCA. |
| CostsPlus    | x_BillingProfileName | string | FOCUS | "Contoso Billing Profile" | Name of the Microsoft billing profile. Same as BillingAccountName for MCA. |
| CostsPlus    | x_ContractedCostInUsd | real | FOCUS | 900.00 | ContractedCost in USD. |
| CostsPlus    | x_CostAllocationRuleName | string | FOCUS | "SharedInfra" | Name of the Microsoft Cost Management cost allocation rule that generated this charge. |
| CostsPlus    | x_CostCenter | string | FOCUS | "CC-123" | Custom value defined by a billing admin for internal chargeback. |
| CostsPlus    | x_CustomerId | string | FOCUS | "cust-001" | Unique identifier for the Cloud Solution Provider (CSP) customer tenant. |
| CostsPlus    | x_CustomerName | string | FOCUS | "Contoso CSP Customer" | Display name for the Cloud Solution Provider (CSP) customer tenant. |
| CostsPlus    | x_EffectiveCostInUsd | real | FOCUS | 800.00 | EffectiveCost in USD. |
| CostsPlus    | x_EffectiveUnitPrice | real | FOCUS | 1.00 | Unit price for a single Pricing Unit of the associated SKU after all discounts. |
| CostsPlus    | x_InvoiceId | string | FOCUS | "INV-202504" | Unique identifier for the invoice this charge was billed on. |
| CostsPlus    | x_InvoiceIssuerId | string | FOCUS | "issuer-001" | Unique identifier for the Cloud Solution Provider (CSP) partner. |
| CostsPlus    | x_InvoiceSectionId | string | FOCUS | "SEC-001" | Unique identifier for the MCA invoice section or EA department. |
| CostsPlus    | x_InvoiceSectionName | string | FOCUS | "SectionA" | Display name for the MCA invoice section or EA department. |
| CostsPlus    | x_ResourceParentType | string | Toolkit | "Microsoft.Resources/resourceGroups" | Parent resource type (if available) |
| CostsPlus    | x_SkuCoreCount | int | Toolkit | 8 | Number of cores for the SKU (if applicable) |
| CostsPlus    | x_SkuImageType | string | Toolkit | "Windows Server BYOL" | Image type for the SKU (if applicable) |
| CostsPlus    | x_SkuLicenseQuantity | int | Toolkit | 16 | License quantity for the SKU (if applicable) |
| CostsPlus    | x_SkuLicenseStatus | string | Toolkit | "Enabled" | License status for the SKU (if applicable) |
| CostsPlus    | x_SkuLicenseType | string | Toolkit | "Windows Server" | License type for the SKU (if applicable) |
| CostsPlus    | x_SkuLicenseUnit | string | Toolkit | "Cores" | License unit for the SKU (if applicable) |
| CostsPlus    | x_SkuLicenseUnusedQuantity | int | Toolkit | 0 | Unused license quantity for the SKU (if applicable) |
| CostsPlus    | x_SkuTermLabel | string | Toolkit | "12 months" | Term label for the SKU (if applicable) |
| CostsPlus    | x_SkuType | string | Toolkit | "IaaS" | Service type for the SKU (if applicable) |
| CostsPlus    | x_SkuUsageType | string | Toolkit | "Consumption" | Usage type for the SKU (if applicable) |
| CostsPlus    | x_ToolkitTool | string | Toolkit | "finops-toolkit" | Toolkit tool used for enrichment |
| CostsPlus    | x_ToolkitVersion | string | Toolkit | "1.0.0" | Toolkit version used for enrichment |
| CostsPlus    | x_TotalDiscountPercent | real | Toolkit | 0.30 | Total percent discount (all discounts combined) |
| CostsPlus    | x_TotalSavings | real | Toolkit | 200.00 | Total savings (all discounts combined) |
