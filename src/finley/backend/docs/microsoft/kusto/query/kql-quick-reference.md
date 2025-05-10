# KQL Quick Reference

This document provides a quick reference guide for Kusto Query Language (KQL) operators and functions.

Applies to: Microsoft Fabric, Azure Data Explorer, Azure Monitor, Microsoft Sentinel

## Filter/Search/Condition

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `where` | Filters on a specific predicate | `T | where Predicate` |
| `where contains/has` | `Contains`: Looks for any substring match `Has`: Looks for a specific word (better performance) | `T | where col1 contains/has "[search term]"` |
| `search` | Searches all columns in the table for the value | `[TabularSource | ] search [kind=CaseSensitivity] [in (TableSources)] SearchPredicate` |
| `take` | Returns the specified number of records. Use to test a query (synonym: `limit`) | `T | take NumberOfRows` |
| `case` | Adds a condition statement, similar to if/then/elseif | `case(predicate_1, then_1, predicate_2, then_2, predicate_3, then_3, else)` |

## Sort and Aggregate Dataset

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `sort operator` | Sort the rows of the input table by one or more columns | `T | sort by expression1 [asc \| desc], expression2 [asc \| desc], ...` |
| `top` | Returns the first N rows of the dataset when sorted | `T | top numberOfRows by expression [asc \| desc] [nulls first \| last]` |
| `summarize` | Groups rows according to by group columns, calculates aggregations | `T | summarize [[Column =] Aggregation [, ...]] [by [Column =] GroupExpression [, ...]]` |
| `count` | Counts records in the input table | `T | count` |
| `extend` | Creates calculated columns and appends them | `T | extend [ColumnName | (ColumnName[, ...]) =] Expression [, ...]` |

## Join and Union

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `join` | Merges rows of two tables by matching values | `LeftTable | join [JoinParameters] ( RightTable ) on Attributes` |
| `union` | Takes two or more tables and returns all their rows | `[T1] | union [T2], [T3], …` |
| `range` | Generates a table with an arithmetic series of values | `range columnName from start to stop step step` |

## Format Data

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `lookup` | Extends columns of a fact table with values from a dimension table | `T1 | lookup [kind = (leftouter \| inner)] ( T2 ) on Attributes` |
| `mv-expand` | Turns dynamic arrays into rows (multi-value expansion) | `T | mv-expand Column` |
| `distinct` | Produces a table with distinct combinations of columns | `distinct [ColumnName], [ColumnName]` |
| `parse` | Parses string expression into calculated columns | `T | parse [kind=regex [flags=regex_flags] \| simple \| relaxed] Expression with * (StringConstant ColumnName [: ColumnType]) *...` |

## Date/Time Functions

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `ago` | Returns time offset relative to query execution time | `ago(a_timespan)` |
| `format_datetime` | Returns data in various date formats | `format_datetime(datetime, format)` |
| `bin` | Rounds values and groups them | `bin(value, roundTo)` |

## Create/Remove Columns

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `print` | Outputs a single row with scalar expressions | `print [ColumnName =] ScalarExpression [',' ...]` |
| `project` | Selects columns to include in specified order | `T | project ColumnName [= Expression] [, ...]` |
| `project-away` | Selects columns to exclude from output | `T | project-away ColumnNameOrPattern [, ...]` |
| `project-keep` | Selects columns to keep in output | `T | project-keep ColumnNameOrPattern [, ...]` |
| `project-rename` | Renames columns in result output | `T | project-rename new_column_name = column_name` |
| `project-reorder` | Reorders columns in result output | `T | project-reorder Col2, Col1, Col* asc` |

## General

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `make-series` | Creates series of aggregated values along axis | `T | make-series [MakeSeriesParamters] [Column =] Aggregation [default = DefaultValue] [, ...] on AxisColumn from start to end step step [by [Column =] GroupExpression [, ...]]` |
| `let` | Binds a name to expressions | `let Name = ScalarExpression \| TabularExpression \| FunctionDefinitionExpression` |
| `invoke` | Runs a function on the input table | `T | invoke function([param1, param2])` |
| `evaluate pluginName` | Evaluates query language extensions (plugins) | `[T | ] evaluate [ evaluateParameters ] PluginName ( [PluginArg1 [, PluginArg2]... )` |

## Visualization

| Operator/Function | Description | Syntax |
| --- | --- | --- |
| `render` | Renders results as graphical output | `T | render Visualization [with (PropertyName = PropertyValue [, ...] )]` |
