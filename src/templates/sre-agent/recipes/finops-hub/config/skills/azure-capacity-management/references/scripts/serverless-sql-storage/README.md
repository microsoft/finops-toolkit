---
title: Serverless SQL storage audit
---

# Serverless SQL storage audit

Azure SQL Database [serverless compute tier](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview) [bills on allocated storage, not max size](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview#billing). Allocated space grows with writes and doesn't auto-shrink—even after deletes. This workbook surfaces the gap between allocated and used storage across all serverless SQL databases in the tenant so you can target `DBCC SHRINKDATABASE` operations where they'll save money.

## What it measures

| Metric | Source | Description |
|--------|--------|-------------|
| Max size (GB) | [Azure Resource Graph](https://learn.microsoft.com/en-us/azure/governance/resource-graph/overview) | Configured ceiling (`properties.maxSizeBytes`). Doesn't affect billing directly. |
| Allocated | [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-sql/database/monitoring-sql-database-azure-monitor) `allocated_data_storage` | What you [pay for](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview#billing). Grows with writes, never auto-shrinks. |
| Used | [Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-sql/database/monitoring-sql-database-azure-monitor) `storage` | Actual data on disk. |

**Waste** = Allocated minus Used. That's the reclamation target. Compare the two columns in the workbook to identify databases worth shrinking.

## How it works

The workbook uses the [merge data source](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-data-sources#merge) pattern to join two queries:

1. **Resource Graph** finds all `GP_S_Gen*` databases across every subscription selected in the subscription picker
2. **Azure Monitor metrics** (hidden step) pulls `allocated_data_storage` and `storage` for each discovered database
3. **Merge** left outer joins on resource ID and renders a single sortable table

The subscription picker scopes the Resource Graph query via `crossComponentResources`. The merge's left outer join ensures databases appear even when metrics haven't populated yet.

## Deploy

### ARM template

```bash
az deployment group create \
  -g <resource-group> \
  --template-file workbook.json
```

The workbook deploys as a `Microsoft.Insights/workbooks` resource. It doesn't require a Log Analytics workspace—Resource Graph and Azure Monitor metrics are the only data sources.

### Find the workbook after deployment

Go to **Azure Monitor** > **Workbooks** > select the resource group you deployed to. The workbook appears as **Serverless SQL Storage - FinOps Audit**.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `workbookDisplayName` | Serverless SQL Storage - FinOps Audit | Display name in the Azure portal |
| `workbookSourceId` | azure monitor | Source binding for the workbook |

### Workbook controls

| Control | Options | Description |
|---------|---------|-------------|
| Subscriptions | Multi-select picker | Scopes the Resource Graph query to selected subscriptions |
| Time range | 1h, 4h, 12h, 1d, 3d, 7d, 30d, 90d | Adjusts the metrics query window. Use 30d or 90d for trend analysis. |

## Prerequisites

- The deploying identity needs **Reader** on every subscription the workbook should scan (Resource Graph respects RBAC)
- Azure Monitor metrics are available without additional configuration for SQL databases
- No agents, extensions, or diagnostic settings required

## Reclaiming allocated storage

After identifying databases with high waste, connect to each database and run:

```sql
DBCC SHRINKDATABASE (N'<database-name>', 10);
```

The `10` specifies the target free space percentage after shrink. [DBCC SHRINKDATABASE reference](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkdatabase-transact-sql).

For file-level control:

```sql
DBCC SHRINKFILE (N'<logical-file-name>', <target-size-mb>);
```

[DBCC SHRINKFILE reference](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkfile-transact-sql).

**Caveat:** Shrinking causes [index fragmentation](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/reorganize-and-rebuild-indexes). Rebuild indexes after shrinking production databases to avoid query performance degradation.

## Limitations

- **500 database cap**: The metrics step processes up to 500 databases. If you have more, use the subscription picker to filter to a smaller set.
- **No computed waste column**: Workbook merge steps don't support cross-column arithmetic. The workbook shows Allocated and Used side by side—compare visually, or use the companion CLI script for computed waste and utilization percentages.
- Resource Graph indexing can lag up to 5 minutes after a database is created or deleted.
- Metrics aren't available for databases created within the last few minutes.
- The merge step joins on resource ID; if a database is deleted between the Resource Graph query and the metrics query, that row shows null for Allocated and Used.
- Max size reduction doesn't reclaim allocated storage—only `DBCC SHRINKDATABASE` or `DBCC SHRINKFILE` does.
