# FinOps Hub Dashboard KQL Queries

This document contains all the KQL (Kusto Query Language) queries used in the FinOps Hub dashboard. Each query is accompanied by a description of its purpose.

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Cost Overview and Summaries](#cost-overview-and-summaries)
- [Time-based Cost Analysis](#time-based-cost-analysis)
- [Resource and Service Breakdowns](#resource-and-service-breakdowns)
- [Savings and Discount Analysis](#savings-and-discount-analysis)
- [Commitment Discount Analysis](#commitment-discount-analysis)
- [Azure Hybrid Benefit Analysis](#azure-hybrid-benefit-analysis)
- [FinOps Hub Infrastructure](#finops-hub-infrastructure)
- [Data Ingestion and Quality](#data-ingestion-and-quality)
- [Helper and Utility Queries](#helper-and-utility-queries)

## Cost Overview and Summaries

### Cost Summary Last Month

```kusto
let monthname = dynamic(['(ignore)', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
let costs = materialize(
    CostsLastMonth
    | summarize BilledCost = round(sum(BilledCost), 2), EffectiveCost = round(sum(EffectiveCost), 2) by BillingPeriodStart = startofmonth(BillingPeriodStart)
    | extend json = todynamic(strcat('[{"type":"Billed cost", "Cost":', BilledCost, '}, {"type":"Effective cost", "Cost":', EffectiveCost, '}]'))
    | mv-expand json
    | project Type = strcat(json.type, ' (', monthname[monthofyear(BillingPeriodStart)], ' ', format_datetime(BillingPeriodStart, 'yyyy'), ')'), Cost = todouble(json.Cost)
);
costs
```

**Description**: Summarizes billed and effective costs for the last month, formatting the values with month names.

### Resource Counts Last Month

```kusto
let data = materialize(
    CostsLastMonth
    | summarize
        Subscriptions = dcount(SubAccountId),
        ResourceGroups = dcount(strcat(SubAccountId, x_ResourceGroupName)),
        Resources = dcount(ResourceId),
        Services = dcount(ServiceName)
    | project json = todynamic(strcat('[{ "Type":"Subscriptions", "Count":', Subscriptions, ' }, { "Type":"Resource groups", "Count":', ResourceGroups, ' }, { "Type":"Resources", "Count":', Resources, ' }, { "Type":"Services", "Count":', Services, ' }]'))
    | mv-expand json
    | project Label = tostring(json.Type), Count = tolong(json.Count)
);
data
```

**Description**: Counts the number of unique subscriptions, resource groups, resources, and services from last month's data.

### Resource Counts Last N Days

```kusto
let data = materialize(
    CostsByDay
    | summarize
        Subscriptions = dcount(SubAccountId),
        ResourceGroups = dcount(strcat(SubAccountId, x_ResourceGroupName)),
        Resources = dcount(ResourceId),
        Services = dcount(ServiceName)
    | project json = todynamic(strcat('[{ "Type":"Subscriptions", "Count":', Subscriptions, ' }, { "Type":"Resource groups", "Count":', ResourceGroups, ' }, { "Type":"Resources", "Count":', Resources, ' }, { "Type":"Services", "Count":', Services, ' }]'))
    | mv-expand json
    | project Label = tostring(json.Type), Count = tolong(json.Count)
);
data
```

**Description**: Similar to the previous query but for a configurable number of days instead of the last month.

### Cost and Savings Summary

```kusto
let data = materialize(
    CostsByMonth
    | summarize 
        BilledCost = sum(BilledCost),
        EffectiveCost = sum(EffectiveCost),
        ContractedCost = sum(ContractedCost),
        ListCost = sum(ListCost)
        by
        ChargePeriodStart
    | order by ChargePeriodStart asc
    | extend CommitmentDiscountSavings = ContractedCost - EffectiveCost
    | extend NegotiatedDiscountSavings = ListCost - ContractedCost
    | extend Month = monthname[monthofyear(ChargePeriodStart)]
    | project json = todynamic(strcat('[{ "Type":"Billed cost", "Count":', BilledCost, ' }, { "Type":"Effective cost", "Count":', EffectiveCost, ' }, { "Type":"Commitment savings", "Count":', CommitmentDiscountSavings, ' }, { "Type":"Negotiated savings", "Count":', NegotiatedDiscountSavings, ' }]')), Month, IsThisMonth = ChargePeriodStart >= startofmonth(now())
    | mv-expand json
    | project Label = strcat(json.Type, ' (', Month, ')'), Count = tolong(json.Count), IsThisMonth
);
data
```

**Description**: Calculates different types of costs and savings (billed, effective, commitment, negotiated), organized by month.

## Time-based Cost Analysis

### Monthly Cost Trend

```kusto
CostsByMonth
| summarize BilledCost = round(sum(BilledCost), 2), EffectiveCost = round(sum(EffectiveCost), 2) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| render timechart
```

**Description**: Shows the trend of billed and effective costs over the months.

### Monthly Cost Change Percentage

```kusto
CostsByMonth
| summarize BilledCost = sum(BilledCost), EffectiveCost = sum(EffectiveCost) by BillingPeriodStart = startofmonth(BillingPeriodStart)
| order by BillingPeriodStart asc
| extend PreviousBilledCost = prev(BilledCost)
| extend PreviousEffectiveCost = prev(EffectiveCost)
| project BillingPeriodStart
    , BilledCost = iif(isempty(PreviousBilledCost), todouble(0), todouble((BilledCost - PreviousBilledCost) * 100.0 / PreviousBilledCost))
    , EffectiveCost = iif(isempty(PreviousEffectiveCost), todouble(0), todouble((EffectiveCost - PreviousEffectiveCost) * 100.0 / PreviousEffectiveCost))
```

**Description**: Calculates the month-over-month percentage change in both billed and effective costs.

### 3-Month Running Total Trend

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsPlus
| where ChargePeriodStart >= startofmonth(ago(90d))
| summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart, Day = dayofmonth(ChargePeriodStart), Month = strcat(format_datetime(ChargePeriodStart, 'MM '), monthname[monthofyear(ChargePeriodStart)])
| order by ChargePeriodStart asc
| extend EffectiveCostRunningTotal = row_cumsum(EffectiveCost, prev(Month) != Month)
| project Day, EffectiveCostRunningTotal, Month
| render areachart  
```

**Description**: Displays a running total of effective costs over the last 3 months as an area chart.

### Running Total - This Month and Last

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsPlus
| where ChargePeriodStart >= startofmonth(startofmonth(now()) - 1d)
| summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart, Month = strcat(format_datetime(ChargePeriodStart, 'MM '), monthname[monthofyear(ChargePeriodStart)])
| order by ChargePeriodStart asc
| extend EffectiveCostRunningTotal = row_cumsum(EffectiveCost, prev(Month) != Month)
| project ChargePeriodStart, EffectiveCostRunningTotal, Month
| render areachart  
```

**Description**: Shows running totals of costs for the current and previous month for comparison.

### 3-Month Daily Trend

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsPlus
| where ChargePeriodStart >= startofmonth(ago(90d))
| summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart, Day = dayofmonth(ChargePeriodStart), Month = strcat(format_datetime(ChargePeriodStart, 'MM '), monthname[monthofyear(ChargePeriodStart)])
| order by ChargePeriodStart asc
| project Day, EffectiveCost, Month
| render columnchart
```

**Description**: Displays daily cost trends over the last 3 months as a column chart.

### Daily Trend by Subscription

```kusto
let costs = CostsPlus | where ChargePeriodStart >= startofmonth(ago(90d));
let all = costs | summarize sum(EffectiveCost) by SubAccountId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = SubAccountId in (topX)
| extend SubAccountId = iff(inTopX, SubAccountId, otherId)
| extend SubAccountName = iff(inTopX, SubAccountName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    SubAccountName = take_any(SubAccountName)
    by
    ChargePeriodStart,
    SubAccountId
| project ChargePeriodStart, EffectiveCost, Sub = iff(SubAccountId == otherId, SubAccountName, strcat(SubAccountName, ' (', split(SubAccountId, '/')[2], ')'))
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows daily costs broken down by subscription (top N subscriptions, with the rest grouped as "others").

### Cost Running Total with Savings

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsPlus
| where startofmonth(ChargePeriodStart) >= startofmonth(now(), -1)
| summarize 
    EffectiveCost = sum(EffectiveCost),
    ContractedCost = sum(ContractedCost),
    ListCost = sum(ListCost)
    by
    ChargePeriodStart,
    Month = strcat(format_datetime(ChargePeriodStart, 'MM '), monthname[monthofyear(ChargePeriodStart)])
| extend CommitmentDiscountSavings = ContractedCost - EffectiveCost
| extend NegotiatedDiscountSavings = ListCost - ContractedCost
| order by ChargePeriodStart asc
| extend EffectiveCostRunningTotal = row_cumsum(EffectiveCost, prev(Month) != Month)
| extend CommitmentDiscountSavingsRunningTotal = row_cumsum(CommitmentDiscountSavings, prev(Month) != Month)
| extend NegotiatedDiscountSavingsRunningTotal = row_cumsum(NegotiatedDiscountSavings, prev(Month) != Month)
| project ChargePeriodStart, CommitmentDiscountSavingsRunningTotal, NegotiatedDiscountSavingsRunningTotal, EffectiveCostRunningTotal, Month
| render areachart  
```

**Description**: Visualizes the running total of costs and both commitment and negotiated discount savings.

### Daily Trend with Change Percentage

```kusto
CostsByDay
| summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart = startofday(ChargePeriodStart)
| order by ChargePeriodStart asc
| extend PreviousEffectiveCost = prev(EffectiveCost)
| project ChargePeriodStart, EffectiveCost, Change = iif(isempty(PreviousEffectiveCost), todouble(0), todouble((EffectiveCost - PreviousEffectiveCost) / PreviousEffectiveCost)) * 100
```

**Description**: Shows daily effective costs along with day-over-day percentage changes.

### Cost Forecast

```kusto
let costs = CostsPlus | where ChargePeriodStart >= startofmonth(now(), -3) and ChargePeriodStart < startofday(ago(-1d));
let startOfPeriod = toscalar(costs | summarize min(startofday(ChargePeriodStart)));
let endOfPeriod = toscalar(costs | summarize max(startofday(ChargePeriodStart)));
let forecastHorizon = numberOfDays * 1d;
costs
| make-series
    EffectiveCost = sum(EffectiveCost)
    on ChargePeriodStart
    from startOfPeriod to endOfPeriod + forecastHorizon step 1d
| extend Forecast = series_decompose_forecast(EffectiveCost, numberOfDays)
```

**Description**: Generates a cost forecast for the next N days based on historical data from the past 3 months.

## Resource and Service Breakdowns

### Monthly Trend by Region

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(RegionName) | summarize sum(EffectiveCost) by RegionName;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit iff(count - maxGroupCount > 1, maxGroupCount, count);
let otherId = '(others)';
costs
| extend inTopX = RegionName in (topX)
| extend RegionName = iff(inTopX, RegionName, strcat('(', count - maxGroupCount, ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart = startofmonth(ChargePeriodStart),
    RegionName
| project ChargePeriodStart, EffectiveCost, Region = RegionName
| order by EffectiveCost desc
```

**Description**: Breaks down costs by Azure region, showing a trend over months with the top regions individually and others grouped.

### Monthly Trend by Service Name

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ServiceName) | summarize sum(EffectiveCost) by ServiceName;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceName in (topX)
| extend ServiceName = iff(inTopX, ServiceName, otherId)
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart,
    ServiceName
| project ChargePeriodStart, EffectiveCost, Category = ServiceName
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows cost trends by service name, highlighting the top services and grouping others.

### Monthly Trend by Service Category

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ServiceCategory) | summarize sum(EffectiveCost) by ServiceCategory;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ServiceCategory in (topX)
| extend ServiceCategory = iff(inTopX, ServiceCategory, otherId)
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart,
    ServiceCategory
| project ChargePeriodStart, EffectiveCost, Category = ServiceCategory
| order by EffectiveCost desc
| render columnchart
```

**Description**: Similar to the service name breakdown but by service category instead.

### Monthly Trend by Subscription

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(SubAccountId) | summarize sum(EffectiveCost) by SubAccountId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = SubAccountId in (topX)
| extend SubAccountId = iff(inTopX, SubAccountId, otherId)
| extend SubAccountName = iff(inTopX, SubAccountName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    SubAccountName = take_any(SubAccountName)
    by
    ChargePeriodStart = startofmonth(ChargePeriodStart),
    SubAccountId
| project ChargePeriodStart, EffectiveCost, Sub = iff(SubAccountId == otherId, SubAccountName, strcat(SubAccountName, ' (', split(SubAccountId, '/')[2], ')'))
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows cost trends by subscription, with top subscribers shown individually and others grouped.

### Monthly Trend by Resource Group

```kusto
let costs = CostsByMonth | extend x_ResourceGroupId = strcat(SubAccountId, '/resourcegroups/', x_ResourceGroupName);
let all = costs | where isnotempty(x_ResourceGroupId) | summarize sum(EffectiveCost) by x_ResourceGroupId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = x_ResourceGroupId in (topX)
| extend x_ResourceGroupId = iff(inTopX, x_ResourceGroupId, otherId)
| extend x_ResourceGroupName = iff(inTopX, x_ResourceGroupName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    SubAccountName = take_any(SubAccountName),
    x_ResourceGroupName = take_any(x_ResourceGroupName)
    by
    ChargePeriodStart,
    x_ResourceGroupId
| project ChargePeriodStart, EffectiveCost, RG = iff(x_ResourceGroupId == otherId, x_ResourceGroupName, strcat(x_ResourceGroupName, ' (', SubAccountName, ')'))
| order by EffectiveCost desc
| render columnchart
```

**Description**: Breaks down costs by resource group, showing trends over time.

### Monthly Trend by Resource

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ResourceId) | summarize sum(EffectiveCost) by ResourceId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ResourceId in (topX)
| extend ResourceId = iff(inTopX, ResourceId, otherId)
| extend ResourceName = iff(inTopX, ResourceName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    ResourceType = take_any(ResourceType),
    ResourceName = take_any(ResourceName)
    by
    ChargePeriodStart,
    ResourceId
| project ChargePeriodStart, EffectiveCost, RG = iff(ResourceId == otherId, ResourceName, strcat(ResourceName, ' (', ResourceType, ')'))
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows cost trends by resource, with top resources shown individually and others grouped.

### Daily Trend by Resource

```kusto
let costs = CostsByDay;
let all = costs | summarize sum(EffectiveCost) by ResourceId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ResourceId in (topX)
| extend ResourceId = iff(inTopX, ResourceId, otherId)
| extend ResourceName = iff(inTopX, ResourceName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    ResourceType = take_any(ResourceType),
    ResourceName = take_any(ResourceName)
    by
    ChargePeriodStart,
    ResourceId
| project ChargePeriodStart, EffectiveCost, RG = iff(ResourceId == otherId, ResourceName, strcat(ResourceName, ' (', ResourceType, ')'))
| order by EffectiveCost desc
| render columnchart
```

**Description**: Similar to the monthly trend by resource but shows daily breakdowns.

### Monthly Trend by Resource Type

```kusto
let costs = CostsByMonth;
let all = costs | where isnotempty(ResourceType) | summarize sum(EffectiveCost) by ResourceType;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = ResourceType in (topX)
| extend ResourceType = iff(inTopX, ResourceType, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart,
    ResourceType
| project ChargePeriodStart, EffectiveCost, Type = ResourceType
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows cost trends by resource type (e.g., VM, Storage, etc.).

### Daily Trend by Resource Type

```kusto
let costs = CostsByDay;
let all = costs | where isnotempty(ResourceType) | summarize sum(EffectiveCost) by ResourceType;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| where isnotempty(ResourceType)
| extend inTopX = ResourceType in (topX)
| extend ResourceType = iff(inTopX, ResourceType, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ChargePeriodStart = startofday(ChargePeriodStart),
    ResourceType
| project ChargePeriodStart, EffectiveCost, Type = ResourceType
| order by EffectiveCost desc
| render columnchart
```

**Description**: Similar to the monthly trend by resource type but shows daily breakdowns.

### Resource Type Summary

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsByDay
| where isnotempty(ResourceType)
| summarize 
    Count = dcount(ResourceId),
    EffectiveCost  = sum(EffectiveCost),
    ListCost  = sum(ListCost),
    ContractedCost  = sum(ContractedCost)
    by
    ResourceType
| order by Count desc
| project 
    Type = ResourceType,
    Count,
    Cost = round(EffectiveCost, 2),
    Savings = round(ListCost - EffectiveCost, 2),
    ["Cost / Resource"] = round(EffectiveCost / Count, 2)
```

**Description**: Provides a summary of each resource type, including count, cost, savings, and cost per resource.

### Resource Inventory Summary

```kusto
let costs = CostsByDay
| where isnotempty(ResourceType);
costs | summarize Value = tostring(dcount(ResourceId)) by Label = "Resources", Order = 10
| union (costs | summarize Value = tostring(dcount(ResourceType)) by Label = "Resource types", Order = 11)
| union (costs | summarize Count = dcount(ResourceId) by Value = ResourceType | order by Count desc | limit 1 | extend Label = "Most used", Order = 21)
| union (costs | summarize sum(EffectiveCost) by Value = ResourceType | order by sum_EffectiveCost desc | limit 1 | extend Label = "Most cost", Order = 22)
| union (costs | summarize AllTypes = dcount(ResourceType), CommittedTypes = dcountif(ResourceType, isnotempty(CommitmentDiscountType)) by Label = "Covered by commitment discounts", Order = 31 | extend Value = strcat(round(1.0 * CommittedTypes / AllTypes * 100, 1), '%'))
| union (costs | summarize Savings = sum(ListCost - EffectiveCost) by Value = ResourceType | order by Savings desc | limit 1 | extend Label = "Most savings", Order = 32)
| union (costs | summarize CostPerResource = sum(EffectiveCost) / dcount(ResourceId) by Value = ResourceType | order by CostPerResource desc | limit 1 | extend Label = "Most expensive (cost / resource)", Order = 41)
| union (costs | where ResourceType !in (CostsPlus | where ChargePeriodStart < ago(numberOfDays * 1d) - 1d | distinct ResourceType) | summarize Count = dcount(ResourceId) by ResourceType | order by Count desc | as d | count | extend Label = "New in last n days", Value = case(Count == 0, '(none)', Count == 1, toscalar(d | project ResourceType), strcat(toscalar(d | limit 1 | project ResourceType), ' and ', (Count - 1), ' more')), Order = 42)
| order by Order asc
```

**Description**: Provides a comprehensive summary of resource inventory, including total counts, most used, most expensive, and new resources.

### Most Expensive Resource Types

```kusto
let costs = CostsByDay | where isnotempty(ResourceType);
let all = costs | summarize sum(EffectiveCost) by ResourceType;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| where isnotempty(ResourceType)
| extend inTopX = ResourceType in (topX)
| extend ResourceType = iff(inTopX, ResourceType, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2)
    by
    ResourceType
| order by EffectiveCost desc
| render columnchart
```

**Description**: Shows the resource types with the highest costs.

### Most Used Resource Types

```kusto
let costs = CostsByDay | where isnotempty(ResourceType);
let all = costs | summarize ResourceCount = dcount(ResourceId) by ResourceType;
let count = toscalar(all | order by ResourceCount desc | count);
let topX = all | order by ResourceCount desc | limit maxGroupCount;
let otherId = '(others)';
costs
| where isnotempty(ResourceType)
| extend inTopX = ResourceType in (topX)
| extend ResourceType = iff(inTopX, ResourceType, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    ResourceCount = dcount(ResourceId)
    by
    ResourceType
| order by ResourceCount desc
| render columnchart
```

**Description**: Shows the resource types with the highest usage (by number of resources).

## Savings and Discount Analysis

### Cost Summary by Type

```kusto
let data = materialize(
    CostsByMonth | extend Period = 'Last n months'
    | union (CostsByDay | extend Period = 'Last n days')
    | summarize 
        ListCost = round(sum(ListCost), 2),
        ContractedCost = round(sum(ContractedCost), 2),
        EffectiveCost = round(sum(EffectiveCost), 2)
        by
        Period
    | project Period, json = todynamic(strcat('[{ "Label":"List", "Value":', ListCost, ' }, { "Label":"Contracted", "Value":', ContractedCost, ' }, { "Label":"Effective", "Value":', EffectiveCost, ' }]'))
    | mv-expand json
    | project Label = tostring(json.Label), Value = tolong(json.Value), Period
);
data
```

**Description**: Provides a comparison of list (retail), contracted (after negotiated discounts), and effective (after all discounts) costs.

### Savings Summary

```kusto
let data = materialize(
    CostsByMonth | extend Period = 'Last n months'
    | union (CostsByDay | extend Period = 'Last n days')
    | summarize
        ListCost = round(sum(ListCost), 2),
        ContractedCost = round(sum(ContractedCost), 2),
        EffectiveCost = round(sum(EffectiveCost), 2)
        by
        Period
    | project Period, json = todynamic(strcat('[{ "Label":"Total", "Value":', ListCost - EffectiveCost, ' }, { "Label":"Negotiated", "Value":', ListCost - ContractedCost, ' }, { "Label":"Commitment", "Value":', ContractedCost - EffectiveCost, ' }]'))
    | mv-expand json
    | project Label = tostring(json.Label), Value = tolong(json.Value), Period
);
data
```

**Description**: Breaks down savings into total, negotiated, and commitment-based categories.

### Monthly Savings Trend

```kusto
CostsByMonth
| where ChargeCategory == 'Usage' or isempty(CommitmentDiscountId)
| summarize 
    ListCost = sum(ListCost),
    ContractedCost = sum(ContractedCost),
    EffectiveCost = sum(EffectiveCost)
    by
    ChargePeriodStart = startofmonth(ChargePeriodStart),
    CommitmentDiscountType
| project
    ChargePeriodStart,
    Savings = round(ListCost - EffectiveCost, 2),
    Type = case(
        isnotempty(CommitmentDiscountType), CommitmentDiscountType,
        'Negotiated'
    )
```

**Description**: Shows the trend of savings over time, broken down by discount type.

### Total Savings by Type

```kusto
CostsByMonth
| where ChargeCategory == 'Usage' or isempty(CommitmentDiscountId)
| summarize 
    Savings = round(sum(ListCost - EffectiveCost), 2)
    by
    Type = case(
        isnotempty(CommitmentDiscountType), CommitmentDiscountType,
        'Negotiated'
    )
```

**Description**: Summarizes total savings by discount type (Negotiated, Reservation, Savings Plan).

### Daily Savings Trend

```kusto
CostsByDay
| where ChargeCategory == 'Usage' or isempty(CommitmentDiscountId)
| summarize 
    ListCost = sum(ListCost),
    ContractedCost = sum(ContractedCost),
    EffectiveCost = sum(EffectiveCost)
    by
    ChargePeriodStart = startofday(ChargePeriodStart),
    CommitmentDiscountType
| project
    ChargePeriodStart,
    Savings = round(ListCost - EffectiveCost, 2),
    Type = case(
        isnotempty(CommitmentDiscountType), CommitmentDiscountType,
        'Negotiated'
    )
```

**Description**: Shows daily savings trends by discount type.

### Effective Savings Rate (ESR)

```kusto
let data = materialize(
    CostsByMonth
    | where x_AmortizationCategory != 'Principal'
    | summarize 
        ListCost = sum(ListCost),
        ContractedCost = sum(ContractedCost),
        EffectiveCost = sum(EffectiveCost)
    | extend TotalSavings = ListCost - EffectiveCost
    | extend EffectiveSavingsRate = TotalSavings / ListCost
    | project json = todynamic(strcat('[',
        '{ "order":11, "type":"TotalSavings", "label":"Total savings", "value":"', numberstring(round(TotalSavings, 2)), '" },',
        '{ "order":12, "type":"", "label":"", "value":"➗" },',
        '{ "order":13, "type":"List", "label":"Cost without discounts", "value":"', numberstring(round(ListCost, 2)), '" },',
        '{ "order":14, "type":"", "label":"", "value":"🟰" },',
        '{ "order":15, "type":"EffectiveSavingsRate", "label":"Effective savings rate", "value":"', percentstring(EffectiveSavingsRate), '" }',
    ']'))
    | mv-expand json
    | order by toint(json.order) asc
    | project Label = tostring(json.label), Value = tostring(json.value), Type = tostring(json.type)
);
data
```

**Description**: Calculates the Effective Savings Rate (ESR), which is the percentage of savings relative to list prices.

### Monthly Savings Breakdown by Type

```kusto
CostsByMonth
| extend x_AmortizationCategory = case(
    ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory), 'Principal',
    isnotempty(CommitmentDiscountCategory), 'Amortized Charge',
    ''
)
| extend x_CommitmentDiscountSavings = iff(ContractedCost == 0, decimal(0), ContractedCost - EffectiveCost)
| extend x_NegotiatedDiscountSavings = iff(ListCost == 0, decimal(0), ListCost - ContractedCost)
| extend x_TotalSavings = iff(ListCost == 0, decimal(0), ListCost - EffectiveCost)
| summarize
    ['List cost'] = round(sumif(ListCost, x_AmortizationCategory != 'Principal'), 2),
    ['Effective cost'] = round(sum(EffectiveCost), 2),
    Savings = round(sum(x_TotalSavings), 2)
    by
    Account = x_BillingProfileId,
    Month = substring(startofmonth(ChargePeriodStart), 0, 7)
| extend ESR = percentstring(Savings/ ['List cost'])
| order by Month desc
```

**Description**: Shows a detailed monthly breakdown of different cost types and savings, including effective savings rate.

### Monthly Cost Breakdown by Type

```kusto
CostsByMonth
| extend x_AmortizationCategory = case(
    ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory), 'Principal',
    isnotempty(CommitmentDiscountCategory), 'Amortized Charge',
    ''
)
| extend x_CommitmentDiscountSavings = iff(ContractedCost == 0, decimal(0), ContractedCost - EffectiveCost)
| extend x_NegotiatedDiscountSavings = iff(ListCost == 0, decimal(0), ListCost - ContractedCost)
| extend x_TotalSavings = iff(ListCost == 0, decimal(0), ListCost - EffectiveCost)
| summarize
    ['On-demand'] = round(sumif(EffectiveCost, PricingCategory == 'Standard'), 2),
    Spot = round(sumif(EffectiveCost, PricingCategory == 'Dynamic'), 2),
    Reservation = round(sumif(EffectiveCost, CommitmentDiscountType == 'Reservation'), 2),
    ['Savings plan'] = round(sumif(EffectiveCost, CommitmentDiscountType == 'Savings Plan'), 2),
    ['Other'] = round(sumif(EffectiveCost, PricingCategory !in ('Standard', 'Dynamic') and isempty(CommitmentDiscountType)), 2)
    by
    Account = x_BillingProfileId,
    Month = substring(startofmonth(ChargePeriodStart), 0, 7)
| order by Month desc
```

**Description**: Breaks down costs by pricing category (on-demand, spot, reservation, savings plan, other) by month.

## Commitment Discount Analysis

### SKUs with Negotiated Discounts

```kusto
CostsByDay
| where isnotempty(x_SkuDescription)
| where x_EffectiveUnitPrice != 0 and isnotempty(x_EffectiveUnitPrice)
| where ListUnitPrice > x_EffectiveUnitPrice
| where isempty(CommitmentDiscountStatus)
| summarize 
    x_ResourceCount = dcount(ResourceId),
    EffectiveCost = round(sum(EffectiveCost), 2),
    BilledCost = round(sum(BilledCost), 2),
    ListUnitPrice = round(take_any(ListUnitPrice), 4),
    ContractedUnitPrice = round(take_any(ContractedUnitPrice), 4),
    x_EffectiveUnitPrice = round(take_any(x_EffectiveUnitPrice), 4),
    PricingQuantity = sum(PricingQuantity)
    by
    x_SkuDescription,
    PricingUnit,
    CommitmentDiscountType,
    x_SkuTerm
| order by EffectiveCost desc
| project 
    x_SkuDescription,
    Quantity = round(PricingQuantity, 4),
    Unit = PricingUnit,
    List = ListUnitPrice,
    Discount = round(ListUnitPrice - x_EffectiveUnitPrice, 4),
    Cost = EffectiveCost
| where Discount > 0
```

**Description**: Lists SKUs with negotiated discounts, showing pricing details and total savings.

### SKUs with Commitment Discounts

```kusto
CostsByDay
| where isnotempty(x_SkuDescription)
| where x_EffectiveUnitPrice != 0 and isnotempty(x_EffectiveUnitPrice)
| where isnotempty(CommitmentDiscountStatus)
| summarize 
    x_ResourceCount = dcount(ResourceId),
    EffectiveCost = round(sum(EffectiveCost), 2),
    BilledCost = round(sum(BilledCost), 2),
    ListUnitPrice = round(take_any(ListUnitPrice), 4),
    ContractedUnitPrice = round(take_any(ContractedUnitPrice), 4),
    x_EffectiveUnitPrice = round(take_any(x_EffectiveUnitPrice), 4),
    PricingQuantity = sum(PricingQuantity)
    by
    x_SkuDescription,
    PricingUnit,
    CommitmentDiscountType,
    x_SkuTerm
| order by EffectiveCost desc
| project 
    x_SkuDescription,
    CommitmentDiscountType,
    Term = case(
        isempty(x_SkuTerm) or x_SkuTerm <= 0, '',
        x_SkuTerm < 12, strcat(x_SkuTerm, ' month', iff(x_SkuTerm != 1, 's', '')),
        strcat(x_SkuTerm / 12, ' year', iff(x_SkuTerm != 12, 's', ''))
    ),
    Quantity = round(PricingQuantity, 4),
    Unit = PricingUnit,
    List = ListUnitPrice,
    Discount = round(ListUnitPrice - x_EffectiveUnitPrice, 4),
    Cost = EffectiveCost
```

**Description**: Lists SKUs with commitment discounts (reservations or savings plans), including term details.

### SKUs with No Discounts

```kusto
CostsByDay
| where isnotempty(x_SkuDescription)
| where x_EffectiveUnitPrice != 0 and isnotempty(x_EffectiveUnitPrice)
| where ListUnitPrice == x_EffectiveUnitPrice
| where isempty(CommitmentDiscountStatus)
| summarize 
    x_ResourceCount = dcount(ResourceId),
    EffectiveCost = round(sum(EffectiveCost), 2),
    BilledCost = round(sum(BilledCost), 2),
    ListUnitPrice = round(take_any(ListUnitPrice), 4),
    ContractedUnitPrice = round(take_any(ContractedUnitPrice), 4),
    x_EffectiveUnitPrice = round(take_any(x_EffectiveUnitPrice), 4),
    PricingQuantity = sum(PricingQuantity)
    by
    x_SkuDescription,
    PricingUnit,
    CommitmentDiscountType,
    x_SkuTerm
| order by EffectiveCost desc
| project 
    x_SkuDescription,
    Quantity = round(PricingQuantity, 4),
    Unit = PricingUnit,
    List = ListUnitPrice,
    Discount = round(ListUnitPrice - x_EffectiveUnitPrice, 4),
    Cost = EffectiveCost
| where Discount == 0
```

**Description**: Lists SKUs that have no discounts applied, highlighting potential savings opportunities.

### Most Used SKUs

```kusto
let doubleGroupCount = maxGroupCount * 2;
let costs = CostsByDay
| where isnotempty(x_SkuDescription)
;
let all = costs | summarize EffectiveCost = round(sum(EffectiveCost), 2) by x_SkuDescription;
let count = toscalar(all | count);
let topX = all | order by EffectiveCost desc | limit doubleGroupCount;
costs
| extend inTopX = x_SkuDescription in (topX)
| extend x_SkuDescription = iff(inTopX, x_SkuDescription, strcat('(', (count - doubleGroupCount), ' others)'))
| summarize EffectiveCost = round(sum(EffectiveCost), 2) by SKU = x_SkuDescription
| order by EffectiveCost desc
```

**Description**: Shows the most frequently used SKUs based on effective cost.

### Purchased Commitments

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsByMonth
| where ChargeCategory == 'Purchase'
| project
    ChargePeriodStart = substring(ChargePeriodStart, 0, 10),
    x_SkuDescription,
    CommitmentDiscountType,
    Term = case(isempty(x_SkuTerm) or x_SkuTerm <= 0, '', x_SkuTerm < 12, strcat(x_SkuTerm, ' month', iff(x_SkuTerm != 1, 's', '')), strcat(x_SkuTerm / 12, ' year', iff(x_SkuTerm != 12, 's', ''))),
    PricingQuantity,
    BilledCost,
    BillingCurrency
| order by ChargePeriodStart desc
```

**Description**: Lists all purchased commitments (reservations and savings plans) with their terms and costs.

### Commitment Discount Usage

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
CostsByDay
| where ChargeCategory == 'Usage'
| where isnotempty(CommitmentDiscountId)
| extend x_CommitmentDiscountUtilizationPotential = case(
    ProviderName == 'Microsoft', EffectiveCost,
    CommitmentDiscountCategory == 'Usage', ConsumedQuantity,
    CommitmentDiscountCategory == 'Spend', EffectiveCost,
    decimal(0)
)
| extend x_CommitmentDiscountUtilizationAmount = iff(CommitmentDiscountStatus == 'Used', x_CommitmentDiscountUtilizationPotential, decimal(0))
| summarize
    CommitmentDiscountName = take_any(CommitmentDiscountName),
    CommitmentDiscountType = take_any(CommitmentDiscountType),
    x_SkuTerm = take_any(x_SkuTerm),
    ListCost = sum(ListCost),
    ContractedCost = sum(ContractedCost),
    EffectiveCost = sum(EffectiveCost),
    x_CommitmentDiscountUtilizationAmount = sum(x_CommitmentDiscountUtilizationAmount),
    x_CommitmentDiscountUtilizationPotential = sum(x_CommitmentDiscountUtilizationPotential)
    by
    CommitmentDiscountId
| order by EffectiveCost desc
| project
    CommitmentDiscountName,
    CommitmentDiscountType,
    Term = case(isempty(x_SkuTerm) or x_SkuTerm <= 0, '', x_SkuTerm < 12, strcat(x_SkuTerm, ' month', iff(x_SkuTerm != 1, 's', '')), strcat(x_SkuTerm / 12, ' year', iff(x_SkuTerm != 12, 's', ''))),
    Utilization = round(x_CommitmentDiscountUtilizationAmount / x_CommitmentDiscountUtilizationPotential * 100, 1),
    Cost = round(EffectiveCost, 2),
    Savings = round(ListCost - EffectiveCost, 2)
```

**Description**: Shows commitment discount usage details, including utilization percentages and savings.

### Detailed Savings Analysis

```kusto
let data = materialize(
    CostsByMonth
    | where x_AmortizationCategory != 'Principal'
    | summarize 
        ListCost = sum(ListCost),
        ContractedCost = sum(ContractedCost),
        EffectiveCost = sum(EffectiveCost)
    | extend CommitmentDiscountSavings = ContractedCost - EffectiveCost
    | extend NegotiatedDiscountSavings = ListCost - ContractedCost
    | extend TotalSavings = ListCost - EffectiveCost
    | project json = todynamic(strcat('[',
        '{ "order":11, "type":"List", "label":"Cost without discounts", "value":"', numberstring(round(ListCost, 2)), '" },',
        '{ "order":12, "type":"", "label":"", "value":"➖" },',
        '{ "order":13, "type":"Contracted", "label":"After negotiated discounts", "value":"', numberstring(round(ContractedCost, 2)), '" },',
        '{ "order":14, "type":"", "label":"", "value":"🟰" },',
        '{ "order":15, "type":"PartialSavings", "label":"Negotiated savings", "value":"', numberstring(round(NegotiatedDiscountSavings, 2)), '" },',
        '{ "order":21, "type":"Contracted", "label":"After negotiated discounts", "value":"', numberstring(round(ContractedCost, 2)), '" },',
        '{ "order":22, "type":"", "label":"", "value":"➖" },',
        '{ "order":23, "type":"Effective", "label":"After commitment discounts", "value":"', numberstring(round(EffectiveCost, 2)), '" },',
        '{ "order":24, "type":"", "label":"", "value":"🟰" },',
        '{ "order":25, "type":"PartialSavings", "label":"Commitment savings", "value":"', numberstring(round(CommitmentDiscountSavings, 2)), '" },',
        '{ "order":31, "type":"List", "label":"Cost without discounts", "value":"', numberstring(round(ListCost, 2)), '" },',
        '{ "order":32, "type":"", "label":"", "value":"➖" },',
        '{ "order":33, "type":"Effective", "label":"After commitment discounts", "value":"', numberstring(round(EffectiveCost, 2)), '" },',
        '{ "order":34, "type":"", "label":"", "value":"🟰" },',
        '{ "order":35, "type":"TotalSavings", "label":"Total savings", "value":"', numberstring(round(TotalSavings, 2)), '" }',
    ']'))
    | mv-expand json
    | order by toint(json.order) asc
    | project Label = tostring(json.label), Value = tostring(json.value), Type = tostring(json.type)
);
data
```

**Description**: Provides a detailed analysis of savings by breaking down negotiated and commitment-based savings with descriptive labels.

### Commitment Discount Breakdown

```kusto
let data = materialize(
    CostsByMonth
    | where isnotempty(CommitmentDiscountStatus)
    | union (
        print json = dynamic([
            {"order": 11, "CommitmentDiscountType": "Reservation", "CommitmentDiscountStatus": "Used"},
            {"order": 12, "CommitmentDiscountType": "Reservation", "CommitmentDiscountStatus": "Unused"},
            {"order": 21, "CommitmentDiscountType": "Savings Plan", "CommitmentDiscountStatus": "Used"},
            {"order": 22, "CommitmentDiscountType": "Savings Plan", "CommitmentDiscountStatus": "Unused"}
        ])
        | mv-expand json
        | evaluate bag_unpack(json)
        | extend EffectiveCost = todecimal(0)
    )
    | summarize Value = sum(EffectiveCost), order = sum(order) by CommitmentDiscountStatus, CommitmentDiscountType
    | order by order asc
    | project Label = strcat(CommitmentDiscountStatus, ' ', tolower(CommitmentDiscountType), 's'), Value
);
data
```

**Description**: Shows a breakdown of commitment discounts by type (reservations vs. savings plans) and usage status (used vs. unused).

### Commitment Discount Chargeback by Resource Group

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let data = (
    CostsByMonth
    | where ChargeCategory == 'Usage'
    | where isnotempty(CommitmentDiscountId)
    | where EffectiveCost != 0
    | extend x_ResourceGroupId = strcat(SubAccountId, '/resourcegroups/', x_ResourceGroupName)
    | summarize 
        EffectiveCost  = sum(EffectiveCost),
        SubAccountName = take_anyif(SubAccountName, isnotempty(SubAccountId)),
        x_ResourceGroupName = take_any(x_ResourceGroupName),
        CommitmentDiscountName = take_any(CommitmentDiscountName),
        CommitmentDiscountType = take_any(CommitmentDiscountType)
        by
        ChargePeriodStart,
        SubAccountId,
        x_ResourceGroupId,
        CommitmentDiscountId,
        CommitmentDiscountStatus
    | as per
    | union (
        per
        | summarize 
            EffectiveCost  = sum(EffectiveCost),
            SubAccountName = take_anyif(SubAccountName, isnotempty(SubAccountId)),
            x_ResourceGroupName = take_any(x_ResourceGroupName),
            CommitmentDiscountName = take_any(CommitmentDiscountName),
            CommitmentDiscountType = take_any(CommitmentDiscountType)
            by
            x_ResourceGroupId,
            CommitmentDiscountId,
            CommitmentDiscountStatus
    )
    | order by ChargePeriodStart asc
    | extend EffectiveCost = todouble(round(EffectiveCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
    | extend x_ResourceGroupName = iff(isempty(x_ResourceGroupName) and CommitmentDiscountStatus == 'Unused', '(Unused)', x_ResourceGroupName)
    | extend SubAccountName = iff(isempty(SubAccountName) and CommitmentDiscountStatus == 'Unused', '(Unused)', SubAccountName)
);
percent((
    data | evaluate pivot(ChargePeriod, sum(EffectiveCost), x_ResourceGroupName, SubAccountName, CommitmentDiscountName, CommitmentDiscountType)
    | extend Count = tolong(Total * 1000)
))
| project-away Count
| order by x_ResourceGroupName asc, SubAccountName asc, Total desc
```

**Description**: Provides a breakdown of commitment discount charges by resource group, useful for internal chargeback scenarios.

### Commitment Discount Usage by Resource

```kusto
CostsByDay
| where ChargeCategory == 'Usage'
| where isnotempty(CommitmentDiscountId)
| where EffectiveCost != 0
| summarize 
    EffectiveCost  = sum(EffectiveCost),
    ResourceName = take_any(ResourceName),
    ResourceType = take_any(ResourceType),
    RegionName = take_any(RegionName),
    x_ResourceGroupName = take_any(x_ResourceGroupName),
    SubAccountName = take_any(SubAccountName),
    CommitmentDiscountName = take_any(CommitmentDiscountName),
    CommitmentDiscountType = take_any(CommitmentDiscountType)
    by
    ResourceId,
    CommitmentDiscountId
| project 
    CommitmentDiscountType,
    CommitmentDiscountName,
    ResourceName,
    ResourceType,
    RegionName,
    x_ResourceGroupName,
    SubAccountName,
    EffectiveCost = round(EffectiveCost, 2)
| order by CommitmentDiscountType asc, CommitmentDiscountName asc, ResourceName asc, ResourceType asc, x_ResourceGroupName asc, SubAccountName asc, EffectiveCost desc
```

**Description**: Shows detailed resource-level usage of commitment discounts.

## Azure Hybrid Benefit Analysis

### Hybrid Benefit Summary

```kusto
let numberOfMonths = int(13);
// baseQuery CostsPlus
let CostsPlus = () {
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
};
// baseQuery CostsByDayAHB
let CostsByDayAHB = () {
    CostsPlus
};
let costs = CostsByDayAHB
| where isnotempty(x_SkuLicenseStatus)
//
// Get the latest resource record first to guarrantee we have the latest status
| summarize arg_max(ChargePeriodStart, *) by ResourceId
| summarize
    x_ResourceCount = dcount(ResourceId),
    x_SkuLicenseUnusedQuantity = sum(x_SkuLicenseUnusedQuantity)
    by
    x_SkuLicenseStatus,
    x_SkuLicenseQuantity,
    x_SkuCoreCount
| union (
    print json = dynamic([
        { "x_SkuLicenseStatus": "Enabled" },
        { "x_SkuLicenseStatus": "Not Enabled" }
    ])
    | mv-expand json
    | evaluate bag_unpack(json)
);
//
// Coverage first
costs
| summarize covered = sumif(x_ResourceCount, x_SkuLicenseStatus == 'Enabled'), all = sum(x_ResourceCount)
| project Order = 1, Label = 'Coverage %', Value = percentstring(covered, all, 1)
//
// First column
| union (costs | where x_SkuLicenseStatus == 'Enabled'     | summarize Value = numberstring(sum(x_ResourceCount)) by Order = 3, Label = 'Covered resources')
| union (costs | where x_SkuLicenseStatus == 'Not Enabled' | summarize Value = numberstring(sum(x_ResourceCount)) by Order = 5, Label = 'Eligible resources')
//
// Second column
| union (costs | where x_SkuLicenseStatus == 'Enabled'     | summarize Value = numberstring(sum(x_SkuLicenseUnusedQuantity)) by Order = 2, Label = 'Underutilized vCPU capacity')
| union (costs | where x_SkuLicenseStatus == 'Enabled'     | summarize Value = numberstring(sum(x_SkuLicenseQuantity)) by Order = 4, Label = 'Covered vCPU capacity')
| union (costs | where x_SkuLicenseStatus == 'Not Enabled' | summarize Value = numberstring(sum(x_SkuLicenseQuantity)) by Order = 6, Label = 'Eligible vCPU capacity')
| order by Order asc
```

**Description**: Provides a comprehensive summary of Azure Hybrid Benefit usage, including coverage percentages and capacity metrics.

### Hybrid Benefit Breakdown by resource

```kusto
let CostsByDayAHB = () {
    Costs_v1_0
    | where ChargePeriodStart >= monthsago(13)
    | extend x_SkuLicenseStatus = case(
        ChargeCategory != 'Usage', '',
        (x_SkuMeterCategory in ('Virtual Machines', 'Virtual Machine Licenses') and x_SkuMeterSubcategory contains 'Windows') or tolower(x_SkuDetails.AHB) == 'false', 'Not Enabled',
        x_SkuDetails.ImageType contains 'Windows Server BYOL' or tolower(x_SkuDetails.AHB) == 'true' or x_SkuMeterSubcategory == 'SQL Server Azure Hybrid Benefit', 'Enabled',
        ''
    )
    | extend x_SkuLicenseType = case(
        ChargeCategory != 'Usage', '',
        x_SkuMeterCategory in ('Virtual Machines', 'Virtual Machine Licenses') and (x_SkuMeterSubcategory contains 'Windows' or x_SkuDetails.ImageType contains 'Windows Server BYOL'), 'Windows Server',
        isnotempty(tolower(x_SkuDetails.AHB)) or x_SkuMeterSubcategory == 'SQL Server Azure Hybrid Benefit', 'SQL Server',
        ''
    )
    | extend x_SkuCoreCount = toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, ''))
    | extend x_SkuType = tostring(x_SkuDetails.ServiceType)
    | extend x_SkuLicenseQuantity = case(
        isempty(x_SkuCoreCount), toint(''),
        x_SkuCoreCount <= 8, 8,
        x_SkuCoreCount <= 16, 16,
        x_SkuCoreCount == 20, 24,
        x_SkuCoreCount > 20, x_SkuCoreCount,
        toint('')
    )
    | extend x_SkuLicenseUnusedQuantity = x_SkuLicenseQuantity - x_SkuCoreCount
};
CostsByDayAHB
| where isnotempty(x_SkuLicenseStatus)
| summarize arg_max(ChargePeriodStart, *) by ResourceId
| project
    ["License type"] = x_SkuLicenseType,
    ResourceName,
    ResourceType,
    SKU = x_SkuType,
    ["SKU cores"] = x_SkuCoreCount,
    ["Required capacity"] = x_SkuLicenseQuantity,
    ["Unused capacity"] = x_SkuLicenseUnusedQuantity,
    x_SkuLicenseStatus,
    x_ResourceGroupName,
    SubAccountName
| order by x_SkuLicenseStatus desc, ["Unused capacity"] desc
```

**Description**: Provides a breakdon of Azure Hybrid Benefit by resource. This view spotlights where AHB is enabled, where it's not, and—most importantly—where you're leaving savings on the table due to underutilized vCPU capacity.

### Underutilized vCPU Capacity

```kusto
CostsByDayAHB
| where x_SkuLicenseStatus == 'Enabled'
| summarize
    arg_max(ChargePeriodStart, *),
    TotalConsumedQuantity = sum(ConsumedQuantity),
    TotalEffectiveCost = sum(EffectiveCost)
    by
    ResourceId
| project 
    ["License type"] = x_SkuLicenseType,
    ResourceName,
    ResourceType,
    SKU = x_SkuType,
    ["SKU cores"] = x_SkuCoreCount,
    ["Required capacity"] = x_SkuLicenseQuantity,
    ["Unused capacity"] = x_SkuLicenseUnusedQuantity,
    ["Unused vCore hours"] = x_SkuLicenseUnusedQuantity * ConsumedQuantity,
    EffectiveCost = TotalEffectiveCost,
    x_ResourceGroupName,
    SubAccountName
| order by ["Unused vCore hours"] desc
```

**Description**: Identifies resources with Azure Hybrid Benefit enabled but not fully utilizing their licensed capacity.

### Fully Utilized vCPU Capacity

```kusto
CostsByDayAHB
| where x_SkuLicenseStatus == 'Enabled'
| where x_SkuLicenseUnusedQuantity == 0
| summarize
    arg_max(ChargePeriodStart, *),
    TotalConsumedQuantity = sum(ConsumedQuantity),
    TotalEffectiveCost = sum(EffectiveCost)
    by
    ResourceId
| project 
    ["License type"] = x_SkuLicenseType,
    ResourceName,
    ResourceType,
    SKU = x_SkuType,
    ["SKU cores"] = x_SkuCoreCount,
    ["vCore hours"] = x_SkuLicenseQuantity * ConsumedQuantity,
    EffectiveCost = TotalEffectiveCost,
    x_ResourceGroupName,
    SubAccountName
| order by ["vCore hours"] desc
```

**Description**: Lists resources that are fully utilizing their licensed capacity through Azure Hybrid Benefit.

### Eligible Resources

```kusto
CostsByDayAHB
| where x_SkuLicenseStatus == 'Not Enabled'
| summarize
    arg_max(ChargePeriodStart, *),
    TotalConsumedQuantity = sum(ConsumedQuantity),
    TotalEffectiveCost = sum(EffectiveCost)
    by
    ResourceId
| project 
    ["License type"] = x_SkuLicenseType,
    ResourceName,
    ResourceType,
    SKU = x_SkuType,
    ["SKU cores"] = x_SkuCoreCount,
    ["Required capacity"] = x_SkuLicenseQuantity,
    ["Eligible vCore hours"] = x_SkuLicenseQuantity * ConsumedQuantity,
    EffectiveCost = TotalEffectiveCost,
    x_ResourceGroupName,
    SubAccountName
| order by ["Eligible vCore hours"] desc
```

**Description**: Identifies resources that are eligible for Azure Hybrid Benefit but don't have it enabled.

## FinOps Hub Infrastructure

### FinOps Hub Cost Breakdown

```kusto
let costs = CostsByMonth
| extend x_ToolkitTool = tostring(Tags['ftk-tool'])
| where x_ToolkitTool == 'FinOps hubs'
| extend x_ToolkitVersion = tostring(Tags['ftk-version'])
| extend x_ResourceParentId = tostring(Tags['cm-resource-parent'])
| extend x_ResourceParentName = database('Ingestion').parse_resourceid(x_ResourceParentId).ResourceName
;
let all = costs | summarize sum(EffectiveCost) by x_ResourceParentId;
let count = toscalar(all | order by sum_EffectiveCost desc | count);
let topX = all | order by sum_EffectiveCost desc | limit maxGroupCount;
let otherId = '(others)';
costs
| extend inTopX = x_ResourceParentId in (topX)
| extend x_ResourceParentId = iff(inTopX, x_ResourceParentId, otherId)
| extend x_ResourceParentName = iff(inTopX, x_ResourceParentName, strcat('(', (count - maxGroupCount), ' others)'))
| summarize 
    EffectiveCost = round(sum(EffectiveCost), 2),
    ResourceType = take_any(ResourceType),
    x_ResourceParentName = take_any(x_ResourceParentName),
    x_ResourceGroupName = take_any(x_ResourceGroupName),
    SubAccountName = take_any(SubAccountName)
    by
    ChargePeriodStart,
    x_ResourceParentId
| project ChargePeriodStart, EffectiveCost, Hub = iff(x_ResourceParentId == otherId, x_ResourceParentName, strcat(x_ResourceParentName, ' (', x_ResourceGroupName, ' / ', SubAccountName, ')'))
| order by EffectiveCost desc
```

**Description**: Shows cost breakdown for the FinOps Hub infrastructure components.

### FinOps Hub Version Summary

```kusto
let monthname = dynamic(['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']);
let costs = CostsByMonth
| extend x_ToolkitTool = tostring(Tags['ftk-tool'])
| where x_ToolkitTool == 'FinOps hubs'
| extend x_ToolkitVersion = tostring(Tags['ftk-version'])
| extend x_ResourceParentId = tostring(Tags['cm-resource-parent'])
| extend x_ResourceParentName = tostring(database('Ingestion').parse_resourceid(x_ResourceParentId).ResourceName)
;
let data = (
    costs
    | summarize 
        EffectiveCost  = sum(EffectiveCost),
        x_ResourceParentName = take_any(x_ResourceParentName),
        RegionName = take_any(RegionName),
        x_ResourceGroupName = take_any(x_ResourceGroupName),
        SubAccountName = take_any(SubAccountName),
        x_ToolkitVersion = take_any(x_ToolkitVersion)
        by
        ChargePeriodStart,
        x_ResourceParentId
    | as per
    | union (
        per
        | summarize 
            EffectiveCost  = sum(EffectiveCost)
            by
            x_ResourceParentId,
            x_ResourceParentName,
            x_ToolkitVersion,
            RegionName,
            x_ResourceGroupName,
            SubAccountName
    )
    | order by ChargePeriodStart asc
    | extend EffectiveCost = todouble(round(EffectiveCost, 2))
    | extend ChargePeriod = iff(isempty(ChargePeriodStart), strcat('Total'), strcat(format_datetime(ChargePeriodStart, 'yyyy-MM - '), monthname[monthofyear(ChargePeriodStart)]))
);
data | evaluate pivot(ChargePeriod, sum(EffectiveCost), x_ResourceParentName, x_ToolkitVersion, RegionName, x_ResourceGroupName, SubAccountName)
| project-rename Name = x_ResourceParentName, Version = x_ToolkitVersion
| order by Total desc
```

**Description**: Provides a summary of FinOps Hub deployments by version, region, and subscription.

## Data Ingestion and Quality

### Ingested Data Summary by Table

```kusto
.show cluster extents
| where TableName contains '_final_v'
| extend Dataset = tostring(split(TableName, '_final_v')[0])
| extend FocusVersion = replace_string(tostring(split(TableName, '_final_v')[1]), '_', '.')
| extend ToolkitVersion = tostring(extract(@'drop-by:ftk-version-([^\s]+)', 1, Tags))
| extend Date  = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 2, Tags))
| extend Scope = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 5, Tags))
| extend Date  = todatetime(strcat(replace_string(trim(@'/', Date), '/', '-'), '-01'))
| extend Scope = replace_regex(Scope, @'/[^/]+$', '')
| project Dataset, FocusVersion, ToolkitVersion, Date, Scope, LastUpdate = MaxCreatedOn, OriginalSize, RowCount
| extend ScopeId = database('Ingestion').parse_resourceid(Scope).ResourceName
| extend ScopeResourceType = database('Ingestion').parse_resourceid(Scope).x_ResourceType
| summarize Rows = sum(RowCount) by Date, Dataset
```

**Description**: Shows the amount of data ingested by table type over time.

### Ingested Cost Data by Scope

```kusto
.show cluster extents
| where TableName contains '_final_v'
| extend Dataset = tostring(split(TableName, '_final_v')[0])
| where Dataset == 'Costs'
| extend FocusVersion = replace_string(tostring(split(TableName, '_final_v')[1]), '_', '.')
| extend ToolkitVersion = tostring(extract(@'drop-by:ftk-version-([^\s]+)', 1, Tags))
| extend Date  = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 2, Tags))
| extend Scope = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 5, Tags))
| extend Date  = todatetime(strcat(replace_string(trim(@'/', Date), '/', '-'), '-01'))
| extend Scope = replace_regex(Scope, @'/[^/]+$', '')
| project Dataset, FocusVersion, ToolkitVersion, Date, Scope, LastUpdate = MaxCreatedOn, OriginalSize, RowCount
| extend ScopeId = tostring(database('Ingestion').parse_resourceid(Scope).ResourceName)
| extend ScopeResourceType = database('Ingestion').parse_resourceid(Scope).x_ResourceType
| summarize Rows = sum(RowCount) by Date, ScopeId
```

**Description**: Shows the amount of cost data ingested by scope over time.

### Ingested Price Data by Scope

```kusto
.show cluster extents
| where TableName contains '_final_v'
| extend Dataset = tostring(split(TableName, '_final_v')[0])
| where Dataset == 'Prices'
| extend FocusVersion = replace_string(tostring(split(TableName, '_final_v')[1]), '_', '.')
| extend ToolkitVersion = tostring(extract(@'drop-by:ftk-version-([^\s]+)', 1, Tags))
| extend Date  = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 2, Tags))
| extend Scope = tostring(extract(@'drop-by:([^/\s]+)(/[0-9]{4}(/[0-9]{2}(/[0-9]{2})?)?)?(/[^\s]+)', 5, Tags))
| extend Date  = todatetime(strcat(replace_string(trim(@'/', Date), '/', '-'), '-01'))
| extend Scope = replace_regex(Scope, @'/[^/]+$', '')
| project Dataset, FocusVersion, ToolkitVersion, Date, Scope, LastUpdate = MaxCreatedOn, OriginalSize, RowCount
| extend ScopeId = tostring(database('Ingestion').parse_resourceid(Scope).ResourceName)
| extend ScopeResourceType = database('Ingestion').parse_resourceid(Scope).x_ResourceType
| summarize Rows = sum(RowCount) by Date, ScopeId
```

**Description**: Shows the amount of price data ingested by scope over time.

### Hub Status Summary

```kusto
database('Ingestion').HubSettings
| extend temp = todynamic(strcat('[',
    '{"Label":"Version","Value":', version, '},',
    '{"Label":"Managed scopes","Value":', array_length(scopes), '},',
    '{"Label":"Data retention","Value":"', toint(retention.final.months), 'mo"}',
']'))
| mvexpand temp
| project Label = tostring(temp.Label), Value = tostring(temp.Value)
```

**Description**: Provides a summary of the FinOps Hub status, including version, managed scopes, and data retention settings.

### Data Quality Issues

```kusto
Costs
| extend EffectiveOverContracted = iff(ContractedCost < EffectiveCost, ContractedCost - EffectiveCost, decimal(0))
| extend ContractedOverList      = iff(ListCost < ContractedCost,      ListCost - ContractedCost,      decimal(0))
| extend EffectiveOverList       = iff(ListCost < EffectiveCost,       ListCost - EffectiveCost,       decimal(0))
| extend Scenario = case(
    ListCost == 0 and CommitmentDiscountCategory == 'Usage' and ChargeCategory == 'Usage', 'Reservation usage missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Usage' and ChargeCategory == 'Purchase', 'Reservation purchase missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Spend' and ChargeCategory == 'Usage', 'Savings plan usage missing list',
    ListCost == 0 and CommitmentDiscountCategory == 'Spend' and ChargeCategory == 'Purchase', 'Savings plan purchase missing list',
    ListCost == 0 and ChargeCategory == 'Purchase', 'Other purchase missing list',
    isnotempty(CommitmentDiscountStatus) and ContractedOverList == 0 and EffectiveOverContracted < 0, 'Commitment cost over contracted',
    ListCost == 0 and BilledCost == 0 and EffectiveCost == 0 and ContractedCost > 0 and x_SourceChanges !contains 'MissingContractedCost', 'ContractedCost should be 0',
    ListCost == 0 and ContractedCost == 0 and BilledCost > 0 and EffectiveCost > 0 and x_PublisherCategory == 'Vendor' and ChargeCategory == 'Usage', 'Marketplace usage missing list/contracted',
    ContractedOverList < 0 and EffectiveOverContracted == 0 and x_SourceChanges !contains 'MissingListCost', 'ListCost too low',
    ContractedUnitPrice == x_EffectiveUnitPrice and EffectiveOverContracted < 0 and x_SourceChanges !contains 'MissingContractedCost', 'ContractedCost doesn\'t match price',
    EffectiveOverContracted != 0 and abs(EffectiveOverContracted) < 0.00000001, 'Rounding error',
    ContractedOverList != 0 and abs(ContractedOverList) < 0.00000001, 'Rounding error',
    EffectiveOverList != 0 and abs(EffectiveOverList) < 0.00000001, 'Rounding error',
    ContractedCost < EffectiveCost or ListCost < ContractedCost or ListCost < EffectiveCost, '',
    EffectiveCost <= ContractedCost and ContractedCost <= ListCost, 'Good',
    '')
| project-reorder ListCost, ContractedCost, BilledCost, EffectiveCost, EffectiveOverList, EffectiveOverContracted, ContractedOverList, x_SourceChanges, ListUnitPrice, ContractedUnitPrice, x_BilledUnitPrice, x_EffectiveUnitPrice, CommitmentDiscountStatus, PricingQuantity, PricingUnit, x_PricingBlockSize, x_PricingUnitDescription
| summarize Rows = count(), EffectiveCost = round(sum(EffectiveCost), 2), EffectiveOverContracted = abs(sum(EffectiveOverContracted)), ContractedOverList = abs(sum(ContractedOverList)), EffectiveOverList = abs(sum(EffectiveOverList)), Agreement = arraystring(make_set(x_BillingAccountAgreement)) by Scenario | order by Rows desc
```

**Description**: Identifies data quality issues in the cost data, such as missing list prices or inconsistent cost fields.

## Helper and Utility Queries

### CostsPlus Query

```kusto
Costs_v1_0
| where ChargePeriodStart >= monthsago(numberOfMonths)
| as filteredCosts
| extend x_ChargeMonth = startofmonth(ChargePeriodStart)
| extend x_CapacityReservationId = tostring(x_SkuDetails.VMCapacityReservationId)
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
| extend x_ToolkitTool = tostring(Tags['ftk-tool'])
| extend x_ToolkitVersion = tostring(Tags['ftk-version'])
| extend tmp_ResourceParent = database('Ingestion').parse_resourceid(Tags['cm-resource-parent'])
| extend x_ResourceParentId = tostring(tmp_ResourceParent.ResourceId)
| extend x_ResourceParentName = tostring(tmp_ResourceParent.ResourceName)
| extend x_ResourceParentType = tostring(tmp_ResourceParent.ResourceType)
| extend CommitmentDiscountNameUnique = iff(isempty(CommitmentDiscountId), '', strcat(CommitmentDiscountName, ' (', CommitmentDiscountType, ')'))
| extend ResourceNameUnique           = iff(isempty(ResourceId),           '', strcat(ResourceName,           ' (', ResourceType, ')'))
| extend x_ResourceGroupNameUnique    = iff(isempty(x_ResourceGroupName),  '', strcat(x_ResourceGroupName,    ' (', SubAccountName, ')'))
| extend SubAccountNameUnique         = iff(isempty(SubAccountId),         '', strcat(SubAccountName,         ' (', split(SubAccountId, '/')[3], ')'))
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
| project-away tmp_SQLAHB, tmp_IsVMUsage, tmp_ResourceParent
```

**Description**: Creates an enhanced version of the Costs table with additional calculated fields for detailed analysis.

### Display Month Options

```kusto
let months = toscalar(database('Ingestion').HubSettings | project toint(retention.final.months));
let monthname = dynamic(['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
range Value from toint(1) to iff(isempty(months), 24, months) step 1
| order by Value desc
| extend MonthsAgo = monthsago(Value)
| extend Label = strcat(Value, ' mo (', monthname[monthofyear(MonthsAgo)], format_datetime(MonthsAgo, ' yyyy'), ')')
| project-away MonthsAgo
```

**Description**: Generates a list of month options for the dashboard parameters, showing the number of months and corresponding date.
