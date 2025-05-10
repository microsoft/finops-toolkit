# Take operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Returns up to the specified number of rows from the input table.

## Syntax

*T* `| take` *NumberOfRows*

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *NumberOfRows* | int | ✓ | The number of rows to return. You can specify any numeric expression. |

## Returns

A table containing the specified number of rows from the input table, unless the input table has fewer rows, in which case all rows are returned.

> [!NOTE]
> `take` is useful for testing a query on a small subset of data. It's not meant to be used for production queries. In general, there's no guarantee which records are returned in the result and which aren't, so the same query may return different results each time it runs. 
>
> For consistent results when querying data, use [`sort by`](sort-operator.md) ... [`take`](take-operator.md).

## Examples

### Return 5 rows from a table

The example returns 5 rows from the `StormEvents` table.

```kusto
StormEvents
| take 5
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | EventType | InjuriesDirect | InjuriesIndirect | DeathsDirect | DeathsIndirect | ... |
|--|--|--|--|--|--|--|--|--|--|--|
| 2007-09-29T08:11:00Z | 2007-09-29T08:11:00Z | 11984 | 61032 | ATLANTIC SOUTH | Waterspout | 0 | 0 | 0 | 0 | ... |
| 2007-09-18T22:00:00Z | 2007-09-19T02:00:00Z | 11928 | 60913 | FLORIDA | Heavy Rain | 0 | 0 | 0 | 0 | ... |
| 2007-09-20T21:57:00Z | 2007-09-20T22:05:00Z | 11928 | 60914 | FLORIDA | Tornado | 0 | 0 | 0 | 0 | ... |
| 2007-09-29T20:01:00Z | 2007-09-29T20:01:00Z | 11983 | 60931 | GEORGIA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-09-20T05:00:00Z | 2007-09-20T06:00:00Z | 11929 | 60932 | MISSISSIPPI | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |

### Use take with a dynamic number of rows

The example uses an expression for the number of rows to return.

```kusto
let rowsToTake = 3;
StormEvents
| take rowsToTake
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | EventType | InjuriesDirect | InjuriesIndirect | DeathsDirect | DeathsIndirect | ... |
|--|--|--|--|--|--|--|--|--|--|--|
| 2007-09-29T08:11:00Z | 2007-09-29T08:11:00Z | 11984 | 61032 | ATLANTIC SOUTH | Waterspout | 0 | 0 | 0 | 0 | ... |
| 2007-09-18T22:00:00Z | 2007-09-19T02:00:00Z | 11928 | 60913 | FLORIDA | Heavy Rain | 0 | 0 | 0 | 0 | ... |
| 2007-09-20T21:57:00Z | 2007-09-20T22:05:00Z | 11928 | 60914 | FLORIDA | Tornado | 0 | 0 | 0 | 0 | ... |

## Notes

* For more predictable results, it's recommended to use [`sort by`](sort-operator.md) before `take`.
* If you need to get the last N records according to some order, use [`sort by`](sort-operator.md) ... [`take`](take-operator.md) (example: `T | sort by @timestamp desc | take 10`).
* The [`limit`](limit-operator.md) operator is an alias for `take` with the same behavior.
