# Time Series Analysis with KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides powerful capabilities for time series analysis. This document explores the features that enable you to create, manipulate, and analyze time series data effectively.

## Creating Time Series with make-series

The `make-series` operator is the foundation for time series analysis in KQL. It creates a series of specified aggregated values along a defined time axis.

### Syntax

```kusto
T | make-series [column =] aggregation [default = defaultValue] 
    [, ...] on timeColumn from start to end step step 
    [by [column =] groupExpression [, ...]]
```

### Parameters

- **column**: Optional name for the output column.
- **aggregation**: Aggregation function to apply (e.g., `sum(Value)`, `avg(Value)`).
- **defaultValue**: Optional default value for missing values.
- **timeColumn**: Column used as the time axis.
- **start**: Start of the time range.
- **end**: End of the time range.
- **step**: Size of each time bin (e.g., `1h`, `1d`).
- **groupExpression**: Optional expression to group by.

### Example

```kusto
let start = ago(7d);
let end = now();
let interval = 1h;

Events
| where Timestamp between (start .. end)
| make-series RequestCount = count() 
    on Timestamp from start to end step interval
    by Region
```

This query creates a time series of event counts per hour over the last 7 days, grouped by Region.

## Series Operations

KQL provides various functions to manipulate and analyze time series data:

### Series Filling Functions

- **series_fill_linear**: Fill missing values using linear interpolation.
- **series_fill_backward**: Fill missing values by carrying the next valid value backward.
- **series_fill_forward**: Fill missing values by carrying the previous valid value forward.
- **series_fill_const**: Fill missing values with a constant value.

Example:
```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend FilledRequestCount = series_fill_linear(RequestCount)
```

### Series Smoothing Functions

- **series_smooth_simple**: Simple moving average smoothing.
- **series_smooth_exponential**: Exponential smoothing.

Example:
```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend SmoothedRequestCount = series_smooth_simple(RequestCount, 3)
```

## Anomaly Detection

KQL provides several functions for detecting anomalies in time series data:

### series_decompose_anomalies

Decomposes a series and returns anomaly points.

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend anomalies = series_decompose_anomalies(RequestCount)
```

### series_detect_outliers

Identifies statistical outliers in a time series.

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend outliers = series_detect_outliers(RequestCount)
```

## Forecasting

KQL supports forecasting future values based on historical time series data:

### series_decompose_forecast

Predicts future values based on seasonal decomposition.

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend forecast = series_decompose_forecast(RequestCount, 12)
```

## Visualization

Time series data can be visualized using the `render` operator:

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval by Region
| render timechart
```

Supported visualization types:
- **timechart**: Line chart with time on the x-axis.
- **areachart**: Area chart with time on the x-axis.
- **linechart**: Line chart (can be used for non-time series as well).

## Advanced Analysis

### Time Series Decomposition

Decompose a time series into trend, seasonal, and residual components:

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| extend decomposition = series_decompose(RequestCount)
| project Timestamp, 
    Trend = decomposition.baseline,
    Seasonal = decomposition.seasonal,
    Residual = decomposition.residual
```

### Seasonality Analysis

Identify patterns that repeat at regular intervals:

```kusto
Events
| make-series RequestCount = count() on Timestamp from start to end step interval
| project Seasonality = series_periods_detect(RequestCount, 0.7)
```

## Best Practices

1. **Choose Appropriate Time Granularity**: Balance between detail and performance.
2. **Handle Missing Values**: Always use series_fill_ functions to handle gaps.
3. **Pre-process Data**: Smooth noisy data before anomaly detection.
4. **Limit Series Size**: For performance, limit the number of points in each series.
5. **Use Appropriate Thresholds**: Adjust sensitivity parameters for your specific data patterns.

## Related Functions

| Category | Functions |
|----------|-----------|
| Creation | `make-series` |
| Filling | `series_fill_linear`, `series_fill_forward`, `series_fill_backward`, `series_fill_const` |
| Smoothing | `series_smooth_simple`, `series_smooth_exponential` |
| Anomaly Detection | `series_decompose_anomalies`, `series_detect_outliers` |
| Forecasting | `series_decompose_forecast` |
| Decomposition | `series_decompose` |
| Seasonality | `series_periods_detect`, `series_periods_validate` |
| Transformation | `series_subtract`, `series_divide`, `series_multiply`, `series_add` |

## See Also

- [make-series operator](../operators/make-series-operator.md)
- [Anomaly detection in Azure Monitor logs](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/kql-machine-learning-azure-monitor)
- [Visualizing time series data](../visualization/render-operator.md)
