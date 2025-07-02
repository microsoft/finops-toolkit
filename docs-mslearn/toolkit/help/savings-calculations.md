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
- **List prices** (public retail rates)
- **Contracted prices** (after negotiated discounts)
- **Effective prices** (after all discounts including commitments)

<br>

## Negative savings behavior

### When negative savings occur

**Negative savings are displayed when the effective price paid is higher than the list price or negotiated price.** This indicates the resource cost more than standard pricing, which can happen due to:

- Pricing misconfigurations
- Unusual billing conditions
- Data quality issues in Cost Management
- Commitment discounts that provide less savings than negotiated rates

### Why show negative savings

Negative savings are displayed as negative numbers (for example, -$100) because they reflect the reality of your cost data. Hiding or zeroing these values would:

- Mask real cost concerns that need investigation
- Prevent identification of pricing anomalies
- Reduce transparency in cost reporting

**Example**: If you have a list price of $100 but paid $120 effective cost, the savings would show as -$20, indicating you overpaid by $20.

<br>

## Zero savings behavior

### When zero savings occur

**Zero savings are displayed when no reliable price comparison can be made.** This happens when:

- List prices are missing or null
- Contracted prices are missing or null  
- Reference prices are zero or invalid

### Why show zero savings for missing prices

When price data is missing, there's no reliable basis for calculating savings. Showing zero ensures:

- Mathematical consistency in totals and aggregations
- No misleading information is presented
- Clear indication that savings couldn't be determined

**Example**: If list price data is missing but you paid $80 effective cost, savings show as $0 because we cannot determine if you saved money or overpaid.

<br>

## Savings calculation examples

The following table shows how different price scenarios are handled:

| List Price | Effective Price | Savings Displayed | Explanation |
|------------|-----------------|-------------------|-------------|
| 100        | 100             | 0                 | No discount applied |
| 100        | 80              | 20                | Standard savings of $20 |
| 100        | 120             | -20               | Negative savings - overpaid by $20 |
| *Missing*  | 80              | 0                 | Cannot calculate savings without list price |
| 100        | *Missing*       | 0                 | Cannot calculate savings without effective price |

<br>

## Impact on totals and aggregations

### Including negative savings in totals

When negative savings are included in aggregated totals:
- Totals reflect the actual sum of all items (including negative values)
- Overall savings may be lower than expected due to negative contributions
- This provides an accurate view of your total cost optimization impact

### Including zero savings in totals

When prices are missing and zero savings are shown:
- Totals will be lower than the complete savings picture
- This is expected behavior and indicates incomplete price data
- Consider exporting price sheets to get complete savings calculations

<br>

## Interpreting your results

### For negative savings

If you see negative savings in your reports:

1. **Investigate the cause** - Check for pricing misconfigurations or billing issues
2. **Review commitment utilization** - Ensure you're not paying for unused commitments
3. **Validate data quality** - Confirm Cost Management data is accurate
4. **Consider optimization** - Evaluate if commitment discounts are providing value

### For zero savings

If you see many zero savings values:

1. **Export price data** - Use Cost Management price sheet exports to populate missing prices
2. **Enable price population** - In storage reports, enable "Experimental: Populate Missing Prices" parameter
3. **Use FinOps hubs** - FinOps hubs with Data Explorer automatically populate missing prices when available

<br>

## User interface guidance

When displaying savings in reports or dashboards, consider adding contextual information:

### For negative savings display

> **ℹ️ Note**: Savings may appear negative if the effective price is higher than the list or negotiated price. This may indicate pricing misconfigurations or unexpected billing conditions. [Learn more about savings calculations](savings-calculations.md).

### For zero savings display  

> **ℹ️ Note**: Savings show as zero when price data is missing or incomplete. Export price sheets or use FinOps hubs to get complete savings calculations. [Learn more about savings calculations](savings-calculations.md).

<br>

## Related errors and troubleshooting

Several error codes in FinOps toolkit relate to missing price data that affects savings calculations:

- [`MissingListUnitPrice`](errors.md#missinglistunitprice) - List prices missing, preventing savings calculation
- [`MissingContractedUnitPrice`](errors.md#missingcontractedunitprice) - Contracted prices missing, preventing savings calculation  
- [`MissingListCost`](errors.md#missinglistcost) - List cost values missing
- [`MissingContractedCost`](errors.md#missingcontractedcost) - Contracted cost values missing
- [`ListCostLessThanContractedCost`](errors.md#listcostlessthancontractedcost) - Data quality issue causing invalid savings
- [`ContractedCostLessThanEffectiveCost`](errors.md#contractedcostlessthaneffectivecost) - Data quality issue causing negative savings

For troubleshooting these issues, see [Troubleshoot common FinOps toolkit errors](errors.md).

<br>

## Give feedback

Let us know how we're doing with a quick review. We use these reviews to improve and expand FinOps tools and resources.

> [!div class="nextstepaction"]
> [Give feedback](https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20understand%20savings%20calculations%20in%20FinOps%20toolkit%20reports%3F/cvaQuestion/How%20valuable%20is%20the%20savings%20calculations%20documentation%3F/surveyId/FTK0.11/bladeName/Toolkit/featureName/Help.SavingsCalculations)

<br>

## Related content

Related resources:

- [Troubleshoot common FinOps toolkit errors](errors.md)
- [Data dictionary](data-dictionary.md)
- [Common terms](terms.md)

Related reports:

- [Rate optimization report](../power-bi/rate-optimization.md)
- [Cost summary report](../power-bi/cost-summary.md)

Related solutions:

- [FinOps hubs](../hubs/finops-hubs-overview.md)
- [Cost Management exports](/azure/cost-management-billing/costs/tutorial-export-acm-data)

<br>