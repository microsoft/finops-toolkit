# timespan data type

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `timespan` data type represents a time interval or duration.

## Overview

A `timespan` value represents a time interval. It can be positive, negative, or zero. Timespan values are represented internally as a count of ticks (1 tick = 100ns).

## timespan literals

Literals of type `timespan` have several formats:

### Integer suffixes

The simplest format is an integer followed by a time unit:

- `d` - days (1d = 24h)
- `h` - hours (1h = 60m)
- `m` - minutes (1m = 60s)
- `s` - seconds (1s = 1,000ms)
- `ms` - milliseconds (1ms = 1,000,000ns)
- `microsecond` - microseconds (1microsecond = 1,000ns)
- `ns` - nanoseconds

Examples:
```kusto
1d        // 1 day
24h       // 24 hours (same as 1d)
60m       // 60 minutes (same as 1h)
3d12h     // 3 days and 12 hours
```

### timespan() function

The `timespan()` function creates a timespan literal from a string:

```kusto
timespan("1.12:30:45.123")     // 1 day, 12 hours, 30 minutes, 45 seconds, and 123 milliseconds
timespan("00:30:00")           // 30 minutes
timespan("00:00:00.008")       // 8 milliseconds
```

### ISO 8601 format

```kusto
timespan("P1DT12H30M45.123S")  // 1 day, 12 hours, 30 minutes, 45 seconds, and 123 milliseconds
```

## Operations on timespan

### Arithmetic operations

Timespans support various arithmetic operations:

```kusto
// Addition and subtraction of timespans
1d + 12h               // 1.5 days
2d - 12h               // 1.5 days

// Multiplication and division with numbers
3 * 1d                 // 3 days
1d * 3                 // 3 days
7d / 7                 // 1 day
```

### Comparison operations

Timespans can be compared using the standard comparison operators:

```kusto
1d > 23h               // true
1h < 60m               // false (they're equal)
30m <= 0.5h            // true
```

## Converting to and from timespan

### Converting from other types

From `datetime`:
```kusto
now() - datetime(2023-01-01)  // timespan representing days since Jan 1, 2023
```

From `string`:
```kusto
totimespan("1.12:30:45.123")  // 1 day, 12 hours, 30 minutes, 45 seconds, and 123 milliseconds
```

From `real`:
```kusto
totimespan(1.5)  // 1.5 seconds
```

### Converting to other types

To `string`:
```kusto
tostring(1d)  // "1.00:00:00"
```

To `real` (seconds):
```kusto
todouble(2h30m)  // 9000.0 (seconds)
```

## Functions for timespan

### timespan components

Extract components from a timespan:

```kusto
let duration = 1d12h30m45s;
print 
    Days = duration / 1d,
    Hours = (duration % 1d) / 1h,
    Minutes = (duration % 1h) / 1m,
    Seconds = (duration % 1m) / 1s
```

### Format timespan

Format a timespan as a string:

```kusto
let duration = 1d12h30m45s;
print 
    StandardFormat = format_timespan(duration),
    CustomFormat = format_timespan(duration, 'hh:mm:ss')
```

## Common Patterns

### Query time windows

```kusto
// Data from the last 7 days
Events 
| where Timestamp > ago(7d)

// Data from a specific time window
Events 
| where Timestamp between (ago(7d) .. ago(1d))
```

### Duration calculations

```kusto
// Calculate event duration
Events 
| extend Duration = EndTime - StartTime
| where Duration > 5m  // Events longer than 5 minutes
```

### Binning by time interval

```kusto
// Group by 15-minute intervals
Events 
| summarize count() by bin(Timestamp, 15m)
```

## Related data types

- [datetime](datetime.md) - For points in time
- [date](date.md) - For calendar dates without time
