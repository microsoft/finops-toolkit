# Bin function

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Rounds values down to an integer multiple of the specified bin size. Used frequently in combination with `summarize by`.

The bin function is useful for creating histogram-like outputs by grouping data into discrete buckets or intervals.

## Syntax

`bin(`*value*`,` *roundTo*`)`

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *value* | scalar | ✓ | The value to round down. Can be a number, date, or timespan. |
| *roundTo* | scalar | ✓ | The "bin size". The value will be rounded down to an integer multiple of this value. |

## Returns

The nearest value lower than *value* that is an integer multiple of *roundTo*.

## Examples

### Binning numeric values

```kusto
print bin(4.5, 1)    // 4.0
print bin(4.5, 5)    // 0.0
print bin(4.5, 0.1)  // 4.5
print bin(-4.5, 1)   // -5.0
```

### Binning datetime values

Datetime values can be binned to create time-based aggregations:

```kusto
StormEvents
| summarize count() by bin(StartTime, 1d)
| sort by StartTime
| render timechart
```

This query groups storm events by day and visualizes the count over time.

### Binning for histograms

```kusto
StormEvents
| summarize count() by bin(DamageProperty, 100000)
| sort by DamageProperty asc
| render columnchart
```

This query creates a histogram of property damage, grouped into $100,000 intervals.

### Using bin() with datetime functions

Bin often works well with date and time functions:

```kusto
StormEvents
| where StartTime > ago(180d)
| summarize EventCount=count() by Week=bin(StartTime, 7d), State
| top 5 by EventCount desc
```

## Notes

1. The `bin()` function performs a floor-like operation, always rounding down to the nearest bin boundary.

2. When working with datetime values, common bin sizes include:
   * `1s`, `1m`, `1h`, `1d` for seconds, minutes, hours, days
   * `1h` is 1 hour (60 minutes)
   * `1d` is 1 day (24 hours)
   * `7d` is 7 days (1 week)
   * `30d` is 30 days (approximate month)

3. For numeric values, the bin size can be any number, but the most useful ones are typically round numbers like 5, 10, 100, etc.

4. Combining `bin()` with `summarize` and `by` is a very common pattern for time series analysis in Kusto.

5. The `bin()` function has aliases including `floor()`, but the `bin()` name is recommended for clarity.
