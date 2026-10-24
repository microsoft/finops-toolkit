---
name: power-bi-finops
description: Use when the user wants to connect, customize, troubleshoot, or build Power BI reports on Azure cost data, including the FinOps toolkit Power BI reports, the Cost Management connector, FinOps hubs (Azure Data Explorer / Microsoft Fabric) data sources, report refresh failures, or turning scan and KQL output into dashboards and visuals.
license: MIT
compatibility: Requires Power BI Desktop (or the Power BI service) and read access to the cost data source — a Cost Management scope, a FinOps hub ADX cluster, or a Fabric workspace. Pairs with the finops-multitool skill and the finops-toolkit skill.
metadata:
  author: microsoft
  version: '1.0'
allowed-tools: az pwsh
---

# Power BI for FinOps

Build and operate Power BI reporting on Azure cost data. The FinOps toolkit ships pre-built Power BI report templates; this skill covers connecting them to a data source, customizing visuals, fixing refresh issues, and building new dashboards from cost data.

## When to use this skill

Use it when the user wants a visual or dashboard, mentions Power BI, `.pbix`/`.pbit` files, report refresh errors, the Cost Management connector, or asks to "visualize" cost, savings, or tag data. For headless analysis (numbers without visuals) prefer the `finops-multitool` skill or the `finops-toolkit` KQL skill, then bring the output here when the user wants it visualized.

## Choosing a data source

| Data source                            | Use when                                                         | Connector                                                                                                       |
| -------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **FinOps hubs (ADX/Kusto)**            | A hub is deployed; want fast, large-scale, multi-month analytics | Azure Data Explorer connector → `Hub` database, `Costs()` / `Prices()` / `Recommendations()` / `Transactions()` |
| **FinOps hubs (Microsoft Fabric RTI)** | Hub deployed to Fabric                                           | Fabric / KQL database connector                                                                                 |
| **Cost Management connector**          | No hub; small scope; quick start                                 | Power BI "Microsoft Cost Management" connector (billing account or EA/MCA scope)                                |
| **FOCUS exports in storage**           | Raw FOCUS cost exports only                                      | Azure Data Lake Storage Gen2 connector → parse parquet/csv                                                      |

The hub data sources are strongly preferred for anything beyond a single small subscription — the Cost Management connector is rate-limited and slow at scale.

## Pre-built toolkit reports

The toolkit publishes report templates aligned to FinOps capabilities. Match the user's intent to the report:

| Report                     | Answers                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| **Cost summary**           | Where is spend going? Trends, top services/resources, MoM change |
| **Rate optimization**      | Are we paying the best rate? Commitment coverage and utilization |
| **Commitment discounts**   | Reservation / savings plan ROI, expirations, recommendations     |
| **Workload optimization**  | Rightsizing, idle/underused resources, waste                     |
| **Governance**             | Tag coverage, policy compliance, allocation readiness            |
| **Data ingestion / FOCUS** | Pipeline health, dataset completeness                            |

Setup steps: open the `.pbit` template → supply the data-source parameters (cluster URI + `Hub` database, or billing scope) → load. For first-time connection details defer to the `finops-toolkit` skill reference `toolkit/power-bi/setup.md` and `toolkit/power-bi/connector.md`.

## Common refresh and connection failures

| Symptom                           | Likely cause                                                              | Fix                                                                               |
| --------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| "We couldn't authenticate" on ADX | Stale credential / wrong tenant                                           | Re-sign in; confirm the signed-in identity has Database Viewer on the hub cluster |
| Empty visuals, no error           | Querying `Ingestion` instead of `Hub`, or date filter outside loaded data | Point queries at the `Hub` database; widen the date slicer                        |
| Refresh times out at scale        | Cost Management connector on a large scope                                | Move to a FinOps hub data source; the connector does not scale                    |
| "Parameter is required" on open   | `.pbit` opened without supplying parameters                               | Re-open the template and fill cluster URI / database / scope                      |
| Costs look low vs. portal         | Comparing `BilledCost` to `EffectiveCost` (or vice versa)                 | Decide the right measure: `BilledCost` = invoice, `EffectiveCost` = amortized     |

## Building custom visuals

1. Get the data shaped first — use a catalog `.kql` query from the `finops-toolkit` skill (e.g. `monthly-cost-trend.kql`, `cost-by-financial-hierarchy.kql`) as the report's query so the model is correct from the start.
2. Use FOCUS column names as field labels (`BilledCost`, `EffectiveCost`, `ServiceName`, `ResourceName`, `Tags`) so reports stay portable across tenants.
3. Default measures: `EffectiveCost` for trend/forecast, `BilledCost` for invoice reconciliation, `x_EffectiveCostSavings` for savings.
4. For chargeback/showback pages, drive the hierarchy from the allocation model in the `cost-allocation` skill (tags + billing hierarchy) rather than ad-hoc grouping.

## Hand-offs

- Need the underlying numbers or a KQL query → `finops-toolkit` skill.
- Need live read-only numbers to seed a visual → `finops-multitool` skill (cost trend, resource costs, tag inventory).
- Need an executive narrative around the visuals → `finops-reporting` skill.
