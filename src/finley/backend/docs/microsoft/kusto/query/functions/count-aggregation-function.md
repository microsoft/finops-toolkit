# count() aggregation function

The `count()` function returns a count of the rows in the input record set.

## Syntax

```kusto
T | count
```

or

```kusto
T | summarize count()
```

## Returns

Returns a table with a single record and a single column named `count_` (in the `summarize` version) or `Count` (in the direct count operator version). The only value in the record is an integer representing the number of rows in T.

## Examples

### Using the count operator

This example shows how to count all rows in the Events table.

```kusto
Events
| count
```

Result:

| Count |
|-------|
| 42    |

### Using count() with summarize

This example counts all rows in the Events table, but uses the summarize operator.

```kusto
Events
| summarize count()
```

Result:

| count_ |
|--------|
| 42     |

### Counting specific rows with a filter

This example counts the number of events with Level = "Error".

```kusto
Events
| where Level == "Error"
| count
```

### Counting by groups

This example counts events by their level.

```kusto
Events
| summarize count() by Level
```

Result:

| Level   | count_ |
|---------|--------|
| Error   | 12     |
| Warning | 18     |
| Info    | 12     |

### Using count() with other aggregations

This example shows how to use count along with other aggregation functions.

```kusto
Events
| summarize Count=count(), 
    AvgDuration=avg(Duration), 
    MaxDuration=max(Duration) 
    by Level
```

Result:

| Level   | Count | AvgDuration | MaxDuration |
|---------|-------|-------------|-------------|
| Error   | 12    | 73.5        | 150         |
| Warning | 18    | 44.2        | 112         |
| Info    | 12    | 22.1        | 44          |

### Counting with multiple dimensions

This example counts events by both Level and EventType.

```kusto
Events
| summarize count() by Level, EventType
```

Result:

| Level   | EventType  | count_ |
|---------|------------|--------|
| Error   | SystemError| 5      |
| Error   | UserError  | 7      |
| Warning | LowDisk    | 3      |
| Warning | HighCPU    | 15     |
| Info    | Startup    | 4      |
| Info    | Shutdown   | 8      |

### Counting distinct values

To count distinct values, use the [dcount()](dcount-aggregation-function.md) function.

```kusto
Events
| summarize CountOfUsers=dcount(UserId) by EventType
```

## Performance Tips

1. When possible, apply filters (`where` operator) before `count` to reduce the amount of data processed.
2. If you're only interested in the count, avoid using `project` before `count` as it doesn't reduce the number of rows.
3. For high-cardinality fields (like UserID), use [dcount()](dcount-aggregation-function.md) to get distinct counts efficiently.
4. The direct `count` operator is slightly more efficient than `summarize count()` for simple counts.

## Related Functions and Operators

- [summarize](../operators/summarize-operator.md) - Aggregates the input by group
- [dcount()](dcount-aggregation-function.md) - Returns an estimate of the number of distinct values
- [countif()](countif-aggregation-function.md) - Returns a count of rows for which the predicate evaluates to true
