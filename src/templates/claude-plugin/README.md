# FinOps Toolkit plugin for Claude Code

A Claude Code plugin that provides AI-powered cloud financial management using the [FinOps Toolkit](https://github.com/microsoft/finops-toolkit) and [Azure Cost Management](https://learn.microsoft.com/en-us/cost-management-billing/).

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) authenticated (`az login`)
- Appropriate Azure RBAC permissions for Cost Management APIs
- For queries: Database Viewer access to a [FinOps hubs](https://learn.microsoft.com/cloud-computing/finops/toolkit/hubs/finops-hubs-overview) ADX cluster

## Installation

Add the plugin to your Claude Code project:

```bash
claude plugin add /path/to/plugin-finops-toolkit
```

The plugin registers an [Azure MCP Server](https://github.com/Azure/azure-mcp) with the Kusto namespace in read-only mode for executing KQL queries against Azure Data Explorer.

## What's included

### Skills

| Skill | Trigger keywords | Description |
|-------|-----------------|-------------|
| **finops-toolkit** | "FinOps hubs", "KQL queries", "Kusto", "Hub database", "ADX cluster" | FinOps hubs query and deployment. KQL-based cost analysis with a think-execute framework, 17 pre-built queries, and schema validation. |
| **azure-cost-management** | "Azure Advisor", "savings plans", "reservations", "budgets", "cost exports", "MACC", "Azure credits" | Azure Cost Management operations: recommendations, budgets, exports, anomaly alerts, and commitment tracking. |

### Agents

| Agent | Color | Description |
|-------|-------|-------------|
| **chief-financial-officer** | Blue | Strategic CFO with 25+ years experience. Covers financial strategy, FP&A, capital allocation, risk management, treasury, tax, investor relations, and FinOps. Produces structured executive-level analysis. |
| **finops-practitioner** | Green | Certified FinOps expert grounded in the six FinOps principles and the Crawl-Walk-Run maturity model. Guides cost allocation, commitment optimization, showback/chargeback, and practice adoption. |
| **ftk-database-query** | Cyan | KQL specialist for the FinOps hubs database. Queries `Costs()`, `Prices()`, `Recommendations()`, and `Transactions()` functions. Uses a catalog of 17 pre-built queries before writing custom KQL. |
| **ftk-hubs-agent** | Red | Azure infrastructure engineer for FinOps hubs deployment, upgrades, and troubleshooting. Handles Bicep templates, Cost Management exports, and post-deployment validation with platform-aware CLI guidance. |

### Commands

| Command | Description |
|---------|-------------|
| `/ftk-hubs-connect` | Discover FinOps hub instances via Azure Resource Graph, connect to a cluster, validate the connection, and save environment settings to `.ftk/environments.local.md`. |
| `/ftk-hubs-healthCheck` | Check deployed hub version against latest stable/dev releases and validate data freshness. |
| `/ftk-mom-report` | Autonomous month-over-month cost analysis with anomaly detection, forecasting, and actionable recommendations. |
| `/ftk-ytd-report` | Comprehensive fiscal year-to-date analysis with forecast through end of fiscal year (June 30). |

### Output style

**ftk-output-style** -- Enforces fact-grounded financial analysis formatting: evidence-backed claims, proper currency formatting (`$1,234,567.89`), percentage conventions, period-over-period tables with variance columns, confidence levels (Confirmed/Estimated/Assumed), and FinOps Framework terminology (FOCUS specification, Crawl/Walk/Run maturity).

### Query catalog

17 pre-built KQL queries for common FinOps scenarios, located in `skills/finops-toolkit/references/queries/catalog/`:

| Query | Purpose |
|-------|---------|
| `costs-enriched-base.kql` | Base query with full enrichment and savings logic. Start here for custom analytics. |
| `monthly-cost-trend.kql` | Billed and effective cost by month for trend analysis. |
| `monthly-cost-change-percentage.kql` | Month-over-month cost change percentage. |
| `top-services-by-cost.kql` | Top N Azure services by cost. |
| `top-resource-types-by-cost.kql` | Top N resource types by cost and usage. |
| `top-resource-groups-by-cost.kql` | Top N resource groups by effective cost. |
| `quarterly-cost-by-resource-group.kql` | Effective cost by resource group for multi-month reporting. |
| `cost-by-region-trend.kql` | Effective cost by Azure region. |
| `cost-by-financial-hierarchy.kql` | Cost by billing profile, invoice section, team, product, app. |
| `cost-anomaly-detection.kql` | Statistical anomaly detection for cost spikes. |
| `cost-forecasting-model.kql` | Projected future costs with configurable forecast horizon. |
| `service-price-benchmarking.kql` | Compare list, contracted, effective, and commitment prices. |
| `commitment-discount-utilization.kql` | Reservation and savings plan utilization. |
| `savings-summary-report.kql` | Total realized savings and Effective Savings Rate (ESR). |
| `top-commitment-transactions.kql` | Top N reservation/savings plan purchases. |
| `top-other-transactions.kql` | Top N non-commitment, non-usage transactions (support, marketplace). |
| `reservation-recommendation-breakdown.kql` | Microsoft reservation recommendations with projected savings. |

### Reference documentation

| File | Description |
|------|-------------|
| `skills/finops-toolkit/references/finops-hubs.md` | FinOps hubs analysis guide: KQL execution, query catalog, anomaly detection, tool matrix. |
| `skills/finops-toolkit/references/finops-hubs-deployment.md` | Deployment and configuration: ADX clusters, Fabric, exports, dashboards, troubleshooting. |
| `skills/finops-toolkit/references/settings-format.md` | `.ftk/environments.local.md` format for named hub environments. |
| `skills/finops-toolkit/references/queries/INDEX.md` | Query-to-scenario matrix with parameters and usage guidance. |
| `skills/finops-toolkit/references/queries/finops-hub-database-guide.md` | Hub database schema: `Costs()`, `Prices()`, `Recommendations()`, `Transactions()` column definitions. |
| `skills/azure-cost-management/references/azure-advisor.md` | Azure Advisor cost recommendations and suppression. |
| `skills/azure-cost-management/references/azure-savings-plans.md` | Savings plan and reservation analysis. |
| `skills/azure-cost-management/references/azure-budgets.md` | Budget creation, notifications, action groups. |
| `skills/azure-cost-management/references/azure-cost-exports.md` | FOCUS format cost exports with backfill. |
| `skills/azure-cost-management/references/azure-anomaly-alerts.md` | Cost anomaly alert deployment. |
| `skills/azure-cost-management/references/azure-credits.md` | Azure Prepayment/credit tracking. |
| `skills/azure-cost-management/references/azure-macc.md` | Microsoft Azure Consumption Commitment tracking. |

## Environment configuration

Hub connection settings are stored in `.ftk/environments.local.md` at your project root:

```markdown
---
default: myhub.eastus
environments:
  myhub.eastus:
    cluster-uri: https://myhub.eastus.kusto.windows.net
    tenant: 00000000-0000-0000-0000-000000000000
    subscription: my-subscription
    resource-group: rg-finops
---
```

Run `/ftk-hubs-connect` to auto-discover and configure hub environments.

## Quick start

1. Install the plugin
2. Run `/ftk-hubs-connect` to discover and connect to your FinOps hub
3. Ask questions: "What are the top 10 most expensive resources this month?"
4. Run `/ftk-mom-report` for a full month-over-month analysis

## License

MIT
