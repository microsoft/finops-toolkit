---
name: focus-data-quality
description: Use when the user works with FOCUS cost data — validating FOCUS conformance, mapping native Azure cost exports to FOCUS columns, checking dataset completeness/freshness, or troubleshooting ingestion gaps that make cost analysis wrong. FOCUS is the FinOps Open Cost and Usage Specification.
license: MIT
compatibility: Requires access to the cost dataset — FOCUS exports in storage, or a FinOps hub that ingests them. Pairs with the finops-toolkit skill (hub ingestion) and the finops-multitool skill.
metadata:
  author: microsoft
  version: "1.0"
---

# FOCUS data quality

Good FinOps analysis depends on good data. FOCUS (FinOps Open Cost and Usage Specification) is the open standard that normalizes cost and usage across providers. This skill validates that the FOCUS data feeding everything else is complete, conformant, and trustworthy.

## When to use this skill

Use it when the user mentions FOCUS, cost exports, column mapping, ingestion gaps, "the numbers look wrong/incomplete," or data freshness. If a downstream skill (Power BI, reporting, allocation) produces suspicious results, suspect data quality and come here first.

## What FOCUS gives you

A common schema so the same query works across providers and over time. Key columns the toolkit and queries rely on:

| Column | Meaning |
|--------|---------|
| `BilledCost` | What the invoice charges for the period |
| `EffectiveCost` | Amortized cost (commitments spread over their term) |
| `ListCost` | Cost at public list price (the savings baseline) |
| `ContractedCost` | Cost at negotiated/contracted price |
| `ChargeCategory` | Usage / Purchase / Tax / Credit / Adjustment |
| `ServiceName`, `ResourceName`, `Region`, `Tags` | Dimensions for grouping/allocation |

Reference: https://learn.microsoft.com/cloud-computing/finops/focus/what-is-focus

## Conformance checks

1. **Schema** — required FOCUS columns present and correctly typed; `x_` columns are toolkit enrichments, not FOCUS itself.
2. **Cost relationships** — sanity-check `ListCost ≥ ContractedCost ≥ EffectiveCost` in aggregate; large violations signal a mapping error.
3. **Charge categories** — Usage dominates; Purchase rows appear when commitments are bought; Credits net negative. Missing categories = partial export.

## Completeness and freshness

| Check | Bad sign | Cause |
|-------|----------|-------|
| **Date coverage** | Gaps or missing recent days | Export schedule broken or lagging (Azure cost data lags ~1–3 days) |
| **Scope coverage** | A subscription/account missing | Export scope too narrow, or RBAC on the export |
| **Row counts vs prior period** | Sudden drop | Failed export run or partial ingestion |
| **Total vs portal** | Material mismatch | Billed-vs-effective confusion, missing scope, or currency mix |
| **Tag dimension empty** | Tags blank in cost data | Tag not enabled as a cost-allocation dimension (common — see `cost-allocation`) |

## Mapping native exports to FOCUS

When data comes from a legacy/native Azure cost export rather than a FOCUS export, map before analyzing: cost-in-billing-currency → `BilledCost`, amortized cost → `EffectiveCost`, list price × quantity → `ListCost`, meter/service → `ServiceName`, resource id → `ResourceName`. The FinOps hub does this automatically on ingestion; defer to the `finops-toolkit` skill's `focus/mapping.md` for the full crosswalk.

## Hand-offs

- Ingestion pipeline health → `finops-toolkit` skill (hub ingestion / data-ingestion report).
- Tag dimension empty → `cost-allocation` skill.
- Once data is trusted → `power-bi-finops`, `finops-reporting`, `unit-economics`.
