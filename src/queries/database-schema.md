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

## Power BI Integration

Power BI reports connect to the Hub database and use the managed dataset functions and tables for analytics. Some tables are derived or virtual, such as compliance calculations and error summaries.

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
`
### Combined Output Schema

The following table lists all columns output by the `CostsPlus` query, including both the base `Costs` table and all enrichment columns, sorted alphabetically. The `Source` column indicates whether a field is from the FOCUS standard, toolkit enrichment, or cloud-specific/custom. The `Example` column provides a sample value for complex or ambiguous fields.

| Dataset Name| Column | Type | Source | Example | Description |
|--------------|--------|------|--------|---------|-------------|
| CostsPlus    | AccountName | string | FOCUS | "Contoso-Prod-Sub" | Account name (cloud provider account/subscription) |
| CostsPlus    | AccountOwnerId | string | FOCUS | "user@contoso.com" | Account owner ID |
| CostsPlus    | AccountType | string | FOCUS | "Subscription" | Account type (e.g., Subscription, Billing Account) |
| CostsPlus    | BillingAccountId | string | FOCUS | "123456" | Billing account ID |
| CostsPlus    | BillingAccountName | string | FOCUS | "Contoso Billing" | Billing account name |
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
| CostsPlus    | InvoiceId | string | FOCUS | "INV-202504" | Invoice ID |
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
| CostsPlus    | PublisherName | string | Toolkit | "Microsoft" | Publisher name (cloud-specific, may not be present for all providers) |
| CostsPlus    | PublisherType | string | Toolkit | "FirstParty" | Publisher type (cloud-specific, may not be present for all providers) |
| CostsPlus    | ResourceGroupName | string | FOCUS | "rg-prod" | Resource group name |
| CostsPlus    | ResourceId | string | FOCUS | "/subscriptions/..." | Resource ID |
| CostsPlus    | ResourceLocation | string | Toolkit | "eastus" | Resource location/region (may be cloud-specific) |
| CostsPlus    | ResourceName | string | FOCUS | "vm-prod-01" | Resource name |
| CostsPlus    | ResourceNameUnique | string | Toolkit | "vm-prod-01 (Microsoft.Compute/virtualMachines)" | Unique resource name (with type) |
| CostsPlus    | ResourceType | string | FOCUS | "Microsoft.Compute/virtualMachines" | Resource type |
| CostsPlus    | ServiceFamily | string | FOCUS | "Compute" | Service family (e.g., Compute, Storage) |
| CostsPlus    | ServiceName | string | FOCUS | "Virtual Machines" | Service name |
| CostsPlus    | ServiceTier | string | FOCUS | "Standard" | Service tier/level |
| CostsPlus    | ServiceType | string | FOCUS | "IaaS" | Service type |
| CostsPlus    | SubAccountId | string | FOCUS | "sub-001" | Subaccount ID |
| CostsPlus    | SubAccountName | string | FOCUS | "Contoso Subaccount" | Subaccount name |
| CostsPlus    | SubAccountNameUnique | string | Toolkit | "Contoso Subaccount (sub-001)" | Unique subaccount name (with ID) |
