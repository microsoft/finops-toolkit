# Ago function

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Returns a datetime that is the specified timespan earlier than the current UTC time (now()).

This function is particularly useful for queries that need to filter data from a relative time range.

## Syntax

`ago(`*timespan*`)`

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *timespan* | timespan | ✓ | The time interval to subtract from the current UTC time. |

## Returns

A datetime value representing the current UTC time (`now()`) minus the specified *timespan* value.

## Examples

### Filter data for the last 24 hours

```kusto
StormEvents
| where StartTime > ago(24h)
| count
```

This example counts the StormEvents that occurred in the last 24 hours.

### Filter data for the last 7 days

```kusto
StormEvents
| where StartTime > ago(7d)
| summarize EventCount=count() by State
| sort by EventCount desc
```

This example counts StormEvents from the last 7 days, grouped by State.

### Multiple ago references in the same query

```kusto
StormEvents
| where StartTime > ago(30d) and StartTime < ago(7d)
| summarize EventCount=count() by bin(StartTime, 1d)
| render timechart
```

This example visualizes storm events that occurred between 30 days ago and 7 days ago, summarized by day.

## Notes

1. The `ago()` function always evaluates to current UTC time at the time of query execution (not at the time the query was authored).

2. The *timespan* parameter can be specified using several formats:
   * A number followed by a time unit: `1d` (1 day), `24h` (24 hours), `30m` (30 minutes)
   * A timespan literal: `time(1.00:00:00)` (1 day)

3. Because `ago()` references the current time (at query execution), queries using this function will return different results when run at different times. Consider using explicit datetime values for reproducible results.

4. When used in dashboards or reports that are refreshed automatically, queries with `ago()` will always refer to the time at refresh.

5. For better query performance, avoid using expressions like `between now() and ago(1d)`. Instead, use `> ago(1d)` since it can leverage time-based indexes more efficiently.
