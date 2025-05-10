# Kusto functions overview

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides a rich set of built-in functions for data processing, manipulation, and analysis. This document provides an overview of the different types of functions available in KQL.

## Function types

KQL functions can be categorized into several types based on their purpose:

### Scalar functions

Scalar functions operate on a single value and return a single value. They can be used in any expression where a scalar value is expected.

Examples include:
- [datetime_part()](functions/datetime-part-function.md) - Extracts a specified part of a datetime value
- [strcat()](functions/strcat-function.md) - Concatenates strings
- [iif()](functions/iif-function.md) - Returns one of two values depending on a predicate

### Aggregation functions

Aggregation functions perform a calculation on a set of values and return a single value. These are typically used with the `summarize` operator.

Examples include:
- [count()](functions/count-aggregation-function.md) - Counts rows
- [avg()](functions/avg-aggregation-function.md) - Calculates the average
- [percentile()](functions/percentile-aggregation-function.md) - Calculates the percentile of a population

### Window functions

Window functions operate over a set of rows and return a value for each row. They are similar to aggregation functions but return multiple values.

Examples include:
- [next()](functions/next-function.md) - Returns the value of a column in a later row
- [prev()](functions/prev-function.md) - Returns the value of a column in an earlier row
- [row_cumsum()](functions/row-cumsum-function.md) - Calculates the cumulative sum of a column

### Time series functions

Time series functions are specialized for working with data across time intervals.

Examples include:
- [ago()](functions/ago-function.md) - Returns a timestamp relative to the current time
- [bin()](functions/bin-function.md) - Rounds values down to the nearest multiple
- [series_decompose_anomalies()](functions/series-decompose-anomalies-function.md) - Anomaly detection in time series

### String functions

String functions manipulate text values.

Examples include:
- [tolower()](functions/tolower-function.md) - Converts a string to lowercase
- [extract()](functions/extract-function.md) - Get a match for a regular expression
- [replace()](functions/replace-function.md) - Replace all occurrences of a substring

### Mathematical functions

Mathematical functions perform numerical calculations.

Examples include:
- [round()](functions/round-function.md) - Rounds a number to the nearest integer
- [sqrt()](functions/sqrt-function.md) - Square root function
- [rand()](functions/rand-function.md) - Random number generator

### User-defined functions

Besides built-in functions, Kusto allows you to define your own functions:

1. **Let statements**: Define inline functions for use within a query.

```kusto
let MyFunction = (param1:string, param2:int) {
    // Function logic here
    StormEvents
    | where State == param1
    | summarize Count=count() by EventType
    | top param2 by Count desc
};
// Call the function
MyFunction("TEXAS", 5)
```

2. **Stored functions**: Functions that are stored as part of the database schema and can be called from any query.

## Common functions by category

### Date and time functions

- [ago()](functions/ago-function.md) - Returns a timestamp relative to the current time
- [datetime_add()](functions/datetime-add-function.md) - Adds a time period to a datetime
- [now()](functions/now-function.md) - Returns the current UTC time
- [startofday()](functions/startofday-function.md) - Returns the start of the day
- [endofmonth()](functions/endofmonth-function.md) - Returns the end of the month

### Statistical functions

- [avg()](functions/avg-aggregation-function.md) - Calculates the average
- [min()](functions/min-aggregation-function.md) - Returns the minimum value
- [max()](functions/max-aggregation-function.md) - Returns the maximum value
- [stdev()](functions/stdev-aggregation-function.md) - Calculates the standard deviation
- [variance()](functions/variance-aggregation-function.md) - Calculates the variance

### String functions

- [countof()](functions/countof-function.md) - Counts occurrences of a substring
- [substring()](functions/substring-function.md) - Extracts a substring
- [trim()](functions/trim-function.md) - Removes leading and trailing whitespace
- [toupper()](functions/toupper-function.md) - Converts to uppercase
- [tolower()](functions/tolower-function.md) - Converts to lowercase

### Array functions

- [array_length()](functions/array-length-function.md) - Returns the number of elements in an array
- [array_sort_asc()](functions/array-sort-asc-function.md) - Sorts an array in ascending order
- [array_contains()](functions/array-contains-function.md) - Checks if an array contains a value
- [range()](functions/range-function.md) - Generates an array of values

### Conversion functions

- [todatetime()](functions/todatetime-function.md) - Converts to datetime
- [tostring()](functions/tostring-function.md) - Converts to string
- [toint()](functions/toint-function.md) - Converts to integer
- [toreal()](functions/toreal-function.md) - Converts to real number

## Further reading

For a complete list of functions, refer to the [function reference](functions/index.md).

For information on how to create your own functions, see [user-defined functions](functions/user-defined-functions.md).
