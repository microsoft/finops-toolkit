# AzureResourceManager engine app

Query engine for Azure Resource Manager. Implements the `queries_{engineName}_ExecuteQuery` contract for the IngestionQueries orchestrator.

## What it provides

- **`azureResourceManager` dataset** — ADF REST dataset for a query-provided Azure Resource Manager relative URL
- **`queries_AzureResourceManager_ExecuteQuery` pipeline** — Entry point that implements the engine contract
- **Four scope-expansion pipelines** — `ExecuteConfiguredScopes`, `ExecuteTenant`, `ExecuteSubscription`, and `ExecuteRegional`
- **`queries_AzureResourceManager_CopyQuery` pipeline** — Performs the authenticated request and writes Parquet to the ingestion container

## How it works

1. IngestionQueries dispatches to `ExecuteQuery` through the engine contract.
2. `ExecuteQuery` validates the scope as an Azure resource ID, including hexadecimal subscription GUIDs, and validates the query as an ARM-relative path.
3. Scope expansion runs across the four expansion pipelines, chained by `ExecutePipeline`. Each level expands one dimension: configured billing scopes, tenant, subscription, then region. Configured billing scopes are filtered against each query's `scopeTypes`.
4. The chain exists because ADF containers cannot nest. A `ForEach` cannot contain another `ForEach`, so each additional dimension requires its own pipeline.
5. The innermost level invokes `CopyQuery` once per fully-resolved scope.
6. `CopyQuery` first sends the query as an authenticated GET from a `Web` activity. An `If` condition then runs the Copy activity only when that response contains at least one item. An empty result set therefore never produces a file. This is the same check the AzureResourceGraph app performs before its Copy activity.
7. A single Copy activity performs the request and writes Parquet. Multi-page responses are followed by the REST source's native `paginationRules` on `$.nextLink`. There is no manual paging loop.

## Design constraints

These constraints are binding. Read them before changing this app.

- **Use the existing art exclusively.** Every pipeline pattern here must already exist in a sibling app, in `IngestionQueries`, or in `Microsoft.CostManagement`. Do not introduce a pattern that has no precedent in this repository, and do not adapt a pattern beyond what the precedent already does.
- The empty-result check is the AzureResourceGraph pattern: a `Web` activity, then an `If` condition, then the Copy activity. Do not replace it with a write-then-delete guard, a row count, a fault-tolerance setting, or a `Fail` activity.
- Concurrency multiplies across the expansion chain. The `batchCount` on each `ForEach` and the `concurrency` on `CopyQuery` are set to the same value for that reason. Change them together or not at all.
- The authority comes from `environment().resourceManager` in every request URL. Do not accept an authority from a query file.

## Dependencies

- **Core app** — Provides the `azurerm` linked service and the `ingestion` dataset.
- **Data Factory managed identity** — Requires read access to each configured ARM endpoint.

## Limitations

- Only GET requests are supported.
- Query files cannot configure the HTTP method, headers, body, authority, or authentication resource.
- The empty-result check reads the `value` array on the response. A provider that returns its results under a different property is not supported.
- A provider that fails rather than returning an empty array, such as the Network provider returning `SubscriptionHasNoUsages`, fails the pipeline. The check does not suppress errors.
