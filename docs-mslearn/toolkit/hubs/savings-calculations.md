---
title: Understanding savings calculations in FinOps toolkit
description: Learn how savings values are calculated and displayed in FinOps toolkit reports, including negative savings and missing price scenarios.
author: flanakin
ms.author: micflan
ms.date: 12/02/2024
ms.topic: concept-article
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps user, I want to understand how savings calculations work in FinOps toolkit reports so that I can interpret negative savings and zero savings correctly.
---

<!-- cSpell:ignore nextstepaction -->
<!-- markdownlint-disable-next-line MD025 -->
# Understanding savings calculations in FinOps toolkit

FinOps toolkit reports calculate savings by comparing different cost values to help you understand your optimization opportunities and actual savings achieved. This article explains how savings values are calculated and displayed, particularly for scenarios involving negative savings or missing price data.

Understanding these calculations is essential for correctly interpreting cost optimization reports and building trust in the data presented.

<br>

## How savings are calculated

Savings calculations in FinOps toolkit reports compare different cost values:

- **Negotiated discount savings** = List cost - Contracted cost
- **Commitment discount savings** = Contracted cost - Effective cost  
- **Total savings** = List cost - Effective cost

These calculations depend on having accurate price data for:

- **List prices** (public retail rates).
- **Contracted prices** (after negotiated discounts).
- **Effective prices** (after all discounts including commitments).

<br>

## Negative savings behavior

**Negative savings are displayed when the effective price paid is higher than the list price or contracted (negotiated) price.** This indicates the resource cost more than standard pricing, which can happen due to:

- Pricing misconfigurations.
- Unusual billing conditions.
- Data quality issues in Cost Management.
- Commitment discounts that provide less savings than negotiated discounts.

Negative savings are displayed as negative numbers (for example, -$100) because they reflect the reality of your cost data. Hiding or zeroing these values would:

- Mask real cost concerns that need investigation.
- Prevent identification of pricing anomalies.
- Reduce transparency in cost reporting.

**Example**: If you have a list price of $100 but paid $120 effective cost, the savings would show as -$20, indicating you overpaid by $20.

<br>

## Zero savings behavior

**Zero savings are displayed when no reliable price comparison can be made.** This happens when:

- List prices are missing or null.
- Contracted prices are missing or null.  
- Reference prices are zero or invalid.

When price data is missing, there's no reliable basis for calculating savings.

**Example**: If list price data is missing but you paid $80 effective cost, savings show as $0 because we cannot determine if you saved money or overpaid.

<br>

## Savings calculation examples

The following table shows how different price scenarios are handled:

| List Price | Effective Price | Savings Displayed | Explanation |
|-----------:|----------------:|------------------:|-------------|
| 100        | 100             | 0                 | No discount applied |
| 100        | 80              | 20                | Standard savings of $20 |
| 100        | 120             | -20               | Negative savings - overpaid by $20 |
| *Missing*  | 80              | 0                 | Cannot calculate savings without list price |
| 100        | *Missing*       | 0                 | Cannot calculate savings without effective price |

<br>

## Impact on totals and aggregations

When you see negative savings in aggregated totals:

- Some rows may be missing ListCost or ContractedCost.
- Effective cost may be higher than your contracted cost for some commitment discounts.

When prices are missing and zero savings are shown:

- Totals will be lower than the complete savings picture.
- This is expected behavior and indicates incomplete price data.
- Consider exporting the price sheet and re-ingesting costs for more complete savings calculations.

<br>

## Interpreting your results

If you see negative savings in your reports:

1. **Investigate the cause** - Check for pricing misconfigurations or billing issues.
2. **Review commitment utilization** - Ensure you're not paying for unused commitments.
3. **Validate data quality** - Confirm Cost Management data is accurate.
4. **Consider optimization** - Evaluate if commitment discounts are providing value.

Use this KQL query in Data Explorer to identify specific scenarios causing negative savings:

