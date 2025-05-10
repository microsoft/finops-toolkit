# Data Ingestion Commands

This document covers the management commands for ingesting data into Azure Data Explorer tables.

## Overview

Azure Data Explorer supports several methods for ingesting data into tables:

1. **Direct ingestion commands** - Used for small data sets and for development/testing
2. **Queued ingestion** - Used for production, high-scale ingestion
3. **Streaming ingestion** - Used for near real-time data processing

## Direct Ingestion Commands

### .ingest inline

Ingests data that is specified inline in the command.

#### Syntax

```kusto
.ingest inline into table TableName [with (PropertyName = PropertyValue [, ...])] <| data
```

#### Example

```kusto
.ingest inline into table Users <|
UserId,Name,Email
1,"John Smith","john@example.com"
2,"Jane Doe","jane@example.com"
```

### .ingest into

Ingests data from a file or blob into a table.

#### Syntax

```kusto
.ingest into table TableName [with (PropertyName = PropertyValue [, ...])] 'URI'
```

#### Example

```kusto
.ingest into table Events 'https://mystorageaccount.blob.core.windows.net/mycontainer/myfile.csv' 
    with (format='csv')
```

## Data Replacement Commands

### .set-or-replace

Replaces all data in a table with new data, or creates the table if it doesn't exist.

#### Syntax

```kusto
.set-or-replace TableName <| data
```

or 

```kusto
.set-or-replace TableName 'URI' [with (PropertyName = PropertyValue [, ...])]
```

#### Example

```kusto
.set-or-replace DailyMetrics <|
Date,Metric,Value
2023-01-01,"Users",1250
2023-01-01,"Sessions",1820
```

### .set-or-append

Appends data to a table, or creates the table and adds the data if the table doesn't exist.

#### Syntax

```kusto
.set-or-append TableName <| data
```

or 

```kusto
.set-or-append TableName 'URI' [with (PropertyName = PropertyValue [, ...])]
```

#### Example

```kusto
.set-or-append WeeklyMetrics <|
Week,Metric,Value
"2023-W01","Users",8250
"2023-W01","Sessions",12820
```

## Ingestion Properties

The following properties can be specified with the `with` clause in ingestion commands:

| Property | Description | Example |
|----------|-------------|---------|
| `format` | The format of the data | `with (format='csv')` |
| `ignoreFirstRecord` | Whether to ignore the first record (header) | `with (ignoreFirstRecord=true)` |
| `ingestionMapping` | Mapping of source data to table columns | `with (ingestionMapping='[{"column":"UserId","datatype":"int","properties":{"path":"$.id"}}]')` |
| `creationTime` | Override the ingestion time | `with (creationTime='2023-01-01')` |
| `extend_schema` | Automatically add missing columns | `with (extend_schema=true)` |
| `ingestIfNotExists` | Ingest only if no data with the same tag exists | `with (ingestIfNotExists='tag1')` |

## Data Formats

Azure Data Explorer supports multiple data formats for ingestion:

| Format | Description | Example |
|--------|-------------|---------|
| `csv` | Comma-separated values | `with (format='csv')` |
| `tsv` | Tab-separated values | `with (format='tsv')` |
| `json` | JSON records | `with (format='json')` |
| `avro` | Avro format | `with (format='avro')` |
| `parquet` | Parquet format | `with (format='parquet')` |
| `orc` | ORC format | `with (format='orc')` |
| `w3clogfile` | W3C log format | `with (format='w3clogfile')` |

## Queued Ingestion

For production workloads, queued ingestion is preferred over direct ingestion commands. This is managed through client SDKs or data connection resources in Azure Data Explorer.

### Using Queued Ingestion with SDK

Example using .NET SDK:

```csharp
// Create Kusto connection string with App Authentication
var kustoConnectionStringBuilder = new KustoConnectionStringBuilder(ingestUri)
{
    FederatedSecurity = true,
    ApplicationClientId = appId,
    ApplicationKey = appKey,
    Authority = tenantId
};

// Create ingestion client
IKustoIngestClient ingestClient = KustoIngestFactory.CreateQueuedIngestClient(kustoConnectionStringBuilder);

// Prepare ingestion properties
var ingestionProperties = new KustoIngestionProperties(databaseName, tableName);
ingestionProperties.Format = DataSourceFormat.csv;
ingestionProperties.IngestionMapping = new IngestionMapping();
ingestionProperties.IngestionMapping.IngestionMappingReference = csvMappingName;

// Ingest from file
using (var fileStream = new FileStream(filePath, FileMode.Open))
{
    var sourceOptions = new StorageSourceOptions()
    {
        SourceId = Guid.NewGuid()
    };
    
    ingestClient.IngestFromStorageAsync(fileStream, ingestionProperties, sourceOptions).Wait();
}
```

## Streaming Ingestion

Streaming ingestion is designed for near real-time scenarios where low latency is critical.

### Enabling Streaming Ingestion

```kusto
.alter database YourDatabaseName policy streamingingestion enable
```

### Using Streaming Ingestion with SDK

Example using .NET SDK:

```csharp
// Create Kusto connection string with App Authentication
var kustoConnectionStringBuilder = new KustoConnectionStringBuilder(engineUri)
{
    FederatedSecurity = true,
    ApplicationClientId = appId,
    ApplicationKey = appKey,
    Authority = tenantId
};

// Create streaming ingestion client
IKustoIngestClient streamingIngestClient = KustoIngestFactory.CreateStreamingIngestClient(kustoConnectionStringBuilder);

// Prepare ingestion properties
var ingestionProperties = new KustoIngestionProperties(databaseName, tableName);
ingestionProperties.Format = DataSourceFormat.json;

// Ingest from stream
using (var memoryStream = new MemoryStream(Encoding.UTF8.GetBytes(jsonData)))
{
    streamingIngestClient.IngestFromStreamAsync(memoryStream, ingestionProperties).Wait();
}
```

## Best Practices

1. Use direct ingestion commands only for development/testing or very small datasets
2. Prefer queued ingestion for production workloads
3. Use streaming ingestion for scenarios requiring near real-time data visibility
4. Set appropriate data formats and mappings for your data sources
5. Monitor ingestion failures using the `.show ingestion failures` command
6. Consider batching small ingestions together for better performance

For more information on data ingestion commands, refer to the [Azure Data Explorer documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/data-ingestion).
