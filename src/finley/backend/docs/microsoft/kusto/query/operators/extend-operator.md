# extend operator

The `extend` operator adds calculated columns to a tabular result set. The new columns are computed for each row based on the expressions provided.

## Syntax

```kusto
T | extend [ColumnName | (ColumnName [, ...]) =] Expression [, ...]
```

## Parameters

* *T*: The input tabular result set.
* *ColumnName*: Optional name for a new column. If omitted, a name will be generated.
* *Expression*: An expression calculated over the columns of the input row.

## Returns

A copy of the input tabular result set, with the specified calculated columns added.

## Examples

### Basic usage

This example adds a new column called `Duration` that calculates the difference between two datetime columns.

```kusto
Events
| extend Duration = EndTime - StartTime
```

### Multiple columns

You can add multiple columns in a single `extend` operation.

```kusto
Events
| extend 
    Duration = EndTime - StartTime,
    EventDayOfWeek = dayofweek(StartTime),
    EventMonth = monthofyear(StartTime)
```

### Using previous calculated columns

You can use previously calculated columns in subsequent expressions within the same `extend` operation.

```kusto
Events
| extend 
    Duration = EndTime - StartTime,
    DurationInMinutes = Duration / 1m
```

### Mathematical expressions

```kusto
Metrics
| extend 
    ValueSquared = Value * Value,
    ValueSqrt = sqrt(Value),
    ValueLog = log10(Value)
```

### String operations

```kusto
Users
| extend 
    NameUpperCase = toupper(Name),
    NameLength = strlen(Name),
    FirstLetter = substring(Name, 0, 1)
```

### Expressions with multiple columns

```kusto
Orders
| extend 
    Subtotal = Quantity * UnitPrice,
    TaxAmount = Quantity * UnitPrice * TaxRate,
    Total = Quantity * UnitPrice * (1 + TaxRate)
```

### JSON parsing

The `extend` operator is particularly useful for extracting values from JSON stored in dynamic columns.

```kusto
Traces
| extend
    UserName = tostring(Properties.user.name),
    UserEmail = tostring(Properties.user.email),
    ActionType = tostring(Properties.action.type)
```

### Working with arrays

```kusto
SecurityEvents
| extend
    SourceIPAddress = tostring(Data.SourceIP),
    SourcePort = toint(Data.SourcePort),
    DestinationIPAddresses = Data.DestinationIPs,
    DestinationIPCount = array_length(Data.DestinationIPs)
```

### Conditional extensions

```kusto
Events
| extend
    Severity = case(
        Level == "Error", 1,
        Level == "Warning", 2,
        Level == "Info", 3,
        4)
```

## Comparing `extend` with `project`

Both `extend` and `project` can be used to create new columns, but they have different behaviors:

- `extend` adds new columns but keeps all existing columns
- `project` creates new columns and allows you to select which existing columns to keep

Example of difference:

**extend**:
```kusto
Events
| extend Duration = EndTime - StartTime
// Result contains all original columns plus the new Duration column
```

**project**:
```kusto
Events
| project EventId, StartTime, EndTime, Duration = EndTime - StartTime
// Result contains only the columns explicitly listed
```

## Performance Tips

1. Use `extend` when you need to create calculated columns while keeping all existing columns.
2. If you only need a subset of columns plus some calculated ones, consider using `project` instead.
3. The `extend` operator doesn't reduce the number of rows - for filtering, use `where` before `extend`.
4. Calculate fields once with `extend` and reuse them in subsequent operations rather than recalculating.
5. For complex transformations on large datasets, consider whether calculations can be done after aggregation to improve performance.

## Related Operators

- [project](project-operator.md) - Creates a result set with specific columns
- [project-away](project-away-operator.md) - Excludes specific columns
- [summarize](summarize-operator.md) - Aggregates groups of rows
