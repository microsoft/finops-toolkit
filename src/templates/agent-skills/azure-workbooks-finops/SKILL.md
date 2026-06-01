---
name: azure-workbooks-finops
description: Use when the user wants to deploy, interpret, or customize the FinOps toolkit Azure Monitor workbooks (Governance and Optimization), build a workbook from cost/resource data, or troubleshoot a workbook that shows no data. For Azure Monitor workbooks specifically — not Power BI.
license: MIT
compatibility: Requires Azure access with Reader (to view) or Workbook Contributor (to save) and, for some tiles, Azure Resource Graph and Cost Management read access. Pairs with the finops-multitool MCP server.
metadata:
  author: microsoft
  version: "1.0"
allowed-tools: az pwsh
---

# Azure Monitor workbooks for FinOps

The FinOps toolkit ships Azure Monitor workbooks that surface governance and optimization findings directly in the Azure portal — no external BI tool required. This skill covers deploying, reading, and customizing them.

## When to use this skill

Use it when the user mentions Azure Monitor workbooks, the Governance or Optimization workbook, in-portal cost/waste views, or wants a workbook (not Power BI). For an external dashboard use `power-bi-finops`; for headless data use the `finops-multitool` scans.

## The two toolkit workbooks

| Workbook | Surfaces | Backed by |
|----------|----------|-----------|
| **Governance** | Tag coverage, policy compliance, resource hygiene, allocation readiness, naming/region drift | Azure Resource Graph |
| **Optimization** | Idle/orphaned resources, rightsizing, commitment coverage, Advisor cost recommendations, waste | Resource Graph + Advisor + Cost Management |

Both are deployed from the toolkit and run live against the selected subscriptions/scope — they reflect current state, not a snapshot.

## Deploying

Deploy via the toolkit's workbook template (ARM/Bicep) into a resource group, then open it under **Azure Monitor → Workbooks**. Scope the workbook with the subscription/resource-group parameters at the top. For deployment specifics defer to the toolkit's workbook docs; the build packaging copies the workbook assets under the toolkit release.

## "Workbook shows no data" triage

| Symptom | Cause | Fix |
|---------|-------|-----|
| All tiles empty | Scope parameter set to a subscription with no matching resources | Re-select subscription(s) at the top |
| Cost tiles empty, ARG tiles fine | Missing Cost Management reader at the chosen scope | Grant Cost Management Reader |
| Advisor tiles empty | Advisor hasn't generated recommendations yet | Wait for Advisor refresh; confirm category = Cost |
| Permission error on a tile | Reader missing on a child subscription | Add Reader at management-group scope |
| Slow load across many subs | Resource Graph fan-out | Narrow the scope or split the workbook run |

## Customizing

- Workbook tiles are Resource Graph (KQL-for-ARG) or Azure Monitor queries — edit the query behind a tile to change what it shows.
- ARG query language overlaps with the patterns in `azure-orphaned-resources` (in the `azure-cost-management` skill) — reuse those queries for new waste tiles.
- Add a parameter for tag key/value to make governance tiles allocation-aware (ties into the `cost-allocation` skill).
- Save customized workbooks as a new shared workbook so toolkit upgrades don't overwrite them.

## Workbook vs Power BI — when to use which

- **Workbook** — live, in-portal, RBAC-scoped, zero extra cost, good for ops/governance teams already in Azure.
- **Power BI** — richer visuals, scheduled refresh, shareable outside the portal, better for exec reporting and large historical analysis (use a FinOps hub source). See `power-bi-finops`.

## Hand-offs

- Same findings as data/JSON → `finops-multitool` scans.
- Richer/historical visuals → `power-bi-finops`.
- Enforce what the Governance workbook flags → `azure-policy-governance`.
