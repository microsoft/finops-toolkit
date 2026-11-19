---
name: tag-coverage-analysis
description: Analyze tag coverage and unattributed cost in FinOps hubs using validated cost fields, observed tags, and business allocation metadata.
author: Microsoft
version: 1.1.0
license: Apache-2.0
---

# Tag coverage analysis

## Purpose

Use this reference to evaluate how well cost records can be attributed through tags and business fields in FinOps hubs.

Keep the original tag coverage intent, but ground the analysis in validated FinOps hubs patterns:

- `Costs()` as the primary analytical surface
- `Tags[...]` for tag inspection and tag-based attribution
- business fields such as `x_CostCenter`, `x_Project`, `ServiceName`, `SubAccountName`, and `x_ResourceGroupName`
- query and schema assets including `costs-enriched-base.kql`, `cost-by-financial-hierarchy.kql`, `finops-hub-database-guide.md`, and `INDEX.md`

Treat tags and business fields as observed and optional. Do not assume every hub populates every tag, enrichment column, or ownership field.

## Grounding and prerequisites

Before starting:

1. Review [finops-hub-database-guide.md](./queries/finops-hub-database-guide.md) for schema details.
2. Review [INDEX.md](./queries/INDEX.md) to confirm whether a catalog query already fits the scenario.
3. Start from [costs-enriched-base.kql](./queries/catalog/costs-enriched-base.kql) when you need to inspect raw enriched records.
4. Use [cost-by-financial-hierarchy.kql](./queries/catalog/cost-by-financial-hierarchy.kql) when tag coverage needs to be compared with financial hierarchy fields.

Inspect which populated tags, fields, and columns are actually present in the reporting window before calculating coverage.

## When to use

- “What is our tag coverage?”
- “How much cost is unattributed because tags are blank?”
- “Which subscriptions or resource groups have weak tag hygiene?”
- “Which services are missing cost allocation tags?”
- “Can we support showback or chargeback with our current tagging?”
- “Which business fields are populated enough to trust?”

## Recommended workflow

### Step 1: Inspect observed tags and business fields

Start by reviewing a small sample from `Costs()`.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| project ServiceName, SubAccountName, x_ResourceGroupName, x_CostCenter, x_Project, Tags
| take 50
```

Inspect which populated tags and fields are present. Review which available keys inside `Tags` are actually populated, and note whether `x_CostCenter` or `x_Project` is present often enough to support allocation.

Useful candidate tags often include:

- `Tags['environment']`
- `Tags['team']`
- `Tags['application']`
- `Tags['owner']`
- `Tags['costCenter']`
- `Tags['project']`

If available, compare those tags with `x_CostCenter` and `x_Project`. When populated, those business fields may be more stable than raw tags for financial reporting.

### Step 2: Establish the total cost baseline

Measure total effective cost for the reporting period before calculating any coverage percentage.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| summarize TotalCost = sum(EffectiveCost)
```

This gives the denominator for all coverage calculations.

### Step 3: Measure single-tag coverage honestly

Choose one observed tag and calculate how much cost has a non-empty value.

```kusto
let base =
    Costs()
    | where ChargePeriodStart >= startofmonth(ago(30d))
    | extend Environment = tostring(Tags['environment']);
base
| summarize
    TotalCost = sum(EffectiveCost),
    TaggedCost = sumif(EffectiveCost, isnotempty(Environment))
| extend UntaggedCost = TotalCost - TaggedCost,
         TagCoverage = TaggedCost / TotalCost
```
 
Repeat the same pattern for any observed tag or field that matters to the business, such as `Tags['team']`, `Tags['application']`, `x_CostCenter`, or `x_Project`.

If populated coverage is weak, say so directly. Blank values are an important finding.

### Step 4: Break down weak coverage by business context

Once you find a weak tag, determine where the unattributed cost lives.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend Environment = tostring(Tags['environment'])
| summarize TotalCost = sum(EffectiveCost),
            UntaggedCost = sumif(EffectiveCost, isempty(Environment))
    by SubAccountName, ServiceName, x_ResourceGroupName
