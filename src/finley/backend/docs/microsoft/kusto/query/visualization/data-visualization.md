# Data Visualization with KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides powerful visualization capabilities through the `render` operator. This document explores how to create effective visualizations directly from your KQL queries.

## The render Operator

The `render` operator displays query results visually. It comes after query tabular data is ready for visualization.

### Syntax

```kusto
T | render Visualization [with (PropertyName = PropertyValue [, ...])]
```

### Visualization Types

| Visualization | Description | Common Use Cases |
|---------------|-------------|------------------|
| `barchart` | Horizontal bar chart | Comparing categories |
| `columnchart` | Vertical bar chart | Comparing values across categories |
| `piechart` | Circular chart divided into slices | Showing proportion or percentage |
| `timechart` | Line chart with time on x-axis | Time series data |
| `linechart` | Line chart for any x-axis | Trend analysis, relationships between variables |
| `scatterchart` | Points on an x,y coordinate system | Correlation between variables |
| `areachart` | Filled areas stacked vertically | Showing cumulative values over time |
| `anomalychart` | Time series with anomalies highlighted | Anomaly detection |
| `pivotchart` | Interactive pivot table | Multi-dimensional analysis |
| `card` | Large number with optional sparkline | Key metrics and KPIs |
| `table` | Tabular data | Detailed data review |

## Basic Visualization Examples

### Bar Chart

```kusto
Events
| summarize count() by Computer
| top 10 by count_
| render barchart
```

### Column Chart

```kusto
Events
| where TimeGenerated > ago(7d)
| summarize count() by bin(TimeGenerated, 1d), EventType
| render columnchart
```

### Pie Chart

```kusto
Events
| where TimeGenerated > ago(1d)
| summarize count() by EventType
| render piechart
```

### Time Chart

```kusto
Perf
| where TimeGenerated > ago(1d)
| where CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

### Scatter Chart

```kusto
Perf
| where TimeGenerated > ago(1h)
| where CounterName == "% Processor Time" or CounterName == "Available MBytes"
| summarize CPU = avgif(CounterValue, CounterName == "% Processor Time"),
           Memory = avgif(CounterValue, CounterName == "Available MBytes")
  by Computer
| render scatterchart
```

## Advanced Visualization Techniques

### Customizing Visualizations

Use the `with` clause to customize visualizations:

```kusto
Events
| summarize count() by bin(TimeGenerated, 1h), EventType
| render timechart with (
    title="Event Count by Type",
    xtitle="Time",
    ytitle="Count",
    series=EventType,
    ymin=0
)
```

### Multi-Series Visualizations

Display multiple lines on a time chart:

```kusto
let timeRange = 7d;
Perf
| where TimeGenerated > ago(timeRange)
| where CounterName == "% Processor Time" and ObjectName == "Processor"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 15m)
| render timechart with (series=Computer)
```

### Stacked Area Charts

Show multiple areas stacked on each other:

```kusto
Events
| where TimeGenerated > ago(1d)
| summarize count() by bin(TimeGenerated, 1h), EventType
| render areachart with (series=EventType)
```

### Anomaly Visualization

Visualize anomalies in time series data:

```kusto
Perf
| where TimeGenerated > ago(7d)
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 15m)
| render anomalychart with (anomalycolumns=avg_CounterValue)
```

### Pivot Charts

Create interactive pivot tables for multi-dimensional analysis:

```kusto
Events
| where TimeGenerated > ago(1d)
| summarize count() by Computer, EventType, EventID
| render pivotchart
```

## Compound Visualizations

### Side-by-Side Visualizations

Use the `union` operator to display side-by-side visualizations:

```kusto
// Create two separate visualizations
let chart1 = Events
| where TimeGenerated > ago(1d) and EventType == "Error"
| summarize count() by bin(TimeGenerated, 1h)
| project TimeGenerated, ErrorCount=count_, vis='Errors';

let chart2 = Events
| where TimeGenerated > ago(1d) and EventType == "Warning"
| summarize count() by bin(TimeGenerated, 1h)
| project TimeGenerated, WarningCount=count_, vis='Warnings';

