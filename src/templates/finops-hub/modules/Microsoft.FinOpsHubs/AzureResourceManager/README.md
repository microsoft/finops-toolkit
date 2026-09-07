# AzureResourceManager engine app

Query engine for Azure Resource Manager. Implements the `queries_{engineName}_ExecuteQuery` contract for the IngestionQueries orchestrator.

## What it provides

- **`azureResourceManager` dataset** — ADF REST dataset for a query-provided Azure Resource Manager relative URL
- **`queries_AzureResourceManager_ExecuteQuery` pipeline** — Entry point that implements the engine contract
- **Three scope-expansion pipelines** — `ExecuteConfiguredScopes`, `ExecuteTenant`, and `ExecuteRegional`
- **`queries_AzureResourceManager_CopyQuery` pipeline** — Performs the authenticated request and writes Parquet to the ingestion container

## How it works

1. IngestionQueries dispatches to `ExecuteQuery` through the engine contract.
2. `ExecuteQuery` validates the scope as an Azure resource ID, including hexadecimal subscription GUIDs, and validates the query as an ARM-relative path.
3. Scope expansion runs across the three expansion pipelines, chained by `ExecutePipeline`. Each pipeline expands one looping dimension: configured billing scopes, then tenant/subscription, then region. Configured billing scopes are filtered against each query's `scopeTypes`. The direct-vs-regional routing per subscription is a non-looping `IfCondition`, so it's inlined in `ExecuteTenant` rather than given its own pipeline. `ExecuteTenant` pages through the full subscription list itself (`Set Subscriptions Url` / `Get All Subscription Pages` / ...) rather than issuing one `Web` call, because the Subscriptions - List API paginates via `nextLink` once a tenant has enough subscriptions; a single call would silently under-count at scale.
4. The chain exists because ADF containers cannot nest. A `ForEach` cannot contain another `ForEach`, so each additional looping dimension requires its own pipeline.
5. The innermost level invokes `CopyQuery` once per fully-resolved scope.
6. `CopyQuery` first sends the query as an authenticated GET from a `Web` activity. An `If` condition then runs the Copy activity only when that response contains at least one item. An empty result set therefore never produces a file. This is the same check the AzureResourceGraph app performs before its Copy activity.
7. A single Copy activity performs the request and writes Parquet. Multi-page responses are followed by the REST source's native `paginationRules` on `$.nextLink`. There is no manual paging loop.

## Design constraints

These constraints are binding. Read them before changing this app.

- **Use the existing art exclusively.** Every pipeline pattern here must already exist in a sibling app, in `IngestionQueries`, or in `Microsoft.CostManagement`. Do not introduce a pattern that has no precedent in this repository, and do not adapt a pattern beyond what the precedent already does.
- The empty-result check is the AzureResourceGraph pattern: a `Web` activity, then an `If` condition, then the Copy activity. Do not replace it with a write-then-delete guard, a row count, a fault-tolerance setting, or a `Fail` activity.
- `CopyQuery` has no pipeline-level `concurrency` setting, matching AzureResourceGraph. It is invoked from three independent fan-out points (`ForEach Scope`, the direct-query branch of `ForEach Subscription`, `ForEach Location`); a shared cap there makes their `batchCount`s multiply against one budget instead of scaling independently, which is what previously forced `ForEach Location` down to 1. Tune each `ForEach`'s own `batchCount` instead; do not add a `concurrency` value back to `CopyQuery`.
- The authority comes from `environment().resourceManager` in every request URL. Do not accept an authority from a query file.
- `ForEach Location`'s `batchCount: 8` is proven against a single-subscription tenant only (see `pipeline_ExecuteRegional`'s comment). `ForEach Subscription`'s existing `batchCount: 30` has never run concurrently against it at scale — a tenant with 30 subscriptions in flight at once, each fanning out to 8 regions, would produce up to 240 simultaneous `CopyQuery` calls, over double what's been verified safe. Do not assume this scales linearly to multi-subscription tenants without testing against one.
- `ExecuteTenant`'s subscription-page loop hits two ADF expression-language constraints that are easy to reintroduce if "simplified": a `SetVariable` cannot read the variable it writes ("self reference is not supported"), so the accumulated array is merged into a scratch variable and copied back in a second `SetVariable`; and ARM omits `nextLink` entirely (not `null`) on the last page, so the loop's continuation URL is set behind an `IfCondition` gated on `contains(activity(...).output, 'nextLink')` rather than `coalesce(...)`, which throws on a genuinely absent property path. Both were proven live against a single-subscription tenant (the loop terminates after one page).
- **At-scale feasibility (~5,000 subscriptions, 4-hour target) is not directly provable on a single-subscription tenant, but the documented platform ceilings support it.** ARM's read throttling (per [request-limits-and-throttling](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling)) is scoped per subscription/service-principal/operation-type, and resource-provider-specific throttling (e.g. the `usages` endpoints this app calls) is scoped per subscription *per region*: a design that fans out by subscription and region, as this one does, does not contend on a single shared bucket. ADF's own binding ceiling ([Data Factory limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#data-factory-limits)) is 3,000 concurrent **External** activity runs (the class `Web` activity belongs to) per Data Factory's own subscription per Azure Integration Runtime region — default equals maximum, not raisable — and 10,000 concurrent pipeline runs per factory. Azure Optimization Engine (`src/optimization-engine/`), cited as prior art for multi-subscription scale, does not fan out per-subscription ARM calls at all; it passes the full subscription list to a single Azure Resource Graph query. That approach does not transfer here: ARG only indexes actual resources (each with a `resourceId`), and subscription quota/usage data returned by the `usages` endpoints has no such resource type in ARG's [supported tables](https://learn.microsoft.com/en-us/azure/governance/resource-graph/reference/supported-tables-resources).

## Dependencies

- **Core app** — Provides the `azurerm` linked service and the `ingestion` dataset.
- **Data Factory managed identity** — Requires read access to each configured ARM endpoint.

## Limitations

- Only GET requests are supported.
- Query files cannot configure the HTTP method, headers, body, authority, or authentication resource.
- The empty-result check reads the `value` array on the response. A provider that returns its results under a different property is not supported.
- A provider that fails rather than returning an empty array, such as the Network provider returning `SubscriptionHasNoUsages`, fails the pipeline. The check does not suppress errors.
- The empty-result check performs the same GET as the real request via a `Web` activity, which has a fixed ~4 MB response-size ceiling independent of the Copy activity's own limits. A query whose full response exceeds that size (observed live: `Microsoft.Compute/skus`, the tenant-wide VM SKU catalog) fails the check with error code `2001` before the Copy activity ever runs. This is a pre-existing limitation, not something introduced by the concurrency changes above, and is unresolved.
