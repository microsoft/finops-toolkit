# AzureResourceGraph engine app

Query engine for Azure Resource Graph (ARG). Implements the `queries_{engineName}_ExecuteQuery` contract for the IngestionQueries orchestrator.

## What it provides

- **`azureResourceGraph` dataset** — ADF REST dataset pointing to the ARG API (`/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01`)
- **`queries_ResourceGraph_ExecuteQuery` pipeline** — Executes an ARG query, paging through all results, and writes each page as Parquet to the ingestion container

## How it works

1. IngestionQueries dispatches to this pipeline via the ADF REST API
2. The pipeline loops, POSTing the query to the ARG endpoint on each iteration, appending source metadata columns (`x_SourceName`, `x_SourceType`, `x_SourceProvider`, `x_SourceVersion`) directly in the query text. A Web activity runs the query first to check for results and read the `$skipToken` continuation token; when there are results, a Copy activity re-runs the same page and uses the provided `translator` to map columns and write it as Parquet to `ingestionPath` (with a `_{page number}` suffix so each page gets its own file)
3. The loop continues until ARG stops returning a `$skipToken`, since a single ARG response is capped at 1,000 rows

## Dependencies

- **Core app** — provides the `azurerm` linked service (REST service with MSI auth to ARM) and the `ingestion` dataset
- **Data Factory managed identity** — must have **Reader** role on the tenant root management group (or individual subscriptions/management groups) to execute ARG queries across the tenant

## Limitations

- ARG query text has a 10 KB limit.
- Each page is fetched twice (once to read `$skipToken`, once via Copy to write it), since the ADF REST connector's `paginationRules` can't inject a continuation token into a POST body. This doubles ARG API calls for queries with multiple pages.
