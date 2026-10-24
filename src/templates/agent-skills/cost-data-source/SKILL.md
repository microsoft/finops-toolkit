---
name: cost-data-source
description: This skill should be used before any spend question that would call the FinOps multitool cost tools — "what's my cost", "current spend", "top resources by cost", "cost by tag", "this month's bill", "where is the money going", or any "cost scan". It decides whether to read from a FinOps Hub (its Kusto database or storage export) or the live Cost Management API, warns the user before a slow API scan, and supports chunking large tenants for incremental progress. Use it to keep cost scans fast and the session engaging instead of blocking on long API runs.
license: MIT
compatibility: Requires the finops-multitool skill and an authenticated Azure session (Connect-AzAccount). The hub Kusto path needs read access to the FinOps Hub Azure Data Explorer / Fabric cluster (or a reachable ftklocal emulator); the storage-reader fallback needs Storage Blob Data Reader on the hub storage account. The cost tools this skill routes are read-only.
metadata:
  author: microsoft
  version: '1.2'
---

# Cost data source routing

Cost questions can be answered from a **FinOps hub**, from existing **Cost Management exports**, or from the **live Cost Management API** (real-time, but slow at scale). The terminal UI exposes these as `Start-FinOpsMultitool -DataSource Hub`, `Export`, or `API`; `GraphOnly` skips cost scans entirely. When a hub is used, the tool picks the path inside the hub automatically:

- **Hub Kusto database** (Azure Data Explorer / Fabric, or a local ftklocal emulator) — the scalable path. Aggregation runs in the engine and only summaries return, so it handles large datasets (tens of GB / hundreds of millions of rows) without loading rows.
- **Hub storage reader** (FOCUS parquet/CSV in storage) — a small-dataset convenience fallback used when no Kusto cluster is reachable. Rows are aggregated in PowerShell.

This skill decides between a hub, exports, and the live API so cost scans stay fast and the session stays interactive. The storage-versus-Kusto choice within the hub is automatic — you don't pick it.

This routing applies **only** to the spend-breakdown scans that can read hub or export data:

- cost data (current month actuals per subscription)
- resource costs (top resources by cost)
- cost by tag (spend by tag key/value)
- cost trend, for the months present in a selected export run (`Export` only)

Other cost-family scans — budget status, anomaly alerts, reservation advice, commitment utilization, savings realized — aren't derivable from cost exports. They use the live API with a hub and are excluded with `Export`. Governance and optimization scans are unaffected.

## Protocol: detect first, then decide

For any spend question that maps to one of the scans above, do this **before** running a cost scan:

1. **Confirm scope.** State the tenant and subscriptions you'll read (see `finops-multitool`).
2. **Look for a hub.** Query Azure Resource Graph, scoped to the selected subscriptions, for Azure Data Explorer clusters tagged `ftk-tool` = `FinOps hubs` and storage accounts whose `cm-resource-parent` tag contains `Microsoft.Cloud/hubs`. `FINOPS_HUB_KUSTO_URI` points the terminal UI at a specific Kusto endpoint, such as a local ftklocal emulator.
3. **Check access.** Kusto needs database query access. The storage reader needs Storage Blob Data Reader on the hub storage account. A hub existing doesn't mean you can read it.
4. **Check coverage and freshness.** Compare the subscriptions in the hub data with the requested scope, and note the newest data date.
5. **Decide** with the table below. Never silently run a slow API scan — warn and ask first.

## Branch behaviours

**A readable hub covers the scope.**
Run with `-DataSource Hub`, or query the hub database directly. State the result is from the hub and label it "as of `<data date>`" — no need to ask. The hub returns billed actuals; current-month forecasts, when shown, are separate full-month totals from the Cost Management API.

**A readable hub covers only some subscriptions.**
Tell the user the coverage (e.g., "the hub covers 1 of 4 subscriptions, ~25%"). Ask which they want:

- the hub for the covered subscriptions only (fast, partial), or
- the live API for full coverage (slower — say roughly how many subscriptions it reads).

**A hub exists but isn't readable.**
Name the missing role or network block and its fix (for example, "you have a hub but lack Storage Blob Data Reader on its storage account — granting that role enables the storage reader; or point at the hub's Kusto cluster, which doesn't need storage access"). Ask whether to:

- fix access and retry the hub, or
- proceed now on the live API.

**No hub, but Cost Management CSV exports exist.**
Offer `-DataSource Export`. It reads one chosen export run for cost totals, resource costs, cost by tag, and the months present in that run. It requires ActualCost or FOCUS BilledCost data and doesn't read Parquet.

**No usable hub or exports.**
There is no hub path. Say how large the live scan is and ask before running it. If the scope is large, offer to chunk (see below) so results arrive in stages. Once the user agrees, run with `-DataSource API`.

## Consent before slow scans

Treat any live-API cost scan across many subscriptions as something to confirm first. Lead with the size ("a live cost scan across these N subscriptions can take several minutes"). Don't fire a long scan unannounced — the user's priority is a fast, informative session.

## Chunking large tenants

When the live API path is the only option and the scope is large, chunk it so progress is visible:

1. Split the subscription list into batches.
2. Run each batch separately: direct Cost Management queries scoped to the batch, or `Start-FinOpsMultitool -SubscriptionId <id> -DataSource API` for one subscription at a time.
3. After each batch, report progress and separate running totals for each currency and reporting period. Don't combine incompatible amounts or treat failed batches as zero spend.

The detection step needs to run only once per scope; reuse its decision across the batches.

## Reading the result

The terminal UI and HTML report name the cost source in the report header ("Cost data: ...").

- **FinOps hub (Kusto or storage)** — lead with "as of `<data date>`" and the subscriptions the hub covers.
- **Cost Management export** — label results with the export run's data date. Partial coverage stays unverified rather than filled with live costs.
- **Cost Management API** — live, real-time data.

Always tell the user which source the numbers came from and, for hub or export data, how fresh it is. An explicit hub or export request that can't be read is reported as an error; it doesn't switch to the live API. Confirm with the user before running a separate API scan.

## Quick reference

| Situation                                | Action                                                                      | Ask the user? |
| ---------------------------------------- | --------------------------------------------------------------------------- | ------------- |
| Readable hub covers the scope            | `-DataSource Hub`, label "as of `<data date>`"                              | No            |
| Readable hub covers part of the scope    | Offer hub (partial) vs API (full)                                           | Yes           |
| Hub exists but isn't readable            | Name blocker + fix; offer retry vs API                                      | Yes           |
| No hub, readable CSV exports             | Offer `-DataSource Export` for its supported scans                          | Yes           |
| No hub or exports                        | State the scan size; offer chunking; run `-DataSource API`                  | Yes           |

## Prerequisites

- An authenticated Azure session (`az login`, or `Connect-AzAccount` for the terminal UI).
- The scalable hub path needs read access to the FinOps Hub Kusto database — an Azure Data Explorer / Fabric cluster (discovered automatically), or a reachable ftklocal emulator via `FINOPS_HUB_KUSTO_URI`.
- The storage-reader fallback and the export reader need **Storage Blob Data Reader** or equivalent data access on the storage account, plus network access.
- Everything this skill routes is read-only.
