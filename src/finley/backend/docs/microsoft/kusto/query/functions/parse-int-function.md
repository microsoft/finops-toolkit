# parse_int() function

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `parse_int()` function tries to convert a string representation of an integer to an actual integer value. If the conversion fails, a null value is returned.

## Syntax

```kusto
parse_int(string)
```

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *string* | string | ✓ | The string to be parsed as an integer. |

## Returns

If the conversion is successful, the result is an integer value. If the conversion is unsuccessful, the result is `null`.

## Examples

### Basic usage

```kusto
print result = parse_int("123")  // 123
```

### Handling invalid inputs

```kusto
print 
    Result1 = parse_int("123"),    // 123
    Result2 = parse_int("12.34"),  // null (contains decimal point)
    Result3 = parse_int("abc"),    // null (not a number)
    Result4 = parse_int("123abc"), // null (contains non-numeric characters)
    Result5 = parse_int("")        // null (empty string)
```

### With leading/trailing spaces

```kusto
print 
    Result1 = parse_int(" 123 ")  // 123 (spaces are trimmed)
```

### With sign

```kusto
print 
    Result1 = parse_int("+123"),  // 123
    Result2 = parse_int("-123")   // -123
```

### Using parse_int in queries

```kusto
Logs
| where parse_int(StatusCode) > 400  // Convert string status code to integer
```

### Extract and parse integers from text

```kusto
Logs
| extend ErrorCode = parse_int(extract("Error code: (\\d+)", 1, Message))
```

### Handle null values

```kusto
Logs
| extend NumericId = parse_int(Id)
| extend FinalId = iif(isnotnull(NumericId), NumericId, -1)  // Replace null with default
```

## Common patterns

### Converting multiple fields

```kusto
Logs
| extend
    StatusCode = parse_int(StatusCodeString),
    Count = parse_int(CountString),
    Duration = parse_int(DurationString)
```

### Filtering after parsing

```kusto
Logs
| extend StatusCode = parse_int(StatusCodeString)
| where isnotnull(StatusCode)  // Only keep rows where parsing succeeded
| where StatusCode between (400 .. 499)  // Filter for 4xx status codes
```

### Combining with other functions

```kusto
Logs
| extend ServerID = trim_start("SRV-", ServerName)
| extend ServerNumber = parse_int(ServerID)
```

## Performance considerations

1. `parse_int()` is more tolerant than `toint()` as it returns null instead of failing when conversion is not possible
2. For better performance in large datasets, consider using `toint()` if you're certain the input will always be a valid integer
3. Use `parse_int()` when working with potentially malformed data or when handling user input

## Related functions

- [toint()](toint-function.md) - Converts to integer, but raises an error for invalid inputs
- [tolong()](tolong-function.md) - Converts to 64-bit integer (long)
- [todouble()](todouble-function.md) - Converts to double-precision floating point
- [parse_json()](parse-json-function.md) - Parses a JSON string into a dynamic object
