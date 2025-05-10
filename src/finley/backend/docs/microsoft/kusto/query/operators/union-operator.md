# Union operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Takes two or more tables and returns all their rows.

## Syntax

*Table1* `| union` [`kind=` *UnionFlavor*] [`withsource=` *ColumnName*] *Table2* [`,` *Table3* ...]

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *Table1*, *Table2*, ... | string | ✓ | The tabular data sources to be combined. |
| *UnionFlavor* | string | | Specifies how to handle columns. Options: `inner` (keep only columns that exist in all tables), `outer` (default, keep all columns, with null values where a column doesn't exist in a table). |
| *ColumnName* | string | | When specified, adds a column with this name to the output. The value identifies the source table for each row. |

## Returns

A table with:

* A row for each row in any of the input tables
* A column for each column that appears in any of the inputs (using the `outer` kind, which is the default)
* If you specify `kind=inner`, only columns that appear in all inputs are included in the output 
* The `withsource` parameter adds a column indicating which source table each row came from

## Examples

### Basic union

This example combines rows from two tables:

```kusto
StormEvents
| where EventType == "Tornado"
| union (StormEvents | where EventType == "Flood")
| take 5
```

Output:

| StartTime | EndTime | EpisodeId | EventId | State | ... |
|--|--|--|--|--|--|
| 2007-01-01T00:00:00Z | 2007-01-01T00:00:00Z | 11749 | 60580 | GEORGIA | ... |
| 2007-09-29T14:00:00Z | 2007-09-29T14:00:00Z | 13619 | 72881 | KANSAS | ... |
| 2007-03-13T21:00:00Z | 2007-03-13T21:00:00Z | 12646 | 65990 | TEXAS | ... |
| 2007-05-05T14:00:00Z | 2007-05-05T14:00:00Z | 13078 | 69300 | KANSAS | ... |
| 2007-08-23T12:00:00Z | 2007-08-23T12:00:00Z | 14096 | 73827 | IOWA | ... |

### Union with source tracking

This example adds a column to indicate the source of each row:

```kusto
StormEvents
| where EventType == "Tornado"
| union withsource=Source (StormEvents | where EventType == "Flood")
| where State == "FLORIDA"
| project Source, EventType, StartTime, EndTime
| take 5
```

Output:

| Source | EventType | StartTime | EndTime |
|--|--|--|--|
| Table1 | Tornado | 2007-06-04T19:25:00Z | 2007-06-04T19:30:00Z |
| Table1 | Tornado | 2007-02-02T12:15:00Z | 2007-02-02T12:15:00Z |
| Table2 | Flood | 2007-08-18T23:00:00Z | 2007-08-19T01:00:00Z |
| Table2 | Flood | 2007-01-05T18:00:00Z | 2007-01-06T07:00:00Z |
| Table2 | Flood | 2007-03-01T12:00:00Z | 2007-03-01T23:59:00Z |

### Union with inner join of columns

When using `kind=inner`, only columns that exist in all tables are included:

```kusto
StormEvents
| union kind=inner (PopulationData)
```

In this example, if `StormEvents` has columns not present in `PopulationData` or vice versa, those columns are not included in the output.

## Notes

1. Unlike SQL's UNION, the default behavior (`kind=outer`) is to keep all columns from all input tables, filling in null values where a column doesn't exist in a particular table.

2. The `union` operator can work with explicit table names or expressions that evaluate to tables.

3. For performance optimization:
   * Use `union` only when necessary. Consider using the [`find`](find-operator.md) operator for searching across multiple tables.
   * Filter tables before applying `union` to reduce the data volume.
   * When dealing with a large number of tables, you can use wildcards:
     ```kusto
     union K* | where ...
     ```

4. To execute a query across clusters, use the [`cluster()`](../management/cross-cluster-or-database-queries.md) function:
   ```kusto
   union (cluster('https://ade.kusto.windows.net/help').database('Samples').StormEvents), StormEvents
   ```
