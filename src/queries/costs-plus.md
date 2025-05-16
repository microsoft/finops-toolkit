# FinOps Hubs Database Schema
#
# Version History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0     | 2025-05-16 | FinOps Toolkit Team | Initial comprehensive schema documentation |


_Last updated: May 16, 2025_

This document provides a comprehensive overview of how to query the FinOps Hubs database. 

## Table of Contents
- [Overview](#overview)
- [Query](#query)
- [Schema](#schema)

---

## Overview

> **Guidance:**  
> When running queries against the FinOps Hub database, use the query below as your starting point for any cost or usage analytics to ensure all queries benefit from the latest schema, enrichment logic, and FinOps best practices.

### Query


This query offers an extensible, normalized query over the Costs table, providing enriched, FinOps-ready cost and usage data.

```kusto
let numberOfMonths = 1;  // Number of months to look back.  Set numberOfMonths = 3 for a quarterly report
Costs_v1_0
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

---


### Examples

Here's an example o how to use the CostsPlus query as a base to analyze total effective cost by resource group for the last three months:

```kusto
let numberOfMonths = 3;  // Look back 3 months for a quarterly report
Costs_v1_0
| where ChargePeriodStart >= monthsago(numberOfMonths)
| as filteredCosts
| extend x_ChargeMonth = startofmonth(ChargePeriodStart)
| extend x_ResourceGroupName = tostring(split(ResourceId, '/')[4])
// ... (include all enrichment logic from the base query)
| summarize TotalEffectiveCost = sum(EffectiveCost) by x_ResourceGroupName, x_ChargeMonth
| order by x_ChargeMonth desc, TotalEffectiveCost desc
```

Here's an example of see what percentage of total consumed core hours are used by each commitment discount type for the last month:

```kusto

``` kusto
let numberOfMonths = 1;
let base = Costs_v1_0
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
// | render piechart
```

### Schema


The following table lists all columns output by the query.  The table is sorted alphabetically by the **Column Name** column. Column names starting in x_ represent toolkit enrichment.


| Column Name                                   | Data Type   |
|-----------------------------------------------|-------------|
| AvailabilityZone                              | string      |
| BilledCost                                    | decimal     |
| BillingAccountId                              | string      |
| BillingAccountName                            | string      |
| BillingAccountType                            | string      |
| BillingCurrency                               | string      |
| BillingPeriodEnd                              | datetime    |
| BillingPeriodStart                            | datetime    |
| ChargeCategory                                | string      |
| ChargeClass                                   | string      |
| ChargeDescription                             | string      |
| ChargeFrequency                               | string      |
| ChargePeriodEnd                               | datetime    |
| ChargePeriodStart                             | datetime    |
| CommitmentDiscountCategory                    | string      |
| CommitmentDiscountId                          | string      |
| CommitmentDiscountName                        | string      |
| CommitmentDiscountStatus                      | string      |
| CommitmentDiscountType                        | string      |
| ConsumedQuantity                              | decimal     |
| ConsumedUnit                                  | string      |
| ContractedCost                                | decimal     |
| ContractedUnitPrice                           | decimal     |
| EffectiveCost                                 | decimal     |
| InvoiceIssuerName                             | string      |
| ListCost                                      | decimal     |
| ListUnitPrice                                 | decimal     |
| PricingCategory                               | string      |
| PricingQuantity                               | decimal     |
| PricingUnit                                   | string      |
| ProviderName                                  | string      |
| PublisherName                                 | string      |
| RegionId                                      | string      |
| RegionName                                    | string      |
| ResourceId                                    | string      |
| ResourceName                                  | string      |
| ResourceType                                  | string      |
| ServiceCategory                               | string      |
| ServiceName                                   | string      |
| SkuId                                         | string      |
| SkuPriceId                                    | string      |
| SubAccountId                                  | string      |
| SubAccountName                                | string      |
| SubAccountType                                | string      |
| Tags                                          | dynamic     |
| x_AccountId                                   | string      |
| x_AccountName                                 | string      |
| x_AccountOwnerId                              | string      |
| x_BilledCostInUsd                             | decimal     |
| x_BilledUnitPrice                             | decimal     |
| x_BillingAccountAgreement                     | string      |
| x_BillingAccountId                            | string      |
| x_BillingAccountName                          | string      |
| x_BillingExchangeRate                         | decimal     |
| x_BillingExchangeRateDate                     | datetime    |
| x_BillingProfileId                            | string      |
| x_BillingProfileName                          | string      |
| x_ChargeId                                    | string      |
| x_ContractedCostInUsd                         | decimal     |
| x_CostAllocationRuleName                      | string      |
| x_CostCategories                              | dynamic     |
| x_CostCenter                                  | string      |
| x_Credits                                     | dynamic     |
| x_CostType                                    | string      |
| x_CurrencyConversionRate                      | decimal     |
| x_CustomerId                                  | string      |
| x_CustomerName                                | string      |
| x_Discount                                    | dynamic     |
| x_EffectiveCostInUsd                          | decimal     |
| x_EffectiveUnitPrice                          | decimal     |
| x_ExportTime                                  | datetime    |
| x_IngestionTime                               | datetime    |
| x_InvoiceId                                   | string      |
| x_InvoiceIssuerId                             | string      |
| x_InvoiceSectionId                            | string      |
| x_InvoiceSectionName                          | string      |
| x_ListCostInUsd                               | decimal     |
| x_Location                                    | string      |
| x_Operation                                   | string      |
| x_PartnerCreditApplied                        | string      |
| x_PartnerCreditRate                           | string      |
| x_PricingBlockSize                            | decimal     |
| x_PricingCurrency                             | string      |
| x_PricingSubcategory                          | string      |
| x_PricingUnitDescription                      | string      |
| x_Project                                     | string      |
| x_PublisherCategory                           | string      |
| x_PublisherId                                 | string      |
| x_ResellerId                                  | string      |
| x_ResellerName                                | string      |
| x_ResourceGroupName                           | string      |
| x_ResourceType                                | string      |
| x_ServiceCode                                 | string      |
| x_ServiceId                                   | string      |
| x_ServicePeriodEnd                            | datetime    |
| x_ServicePeriodStart                          | datetime    |
| x_SkuDescription                              | string      |
| x_SkuDetails                                  | dynamic     |
| x_SkuIsCreditEligible                         | bool        |
| x_SkuMeterCategory                            | string      |
| x_SkuMeterId                                  | string      |
| x_SkuMeterName                                | string      |
| x_SkuMeterSubcategory                         | string      |
| x_SkuOfferId                                  | string      |
| x_SkuOrderId                                  | string      |
| x_SkuOrderName                                | string      |
| x_SkuPartNumber                               | string      |
| x_SkuRegion                                   | string      |
| x_SkuServiceFamily                            | string      |
| x_SkuTerm                                     | int         |
| x_SkuTier                                     | string      |
| x_SourceChanges                               | string      |
| x_SourceName                                  | string      |
| x_SourceProvider                              | string      |
| x_SourceType                                  | string      |
| x_SourceVersion                               | string      |
| x_UsageType                                   | string      |
| x_ChargeMonth                                 | datetime    |
| x_CapacityReservationId                       | string      |
| x_SkuCoreCount                                | int         |
| x_SkuUsageType                                | string      |
| x_SkuImageType                                | string      |
| x_SkuType                                     | string      |
| x_ConsumedCoreHours                           | decimal     |
| x_SkuLicenseStatus                            | string      |
| x_SkuLicenseType                              | string      |
| x_SkuLicenseQuantity                          | long        |
| x_SkuLicenseUnit                              | string      |
| x_SkuLicenseUnusedQuantity                    | long        |
| x_CommitmentDiscountKey                       | string      |
| x_CommitmentDiscountUtilizationPotential      | decimal     |
| x_CommitmentDiscountUtilizationAmount         | decimal     |
| x_SkuTermLabel                                | string      |
| x_AmortizationCategory                        | string      |
| x_CommitmentDiscountSavings                   | decimal     |
| x_NegotiatedDiscountSavings                   | decimal     |
| x_TotalSavings                                | decimal     |
| x_CommitmentDiscountPercent                   | decimal     |
| x_NegotiatedDiscountPercent                   | decimal     |
| x_TotalDiscountPercent                        | decimal     |
| x_ToolkitTool                                 | string      |
| x_ToolkitVersion                              | string      |
| x_ResourceParentId                            | string      |
| x_ResourceParentName                          | string      |
| x_ResourceParentType                          | string      |
| CommitmentDiscountNameUnique                  | string      |
| ResourceNameUnique                            | string      |
| x_ResourceGroupNameUnique                     | string      |
| SubAccountNameUnique                          | string      |
| x_FreeReason                                  | string      |
