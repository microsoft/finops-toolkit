# 📦 Recommendations Automation Runbooks

This folder contains the several Azure Automation Runbooks responsible for generating the weekly optimization recommendations. All the `Recommend-*` runbooks follow the same pattern, generating one or more recommendation types, after a domain-specific Log Analytics query, and exporting it as a JSON blob to Azure Storage. 

The [Ingest-RecommendationsToLogAnalytics](./Ingest-RecommendationsToLogAnalytics.ps1) and [Ingest-RecommendationsToSQLServer](./Ingest-RecommendationsToSQLServer.ps1) runbooks are generic Azure Storage to Log Analytics/SQL Server ingestion scripts that take whatever exported JSON and ingests its data, respectively into the Log Analytics and SQL Database recommendations table.

The [Ingest-SuppressionsToLogAnalytics](./Ingest-SuppressionsToLogAnalytics.ps1) runbook brings the user-generated recommendation suppressions (see the [`Suppress-Recommendation` script](../Suppress-Recommendation.ps1)) from the SQL Database to a corresponding table in Log Analytics, so that the [Recommendations Workbook](../../views/workbooks/recommendations.json) is able to filter out suppressed recommendations.