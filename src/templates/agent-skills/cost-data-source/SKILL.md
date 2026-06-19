---
name: cost-data-source
description: This skill should be used before any spend question that would call the FinOps Multitool cost tools — "what's my cost", "current spend", "top resources by cost", "cost by tag", "this month's bill", "where is the money going", or any "cost scan". It decides whether to read from a FinOps Hub (its Kusto database or storage export) or the live Cost Management API, warns the user before a slow API scan, and supports chunking large tenants for incremental progress. Use it to keep cost scans fast and the session engaging instead of blocking on long API runs.
license: MIT
compatibility: Requires the finops-multitool MCP server (see .vscode/mcp.json) and an authenticated Azure session (Connect-AzAccount). The hub Kusto path needs read access to the FinOps Hub Azure Data Explorer / Fabric cluster (or a reachable ftklocal emulator); the storage-reader fallback needs Storage Blob Data Reader on the hub storage account. The cost tools this skill routes are read-only.
metadata:
  author: microsoft
  version: '1.1'
---

# Cost data source routing

Cost questions can be answered from a **FinOps Hub** or from the **live Cost Management API** (real-time, but slow at scale because it queries per subscription). When a hub is used, the tool picks the path automatically:

- **Hub Kusto database** (Azure Data Explorer / Fabric, or a local ftklocal emulator) — the scalable path. Aggregation runs in the engine and only summaries return, so it handles large datasets (tens of GB / hundreds of millions of rows) without loading rows.
- **Hub storage reader** (FOCUS parquet/CSV in storage) — a small-dataset convenience fallback used when no Kusto cluster is reachable. Rows are aggregated in PowerShell.

This skill decides hub vs API so cost scans stay fast and the session stays interactive. The hub-vs-storage-vs-Kusto choice within the hub is automatic — you don't pick it.

This routing applies **only** to the spend-breakdown tools that read from a hub:

- `scan_cost_data` (current month actuals per subscription)
- `scan_resource_costs` (top resources by cost)
- `scan_cost_by_tag` (spend by tag key/value)

All other cost-family tools — `scan_cost_trend`, `scan_budget_status`, `scan_anomaly_alerts`, `scan_reservation_advice`, `scan_commitment_utilization`, `scan_savings_realized` — are **not** derivable from cost exports and always run on the live API. Governance and optimization tools are unaffected.

## Protocol: detect first, then decide

For any spend question that maps to one of the three tools above, do this **before** calling the cost tool:

1. Call `detect_cost_data_source` (pass `subscriptionId` if the user scoped to one subscription). It returns a decision object describing whether a hub was found, whether it is readable, what it covers, how fresh it is, and how long the live API path would take.
2. Branch on the `Recommendation` field. Never silently run a slow API scan — warn and ask first.

### Decision object fields

| Field                 | Meaning                                                                                                                                         |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `HubFound`            | Whether a FinOps Hub / cost export exists in scope                                                                                              |
| `Readable`            | Whether the export can actually be read with the current identity                                                                               |
| `KustoClusterUri`     | The hub's Azure Data Explorer / Fabric cluster URI when discovered (the scalable engine path). Empty when only the storage reader is available. |
| `ReadBlocker`         | Why it is not readable: `NoRbac`, `NetworkDenied`, `PublicAccessDisabled`, `DependencyMissing`, `Unknown`, or `None`                            |
| `RemediationHint`     | The concrete fix for the blocker                                                                                                                |
| `CoveragePct`         | Share of the requested subscriptions the hub covers                                                                                             |
| `Freshness`           | Date of the newest export data (use this as the "as of" label)                                                                                  |
| `EstimatedApiSeconds` | Rough wall-clock estimate for the live API path over the requested scope                                                                        |
| `Recommendation`      | `UseHub`, `UseHubPartial`, `FixAccessThenHub`, or `UseApi`                                                                                      |
| `Message`             | A short human summary you can relay                                                                                                             |

## Branch behaviours

**`UseHub` — readable hub covers the scope.**
Call the cost tool with `dataSource: "hub"`. State the result is from the hub and label it "as of `<Freshness>`" — no need to ask. The tool serves it from the hub Kusto database when a cluster is available (engine-side aggregation, scalable) or the storage reader otherwise; the `source` field on the result tells you which. The hub returns billed actuals only; if the user explicitly needs a live forecast, call with `dataSource: "api"`.

