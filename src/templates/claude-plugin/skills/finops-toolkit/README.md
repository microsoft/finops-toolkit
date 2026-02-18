# FinOps Toolkit skill

KQL-based cost analysis and infrastructure deployment for [FinOps hubs](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview). Provides a query catalog of 17 pre-built KQL queries, database schema documentation, hub deployment workflows, and a structured think-execute framework for financial analysis.

## When this skill activates

Triggered when you ask about: FinOps hubs, FinOps toolkit, KQL queries, Kusto, cost data analysis, Hub database, Costs function, Prices function, Recommendations function, FinOps hubs deployment, Azure Data Explorer, or ADX cluster.

## Prerequisites

- Azure CLI authenticated (`az login`)
- Azure MCP Server (provided by the plugin)
- Database Viewer access to a FinOps hubs ADX cluster
- Environment configured in `.ftk/environments.local.md` (use `/ftk-hubs-connect`)

## Core rules

1. Read the reference docs before writing any query
2. Verify schema before any query (check database guide)
3. Never guess column names or data
4. Show query before execution
5. Stop if confidence < 70%

## Database functions

The FinOps hubs database exposes four analytic functions:

| Function | Purpose | Key columns |
|----------|---------|-------------|
| `Costs()` | Cost and usage analytics (FOCUS-aligned) | `BilledCost`, `EffectiveCost`, `ContractedCost`, `ListCost`, `ServiceName`, `ResourceName`, `Tags` |
| `Prices()` | Price sheets with list, contracted, and effective pricing | `ListUnitPrice`, `ContractedUnitPrice`, `x_EffectiveUnitPrice`, `PricingUnit` |
| `Recommendations()` | Reservation and savings plan recommendations | `x_EffectiveCostBefore`, `x_EffectiveCostAfter`, `x_EffectiveCostSavings` |
| `Transactions()` | Commitment purchases, refunds, and exchanges | `BilledCost`, `ChargeCategory`, `x_SkuTerm`, `x_TransactionType` |

Columns prefixed with `x_` are toolkit enrichments added during ingestion (e.g., `x_ResourceGroupName`, `x_CommitmentDiscountSavings`, `x_TotalSavings`).

## Query catalog

17 pre-built KQL queries in `references/queries/catalog/`. Always check the catalog before writing custom KQL.

| Query | Purpose | Parameters |
|-------|---------|------------|
| `costs-enriched-base.kql` | Full enrichment base for custom analytics | `startDate`, `endDate` |
| `monthly-cost-trend.kql` | Billed and effective cost by month | `startDate`, `endDate` |
| `monthly-cost-change-percentage.kql` | Month-over-month cost change % | `startDate`, `endDate` |
| `top-services-by-cost.kql` | Top N services by cost | `N`, `startDate`, `endDate` |
| `top-resource-types-by-cost.kql` | Top N resource types by cost | `N`, `startDate`, `endDate` |
| `top-resource-groups-by-cost.kql` | Top N resource groups by cost | `N`, `startDate`, `endDate` |
| `quarterly-cost-by-resource-group.kql` | Resource group costs by quarter | `N`, `startDate`, `endDate` |
| `cost-by-region-trend.kql` | Effective cost by Azure region | `startDate`, `endDate` |
| `cost-by-financial-hierarchy.kql` | Cost by billing profile, team, product, app | `N`, `startDate`, `endDate` |
| `cost-anomaly-detection.kql` | Statistical anomaly detection | `numberOfMonths`, `interval` |
| `cost-forecasting-model.kql` | Future cost projections | `forecastPeriods`, `interval` |
| `service-price-benchmarking.kql` | Price comparison across tiers | `startDate`, `endDate` |
| `commitment-discount-utilization.kql` | RI/SP utilization analysis | `startDate`, `endDate` |
| `savings-summary-report.kql` | Total savings and ESR KPI | `startDate`, `endDate` |
| `top-commitment-transactions.kql` | Top N RI/SP purchases | `N`, `startDate`, `endDate` |
| `top-other-transactions.kql` | Top N non-usage transactions | `N`, `startDate`, `endDate` |
| `reservation-recommendation-breakdown.kql` | Reservation recommendations with break-even | Filter by service/region |

See `references/queries/INDEX.md` for the full scenario-to-query matrix.

## Hub deployment

The skill covers FinOps hubs infrastructure deployment via Azure portal, PowerShell (`Deploy-FinOpsHub`), or Bicep modules. Architecture includes:

- Storage Account (Data Lake Gen2) for data staging
- Azure Data Factory for ingestion pipelines
- Azure Data Explorer or Microsoft Fabric RTI for analytics
- Key Vault for managed identity credentials

Estimated cost: ~$120/mo + $10/mo per $1M in monitored spend.

See `references/finops-hubs-deployment.md` for deployment methods, scope configuration, backfill, Fabric setup, and dashboard/Power BI report setup.

## Reference documentation

| File | Contents |
|------|----------|
| `references/finops-hubs.md` | Analysis guide: KQL execution, query catalog protocol, tool matrix, performance rules, quality checklist |
| `references/finops-hubs-deployment.md` | Deployment: prerequisites, methods (portal/PowerShell/Bicep), exports, backfill, Fabric, dashboards |
| `references/settings-format.md` | `.ftk/environments.local.md` format: named environments with cluster-uri, tenant, subscription |
| `references/queries/INDEX.md` | Query-to-scenario matrix with parameters and usage guidance |
| `references/queries/finops-hub-database-guide.md` | Full database schema: all four functions, column definitions, enrichment columns, query best practices |
| `references/workflows/ftk-hubs-connect.md` | Hub discovery via Resource Graph, connection validation, environment persistence |
| `references/workflows/ftk-hubs-healthCheck.md` | Version comparison against stable/dev releases, data freshness check |

## Query execution

```json
{
  "cluster-uri": "<from .ftk/environments.local.md>",
  "database": "Hub",
  "tenant": "<from .ftk/environments.local.md>",
  "query": "<KQL query>"
}
```

Always use the "Hub" database (never "Ingestion"). Always include `tenant` for cross-tenant scenarios.
