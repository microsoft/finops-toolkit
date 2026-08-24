# AzureResourceManager engine app

Query engine for Azure Resource Manager. Implements the `queries_{engineName}_ExecuteQuery` contract for the IngestionQueries orchestrator.

## What it provides

- **`azureResourceManager` dataset** — ADF REST dataset for a query-provided Azure Resource Manager relative URL
- **`queries_AzureResourceManager_ExecuteQuery` pipeline** — Executes one ARM GET request via REST and writes results as Parquet to the ingestion container

## How it works

1. IngestionQueries dispatches to this pipeline through the existing ADF REST API flow.
2. The pipeline uses the query string as the ARM-relative URL.
3. The Copy activity issues a GET request and follows the response `nextLink`.
4. The Copy activity uses the provided `translator` and writes Parquet to the `ingestionPath`.

## Dependencies

- **Core app** — Provides the `azurerm` linked service and the `ingestion` dataset.
- **Data Factory managed identity** — Requires read access to each configured ARM endpoint.

## Limitations

- Only GET requests are supported.
- Query files cannot configure the HTTP method, headers, body, authority, or authentication resource.
