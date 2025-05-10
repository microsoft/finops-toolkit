# KQL Scalar Functions Overview

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Scalar functions in Kusto Query Language (KQL) operate on a single row and return a value or values for each row. These functions are essential for data manipulation, transformation, and analysis in KQL queries.

## Categories of Scalar Functions

### Conversion Functions

These functions convert data from one type to another:

| Function | Description | Example |
|----------|-------------|---------|
| `tostring()` | Converts input to string representation | `tostring(123)` → `"123"` |
| `toint()` | Converts input to integer representation | `toint("123")` → `123` |
| `tolong()` | Converts input to long (64-bit) integer | `tolong("9223372036854775807")` |
| `todouble()` | Converts input to double (floating point) | `todouble("3.14")` → `3.14` |
| `tobool()` | Converts input to boolean value | `tobool("true")` → `true` |
| `todatetime()` | Converts input to datetime | `todatetime("2023-01-15")` |
| `totimespan()` | Converts input to timespan | `totimespan("1.12:30:45")` |

### String Functions

These functions operate on string values:

| Function | Description | Example |
|----------|-------------|---------|
| `strcat()` | Concatenates strings | `strcat("Hello", ", ", "World")` → `"Hello, World"` |
| `strlen()` | Returns string length | `strlen("Hello")` → `5` |
| `substring()` | Extracts part of string | `substring("Hello", 1, 3)` → `"ell"` |
| `toupper()` | Converts to uppercase | `toupper("Hello")` → `"HELLO"` |
| `tolower()` | Converts to lowercase | `tolower("Hello")` → `"hello"` |
| `trim()` | Removes leading/trailing whitespace | `trim(" Hello ")` → `"Hello"` |
| `replace()` | Replaces string pattern | `replace("Hello", "l", "w")` → `"Hewwo"` |
| `countof()` | Counts occurrences of substring | `countof("Hello", "l")` → `2` |
| `extract()` | Extracts match using regex | `extract("x=([0-9]+)", 1, "x=123")` → `"123"` |

### Mathematical Functions

These functions perform mathematical operations:

| Function | Description | Example |
|----------|-------------|---------|
| `abs()` | Absolute value | `abs(-5)` → `5` |
| `sqrt()` | Square root | `sqrt(16)` → `4` |
| `pow()` | Power | `pow(2, 3)` → `8` |
| `exp()` | Exponential | `exp(1)` → `2.71828` |
| `log()` | Natural logarithm | `log(10)` → `2.30259` |
| `round()` | Rounds to nearest integer | `round(3.5)` → `4` |
| `floor()` | Rounds down | `floor(3.7)` → `3` |
| `ceiling()` | Rounds up | `ceiling(3.2)` → `4` |

### Date and Time Functions

These functions work with date and time values:

| Function | Description | Example |
|----------|-------------|---------|
| `now()` | Current UTC datetime | `now()` → `2023-12-31T12:34:56.7890000Z` |
| `ago()` | Datetime relative to now | `ago(1h)` → `2023-12-31T11:34:56.7890000Z` |
| `datetime_add()` | Add time to datetime | `datetime_add('day', 1, datetime(2023-01-15))` |
| `datetime_diff()` | Difference between datetimes | `datetime_diff('hour', datetime(2023-01-16), datetime(2023-01-15))` → `24` |
| `dayofweek()` | Day of week (0-6) | `dayofweek(datetime(2023-01-15))` → `0` (Sunday) |
| `startofday()` | Start of day | `startofday(datetime(2023-01-15T15:30:45))` → `2023-01-15T00:00:00Z` |
| `endofday()` | End of day | `endofday(datetime(2023-01-15T15:30:45))` → `2023-01-15T23:59:59.999Z` |

### Logical and Conditional Functions

These functions evaluate conditions and provide logical operations:

| Function | Description | Example |
|----------|-------------|---------|
| `iif()` | If-then-else expression | `iif(2 > 1, "Greater", "Less")` → `"Greater"` |
| `case()` | Multi-condition cases | `case(x == 1, "One", x == 2, "Two", "Other")` |
| `coalesce()` | First non-null value | `coalesce(null, "Hello", "World")` → `"Hello"` |
| `isnotnull()` | Checks if not null | `isnotnull("Test")` → `true` |
| `isnull()` | Checks if null | `isnull(null)` → `true` |

### Array Functions

These functions operate on arrays:

| Function | Description | Example |
|----------|-------------|---------|
| `array_length()` | Number of elements | `array_length(dynamic([1,2,3]))` → `3` |
| `array_contains()` | Checks if array contains value | `array_contains(dynamic([1,2,3]), 2)` → `true` |
| `array_index_of()` | Index of element | `array_index_of(dynamic([1,2,3]), 2)` → `1` |
| `array_concat()` | Concatenates arrays | `array_concat(dynamic([1,2]), dynamic([3,4]))` → `[1,2,3,4]` |
| `array_sum()` | Sum of elements | `array_sum(dynamic([1,2,3]))` → `6` |

## Best Practices

1. **Type Conversion**: Always use appropriate conversion functions when working with mixed data types.
2. **Null Handling**: Use `isnull()` and `isnotnull()` to check for nulls, and `coalesce()` to provide default values.
3. **Performance**: String functions can be expensive for large datasets. Consider optimizing where possible.
4. **Date Calculations**: Use `ago()` for relative time calculations rather than `now() - interval`.
5. **Error Handling**: Use `try_cast()` and similar functions when there's a risk of conversion errors.

## See Also

- [String Functions](./string-functions.md)
- [Numeric Functions](./numeric-functions.md)
- [Datetime Functions](./datetime-functions.md)
- [Dynamic/Array Functions](./dynamic-functions.md)
