# AzureResourceManager engine app

Query engine for Azure Resource Manager. Implements the `queries_{engineName}_ExecuteQuery` contract for the IngestionQueries orchestrator.

## What it provides

- **`azureResourceManager` dataset** — ADF REST dataset for a query-provided Azure Resource Manager relative URL
- **`queries_AzureResourceManager_ExecuteQuery` pipeline** — Executes validated ARM GET requests and writes results as Parquet to the ingestion container

## How it works

1. IngestionQueries dispatches to this pipeline through the existing ADF REST API flow.
2. The pipeline validates the scope as an Azure resource ID, including hexadecimal subscription GUIDs, and the query as an ARM-relative path.
3. Configured billing scopes are filtered against each query's `scopeTypes`.
4. Before each authenticated GET, the pipeline requires the request URL to be ARM-relative or to start with the current cloud's exact Azure Resource Manager authority.
5. Exactly one authenticated REST Copy streams each validated response into a raw JSON file.
6. Two storage Copies read that same JSON file: one writes the `value` rows using the query translator, while the other maps only the root `nextLink` into a tiny Parquet metadata file.
7. A Lookup reads only that metadata file. An absent or null `nextLink` ends the loop.
8. Raw and metadata files use a run-unique `_ftk-arm-pagination/{runId}` folder outside query staging, which is deleted after paging succeeds.
9. The data Copy activity uses the provided translator and source metadata when writing Parquet to the `ingestionPath`.

## Dependencies

- **Core app** — Provides the `azurerm` linked service and the `ingestion` dataset.
- **Data Factory managed identity** — Requires read access to each configured ARM endpoint.

## Limitations

- Only GET requests are supported.
- Query files cannot configure the HTTP method, headers, body, authority, or authentication resource.
