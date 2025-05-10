# Join operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Merges the rows of two tables to form a new table by matching values of the specified column(s) from each table.

## Syntax

*LeftTable* `| join` [`kind=` *JoinFlavor*] [ `hint.strategy=` *Strategy* ] [ `hint.shufflekey=` *Column* ] [`hint.remote=` *RemoteClusterName* ] ( *RightTable* ) `on` *Attributes*

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *LeftTable* | string | ✓ | The left (or outer) tabular data source to be joined. Also referenced as `$left`. |
| *RightTable* | string | ✓ | The right (or inner) tabular data source to be joined. Also referenced as `$right`. |
| *JoinFlavor* | string | | Specifies the kind of join to perform. Options include: `inner` (default), `leftouter`, `rightouter`, `fullouter`, `innerunique`, `leftanti`, `leftantisemi`, and others (see join flavors section). |
| *Strategy* | string | | Advanced option to control join strategy. Options include: `broadcast`, `shuffle`. |
| *Attributes* | string | ✓ | Specifies the column(s) to match between tables. Format: `$left.LeftColumn == $right.RightColumn` or just `CommonColumn` if both tables have the same column name. |

## Returns

A table with:
* A column for each column in each of the two tables, including the join key columns. The columns from the right table will be automatically renamed if there are name conflicts.
* A row for each matching pair of values from the left and right tables, depending on the join flavor. A match is when the specified columns in the left row and right row have equal values.

> [!NOTE]
> If the $left side produces more than 1,000,000 rows, the query will fail unless you broadcast the values to the right side of the join.

## Join flavors

### Inner join (default)

The `inner` join flavor, which is the default, returns the intersection of the two tables based on the join key.

```
LeftTable | join RightTable on Key
```

This is equivalent to:

```
LeftTable | join kind=inner RightTable on Key
```

### Outer joins

Outer joins (left, right, full) include rows from one or both tables even if there's no match.

* **Left outer join** (`kind=leftouter`): Returns all rows from the left table and only the matching rows from the right table.
* **Right outer join** (`kind=rightouter`): Returns all rows from the right table and only the matching rows from the left table.
* **Full outer join** (`kind=fullouter`): Returns all rows from both tables, matching where possible.

### Anti-joins

Anti-joins return rows from one table that don't match any row in the other table.

* **Left anti join** (`kind=leftanti`): Returns only rows from the left table that don't match any row in the right table.
* **Right anti join** (`kind=rightanti`): Returns only rows from the right table that don't match any row in the left table.

## Examples

### Basic inner join

```kusto
StormEvents
| where State == "TEXAS" 
| summarize TotalDamage=sum(DamageProperty) by State
| join (PopulationData) on State
| project State, TotalDamage, Population, DamagePerCapita=TotalDamage/Population
```

### Join with different column names

When the join columns have different names, use the `$left` and `$right` notation:

```kusto
StormEvents 
| join (PopulationData) on $left.State == $right.StateName
```

### Left outer join

Perform a left outer join to include all rows from the left table:

```kusto
StormEvents
| summarize EventCount=count() by State
| join kind=leftouter (PopulationData) on State
| project State, EventCount, Population=coalesce(Population, 0)
```

## Performance tips

For better join performance:

1. **Put the smaller table on the left side** of the join whenever possible. The join operator matches each row from the left table to the right table, so having fewer rows on the left reduces the number of lookups needed.

2. **Filter both tables before joining** to reduce the data volume involved in the join.

3. **Use the appropriate join flavor** to avoid unnecessary processing. For example, `innerunique` can be more efficient than `inner` when you only need one match from the right table.

4. **Use join hints** to optimize performance when working with large tables. For example:
   ```kusto
   Table1 
   | join hint.strategy=broadcast Table2 on Key
   ```

5. **Consider alternatives to join** such as [lookup](lookup-operator.md) for reference data scenarios or [union](union-operator.md) when you need to combine rows rather than join them.
