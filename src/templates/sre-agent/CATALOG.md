# FinOps toolkit SRE Agent - current catalog

This catalog documents the current `recipes/finops-hub/` implementation for the SRE Agent template. The source of truth is the recipe content in this repository:

- Agent defaults: `recipes/finops-hub/agent.json`
- Expected inventory: `recipes/finops-hub/expected-config.json`
- Subagents: `recipes/finops-hub/config/subagents/*.yaml`
- Skills: `recipes/finops-hub/config/skills/*/`
- Tools: `recipes/finops-hub/config/tools/*.yaml`
- Scheduled tasks: `recipes/finops-hub/automations/scheduled-tasks/*.yaml`

## Implemented inventory

| Component | Count | Source |
|-----------|------:|--------|
| Subagents | 5 | `config/subagents/*.yaml` |
| Skills | 3 | `config/skills/*/` |
| Tools | 34 | `config/tools/*.yaml` |
| Scheduled tasks | 19 | `automations/scheduled-tasks/*.yaml` |
| Connector | 1 | `connectors.json` |

Tool mix:

| Tool type | Count |
|-----------|------:|
| KustoTool | 21 |
| PythonTool | 13 |

## Subagents

| Subagent | Scheduled tasks | Tool access | Focus |
|----------|----------------:|------------:|-------|
| `azure-capacity-manager` | 9 | 19 | Azure quota, capacity reservation groups, region and zone access, AKS capacity readiness, and capacity governance. |
| `chief-financial-officer` | 3 | 27 | Executive finance, budgeting, forecasting, risk, capital allocation, and FinOps cost optimization. |
| `finops-practitioner` | 5 | 28 | FinOps practice guidance, allocation, showback or chargeback, commitment optimization, governance, anomaly response, and maturity assessment. |
| `ftk-database-query` | 0 | 26 | FinOps Hub database and KQL work, schema-aware analysis, recommendations, transactions, and pricing interpretation. |
| `ftk-hubs-agent` | 2 | 9 | FinOps Hubs deployment, upgrade, maintenance, troubleshooting, and validation. |

## Skills

| Skill | Path |
|-------|------|
| `azure-capacity-management` | `config/skills/azure-capacity-management/` |
| `azure-cost-management` | `config/skills/azure-cost-management/` |
| `finops-toolkit` | `config/skills/finops-toolkit/` |

## Scheduled tasks

| Task | Agent | Schedule | Source | Purpose |
|------|-------|----------|--------|---------|
| `CapacityDailyMonitor` | `azure-capacity-manager` | `30 6 * * *` | `capacity-daily-monitor.yaml` | Daily capacity supply chain health check: quota usage, CRG utilization, and zone capacity. |
| `HubsHealthCheck` | `ftk-hubs-agent` | `0 6 * * *` | `hubs-health-check.yaml` | FinOps Hub version and data freshness validation. |
| `Monthly` | `finops-practitioner` | `15 17 5 * *` | `monthly-report.yaml` | Autonomous monthly cost analysis. |
| `CapacityWeeklySupplyReview` | `azure-capacity-manager` | `0 8 * * 1` | `capacity-weekly-supply-review.yaml` | Weekly capacity supply chain review for quota headroom, CRG optimization, SKU availability, and benefit recommendations. |
| `ComputeUtilizationTrend` | `azure-capacity-manager` | `0 7 * * 1` | `compute-utilization-trend.yaml` | Weekly VM quota utilization trend review across subscriptions and regions. |
| `CostOptimization` | `finops-practitioner` | `0 8 * * 1` | `cost-optimization.yaml` | Comprehensive cost optimization report with orphaned resources, rightsizing, and commitment analysis. |
| `NonComputeQuotaAudit` | `azure-capacity-manager` | `0 7 * * 2` | `non-compute-quota-audit.yaml` | Weekly storage, network, and non-compute quota risk audit. |
| `DbQuotaAudit` | `azure-capacity-manager` | `0 7 * * 3` | `db-quota-audit.yaml` | Weekly SQL DB, SQL MI, Cosmos DB, PostgreSQL Flex, and MySQL Flex quota and region/AZ access audit. |
| `SkuAvailabilityAudit` | `azure-capacity-manager` | `0 7 * * 3` | `sku-availability-audit.yaml` | Weekly regional SKU availability and restriction audit. |
| `MonitoringScopeValidation` | `ftk-hubs-agent` | `0 9 * * 4` | `monitoring-scope-validation.yaml` | Weekly validation that FinOps Hub monitoring covers all active subscriptions. |
| `BenefitRecommendationReview` | `chief-financial-officer` | `0 8 * * 5` | `benefit-recommendation-review.yaml` | Weekly executive review of reservation and savings plan recommendations. |
| `AdvisorSuppressionReview` | `finops-practitioner` | `0 9 1 * *` | `advisor-suppression-review.yaml` | Monthly review of active Advisor recommendation suppressions for stale or expired decisions. |
| `AIWorkloadCostAnalysis` | `chief-financial-officer` | `0 10 1 * *` | `ai-workload-cost-analysis.yaml` | Monthly AI workload cost analysis for Azure OpenAI token economics, model efficiency, and cost allocation. |
| `CapacityMonthlyPlanning` | `azure-capacity-manager` | `0 9 1 * *` | `capacity-monthly-planning.yaml` | Monthly capacity planning cycle for demand forecasting, procurement pipeline, and governance review. |
| `StoragePaasGrowthForecast` | `azure-capacity-manager` | `0 8 1 * *` | `storage-paas-growth-forecast.yaml` | Monthly storage and PaaS quota growth forecast across active subscriptions. |
| `YOY` | `chief-financial-officer` | `0 9 5 1,7 *` | `yoy-report.yaml` | Semiannual year-over-year financial analysis for January and July close checkpoints. |
| `BudgetCoverageAudit` | `finops-practitioner` | `0 8 15 * *` | `budget-coverage-audit.yaml` | Monthly audit of subscription budget coverage and missing budget controls. |
| `AlertCoverageAudit` | `finops-practitioner` | `0 8 16 * *` | `alert-coverage-audit.yaml` | Monthly audit of cost anomaly alert coverage across active subscriptions. |
| `CapacityQuarterlyStrategy` | `azure-capacity-manager` | `0 9 1 1,4,7,10 *` | `capacity-quarterly-strategy.yaml` | Quarterly capacity strategy review for supply chain maturity, commitment alignment, and architecture evolution. |

