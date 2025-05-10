# datetime data type

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `datetime` data type represents an instant in time, typically expressed as a date and time of day.

Values of `datetime` range from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59.9999999Z.

Internally, `datetime` values are stored as the number of ticks (1 tick = 100ns) since 1601-01-01 00:00:00.

## datetime literals

Literals of type `datetime` have the format `datetime(`*value*`)`. The following formats are supported for *value*:

|Format|Example|
|--|--|
|ISO 8601|`datetime(2015-12-31)`|
|ISO 8601 with time|`datetime(2015-12-31 23:59:59.9)`|
|ISO 8601 with T separator|`datetime(2015-12-31T23:59:59.9)`|
|ISO 8601 with timezone|`datetime(2015-12-31 23:59:59.9 +02:00)`|

You can also create datetime values using the [`todatetime()`](../functions/todatetime-function.md) function.

## Operators

The `datetime` data type supports the following operators:

* Equality operators: `==`, `!=`
* Comparison operators: `>`, `>=`, `<`, `<=`
* Addition and subtraction of a [`timespan`](timespan.md) value: `+`, `-`
* Subtraction of another `datetime` value, producing a `timespan` value

## Functions

Kusto provides many functions for working with datetime values:

* [`ago()`](../functions/ago-function.md): Returns a datetime that is the specified timespan earlier than the current time
* [`datetime_add()`](../functions/datetime-add-function.md): Adds a timespan to a datetime
* [`datetime_diff()`](../functions/datetime-diff-function.md): Returns the difference between two datetime values in specified units
* [`dayofmonth()`](../functions/dayofmonth-function.md): Returns the day number (1-31) of the month
* [`dayofweek()`](../functions/dayofweek-function.md): Returns the integer number of the day (0-6, with 0 = Sunday)
* [`dayofyear()`](../functions/dayofyear-function.md): Returns the day number (1-366) of the year
* [`endofday()`](../functions/endofday-function.md): Returns the end of the day containing the date, shifted by an offset
* [`endofmonth()`](../functions/endofmonth-function.md): Returns the end of the month containing the date
* [`endofweek()`](../functions/endofweek-function.md): Returns the end of the week containing the date
* [`endofyear()`](../functions/endofyear-function.md): Returns the end of the year containing the date
* [`format_datetime()`](../functions/format-datetime-function.md): Formats a datetime according to a format specification
* [`getmonth()`](../functions/getmonth-function.md): Get the month number (1-12) from a datetime
* [`getyear()`](../functions/getyear-function.md): Returns the year part of a datetime
* [`now()`](../functions/now-function.md): Returns the current UTC time
* [`startofday()`](../functions/startofday-function.md): Returns the start of the day containing the date
* [`startofmonth()`](../functions/startofmonth-function.md): Returns the start of the month containing the date
* [`startofweek()`](../functions/startofweek-function.md): Returns the start of the week containing the date
* [`startofyear()`](../functions/startofyear-function.md): Returns the start of the year containing the date
* [`todatetime()`](../functions/todatetime-function.md): Converts input to datetime scalar

## Examples

```kusto
print date1 = datetime(2020-01-01 12:00:00)
| extend date2 = datetime(2020-01-02 12:00:00)
| extend diff = date2 - date1
```

The output is:

| date1 | date2 | diff |
|--|--|--|
| 2020-01-01T12:00:00Z | 2020-01-02T12:00:00Z | 1.00:00:00 |

```kusto
print now() 
| extend yesterday = ago(1d)
| extend tomorrow = datetime_add('day', 1, now())
```

The output might be:

| now_ | yesterday | tomorrow |
|--|--|--|
| 2023-05-09T14:58:53.3028070Z | 2023-05-08T14:58:53.3028070Z | 2023-05-10T14:58:53.3028070Z |