// Union them together 
union chart1, chart2
| render timechart with (series=vis, ycolumns=ErrorCount, WarningCount)
```

### Multiple Y-Axes

Display different metrics on separate y-axes:

```kusto
// CPU and Memory on different scales
Perf
| where TimeGenerated > ago(1d)
| where CounterName in ("% Processor Time", "Available MBytes")
| summarize avg(CounterValue) by bin(TimeGenerated, 15m), CounterName
| render timechart with (ysplit=axes)
```

## Best Practices for Effective Visualizations

1. **Choose the right visualization type**:
   - Use time charts for time series data
   - Use bar/column charts for categorical comparisons
   - Use scatter charts for relationship analysis
   - Use pie charts sparingly and only for part-to-whole relationships

2. **Use clear titles and labels**:
   - Always include descriptive titles
   - Label axes appropriately
   - Use legends when multiple series are present

3. **Focus on the message**:
   - Filter out unnecessary data
   - Sort data meaningfully (e.g., by frequency, time, or value)
   - Use colors consistently

4. **Optimize performance**:
   - Aggregate data appropriately
   - Limit the number of series (5-7 max for readability)
   - Consider the time range and bin size

5. **Make visualizations accessible**:
   - Use colorblind-friendly palettes
   - Avoid relying solely on color to convey information
   - Include numerical values when appropriate

## Troubleshooting Visualizations

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| No visualization appears | Incorrect data structure | Ensure data columns match expected format for visualization type |
| Too many series | Too many distinct values | Use `top` or `limit` to reduce number of series |
| Unexpected scale | Outliers skewing axis | Use `with (ymin=X, ymax=Y)` to set scale manually |
| Chart is too dense | Too many data points | Increase bin size or reduce time range |
| Colors are confusing | Default color scheme | Use `palette` property to specify colors |

## Use Cases by Visualization Type

### Time-Based Analysis

```kusto
// CPU utilization over time
Perf
| where TimeGenerated > ago(12h)
| where CounterName == "% Processor Time" and ObjectName == "Processor"
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

### Categorical Analysis

```kusto
// Error distribution by type
Events
| where TimeGenerated > ago(1d) and EventLevel == "Error"
| summarize count() by EventType
| sort by count_ desc
| render piechart
```

### Relationship Analysis

```kusto
// Correlation between CPU and Memory
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| project TimeGenerated, Computer, CPU = CounterValue
| join kind=inner (
    Perf
    | where TimeGenerated > ago(1h)
    | where ObjectName == "Memory" and CounterName == "Available MBytes"
    | project TimeGenerated, Computer, Memory = CounterValue
) on TimeGenerated, Computer
| summarize AvgCPU = avg(CPU), AvgMemory = avg(Memory) by Computer
| render scatterchart
```

### Comparative Analysis

```kusto
// Compare resources by usage
Perf
| where TimeGenerated > ago(1d)
| where CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer
| top 10 by AvgCPU desc
| render columnchart
```

## Advanced Visualization Properties

| Property | Description | Example |
|----------|-------------|---------|
| `title` | Chart title | `title="CPU Utilization"` |
| `xtitle` | X-axis title | `xtitle="Time (UTC)"` |
| `ytitle` | Y-axis title | `ytitle="CPU Percentage"` |
| `xaxis` | X-axis scale type | `xaxis=linear` or `xaxis=log` |
| `yaxis` | Y-axis scale type | `yaxis=linear` or `yaxis=log` |
| `series` | Column to use for series | `series=Computer` |
| `ycolumns` | Columns to use as y-values | `ycolumns=CPU, Memory` |
| `ysplit` | How to handle multiple y-columns | `ysplit=panels` or `ysplit=axes` |
| `kind` | Sub-type for visualization | `kind=stacked` or `kind=unstacked` |
| `ymin` | Minimum y-axis value | `ymin=0` |
| `ymax` | Maximum y-axis value | `ymax=100` |
| `palette` | Color palette to use | `palette=spectral` |

## See Also

- [Render operator reference](../operators/render-operator.md)
- [Make-series for time series visualization](../operators/make-series-operator.md)
- [Advanced analytics and anomaly detection](../time-series-analysis.md)
