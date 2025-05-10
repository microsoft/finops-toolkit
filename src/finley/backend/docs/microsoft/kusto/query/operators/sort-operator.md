# Sort operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Sorts the rows of the input table into order by one or more columns.

## Syntax

*T* `| sort by` *column* [`asc` | `desc`] [`,` *column* [`asc` | `desc`] ]...

*T* `| order by` *column* [`asc` | `desc`] [`,` *column* [`asc` | `desc`] ]...

> [!NOTE]
> `order by` is an alias of `sort by`

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *column* | string | ✓ | The column by which to sort the input. The data type of the column must be numeric, date, time, or string. |
| `asc` or `desc` | string | | `asc` sorts into ascending order (low to high). Default is `desc` (high to low). |

## Returns

A table whose rows are reordered according to the specified sort criteria.

> [!NOTE]
> `sort` and `top` are the only operators that can guarantee the order of their results. To ensure ordering of results in a query, you should always apply either `sort` or `top` as the last step that produces results.

## Examples

### Sort by a single column

```kusto
StormEvents
| sort by StartTime desc
| take 5
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | EventType | InjuriesDirect | InjuriesIndirect | DeathsDirect | DeathsIndirect | ... |
|--|--|--|--|--|--|--|--|--|--|--|
| 2007-12-31T23:30:00Z | 2007-12-31T23:37:00Z | 14479 | 82091 | GEORGIA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-12-31T23:00:00Z | 2007-12-31T23:05:00Z | 14479 | 82090 | GEORGIA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-12-31T23:00:00Z | 2007-12-31T23:00:00Z | 12554 | 67741 | MISSISSIPPI | Winter Weather | 0 | 0 | 0 | 0 | ... |
| 2007-12-31T22:53:00Z | 2007-12-31T22:53:00Z | 14479 | 82089 | GEORGIA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-12-31T22:50:00Z | 2007-12-31T22:55:00Z | 14479 | 82088 | GEORGIA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |

### Sort by multiple columns

When sorting by multiple columns, the sort is performed according to the order of the columns. Data is sorted first by the first column, then by the second column within each value of the first column, and so on.

```kusto
StormEvents
| sort by State asc, StartTime desc
| take 5
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | EventType | InjuriesDirect | InjuriesIndirect | DeathsDirect | DeathsIndirect | ... |
|--|--|--|--|--|--|--|--|--|--|--|
| 2007-12-21T08:42:00Z | 2007-12-21T08:45:00Z | 14251 | 78267 | ALABAMA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-12-20T08:30:00Z | 2007-12-20T08:30:00Z | 14246 | 78173 | ALABAMA | Hail | 0 | 0 | 0 | 0 | ... |
| 2007-12-16T22:40:00Z | 2007-12-16T22:40:00Z | 14243 | 78015 | ALABAMA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-12-16T18:55:00Z | 2007-12-16T18:55:00Z | 14243 | 78014 | ALABAMA | Thunderstorm Wind | 0 | 0 | 0 | 0 | ... |
| 2007-11-14T21:48:00Z | 2007-11-14T21:48:00Z | 13654 | 70113 | ALABAMA | Hail | 0 | 0 | 0 | 0 | ... |

## Notes

* The default order for `sort` is `desc` (descending). Explicitly specifying the sort order makes your query more readable.
* Consider using the [`top`](top-operator.md) operator when you need to sort and limit the number of rows in one operation. `top` provides better performance than the combination of `sort` and `take`.
* Sorting requires shuffling data among cluster nodes. If the amount of data being sorted is large, performance may be impacted.
* For better performance when working with large datasets, consider using aggregations and summaries where possible instead of sorting the entire dataset.
