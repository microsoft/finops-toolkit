# Count operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Returns a table with a single record containing the number of records in the input table.

## Syntax

*T* `| count`

## Parameters

*T*: The tabular input whose records are to be counted.

## Returns

This operator returns a table with a single record and column of type `long` named `Count`. The value of the only cell is the number of records in *T*.

## Examples

```kusto
StormEvents | count
```

Output:

| Count |
|-------|
| 59066 |

## Notes

`count` is equivalent to [`summarize count()`](summarize-operator.md).

```kusto
T | summarize count()
```

The `count` operator is often more performant than using `summarize count()` because it doesn't require grouping.
