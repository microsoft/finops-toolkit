# Time Series Analysis in KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides powerful capabilities for time series analysis, enabling you to analyze and visualize data that changes over time. This document covers the key functions, operators, and techniques for working with time series data.

## Key Concepts

### Time Series

A time series is a sequence of data points collected or observed at successive points in time, usually at uniform intervals. Common examples include:

- Server telemetry (CPU, memory, network) over time
- User activity metrics (logins, transactions) by hour/day
- IoT device sensor readings (temperature, humidity) at regular intervals
- Business metrics (revenue, user counts) tracked daily/monthly

### Time Bins

Time binning is the process of grouping time into discrete intervals (bins) to make analysis more manageable. This is crucial for time series analysis and is accomplished using the `bin()` function in KQL.

## Time Functions

### Basic Time Functions

#### ago()

Returns a timestamp relative to the current UTC clock time:

```kusto
// Data from the last 24 hours
Logs | where Timestamp > ago(24h)
```

#### now()

Returns the current UTC datetime:

```kusto
// Compare timestamps to current time
Events | extend TimeSinceEvent = now() - Timestamp
```

#### datetime_diff()

Calculates the difference between two datetimes in specified units:

```kusto
Events
| extend DurationInMinutes = datetime_diff('minute', EndTime, StartTime)
```

### Time Binning Functions

#### bin()

Groups timestamps into fixed-size time bins:

```kusto
Logs
| summarize count() by TimeBin = bin(Timestamp, 1h)
```

#### floor()

Similar to bin(), rounds down to the nearest multiple:

```kusto
Logs
| summarize count() by TimeBin = floor(Timestamp, 1h)
```

### Time Period Functions

KQL provides functions to identify specific parts of a datetime:

```kusto
Events
| extend
    Year = getyear(Timestamp),
    Month = getmonth(Timestamp),
    Day = getday(Timestamp),
    DayOfWeek = dayofweek(Timestamp),
    Hour = gethour(Timestamp)
```

### Start/End Period Functions

Functions to get the start or end of a time period:

```kusto
Events
| extend
    DayStart = startofday(Timestamp),
    WeekStart = startofweek(Timestamp),
    MonthStart = startofmonth(Timestamp),
    DayEnd = endofday(Timestamp)
```

## Time Series Operators

### make-series

The `make-series` operator is designed specifically for time series analysis:

```kusto
Logs
| where Timestamp between(ago(7d) .. now())
| make-series
    RequestCount = count()
    on Timestamp
    from ago(7d) to now()
    step 1h
    by Region
```

This creates a time series of request counts for each region, with one data point per hour over the past 7 days.

## Time Series Analysis Functions

### Series Decomposition

#### series_decompose()

Decomposes a series into seasonal, trend, and residual components:

```kusto
let hourlyData = Logs
| make-series Requests = count() on Timestamp from ago(14d) to now() step 1h;
hourlyData
| extend SeriesDecomposition = series_decompose(Requests)
| project
    Timestamp,
    Requests,
    Trend = SeriesDecomposition.trend,
    Seasonal = SeriesDecomposition.seasonal,
    Residual = SeriesDecomposition.residual
| render timechart
```

#### series_decompose_anomalies()

Detects anomalies in a time series using decomposition:

```kusto
let hourlyData = Logs
| make-series Requests = count() on Timestamp from ago(14d) to now() step 1h;
hourlyData
| extend anomalies = series_decompose_anomalies(Requests)
| render anomalychart with(anomalycolumns=anomalies)
```

### Series Forecasting

#### series_fit_line()

Fits a line to a series:

```kusto
let dailyData = Logs
| make-series Requests = count() on Timestamp from ago(30d) to now() step 1d;
dailyData
| extend (RSquare, Slope, Variance, RVariance, LineFit) = series_fit_line(Requests)
| project Timestamp, Requests, LineFit
| render timechart
```

#### series_fit_2lines()

Fits two connected lines to detect trend changes:

```kusto
let dailyData = Logs
| make-series Requests = count() on Timestamp from ago(60d) to now() step 1d;
dailyData
| extend series_fit_2lines(Requests)
| project Timestamp, Requests, series_fit_2lines_fit_Requests
| render timechart
```

### Series Smoothing

#### series_fir()

Applies a Finite Impulse Response filter for smoothing:

```kusto
let hourlyData = Logs
| make-series Requests = count() on Timestamp from ago(7d) to now() step 1h;
hourlyData
| extend SmoothRequests = series_fir(Requests, repeat(1, 5), true)
| project Timestamp, Requests, SmoothRequests
| render timechart
```

#### series_moving_avg()

Calculates a moving average of a series:

```kusto
let hourlyData = Logs
| make-series Requests = count() on Timestamp from ago(7d) to now() step 1h;
hourlyData
| extend MovingAvg = series_moving_avg(Requests, 5)
| project Timestamp, Requests, MovingAvg
| render timechart
```

## Visualizing Time Series

The `render` operator is particularly useful for visualizing time series data:

```kusto
Logs
| summarize RequestCount = count() by bin(Timestamp, 1h)
| render timechart
```

### Chart Types

- `timechart`: Line chart optimized for time series
- `areachart`: Area chart for time series
- `barchart`: Bar chart for categorical data
- `columnchart`: Column chart for categorical data
- `anomalychart`: Line chart highlighting anomalies

### Visualization Parameters

```kusto
Logs
| make-series RequestCount = count() on Timestamp from ago(7d) to now() step 1h by Region
| render timechart with (
    title = "Hourly Requests by Region",
    xtitle = "Time",
    ytitle = "Request Count",
    series = Region
)
```

## Common Time Series Patterns

### Daily Patterns Analysis

```kusto
Logs
| where Timestamp >= ago(7d)
| extend Hour = datetime_part("hour", Timestamp)
| summarize RequestCount = count() by Hour, Day = bin(Timestamp, 1d)
| render timechart
```

### Weekly Patterns

```kusto
Logs
| where Timestamp >= ago(28d)
| extend DayOfWeek = dayofweek(Timestamp)
| summarize RequestCount = count() by DayOfWeek, Week = bin(Timestamp, 7d)
```

### Comparing Periods

```kusto
let currentPeriod = Logs
| where Timestamp between(ago(7d) .. now())
| summarize CurrentCount = count() by bin(Timestamp, 1h);
let previousPeriod = Logs
| where Timestamp between(ago(14d) .. ago(7d))
| summarize PreviousCount = count() by bin(Timestamp, 1h);
currentPeriod
| join kind=fullouter previousPeriod on Timestamp
| project Timestamp, CurrentCount, PreviousCount
| render timechart
```

### Growth Rate Calculation

```kusto
Logs
| summarize RequestCount = count() by Day = bin(Timestamp, 1d)
| order by Day asc
| extend PreviousDay = prev(RequestCount)
| extend GrowthRate = (RequestCount - PreviousDay) * 100.0 / PreviousDay
```

## Best Practices

1. **Appropriate Time Bins**: Choose time bins appropriate for your data and analysis needs
2. **Handling Missing Data**: Use `series_fill_linear()` or `series_fill_const()` to handle gaps
3. **Outlier Treatment**: Consider removing outliers before analysis for more accurate results
4. **Pre-aggregation**: Aggregate data to an appropriate level before applying time series functions
5. **Visualization**: Use rendering options to create clear, informative visualizations
6. **Date Alignment**: Ensure dates are properly aligned for period comparisons

## Related Topics

- [Datetime Data Type](datetime.md)
- [Bin Function](../functions/bin-function.md)
- [Make-series Operator](../operators/make-series-operator.md)
- [Render Operator](../operators/render-operator.md)