| order by UntaggedCost desc
```

This highlights which `SubAccountName`, `ServiceName`, or `x_ResourceGroupName` values have the largest unattributed cost.

### Step 5: Compare tag coverage with financial hierarchy fields

If available, compare tag-based attribution with business hierarchy fields.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend Team = tostring(Tags['team']),
         Application = tostring(Tags['application'])
| summarize EffectiveCost = sum(EffectiveCost)
    by x_CostCenter, x_Project, Team, Application, SubAccountName
| order by EffectiveCost desc
```

Use `cost-by-financial-hierarchy.kql` as the validated pattern when you need a fuller billing hierarchy view. This is especially useful when tags are only partially populated but financial ownership fields are more reliable.

### Step 6: Check service-level tag hygiene

Some services may have weaker tagging than others.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend ProjectTag = tostring(Tags['project'])
| summarize TotalCost = sum(EffectiveCost),
            TaggedCost = sumif(EffectiveCost, isnotempty(ProjectTag))
    by ServiceName
| extend Coverage = TaggedCost / TotalCost
| order by Coverage asc, TotalCost desc
```

Use this to identify high-cost services with poor tag coverage first.

### Step 7: Check account and resource-group concentration

Weak tagging is often concentrated in a few places.

```kusto
Costs()
| where ChargePeriodStart >= startofmonth(ago(30d))
| extend CostCenter = coalesce(x_CostCenter, tostring(Tags['costCenter']))
| summarize TotalCost = sum(EffectiveCost),
            UnallocatedCost = sumif(EffectiveCost, isempty(CostCenter))
    by SubAccountName, x_ResourceGroupName
| order by UnallocatedCost desc
```

This helps prioritize cleanup by subscription and resource group instead of treating tag coverage as one flat percentage.

## Output guidance

### 1. Executive summary

- Reporting window
- Total effective cost analyzed
- Best observed attribution field or tag
- Weakest important tag or field
- Total unattributed cost
- Highest-priority cleanup target

### 2. Coverage scorecard

| Field or tag | Coverage % | Tagged cost | Untagged cost | Notes |
|---|---:|---:|---:|---|
| `Tags['environment']` | XX% | $X | $Y | Observed, partially populated |
| `Tags['team']` | XX% | $X | $Y | Optional in some subscriptions |
| `x_CostCenter` | XX% | $X | $Y | Better for finance if populated |
| `x_Project` | XX% | $X | $Y | Sparse in shared platforms |

### 3. Untagged or unattributed cost breakdown

Report where blank values concentrate:

- by `SubAccountName`
- by `ServiceName`
- by `x_ResourceGroupName`
- by `x_CostCenter` or `x_Project` when populated

### 4. Interpretation notes

- Call out which tags were observed.
- Call out which fields were optional.
- State whether business conclusions rely on tags, enrichment fields, or both.
- Tell readers to inspect populated tags and fields before standardizing on one allocation key.

## Analyst guidance

1. Use `Costs()` first; this is the primary surface for coverage analysis.
2. Inspect populated tags and available fields before choosing the dimensions to report.
3. Treat blank tags as governance evidence, not just missing formatting.
4. Prefer the most consistently populated field, even if it is `x_CostCenter` or `x_Project` instead of a tag.
5. Use `costs-enriched-base.kql` when you need to validate what the hub actually contains.
6. Use `cost-by-financial-hierarchy.kql` when you need to compare tags with billing ownership structure.
7. Use `finops-hub-database-guide.md` and `INDEX.md` before inventing custom assumptions about schema.

## See also

- [finops-hub-database-guide.md](./queries/finops-hub-database-guide.md)
- [INDEX.md](./queries/INDEX.md)
- [costs-enriched-base.kql](./queries/catalog/costs-enriched-base.kql)
- [cost-by-financial-hierarchy.kql](./queries/catalog/cost-by-financial-hierarchy.kql)
