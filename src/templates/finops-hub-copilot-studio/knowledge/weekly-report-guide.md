# Weekly cost anomaly report guide

This guide defines the workflow for producing a structured weekly cost anomaly report. Follow these steps when the user asks for a weekly report, weekly summary, or anomaly review.

**IMPORTANT: This is a workflow guide. Execute all queries via the Kusto MCP tool — never return this document as an answer.**

## Date boundaries

Use these for all queries in the report:

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
```

## Queries to run

All queries filter `ChargeCategory == "Usage" and x_PublisherCategory == "Cloud Provider"` unless noted otherwise.

### Q1: Weekly cost total

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
    and ChargeCategory == "Usage" and x_PublisherCategory == "Cloud Provider"
| summarize Cost = round(sum(EffectiveCost), 2), Days = dcount(ChargePeriodStart)
    by Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| extend DailyAvg = round(Cost / Days, 2)
```

### Q2: Category summary (top movers)

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
    and ChargeCategory == "Usage" and x_PublisherCategory == "Cloud Provider"
| extend Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| summarize Cost = round(sum(EffectiveCost), 2) by x_SkuMeterCategory, Week
| evaluate pivot(Week, sum(Cost))
| extend Change = round(LastWeek - PriorWeek, 2),
    ChangePct = round((LastWeek - PriorWeek) / iff(PriorWeek == 0, real(null), PriorWeek) * 100, 1)
| where abs(Change) > 50 or abs(ChangePct) > 20
| order by Change desc
```

### Q3: Resource increases

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
    and ChargeCategory == "Usage" and x_PublisherCategory == "Cloud Provider"
| extend Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| summarize Cost = round(sum(EffectiveCost), 2)
    by ResourceId, ResourceName, x_ResourceGroupName, x_SkuMeterCategory, Week
| evaluate pivot(Week, sum(Cost))
| extend Change = round(LastWeek - PriorWeek, 2),
    ChangePct = round((LastWeek - PriorWeek) / iff(PriorWeek == 0, real(null), PriorWeek) * 100, 1)
| where LastWeek > 50 and (ChangePct > 50 or Change > 100)
| order by Change desc
```

### Q4: Resource decreases

Same as Q3 but filter for decreases:

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
    and ChargeCategory == "Usage" and x_PublisherCategory == "Cloud Provider"
| extend Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| summarize Cost = round(sum(EffectiveCost), 2)
    by ResourceId, ResourceName, x_ResourceGroupName, x_SkuMeterCategory, Week
| evaluate pivot(Week, sum(Cost))
| extend Change = round(LastWeek - PriorWeek, 2),
    ChangePct = round((LastWeek - PriorWeek) / iff(PriorWeek == 0, real(null), PriorWeek) * 100, 1)
| where PriorWeek > 50 and (ChangePct < -50 or Change < -100)
| order by Change asc
```

### Q5: Commitment coverage drops

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
| extend Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| summarize
    Total = round(sum(EffectiveCost), 2),
    RICost = round(sumif(EffectiveCost, CommitmentDiscountStatus == "Used"), 2),
    Savings = round(sum(x_CommitmentDiscountSavings), 2)
    by ResourceId, ResourceName, x_ResourceGroupName, x_SkuMeterCategory, Week
| extend CovPct = round(RICost / iff(Total == 0, real(null), Total) * 100, 1)
| evaluate pivot(Week, take_any(Total), take_any(RICost), take_any(CovPct), take_any(Savings))
| where PriorWeek_CovPct > 30 and PriorWeek_Total > 50
    and (PriorWeek_CovPct - LastWeek_CovPct) > 30
| extend MonthlySavingsAtRisk = round((PriorWeek_Savings - LastWeek_Savings) * 4.33, 2)
| order by MonthlySavingsAtRisk desc
```

### Q6: Marketplace usage

```kusto
let LastWeekEnd = startofweek(now());
let LastWeekStart = datetime_add('day', -7, LastWeekEnd);
let PriorWeekStart = datetime_add('day', -14, LastWeekEnd);
Costs_v1_2()
| where ChargePeriodStart >= PriorWeekStart and ChargePeriodStart < LastWeekEnd
    and x_PublisherCategory == "Vendor" and ChargeCategory == "Usage"
| extend Week = iff(ChargePeriodStart >= LastWeekStart, "LastWeek", "PriorWeek")
| summarize Cost = round(sum(EffectiveCost), 2)
    by ResourceId, ResourceName, x_ResourceGroupName, PublisherName, Week
| evaluate pivot(Week, sum(Cost))
| where LastWeek > 10
| order by LastWeek desc
```

### Q7: Marketplace purchases (13-month lookback)

```kusto
Costs_v1_2()
| where ChargePeriodStart >= datetime_add('month', -13, startofmonth(now()))
    and ChargeCategory == "Purchase" and x_PublisherCategory == "Vendor"
| summarize Cost = round(sum(EffectiveCost), 2)
    by BillingMonth = startofmonth(ChargePeriodStart), PublisherName
| where Cost >= 10
| order by PublisherName asc, BillingMonth asc
```

Classify each publisher by frequency: 10+ months = Monthly recurring, 3-9 months = Intermittent, 2 months = Annual, 1 month (current) = New, 1 month (older) = One-time.

## Post-processing rules

### Cross-reference coverage drops with increases

If a ResourceId appears in both Q3 (increases) and Q5 (coverage drops):
- Remove it from the increases table.
- Label it "RI/SP expired" in the coverage section.
- Add a summary note: "N resources saw +$X/week due to expired commitments."

### Group by resource group

- 5+ resources with same direction in same RG → consolidate to one line: "~N resources in `rg-name`, total +$X/week"
- 3-4 resources with same pattern → shared subheading
- Fewer than 3 or mixed direction → list individually

### Severity classification

**New resources** (PriorWeek is null or 0):
- Major: >$200/week
- Minor: >$50/week
- Watch: below $50/week

**Existing resources:**
- Major: abs(Change) > $200, OR abs(ChangePct) > 100% AND LastWeek > $100
- Minor: abs(Change) > $50
- Watch: below thresholds

Show Major and Minor in main tables. Collect Watch items in a separate sub-table.

## Report structure

Present the report in this order:

1. **Total cost summary** — last week vs prior week, daily average, overall change
2. **Category summary** — top movers by service category with key driver bullets
3. **Commitment coverage changes** — if any; include prior/current coverage %, monthly savings at risk, recommendation to renew
4. **Major increases** — resource-level, grouped by RG where applicable
5. **Significant decreases** — resource-level, grouped by RG
6. **Marketplace** — usage changes + purchases classified by pattern (monthly/intermittent/new/one-time)
7. **Action items** — prioritized list of recommended follow-ups
