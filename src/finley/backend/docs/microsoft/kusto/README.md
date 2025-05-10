# Kusto Query Language (KQL) Documentation

This directory contains comprehensive documentation about Kusto Query Language (KQL) and Azure Data Explorer.

## What is Kusto?

Kusto is a service for storing and running interactive analytics over Big Data. Azure Data Explorer is the Microsoft Azure data service that uses Kusto. Kusto Query Language (KQL) is used to query and analyze data across many Microsoft products, including:

- Azure Data Explorer
- Azure Monitor
- Application Insights
- Microsoft Sentinel
- Microsoft Defender for Endpoint
- Microsoft Fabric

## Directory Structure

- [**query/**](query/) - Kusto Query Language documentation
  - [**operators/**](query/operators/) - Documentation for KQL operators 
  - [**functions/**](query/functions/) - Documentation for KQL functions
  - [**scalar-data-types/**](query/scalar-data-types/) - Documentation for KQL data types
  - [**plugins/**](query/plugins/) - Documentation for plugins like Python integration
  - [**tutorials/**](query/tutorials/) - KQL tutorials and examples
- [**management/**](management/) - Documentation for Kusto management commands
- [**api/**](api/) - Documentation for Kusto APIs

## Contents

1. **[KQL Overview](query/kql-overview.md)** - Introduction to Kusto Query Language, its basic structure, and common operators.

2. **[KQL Quick Reference](query/kql-quick-reference.md)** - A quick reference guide to KQL operators and functions, organized by category.

3. **[First Query](query/tutorials/first-query.md)** - Learn how to write your first KQL query, including basic operators like `take`, `project`, `where`, and `sort`.

4. **[Gain Insights](query/tutorials/gain-insights.md)** - Advanced querying techniques using aggregation functions, visualization, and variables.

5. **[Query Data](query-data.md)** - How to use KQL querysets to run queries and customize results from different data sources.

6. **[Azure Data Explorer Overview](azure-data-explorer-overview.md)** - Introduction to Azure Data Explorer, its capabilities, and what makes it unique.

7. **[Machine Learning Features](query/machine-learning-features.md)** - Overview of the machine learning and AIOps capabilities in KQL.

8. **[Debug Inline Python](query/plugins/debug-inline-python.md)** - How to debug Python code embedded in KQL queries using Visual Studio Code.

9. **[Integrations Overview](integrations-overview.md)** - Available tools and services that integrate with KQL and Azure Data Explorer.

## Key Features of KQL

- **Simple and intuitive syntax** - Easy to learn and use, with a pipe-based syntax similar to PowerShell and Unix/Linux pipelines
- **Optimized for log and time-series data** - Perfect for analyzing logs, telemetry, and IoT data
- **Built-in visualization** - Create charts and graphs directly in your queries
- **Advanced analytics capabilities** - Time series analysis, machine learning functions, and Python integration
- **High performance** - Designed for analyzing large volumes of data quickly

## Common Operators

- [Count](query/operators/count-operator.md) - Returns the number of rows in a table
- [Project](query/operators/project-operator.md) - Selects columns to include in the result
- [Where](query/operators/where-operator.md) - Filters data based on a condition
- [Sort](query/operators/sort-operator.md) - Orders the results by specified columns
- [Take](query/operators/take-operator.md) - Returns a specified number of rows
- [Summarize](query/operators/summarize-operator.md) - Aggregates data by groups
- [Join](query/operators/join-operator.md) - Combines rows from two tables
- [Union](query/operators/union-operator.md) - Combines results from multiple tables
- [Render](query/operators/render-operator.md) - Visualizes data as charts or graphs

## Common Functions

- [Ago](query/functions/ago-function.md) - Returns a datetime relative to the current time
- [Bin](query/functions/bin-function.md) - Rounds values down to multiples of a given size

## Getting Started

If you're new to KQL, we recommend starting with the following documents in order:

1. [KQL Overview](query/kql-overview.md)
2. [First Query](query/tutorials/first-query.md)
3. [KQL Quick Reference](query/kql-quick-reference.md)
4. [Gain Insights](query/tutorials/gain-insights.md)

## Additional Resources

- [Official Kusto Query Language Documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Azure Data Explorer Documentation](https://learn.microsoft.com/en-us/azure/data-explorer/)
- [KQL Samples on GitHub](https://github.com/microsoft/Kusto-Query-Language)
- [Azure Data Explorer Playground](https://dataexplorer.azure.com/clusters/help/databases/Samples)
