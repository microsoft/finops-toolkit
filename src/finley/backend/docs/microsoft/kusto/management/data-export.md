# Data Export Commands

This document covers the management commands for exporting data from Azure Data Explorer tables to external storage.

## Overview

Azure Data Explorer provides several mechanisms for exporting data:

1. **Direct export commands** - Used for ad-hoc data exports
2. **Continuous export** - Used for regular, ongoing data exports
3. **Export to external tables** - Used for creating queryable, external representations of data

## Direct Export Commands

### .export

Exports the results of a query to external storage.

#### Syntax

```kusto
.export [async] [compressed] to csv|tsv|json (h@"storageUri" [with (propertyName = propertyValue [, ...])]) <| query
```

#### Example

```kusto
.export to csv (
    h@"https://mystorageaccount.blob.core.windows.net/mycontainer/queryresults.csv"
      with (
        sas = "?sv=2018-03-28&ss=b&srt=sco&sp=rw&se=2022-12-31T00:00:00Z&st=2019-01-01T00:00:00Z&spr=https&sig=XXXXXXXXXXXXX",
        filesystem = "filesystem",
        namePrefix = "export",
        includeHeaders = "all"
      )
) <|
    Events
    | where Timestamp > ago(1d)
    | project Timestamp, Source, EventType, Message
```

### .export async

Executes an export operation asynchronously, returning a control token that can be used to track progress.

#### Syntax

```kusto
.export async to csv|tsv|json (h@"storageUri" [with (propertyName = propertyValue [, ...])]) <| query
```

#### Example

```kusto
.export async to csv (
    h@"https://mystorageaccount.blob.core.windows.net/mycontainer/queryresults.csv"
      with (
        sas = "?sv=2018-03-28&ss=b&srt=sco&sp=rw&se=2022-12-31T00:00:00Z&st=2019-01-01T00:00:00Z&spr=https&sig=XXXXXXXXXXXXX"
      )
) <|
    Events
    | where Timestamp > ago(30d)
    | summarize count() by bin(Timestamp, 1d), Source
```

## Continuous Export

### .create-or-alter continuous-export

Creates or alters a continuous export job that regularly exports data to external storage.

#### Syntax

```kusto
.create-or-alter continuous-export ContinuousExportName
to table ExternalTableName
[with (propertyName = propertyValue [, ...])]
<| query
```

#### Example

```kusto
// First, create an external table
.create external table ExternalEvents (Timestamp:datetime, Source:string, EventType:string, Message:string)
   kind=adl
   partition by bin(Timestamp, 1d)
   pathformat = ('events/year={datetime_part("year", Timestamp)}/month={datetime_part("month", Timestamp):d2}/day={datetime_part("day", Timestamp):d2}/data_{guid()}.parquet')
   dataformat = parquet
   (
      h@'https://mystorageaccount.dfs.core.windows.net/mycontainer/;secretKey'
   )

// Then, create a continuous export
.create-or-alter continuous-export EventsExport
to table ExternalEvents
with (intervalBetweenRuns=1h)
<|
    Events
    | where Timestamp > ago(7d)
```

### .show continuous-export

Shows details of existing continuous export jobs.

#### Syntax

```kusto
.show continuous-export [ContinuousExportName]
```

#### Example

```kusto
.show continuous-export EventsExport
```

### .drop continuous-export

Deletes a continuous export job.

#### Syntax

```kusto
.drop continuous-export ContinuousExportName
```

#### Example

```kusto
.drop continuous-export EventsExport
```

## Export to External Tables

### .create external table

Creates an external table that can be used for exporting data.

#### Syntax

```kusto
.create external table ExternalTableName (ColName:ColType [, ...])
kind=blob|adl
[partition by (PartitionColumn [, ...])]
[pathformat = 'PathFormat']
dataformat = csv|tsv|json|parquet|orc
(
   h@'storageUri' [with (propertyName = propertyValue [, ...])]
)
```

#### Example

```kusto
.create external table ExternalLogs (Timestamp:datetime, Level:string, Message:string, ProcessId:int)
   kind=adl
   partition by bin(Timestamp, 1d)
   pathformat = ('logs/year={datetime_part("year", Timestamp)}/month={datetime_part("month", Timestamp):d2}/day={datetime_part("day", Timestamp):d2}/data_{guid()}.parquet')
   dataformat = parquet
   (
      h@'https://mystorageaccount.dfs.core.windows.net/mycontainer/;secretKey'
   )
```

### Write to external table

Write query results to an external table using the `write` operator.

#### Syntax

```kusto
query | write [append] [with(propertyName = propertyValue [, ...])] ExternalTableName
```

#### Example

```kusto
Events
| where Timestamp > ago(1d)
| where Level == "Error"
| project Timestamp, Level, Message, ProcessId
| write ExternalLogs
```

## Export Formats

Azure Data Explorer supports multiple data formats for exporting:

| Format | Description | Example |
|--------|-------------|---------|
| `csv` | Comma-separated values | `dataformat = csv` |
| `tsv` | Tab-separated values | `dataformat = tsv` |
| `json` | JSON records | `dataformat = json` |
| `parquet` | Parquet format (columnar storage) | `dataformat = parquet` |
| `orc` | ORC format (columnar storage) | `dataformat = orc` |

## Export Properties

The following properties can be specified with the `with` clause in export commands:

| Property | Description | Example |
|----------|-------------|---------|
| `sas` | Shared Access Signature for Azure Storage | `with (sas = "?sv=2018-03-28&ss=b&srt=...")` |
| `filesystem` | The filesystem for ADLSv2 | `with (filesystem = "myfs")` |
| `namePrefix` | Prefix for the exported file names | `with (namePrefix = "export")` |
| `includeHeaders` | Whether to include column headers | `with (includeHeaders = "all")` |
| `encoding` | Text encoding for export | `with (encoding = "UTF8")` |
| `compressed` | Whether to compress the output | `with (compressed = true)` |

## Monitoring Exports

### .show export

Shows the status and details of an export operation.

#### Syntax

```kusto
.show export OperationId
```

#### Example

```kusto
.show export 3c9a315f-1d33-43ef-a3a1-54f2e2049161
```

## Best Practices

1. **Use appropriate formats**: 
   - CSV/TSV for simple data that needs to be human-readable
   - Parquet for large datasets and analytical workloads
   - JSON for hierarchical data

2. **Partitioning**: 
   - Partition exported data by time or other high-cardinality columns
   - Choose partition granularity appropriate for your data volume
   - Use `bin()` function for time-based partitioning

3. **Performance considerations**:
   - For large exports, use asynchronous operations
   - Pre-filter data when possible to reduce export size
   - For regular exports, use continuous export

4. **Monitoring and maintenance**:
   - Regularly check continuous export operations
   - Set up alerting for failed exports
   - Clean up temporary exports to avoid storage costs

For more information on data export commands, refer to the [Azure Data Explorer documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/data-export).
