# Table Management Commands

This document covers management commands for creating and managing tables in Azure Data Explorer.

## Creating Tables

### .create table

Creates a new table with the specified schema.

#### Syntax

```kusto
.create table TableName (ColumnName:ColumnType [, ...])
```

#### Example

```kusto
.create table Events (
    Timestamp: datetime,
    EventId: guid,
    EventType: string,
    UserId: string,
    Properties: dynamic
)
```

### .create-merge table

Creates a table if it doesn't exist, or merges the schema with an existing table.

#### Syntax

```kusto
.create-merge table TableName (ColumnName:ColumnType [, ...])
```

#### Example

```kusto
.create-merge table Events (
    Timestamp: datetime,
    EventId: guid,
    EventType: string,
    UserId: string,
    Properties: dynamic,
    Duration: timespan  // New column to add or merge
)
```

## Altering Tables

### .alter table

Modifies an existing table's schema.

#### Syntax

```kusto
.alter table TableName (ColumnName:ColumnType [, ...])
```

#### Example

```kusto
.alter table Events (
    Timestamp: datetime,
    EventId: guid,
    EventType: string,
    UserId: string,
    Properties: dynamic,
    Duration: timespan,
    Region: string  // Added new column
)
```

### .alter-merge table

Adds columns to an existing table without affecting existing columns.

#### Syntax

```kusto
.alter-merge table TableName (ColumnName:ColumnType [, ...])
```

#### Example

```kusto
.alter-merge table Events (
    Category: string,  // New column
    SubEventType: string  // New column
)
```

## Dropping Tables

### .drop table

Removes a table and all its data.

#### Syntax

```kusto
.drop table TableName
```

#### Example

```kusto
.drop table OutdatedEvents
```

### .drop tables

Drops multiple tables that match a wildcard pattern.

#### Syntax

```kusto
.drop tables (TableName1, TableName2)
```

or

```kusto
.drop tables TablePattern
```

#### Example

```kusto
.drop tables (Events_2020, Events_2021)
```

## Renaming Tables

### .rename table

Renames an existing table.

#### Syntax

```kusto
.rename table OldTableName to NewTableName
```

#### Example

```kusto
.rename table Events to EventsArchive
```

## Viewing Table Information

### .show table

Shows information about a specific table.

#### Syntax

```kusto
.show table TableName
```

#### Example

```kusto
.show table Events
```

### .show tables

Lists all tables in the database, or tables matching a pattern.

#### Syntax

```kusto
.show tables
```

or

```kusto
.show tables (TableName1, TableName2)
```

or

```kusto
.show tables TablePattern
```

#### Example

```kusto
.show tables
```

```kusto
.show tables Event*
```

### .show table schema

Shows the schema of a table.

#### Syntax

```kusto
.show table TableName schema
```

#### Example

```kusto
.show table Events schema
```

## Folder and DocString Properties

### .alter table folder

Sets the folder property of a table, used for organizing tables.

#### Syntax

```kusto
.alter table TableName folder "FolderPath"
```

#### Example

```kusto
.alter table Events folder "Telemetry/ApplicationEvents"
```

### .alter table docstring

Sets the documentation string for a table.

#### Syntax

```kusto
.alter table TableName docstring "Documentation"
```

#### Example

```kusto
.alter table Events docstring "Contains application event telemetry data"
```

## Policy Management

### .alter table retention policy

Sets the data retention policy for a table.

#### Syntax

```kusto
.alter table TableName policy retention softdelete = TimeSpan
```

#### Example

```kusto
.alter table Events policy retention softdelete = 90d
```

### .alter table cache policy

Sets the hot cache policy for a table.

#### Syntax

```kusto
.alter table TableName policy caching hot = TimeSpan
```

#### Example

```kusto
.alter table Events policy caching hot = 7d
```

## Sharding Policy

### .alter table sharding policy

Configures the sharding policy for a table.

#### Syntax

```kusto
.alter table TableName policy sharding "ShardingPolicy"
```

#### Example

```kusto
.alter table Events policy sharding "MaxRowCount=750000;MaxExtentSizeInMb=1024;MaxOriginalSizeInMb=2048"
```

## Best Practices

1. Use `-merge` variants when possible to make commands idempotent
2. Set appropriate retention and caching policies based on data usage patterns
3. Use folders to organize tables logically
4. Add descriptive docstrings to document table purpose and structure
5. Monitor table sizes and shard accordingly for optimal performance

For more information on table management commands, refer to the [Azure Data Explorer documentation](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/management/tables-commands).
