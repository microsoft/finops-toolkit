# Kusto Management Commands

Kusto management commands are used to manage Azure Data Explorer resources such as databases, tables, policies, and security. They are executed using the `.` prefix, unlike KQL queries.

## Overview

Management commands in Kusto are used for:

- Creating, altering, and dropping schema objects (databases, tables, functions)
- Managing data (ingestion, export)
- Setting and viewing policies (retention, caching, security)
- Monitoring and diagnosing

## Command Categories

### Database Management

| Command | Description |
|---------|-------------|
| `.create database` | Creates a new database |
| `.drop database` | Drops an existing database |
| `.show databases` | Lists all databases in the cluster |
| `.alter database` | Modifies database properties |

### Table Management

| Command | Description |
|---------|-------------|
| `.create table` | Creates a new table |
| `.create-merge table` | Creates a table if it doesn't exist or merges with existing definition |
| `.drop table` | Drops an existing table |
| `.alter table` | Modifies table schema |
| `.rename table` | Renames a table |
| `.show tables` | Lists all tables in a database |

### Column Management

| Command | Description |
|---------|-------------|
| `.alter column` | Changes a column's type or name |
| `.drop column` | Removes a column from a table |
| `.alter-merge table` | Adds columns to an existing table |

### Data Management

| Command | Description |
|---------|-------------|
| `.ingest` | Ingests data into a table |
| `.set-or-append` | Appends data to a table, or creates and sets data if table doesn't exist |
| `.set-or-replace` | Replaces data in a table, or creates and sets data if table doesn't exist |
| `.move extents` | Moves extents between tables |
| `.drop extents` | Removes extents from a table |

### Policy Management

| Command | Description |
|---------|-------------|
| `.alter retention policy` | Modifies data retention policy |
| `.alter cache policy` | Modifies hot cache policy |
| `.alter merge policy` | Modifies data merging policy |
| `.show policy` | Shows current policies |

### Security Management

| Command | Description |
|---------|-------------|
| `.add database role` | Adds a security role to a database |
| `.drop database role` | Removes a security role from a database |
| `.add table role` | Adds a security role to a table |
| `.show principal roles` | Shows role assignments for a principal |

## Syntax

Management commands have the following syntax:

```
.<command> [entity_type] [entity_name] [additional parameters]
```

Where:
- `<command>` is the action to perform (create, drop, alter, etc.)
- `entity_type` is the type of object to operate on (database, table, function, etc.)
- `entity_name` is the name of the specific entity
- `additional parameters` vary by command

## Examples

### Creating a Table

```kusto
.create table MyTable (Level:string, Timestamp:datetime, UserId:string, Message:string, ProcessId:int32)
```

### Setting Data Retention Policy

```kusto
.alter table MyTable policy retention softdelete = 365d
```

### Managing Security

```kusto
.add database admin ('aaduser=user@contoso.com')
```

## Important Notes

1. Management commands require appropriate permissions
2. Many commands support an idempotent `-merge` variant
3. Command syntax differs from query syntax (starts with `.` and doesn't use pipes)
4. Commands are typically scoped to the current database context

For full documentation and examples of each command, refer to the specific command documentation files.
