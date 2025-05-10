# Kusto Query Language Overview

A query is a read-only request to process data and return results. The request is stated in plain text, using a data-flow model that is easy to read, author, and automate. Queries always run in the context of a particular table or database. At a minimum, a query consists of a source data reference and one or more query operators applied in sequence, indicated visually by the use of a pipe character (|) to delimit operators.

Kusto Query Language is a powerful tool to explore your data and discover patterns, identify anomalies and outliers, create statistical modeling, and more. The query uses schema entities that are organized in a hierarchy similar to SQL's: databases, tables, and columns.

## Prerequisites

1. A workspace with a Microsoft Fabric-enabled capacity
2. A KQL database with data

## Basic Query Structure

The basic structure of a Kusto query consists of:
- A data source (usually a table)
- One or more operators applied in sequence using the pipe (|) character

Example:
```kusto
TableName
| where TimeGenerated > ago(1h)
| where Severity == "Error"
| project Computer, Message
| sort by TimeGenerated desc
```

## Common Operators

| Operator | Description | Syntax |
| --- | --- | --- |
| `where` | Filters on a specific predicate | `T | where Predicate` |
| `project` | Selects columns to include | `T | project ColumnName [= Expression] [, ...]` |
| `extend` | Creates calculated columns | `T | extend [ColumnName | (ColumnName[, ...]) =] Expression [, ...]` |
| `summarize` | Groups and aggregates | `T | summarize [[Column =] Aggregation [, ...]] [by [Column =] GroupExpression [, ...]]` |
| `join` | Merges rows from two tables | `LeftTable | join [JoinParameters] ( RightTable ) on Attributes` |
| `union` | Combines multiple tables | `[T1] | union [T2], [T3], …` |
| `sort` | Sorts rows | `T | sort by expression1 [asc | desc], expression2 [asc | desc], …` |
| `top` | Returns first N rows | `T | top numberOfRows by expression [asc | desc]` |
| `count` | Counts records | `T | count` |
| `render` | Visualizes results | `T | render Visualization [with (PropertyName = PropertyValue [, ...] )]` |

## Data Types

| Data type | Description |
| --- | --- |
| `datetime` | Data and time information typically representing event timestamps |
| `string` | Character string in UTF-8 enclosed in single quotes (`'`) or double quotes (`"`) |
| `bool` | Boolean values `true` or `false` |
| `int` | 32-bit integer |
| `long` | 64-bit integer |

## Time Series Analysis and Machine Learning

Kusto Query Language includes powerful capabilities for:
- Time series analysis
- Anomaly detection
- Forecasting
- Root cause analysis
- Clustering

The `python()` plugin extends KQL with Python capabilities, allowing the use of Python libraries for advanced machine learning scenarios.

## Resources

For more information on the Kusto Query Language, see [Kusto Query Language (KQL) Overview](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/index?context=/fabric/context/context).
