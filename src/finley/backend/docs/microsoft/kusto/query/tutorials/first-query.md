# Writing Your First Query with Kusto Query Language

This guide introduces the basics of writing queries in Kusto Query Language (KQL).

## Learning Objectives

By the end of this guide, you'll be able to:

- Write your first query with KQL
- Use KQL to explore data by using the most common operators

## Basic Structure of a Kusto Query

Kusto queries are written using a query language specifically designed for log and time-series data analysis. The language is designed to be easy to read and author.

A basic query typically includes:

1. **Data source**: A reference to a table in your database
2. **Operators**: Commands that manipulate the data, separated by the pipe character (`|`)

For example:

```kusto
StormEvents
| where StartTime >= datetime(2007-02-01) and StartTime < datetime(2007-03-01)
| where State == "FLORIDA" 
| count
```

## Common Operators

### `take` - Return a Specific Number of Rows

The `take` operator returns a specific number of rows from a table. It's useful when you want to see a sample of your data:

```kusto
StormEvents
| take 5
```

This query returns 5 random rows from the StormEvents table.

### `project` - Select Columns to Return

The `project` operator allows you to select specific columns to include in your result:

```kusto
StormEvents
| project EventId, StartTime, EndTime, State, EventType
| take 10
```

This query returns 10 rows with only the specified columns.

### `where` - Filter Data

The `where` operator filters a table to include only rows that satisfy a condition:

```kusto
StormEvents
| where State == "TEXAS"
| where EventType == "Tornado"
| project StartTime, EndTime, State, EventType
| take 10
```

This query returns tornado events that occurred in Texas.

### `sort` - Reorder Returned Data

The `sort` operator (also known as `order`) sorts the rows of the input table by one or more columns:

```kusto
StormEvents
| where EventType == "Tornado"
| sort by StartTime desc
| project StartTime, State, EventType
| take 10
```

This query returns the 10 most recent tornado events, sorted by start time in descending order.

## Challenge

Try writing a query that:
1. Filters the StormEvents table to include only events from "WASHINGTON" state
2. Selects the EventId, StartTime, EndTime, and EventType columns
3. Sorts the results by StartTime in ascending order
4. Limits the results to 15 rows

Solution:
```kusto
StormEvents
| where State == "WASHINGTON"
| project EventId, StartTime, EndTime, EventType
| sort by StartTime asc
| take 15
```

## Summary

In this guide, you've learned:

- The basic structure of a Kusto query
- How to use common operators like `take`, `project`, `where`, and `sort`
- How to combine these operators to create more complex queries

These basic operators form the foundation for more advanced queries that can help you gain insights from your data.
