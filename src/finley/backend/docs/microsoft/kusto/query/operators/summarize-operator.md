# Summarize operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Produces a table that aggregates the content of the input table.

## Syntax

*T* `| summarize` [`hint.shufflekey=`*Column*] [[*Column* `=`] *Aggregation* [`,` ...]] [`by` [*Column* `=`] *GroupExpression* [`,` ...]]

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *Column* | string | | The name for the result column. Defaults to a name derived from the expression. |
| *Aggregation* | string | | A call to an [aggregation function](../aggregation-functions.md) such as `count()` or `avg()`, with column names as arguments. |
| *GroupExpression* | string | | An expression over the columns that specifies which set of values to group. |

## Returns

A table with rows containing the specified aggregation values for each of the distinct values of the `by` expressions. The output contains as many rows as there are distinct combinations of `by` values, and as many columns as there are aggregations and `by` expressions. 

If there is no `by` clause, the output table has just a single record.

## Examples

### Count rows by state

```kusto
StormEvents
| summarize Count=count() by State
| top 5 by Count desc
```

Output:

| State | Count |
|-------|-------|
| TEXAS | 4701 |
| KANSAS | 3166 |
| IOWA | 2337 |
| ILLINOIS | 2022 |
| MISSOURI | 2016 |

### Sum values by category

```kusto
StormEvents
| summarize TotalDamage=sum(DamageProperty) by EventType
| top 5 by TotalDamage desc
```

Output:

| EventType | TotalDamage |
|-----------|-------------|
| Tornado | 5528938650 |
| Flash Flood | 5396497100 |
| Thunderstorm Wind | 4765918796 |
| Hail | 3022622694 |
| Flood | 2688407800 |

### Multiple aggregations

You can apply multiple aggregations in the same `summarize` operation:

```kusto
StormEvents
| summarize EventCount=count(), 
            StormDuration=avg(EndTime - StartTime),
            MaxDamage=max(DamageProperty)
          by State
| top 5 by MaxDamage desc
```

Output:

| State | EventCount | StormDuration | MaxDamage |
|-------|------------|---------------|-----------|
| MISSOURI | 2016 | 00:42:21.5835 | 2500000000 |
| TEXAS | 4701 | 00:49:27.6851 | 1500000000 |
| ILLINOIS | 2022 | 00:49:10.6491 | 950000000 |
| FLORIDA | 1042 | 00:33:11.8894 | 500000000 |
| MISSISSIPPI | 1375 | 00:38:25.4096 | 400000000 |

### Group by multiple columns

```kusto
StormEvents
| where DamageCrops > 0
| summarize TotalDamage=sum(DamageCrops) by State, EventType
| top 5 by TotalDamage desc
```

Output:

| State | EventType | TotalDamage |
|-------|-----------|-------------|
| IOWA | Hail | 449117000 |
| ILLINOIS | Flood | 320000000 |
| IOWA | Flood | 297000000 |
| MINNESOTA | Flood | 288000000 |
| MISSOURI | Flood | 258000000 |

### Group by computed columns

You can use any expression as a grouping key in the `by` clause, not just a column name:

```kusto
StormEvents
| where StartTime > datetime(2007-01-01)
| summarize Count=count() by Month=startofmonth(StartTime)
| top 5 by Count desc
```

Output:

| Month | Count |
|-------|-------|
| 2007-06-01T00:00:00Z | 6486 |
| 2007-05-01T00:00:00Z | 6067 |
| 2007-07-01T00:00:00Z | 5799 |
| 2007-04-01T00:00:00Z | 5239 |
| 2007-08-01T00:00:00Z | 4152 |

## Performance tips

* Apply filters (`where` operator) before using `summarize` to reduce the amount of data being processed.

* For columns with high cardinality (many distinct values), use the `hint.shufflekey` to potentially improve performance:

  ```kusto
  StormEvents
  | summarize hint.shufflekey = State Count=count() by State
  ```

* The `summarize` operator is resource-intensive. Consider these alternatives when appropriate:
  * Use [`count`](count-operator.md) instead of `summarize count()` when you just need the total row count.
  * Use [`top-nested`](top-nested-operator.md) for multiple levels of summarization.
  * Use [`top-hitters`](top-hitters-operator.md) for approximate aggregations of high-cardinality columns.
