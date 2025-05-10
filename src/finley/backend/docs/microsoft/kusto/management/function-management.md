# Function Management Commands

This document covers the management commands for creating and managing functions in Azure Data Explorer.

## Overview

Functions in Azure Data Explorer allow you to:

1. Encapsulate complex queries for reuse
2. Build modular solutions
3. Create parameterized queries
4. Share common logic across multiple queries

## Function Types

Azure Data Explorer supports several types of functions:

1. **Scalar functions** - Return a single value
2. **Tabular functions** - Return a table result
3. **Stored functions** - Permanently stored in the database
4. **Query-defined functions** - Defined using `let` statements within a query

## Creating and Managing Functions

### .create function

Creates a new stored function in the database.

#### Syntax

```kusto
.create function [with (PropertyName = PropertyValue [, ...])]
FunctionName([ParamName:ParamType [, ...]])
{
    FunctionBody
}
```

#### Example - Scalar Function

```kusto
.create function GetMonthName(dt:datetime)
{
    case(
        month_of_year(dt) == 1, "January",
        month_of_year(dt) == 2, "February",
        month_of_year(dt) == 3, "March",
        month_of_year(dt) == 4, "April",
        month_of_year(dt) == 5, "May",
        month_of_year(dt) == 6, "June",
        month_of_year(dt) == 7, "July",
        month_of_year(dt) == 8, "August",
        month_of_year(dt) == 9, "September",
        month_of_year(dt) == 10, "October",
        month_of_year(dt) == 11, "November",
        month_of_year(dt) == 12, "December",
        "Unknown"
    )
}
```

#### Example - Tabular Function

```kusto
.create function EventsInPeriod(startTime:datetime, endTime:datetime)
{
    Events
    | where Timestamp between (startTime .. endTime)
    | summarize count() by EventType
}
```

### .create-or-alter function

Creates a new function or alters an existing one.

#### Syntax

```kusto
.create-or-alter function [with (PropertyName = PropertyValue [, ...])]
FunctionName([ParamName:ParamType [, ...]])
{
    FunctionBody
}
```

#### Example

```kusto
.create-or-alter function UsersWithMinimumOrders(minOrders:int)
{
    Users
    | join (
        Orders
        | summarize OrderCount = count() by UserId
        | where OrderCount >= minOrders
    ) on $left.Id == $right.UserId
    | project Id, Name, Email, OrderCount
}
```

### .drop function

Removes a function from the database.

#### Syntax

```kusto
.drop function FunctionName
```

#### Example

```kusto
.drop function GetMonthName
```

## Viewing Function Information

### .show function

Shows information about a specific function.

#### Syntax

```kusto
.show function FunctionName
```

#### Example

```kusto
.show function EventsInPeriod
```

### .show functions

Lists all functions in the database, optionally filtered by pattern.

#### Syntax

```kusto
.show functions
```

or

```kusto
.show functions (FunctionName1, FunctionName2, ...)
```

or

```kusto
.show functions FunctionPattern
```

#### Example

```kusto
.show functions
```

```kusto
.show functions Events*
```

## Function Properties

Functions support several properties that can be specified when creating or altering them:

| Property | Description | Example |
|----------|-------------|---------|
| `folder` | Logical folder for organizing functions | `with (folder="Helpers")` |
| `docstring` | Documentation string for the function | `with (docstring="Returns events in the given period")` |
| `skipvalidation` | Skip parameter type validation | `with (skipvalidation="true")` |
| `view` | Make function available as a view | `with (view="true")` |

### Setting Function Properties

#### Example

```kusto
.create-or-alter function with (
    folder = "Common",
    docstring = "Returns the count of events by type in the given time period"
)
EventsInPeriod(startTime:datetime, endTime:datetime)
{
    Events
    | where Timestamp between (startTime .. endTime)
    | summarize count() by EventType
}
```

## Using Query-Defined Functions

Query-defined functions use the `let` statement to define temporary functions within a query.

#### Example

```kusto
let GetRecentUsers = (days:int) {
    Users
    | where CreatedDate > ago(days * 1d)
};
GetRecentUsers(7) // Get users created in the last 7 days
```

## Function Caching

### .alter function caching-policy

Sets the caching policy for a function.

#### Syntax

```kusto
.alter function FunctionName policy caching hot = TimeSpan
```

#### Example

```kusto
.alter function DailyStatistics policy caching hot = 1d
```

## Best Practices

1. Use functions to encapsulate complex logic
2. Document your functions with the `docstring` property
3. Organize functions using the `folder` property
4. Use parameters to make functions flexible and reusable
5. Consider caching policies for frequently used functions
6. Use query-defined functions for query-specific logic
7. Use stored functions for logic shared across multiple queries

For more information on function management commands, refer to the [Azure Data Explorer documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/functions).
