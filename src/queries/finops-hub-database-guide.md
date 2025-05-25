# FinOps Hubs Database Schema

This document provides a comprehensive overview of how to query and analyze data in the FinOps Hubs database, including schema details for all major tables and functions.

---

## Table of Contents

- [FinOps Hubs Database Schema](#finops-hubs-database-schema)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Key Benefits](#key-benefits)
    - [What's Included](#whats-included)
    - [Prerequisites](#prerequisites)
  - [Overview](#overview)
  - [Query Best Practices](#query-best-practices)
  - [Key Enrichment Columns](#key-enrichment-columns)
  - [Example Queries](#example-queries)
  - [Example Query: Financial Hierarchy Reporting](#example-query-financial-hierarchy-reporting)
    - [Example Query: Cost by Billing Profile, Invoice Section, Team, Product, Application](#example-query-cost-by-billing-profile-invoice-section-team-product-application)
  - [Example Query: Reservation Recommendation Breakdown](#example-query-reservation-recommendation-breakdown)
    - [Example Query: Quarterly Cost by Resource Group](#example-query-quarterly-cost-by-resource-group)
    - [Example Query: Top 5 Resource Groups by Effective Cost (Last Month)](#example-query-top-5-resource-groups-by-effective-cost-last-month)
    - [Example Query: Commitment Discount Utilization Pie Chart](#example-query-commitment-discount-utilization-pie-chart)
    - [Example Query: All available columns](#example-query-all-available-columns)
      - [Column Definitions](#column-definitions)
  - [Additional Tables](#additional-tables)
  - [Schema Reference](#schema-reference)
    - [Prices()](#prices)
    - [Recommendations()](#recommendations)
    - [Transactions()](#transactions)
  - [Glossary](#glossary)
  - [Change Log](#change-log)
  - [References](#references)

---

## Getting Started

FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization—virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs. FinOps hubs extend Cost Management to provide a scalable platform for advanced data reporting and analytics, through tools like Power BI and Microsoft Fabric.

### Key Benefits

1. Report on cost and usage across multiple accounts and subscriptions—even across tenants.
2. Analyze negotiated and commitment discount savings for EA billing accounts and MCA billing profiles.
3. Run advanced analytical queries and report on year-over-year cost trends in seconds.
4. Ingest data into Microsoft Fabric Real-Time Intelligence (RTI) or Azure Data Explorer (ADX).
5. Full alignment with the [FinOps Open Cost and Usage Specification (FOCUS)](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/focus/what-is-focus).
6. Expanded support for more clouds, accounts, and scopes (including Azure Government, China, and MOSA subscriptions).
7. Extensible via Data Factory, Data Explorer, Fabric, and Power BI to integrate business or other providers' cost data.
8. Backwards compatibility as future dataset versions add or change columns.
9. Convert exported data to parquet for faster data access.

### What's Included

The FinOps hub template includes:

- **Azure Data Explorer (Kusto):** Scalable datastore for advanced analytics (optional, but recommended for >$100K spend).
- **Microsoft Fabric Real-Time Intelligence (RTI):** Alternative analytics platform.
- **Storage Account (Data Lake Storage Gen2):** Staging area for data ingestion.
- **Data Factory:** Manages data ingestion and cleanup.
- **Key Vault:** Stores Data Factory system managed identity credentials.

Once deployed, you can query data directly using KQL, visualize data using Data Explorer dashboards, Fabric RTI dashboards, or Power BI reports, or connect to the database/storage from your own tools.

### Prerequisites

- Access to the Azure Data Explorer cluster hosting the Hub database.
- Appropriate permissions (read access).
- Familiarity with Kusto Query Language (KQL).

You can run queries in:

- Azure Data Explorer Web UI
- Azure Monitor Workbooks
- Azure Synapse Studio

For deployment details, see the [FinOps hub deployment tutorial](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/deploy).

---

## Overview

The FinOps Hubs database is designed to support advanced cost and usage analytics for cloud financial operations (FinOps). It provides normalized, enriched data and a set of analytic functions to help you optimize, allocate, and report on cloud spend.

---

## Query Best Practices

- **Start with the CostsPlus Query:**  
  Use the provided CostsPlus query as your base for any cost or usage analytics. This ensures you benefit from the latest schema, enrichment logic, and FinOps best practices.

- **Use KQL (Kusto Query Language):**  
  All queries should be written in KQL for compatibility with Azure Data Explorer.

- **Leverage Enrichment Columns:**  
  Columns prefixed with `x_` provide additional context and enrichment for FinOps analysis.

---

## Key Enrichment Columns

Columns prefixed with `x_` are toolkit enrichments. Some of the most useful are:

| Column Name         | Description                                      |
|---------------------|--------------------------------------------------|
| x_ChargeMonth       | Normalized month for charge period               |
| x_ConsumedCoreHours | Total core hours consumed (for VMs)              |
| x_CommitmentDiscountSavings | Realized savings from commitment discounts (actual savings applied to your bill) |
| x_TotalSavings      | Realized total savings (negotiated + commitment, as actually applied)          |
| x_ResourceGroupName | Resource group name (parsed from ResourceId)     |

---

## Example Queries

## Example Query: Financial Hierarchy Reporting

### Example Query: Cost by Billing Profile, Invoice Section, Team, Product, Application

This example demonstrates how to report costs using the full financial hierarchy: **Billing Profile → Invoice Section → Team → Product → Application**. The last three levels are derived from resource tags. This query uses the `Costs()` table and the recommended enrichment columns.

```kusto
let numberOfMonths = 1; // Set to desired reporting period
Costs()
| where ChargePeriodStart >= monthsago(numberOfMonths)
| extend Team = tostring(Tags['team']), Product = tostring(Tags['product']), Application = tostring(Tags['application'])
| summarize TotalCost = sum(EffectiveCost)
    by x_BillingProfileName, x_InvoiceSectionName, Team, Product, Application
| join kind=leftouter (
    Costs()
    | where ChargePeriodStart >= monthsago(numberOfMonths)
    | summarize GrandTotal = sum(EffectiveCost)
)
on 1 == 1
| extend PercentOfTotal = 100.0 * TotalCost / GrandTotal
| project x_BillingProfileName, x_InvoiceSectionName, Team, Product, Application, TotalCost, PercentOfTotal
| order by TotalCost desc
```

**Column mapping:**

- **Billing Profile:** `x_BillingProfileName` or `x_BillingProfileId`
- **Invoice Section:** `x_InvoiceSectionName` or `x_InvoiceSectionId`
- **Team:** `Tags['team']`
- **Product:** `Tags['product']`
- **Application:** `Tags['application']`

> **Note:** Ensure all resources are consistently tagged. Missing tags will appear as blank values.

---

## Example Query: Reservation Recommendation Breakdown

Shows how to analyze reservation recommendations for cost savings including break-even points.

```kusto
Recommendations()
| where x_SourceProvider == 'Microsoft' and x_SourceType == 'ReservationRecommendations'
| extend RegionId = tostring(x_RecommendationDetails.RegionId)
| extend RegionName = tostring(x_RecommendationDetails.RegionName)
| extend x_CommitmentDiscountSavings = x_EffectiveCostBefore - x_EffectiveCostAfter
| extend x_CommitmentDiscountScope = tostring(x_RecommendationDetails.CommitmentDiscountScope)
| extend x_CommitmentDiscountNormalizedSize  = tostring(x_RecommendationDetails.CommitmentDiscountNormalizedSize)
| extend x_SkuTerm = toint(x_RecommendationDetails.SkuTerm)
| extend x_SkuMeterId = tostring(x_RecommendationDetails.SkuMeterId)
| summarize arg_max(x_RecommendationDate, *) by  x_CommitmentDiscountNormalizedSize, x_SkuMeterId, x_SkuTerm, RegionId,tostring(x_RecommendationDetails.CommitmentDiscountNormalizedGroup)
| extend x_BreakEvenMonths = x_EffectiveCostAfter * x_SkuTerm / x_EffectiveCostBefore
| extend x_BreakEvenDate = startofday(now()) + 1d + toint(x_BreakEvenMonths * 30.437) * 1d
| project
    RegionId,
    RegionName = iff(isempty(RegionName), RegionId, RegionName),
    x_BreakEvenDate,
    x_BreakEvenMonths,
    x_CommitmentDiscountKey             = strcat(x_CommitmentDiscountNormalizedSize, x_SkuMeterId),
    x_CommitmentDiscountNormalizedGroup = tostring(x_RecommendationDetails.CommitmentDiscountNormalizedGroup),
    x_CommitmentDiscountNormalizedRatio = tostring(x_RecommendationDetails.CommitmentDiscountNormalizedRatio),
    x_CommitmentDiscountNormalizedSize,
    x_CommitmentDiscountPercent         = 1.0 * x_CommitmentDiscountSavings / x_EffectiveCostBefore * 100,
    x_CommitmentDiscountResourceType = tostring(x_RecommendationDetails.CommitmentDiscountResourceType),
    x_CommitmentDiscountSavings,
    x_CommitmentDiscountSavingsDailyRate = x_CommitmentDiscountSavings / (x_SkuTerm - x_BreakEvenMonths) / (365/12),
    x_CommitmentDiscountScope = case(
        x_CommitmentDiscountScope == 'Single', 'Subscription',
        x_CommitmentDiscountScope
    ),
    x_EffectiveCostAfter,
    x_EffectiveCostBefore,
    x_LookbackPeriodLabel = replace_regex(tostring(x_RecommendationDetails.LookbackPeriodDuration), 'P([0-9]+)D', @'\1 days'),
    x_RecommendationDate,
    x_RecommendedQuantity           = todecimal(x_RecommendationDetails.RecommendedQuantity),
    x_RecommendedQuantityNormalized = todecimal(x_RecommendationDetails.RecommendedQuantityNormalized),
    x_SkuMeterId,
    x_SkuTerm,
    x_SkuTermLabel = case(x_SkuTerm < 12, strcat(x_SkuTerm, ' month', iff(x_SkuTerm != 1, 's', '')), strcat(x_SkuTerm / 12, ' year', iff(x_SkuTerm != 12, 's', '')))
```

### Example Query: Quarterly Cost by Resource Group

```kusto
let numberOfMonths = 3;  // Look back 3 months for a quarterly report
Costs()
| where ChargePeriodStart >= monthsago(numberOfMonths)
| as filteredCosts
| extend x_ChargeMonth = startofmonth(ChargePeriodStart)
| extend x_ResourceGroupName = tostring(split(ResourceId, '/')[4])
// ... (include all enrichment logic from the base query)
| summarize TotalEffectiveCost = sum(EffectiveCost) by x_ResourceGroupName, x_ChargeMonth
| order by x_ChargeMonth desc, TotalEffectiveCost desc
```

### Example Query: Top 5 Resource Groups by Effective Cost (Last Month)

```kusto
let numberOfMonths = 1;
Costs()
| where ChargePeriodStart >= monthsago(numberOfMonths)
| extend x_ResourceGroupName = tostring(split(ResourceId, '/')[4])
| summarize TotalEffectiveCost = sum(EffectiveCost) by x_ResourceGroupName
| top 5 by TotalEffectiveCost desc
```

### Example Query: Commitment Discount Utilization Pie Chart

```kusto
let numberOfMonths = 1;
let base = Costs()
| where ChargePeriodStart >= monthsago(numberOfMonths)
| extend x_SkuCoreCount = toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, ''))
| extend x_ConsumedCoreHours = iff(isnotempty(x_SkuCoreCount), x_SkuCoreCount * ConsumedQuantity, todecimal(''));
let total = base | summarize Total=todecimal(sum(x_ConsumedCoreHours));
base
| summarize TotalConsumedCoreHours = todecimal(sum(x_ConsumedCoreHours)) by CommitmentDiscountType
| extend CommitmentDiscountType = iff(isempty(CommitmentDiscountType), 'On Demand', CommitmentDiscountType)
| extend PercentOfTotal = 100.0 * TotalConsumedCoreHours / toscalar(total)
| project CommitmentDiscountType, TotalConsumedCoreHours=todouble(TotalConsumedCoreHours), PercentOfTotal=todouble(PercentOfTotal)
| order by PercentOfTotal desc
| render piechart
```

### Example Query: All available columns

```kusto
let numberOfMonths = 1;  // Number of months to look back.  Set numberOfMonths = 3 for a quarterly report
Costs()
//
// Apply summarization settings
| where ChargePeriodStart >= monthsago(numberOfMonths)
| as filteredCosts
| extend x_ChargeMonth = startofmonth(ChargePeriodStart)
//
//| extend x_SkuVMProperties = tostring(x_SkuDetails.VMProperties)
| extend x_CapacityReservationId = tostring(x_SkuDetails.VMCapacityReservationId)
//
// Hybrid Benefit
| extend tmp_SQLAHB = tolower(x_SkuDetails.AHB)
| extend tmp_IsVMUsage  = x_SkuMeterCategory in ('Virtual Machines', 'Virtual Machine Licenses') and ChargeCategory == 'Usage'
| extend x_SkuCoreCount = toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, ''))
| extend x_SkuUsageType = tostring(x_SkuDetails.UsageType)
| extend x_SkuImageType = tostring(x_SkuDetails.ImageType)
| extend x_SkuType      = tostring(x_SkuDetails.ServiceType)
| extend x_ConsumedCoreHours = iff(isnotempty(x_SkuCoreCount), x_SkuCoreCount * ConsumedQuantity, todecimal(''))
| extend x_SkuLicenseStatus = case(
    ChargeCategory != 'Usage', '',
    (x_SkuMeterCategory in ('Virtual Machines', 'Virtual Machine Licenses') and x_SkuMeterSubcategory contains 'Windows') or tmp_SQLAHB == 'false', 'Not Enabled',
    x_SkuDetails.ImageType contains 'Windows Server BYOL' or tmp_SQLAHB == 'true' or x_SkuMeterSubcategory == 'SQL Server Azure Hybrid Benefit', 'Enabled',
    ''
)
| extend x_SkuLicenseType = case(
    ChargeCategory != 'Usage', '',
    x_SkuMeterCategory in ('Virtual Machines', 'Virtual Machine Licenses') and (x_SkuMeterSubcategory contains 'Windows' or x_SkuDetails.ImageType contains 'Windows Server BYOL'), 'Windows Server',
    isnotempty(tmp_SQLAHB) or x_SkuMeterSubcategory == 'SQL Server Azure Hybrid Benefit', 'SQL Server',
    ''
)
| extend x_SkuLicenseQuantity = case(
    isempty(x_SkuCoreCount), toint(''),
    x_SkuCoreCount <= 8, 8,
    x_SkuCoreCount <= 16, 16,
    x_SkuCoreCount == 20, 24,
    x_SkuCoreCount > 20, x_SkuCoreCount,
    toint('')
)
| extend x_SkuLicenseUnit = iff(isnotempty(x_SkuLicenseQuantity), 'Cores', '')
| extend x_SkuLicenseUnusedQuantity = x_SkuLicenseQuantity - x_SkuCoreCount
//
| extend x_CommitmentDiscountKey = iff(tmp_IsVMUsage and isnotempty(x_SkuDetails.ServiceType), strcat(x_SkuDetails.ServiceType, x_SkuMeterId), '')
| extend x_CommitmentDiscountUtilizationPotential = case(
    ChargeCategory == 'Purchase', decimal(0),
    ProviderName == 'Microsoft' and isnotempty(CommitmentDiscountCategory), EffectiveCost,
    CommitmentDiscountCategory == 'Usage', ConsumedQuantity,
    CommitmentDiscountCategory == 'Spend', EffectiveCost,
    decimal(0)
)
| extend x_CommitmentDiscountUtilizationAmount = iff(CommitmentDiscountStatus == 'Used', x_CommitmentDiscountUtilizationPotential, decimal(0))
| extend x_SkuTermLabel = case(isempty(x_SkuTerm) or x_SkuTerm <= 0, '', x_SkuTerm < 12, strcat(x_SkuTerm, ' month', iff(x_SkuTerm != 1, 's', '')), strcat(x_SkuTerm / 12, ' year', iff(x_SkuTerm != 12, 's', '')))
//
// CSP partners
// x_PartnerBilledCredit = iff(x_PartnerCreditApplied, BilledCost * x_PartnerCreditRate, todouble(0))
// x_PartnerEffectiveCredit = iff(x_PartnerCreditApplied, EffectiveCost * x_PartnerCreditRate, todouble(0))
//
// Savings
| extend x_AmortizationCategory = case(
    ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory), 'Principal',
    isnotempty(CommitmentDiscountCategory), 'Amortized Charge',
    ''
)
| extend x_CommitmentDiscountSavings = iff(ContractedCost == 0,      decimal(0), ContractedCost - EffectiveCost)
| extend x_NegotiatedDiscountSavings = iff(ListCost == 0,            decimal(0), ListCost - ContractedCost)
| extend x_TotalSavings              = iff(ListCost == 0,            decimal(0), ListCost - EffectiveCost)
| extend x_CommitmentDiscountPercent = iff(ContractedUnitPrice == 0, decimal(0), (ContractedUnitPrice - x_EffectiveUnitPrice) / ContractedUnitPrice)
| extend x_NegotiatedDiscountPercent = iff(ListUnitPrice == 0,       decimal(0), (ListUnitPrice - ContractedUnitPrice) / ListUnitPrice)
| extend x_TotalDiscountPercent      = iff(ListUnitPrice == 0,       decimal(0), (ListUnitPrice - x_EffectiveUnitPrice) / ListUnitPrice)
//
// Toolkit
| extend x_ToolkitTool = tostring(Tags['ftk-tool'])
| extend x_ToolkitVersion = tostring(Tags['ftk-version'])
| extend tmp_ResourceParent = database('Ingestion').parse_resourceid(Tags['cm-resource-parent'])
| extend x_ResourceParentId = tostring(tmp_ResourceParent.ResourceId)
| extend x_ResourceParentName = tostring(tmp_ResourceParent.ResourceName)
| extend x_ResourceParentType = tostring(tmp_ResourceParent.ResourceType)
//
// TODO: Only add differentiators when the name is not unique
| extend CommitmentDiscountNameUnique = iff(isempty(CommitmentDiscountId), '', strcat(CommitmentDiscountName, ' (', CommitmentDiscountType, ')'))
| extend ResourceNameUnique           = iff(isempty(ResourceId),           '', strcat(ResourceName,           ' (', ResourceType, ')'))
| extend x_ResourceGroupNameUnique    = iff(isempty(x_ResourceGroupName),  '', strcat(x_ResourceGroupName,    ' (', SubAccountName, ')'))
| extend SubAccountNameUnique         = iff(isempty(SubAccountId),         '', strcat(SubAccountName,         ' (', split(SubAccountId, '/')[3], ')'))
//
// Explain why cost is 0
| extend x_FreeReason = case(
    BilledCost != 0.0 or EffectiveCost != 0.0, '',
    PricingCategory == 'Committed', strcat('Unknown ', CommitmentDiscountStatus, ' Commitment'),
    x_BilledUnitPrice == 0.0 and x_EffectiveUnitPrice == 0.0 and ContractedUnitPrice == 0.0 and ListUnitPrice == 0.0 and isempty(CommitmentDiscountType), case(
        x_SkuDescription contains 'Trial', 'Trial',
        x_SkuDescription contains 'Preview', 'Preview',
        'Other'
    ),
    x_BilledUnitPrice > 0.0 or x_EffectiveUnitPrice > 0.0, case(
        PricingQuantity > 0.0, 'Low Usage',
        PricingQuantity == 0.0, 'No Usage',
        'Unknown Negative Quantity'
    ),
    'Unknown'
)
//
| project-away tmp_SQLAHB, tmp_IsVMUsage, tmp_ResourceParent
```

#### Column Definitions

The following table lists the columns produced in the `All available columns` query.

| Column Name                                   | Data Type   | Description |
|-----------------------------------------------|-------------|-------------|
| AvailabilityZone                              | string      | Availability zone of the resource, if applicable. |
| BilledCost                                    | decimal     | The cost billed for the resource or usage. |
| BillingAccountId                              | string      | Unique identifier for the billing account. |
| BillingAccountName                            | string      | Name of the billing account. |
| BillingAccountType                            | string      | Type of billing account (e.g., EA, MCA). |
| BillingCurrency                               | string      | Currency used for billing. |
| BillingPeriodEnd                              | datetime    | End date of the billing period. |
| BillingPeriodStart                            | datetime    | Start date of the billing period. |
| ChargeCategory                                | string      | Category of the charge (e.g., Usage, Purchase). |
| ChargeClass                                   | string      | Class of the charge (e.g., Service, Tax). |
| ChargeDescription                             | string      | Description of the charge. |
| ChargeFrequency                               | string      | Frequency of the charge (e.g., Monthly, One-time). |
| ChargePeriodEnd                               | datetime    | End date of the charge period. |
| ChargePeriodStart                             | datetime    | Start date of the charge period. |
| CommitmentDiscountCategory                    | string      | Type of commitment discount (e.g., Reserved Instance, Savings Plan). |
| CommitmentDiscountId                          | string      | Unique identifier for the commitment discount. |
| CommitmentDiscountName                        | string      | Name of the commitment discount. |
| CommitmentDiscountStatus                      | string      | Status of the commitment discount (e.g., Used, Unused). |
| CommitmentDiscountType                        | string      | The specific type of discount (e.g., RI, SP). |
| ConsumedQuantity                              | decimal     | Amount of resource usage consumed. |
| ConsumedUnit                                  | string      | Unit of measure for consumed quantity. |
| ContractedCost                                | decimal     | Negotiated cost for the resource or usage. |
| ContractedUnitPrice                           | decimal     | Negotiated unit price for the resource. |
| EffectiveCost                                 | decimal     | Actual cost after all discounts and credits. |
| InvoiceIssuerName                             | string      | Name of the invoice issuer. |
| ListCost                                      | decimal     | List (retail) cost for the resource or usage. |
| ListUnitPrice                                 | decimal     | List (retail) unit price for the resource. |
| PricingCategory                               | string      | Category of pricing (e.g., Standard, Spot). |
| PricingQuantity                               | decimal     | Quantity used for pricing. |
| PricingUnit                                   | string      | Unit of measure for pricing. |
| ProviderName                                  | string      | Name of the cloud provider. |
| PublisherName                                 | string      | Name of the publisher. |
| RegionId                                      | string      | Identifier for the region. |
| RegionName                                    | string      | Name of the region. |
| ResourceId                                    | string      | Unique identifier for the resource. |
| ResourceName                                  | string      | Name of the resource. |
| ResourceType                                  | string      | Type of resource (e.g., Virtual Machine, SQL Database). |
| ServiceCategory                               | string      | High-level service category (e.g., Compute, Storage). |
| ServiceName                                   | string      | Name of the Azure service. |
| SkuId                                         | string      | Unique identifier for the SKU. |
| SkuPriceId                                    | string      | Unique identifier for the SKU price. |
| SubAccountId                                  | string      | Identifier for the sub-account or subscription. |
| SubAccountName                                | string      | Name of the sub-account or subscription. |
| SubAccountType                                | string      | Type of sub-account. |
| Tags                                          | dynamic     | Resource tags as a dynamic object. |
| x_AccountId                                   | string      | Enriched account identifier. |
| x_AccountName                                 | string      | Enriched account name. |
| x_AccountOwnerId                              | string      | Owner ID for the account. |
| x_BilledCostInUsd                             | decimal     | Billed cost converted to USD. |
| x_BilledUnitPrice                             | decimal     | Billed unit price. |
| x_BillingAccountAgreement                     | string      | Billing agreement reference. |
| x_BillingAccountId                            | string      | Enriched billing account ID. |
| x_BillingAccountName                          | string      | Enriched billing account name. |
| x_BillingExchangeRate                         | decimal     | Exchange rate used for billing. |
| x_BillingExchangeRateDate                     | datetime    | Date of the exchange rate. |
| x_BillingProfileId                            | string      | Billing profile identifier. |
| x_BillingProfileName                          | string      | Name of the billing profile. |
| x_ChargeId                                    | string      | Unique identifier for the charge. |
| x_ContractedCostInUsd                         | decimal     | Contracted cost converted to USD. |
| x_CostAllocationRuleName                      | string      | Name of the cost allocation rule. |
| x_CostCategories                              | dynamic     | Cost categories as a dynamic object. |
| x_CostCenter                                  | string      | Cost center for the transaction. |
| x_Credits                                     | dynamic     | Credits applied as a dynamic object. |
| x_CostType                                    | string      | Type of cost (e.g., Amortized, Principal). |
| x_CurrencyConversionRate                      | decimal     | Currency conversion rate used. |
| x_CustomerId                                  | string      | Customer identifier. |
| x_CustomerName                                | string      | Name of the customer. |
| x_Discount                                    | dynamic     | Discount details as a dynamic object. |
| x_EffectiveCostInUsd                          | decimal     | Effective cost converted to USD. |
| x_EffectiveUnitPrice                          | decimal     | Final unit price after all discounts. |
| x_ExportTime                                  | datetime    | Time the record was exported. |
| x_IngestionTime                               | datetime    | Timestamp when the record was ingested. |
| x_InvoiceId                                   | string      | Invoice identifier. |
| x_InvoiceIssuerId                             | string      | Invoice issuer identifier. |
| x_InvoiceSectionId                            | string      | Invoice section identifier. |
| x_InvoiceSectionName                          | string      | Invoice section name. |
| x_ListCostInUsd                               | decimal     | List cost converted to USD. |
| x_Location                                    | string      | Location of the resource. |
| x_Operation                                   | string      | Operation performed. |
| x_PartnerCreditApplied                        | string      | Whether partner credit was applied. |
| x_PartnerCreditRate                           | string      | Partner credit rate. |
| x_PricingBlockSize                            | decimal     | Block size for pricing. |
| x_PricingCurrency                             | string      | Currency for pricing. |
| x_PricingSubcategory                          | string      | Subcategory for pricing. |
| x_PricingUnitDescription                      | string      | Description of the pricing unit. |
| x_Project                                     | string      | Project name or identifier. |
| x_PublisherCategory                           | string      | Publisher category. |
| x_PublisherId                                 | string      | Publisher identifier. |
| x_ResellerId                                  | string      | Reseller identifier. |
| x_ResellerName                                | string      | Name of the reseller. |
| x_ResourceGroupName                           | string      | Name of the resource group. |
| x_ResourceType                                | string      | Enriched resource type. |
| x_ServiceCode                                 | string      | Service code. |
| x_ServiceId                                   | string      | Service identifier. |
| x_ServicePeriodEnd                            | datetime    | End of the service period. |
| x_ServicePeriodStart                          | datetime    | Start of the service period. |
| x_SkuDescription                              | string      | Description of the SKU. |
| x_SkuDetails                                  | dynamic     | Details of the SKU as a dynamic object. |
| x_SkuIsCreditEligible                         | bool        | Whether the SKU is credit eligible. |
| x_SkuMeterCategory                            | string      | Meter category for the SKU. |
| x_SkuMeterId                                  | string      | Meter ID for the SKU. |
| x_SkuMeterName                                | string      | Meter name for the SKU. |
| x_SkuMeterSubcategory                         | string      | Meter subcategory for the SKU. |
| x_SkuOfferId                                  | string      | Offer ID for the SKU. |
| x_SkuOrderId                                  | string      | Order ID for the SKU. |
| x_SkuOrderName                                | string      | Name of the SKU order. |
| x_SkuPartNumber                               | string      | Part number for the SKU. |
| x_SkuRegion                                   | string      | Region for the SKU. |
| x_SkuServiceFamily                            | string      | Service family for the SKU. |
| x_SkuTerm                                     | int         | Term length for the SKU (months). |
| x_SkuTier                                     | string      | Tier for the SKU (e.g., Standard, Premium). |
| x_SourceChanges                               | string      | Source changes or notes. |
| x_SourceName                                  | string      | Name of the data source. |
| x_SourceProvider                              | string      | Provider of the data source. |
| x_SourceType                                  | string      | Type of data source. |
| x_SourceVersion                               | string      | Version of the data source. |
| x_UsageType                                   | string      | Usage type for the resource. |
| x_ChargeMonth                                 | datetime    | Normalized month for charge period. |
| x_CapacityReservationId                       | string      | Capacity reservation identifier. |
| x_SkuCoreCount                                | int         | Number of cores for the SKU. |
| x_SkuUsageType                                | string      | Usage type for the SKU. |
| x_SkuImageType                                | string      | Image type for the SKU. |
| x_SkuType                                     | string      | Service type for the SKU. |
| x_ConsumedCoreHours                           | decimal     | Total core hours consumed. |
| x_SkuLicenseStatus                            | string      | License status for the SKU. |
| x_SkuLicenseType                              | string      | License type for the SKU. |
| x_SkuLicenseQuantity                          | long        | License quantity for the SKU. |
| x_SkuLicenseUnit                              | string      | License unit for the SKU. |
| x_SkuLicenseUnusedQuantity                    | long        | Unused license quantity for the SKU. |
| x_CommitmentDiscountKey                       | string      | Key for commitment discount utilization. |
| x_CommitmentDiscountUtilizationPotential      | decimal     | Potential utilization for commitment discount. |
| x_CommitmentDiscountUtilizationAmount         | decimal     | Actual utilization amount for commitment discount. |
| x_SkuTermLabel                                | string      | Human-readable label for SKU term. |
| x_AmortizationCategory                        | string      | Amortization category (e.g., Principal, Amortized Charge). |
| x_CommitmentDiscountSavings                   | decimal     | Realized savings from commitment discounts (actual savings applied to your bill). |
| x_NegotiatedDiscountSavings                   | decimal     | Realized savings from negotiated discounts (actual savings applied to your bill). |
| x_TotalSavings                                | decimal     | Realized total savings (negotiated + commitment, as actually applied). |
| x_CommitmentDiscountPercent                   | decimal     | Percent savings from commitment discount. |
| x_NegotiatedDiscountPercent                   | decimal     | Percent savings from negotiated discount. |
| x_TotalDiscountPercent                        | decimal     | Total percent savings. |
| x_ToolkitTool                                 | string      | Toolkit tool name. |
| x_ToolkitVersion                              | string      | Toolkit version. |
| x_ResourceParentId                            | string      | Resource parent identifier. |
| x_ResourceParentName                          | string      | Resource parent name. |
| x_ResourceParentType                          | string      | Resource parent type. |
| CommitmentDiscountNameUnique                  | string      | Unique name for the commitment discount. |
| ResourceNameUnique                            | string      | Unique name for the resource. |
| x_ResourceGroupNameUnique                     | string      | Unique name for the resource group. |
| SubAccountNameUnique                          | string      | Unique name for the sub-account. |
| x_FreeReason                                  | string      | Reason why the cost is zero. |

> **Note:**
> The savings columns (`x_CommitmentDiscountSavings`, `x_NegotiatedDiscountSavings`, `x_TotalSavings`) represent realized savings—these are the actual discounts and savings that have been applied to your costs, not just potential or theoretical savings.

---

## Additional Tables

The FinOps Hubs database includes several tables which are accessed via these functions for specialized cost and usage analysis:

| Table/Function Name        | Description                                                        |
|----------------------------|--------------------------------------------------------------------|
| Prices()                   | Price list for Azure services.                                     |
| Recommendations()          | Provides recommendations for cost optimization via Reserved Instance Purchases. |
| Transactions()             | Tracks all transactions related to Reserved Instances, including purchases, refunds, and adjustments. |

## Schema Reference

> **Note:**  
> All columns prefixed with `x_` are toolkit enrichment columns, providing additional context for FinOps analysis.

Below are the column definitions for the main analytic tables in the FinOps Hubs database. These definitions are based on Microsoft Learn, FinOps best practices, and common cloud cost management terminology.

### Prices()

| Column Name                              | Data Type   | Description |
|------------------------------------------|-------------|-------------|
| BillingAccountId                         | string      | Unique identifier for the billing account. |
| BillingAccountName                       | string      | Name of the billing account. |
| BillingCurrency                          | string      | Currency used for billing. |
| ChargeCategory                           | string      | Category of the charge (e.g., Usage, Purchase). |
| CommitmentDiscountCategory               | string      | Type of commitment discount. |
| CommitmentDiscountType                   | string      | Specific type of discount. |
| ContractedUnitPrice                      | decimal     | Negotiated unit price for the resource. |
| ListUnitPrice                            | decimal     | List (retail) unit price for the resource. |
| PricingCategory                          | string      | Category of pricing (e.g., Standard, Spot). |
| PricingUnit                              | string      | Unit of measure for pricing (e.g., hours, GB). |
| SkuId                                    | string      | Unique identifier for the SKU. |
| SkuPriceId                               | string      | Unique identifier for the SKU price. |
| SkuPriceIdv2                             | string      | Alternate identifier for the SKU price. |
| x_BaseUnitPrice                          | decimal     | Base unit price before discounts. |
| x_BillingAccountAgreement                | string      | Billing agreement reference. |
| x_BillingAccountId                       | string      | Enriched billing account ID. |
| x_BillingProfileId                       | string      | Billing profile identifier. |
| x_CommitmentDiscountSpendEligibility     | string      | Eligibility for spend-based discounts. |
| x_CommitmentDiscountUsageEligibility     | string      | Eligibility for usage-based discounts. |
| x_ContractedUnitPriceDiscount            | decimal     | Discount amount from contracted price. |
| x_ContractedUnitPriceDiscountPercent     | decimal     | Discount percent from contracted price. |
| x_EffectivePeriodEnd                     | datetime    | End of the effective pricing period. |
| x_EffectivePeriodStart                   | datetime    | Start of the effective pricing period. |
| x_EffectiveUnitPrice                     | decimal     | Final unit price after all discounts. |
| x_EffectiveUnitPriceDiscount             | decimal     | Discount amount from effective price. |
| x_EffectiveUnitPriceDiscountPercent      | decimal     | Discount percent from effective price. |
| x_IngestionTime                          | datetime    | Timestamp when the record was ingested. |
| x_PricingBlockSize                       | decimal     | Block size for pricing (e.g., 1000 units). |
| x_PricingCurrency                        | string      | Currency for pricing. |
| x_PricingSubcategory                     | string      | Subcategory for pricing. |
| x_PricingUnitDescription                 | string      | Description of the pricing unit. |
| x_SkuDescription                         | string      | Description of the SKU. |
| x_SkuId                                  | string      | Enriched SKU ID. |
| x_SkuIncludedQuantity                    | decimal     | Quantity included at no extra cost. |
| x_SkuMeterCategory                       | string      | Meter category for the SKU. |
| x_SkuMeterId                             | string      | Meter ID for the SKU. |
| x_SkuMeterName                           | string      | Meter name for the SKU. |
| x_SkuMeterSubcategory                    | string      | Meter subcategory for the SKU. |
| x_SkuMeterType                           | string      | Meter type for the SKU. |
| x_SkuPriceType                           | string      | Type of price (e.g., retail, negotiated). |
| x_SkuProductId                           | string      | Product ID for the SKU. |
| x_SkuRegion                              | string      | Region for the SKU. |
| x_SkuServiceFamily                       | string      | Service family for the SKU. |
| x_SkuOfferId                             | string      | Offer ID for the SKU. |
| x_SkuPartNumber                          | string      | Part number for the SKU. |
| x_SkuTerm                                | int         | Term length for the SKU (months). |
| x_SkuTier                                | decimal     | Tier for the SKU (e.g., Standard, Premium). |
| x_SourceName                             | string      | Name of the data source. |
| x_SourceProvider                         | string      | Provider of the data source. |
| x_SourceType                             | string      | Type of data source. |
| x_SourceVersion                          | string      | Version of the data source. |
| x_TotalUnitPriceDiscount                 | decimal     | Total discount amount. |
| x_TotalUnitPriceDiscountPercent          | decimal     | Total discount percent. |

### Recommendations()

| Column Name              | Data Type   | Description |
|--------------------------|-------------|-------------|
| ProviderName             | string      | Name of the cloud provider. |
| SubAccountId             | string      | Identifier for the sub-account or subscription. |
| x_IngestionTime          | datetime    | Timestamp when the record was ingested. |
| x_EffectiveCostAfter     | decimal     | Projected cost after applying the recommendation. |
| x_EffectiveCostBefore    | decimal     | Cost before applying the recommendation. |
| x_EffectiveCostSavings   | decimal     | Estimated cost savings from the recommendation. |
| x_RecommendationDate     | datetime    | Date the recommendation was generated. |
| x_RecommendationDetails  | dynamic     | Details of the recommendation (dynamic object). |
| x_SourceName             | string      | Name of the data source. |
| x_SourceProvider         | string      | Provider of the data source. |
| x_SourceType             | string      | Type of data source. |
| x_SourceVersion          | string      | Version of the data source. |

### Transactions()

| Column Name                  | Data Type   | Description |
|------------------------------|-------------|-------------|
| BilledCost                   | decimal     | Cost billed for the transaction. |
| BillingAccountId             | string      | Unique identifier for the billing account. |
| BillingAccountName           | string      | Name of the billing account. |
| BillingCurrency              | string      | Currency used for billing. |
| BillingPeriodEnd             | datetime    | End date of the billing period. |
| BillingPeriodStart           | datetime    | Start date of the billing period. |
| ChargeCategory               | string      | Category of the charge (e.g., Usage, Purchase). |
| ChargeClass                  | string      | Class of the charge (e.g., Service, Tax). |
| ChargeDescription            | string      | Description of the charge. |
| ChargeFrequency              | string      | Frequency of the charge (e.g., Monthly, One-time). |
| ChargePeriodStart            | datetime    | Start date of the charge period. |
| PricingQuantity              | decimal     | Quantity used for pricing. |
| PricingUnit                  | string      | Unit of measure for pricing. |
| ProviderName                 | string      | Name of the cloud provider. |
| RegionId                     | string      | Identifier for the region. |
| RegionName                   | string      | Name of the region. |
| SubAccountId                 | string      | Identifier for the sub-account or subscription. |
| SubAccountName               | string      | Name of the sub-account or subscription. |
| x_AccountName                | string      | Enriched account name. |
| x_AccountOwnerId             | string      | Owner ID for the account. |
| x_CostCenter                 | string      | Cost center for the transaction. |
| x_InvoiceId                  | string      | Invoice identifier. |
| x_InvoiceNumber              | string      | Invoice number. |
| x_InvoiceSectionId           | string      | Invoice section identifier. |
| x_InvoiceSectionName         | string      | Invoice section name. |
| x_IngestionTime              | datetime    | Timestamp when the record was ingested. |
| x_MonetaryCommitment         | decimal     | Monetary value of the commitment. |
| x_Overage                    | decimal     | Overage amount (if any). |
| x_PurchasingBillingAccountId | string      | Purchasing billing account identifier. |
| x_SkuOrderId                 | string      | Order ID for the SKU. |
| x_SkuOrderName               | string      | Name of the SKU order. |
| x_SkuSize                    | string      | Size of the SKU. |
| x_SkuTerm                    | int         | Term length for the SKU (months). |
| x_SourceName                 | string      | Name of the data source. |
| x_SourceProvider             | string      | Provider of the data source. |
| x_SourceType                 | string      | Type of data source. |
| x_SourceVersion              | string      | Version of the data source. |
| x_SubscriptionId             | string      | Subscription identifier. |
| x_TransactionType            | string      | Type of transaction (e.g., Purchase, Refund). |

## Glossary

| Term                        | Definition |
|-----------------------------|------------|
| FinOps                      | Cloud Financial Operations: discipline for managing cloud spend and value. |
| FOCUS                       | FinOps Open Cost and Usage Specification: a standard schema for cloud cost data. |
| KQL                         | Kusto Query Language: query language for Azure Data Explorer. |
| Commitment Discount         | Azure Reserved Instances or Savings Plans that provide discounted rates for commitment. |
| Effective Cost              | Actual cost after all discounts and credits are applied. |
| SKU                         | Stock Keeping Unit: unique identifier for a specific Azure resource or service offering. |
| Resource Group              | Logical container for Azure resources. |
| Meter Category              | Category of usage meter (e.g., Compute, Storage). |
| Enrichment Column (x_*)     | Additional columns added by the toolkit for analytics and reporting. |
| Data Ingestion              | Process of importing and normalizing data into the FinOps Hub. |
| Power BI                    | Microsoft analytics and visualization platform. |
| Azure Data Explorer (ADX)   | Scalable analytics service for large data sets. |
| Microsoft Fabric RTI        | Real-Time Intelligence analytics platform. |

---

## Change Log

| Date       | Version | Author              | Notes                        |
|------------|---------|---------------------|------------------------------|
| 2025-05-16 | 1.0     | FinOps Toolkit Team | Initial documentation        |
| 2025-05-16 | 1.1     | FinOps Toolkit Team | Expanded schema, glossary, references |

---

## References

- [FinOps Hubs Overview](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/finops-hubs-overview)
- [FinOps Open Cost and Usage Specification (FOCUS)](https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/focus/what-is-focus)
- [Schema optimization best practices (Azure Data Explorer)](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice)
- [Kusto Query Language Documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
