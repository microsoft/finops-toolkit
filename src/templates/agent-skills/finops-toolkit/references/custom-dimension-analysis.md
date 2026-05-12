---
name: custom-dimension-analysis
description: Analyze costs with business allocation fields and tags in FinOps hubs for showback, chargeback, and ownership reporting when those fields are populated.
author: Microsoft
version: 1.0.0
license: Apache-2.0
---

# Custom dimension analysis

## Purpose
Use this reference to analyze costs through business-aligned dimensions such as team, product, application, environment, cost center, or project. In FinOps hubs, `Costs()` is the primary surface for this analysis.

Treat business allocation metadata as observed and optional. Do not assume every hub populates every tag or enrichment column.

## Validated grounding
Use these repo assets as the approved starting points:
- `Costs()` for primary analysis
- `costs-enriched-base.kql` to inspect enriched cost records and available metadata
- `cost-by-financial-hierarchy.kql` for a ready-made allocation pattern
- `finops-hub-database-guide.md` for schema details
- `INDEX.md` to find the right catalog query for the scenario

## Business allocation fields to inspect
Inspect which populated fields, tags, and columns are actually present in your hub before choosing a business dimension.

Common fields worth checking:
- `Tags['team']`
- `Tags['product']`
- `Tags['application']`
- `Tags['environment']`
- `x_CostCenter`
- `x_Project`
- `x_BillingProfileName`
- `x_InvoiceSectionName`

Some environments have strong tag coverage, some rely more on financial hierarchy columns, and some have both. Use only the fields that are observed and meaningfully populated in the reporting period.

## Recommended workflow

### 1. Inspect populated business fields first
Start with `costs-enriched-base.kql` or a small direct query against `Costs()`:

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| project x_BillingProfileName, x_InvoiceSectionName, x_CostCenter, x_Project, Tags
| take 50
```

Review which available fields and tags are actually populated. If available, compare how consistently `Tags['team']`, `Tags['product']`, `Tags['application']`, `Tags['environment']`, `x_CostCenter`, and `x_Project` are filled.

### 2. Choose the business dimension with the best coverage
If `Tags['team']` is populated, start there:

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend Team = tostring(Tags['team'])
| summarize EffectiveCost = sum(EffectiveCost) by Team
| order by EffectiveCost desc
```

Repeat the same pattern for `Tags['product']`, `Tags['application']`, `Tags['environment']`, `x_CostCenter`, or `x_Project` when populated.

### 3. Add financial hierarchy context
Use `cost-by-financial-hierarchy.kql` when you need business reporting that rolls up through billing ownership and allocation layers.

Example pattern:

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend Team = tostring(Tags['team'])
| extend Product = tostring(Tags['product'])
| extend Application = tostring(Tags['application'])
| summarize EffectiveCost = sum(EffectiveCost)
    by x_BillingProfileName, x_InvoiceSectionName, Team, Product, Application, x_CostCenter, x_Project
| order by EffectiveCost desc
```

This is useful for showback and chargeback because it connects business ownership to the financial hierarchy already present in the hub.

### 4. Measure allocation coverage honestly
Business reporting is only as strong as field coverage.

```kusto
let base =
    Costs()
    | where ChargePeriodStart >= startofmonth(ago(30d))
    | extend Team = tostring(Tags['team']);
base
| summarize
    TotalCost = sum(EffectiveCost),
    AllocatedCost = sumif(EffectiveCost, isnotempty(Team))
| extend AllocationCoverage = AllocatedCost / TotalCost
```

If the selected field is only partially populated, say so clearly. Unallocated cost is an important finding, not a formatting problem.

### 5. Compare multiple business dimensions only when useful
If populated, compare team, product, application, cost center, or project to answer questions such as:
- Which team owns the most cost?
- Which product has the fastest growth?
- Which application is expensive across multiple invoice sections?
- Which `x_CostCenter` or `x_Project` values have weak allocation coverage?

## Output guidance
Present results in a way finance and engineering teams can use:

### Executive summary
- Dimension analyzed
- Reporting window
- Total effective cost
- Allocation coverage percentage
- Largest observed business owner or group
- Biggest data quality gap, if populated fields are inconsistent

### Business dimension breakdown
| Business dimension | Effective cost | Percent of total | Coverage note |
|---|---:|---:|---|
| Team A | $X | Y% | Well populated |
| Team B | $X | Y% | Partial tags |
| Unallocated | $X | Y% | Missing tag or field |

### Financial hierarchy context
Where useful, add:
- `x_BillingProfileName`
- `x_InvoiceSectionName`
- `x_CostCenter`
- `x_Project`

This helps separate business ownership from billing structure.

## Interpretation guidance
- Prefer the field with the most stable and populated coverage.
- If multiple fields disagree, call that out as a data-quality issue.
- If `Tags['environment']` is populated, use it to separate production from non-production before comparing teams or products.
- If `x_CostCenter` or `x_Project` is populated only for part of the estate, describe that limitation directly.
- Use `finops-hub-database-guide.md` to verify column meaning before making claims about ownership.
- Use `INDEX.md` to decide whether a catalog query is better than a custom query for the scenario.

## Good analyst behavior
- Tell readers which fields were observed.
- Tell readers which fields were optional or sparsely populated.
- Tell readers to inspect populated tags before standardizing on a showback dimension.
- Keep the analysis centered on `Costs()` and validated query assets.

## See also
- `queries/finops-hub-database-guide.md`
- `queries/INDEX.md`
- `queries/catalog/costs-enriched-base.kql`
- `queries/catalog/cost-by-financial-hierarchy.kql`