## Tool inventory

### Kusto tools

| Tool | Purpose |
|------|---------|
| `ai-cost-by-application` | Breaks down Azure OpenAI costs by application, team, and environment tags. |
| `ai-daily-trend` | Reports daily Azure OpenAI cost and token consumption trends. |
| `ai-model-cost-comparison` | Compares cost per 1K tokens across Azure OpenAI model versions. |
| `ai-token-usage-breakdown` | Breaks Azure OpenAI token consumption down by model version and input/output direction. |
| `commitment-discount-utilization` | Analyzes consumed core hours by commitment discount type. |
| `cost-anomaly-detection` | Detects cost spikes and drops over a configurable history window. |
| `cost-by-financial-hierarchy` | Summarizes costs across billing profile, invoice section, team, product, application, and environment. |
| `cost-by-region-trend` | Summarizes effective cost by Azure region. |
| `cost-forecasting-model` | Forecasts future effective cost from historical cost data. |
| `costs-enriched-base` | Returns enriched row-level cost and usage samples for drill-down analysis. |
| `monthly-cost-change-percentage` | Calculates month-over-month billed and effective cost change. |
| `monthly-cost-trend` | Returns billed and effective cost totals by month. |
| `quarterly-cost-by-resource-group` | Returns top resource-group cost rows by subscription and month. |
| `reservation-recommendation-breakdown` | Analyzes Microsoft reservation recommendations from `Recommendations()`. |
| `savings-summary-report` | Summarizes list cost, effective cost, negotiated discount savings, commitment savings, and effective savings rate. |
| `service-price-benchmarking` | Benchmarks services by list, contracted, and effective cost. |
| `top-commitment-transactions` | Returns top non-usage commitment discount purchase transactions. |
| `top-other-transactions` | Returns top non-usage, non-commitment purchase transactions. |
| `top-resource-groups-by-cost` | Returns top resource groups by effective cost. |
| `top-resource-types-by-cost` | Returns top resource types by count and effective cost. |
| `top-services-by-cost` | Returns top Azure services by effective cost. |

### Python tools

| Tool | Purpose |
|------|---------|
| `benefit-recommendations` | Gets Cost Management benefit recommendations for savings plans and reserved instances. |
| `capacity-reservation-groups` | Lists capacity reservation groups and reports reserved versus allocated capacity. |
| `data-freshness-check` | Checks FinOps Hub function data freshness through Azure Data Explorer REST queries. |
| `db-service-quotas` | Reports SQL DB, SQL MI, Cosmos DB, PostgreSQL Flex, and MySQL Flex quota and region access signals. |
| `deploy-anomaly-alert` | Creates or updates a Cost Management scheduled action for anomaly detection. |
| `deploy-budget` | Creates or updates a subscription-level Cost Management budget. |
| `deploy-bulk-anomaly-alerts` | Creates or updates anomaly alert scheduled actions across subscriptions discovered from a management group. |
| `deploy-bulk-budgets` | Creates or updates Cost Management budgets across subscriptions discovered from a management group. |
| `non-compute-quotas` | Checks non-compute Azure service quota utilization. |
| `resource-graph-query` | Runs Azure Resource Graph KQL across one or more subscriptions. |
| `sku-availability` | Lists regional SKU availability for Azure Compute or Azure Data Explorer. |
| `suppress-advisor-recommendations` | Suppresses selected Azure Advisor recommendations across subscriptions under a management group. |
| `vm-quota-usage` | Reports Azure VM family quota usage and quota risk by subscription and region. |

## Operating notes

- Scheduled tasks are applied outside the main Bicep deployment by `bicep/apply-extras.sh`.
- `README.md` carries the deployment workflow; this file carries the detailed implemented recipe inventory.
- Add or remove scheduled task YAML, tool YAML, subagent YAML, or skill directories first, then update this catalog and `README.md` in the same change.
