# Integrations Overview for Kusto Query Language

KQL (Kusto Query Language) can be integrated with various tools and services. This document outlines the main integrations available.

## Query Connectors

| Name | Functionality | Roles | Use cases |
| --- | --- | --- | --- |
| Apache Spark | Query, Ingest, and Export | Data Analyst, Data Scientist | Machine learning (ML), Extract-Transform-Load (ETL), and Log Analytics scenarios using any Spark cluster |
| Apache Spark for Azure Synapse Analytics | Query, Ingest, and Export | Data Analyst, Data Scientist | Machine learning (ML), Extract-Transform-Load (ETL), and Log Analytics scenarios using Synapse Analytics Spark cluster |
| Azure Functions | Query, Ingest, and Orchestrate | Data Engineer, Application Developer | Integrate Azure Data Explorer into your serverless workflows to ingest data and run queries against your cluster |
| JDBC | Query | Application Developer | Use JDBC to connect to Azure Data Explorer databases and execute queries |
| Logic Apps | Query and Orchestrate | Low Code Application Developer | Run queries and commands automatically as part of a scheduled or triggered task |
| Matlab | Query | Data Analyst, Data Scientist | Analyse data, develop algorithms and create models |
| ODBC | Query | Application Developer | Establish a connection to Azure Data Explorer from any application that is equipped with support for the ODBC driver for SQL Server |
| Power Apps | Query and Orchestrate | Low Code Application Developer | Build a low code, highly functional app to make use of data stored in Azure Data Explorer |
| Power Automate | Query and Orchestrate | Low Code Application Developer | Orchestrate and schedule flows, send notifications, and alerts, as part of a scheduled or triggered task |

## Development Tools

### Kusto Query Language Plugin
Access the Kusto Query Language editor plugin.

### Embedding the Azure Data Explorer Web UI
The Azure Data Explorer web UI can be embedded in an iframe and hosted in third-party websites.

### PowerShell
PowerShell scripts can use the Kusto client libraries, as PowerShell inherently integrates with .NET libraries.

- **Functionality:** Query
- **Documentation:** Use Kusto .NET client libraries from PowerShell

### Real-Time Intelligence in Microsoft Fabric
Real-Time Intelligence is a fully managed big data analytics platform optimized for streaming, and time-series data.

- **Functionality:** Ingestion, Export, Query, Visualization
- **Ingestion type supported:** Streaming, Batching
- **Documentation:** What is Real-Time Intelligence in Fabric?

### SyncKusto
Sync Kusto is a tool that enables users to synchronize various Kusto schema entities, such as table schemas and stored functions. This synchronization is done between the local file system, an Azure Data Explorer database, and Azure repos.

- **Functionality:** Source control
- **Repository:** SyncKusto
- **Documentation:** Sync Kusto

### Web UI
Azure Data Explorer provides a web experience that enables you to connect to your Azure Data Explorer clusters and write, run, and share Kusto Query Language (KQL) commands and queries.

- **Functionality:** Ingestion, Export, Query, Visualization
- **Ingestion type supported:** Batching, Streaming
- **Documentation:** Azure Data Explorer web UI, Get data from file
