# Query Data in a KQL Queryset

The KQL queryset is the item used to run queries, view, and customize query results on data from different data sources, such as Eventhouse, KQL database, and more.

You can also use a KQL queryset to perform cross-service queries with data from an Azure Monitor Log Analytics workspace or from an Application Insights resource.

The KQL Queryset uses the Kusto Query Language for creating queries, and also supports many SQL functions.

## Prerequisites

1. A workspace with a Microsoft Fabric-enabled capacity
2. A KQL database with editing permissions and data, or an Azure Data Explorer cluster and database with AllDatabaseAdmin permissions.

## Sample Gallery

A query is a read-only request to process data and return results. The request is stated in plain text, using a data-flow model that is easy to read, author, and automate. Queries always run in the context of a particular table or database. At a minimum, a query consists of a source data reference and one or more query operators applied in sequence, indicated visually by the use of a pipe character (|) to delimit operators.

### Running Queries

In the query editor window, place your cursor anywhere on the query text and select the **Run** button, or press **Shift** + **Enter** to run a query. Results are displayed in the query results pane, directly below the query editor window.

Before running any query or command, take a moment to read the comments above it. The comments include important information.

> **Tip**: Select **Recall** at the top of the query window to show the result set from the first query without having to rerun the query. Often during analysis, you run multiple queries, and **Recall** allows you to retrieve the results of previous queries.

## Example Queries

To get started with example KQL queries:

1. In the **Explorer** pane, select the **More menu** [...] on a desired table > **Query table**. Example queries run in the context of a selected table.

2. Select a single query to populate the **Explore your data** window. The query will automatically run and display results.

## Clean Up Resources

Clean up the items created by navigating to the workspace in which they were created.

1. In your workspace, hover over the KQL Database or KQL Queryset you want to delete, select the **More menu** [...] > **Delete**.

2. Select **Delete**. You can't recover deleted items.
