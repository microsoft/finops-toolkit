# What is Azure Data Explorer?

Azure Data Explorer is a fast, fully managed data analytics service for real-time analysis on large volumes of data streaming from applications, websites, IoT devices, and more. You can use Azure Data Explorer to collect, store, and analyze diverse data to improve products, enhance customer experiences, monitor devices, and boost operations.

## Azure Data Explorer Flow

### Query Database

Azure Data Explorer uses the Kusto Query Language (KQL), which is an expressive, intuitive, and highly productive query language. It offers a smooth transition from simple one-liners to complex data processing scripts, and supports querying structured, semi-structured, and unstructured (text search) data. 

There's a wide variety of query language operators and functions in the language:
- Aggregation functions
- Filtering
- Time series functions
- Geospatial functions
- Joins
- Unions
- And more

KQL supports cross-cluster and cross-database queries, and is feature rich from a parsing (json, XML, and more) perspective. The language also natively supports advanced analytics.

Use the web application to run, review, and share queries and results. You can also send queries programmatically (using an SDK) or to a REST API endpoint. If you're familiar with SQL, get started with the SQL to Kusto cheat sheet.

## What Makes Azure Data Explorer Unique?

### Data Velocity, Variety, and Volume

With Azure Data Explorer, you can ingest terabytes of data in minutes via queued ingestion or streaming ingestion. You can query petabytes of data, with results returned within milliseconds to seconds. Azure Data Explorer provides high velocity (millions of events per second), low latency (seconds), and linear scale ingestion of raw data. Ingest your data in different formats and structures, flowing from various pipelines and sources.

### User-friendly Query Language

Query Azure Data Explorer with the Kusto Query Language (KQL), an open-source language initially invented by the team. The language is simple to understand and learn, and highly productive. You can use simple operators and advanced analytics. Azure Data Explorer also supports T-SQL.

### Advanced Analytics

Use Azure Data Explorer for time series analysis with a large set of functions including:
- Adding and subtracting time series
- Filtering
- Regression
- Seasonality detection
- Geospatial analysis
- Anomaly detection
- Scanning and forecasting

Time series functions are optimized for processing thousands of time series in seconds. Pattern detection is made easy with cluster plugins that can diagnose anomalies and do root cause analysis. You can also extend Azure Data Explorer capabilities by embedding python code in KQL queries.

### Easy-to-use Wizard

The get data experience makes the data ingestion process easy, fast, and intuitive. The Azure Data Explorer web UI provides an intuitive and guided experience that helps you ramp-up quickly to start ingesting data, creating database tables, and mapping structures. It enables one time or a continuous ingestion from various sources and in various data formats. Table mappings and schema are auto suggested and easy to modify.

## Distributed Data Query

Azure Data Explorer uses distributed data query technology intended for fast ad hoc analytics on large unstructured data sets. Key features of this technology include:

1. Query-generated temporary data is stored in aggregated RAM
2. Relevant extents are marked on a query plan, providing snapshot isolation
3. Fast and efficient queries are prioritized with short default timeouts
4. Native support for cross-cluster queries that minimizes inter-cluster data exchange
5. Queries are just-in-time compiled into highly efficient machine code, using data statistics from all extents and tailored to column encoding specifics

> **Note**: Azure Data Explorer is designed to work with the Kusto Query Language (KQL), custom-built for Azure Data Explorer. Additionally, T-SQL is supported.
