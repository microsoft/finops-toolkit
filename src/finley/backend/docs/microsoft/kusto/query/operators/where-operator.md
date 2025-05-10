# Where operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Filters a table to the subset of rows that satisfy a predicate.

## Syntax

*T* `| where` *Predicate*

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *Predicate* | string | ✓ | A boolean expression over the columns of *T* to evaluate for each row in *T*. Only rows for which the expression evaluates to `true` are retained. |

## Returns

Rows in *T* for which *Predicate* is `true`.

## Examples

### Filter by a specific value

```kusto
StormEvents
| where State == "FLORIDA"
| take 5
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | EventType | InjuriesDirect | InjuriesIndirect | DeathsDirect | DeathsIndirect | ... |
|--|--|--|--|--|--|--|--|--|--|--|
| 2007-09-18T22:00:00Z | 2007-09-18T22:00:00Z | 11927 | 71441 | FLORIDA | Heavy Rain | 0 | 0 | 0 | 0 | ... |
| 2007-09-20T21:57:00Z | 2007-09-20T21:57:00Z | 11928 | 71442 | FLORIDA | Tornado | 0 | 0 | 0 | 0 | ... |
| 2007-10-01T20:00:00Z | 2007-10-01T20:00:00Z | 12888 | 73250 | FLORIDA | Waterspout | 0 | 0 | 0 | 0 | ... |
| 2007-10-02T14:11:00Z | 2007-10-02T14:11:00Z | 12889 | 73251 | FLORIDA | Heavy Rain | 0 | 0 | 0 | 0 | ... |
| 2007-12-20T15:00:00Z | 2007-12-20T16:00:00Z | 13499 | 76147 | FLORIDA | Strong Wind | 0 | 0 | 0 | 0 | ... |

### Filter by a date range

```kusto
StormEvents
| where StartTime between (datetime(2007-02-01) .. datetime(2007-03-01))
| where State == "FLORIDA"
| count
```

Output:

| Count |
|-------|
| 2 |

### Filter using a function

```kusto
StormEvents
| where StartTime > ago(30d)
| count
```

This query returns the count of StormEvents in the last 30 days. The `ago()` function returns a date/time that's the specified amount of time before the current time.

## Notes

For better query performance:

1. Use simple comparisons between column names and constants. ('Constant' means constant over the table - so `now()` and `ago()` are OK, and so are scalar values assigned using a [`let` statement](../statements/let.md).)

   For example, prefer `where Timestamp > ago(1d)` to `where floor(Timestamp, 1d) == ago(1d)`.

2. The simplest terms should be first in a conjunction: `where Timestamp > ago(1d) and Level == "Error"`