**`UseHubPartial` — readable hub, but it covers only some subscriptions.**
Tell the user the coverage (e.g., "the hub covers 1 of 4 subscriptions, ~25%"). Ask which they want:

- the hub for the covered subscriptions only (fast, partial), or
- the live API for full coverage (slower — give the `EstimatedApiSeconds` estimate).
  Then call the tool with `dataSource: "hub"` or `dataSource: "api"` accordingly.

**`FixAccessThenHub` — a hub exists but is not readable.**
Name the blocker and its fix from `ReadBlocker` / `RemediationHint` (for example, "you have a hub but lack Storage Blob Data Reader on its storage account — granting that role enables the storage reader; or point at the hub's Kusto cluster, which doesn't need storage access"). Ask whether to:

- fix access and retry the hub, or
- proceed now on the live API (give the `EstimatedApiSeconds` estimate).

**`UseApi` — no usable hub in scope.**
There is no hub path. Relay the `EstimatedApiSeconds` estimate and ask before running a long scan. If the estimate is large, offer to chunk (see below) so results stream in. Once the user agrees, call the tool with `dataSource: "api"`.

## Consent before slow scans

Treat any live-API cost scan with a non-trivial `EstimatedApiSeconds` as something to confirm first. Lead with the estimate ("a live cost scan across these N subscriptions will take roughly M seconds"). Don't fire a long scan unannounced — the user's priority is a fast, informative session.

## Chunking large tenants

When the live API path is the only option and the scope is large, chunk it so progress is visible:

1. Split the subscription list into batches.
2. Call the cost tool once per batch, passing `subscriptionIds` (an array) for that batch and `dataSource: "api"`.
3. After each batch, report incremental progress and a running total — e.g., "batch 2 of 5 done, $42,100 so far".

`subscriptionIds` overrides `subscriptionId` when both are present. The detection step needs to run only once per scope; reuse its decision across the batches.

## Reading the result

Each cost-tool result carries a `source` field:

- `source: "FinOpsHubKusto"` — served from the hub's Kusto database (Azure Data Explorer / Fabric / ftklocal), aggregated in the engine. The scalable path. Use the `asOf` and `coveragePct` fields when summarizing, and lead with "as of `<asOf>`".
- `source: "FinOpsHub"` — served from the hub storage reader (small-dataset path). Same `asOf` / `coveragePct` handling. The `note` field flags that forecast is excluded.
- `source: "CostManagementExport"` — served from a readable Cost Management CSV export (small-dataset path).
- `source: "LiveApi"` — live Cost Management API, real-time.

Always tell the user which source the numbers came from and, for hub data, how fresh it is. If a hub read was requested with `dataSource: "hub"` but neither a Kusto cluster nor a readable export was available, the tool returns an error naming the blocker — fall back by re-calling with `dataSource: "api"` after confirming with the user.

## Quick reference

| `Recommendation`   | Action                                                          | Ask the user? |
| ------------------ | --------------------------------------------------------------- | ------------- |
| `UseHub`           | Call tool with `dataSource: "hub"`, label "as of `<Freshness>`" | No            |
| `UseHubPartial`    | Offer hub (partial) vs API (full + estimate)                    | Yes           |
| `FixAccessThenHub` | Name blocker + fix; offer retry vs API (estimate)               | Yes           |
| `UseApi`           | Give estimate; offer chunking; run on `dataSource: "api"`       | Yes           |

## Prerequisites

- The `finops-multitool` MCP server must be running (defined in `.vscode/mcp.json`).
- An authenticated Azure session is required (`Connect-AzAccount`).
- The scalable hub path needs read access to the FinOps Hub Kusto database — an Azure Data Explorer / Fabric cluster (discovered automatically), or a reachable ftklocal emulator via `FINOPS_HUB_KUSTO_URI`.
- The storage-reader fallback additionally needs **Storage Blob Data Reader** on the hub storage account. Without any hub path, `detect_cost_data_source` reports the blocker and the live API is used instead.
- The cost tools this skill routes are read-only.
