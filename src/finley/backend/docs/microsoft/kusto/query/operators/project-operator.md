# Project operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Selects the columns to include, rename, or drop, and inserts computed columns.

## Syntax

*T* `| project` [*ColumnName* | `(` *ColumnName* [`,` ...] `)` `=` ] *Expression* [`,` ...]

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *ColumnName* | string | | Name of a column to output. If omitted, the name is derived from the expression. Examples: `project` *foo* presents a column named *foo*; `project` *foo=bar* presents a column named *foo* that was calculated using the *bar* expression. |
| *Expression* | string | ✓ | An expression over the columns of the input that defines how to compute the value of a column in the result. |

## Returns

A table with columns as named in the arguments and as many rows as in the input table.

## Examples

### Project specific columns

The following query keeps only the `StartTime` and `State` columns:

```kusto
StormEvents
| project StartTime, State
| take 5
```

Output:

| StartTime | State |
|--|--|
| 2007-09-18T22:00:00Z | FLORIDA |
| 2007-09-20T21:57:00Z | FLORIDA |
| 2007-09-29T08:11:00Z | ATLANTIC SOUTH |
| 2007-10-01T20:00:00Z | FLORIDA |
| 2007-10-02T14:11:00Z | FLORIDA |

### Rename columns

The following query renames the `DamageProperty` column to `PropertyDamage`:

```kusto
StormEvents
| project StartTime, State, PropertyDamage=DamageProperty
| take 5
```

Output:

| StartTime | State | PropertyDamage |
|--|--|--|
| 2007-09-18T22:00:00Z | FLORIDA | 0 |
| 2007-09-20T21:57:00Z | FLORIDA | 0 |
| 2007-09-29T08:11:00Z | ATLANTIC SOUTH | 0 |
| 2007-10-01T20:00:00Z | FLORIDA | 15000 |
| 2007-10-02T14:11:00Z | FLORIDA | 0 |

### Create calculated columns

The following query creates a new column with a calculation:

```kusto
StormEvents
| project StartTime, State, Duration = EndTime - StartTime
| take 5
```

Output:

| StartTime | State | Duration |
|--|--|--|
| 2007-09-18T22:00:00Z | FLORIDA | 00:00:00 |
| 2007-09-20T21:57:00Z | FLORIDA | 00:00:00 |
| 2007-09-29T08:11:00Z | ATLANTIC SOUTH | 00:00:00 |
| 2007-10-01T20:00:00Z | FLORIDA | 00:00:00 |
| 2007-10-02T14:11:00Z | FLORIDA | 00:00:00 |

## Notes

The projection operation can involve complex calculations, including calls to many functions.

If you don't want to keep all original columns and just want to add new ones, use [`extend`](extend-operator.md) instead.

For other ways to modify column selection, use:
- [`project-away`](project-away-operator.md): Exclude specific columns
- [`project-keep`](project-keep-operator.md): Keep specific columns
- [`project-rename`](project-rename-operator.md): Rename columns
- [`project-reorder`](project-reorder-operator.md): Reorder columns
