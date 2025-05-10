# bool data type

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `bool` data type represents a boolean (logical) value that can be either `true` or `false`.

## Overview

Boolean values are fundamental in programming and data analysis for representing conditions, flags, and binary states. In Kusto Query Language, they're used for logical operations, condition expressions, and filters.

## bool literals

Literals of type `bool` can be represented in two ways:

```kusto
true
false
```

## Operations on bool

### Logical operations

Boolean values support the following logical operations:

1. Logical AND: `and`
   ```kusto
   true and true    // true
   true and false   // false
   false and false  // false
   ```

2. Logical OR: `or`
   ```kusto
   true or true     // true
   true or false    // true
   false or false   // false
   ```

3. Logical NOT: `not`
   ```kusto
   not true         // false
   not false        // true
   ```

4. Logical XOR: `xor`
   ```kusto
   true xor true    // false
   true xor false   // true
   false xor false  // false
   ```

### Comparison operations

Boolean values can be compared for equality:

```kusto
true == true        // true
true == false       // false
true != false       // true
```

Note that in KQL, comparison operators like `<`, `>`, `<=`, `>=` are not defined for boolean values.

## Converting to and from bool

### Converting from other types

From `string`:
```kusto
tobool("true")      // true
tobool("false")     // false
tobool("True")      // true (case-insensitive)
tobool("yes")       // true
tobool("no")        // false
tobool("1")         // true
tobool("0")         // false
```

From `int` or other numeric types:
```kusto
tobool(1)           // true
tobool(0)           // false
tobool(123)         // true (any non-zero value is true)
```

From `dynamic`:
```kusto
tobool(dynamic(true))  // true
tobool(dynamic(false)) // false
```

### Converting to other types

To `string`:
```kusto
tostring(true)      // "true"
tostring(false)     // "false"
```

To `int`:
```kusto
toint(true)         // 1
toint(false)        // 0
```

## Common Patterns

### Filtering data using bool columns

```kusto
Events
| where IsError == true
```

Or simply:

```kusto
Events
| where IsError  // Implicit comparison with true
```

### Negating bool conditions

```kusto
Events
| where not IsError
```

Or:

```kusto
Events
| where IsError == false
```

### Creating bool expressions

```kusto
Events
| extend 
    IsCritical = Level == "Critical",
    IsFromEurope = Region in ("EU-West", "EU-Central", "EU-North")
| where IsCritical or IsFromEurope
```

### Conditional evaluation with bool

Using `iff()` function:

```kusto
Events
| extend Severity = iff(IsError, "High", "Normal")
```

Using the `case()` function:

```kusto
Events
| extend Severity = case(
    IsError and IsUserImpacting, "Critical",
    IsError, "High",
    "Normal")
```

### Aggregating bool values

The bool data type can be aggregated using functions like:

```kusto
Events
| summarize 
    ErrorCount = countif(IsError),
    ErrorRate = avg(toint(IsError)) * 100 // Calculate percentage
    by Region
```

## Performance Considerations

1. Boolean expressions are particularly efficient for filtering in KQL
2. Use boolean filters as early as possible in the query pipeline
3. Precomputing boolean conditions with `extend` can improve readability for complex conditions
4. When using multiple boolean conditions, order them from most selective to least selective

## Related data types

- [int](int.md) - For integer values
- [string](string.md) - For text data
