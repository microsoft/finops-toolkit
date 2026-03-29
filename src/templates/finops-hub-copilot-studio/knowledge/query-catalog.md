# FinOps Hub KQL query catalog

This document contains ready-to-use KQL query patterns for common FinOps analysis tasks. Use these as templates when answering cost questions. Always execute queries via the Kusto MCP tool — never answer from this document alone.

All queries use the `Costs_v1_2()` function unless noted otherwise.

## Top resource groups by cost

```kusto
let N = 5;
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by SubAccountName, x_ResourceGroupName
| top N by EffectiveCost desc
```

## Top services by cost

```kusto
let N = 10;
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by ServiceName
| top N by EffectiveCost desc
```

## Monthly cost trend

```kusto
let startDate = startofmonth(ago(365d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize BilledCost = sum(BilledCost), EffectiveCost = sum(EffectiveCost)
    by x_ChargeMonth = startofmonth(ChargePeriodStart)
| order by x_ChargeMonth asc
```

## Month-over-month cost change percentage

```kusto
let startDate = startofmonth(ago(390d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize BilledCost = sum(BilledCost), EffectiveCost = sum(EffectiveCost)
    by ChargePeriodStart = startofmonth(ChargePeriodStart)
| order by ChargePeriodStart asc
| extend PreviousBilledCost = prev(BilledCost), PreviousEffectiveCost = prev(EffectiveCost)
| project ChargePeriodStart,
    BilledCostChangePct = iff(isempty(PreviousBilledCost), 0.0, toreal((BilledCost - PreviousBilledCost) * 100.0 / PreviousBilledCost)),
    EffectiveCostChangePct = iff(isempty(PreviousEffectiveCost), 0.0, toreal((EffectiveCost - PreviousEffectiveCost) * 100.0 / PreviousEffectiveCost))
```

## Cost anomaly detection

Uses Data Explorer time series decomposition to detect spikes and drops.

```kusto
let numberOfMonths = 12;
let start = startofmonth(ago(numberOfMonths * 30d));
let end = now();
let interval = 1d;
Costs_v1_2()
| where ChargePeriodStart between (start .. end)
| summarize DailyCost = sum(EffectiveCost) by bin(ChargePeriodStart, interval)
| make-series CostSeries = sum(DailyCost) on ChargePeriodStart from start to end step interval
| extend anomalies = series_decompose_anomalies(CostSeries)
| project ChargePeriodStart, CostSeries, anomalies
| render timechart
```

## Cost forecasting

Uses Data Explorer time series forecasting to project future spend.

```kusto
let startDate = startofmonth(ago(365d));
let endDate = startofmonth(now());
let forecastPeriods = 90;
let interval = 1d;
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by bin(ChargePeriodStart, interval)
| make-series EffectiveCostSeries = sum(EffectiveCost) on ChargePeriodStart from startDate to endDate step interval
| extend forecast = series_decompose_forecast(EffectiveCostSeries, forecastPeriods)
| project ChargePeriodStart, EffectiveCostSeries, forecast
```

## Savings summary with Effective Savings Rate (ESR)

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory))
| extend x_NegotiatedDiscountSavings = iff(ListCost < ContractedCost, decimal(0), ListCost - ContractedCost)
| extend x_CommitmentDiscountSavings = iff(ContractedCost < EffectiveCost, decimal(0), ContractedCost - EffectiveCost)
| extend x_TotalSavings = iff(ListCost < EffectiveCost, decimal(0), ListCost - EffectiveCost)
| summarize
    ListCost = todouble(sum(ListCost)),
    EffectiveCost = todouble(sum(EffectiveCost)),
    x_NegotiatedDiscountSavings = todouble(sum(x_NegotiatedDiscountSavings)),
    x_CommitmentDiscountSavings = todouble(sum(x_CommitmentDiscountSavings)),
    x_TotalSavings = todouble(sum(x_TotalSavings))
    by BillingCurrency
