---
name: understand-finops-hub-context
description: Mandatory foundational reference for establishing FinOps hub context before analysis
author: Microsoft
version: 1.0.0
license: Apache-2.0
---

# Understand FinOps hub context

## Purpose

This is the mandatory foundational step before any cost analysis. Start by confirming the active FinOps hub, validating the cluster URI, and establishing the available hub context before moving into deeper analysis.

Use this reference once at the beginning of an analysis session, then reuse that context for the rest of the conversation instead of repeating the same setup work.

## Required grounding references

- `references/workflows/ftk-hubs-connect.md`
- `references/workflows/ftk-hubs-healthCheck.md`
- `references/queries/finops-hub-database-guide.md`
- `references/queries/INDEX.md`

## When to use

- **Mandatory** at the start of any FinOps analysis conversation or workflow
- Before using deeper query-catalog analysis patterns
- When switching to a different hub or cluster URI
- When the current session does not yet have confirmed hub context

## What this step establishes

This step confirms the Hub is reachable and identifies what context is actually observable from the FinOps hubs dataset. Ground your work in Azure Data Explorer, KQL, and the query catalog rather than assumptions.

### Core data surfaces

Use the documented functions from `references/queries/finops-hub-database-guide.md`:

- `Costs()`
- `Prices()`
- `Recommendations()`
- `Transactions()`

### Minimum validation query

Use a simple KQL summary to understand data coverage before analysis:

```kusto
Costs()
| summarize Rows=count(), MinCharge=min(ChargePeriodStart), MaxCharge=max(ChargePeriodStart), Services=dcount(ServiceName), ResourceGroups=dcount(x_ResourceGroupName)
```

This gives a quick view of row volume, date range, service diversity, and resource-group coverage.

### Tag-key discovery

Discover which tags are present instead of assuming a business taxonomy:

```kusto
Costs()
| mv-expand TagKey = bag_keys(Tags)
| summarize by TagKey
| order by TagKey asc
```

Observed keys may include values such as `org`, `env`, `Project`, or `CostCenter`, but business tags are not guaranteed to exist consistently.

## How to use this reference

### Step 1: Connect to the correct Hub

Follow `references/workflows/ftk-hubs-connect.md` to identify or confirm the active FinOps hub and cluster URI.

If a cluster URI is already established for the session, reuse it. If not, connect first before running analysis queries.

### Step 2: Validate the Hub and data freshness

Use `references/workflows/ftk-hubs-healthCheck.md` after connection if you need to confirm version guidance or investigate stale data.

### Step 3: Establish baseline analytical context

Use the schema guide in `references/queries/finops-hub-database-guide.md` and the query catalog in `references/queries/INDEX.md` to choose the right starting point.

For most custom exploration, begin with a small validation query, then expand into a catalog query or a focused KQL investigation.

### Step 4: Record only observed business context

Summarize what the Hub actually shows. Keep the summary factual and bounded to observable cost, pricing, recommendation, transaction, enrichment, and tag evidence.

## Honest interpretation rules

- Optional team tags may be missing, so treat them as observed only when present.
- Optional product tags may be missing or blank in many datasets.
- Optional application tags may be missing; if present, validate the actual tag key and coverage before using them.
- Optional environment tags are not guaranteed and may appear as `env` instead of a full `environment` key.

Validation shorthand: `\bteam\b` is optional, `\bproduct\b` is optional, `\bapplication\b` is optional, and `\benvironment\b` is not guaranteed.

Do not treat business tags as universal requirements across all records.

Do not infer budget ownership, stakeholder mappings, recharge policy details, or future business milestones from Hub data alone. Those require separate business or governance inputs outside this foundational step.

## Suggested output format

After this step, provide a concise summary like:

### Hub context summary

- **FinOps hub**: [hub name or cluster short URI]
- **Cluster URI**: [active cluster URI]
- **Data coverage**: [min/max charge period, row count, major service count]
- **Available functions used for follow-up**: `Costs()`, `Prices()`, `Recommendations()`, `Transactions()`
- **Observed tag keys**: [examples discovered with `bag_keys(Tags)`]
- **Known gaps or cautions**: [missing tags, sparse coverage, stale data, or incomplete enrichment]

### Recommended next move

- Use `references/queries/INDEX.md` to choose a scenario-specific query.
- Use `references/queries/finops-hub-database-guide.md` to verify columns and enrichment fields.

## Integration guidance for other references

Other analysis references should assume this foundational step happened first. They should reuse the established hub context, cluster URI, freshness status, and observed tag evidence instead of re-establishing them from scratch.

## Best practices

1. Connect once, then reuse the confirmed hub context.
2. Prefer observed tag keys over assumed business dimensions.
3. Start with lightweight KQL validation before large analysis queries.
4. Use the query catalog for scenario-specific analysis instead of inventing unsupported patterns.
5. Keep conclusions limited to what the Hub data actually shows.

## See also

- `references/workflows/ftk-hubs-connect.md`
- `references/workflows/ftk-hubs-healthCheck.md`
- `references/queries/finops-hub-database-guide.md`
- `references/queries/INDEX.md`