```kusto
Costs
| extend EffectiveOverContracted = iff(ContractedCost < EffectiveCost, ContractedCost - EffectiveCost, decimal(0))
| extend ContractedOverList      = iff(ListCost < ContractedCost,      ListCost - ContractedCost,      decimal(0))
| extend EffectiveOverList       = iff(ListCost < EffectiveCost,       ListCost - EffectiveCost,       decimal(0))
| extend scenario = case(
    ListCost == 0 and CommitmentDiscountCategory == 'Usage' and ChargeCategory == 'Usage', 'Reservation usage missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Usage' and ChargeCategory == 'Purchase', 'Reservation purchase missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Spend' and ChargeCategory == 'Usage', 'Savings plan usage missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Spend' and ChargeCategory == 'Purchase', 'Savings plan purchase missing list',
    ListCost == 0 and ChargeCategory == 'Purchase', 'Other purchase missing list',
    isnotempty(CommitmentDiscountStatus) and ContractedOverList == 0 and EffectiveOverContracted < 0, 'Commitment cost over contracted',
    ListCost == 0 and BilledCost == 0 and EffectiveCost == 0 and ContractedCost > 0 and x_SourceChanges !contains 'MissingContractedCost', 'ContractedCost should be 0',
    ListCost == 0 and ContractedCost == 0 and BilledCost > 0 and EffectiveCost > 0 and x_PublisherCategory == 'Vendor' and ChargeCategory == 'Usage', 'Marketplace usage missing list/contracted',
    ContractedOverList < 0 and EffectiveOverContracted == 0 and x_SourceChanges !contains 'MissingListCost', 'ListCost too low',
    ContractedUnitPrice == x_EffectiveUnitPrice and EffectiveOverContracted < 0 and x_SourceChanges !contains 'MissingContractedCost', 'ContractedCost doesn''t match price',
    EffectiveOverContracted != 0 and abs(EffectiveOverContracted) < 0.00000001, 'Rounding error',
    ContractedOverList != 0 and abs(ContractedOverList) < 0.00000001, 'Rounding error',
    EffectiveOverList != 0 and abs(EffectiveOverList) < 0.00000001, 'Rounding error',
    ContractedCost < EffectiveCost or ListCost < ContractedCost or ListCost < EffectiveCost, '',
    EffectiveCost <= ContractedCost and ContractedCost <= ListCost, 'Good',
    '')
| project-reorder ListCost, ContractedCost, BilledCost, EffectiveCost, EffectiveOverList, EffectiveOverContracted, ContractedOverList, x_SourceChanges, ListUnitPrice, ContractedUnitPrice, x_BilledUnitPrice, x_EffectiveUnitPrice, CommitmentDiscountStatus, PricingQuantity, PricingUnit, x_PricingBlockSize, x_PricingUnitDescription
| summarize count(), EffectiveOverContracted = sum(EffectiveOverContracted), ContractedOverList = sum(ContractedOverList), EffectiveOverList = sum(EffectiveOverList), Type = arraystring(make_set(x_BillingAccountAgreement)) by scenario
```

This query categorizes different scenarios that can cause negative savings and helps identify the root cause of pricing discrepancies.

If you see many zero savings values:

1. **Export price data** - Use Cost Management price sheet exports to populate missing prices.
2. **Enable price population** - In storage reports, enable "Experimental: Populate Missing Prices" parameter.
3. **Use FinOps hubs** - FinOps hubs with Data Explorer automatically populate missing prices when available.

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20savings%20calculations%20in%20FinOps%20toolkit%20reports%3F/cvaQuestion/How%20valuable%20is%20the%20savings%20calculations%20documentation%3F/surveyId/FTK/bladeName/Hubs/featureName/SavingsCalculations)

<br>

## Related content

- [Troubleshoot common FinOps toolkit errors](../help/errors.md)
- [Data dictionary](../help/data-dictionary.md)
- [Common terms](../help/terms.md)
- [FinOps toolkit Power BI reports](../power-bi/reports.md)

<br>