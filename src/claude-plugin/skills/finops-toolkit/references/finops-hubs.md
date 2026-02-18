---
name: FinOps Hubs Analysis
description: Domain knowledge for analyzing cloud financial data in [Microsoft FinOps Hubs](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview). It enables cost analysis, anomaly detection, savings optimization, and FinOps Framework-aligned reporting. **Mission**: Transform cloud cost data into actionable business insights through FinOps best practices. **Capabilities**: KQL analysis | Anomaly detection | Multi-cloud support | FinOps Framework guidance **Temporal**: Data refreshes daily | Default 30-day analysis | UTC timezone
---

## Query Access

All KQL queries are located in `references/queries/`:

| Resource | Path | Purpose |
|----------|------|---------|
| **Index** | `references/queries/INDEX.md` | Query catalog with descriptions and parameters |
| **Catalog** | `references/queries/catalog/*.kql` | Actual query files to execute |
| **Schema** | `references/queries/finops-hub-database-guide.md` | Database schema and column definitions |

**To execute a query:**
1. Read the .kql file from `references/queries/catalog/[name].kql`
2. Substitute parameters (startDate, endDate, N, etc.)
3. Get environment config from `.ftk/environments.local.md` (cluster-uri, tenant, subscription, resource-group)
4. Execute via `mcp__azure-mcp-server__kusto` command `kusto_query`

**Required MCP parameters:**
```json
{
  "cluster-uri": "<cluster-uri from .ftk/environments.local.md>",
  "database": "Hub",
  "tenant": "<tenant from .ftk/environments.local.md>",
  "query": "<your KQL query>"
}
```

> **CRITICAL**: Always include `tenant` parameter. Cross-tenant (B2B) scenarios fail with "Unauthorized" if tenant is omitted.

---

## Critical Constraints

> **KUSTO (KQL), NOT SQL**
>
> FinOps Hubs uses **Azure Data Explorer (Kusto)**, not SQL Server. Use **KQL syntax only**.
>
> | KQL | SQL |
> |-----|-----|
> | `| where Column == "value"` | `WHERE Column = 'value'` |
> | `| summarize count() by Column` | `SELECT COUNT(*) GROUP BY Column` |
> | `| project Column1, Column2` | `SELECT Column1, Column2` |
> | `| take 10` | `TOP 10` or `LIMIT 10` |
>
> **NEVER use SQL syntax.** Queries will fail.

**Database Rules:**
- Always use "Hub" database, NEVER "Ingestion"
- Function-based access: `Costs()`, `Prices()`, `Recommendations()`

---

## Query Catalog Summary

> **Tip:** Read `references/queries/INDEX.md` for the full catalog. Start with `costs-enriched-base.kql` for custom analytics.

| FinOps Task | Query File | Key Parameters |
|-------------|------------|----------------|
| Foundation for custom analysis | `costs-enriched-base.kql` | `startDate`, `endDate` |
| Monthly cost trends | `monthly-cost-trend.kql` | `startDate`, `endDate` |
| Top resource groups | `top-resource-groups-by-cost.kql` | `N`, `startDate`, `endDate` |
| Top services | `top-services-by-cost.kql` | `N`, `startDate`, `endDate` |
| Anomaly detection | `cost-anomaly-detection.kql` | `numberOfMonths`, `interval` |
| Commitment utilization | `commitment-discount-utilization.kql` | `startDate`, `endDate` |
| Savings summary (ESR) | `savings-summary-report.kql` | `startDate`, `endDate` |
| Cost forecasting | `cost-forecasting-model.kql` | `forecastPeriods`, `interval` |
| Reservation recommendations | `reservation-recommendation-breakdown.kql` | Filter by service/region |

**Catalog Protocol:**
1. ALWAYS check the catalog FIRST before writing custom queries
2. Read the actual .kql file to get the exact query
3. Adapt only the parameters, never recreate enrichment logic
4. The `x_*` columns are pre-calculated - use them directly

---

## Tool Matrix

| Scenario | Primary Tool | Fallback |
|----------|--------------|----------|
| Cost queries | Query Catalog → `mcp__azure-mcp-server__kusto` | Manual query |
| Azure docs | `microsoft-docs:microsoft-docs` | Web search |
| Code reference | `microsoft-docs:microsoft-code-reference` | Web search |
| Resources | Azure Resource Graph via `mcp__azure-mcp-server__kusto` | Azure CLI |

---

## Performance Rules

1. **Default**: 30 days (`ago(30d)`)
2. **Max**: 90 days without approval
3. **Freshness check**: `Costs | where ChargePeriodStart >= ago(7d) | summarize max(ChargePeriodStart)`

**Bad**: `Costs | summarize sum(BilledCost)`
**Good**: `Costs | where ChargePeriodStart >= ago(30d) | summarize sum(BilledCost)`

---

## FinOps Framework Alignment

**Understand & Cost**: Allocation (tags) | Anomalies | Ingestion | Analytics
**Optimize**: Reservations | Right-sizing | Scheduling
**Quantify Value**: Unit economics | Budgets | Forecasts
**Manage Practice**: Governance | Onboarding | Education

---

## Quality Checklist

- [ ] Query Catalog checked FIRST
- [ ] Time filters on ALL queries
- [ ] Query shown to user before execution
- [ ] Results validated for completeness
- [ ] Confidence level stated
- [ ] Recommendations are actionable
- [ ] Impact quantified in dollars

---

## References

- [FinOps Framework (Microsoft Learn)](https://learn.microsoft.com/cloud-computing/finops/framework/finops-framework)
- [FinOps Hubs Overview](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview)
- [KQL Documentation](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [FinOps Foundation](https://www.finops.org/framework/)
