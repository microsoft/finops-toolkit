# 📥 Azure Optimization Engine T-SQL initialization scripts

This folder contains T-SQL scripts that are executed by the AOE [deployment/upgrade script](../Deploy-AzureOptimizationEngine.ps1), in order to populate the AOE SQL Database with the required tables and procedures, as well as with initial data:

- [loganalyticsingestcontrol-table.sql](./loganalyticsingestcontrol-table.sql) creates/updates the `LogAnalyticsIngestControl` table, where the reference of the date/time/line of the latest ingested Storage blob (into Log Analytics), per Log Analytics table and respective Storage container.
- [loganalyticsingestcontrol-initialize.sql](./loganalyticsingestcontrol-initialize.sql) inserts the `LogAnalyticsIngestControl` table's initial records, with the default date/time/line for the latest ingested blob, per Log Analytics table and respective Storage container.
- [loganalyticsingestcontrol-upgrade.sql](./loganalyticsingestcontrol-upgrade.sql) updates the `LogAnalyticsIngestControl` table with default values for the corresponding Log Analytics table names of the Storage containers of the initial versions of AOE - needed only for upgrading old AOE versions.
- [sqlserveringestcontrol-table.sql](./sqlserveringestcontrol-table.sql) creates/updates the `SqlServerIngestControl` table, where the reference of the date/time/line of the latest ingested recommendation blob (all recommendation blobs are ingested into the same SQL Database `Recommendations` table).
- [sqlserveringestcontrol-initialize.sql](./sqlserveringestcontrol-initialize.sql) inserts the `SqlServerIngestControl` table's initial record, with the default date/time/line for the latest ingested recommendation blob.
- [recommendations-table.sql](./recommendations-table.sql) creates/updates the `Recommendations` table, where the AOE recommendations are stored every week. This table is used by the [Power BI report](../views/AzureOptimizationEngine.pbix).
- [recommendations-sp.sql](./recommendations-sp.sql) creates/updates the `GetRecommendations` stored procedure of the `Recommendations` table, which is used by the [Power BI report](../views/AzureOptimizationEngine.pbix) to load the latest AOE recommendations whenever it is refreshed.
- [filters-table.sql](./filters-table.sql) creates the `Filters` table, where users can store recommendation suppressions with the help of the [`Suppress-Recommendation` script](../Suppress-Recommendation.ps1).