---
title: Troubleshooting reservation savings calculations
description: Learn how to diagnose and fix issues with reservation savings showing as zero in FinOps toolkit reports.
author: flanakin
ms.author: micflan
ms.date: 10/10/2025
ms.topic: troubleshooting-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I want to understand why reservation savings are showing as zero so I can fix the issue and get accurate savings calculations.
---

<!-- markdownlint-disable-next-line MD025 -->
# Troubleshooting reservation savings calculations

If your FinOps toolkit reports show zero savings for reservations even though you have active reservations in use, this article helps you diagnose and resolve the issue.

This is typically caused by missing price data in the Cost Management FOCUS export, which is a known limitation documented in the [FOCUS conformance summary](https://learn.microsoft.com/cloud-computing/finops/focus/conformance-summary#missing-data).

<br>

## Symptoms

You may experience one or more of the following symptoms:

- Rate optimization reports show 0.00% estimated savings rate (ESR) for reservations
- ContractedCost equals EffectiveCost for reservation usage charges
- ListCost equals ContractedCost equals EffectiveCost for reservation usage charges
- x_SourceChanges column contains "MissingContractedCost" or "MissingListCost" for reservation rows

<br>

## Root cause

Microsoft Cost Management FOCUS exports set ContractedCost and ListCost to zero for:

- All Microsoft Customer Agreement (MCA) reservation usage
- Enterprise Agreement (EA) reservation usage when cost allocation is enabled
- EA and MCA Marketplace charges

This is documented behavior, not a bug. The workaround is to join cost data with price sheet data, which FinOps toolkit does automatically when price data is available.

<br>

## Verify price data is available

### Step 1: Confirm price sheet exports exist

For Microsoft Customer Agreement (MCA) accounts:

1. Navigate to **Cost Management + Billing** in the Azure portal
2. Select your **billing profile** (not billing account)
3. Go to **Exports** and verify you have a price sheet export configured
4. Check the export run history to confirm it has run successfully

For Enterprise Agreement (EA) accounts:

1. Navigate to **Cost Management + Billing** in the Azure portal  
2. Select your **billing account**
3. Go to **Exports** and verify you have a price sheet export configured
4. Check the export run history to confirm it has run successfully

> [!IMPORTANT]
> For MCA accounts, price sheet exports must use the billing profile scope, not the billing account scope. The scope should look like: `/providers/Microsoft.Billing/billingAccounts/{billingAccountId}/billingProfiles/{billingProfileId}`

### Step 2: Verify export order

Price sheet data must be exported and ingested **before** cost data for each billing period. This ensures the price join can populate missing ContractedCost and ListCost values.

Recommended export order:
1. Price sheet (first)
2. Cost and usage (FOCUS)
3. Reservation details
4. Reservation recommendations
5. Reservation transactions

### Step 3: Check Data Explorer tables

If using FinOps hubs with Data Explorer, run this query to verify price data exists:

```kusto
// Check if prices exist for your billing profile and time period
Prices_final_v1_2
| where x_BillingProfileId == "YOUR_BILLING_PROFILE_ID"  // Replace with your actual billing profile ID
| where x_EffectivePeriodStart >= datetime(2025-08-01) and x_EffectivePeriodStart < datetime(2025-09-01)
| where x_SkuPriceType == 'Consumption'
| summarize PriceCount = count(), SampleMeters = make_set(x_SkuMeterId, 10) by x_BillingProfileId, Month = substring(x_EffectivePeriodStart, 0, 7)
```

Expected results:
- Should return rows for your billing profile ID
- Should show prices for the months you're analyzing
- Should show multiple meters with Consumption price type

If this query returns no results, your price sheet data was not exported or ingested correctly.

<br>

## Diagnose price join failures

Even when price data exists, the join may fail due to mismatched keys. Run this diagnostic query to identify the issue:

```kusto
// Find reservation costs that are missing prices
let reservationCosts = Costs_final_v1_2
| where BillingPeriodStart >= datetime(2025-08-01) and BillingPeriodStart < datetime(2025-09-01)
| where CommitmentDiscountType == "Reservation"
| where ChargeCategory == "Usage"
| extend CostLookupKey = tolower(strcat(x_BillingProfileId, substring(ChargePeriodStart, 0, 7), x_SkuMeterId, x_SkuOfferId))
| summarize 
    CostRows = count(),
    SampleCostLookupKey = any(CostLookupKey),
    MissingPrices = countif(x_SourceChanges contains "MissingContractedCost" or x_SourceChanges contains "MissingListCost")
  by x_BillingProfileId, x_SkuMeterId, x_SkuOfferId, Month = substring(ChargePeriodStart, 0, 7);

// Check if matching prices exist
let prices = Prices_final_v1_2
| where x_SkuPriceType == 'Consumption'
| extend PriceLookupKey = tolower(strcat(x_BillingProfileId, substring(x_EffectivePeriodStart, 0, 7), x_SkuMeterId, x_SkuOfferId))
| summarize 
    PriceRows = count(),
    SamplePriceLookupKey = any(PriceLookupKey),
    SampleListPrice = any(ListUnitPrice),
    SampleContractedPrice = any(ContractedUnitPrice)
  by x_BillingProfileId, x_SkuMeterId, x_SkuOfferId, Month = substring(x_EffectivePeriodStart, 0, 7);

// Compare
reservationCosts
| join kind=leftouter (prices) on x_BillingProfileId, x_SkuMeterId, x_SkuOfferId, Month
| project 
    x_BillingProfileId, 
    x_SkuMeterId, 
    x_SkuOfferId, 
    Month,
    CostRows,
    MissingPrices,
    PriceRows,
    HasMatchingPrice = isnotnull(PriceRows),
    SampleCostLookupKey,
    SamplePriceLookupKey,
    SampleListPrice,
    SampleContractedPrice
| order by HasMatchingPrice asc, MissingPrices desc
```

This query shows:
- Which reservation meters have cost data
- Whether matching prices exist for those meters
- How many rows are missing prices
- Sample lookup keys for debugging

Common issues identified by this query:
- **HasMatchingPrice = false**: Price sheet is missing prices for these meters
- **PriceRows = 0**: No prices exist for this meter/month combination
- **SampleListPrice or SampleContractedPrice = 0**: Prices exist but are zero

<br>

## Resolution steps

### Issue: No price sheet exports

**Solution**: Create and run price sheet exports

1. Navigate to the appropriate scope (billing profile for MCA, billing account for EA)
2. Create a new export with:
   - Dataset: Price sheet
   - Frequency: Monthly export of last month's costs
   - Format: CSV or Parquet
3. Manually run the export for historical months using "Export selected dates"
4. Wait for Data Explorer ingestion pipeline to complete

### Issue: Price exports exist but use wrong scope

**Solution**: Create exports at the correct scope

For MCA accounts, price sheet exports must use the billing profile scope:
- ✅ Correct: `/providers/Microsoft.Billing/billingAccounts/{id}/billingProfiles/{id}`
- ❌ Incorrect: `/providers/Microsoft.Billing/billingAccounts/{id}`

Delete the incorrect export and create a new one at the billing profile level.

### Issue: Prices exported after costs

**Solution**: Re-export data in the correct order

1. Export price sheet for the affected months
2. Wait for price ingestion to complete
3. Re-export cost data for the same months
4. Wait for cost ingestion to complete

The cost ingestion will now join with the available price data.

### Issue: Prices missing for specific meters

**Solution**: Verify meter eligibility and pricing

Some meters may not have Consumption-type prices in the price sheet:
- Marketplace services (priced by third-party vendors)
- Services with custom pricing agreements
- Preview or private offer services

For these scenarios, ContractedCost and ListCost will remain zero, which is expected.

<br>

## Verify the fix

After implementing the resolution steps, verify that savings are now calculated correctly:

```kusto
// Verify reservation savings are calculated
Costs_final_v1_2
| where BillingPeriodStart >= datetime(2025-08-01) and BillingPeriodStart < datetime(2025-09-01)
| where CommitmentDiscountType == "Reservation"
| where ChargeCategory == "Usage"
| summarize 
    TotalRows = count(),
    RowsWithSavings = countif(x_CommitmentDiscountSavings > 0),
    RowsMissingPrices = countif(x_SourceChanges contains "MissingContractedCost"),
    AvgEffectiveCost = avg(EffectiveCost),
    AvgContractedCost = avg(ContractedCost),
    AvgListCost = avg(ListCost),
    TotalSavings = sum(x_CommitmentDiscountSavings)
```

Expected results after fix:
- RowsWithSavings > 0 (showing actual savings)
- RowsMissingPrices = 0 (no missing price errors)
- AvgContractedCost > AvgEffectiveCost (showing the discount)
- TotalSavings > 0 (positive savings amount)

<br>

## Related content

- [Understanding savings calculations](./savings-calculations.md)
- [FOCUS conformance summary](https://learn.microsoft.com/cloud-computing/finops/focus/conformance-summary)
- [Configure scopes for FinOps hubs](./configure-scopes.md)
- [Deploy FinOps hubs](./deploy.md)
- [Troubleshoot common FinOps toolkit errors](../help/errors.md)

<br>