| extend x_EffectiveSavingsRate = iff(ListCost == 0, 0.0, x_TotalSavings / ListCost * 100.0)
```

## Commitment discount utilization

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
let base = Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| extend x_SkuCoreCount = toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, 0))
| extend x_ConsumedCoreHours = iff(isnotempty(x_SkuCoreCount), x_SkuCoreCount * ConsumedQuantity, todecimal(''));
let total = base | summarize Total = todecimal(sum(x_ConsumedCoreHours));
base
| summarize TotalConsumedCoreHours = todecimal(sum(x_ConsumedCoreHours)) by CommitmentDiscountType
| extend CommitmentDiscountType = iff(isempty(CommitmentDiscountType), 'On Demand', CommitmentDiscountType)
| extend PercentOfTotal = 100.0 * TotalConsumedCoreHours / toscalar(total)
| project CommitmentDiscountType, TotalConsumedCoreHours = todouble(TotalConsumedCoreHours), PercentOfTotal = todouble(PercentOfTotal)
| order by PercentOfTotal desc
```

## Service price benchmarking

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| extend
    x_CommitmentDiscountSavings = iif(ContractedCost == 0.0, 0.0, toreal(ContractedCost - EffectiveCost)),
    x_NegotiatedDiscountSavings = iif(ListCost == 0.0, 0.0, toreal(ListCost - ContractedCost)),
    x_TotalSavings = iif(ListCost == 0.0, 0.0, toreal(ListCost - EffectiveCost))
| summarize
    ListCost = round(sum(toreal(ListCost)), 0),
    ContractedCost = round(sum(toreal(ContractedCost)), 0),
    EffectiveCost = round(sum(toreal(EffectiveCost)), 0),
    NegotiatedSavings = round(sum(x_NegotiatedDiscountSavings), 0),
    CommitmentSavings = round(sum(x_CommitmentDiscountSavings), 0),
    TotalSavings = round(sum(x_TotalSavings), 0)
    by ServiceName
| order by TotalSavings desc
```

## Cost by region

```kusto
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize EffectiveCost = sum(EffectiveCost) by RegionName
| order by EffectiveCost desc
```

## Cost by financial hierarchy

Uses tag-based hierarchy: billing profile, invoice section, team, product, application.

```kusto
let N = 5;
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
let GrandTotal = toscalar(
    Costs_v1_2()
    | where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
    | summarize sum(toreal(EffectiveCost))
);
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| extend x_Team = tostring(Tags['team']), x_Product = tostring(Tags['product']),
    x_Application = tostring(Tags['application']), x_Environment = tostring(Tags['environment'])
| summarize EffectiveCost = sum(toreal(EffectiveCost))
    by x_BillingProfileName, x_InvoiceSectionName, x_Team, x_Product, x_Application, x_Environment
| extend PercentOfTotal = 100.0 * EffectiveCost / GrandTotal
| order by EffectiveCost desc
| top N by EffectiveCost
```

## Top resource types by cost

```kusto
let N = 10;
let startDate = startofmonth(ago(30d));
let endDate = startofmonth(now());
Costs_v1_2()
| where ChargePeriodStart >= startDate and ChargePeriodStart < endDate
| summarize ResourceCount = count(), EffectiveCost = sum(EffectiveCost) by ResourceType
| top N by EffectiveCost desc
```

## Reservation recommendations

Uses the `Recommendations()` function (not Costs).

```kusto
Recommendations()
| where x_SourceProvider == 'Microsoft' and x_SourceType == 'ReservationRecommendations'
| extend RegionId = tostring(x_RecommendationDetails.RegionId)
| extend RegionName = tostring(x_RecommendationDetails.RegionName)
| extend x_CommitmentDiscountSavings = x_EffectiveCostBefore - x_EffectiveCostAfter
| extend x_SkuTerm = toint(x_RecommendationDetails.SkuTerm)
| extend x_BreakEvenMonths = x_EffectiveCostAfter * x_SkuTerm / x_EffectiveCostBefore
| project
    RegionName = iff(isempty(RegionName), RegionId, RegionName),
    x_CommitmentDiscountSavings = toreal(x_CommitmentDiscountSavings),
    x_CommitmentDiscountPercent = toreal(1.0 * x_CommitmentDiscountSavings / x_EffectiveCostBefore * 100),
    x_BreakEvenMonths = toreal(x_BreakEvenMonths),
    x_SkuTerm = toreal(x_SkuTerm),
    x_RecommendedQuantity = toreal(x_RecommendationDetails.RecommendedQuantity),
    x_EffectiveCostBefore = toreal(x_EffectiveCostBefore),
    x_EffectiveCostAfter = toreal(x_EffectiveCostAfter)
| top 10 by x_CommitmentDiscountSavings
```
