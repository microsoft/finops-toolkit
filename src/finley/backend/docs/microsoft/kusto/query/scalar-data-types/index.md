# Scalar data types

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

This document lists the scalar data types supported by the Kusto Query Language.

## Supported data types

The following table lists the scalar data types supported by Kusto:

| Type | Description |
|--|--|
| `bool` | A boolean value, `true` or `false` |
| `datetime` | A date and time value |
| `decimal` | A 128-bit decimal value |
| `dynamic` | An array or property bag of values |
| `guid` | A globally-unique identifier value |
| `int` | A 32-bit signed integer value |
| `long` | A 64-bit signed integer value |
| `real` | A 64-bit floating-point value |
| `string` | A text value (Unicode) |
| `timespan` | A time interval value |

## Common scalar data types

### bool

The `bool` data type represents a Boolean value: `true` or `false`.

#### Operators on bool

`==` (equality), `!=` (inequality), `!` (logical NOT), `and` (logical AND), `or` (logical OR)

All comparison operators (`>`, `>=`, `<`, `<=`, `==`, `!=`) can be applied to bool values.

### datetime

The `datetime` data type represents an instant in time, typically expressed as a date and time of day.

Values of `datetime` range from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59.9999999Z.

Internally, `datetime` values are stored as the number of ticks (1 tick = 100ns) since 1601-01-01 00:00:00.

#### datetime literals

Literals of type `datetime` have the form `datetime(`*value*`)`, where a number of formats are supported for *value*:

```
datetime(2015-12-31)
datetime(2015-12-31 23:59:59.9)
datetime(2015-12-31T23:59:59.9)
datetime(2015-12-31 23:59:59.9 +02:00)
```

### dynamic

The `dynamic` data type is special in that it can take on values of other data types, such as arrays or property bags (JSON objects).

Example:

```kusto
StormEvents
| extend info = dynamic({"warning": "A storm happened", "severity": 5})
| project info.warning, info.severity
```

### int

The `int` data type represents a 32-bit signed integer.

### long

The `long` data type represents a 64-bit signed integer.

### real

The `real` data type represents a 64-bit double-precision floating-point number.

### string

The `string` data type represents a sequence of zero or more Unicode characters.

String literals are enclosed by either single quotes (') or double quotes ("):

```
"this is a string literal"
'this is a string literal'
```

### timespan

The `timespan` data type represents a time interval.

Values of `timespan` range from -10675199 days through +10675199 days.

Timespan literals have the form `timespan(`*value*`)` where a number of formats are supported for *value*:

```
timespan(0.12:23:45.6789)   // 0 days, 12 hours, 23 minutes, 45.6789 seconds
timespan(3.14:15:926)      // 3 days, 14 hours, 15 minutes, 92.6 seconds
timespan(-1.23:45:67.89)   // -1 days, 23 hours, 45 minutes, 67.89 seconds
```

## Data type conversions

Kusto provides a number of functions for data type conversions:

- [`toboolean()`](../functions/tobool-function.md)
- [`todatetime()`](../functions/todatetime-function.md)
- [`todouble()`](../functions/todouble-function.md)
- [`toint()`](../functions/toint-function.md)
- [`tolong()`](../functions/tolong-function.md)
- [`toreal()`](../functions/toreal-function.md)
- [`tostring()`](../functions/tostring-function.md)
- [`totimespan()`](../functions/totimespan-function.md)
